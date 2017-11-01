`timescale 1ps / 1ps

module cholesky_tb ();

    reg          clk, rst, enable1_3;
    wire [575:0] factor1_3;
    reg [575:0]  factor1_3_actual;
    wire         ready1;
    reg [575:0]  matrix1_3;

    cholesky #(.SIZE(3)) UUT1_3 (
    .factor  (factor1_3), // Cholesky factor, lower triangular n x n matrix.
    .ready   (ready1),
    .matrix  (matrix1_3), // Symmetric, positive definite n x n matrix.
    .enable  (enable1_3),
    .clk     (clk),
    .rst     (rst)
    );

    initial begin
        $dumpfile("cholesky.vcd");
        $dumpvars(0, cholesky_tb);
        rst = 1'b1;
        clk = 1'b0;
        enable1_3 = 1'b0;
        #20000;
        rst = 1'b0;
        /* +-              -+   +-            -+  +-            -+
         * |  25   15   -5  |   |   5   0   0  |  |   5   3  -1  |
         * |  15   18    0  | = |   3   3   0  |  |   0   3   1  |
         * |  -5    0   11  |   |  -1   1   3  |  |   0   0   3  |
         * +-              -+   +-            -+  +-            -+
         * symmetric positive   lower triangular  upper triangular
         *      definite             factor            factor
         */
        matrix1_3 = 576'h40260000000000000000000000000000c01400000000000000000000000000004032000000000000402e000000000000c014000000000000402e0000000000004039000000000000;
        factor1_3_actual = 576'h40080000000000003ff0000000000000bff0000000000000000000000000000040080000000000004008000000000000000000000000000000000000000000004014000000000000;
        #2000;
        enable1_3 = 1'b1;
        #25000;
        enable1_3 = 1'b0;
        #23000000;
        $display("Cholesky factorisation of 3x3 symmetric positive definite matrix A,\n\t+-              -+   +-            -+  +-            -+\n\t|  25   15   -5  |   |   5   0   0  |  |   5   3  -1  |\n\t|  15   18    0  | = |   3   3   0  |  |   0   3   1  |\n\t|  -5    0   11  |   |  -1   1   3  |  |   0   0   3  |\n\t+-              -+   +-            -+  +-            -+\n\tsymmetric positive   lower triangular  upper triangular\n\t     definite             factor            factor");
        $display("\t(Actual Cholesky factors shown above, computed lower triangluar factor follows below.)");
        $display("\tResults, lower triangular matrix L (denoted by l_ij, actual values in braces):");

        $display("\t\tl_11 = %h (%h)", factor1_3[63:0], factor1_3_actual[63:0]);
        $display("\t\tl_12 = %h (%h)", factor1_3[127:64], factor1_3_actual[127:64]);
        $display("\t\tl_13 = %h (%h)", factor1_3[191:128], factor1_3_actual[191:128]);
        $display("\t\tl_21 = %h (%h)", factor1_3[255:192], factor1_3_actual[255:192]);
        $display("\t\tl_22 = %h (%h)", factor1_3[319:256], factor1_3_actual[319:256]);
        $display("\t\tl_23 = %h (%h)", factor1_3[383:320], factor1_3_actual[383:320]);
        $display("\t\tl_31 = %h (%h)", factor1_3[447:384], factor1_3_actual[447:384]);
        $display("\t\tl_32 = %h (%h)", factor1_3[511:448], factor1_3_actual[511:448]);
        $display("\t\tl_33 = %h (%h)", factor1_3[575:512], factor1_3_actual[575:512]);

        $finish;
    end

    always begin
        #5000;
        clk = ~clk;
    end

endmodule
