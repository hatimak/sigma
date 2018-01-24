`timescale 1ns / 1ps

module pe_meas_proc (
    input wire           clk,
    input wire           en_clk,
    input wire [159 : 0] state, // State vector
    input wire           state_valid,

    output wire [63 : 0] meas, // Measurement vector holding range and bearing
    output wire          meas_valid
    );

    wire [23 : 0] bearing_out; // Only 19 LSB bits hold the actual output
    wire [31 : 0] xi, eta, range_out;
    wire [47 : 0] xi_sq, eta_sq, range_sq;
    reg   [1 : 0] en_clk_del, state_valid_del;

    assign xi  = state[159 : 128];
    assign eta = state[95 : 64];

    // xi ^ 2
    pe_meas_ip_square range_1 (
        .A (xi),
        .B (xi),
        .P (xi_sq)
        );

    // eta ^ 2
    pe_meas_ip_square range_2 (
        .A (eta),
        .B (eta),
        .P (eta_sq)
        );

    // xi ^ 2 + eta ^ 2
    pe_meas_ip_add_long range_3 (
        .A (xi_sq),
        .B (eta_sq),
        .S (range_sq)
        );

    // Delay en_clk and state_valid signals by a cycle to allow for previous adder/multiplier outputs to settle
    always @(posedge clk) begin
        en_clk_del      <= {en_clk_del[0], en_clk};
        state_valid_del <= {state_valid_del[0], state_valid};
    end

    // sqrt(xi ^ 2 + eta ^ 2)
    pe_meas_ip_sqrt range (
        .aclk                    (clk),
        .aclken                  (en_clk_del[1]),
        .s_axis_cartesian_tvalid (state_valid_del[1]),
        .s_axis_cartesian_tdata  (range_sq[46 : 0]),
        .m_axis_dout_tvalid      (), // Not connected, pe_meas_ip_sqrt is pipelined and has a latency of 17 cycles
        .m_axis_dout_tdata       (range_out)
        );

    pe_meas_ip_arctan bearing (
        .aclk                    (clk),
        .aclken                  (en_clk_del[1]),
        .s_axis_cartesian_tvalid (state_valid_del[1]),
        .s_axis_cartesian_tdata  ({ eta, xi }),
        .m_axis_dout_tvalid      (), // Not connected, pe_meas_ip_arctan is pipelined and has a latency of 22 cycles
        .m_axis_dout_tdata       (bearing_out)
        );

    pe_meas_ip_shift_ram shift_range (
        .D   (range_out),      // input wire [31 : 0] D
        .CLK (clk),  // input wire CLK
        .CE  (en_clk_del[1]),    // input wire CE
        .Q   (meas[63 : 32])      // output wire [31 : 0] Q
        );
    // If bearing_out is negative, then add leading 1's, else add leading 0's.
    assign meas[31 : 0]  = (bearing_out[18]) ? { {13{1'b1}}, bearing_out[18 : 0] } : { {13{1'b0}}, bearing_out[18 : 0] };

    pe_meas_ip_shift_valid shift_valid (
        .D   (state_valid),
        .CLK (clk),
        .CE  (en_clk_del[1]),
        .Q   (meas_valid)
        );

endmodule
