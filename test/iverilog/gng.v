`timescale 1ns / 1ps


module gng_tb ();

    reg clk, rstn, ce;
    wire [15:0] data_out;
    wire        valid_out;

    reg flag;

    gng #(
        .INIT_Z1(64'd5030521853213464767),
        .INIT_Z2(64'd18445829279764255008),
        .INIT_Z3(64'd18436106598722573559)
    ) uut (
        // System signals
        .clk       (clk),        // system clock
        .rstn      (rstn),       // system synchronous reset, active low
    
        // Data interface
        .ce        (ce),         // clock enable
        .valid_out (valid_out),  // output data valid
        .data_out  (data_out)    // output data, s<16,11>
    );

    initial begin
        $dumpfile("gng.vcd");
        $dumpvars(0, gng_tb);
        rstn = 1'b0;
        ce = 1'b0;
        clk = 1'b0;
        flag = 1'b0;
        #20;
        rstn = 1'b1;
        #10;
        ce = 1'b1;
        #120; // Wait for at least 11 clock cycles before valid_out is raised and samples are available.

        flag = 1'b1;
        #100000000;
        $finish;
    end

    always @(posedge clk) begin
        if (flag) begin
            $display("%h\n", data_out);
        end
    end

    always begin
        #5;
        clk = (clk === 1'b0);
    end

endmodule

