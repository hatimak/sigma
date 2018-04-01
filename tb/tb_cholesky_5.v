`timescale 1ns / 1ps

module tb_cholesky_5 ();

    reg           clk, clk_en, rst, A_valid;
    reg [479 : 0] A;
    wire          L_valid;
    wire [31 : 0] L_11, L_21, L_22, L_31, L_32, L_33, L_41, L_42, L_43, L_44, L_51, L_52, L_53, L_54, L_55;

    cholesky_5 uut (
        .clk     (clk),
        .clk_en  (clk_en),
        .rst     (rst),
        .A       (A),
        .A_valid (A_valid),

        .L       ({L_55, L_54, L_53, L_52, L_51, L_44, L_43, L_42, L_41, L_33, L_32, L_31, L_22, L_21, L_11}),
        .L_valid (L_valid)
    );

    initial begin
        #200; // Global Set/Reset (GSR) is in effect for the first 100ns so apply stimulus afterwards
        clk = 1'b0;
        clk_en = 1'b1;
        rst = 1'b1;
        A_valid = 1'b0;
        A = 480'h000a00000000000000140000000700000002000000c80000001e00000006000000000000006400000000000000120000003200000009000000190000;
        #20;
        rst = 1'b0;
        #27;
        A_valid = 1'b1;
        #203;
        A_valid = 1'b0;
        #5004;
        A_valid = 1'b1;
        #99;
        A_valid = 1'b0;
        #10000;
        $finish;
    end

    always begin
        #5;
        clk = (clk === 1'b0);
    end

endmodule
