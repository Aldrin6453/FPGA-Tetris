module ball #(
    parameter int NUM = 4,
    parameter [9:0] X_INIT [NUM] = '{160, 320, 480, 640},
    parameter [9:0] Y_INIT [NUM] = '{0, 12, 24, 48},
    parameter int SPEED = 1,
    parameter [9:0] SIZE = 16
)(
    input  logic        Reset,
        input  logic        frame_clk,
    input  logic [7:0]  keycode,
    output logic [9:0]  BallX [NUM],
    output logic [9:0]  BallY [NUM],
    output logic [9:0]  BallS [NUM]
);

    always_ff @(posedge frame_clk or posedge Reset) begin
    if (Reset) begin
        for (int i = 0; i < NUM; i++) begin
            BallX[i] <= X_INIT[i];
            BallY[i] <= Y_INIT[i];
            BallS[i] <= SIZE;
        end
    end else begin
        for (int i = 0; i < NUM; i++) begin
            // compute next Y
            logic [10:0] nextY = BallY[i] + SPEED;

            // clamp at 460
            if (nextY[9:0] > 460)
                BallY[i] <= 10'd460;
            else
                BallY[i] <= nextY[9:0];

            // X unchanged
            BallX[i] <= BallX[i];

            // size stays constant
            BallS[i] <= SIZE;
        end
    end
end
endmodule
