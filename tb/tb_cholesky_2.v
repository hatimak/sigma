`timescale 1ns / 1ps

module tb_cholesky_2 ();

    reg           clk, clk_en, rst, A_valid;
    reg  [95 : 0] A;
    wire          L_valid;
    wire [31 : 0] L_11, L_21, L_22;

    cholesky_2 uut (
        .clk     (clk),
        .clk_en  (clk_en),
        .rst     (rst),
        .A       (A),
        .A_valid (A_valid),

        .L       ({L_22, L_21, L_11}),
        .L_valid (L_valid)
    );

    initial begin
        #200; // Global Set/Reset (GSR) is in effect for the first 100ns so apply stimulus afterwards
        clk = 1'b0;
        clk_en = 1'b1;
        rst = 1'b1;
        A_valid = 1'b0;
        A = 96'h0032_0000__0009_0000__0019_0000;
        #20;
        rst = 1'b0;
        #27;
        A_valid = 1'b1;
        #203;
        A_valid = 1'b0;
        #2004;
        A_valid = 1'b1;
        #99;
        A_valid = 1'b0;
        #5000;
        $finish;
    end

    always begin
        #5;
        clk = (clk === 1'b0);
    end

endmodule
