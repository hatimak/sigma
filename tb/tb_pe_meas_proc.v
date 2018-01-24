`timescale 1ns / 1ps

module tb_pe_meas_proc ();

    reg           clk;
    reg           en_clk;
    reg [159 : 0] state;
    reg           state_valid;
    wire          meas_valid;
    wire [63 : 0] meas;

    pe_meas_proc uut (
        .clk         (clk),
        .en_clk      (en_clk),
        .state       (state),
        .state_valid (state_valid),

        .meas        (meas),
        .meas_valid  (meas_valid)
        );

    always begin
        #5;
        clk = (clk === 1'b0);
    end

    initial begin
        clk = 1'b0;
        en_clk = 1'b1;
        state_valid = 1'b0;
        #10;
        state = 160'h03e8_0000__012c_0000__03e8_0000__0000_0000__ffff_f1fe;
        #10;
        state_valid = 1'b1;
        #30;
        state = 160'h07cf_4000__0257_4000__07d0_4000__0001_8000__ffff_f000;
        #10;
        state = 160'h03e8_0000__012c_0000__03e8_0000__0000_0000__ffff_f000;
        #40;
        state_valid = 1'b0;
        #20;

        #500;
        $display("range   = 0x%x\nbearing = 0x%x\n", meas[63 : 32], meas[31 : 0]);
        $finish;
    end

endmodule
