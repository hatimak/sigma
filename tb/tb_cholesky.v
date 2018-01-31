`timescale 1ns / 1ps

module tb_cholesky();

    reg            clk, clk_en, rst, A_valid;
    reg  [479 : 0] A;
    wire [479 : 0] L;
    wire           L_valid;

    cholesky uut (
        .clk     (clk),
        .clk_en  (clk_en),
        .rst     (rst),
        .A       (A),
        .A_valid (A_valid),

        .L       (L),
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
        #103;
        A_valid = 1'b0;
        #10000;
        $finish;
    end

    always begin
        #5;
        clk = (clk === 1'b0);
    end

endmodule
