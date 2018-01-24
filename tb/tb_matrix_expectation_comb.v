`timescale 1ns / 1ps

module tb_matrix_expectation_comb ();

    reg   [31 : 0] weight, weight_y;
    reg   [63 : 0] sigma_y;
    reg  [127 : 0] run_sum_y;
    reg  [159 : 0] sigma;
    reg  [319 : 0] run_sum;
    wire [127 : 0] mac_out_y;
    wire [319 : 0] mac_out;

    pe_matrix_expectation_comb #(
        .DIM_SIGMA(5)
    ) uut_1 (
        .weight  (weight),
        .sigma   (sigma),
        .run_sum (run_sum),

        .mac_out (mac_out)
        );

    pe_matrix_expectation_comb #(
        .DIM_SIGMA(2)
    ) uut_2 (
        .weight  (weight_y),
        .sigma   (sigma_y),
        .run_sum (run_sum_y),

        .mac_out (mac_out_y)
        );

    initial begin
        weight = 32'h0000_0ae7;
        weight_y = weight;
        sigma = 160'h03e8_0000__012c_0000__03e8_0000__0000_0000__ffff_ead0;
        sigma_y = 64'h0586_4000__0000_c000;
        run_sum = {320{1'b0}};
        run_sum_y = {128{1'b0}};
        #300;
        $display("sigma_x:\n%x\n%x\n%x\n", mac_out[303 : 272], mac_out[239 : 208], mac_out[47 : 16]);
        $display("sigma_y:\n%x\n%x\n", mac_out_y[111 : 80], mac_out_y[47 : 16]);
        $finish;
    end

endmodule
