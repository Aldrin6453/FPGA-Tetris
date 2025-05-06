
//-------------------------------------------------------------------------
//    color_mapper.sv
//    Renders NUM falling squares in distinct colors atop a gradient background
//-------------------------------------------------------------------------
module color_mapper #(
    parameter int NUM = 4
)(
    input  logic [9:0] BallX [NUM],
    input  logic [9:0] BallY [NUM],
    input  logic [9:0] Ball_size [NUM],
    input  logic [9:0] DrawX,
    input  logic [9:0] DrawY,
    output logic [3:0] Red,
    output logic [3:0] Green,
    output logic [3:0] Blue
);

    always_comb begin
        // background gradient
        Red   = 4'hf;
Green = 4'hf;
Blue  = 4'hf;

        // overlay each square
        if ((DrawX >= 160 - 16) && (DrawX <= 160 + 16) &&
    (DrawY >= 100 - 16) && (DrawY <= 100 + 16)) begin
    Red = 4'hf;
    Green = 4'h0;
    Blue = 4'h0;
end
        for (int i = 0; i < NUM; i++) begin
            if ((DrawX >= BallX[i] - Ball_size[i]) &&
                (DrawX <= BallX[i] + Ball_size[i]) &&
                (DrawY >= BallY[i] - Ball_size[i]) &&
                (DrawY <= BallY[i] + Ball_size[i])) begin
                case (i)
                    0: begin Red=4'hf; Green=4'h0; Blue=4'h0; end // red
                    1: begin Red=4'h0; Green=4'hf; Blue=4'h0; end // green
                    2: begin Red=4'h0; Green=4'h0; Blue=4'hf; end // blue
                    3: begin Red=4'hf; Green=4'hf; Blue=4'h0; end // yellow
                    default: begin Red=4'hf; Green=4'h0; Blue=4'hf; end // magenta
                endcase
            end
        end
    end
endmodule
