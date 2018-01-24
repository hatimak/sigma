`timescale 1ns / 1ps

/* +-                                                            -+ +-       -+
 * | 1 sin(w * T) / w           0   -(1 / w - cos(w * T) / w)   0 | | xi      |
 * | 0 cos(w * T)               0   -sin(w * T)                 0 | | xi_dot  |
 * | 0 1 / w - cos(w * T) / w   1   sin(w * T) / w              0 | | eta     |
 * | 0 sin(w * T)               0   cos(w * T)                  0 | | eta_dot |
 * | 0 0                        0   0                           1 | | w       |
 * +-                                                            -+ +-       -+
 *
 * TODO: Assuming T = 1 sec for now, must generalise.
 */

module pe_time_proc (
    input wire           clk,
    input wire           en_clk,
    input wire [159 : 0] x_curr, // Current state vector
    input wire           x_curr_valid,

    output reg [159 : 0] x_next, // Next state vector
    output reg           x_next_valid
    );

    wire           trig_out_valid, phase_div_out_valid;
    wire  [31 : 0] phase_div_sub_out, sine_mult_phase_inv_out, cosine_mult_phase_inv_out, 
                   x4_1_out, x4_2_out, x3_1_1_out, x3_1_out, x3_3_out, x3_2_out, x2_1_out, 
                   x2_2_out, x1_1_out, x1_2_out, x1_3_out, sine, cosine,
                   phase_inv, // Holds inverse of omega (w)
                   x_xi, x_xi_dot, x_eta, x_eta_dot, x_w;
    wire  [47 : 0] trig_out;
    wire  [55 : 0] phase_div_out;
    wire [159 : 0] x_next_t;

    assign x_xi      = x_curr[159 : 128];
    assign x_xi_dot  = x_curr[127 : 96];
    assign x_eta     = x_curr[95 : 64];
    assign x_eta_dot = x_curr[63 : 32];
    assign x_w       = x_curr[31 : 0];

    // CORDIC IP to compute sine and cosine of omega (w).
    pe_time_ip_trig trig (
        .aclk                (clk),
        .aclken              (en_clk),
        .s_axis_phase_tvalid (x_curr_valid),
        .s_axis_phase_tdata  ({ {5{1'b0}}, x_w[18 : 0] }),
        .m_axis_dout_tvalid  (trig_out_valid),
        .m_axis_dout_tdata   (trig_out)
        );

    // If cosine/sine is negative, then extend with 1's, else extend with 0's.
    assign cosine = (trig_out[17]) ? { {14{1'b1}}, trig_out[17 : 0] }  : { {14{1'b0}}, trig_out[17 : 0] };
    assign sine   = (trig_out[17]) ? { {14{1'b1}}, trig_out[41 : 24] } : { {14{1'b0}}, trig_out[41 : 24] };

    // Divider Generator IP using Radix2 algorithm to compute inverse of omega (w).
    pe_time_ip_div phase_div (
        .aclk                   (clk),
        .s_axis_divisor_tvalid  (x_curr_valid),
        .s_axis_divisor_tdata   (x_w),
        .s_axis_dividend_tvalid (1'b1), // Always valid since dividend is fixed
        .s_axis_dividend_tdata  (32'h00_01__00_00), // Tie dividend to 1.0
        .m_axis_dout_tvalid     (), // Not connected
        .m_axis_dout_tdata      (phase_div_out)
        );

    /* Since Divider Generator IP uses Radix2 algorithm and outputs both quotient 
     * and remainder signed, so adjust output to match our number representation.
     */
    pe_time_ip_sub_const phase_div_sub (
        .A (phase_div_out[48 : 17]),
        .S (phase_div_sub_out)
        );

    assign phase_inv = (phase_div_out[16]) ? {phase_div_sub_out[15 : 0], phase_div_out[15 : 0]} : {phase_div_out[32 : 17], phase_div_out[15 : 0]};

// ================================================================================
    // Purely combinational from henceforth ...

    pe_time_ip_mult_dsp sine_mult_phase_inv (
        .A (sine),
        .B (phase_inv),
        .P (sine_mult_phase_inv_out)
        );

    pe_time_ip_mult_dsp cosine_mult_phase_inv (
        .A (cosine),
        .B (phase_inv),
        .P (cosine_mult_phase_inv_out)
        );

// --------------------------------------------------------------------------------
    // cos(w * T) * xi_dot
    pe_time_ip_mult_dsp x2_1 (
        .A (cosine),
        .B (x_xi_dot),
        .P (x2_1_out)
        );

    // sin(w * T) * eta_dot
    pe_time_ip_mult_dsp x2_2 (
        .A (sine),
        .B (x_eta_dot),
        .P (x2_2_out)
        );

    // cos(w * T) * xi_dot - sin(w * T) * eta_dot
    pe_time_ip_sub x2 (
        .A (x2_1_out),
        .B (x2_2_out),
        .S (x_next_t[127 : 96])
        );
// --------------------------------------------------------------------------------

    // phase_inv - cosine_mult_phase_inv_out = 1 / w - cos(w * T) / w
    pe_time_ip_sub x3_1_1 (
        .A (phase_inv),
        .B (cosine_mult_phase_inv_out),
        .S (x3_1_1_out)
        );

    // (1 / w - cos(w * T) / w) * xi_dot
    pe_time_ip_mult_dsp x3_1_2 (
        .A (x3_1_1_out),
        .B (x_xi_dot),
        .P (x3_1_out)
        );

    // (sin(w * T) / w) * eta_dot
    pe_time_ip_mult_dsp x3_3 (
        .A (sine_mult_phase_inv_out),
        .B (x_eta_dot),
        .P (x3_3_out)
        );

    // (sin(w * T) / w) * eta_dot + (1 / w - cos(w * T) / w) * xi_dot
    pe_time_ip_add x3_2 (
        .A (x3_1_out),
        .B (x3_3_out),
        .S (x3_2_out)
        );

    pe_time_ip_add x3 (
        .A (x3_2_out),
        .B (x_eta),
        .S (x_next_t[95 : 64])
        );
// --------------------------------------------------------------------------------

    // sin(w * T) * xi_dot
    pe_time_ip_mult_dsp x4_1 (
        .A (sine),
        .B (x_xi_dot),
        .P (x4_1_out)
        );

    // cos(w * T) * eta_dot
    pe_time_ip_mult_dsp x4_2 (
        .A (cosine),
        .B (x_eta_dot),
        .P (x4_2_out)
        );

    // x4_1_out + x4_2_out = sin(w * T) * xi_dot + cos(w * T) * eta_dot
    pe_time_ip_add x4 (
        .A (x4_1_out),
        .B (x4_2_out),
        .S (x_next_t[63 : 32])
        );
// --------------------------------------------------------------------------------

    // (sin(w * T) / w) * xi_dot
    pe_time_ip_mult_dsp x1_1 (
        .A (sine_mult_phase_inv_out),
        .B (x_xi_dot),
        .P (x1_1_out)
        );

    // (1 / w - cos(w * T) / w) * eta_dot
    pe_time_ip_mult_dsp x1_2 (
        .A (x3_1_1_out),
        .B (x_eta_dot),
        .P (x1_2_out)
        );

    // ( (sin(w * T) / w) * xi_dot ) - ( (1 / w - cos(w * T) / w) * eta_dot )
    pe_time_ip_sub x1_3 (
        .A (x1_1_out),
        .B (x1_2_out),
        .S (x1_3_out)
        );

    pe_time_ip_add x1 (
        .A (x1_3_out),
        .B (x_xi),
        .S (x_next_t[159 : 128])
        );
// --------------------------------------------------------------------------------

    assign x_next_t[31 : 0] = x_w;
// --------------------------------------------------------------------------------

    always @(posedge clk) begin
        x_next_valid <= trig_out_valid;
        x_next <= x_next_t;
    end

endmodule
