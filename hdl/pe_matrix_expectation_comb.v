`timescale 1ns / 1ps

/* N_SIGMA nuber of sigma points and their corresponding weights are input, 
 * one pair every cycle. Thus, expected value is available N_SIGMA cycles 
 * after the first sigma point-weight pair is applied.
 */

module pe_matrix_expectation_comb #(
    parameter DIM_SIGMA = 5
    ) (
    input wire              [31 : 0] weight,
    input wire  [32*DIM_SIGMA-1 : 0] sigma,
    input wire  [64*DIM_SIGMA-1 : 0] run_sum,

    output wire [64*DIM_SIGMA-1 : 0] mac_out
    );

    generate
        genvar i;
        for (i = 0; i < DIM_SIGMA; i = i + 1) begin
            localparam IND_SIGMA  = (32 * i);
            localparam IND_RUNSUM = (64 * i);
            pe_matrix_ip_mac mac (
                .A        (weight),
                .B        (sigma[IND_SIGMA+31 : IND_SIGMA]),
                .C        (run_sum[IND_RUNSUM+63 : IND_RUNSUM]),
                .SUBTRACT (1'b0), // Add
                .P        (mac_out[IND_RUNSUM+63 : IND_RUNSUM]),
                .PCOUT    () // Not connected, pe_matrix_ip_mac spans multiple DSP slices
                );
        end
    endgenerate

endmodule
