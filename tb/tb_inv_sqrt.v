`timescale 1ns / 1ps

module tb_inv_sqrt ();

    reg           clk, clken, rst, data_valid;
    reg  [31 : 0] data;
    wire          out_valid;
    wire [31 : 0] out;

    chol_inv_sqrt uut (
        .clk        (clk),
        .clken      (clken),
        .rst        (rst),
        .data_valid (data_valid),
        .data       (data),
        .out        (out),
        .out_valid  (out_valid)
    );

    initial begin
        #200; // Global Set/Reset (GSR) is in effect for the first 100ns so apply stimulus afterwards
        clk = 1'b0;
        clken = 1'b1;
        rst = 1'b1;
        data_valid = 1'b0;
        data = 32'h0002_0000; // 2.0
        #30;
        rst = 1'b0;
        #57;
        data_valid = 1'b1;
        #43;
        data_valid = 1'b0;
        #1000;
        data = 32'h00c1_3f9c; // 193.2484741210938
        #18;
        data_valid = 1'b1;
        #26;
        data_valid = 1'b0;
        #2000;
        $finish;
    end

    always begin
        #5;
        clk = (clk === 1'b0);
    end

endmodule
