`timescale 1ps / 1ps

module matrix_mul_tb ();

    reg [255:0]  mat1_a, mat1_b, actual_mat1_prod;
    wire [255:0] mat1_prod;
    reg [575:0]  mat2_a, mat2_b, actual_mat2_prod;
    wire [575:0] mat2_prod;
    reg          rst, clk, enable;
    wire         ready1, ready2;

    matrix_mul #(.SIZE(2)) UUT_1(
        .prod   (mat1_prod),
        .ready  (ready1),
        .op_a   (mat1_a),
        .op_b   (mat1_b),
        .enable (enable),
        .clk    (clk),
        .rst    (rst)
        );

    matrix_mul #(.SIZE(3)) UUT_2(
        .prod   (mat2_prod),
        .ready  (ready2),
        .op_a   (mat2_a),
        .op_b   (mat2_b),
        .enable (enable),
        .clk    (clk),
        .rst    (rst)
        );

    initial begin
        $dumpfile("matrix_mul.vcd");
        $dumpvars(0, matrix_mul_tb);
        rst = 1'b1;
        clk = 1'b0;
        enable = 1'b0;
        #20000;
        rst = 1'b0;
        /* +-                        -+   +-                      -+   +-                           -+
         * |  1.234726e+5  -9.0356e+2 |   | -3.41284e+2   2.173e+3 |   | -4.213923e+7   2.683383e+8  |
         * |                          | x |                        | = |                             |
         * | -1.050053e-9  -4.0601e+1 |   |  1.10004e-2  -3.578e+1 |   | -4.466269e-1   1.452704e+3  |
         * +-                        -+   +-                      -+   +-                           -+
         */
        mat1_a = 256'hc0444ced916872b0be120a2e932b52e1c08c3c7ae147ae1440fe25099999999a;
        mat1_b = 256'hc041e3d70a3d70a43f868760b1f17f3440a0fa0000000000c075548b43958106;
        actual_mat1_prod = 256'h4096b2d0ab1b2de4bfdc9588eaf659ff41affd08e25a8588c18417f30610391c;

        /* +-                                             -+   +-                                            -+   +-                                            -+
         * |  3.221347e+51   -5.023256e+20   -7.234120e-12 |   | -3.412840e-22    2.172001e+30   4.234672e+34 |   | -1.099394e+30   6.996768e+81   1.364135e+086 |
         * |  1.033450e-94   -4.060100e+10   -3.258239e+83 | x |  1.100420e-22   -3.572380e+17   1.033450e-94 | = | -7.896972e+41   2.010985e+89  -3.454787e+105 |
         * |  2.423693e-42   -7.234120e-16    4.060123e+32 |   |  2.423693e-42   -6.172001e+05   1.060323e+22 |   |  9.840493e-10  -2.505908e+38   4.305043e+054 |
         * +-                                             -+   +-                                            -+   +-                                            -+
         */
        mat2_a = 576'h46b404987f049fd2bcca104c4a82707f374b066befadb0aed14577d70f519dd1c222e804308000002c6b97cbef2539e9bd9fd0e520f43a53c43b3b2b07c3d0f64aa138453dfbd246;
        mat2_b = 576'h4481f66b43742401c122d5e01b22d0e5374b066befadb0ae2c6b97cbef2539e9c393d4a845e915803b60a10b941cd87147204fb5935d81bc463b6a1cba97488abb79c9648372c334;
        actual_mat2_prod = 576'h4b46792ee2b62f48c7e790c11f4a64113e10e7e50d109ac2d5d819f6f6c21eb1527945ca02638863c8a2216c56c26c5451d18e0e7f06c9b150ed81288e9db9b0c62bc0ab43dd2163;
        #5000;
        enable = 1'b1;
        #15000;
        enable = 1'b0;
        #3000000;
        $display("[a]_{2x2} x [b]_{2x2} = [c]_{2x2}");
        if (mat1_prod[63:0] == actual_mat1_prod[63:0]) begin
            $display($time,"ps: Pass! a_11.b_11 + a_12.b_21 = c_11 (%h)", mat1_prod[63:0]);
        end else begin
            $display($time,"ps: Error! a_11.b_11 + a_12.b_21 != c_11 (%h)", mat1_prod[63:0]);
        end
        if (mat1_prod[127:64] == actual_mat1_prod[127:64]) begin
            $display($time,"ps: Pass! a_11.b_12 + a_12.b_22 = c_12 (%h)", mat1_prod[127:64]);
        end else begin
            $display($time,"ps: Error! a_11.b_12 + a_12.b_22 != c_12 (%h)", mat1_prod[127:64]);
        end
        if (mat1_prod[191:128] == actual_mat1_prod[191:128]) begin
            $display($time,"ps: Pass! a_21.b_11 + a_22.b_21 = c_21 (%h)", mat1_prod[191:128]);
        end else begin
            $display($time,"ps: Error! a_21.b_11 + a_22.b_21 != c_21 (%h)", mat1_prod[191:128]);
        end
        if (mat1_prod[255:192] == actual_mat1_prod[255:192]) begin
            $display($time,"ps: Pass! a_21.b_12 + a_22.b_22 = c_22 (%h)", mat1_prod[255:192]);
        end else begin
            $display($time,"ps: Error! a_21.b_12 + a_22.b_22 != c_22 (%h)", mat1_prod[255:192]);
        end
        $display("");
        #6000000;
        $display("[e]_{3x3} x [f]_{3x3} = [g]_{3x3}");
        if (mat2_prod[63:0] == actual_mat2_prod[63:0]) begin
            $display($time,"ps: Pass! e_11.f_11 + e_12.f_21 + e_13.f_31 = g_11 (%h)", mat2_prod[63:0]);
        end else begin
            $display($time,"ps: Error! e_11.f_11 + e_12.f_21 + e_13.f_31 != g_11 (%h)", mat2_prod[63:0]);
        end
        if (mat2_prod[127:64] == actual_mat2_prod[127:64]) begin
            $display($time,"ps: Pass! e_11.f_12 + e_12.f_22 + e_13.f_32 = g_12 (%h)", mat2_prod[127:64]);
        end else begin
            $display($time,"ps: Error! e_11.f_12 + e_12.f_22 + e_13.f_32 != g_12 (%h)", mat2_prod[127:64]);
        end
        if (mat2_prod[191:128] == actual_mat2_prod[191:128]) begin
            $display($time,"ps: Pass! e_11.f_13 + e_12.f_23 + e_13.f_33 = g_13 (%h)", mat2_prod[127:64]);
        end else begin
            $display($time,"ps: Error! e_11.f_13 + e_12.f_23 + e_13.f_33 != g_13 (%h)", mat2_prod[127:64]);
        end
        if (mat2_prod[255:192] == actual_mat2_prod[255:192]) begin
            $display($time,"ps: Pass! e_21.f_11 + e_22.f_21 + e_23.f_31 = g_21 (%h)", mat2_prod[63:0]);
        end else begin
            $display($time,"ps: Error! e_21.f_11 + e_22.f_21 + e_23.f_31 != g_21 (%h)", mat2_prod[63:0]);
        end
        if (mat2_prod[319:256] == actual_mat2_prod[319:256]) begin
            $display($time,"ps: Pass! e_21.f_12 + e_22.f_22 + e_23.f_32 = g_22 (%h)", mat2_prod[127:64]);
        end else begin
            $display($time,"ps: Error! e_21.f_12 + e_22.f_22 + e_23.f_32 != g_22 (%h)", mat2_prod[127:64]);
        end
        if (mat2_prod[383:320] == actual_mat2_prod[383:320]) begin
            $display($time,"ps: Pass! e_21.f_13 + e_22.f_23 + e_23.f_33 = g_23 (%h)", mat2_prod[127:64]);
        end else begin
            $display($time,"ps: Error! e_21.f_13 + e_22.f_23 + e_23.f_33 != g_23 (%h)", mat2_prod[127:64]);
        end
        if (mat2_prod[447:384] == actual_mat2_prod[447:384]) begin
            $display($time,"ps: Pass! e_31.f_11 + e_32.f_21 + e_33.f_31 = g_31 (%h)", mat2_prod[63:0]);
        end else begin
            $display($time,"ps: Error! e_31.f_11 + e_32.f_21 + e_33.f_31 != g_31 (%h)", mat2_prod[63:0]);
        end
        if (mat2_prod[511:448] == actual_mat2_prod[511:448]) begin
            $display($time,"ps: Pass! e_31.f_12 + e_32.f_22 + e_33.f_32 = g_32 (%h)", mat2_prod[127:64]);
        end else begin
            $display($time,"ps: Error! e_31.f_12 + e_32.f_22 + e_33.f_32 != g_32 (%h)", mat2_prod[127:64]);
        end
        if (mat2_prod[575:512] == actual_mat2_prod[575:512]) begin
            $display($time,"ps: Pass! e_31.f_13 + e_32.f_23 + e_33.f_33 = g_33 (%h)", mat2_prod[127:64]);
        end else begin
            $display($time,"ps: Error! e_31.f_13 + e_32.f_23 + e_33.f_33 != g_33 (%h)", mat2_prod[127:64]);
        end
        $finish;
    end

    always begin
        #5000;
        clk = ~clk;
    end

endmodule
