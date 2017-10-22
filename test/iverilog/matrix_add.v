`timescale 1ps / 1ps

module matrix_add_tb ();

    reg [255:0]  mat_a, mat_b;
    wire [255:0] mat_sum;
    reg          rst, clk, enable;
    wire         ready;

    matrix_add #(.SIZE(2)) UUT(
        .sum    (mat_sum),
        .ready  (ready),
        .op_a   (mat_a),
        .op_b   (mat_b),
        .enable (enable),
        .clk    (clk),
        .rst    (rst)
        );

    initial begin
        $dumpfile("matrix_add.vcd");
        $dumpvars(0, matrix_add_tb);
        rst = 1'b1;
        clk = 1'b0;
        enable = 1'b0;
        #20000;
        rst = 1'b0;
        /* +-                                      -+   +-                                      -+   +-                                               -+
         * |  3.4500000000e+002  -9.0300000000e+002 |   | -3.4400000000e+002   2.1000000000e+001 |   | 3.422700000000000e+001  -8.820000000000000e+002 |
         * |                                        | + |                                        | = |                                                 |
         * | -1.0000000000e-309  -4.0600000000e+001 |   |  1.1000000000e-309  -3.5700000000e+001 |   | 9.999999999999969e-311  -7.630000000000001e+001 |
         * +-                                      -+   +-                                      -+   +-                                               -+
         */
        mat_a = 256'b1100000001000100010011001100110011001100110011001100110011001101_1000000000000000101110000001010101110010011010001111110110101110_1100000010001100001110000000000000000000000000000000000000000000_0100000001110101100100000000000000000000000000000000000000000000;
        mat_b = 256'b1100000001000001110110011001100110011001100110011001100110011010_0000000000000000110010100111110111111101110110011110001111011001_0100000000110101000000000000000000000000000000000000000000000000_1100000001110101100000000000000000000000000000000000000000000000;
        #1000;
        enable = 1'b1;
        #10000;
        enable = 1'b0;
        #500000;
        if (mat_sum[63:0] == 64'h3FF0000000000000) begin
            $display($time,"ps: Pass! a_11 + b_11 = c_11 (%h)", mat_sum[63:0]);
        end else begin
            $display($time,"ps: Error! a_11 + b_11 != c_11 (%h)", mat_sum[63:0]);
        end
        if (mat_sum[127:64] == 64'hC08B900000000000) begin
            $display($time,"ps: Pass! a_12 + b_12 = c_12 (%h)", mat_sum[127:64]);
        end else begin
            $display($time,"ps: Error! a_12 + b_12 != c_12 (%h)", mat_sum[127:64]);
        end
        if (mat_sum[191:128] == 64'h000012688B70E62B) begin
            $display($time,"ps: Pass! a_21 + b_21 = c_21 (%h)", mat_sum[191:128]);
        end else begin
            $display($time,"ps: Error! a_21 + b_21 != c_21 (%h)", mat_sum[191:128]);
        end
        if (mat_sum[255:192] == 64'hC053133333333334) begin
            $display($time,"ps: Pass! a_22 + b_22 = c_22 (%h)", mat_sum[255:192]);
        end else begin
            $display($time,"ps: Error! a_22 + b_22 != c_22 (%h)", mat_sum[255:192]);
        end
        $finish;
    end

    always begin
        #5000;
        clk = ~clk;
    end

endmodule
