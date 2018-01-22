`timescale 1ns / 1ps

module tb_pe_time_proc();

    reg            clk, en_clk, x_curr_valid;
    reg [159 : 0]  x_curr;
    wire [159 : 0] x_next;
    wire           x_next_valid;

    pe_time_proc uut (
        .clk          (clk),
        .en_clk       (en_clk),
        .x_curr       (x_curr),
        .x_curr_valid (x_curr_valid),
        .x_next       (x_next),
        .x_next_valid (x_next_valid)
        );


    initial begin
        clk = 1'b0;
        x_curr_valid = 1'b0;
        en_clk = 1'b1;
        #25;
        x_curr = 160'h03e8_0000__012c_0000__03e8_0000__0000_0000__ffff_f1fe;
        x_curr_valid = 1'b1;
        #30;
        x_curr = 160'h07cf_4000__0257_4000__07d0_4000__0001_8000__ffff_f000;
        #10;
        x_curr = 160'h07cf_4000__012c_4000__03e8_0000__0001_4000__ffff_f100;
        #60;
        x_curr_valid = 1'b0;

        #300;
        $display("%b\n%b\n%b\n%b\n%b\n", x_next[159 : 128], x_next[127 : 96], x_next[95 : 64], x_next[63 : 32], x_next[31 : 0]);
        $finish;
    end

    always begin
        #5;
        clk = (clk === 1'b0);
    end

endmodule
