`timescale 1ns / 1ps

module chol_sqrt (
    input wire           clk,
    input wire           clken,
    input wire           rst,
    input wire           data_valid,
    input wire  [31 : 0] data,
    output wire [31 : 0] out
    );

    wire [23 : 0] out_t;

    cholesky_ip_sqrt sqrt_0 (
        .aclk                    (clk),
        .aclken                  (clken),
        .aresetn                 (~rst),
        .s_axis_cartesian_tvalid (data_valid),
        .s_axis_cartesian_tdata  (data),
        .m_axis_dout_tvalid      (), // Not connected, since latency is known beforehand, we know when to sample
        .m_axis_dout_tdata       (out_t)
    );
    assign out = { {8{1'b0}}, out_t };

endmodule
