//-------------------------------------------------------------------------
//    mb_usb_hdmi_top.sv
//    Zuofu Cheng  -- UPDATED for multi-cell Tetris (May?2025)
//-------------------------------------------------------------------------
//
//  • USB keyboard ? keycodes
//  • VGA timing ? HDMI encoder
//  • 4-digit HEX displays show low-byte keycode
//  • New signals: board_cells, cur_shape, cur_row/col, cur_clr
//-------------------------------------------------------------------------

module mb_usb_hdmi_top(
    input  logic Clk,
    input  logic reset_rtl_0,

    // USB-SPI bridge
    input  logic [0:0] gpio_usb_int_tri_i,
    output logic       gpio_usb_rst_tri_o,
    input  logic       usb_spi_miso,
    output logic       usb_spi_mosi,
    output logic       usb_spi_sclk,
    output logic       usb_spi_ss,

    // UART passthrough
    input  logic uart_rtl_0_rxd,
    output logic uart_rtl_0_txd,

    // HDMI (TMDS)
    output logic hdmi_tmds_clk_n,
    output logic hdmi_tmds_clk_p,
    output logic [2:0] hdmi_tmds_data_n,
    output logic [2:0] hdmi_tmds_data_p,

    // 4-digit HEX displays (two banks)
    output logic [7:0] hex_segA,
    output logic [3:0] hex_gridA,
    output logic [7:0] hex_segB,
    output logic [3:0] hex_gridB
);

    //---------------------------------------------------------------------
    //  Clock / Reset plumbing
    //---------------------------------------------------------------------
    logic clk_25MHz, clk_125MHz;
    logic locked;
    logic reset_ah;          // active-high reset for our modules
    assign reset_ah = reset_rtl_0;

    //---------------------------------------------------------------------
    //  Keycode registers from USB block-design ("design_1")
    //---------------------------------------------------------------------
    logic [31:0] keycode0_gpio, keycode1_gpio;

    //---------------------------------------------------------------------
    //  VGA draw position from controller
    //---------------------------------------------------------------------
    logic [9:0] drawX, drawY;
    logic       hsync, vsync, vde;
    logic [3:0] red, green, blue;

    //---------------------------------------------------------------------
    //  NEW Tetris frame-buffer / active-piece signals
    //---------------------------------------------------------------------
    logic [3:0] board_cells [0:199];   // 20×10 playfield
    logic [2:0] cur_shape;             // I-O-T-S-Z-J-L (0-6)
    logic [4:0] cur_row;               // origin row of 4×4 mask
    logic signed [5:0] cur_col; 
    logic [3:0] cur_clr;               // palette index

    //=====================================================================
    //  HEX display drivers (show low-byte keycode just like before)
    //=====================================================================
    hex_driver HexA (
        .clk   (Clk),
        .reset (reset_ah),
        .in    ({ keycode0_gpio[31:28], keycode0_gpio[27:24],
                  keycode0_gpio[23:20], keycode0_gpio[19:16] }),
        .hex_seg (hex_segA),
        .hex_grid(hex_gridA)
    );

    hex_driver HexB (
        .clk   (Clk),
        .reset (reset_ah),
        .in    ({ keycode0_gpio[15:12], keycode0_gpio[11:8],
                  keycode0_gpio[7:4],   keycode0_gpio[3:0] }),
        .hex_seg (hex_segB),
        .hex_grid(hex_gridB)
    );

    //=====================================================================
    //  MicroBlaze system ("design_1") - UNCHANGED
    //=====================================================================
    design_1 mb_block_i (
        .clk_100MHz        (Clk),
        .reset_rtl_0       (~reset_ah),          // design_1 expects active-low
        .gpio_usb_int_tri_i(gpio_usb_int_tri_i),
        .gpio_usb_rst_tri_o(gpio_usb_rst_tri_o),
        .gpio_usb_keycode_0_tri_o(keycode0_gpio),
        .gpio_usb_keycode_1_tri_o(keycode1_gpio),
        .usb_spi_miso      (usb_spi_miso),
        .usb_spi_mosi      (usb_spi_mosi),
        .usb_spi_sclk      (usb_spi_sclk),
        .usb_spi_ss        (usb_spi_ss),
        .uart_rtl_0_rxd    (uart_rtl_0_rxd),
        .uart_rtl_0_txd    (uart_rtl_0_txd)
    );

    //=====================================================================
    //  Clock wizard: 25?MHz pixel & 125?MHz TMDS ×5
    //=====================================================================
    clk_wiz_0 clk_wiz (
        .clk_in1 (Clk),
        .reset   (reset_ah),
        .clk_out1(clk_25MHz),
        .clk_out2(clk_125MHz),
        .locked  (locked)
    );

    //=====================================================================
    //  VGA timing generator (640×480 @ 60?Hz)
    //=====================================================================
    vga_controller vga (
        .pixel_clk    (clk_25MHz),
        .reset        (reset_ah),
        .hs           (hsync),
        .vs           (vsync),
        .active_nblank(vde),
        .drawX        (drawX),
        .drawY        (drawY)
    );

    //=====================================================================
    //  HDMI encoder (Real-Digital IP)
    //=====================================================================
    hdmi_tx_0 vga_to_hdmi (
        .pix_clk      (clk_25MHz),
        .pix_clkx5    (clk_125MHz),
        .pix_clk_locked(locked),
        .rst          (reset_ah),        // active-HIGH here
        .red          (red),
        .green        (green),
        .blue         (blue),
        .hsync        (hsync),
        .vsync        (vsync),
        .vde          (vde),
        .aux0_din     (4'b0),
        .aux1_din     (4'b0),
        .aux2_din     (4'b0),
        .ade          (1'b0),
        .TMDS_CLK_P   (hdmi_tmds_clk_p),
        .TMDS_CLK_N   (hdmi_tmds_clk_n),
        .TMDS_DATA_P  (hdmi_tmds_data_p),
        .TMDS_DATA_N  (hdmi_tmds_data_n)
    );
    
    logic [1:0] cur_orient;

    //=====================================================================
    //  NEW: 7-tetromino game logic + renderer
    //=====================================================================
    tetris_core game_core (
        .Reset     (reset_ah),
        .vsync     (vsync),                 // 60?Hz pulse
        .keycodes   (keycode0_gpio),    // low byte of keycode
        .board     (board_cells),
        .cur_shape (cur_shape),
        .cur_row   (cur_row),
        .cur_col   (cur_col),
        .cur_clr   (cur_clr),
        .cur_orient (cur_orient)
    );

    tetris_render renderer (
        .DrawX     (drawX),
        .DrawY     (drawY),
        .board     (board_cells),
        .cur_shape (cur_shape),
        .cur_row   (cur_row),
        .cur_col   (cur_col),
        .cur_clr   (cur_clr),
        .cur_orient (cur_orient),
        .Red       (red),
        .Green     (green),
        .Blue      (blue)
    );

endmodule
