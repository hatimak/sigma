`timescale 1ns / 1ps

module tb_inv_2 ();

    reg           clk, clk_en, rst, A_valid;
    reg  [95 : 0] A;
    wire          Z_valid;
    wire [31 : 0] Z_11, Z_21, Z_22;

    inv_2 uut (
        .clk     (clk),
        .clk_en  (clk_en),
        .rst     (rst),
        .A       (A),
        .A_valid (A_valid),

        .Z       ({Z_22, Z_21, Z_11}),
        .Z_valid (Z_valid)
    );

    initial begin
        #200; // Global Set/Reset (GSR) is in effect for the first 100ns so apply stimulus afterwards
        clk = 1'b0;
        clk_en = 1'b1;
        rst = 1'b1;
        A_valid = 1'b0;
        /* +-         -+
         * | 1000  250 |
         * |  250  750 |
         * +-         -+
         */
        A = 96'h02ee_0000__00fa_0000__03e8_0000;
        #20;
        rst = 1'b0;
        #27;
        A_valid = 1'b1;
        #203;
        A_valid = 1'b0;
        #5000;
        $finish;
    end

    always begin
        #5;
        clk = (clk === 1'b0);
    end

endmodule
