`timescale 1ps / 1ps

module cholesky_tb ();

    reg           clk, rst, enable1_3;
    wire [575:0]  factor1_3;
    reg [575:0]   factor1_3_actual, matrix1_3;
    wire          ready1;

    wire [1023:0] factor2_4;
    reg [1023:0]  factor2_4_actual, matrix2_4;
    wire          ready2;
    reg           enable2_4;

    cholesky #(.SIZE(3)) UUT1_3 (
    .factor  (factor1_3), // Cholesky factor, lower triangular n x n matrix.
    .ready   (ready1),
    .matrix  (matrix1_3), // Symmetric, positive definite n x n matrix.
    .enable  (enable1_3),
    .clk     (clk),
    .rst     (rst)
    );

    cholesky #(.SIZE(4)) UUT2_4 (
    .factor  (factor2_4), // Cholesky factor, lower triangular n x n matrix.
    .ready   (ready2),
    .matrix  (matrix2_4), // Symmetric, positive definite n x n matrix.
    .enable  (enable2_4),
    .clk     (clk),
    .rst     (rst)
    );

    initial begin
        $dumpfile("cholesky.vcd");
        $dumpvars(0, cholesky_tb);
        rst = 1'b1;
        clk = 1'b0;
        enable1_3 = 1'b0;
        enable2_4 = 1'b0;
        #20000;
        rst = 1'b0;
        /* +-              -+   +-            -+  +-            -+
         * |  25   15   -5  |   |   5   0   0  |  |   5   3  -1  |
         * |  15   18    0  | = |   3   3   0  |  |   0   3   1  |
         * |  -5    0   11  |   |  -1   1   3  |  |   0   0   3  |
         * +-              -+   +-            -+  +-            -+
         * symmetric positive   lower triangular  upper triangular
         *      definite             factor            factor
         *
         * +-                   -+     +-                                         -+
         * |  18   22   54   42  |     |  4.24264   0.0        0.0        0.0      |
         * |  22   70   86   62  | =>  |  5.18545   6.56591    0.0        0.0      |
         * |  54   86  174  134  | =>  | 12.72792   3.04604    1.64974    0.0      |
         * |  42   62  134  106  |     |  9.89949   1.62455    1.84971    1.39262  |
         * +-                   -+     +-                                         -+
         *   symmetric positive              lower triangular Cholesky factor
         *       definite
         */
        matrix1_3 = 576'h40260000000000000000000000000000c01400000000000000000000000000004032000000000000402e000000000000c014000000000000402e0000000000004039000000000000;
        factor1_3_actual = 576'h40080000000000003ff0000000000000bff0000000000000000000000000000040080000000000004008000000000000000000000000000000000000000000004014000000000000;
        matrix2_4 = 1024'h405a8000000000004060c00000000000404f00000000000040450000000000004060c000000000004065c000000000004055800000000000404b000000000000404f0000000000004055800000000000405180000000000040360000000000004045000000000000404b00000000000040360000000000004032000000000000;
        factor2_4_actual = 1024'h3ff6482be8bc169c3ffd9869835158b83ff9fe28240b78034023cc89f40a287800000000000000003ffa6555c52e72da40085e4a38327675402974b1ee24356900000000000000000000000000000000401a437de939eadd4014bde69ad42c3d0000000000000000000000000000000000000000000000004010f8769ec2ce46;
        #2000;
        enable1_3 = 1'b1;
        enable2_4 = 1'b1;
        #25000;
        enable1_3 = 1'b0;
        enable2_4 = 1'b0;
        #25000000;
        $display("Cholesky factorisation of 3x3 symmetric positive definite matrix,\n\t+-              -+   +-            -+  +-            -+\n\t|  25   15   -5  |   |   5   0   0  |  |   5   3  -1  |\n\t|  15   18    0  | = |   3   3   0  |  |   0   3   1  |\n\t|  -5    0   11  |   |  -1   1   3  |  |   0   0   3  |\n\t+-              -+   +-            -+  +-            -+\n\tsymmetric positive   lower triangular  upper triangular\n\t     definite             factor            factor");
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

        #15000000;
        $display("Cholesky factorisation of 4x4 symmetric positive definite matrix,\n\t+-                   -+     +-                                         -+\n\t|  18   22   54   42  |     |  4.24264   0.0        0.0        0.0      |\n\t|  22   70   86   62  | =>  |  5.18545   6.56591    0.0        0.0      |\n\t|  54   86  174  134  | =>  | 12.72792   3.04604    1.64974    0.0      |\n\t|  42   62  134  106  |     |  9.89949   1.62455    1.84971    1.39262  |\n\t+-                   -+     +-                                         -+\n\t  symmetric positive              lower triangular Cholesky factor\n\t      definite");
        $display("\t(Actual Cholesky factors shown above, computed lower triangluar factor follows below.)");
        $display("\tResults, lower triangular matrix L (denoted by l_ij, actual values in braces):");

        $display("\t\tl_11 = %h (%h)", factor2_4[63:0], factor2_4_actual[63:0]);
        $display("\t\tl_12 = %h (%h)", factor2_4[127:64], factor2_4_actual[127:64]);
        $display("\t\tl_13 = %h (%h)", factor2_4[191:128], factor2_4_actual[191:128]);
        $display("\t\tl_14 = %h (%h)", factor2_4[255:192], factor2_4_actual[255:192]);
        $display("\t\tl_21 = %h (%h)", factor2_4[319:256], factor2_4_actual[319:256]);
        $display("\t\tl_22 = %h (%h)", factor2_4[383:320], factor2_4_actual[383:320]);
        $display("\t\tl_23 = %h (%h)", factor2_4[447:384], factor2_4_actual[447:384]);
        $display("\t\tl_24 = %h (%h)", factor2_4[511:448], factor2_4_actual[511:448]);
        $display("\t\tl_31 = %h (%h)", factor2_4[575:512], factor2_4_actual[575:512]);
        $display("\t\tl_32 = %h (%h)", factor2_4[639:576], factor2_4_actual[639:576]);
        $display("\t\tl_33 = %h (%h)", factor2_4[703:640], factor2_4_actual[703:640]);
        $display("\t\tl_34 = %h (%h)", factor2_4[767:704], factor2_4_actual[767:704]);
        $display("\t\tl_41 = %h (%h)", factor2_4[831:768], factor2_4_actual[831:768]);
        $display("\t\tl_42 = %h (%h)", factor2_4[895:832], factor2_4_actual[895:832]);
        $display("\t\tl_43 = %h (%h)", factor2_4[959:896], factor2_4_actual[959:896]);
        $display("\t\tl_44 = %h (%h)", factor2_4[1023:960], factor2_4_actual[1023:960]);

        $finish;
    end

    always begin
        #5000;
        clk = ~clk;
    end

endmodule
