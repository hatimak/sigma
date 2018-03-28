`timescale 1ns / 1ps

module chol_mac (
    input wire           clk,
    input wire           clken,
    input wire           rst,
    input wire  [31 : 0] a,
    input wire  [31 : 0] b,
    input wire  [63 : 0] c,
    output wire [63 : 0] out
    );

    pe_matrix_ip_mac mac_0 (
        .CLK      (clk),
        .SCLR     (rst),
        .CE       (clken),
        .A        (a),
        .B        (b),
        .C        (c),
        .SUBTRACT (1'b1), // Subtract, i.e., P = C - A * B (refer Xilinx LogiCORE datasheet)
        .P        (out),
        .PCOUT    () // Not connected since pe_matrix_ip_mac spans multiple DSP slices
    );

endmodule
