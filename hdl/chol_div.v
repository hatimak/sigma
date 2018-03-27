`timescale 1ns / 1ps

module chol_div (
    input wire           clk,
    input wire           clken,
    input wire           rst,
    input wire           divisor_valid,
    input wire  [31 : 0] divisor,
    input wire           dividend_valid,
    input wire  [31 : 0] dividend,

    output wire [31 : 0] out
    );

    wire [31 : 0] out_tt;
    wire [55 : 0] out_t;

    cholesky_ip_div div_4 (
        .aclk                   (clk),
        .aclken                 (clken),
        .aresetn                (~rst),
        .s_axis_divisor_tvalid  (divisor_valid),
        .s_axis_divisor_tdata   (divisor),
        .s_axis_dividend_tvalid (dividend_valid),
        .s_axis_dividend_tdata  (dividend),
        .m_axis_dout_tvalid     (),  // Not connected, since latency is known beforehand, we know when to sample
        .m_axis_dout_tdata      (out_t)
    );
    cholesky_ip_sub_const div_sub_4 (
        .A   (out_t[48 : 17]),
        .CLK (clk),
        .CE  (clken),
        .S   (out_tt)
    );
    assign out = (out_t[16]) ? {out_tt[15 : 0], out_t[15 : 0]} : {out_t[32 : 17], out_t[15 : 0]};

endmodule
