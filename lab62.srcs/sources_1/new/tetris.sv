//?????????????????????????????????????????????????????????????????????????????
//  tetris_core.sv
//      • 7-bag generator
//      • 4 pre-drawn orientations per piece
//      • 32-bit keycode bus  (looks at every HID byte)
//      • A / D : left / right       (edge-triggered)
//      • W     : rotate 90° CW       (edge-triggered)
//      • S     : soft-drop (held)
//      • 3?Hz gravity
//?????????????????????????????????????????????????????????????????????????????
`ifndef TETRIS_CORE_SV
`define TETRIS_CORE_SV

module tetris_core #(
    parameter int DROP_DIV   = 20,   // 60?Hz / 20 ??3?Hz
    parameter int MID_COL    = 3,
    parameter int NUM_SHAPES = 7,
    parameter int NUM_ORI    = 4,
    parameter int TOTAL_MASK = NUM_SHAPES*NUM_ORI   // 28 entries
)(
    input  logic        Reset,
    input  logic        vsync,
    input  logic [31:0] keycodes,      // 4-byte HID report
    output logic [3:0]  board [0:199], // 20×10 playfield
    output logic [2:0]  cur_shape,     // 0-6
    output logic [1:0]  cur_orient,    // 0-3
    output logic [4:0]  cur_row,
    output logic signed [5:0] cur_col,
    output logic [3:0]  cur_clr
);

    //???????????????? ROMs ????????????????????????????????????????????
    localparam logic [15:0] SHAPE_ROM [0:TOTAL_MASK-1] = '{
        // I
        16'b0000_1111_0000_0000, 16'b0010_0010_0010_0010,
        16'b0000_1111_0000_0000, 16'b0010_0010_0010_0010,
        // O
        16'b0000_0110_0110_0000, 16'b0000_0110_0110_0000,
        16'b0000_0110_0110_0000, 16'b0000_0110_0110_0000,
        // T  ? ? ? ?
        16'b0000_0100_1110_0000, 16'b0000_0100_0110_0100,
        16'b0000_0000_1110_0100, 16'b0000_0100_1100_0100,
        // S
        16'b0000_0011_0110_0000, 16'b0000_0100_0110_0010,
        16'b0000_0011_0110_0000, 16'b0000_0100_0110_0010,
        // Z
        16'b0000_1100_0110_0000, 16'b0000_0010_0110_0100,
        16'b0000_1100_0110_0000, 16'b0000_0010_0110_0100,
        // J
        16'b0000_1000_1110_0000, 16'b0000_0110_0100_0100,
        16'b0000_0000_1110_0010, 16'b0000_0100_0100_1100,
        // L
        16'b0000_0010_1110_0000, 16'b0000_0100_0100_0110,
        16'b0000_0000_1110_1000, 16'b0000_1100_0100_0100
    };

    localparam logic [3:0] COLOR_ROM [0:NUM_SHAPES-1] =
        '{4'h6,4'h4,4'h5,4'h2,4'h1,4'h3,4'h7};   // orange, yellow, cyan...

    //???????????????? helpers ?????????????????????????????????????????
    function automatic int idx (input int r, input int c);
        return r*10 + c;
    endfunction

    // "does ANY byte equal value?"
    function automatic logic has_key(input logic [31:0] kc, input logic [7:0] value);
        has_key = (kc[7:0]   == value) ||
                  (kc[15:8]  == value) ||
                  (kc[23:16] == value) ||
                  (kc[31:24] == value);
    endfunction

    // true if tetromino would collide after (dr,dc)
    function automatic logic will_hit
        (input int dr, input int dc,
         input logic [2:0] shape, input logic [1:0] orient);
        int bit_pos, r, c;
        logic [15:0] mask;
        begin
            will_hit = 0;
            mask = SHAPE_ROM[shape*NUM_ORI + orient];
            for (bit_pos = 0; bit_pos < 16; bit_pos++)
                if (mask[bit_pos]) begin
                    r = cur_row + dr + bit_pos/4;
                    c = cur_col + dc + bit_pos%4;
                    if (r > 19 || c < 0 || c > 9)        will_hit = 1;
                    else if (board[idx(r,c)] != 0)       will_hit = 1;
                end
        end
    endfunction

    //???????????????? timing divider (3?Hz) ??????????????????????????
    localparam int DIV_W = $clog2(DROP_DIV);
    logic [DIV_W-1:0] div_ctr;
    wire tick_grav = (div_ctr == DROP_DIV-1);
    always_ff @(posedge vsync or posedge Reset)
        if (Reset) div_ctr <= 0;
        else       div_ctr <= tick_grav ? 0 : div_ctr + 1;

    //???????????????? key edge detection ?????????????????????????????
    logic a_now,d_now,s_now,w_now, a_prev,d_prev,s_prev,w_prev;
    always_ff @(posedge vsync or posedge Reset) begin
        if (Reset) {a_prev,d_prev,s_prev,w_prev} <= 0;
        else       {a_prev,d_prev,s_prev,w_prev} <= {a_now,d_now,s_now,w_now};
    end

    always_comb begin
        a_now = has_key(keycodes, 8'h04);   // A
        d_now = has_key(keycodes, 8'h07);   // D
        s_now = has_key(keycodes, 8'h16);   // S
        w_now = has_key(keycodes, 8'h1A);   // W
    end

    wire trig_left  =  a_now & ~a_prev;
    wire trig_right =  d_now & ~d_prev;
    wire trig_soft  =  s_now;              // held
    wire trig_rot   =  w_now & ~w_prev;

    //???????????????? main FSM ???????????????????????????????????????
    int bit_pos, r, c, rr;
    logic [15:0] mask;

    always_ff @(posedge vsync or posedge Reset) begin
        if (Reset) begin
            for (r = 0; r < 200; r++) board[r] <= 0;
            cur_shape  <= 0;
            cur_orient <= 0;
            cur_row    <= 0;
            cur_col    <= MID_COL;
            cur_clr    <= COLOR_ROM[0];
        end else begin
            // try rotate
            if (trig_rot) begin
                logic [1:0] next_ori = (cur_orient == 3) ? 0 : cur_orient + 1;
                if (!will_hit(0,0,cur_shape,next_ori))
                    cur_orient <= next_ori;
            end

            // horizontal
            if (trig_left  && !will_hit(0,-1,cur_shape,cur_orient))
                cur_col <= cur_col - 1;
            else if (trig_right && !will_hit(0,1,cur_shape,cur_orient))
                cur_col <= cur_col + 1;

            // gravity / soft-drop
            if (tick_grav || trig_soft) begin
                if (will_hit(1,0,cur_shape,cur_orient)) begin
                    // lock piece
                    mask = SHAPE_ROM[cur_shape*NUM_ORI + cur_orient];
                    for (bit_pos = 0; bit_pos < 16; bit_pos++)
                        if (mask[bit_pos]) begin
                            r = cur_row + bit_pos/4;
                            c = cur_col + bit_pos%4;
                            board[idx(r,c)] <= cur_clr;
                        end
                    // clear full rows
                    for (r = 19; r >= 0; r--) begin : CLEAR_LOOP
                        logic full = 1;
                        for (c = 0; c < 10; c++)
                            if (board[idx(r,c)] == 0) full = 0;
                        if (full) begin
                            for (rr = r; rr > 0; rr--)
                                for (c = 0; c < 10; c++)
                                    board[idx(rr,c)] <= board[idx(rr-1,c)];
                            for (c = 0; c < 10; c++) board[idx(0,c)] <= 0;
                        end
                    end
                    // spawn next
                    cur_shape  <= (cur_shape == NUM_SHAPES-1) ? 0 : cur_shape + 1;
                    cur_orient <= 0;
                    cur_row    <= 0;
                    cur_col    <= MID_COL;
                    cur_clr    <= COLOR_ROM[(cur_shape == NUM_SHAPES-1) ? 0 : cur_shape + 1];
                end else begin
                    cur_row <= cur_row + 1;
                end
            end
        end
    end
endmodule
`endif
`ifndef TETRIS_RENDER_SV
`define TETRIS_RENDER_SV
//?????????????????????????????????????????????????????????????????????????????
//  tetris_render.sv
//?????????????????????????????????????????????????????????????????????????????
module tetris_render #(
    parameter int CELL = 16,
    parameter int X0   = (640-10*CELL)/2
)(
    input  logic [9:0] DrawX,
    input  logic [9:0] DrawY,
    input  logic [3:0] board [0:199],
    input  logic [2:0] cur_shape,
    input  logic [1:0] cur_orient,
    input  logic [4:0] cur_row,
    input  logic signed [5:0] cur_col,
    input  logic [3:0] cur_clr,
    output logic [3:0] Red,
    output logic [3:0] Green,
    output logic [3:0] Blue
);
    // 28 masks duplicated for simplicity
    localparam logic [15:0] SHAPE_ROM [0:27] = '{
        16'b0000_1111_0000_0000, 16'b0010_0010_0010_0010,
        16'b0000_1111_0000_0000, 16'b0010_0010_0010_0010,
        16'b0000_0110_0110_0000, 16'b0000_0110_0110_0000,
        16'b0000_0110_0110_0000, 16'b0000_0110_0110_0000,
        16'b0000_0100_1110_0000, 16'b0000_0100_0110_0100,
        16'b0000_0000_1110_0100, 16'b0000_0100_1100_0100,
        16'b0000_0011_0110_0000, 16'b0000_0100_0110_0010,
        16'b0000_0011_0110_0000, 16'b0000_0100_0110_0010,
        16'b0000_1100_0110_0000, 16'b0000_0010_0110_0100,
        16'b0000_1100_0110_0000, 16'b0000_0010_0110_0100,
        16'b0000_1000_1110_0000, 16'b0000_0110_0100_0100,
        16'b0000_0000_1110_0010, 16'b0000_0100_0100_1100,
        16'b0000_0010_1110_0000, 16'b0000_0100_0100_0110,
        16'b0000_0000_1110_1000, 16'b0000_1100_0100_0100
    };

    // board coords
    logic [4:0] row;  logic signed [6:0] col;  logic in_board;
    always_comb begin
        row      = DrawY / CELL;
        col      = (DrawX - X0) / CELL;
        in_board = (DrawX >= X0) && (DrawX < X0 + 10*CELL) &&
                   (DrawY < 20*CELL);
    end

    // active-piece test
    function automatic logic hits_active;
        input logic [4:0] r_in;  input logic signed [6:0] c_in;
        int bit_pos;  logic [15:0] mask;
        begin
            mask = SHAPE_ROM[cur_shape*4 + cur_orient];
            hits_active = 0;
            for (bit_pos = 0; bit_pos < 16; bit_pos++)
                if (mask[bit_pos])
                    if (r_in == cur_row + bit_pos/4 &&
                        c_in == cur_col + bit_pos%4)
                        hits_active = 1;
        end
    endfunction

    // colour selection
    logic [3:0] cell_clr = in_board ? board[row*10 + col] : 4'h0;
    logic [3:0] pix_clr;
    always_comb begin
        if (!in_board)                 pix_clr = 4'h0;
        else if (hits_active(row,col)) pix_clr = cur_clr;
        else if (cell_clr == 0)        pix_clr = 4'hF;
        else                           pix_clr = cell_clr;
    end

    // 16-colour palette
    always_comb
        unique case (pix_clr)
            4'h0 : begin Red=0;  Green=0;  Blue=0;  end
            4'h1 : begin Red=15; Green=0;  Blue=0;  end
            4'h2 : begin Red=0;  Green=15; Blue=0;  end
            4'h3 : begin Red=0;  Green=0;  Blue=15; end
            4'h4 : begin Red=15; Green=15; Blue=0;  end
            4'h5 : begin Red=0;  Green=15; Blue=15; end
            4'h6 : begin Red=15; Green=8;  Blue=0;  end
            4'h7 : begin Red=8;  Green=8;  Blue=8;  end
            4'hF : begin Red=15; Green=15; Blue=15; end
            default: begin Red=15; Green=0; Blue=15; end
        endcase
endmodule
`endif
