`timescale 1ns / 1ps

module tb_inv_lower_2 ();

    reg           clk, clk_en, rst, A_valid;
    reg  [95 : 0] A;
    wire          Z_valid;
    wire [31 : 0] Z_11, Z_21, Z_22;

    inv_lower_2 uut (
        .clk     (clk),
        .clk_en  (clk_en),
        .rst     (rst),
        .S       (A),
        .S_valid (A_valid),

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
        A = 96'h0002_aa0a__0000_1ff2__0001_ff25;
        #20;
        rst = 1'b0;
        #27;
        A_valid = 1'b1;
        #63;
        A_valid = 1'b0;
        #450;
        /* +-              -+
         * | 0.2500  0.0625 |
         * | 0.0625  0.1250 |
         * +-              -+
         */
        A = 96'h0000_2000__0000_1000__0000_4000;
        #44;
        A_valid = 1'b1;
        #93;
        A_valid = 1'b0;
        #500;
        $finish;
    end

    always begin
        #5;
        clk = (clk === 1'b0);
    end

endmodule
