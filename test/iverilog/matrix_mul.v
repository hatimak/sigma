`timescale 1ps / 1ps

module matrix_mul_tb ();

    reg [255:0]  mat1_a, mat1_b;
    wire [255:0] mat1_prod;
    reg [255:0]  actual_mat1_prod;
    reg          rst, clk, enable1;
    wire         ready1;

    matrix_mul #(.SIZE(2)) UUT_1(
        .prod   (mat1_prod),
        .ready  (ready1),
        .op_a   (mat1_a),
        .op_b   (mat1_b),
        .enable (enable1),
        .clk    (clk),
        .rst    (rst)
        );

    initial begin
        $dumpfile("matrix_mul.vcd");
        $dumpvars(0, matrix_mul_tb);
        rst = 1'b1;
        clk = 1'b0;
        enable1 = 1'b0;
        #20000;
        rst = 1'b0;
        /* +-                        -+   +-                      -+   +-                           -+
         * |  1.234726e+5  -9.0356e+2 |   | -3.41284e+2   2.173e+3 |   | -4.213923e+7   2.683383e+8  |
         * |                          | * |                        | = |                             |
         * | -1.050053e-9  -4.0601e+1 |   |  1.10004e-2  -3.578e+1 |   | -4.466269e-1   1.452704e+3  |
         * +-                        -+   +-                      -+   +-                           -+
         */
        mat1_a = 256'hc0444ced916872b0be120a2e932b52e1c08c3c7ae147ae1440fe25099999999a;
        mat1_b = 256'hc041e3d70a3d70a43f868760b1f17f3440a0fa0000000000c075548b43958106;
        actual_mat1_prod = 256'h4096b2d0ab1b2de4bfdc9588eaf659ff41affd08e25a8588c18417f30610391c;
        #5000;
        enable1 = 1'b1;
        #15000;
        enable1 = 1'b0;
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
        $finish;
    end

    always begin
        #5000;
        clk = ~clk;
    end

endmodule
