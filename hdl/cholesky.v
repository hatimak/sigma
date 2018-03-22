`timescale 1ns / 1ps

module cholesky (
    input wire           clk,
    input wire           clk_en,
    input wire           rst,
    input wire [479 : 0] A,
    input wire           A_valid,

    output reg [479 : 0] L,
    output reg           L_valid
    );

    localparam N             = 5;
    localparam COUNT_WIDTH   = 9;

    localparam DIV_SUB_LATENCY = 1; // The output of divider generator IP needs to be "formatted" so extra latency here
    localparam DIV_LATENCY     = 53 + DIV_SUB_LATENCY;
    localparam SQRT_LATENCY    = 27; // 1 more than the latency reported by "IP Customization" dialog of Vivado (specific to Vivado only).
    localparam MAC_LATENCY     = 9;
    localparam PRE_LATENCY     = 2; // 1 more than the latency reported by "IP Customization" dialog of Vivado (specific to Vivado only).

    /* Computation of column 1 of Cholesky factor takes (SQRT_LATENCY + DIV_LATENCY + MAC_LATENCY) cycles
     * Computation of column j of Cholesky factor takes ((PRE_LATENCY + SQRT_LATENCY) + (PRE_LATENCY + DIV_LATENCY) + (MAC_LATENCY)) cycles, for j = 2..N-1
     * Computation of column N of Cholesky factor takes (PRE_LATENCY + SQRT_LATENCY) cycles
     */
    localparam COL_1_LATENCY = SQRT_LATENCY + DIV_LATENCY + MAC_LATENCY;
    localparam COL_2_LATENCY = (PRE_LATENCY + SQRT_LATENCY) + (PRE_LATENCY + DIV_LATENCY) + (MAC_LATENCY) + COL_1_LATENCY;
    localparam COL_3_LATENCY = (PRE_LATENCY + SQRT_LATENCY) + (PRE_LATENCY + DIV_LATENCY) + (MAC_LATENCY) + COL_2_LATENCY;
    localparam COL_4_LATENCY = (PRE_LATENCY + SQRT_LATENCY) + (PRE_LATENCY + DIV_LATENCY) + (MAC_LATENCY) + COL_3_LATENCY;
    localparam COL_5_LATENCY = (PRE_LATENCY + SQRT_LATENCY) + COL_4_LATENCY;

    localparam CHOL_LATENCY  = COL_5_LATENCY; // Latency of last column

    wire [31 : 0] A_11 = A[31 : 0],
                  A_21 = A[63 : 32],
                  A_22 = A[95 : 64],
                  A_31 = A[127 : 96],
                  A_32 = A[159 : 128],
                  A_33 = A[191 : 160],
                  A_41 = A[223 : 192],
                  A_42 = A[255 : 224],
                  A_43 = A[287 : 256],
                  A_44 = A[319 : 288],
                  A_51 = A[351 : 320],
                  A_52 = A[383 : 352],
                  A_53 = A[415 : 384],
                  A_54 = A[447 : 416],
                  A_55 = A[479 : 448];

    wire          sclr_mac_22, sclr_mac_32, sclr_mac_42, sclr_mac_52,
                  sclr_mac_33, sclr_mac_43, sclr_mac_53,
                  sclr_mac_44, sclr_mac_54,
                  sclr_mac_55,
                  sqrt_data_valid, div_divisor_valid;
    wire  [3 : 0] div_dividend_valid;
    wire [23 : 0] sqrt_out_t;
    wire [31 : 0] div_1_sub_out, div_2_sub_out, div_3_sub_out, div_4_sub_out,
                  div_1_out, div_2_out, div_3_out, div_4_out,
                  sqrt_out_tt,
                  mac_22_a, mac_32_a, mac_32_b, mac_42_a, mac_42_b, mac_52_a, mac_52_b,
                  mac_33_a, mac_43_a, mac_43_b, mac_53_a, mac_53_b,
                  mac_44_a, mac_54_a, mac_54_b,
                  mac_55_a,
                  pre_sub_1_a, pre_sub_1_b, pre_sub_2_a, pre_sub_2_b, pre_sub_3_a, pre_sub_3_b, pre_sub_sq_a, pre_sub_sq_b,
                  pre_sub_1_out, pre_sub_2_out, pre_sub_3_out, pre_sub_sq_out;
    wire [55 : 0] div_1_out_t, div_2_out_t, div_3_out_t, div_4_out_t;
    wire [63 : 0] mac_22_p, mac_32_p, mac_42_p, mac_52_p,
                  mac_33_p, mac_43_p, mac_53_p,
                  mac_44_p, mac_54_p,
                  mac_55_p;
    reg           clk_en_sqrt, sqrt_data_valid_d1, sqrt_data_valid_d2, count_en;
    reg   [3 : 0] clk_en_div, div_dividend_valid_d1, div_dividend_valid_d2;
    reg   [9 : 0] clk_en_mac;
    reg  [31 : 0] sqrt_out, sqrt_data, div_divisor, div_dividend [3 : 0];
    reg  [63 : 0] run_sum_22, run_sum_32, run_sum_42, run_sum_52,
                  run_sum_33, run_sum_43, run_sum_53,
                  run_sum_44, run_sum_54,
                  run_sum_55;

    reg [COUNT_WIDTH-1 : 0] count;

    // Keeping count of cycles
    always @(posedge clk) begin
        if (rst) begin
            count_en <= 1'b0;
        end else if (count == CHOL_LATENCY) begin
            if (A_valid) begin
                count_en <= 1'b1;
            end else begin
                count_en <= 1'b0;
            end
        end else if (A_valid) begin
            count_en <= 1'b1;
        end else begin
            count_en <= count_en;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            count <= {COUNT_WIDTH{1'b0}};
        end else if (count == CHOL_LATENCY) begin
            if (A_valid) begin
                count <= { {COUNT_WIDTH-1{1'b0}}, 1'b1 };
            end else begin
                count <= {COUNT_WIDTH{1'b0}};
            end
        end else if (count_en || A_valid) begin
            count <= count + 1;
        end else begin
            count <= count;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            L_valid <= 1'b0;
        end else begin
            if (count == CHOL_LATENCY) begin
                L_valid <= 1'b1;
            end else begin
                L_valid <= 1'b0;
            end
        end
    end

// ================================================================================

    localparam S_IDLE  = 6'b00_0001;
    localparam S_COL_1 = 6'b00_0010;
    localparam S_COL_2 = 6'b00_0100;
    localparam S_COL_3 = 6'b00_1000;
    localparam S_COL_4 = 6'b01_0000;
    localparam S_COL_5 = 6'b10_0000;

    localparam S_COL_1_LAT = SQRT_LATENCY + DIV_LATENCY + MAC_LATENCY; // First column latency
    localparam S_COL_I_LAT = (PRE_LATENCY + SQRT_LATENCY) + (PRE_LATENCY + DIV_LATENCY) + (MAC_LATENCY); // I-th column latency, I = 2, 3, ..., N-1
    localparam S_COL_N_LAT = PRE_LATENCY + SQRT_LATENCY; // Last column latency

    reg [5 : 0] state;
    reg [7 : 0] s_count;

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            s_count <= 8'b0000_0000;

            clk_en_div <= 4'b0000;
            clk_en_sqrt <= 1'b0;
            clk_en_mac <= 10'b00_0000_0000;

            sqrt_data <= {32{1'b0}};
            div_divisor <= {{15{1'b0}}, 1'b1, {16{1'b0}}}; // Don't want 0.0 in the denominator, so 1.0
            div_dividend[0] <= {32{1'b0}};
            div_dividend[1] <= {32{1'b0}};
            div_dividend[2] <= {32{1'b0}};
            div_dividend[3] <= {32{1'b0}};
        end else begin
            case (state)
                S_IDLE: begin
                    if (A_valid) begin
                        state <= S_COL_1;
                        s_count <= 8'b0000_0001;

                        clk_en_sqrt <= 1'b1;
                        sqrt_data <= A_11;
                    end else begin
                        state <= S_IDLE;
                        s_count <= 8'b0000_0000;

                        clk_en_sqrt <= 1'b0;
                        sqrt_data <= {32{1'b0}};
                    end

                    clk_en_div <= 4'b0000;
                    clk_en_mac <= 10'b00_0000_0000;

                    div_divisor <= {{15{1'b0}}, 1'b1, {16{1'b0}}}; // Don't want 0.0 in the denominator, so 1.0
                    div_dividend[0] <= {32{1'b0}};
                    div_dividend[1] <= {32{1'b0}};
                    div_dividend[2] <= {32{1'b0}};
                    div_dividend[3] <= {32{1'b0}};
                end
                S_COL_1: begin
                    if (s_count == S_COL_1_LAT) begin
                        state <= S_COL_2;
                        s_count <= 8'b0000_0001;

                        clk_en_sqrt <= 1'b1;
                    end else begin
                        state <= S_COL_1;
                        s_count <= s_count + 8'b0000_0001;
                        
                        if (s_count > SQRT_LATENCY) begin
                            clk_en_sqrt <= 1'b0;
                        end
                    end

                    if (s_count >= SQRT_LATENCY - 1 && s_count <= SQRT_LATENCY + DIV_LATENCY) begin
                        clk_en_div <= 4'b1111;
                    end else begin
                        clk_en_div <= 4'b0000;
                    end
                    if (s_count >= SQRT_LATENCY + DIV_LATENCY - 1 && s_count <= SQRT_LATENCY + DIV_LATENCY + MAC_LATENCY) begin
                        clk_en_mac <= 10'b11_1111_1111;
                    end else begin
                        clk_en_mac <= 10'b00_0000_0000;
                    end

                    if (s_count == SQRT_LATENCY) begin
                        div_divisor <= sqrt_out;
                        div_dividend[0] <= A_21;
                        div_dividend[1] <= A_31;
                        div_dividend[2] <= A_41;
                        div_dividend[3] <= A_51;
                    end
                end
                S_COL_2: begin
                    if (s_count == S_COL_I_LAT) begin
                        state <= S_COL_3;
                        s_count <= 8'b0000_0001;

                        clk_en_sqrt <= 1'b1;
                    end else begin
                        state <= S_COL_2;
                        s_count <= s_count + 8'b0000_0001;

                        if (s_count > PRE_LATENCY + SQRT_LATENCY) begin
                            clk_en_sqrt <= 1'b0;
                        end
                    end

                    if (s_count >= SQRT_LATENCY + 2 * PRE_LATENCY - 1 && s_count <= SQRT_LATENCY + 2 * PRE_LATENCY + DIV_LATENCY) begin
                        clk_en_div <= 4'b0111;
                    end else begin
                        clk_en_div <= 4'b0000;
                    end
                    if (s_count >= SQRT_LATENCY + DIV_LATENCY + 2 * PRE_LATENCY - 1 && s_count <= SQRT_LATENCY + DIV_LATENCY + 2 * PRE_LATENCY + MAC_LATENCY) begin
                        clk_en_mac <= 10'b11_1111_0000;
                    end else begin
                        clk_en_mac <= 10'b00_0000_0000;
                    end

                    if (s_count == PRE_LATENCY) begin
                        sqrt_data <= pre_sub_sq_out;
                    end
                    if (s_count == SQRT_LATENCY + 2 * PRE_LATENCY) begin
                        div_divisor <= sqrt_out;
                        div_dividend[0] <= pre_sub_1_out;
                        div_dividend[1] <= pre_sub_2_out;
                        div_dividend[2] <= pre_sub_3_out;
                    end
                end
                S_COL_3: begin
                    if (s_count == S_COL_I_LAT) begin
                        state <= S_COL_4;
                        s_count <= 8'b0000_0001;

                        clk_en_sqrt <= 1'b1;
                    end else begin
                        state <= S_COL_3;
                        s_count <= s_count + 8'b0000_0001;

                        if (s_count > PRE_LATENCY + SQRT_LATENCY) begin
                            clk_en_sqrt <= 1'b0;
                        end
                    end

                    if (s_count >= SQRT_LATENCY + 2 * PRE_LATENCY - 1 && s_count <= SQRT_LATENCY + 2 * PRE_LATENCY + DIV_LATENCY) begin
                        clk_en_div <= 4'b0011;
                    end else begin
                        clk_en_div <= 4'b0000;
                    end
                    if (s_count >= SQRT_LATENCY + DIV_LATENCY + 2 * PRE_LATENCY - 1 && s_count <= SQRT_LATENCY + DIV_LATENCY + 2 * PRE_LATENCY + MAC_LATENCY) begin
                        clk_en_mac <= 10'b11_1000_0000;
                    end else begin
                        clk_en_mac <= 10'b00_0000_0000;
                    end

                    if (s_count == PRE_LATENCY) begin
                        sqrt_data <= pre_sub_sq_out;
                    end
                    if (s_count == SQRT_LATENCY + 2 * PRE_LATENCY) begin
                        div_divisor <= sqrt_out;
                        div_dividend[0] <= pre_sub_1_out;
                        div_dividend[1] <= pre_sub_2_out;
                    end
                end
                S_COL_4: begin
                    if (s_count == S_COL_I_LAT) begin
                        state <= S_COL_5;
                        s_count <= 8'b0000_0001;

                        clk_en_sqrt <= 1'b1;
                    end else begin
                        state <= S_COL_4;
                        s_count <= s_count + 8'b0000_0001;

                        if (s_count > PRE_LATENCY + SQRT_LATENCY) begin
                            clk_en_sqrt <= 1'b0;
                        end
                    end

                    if (s_count >= SQRT_LATENCY + 2 * PRE_LATENCY - 1 && s_count <= SQRT_LATENCY + 2 * PRE_LATENCY + DIV_LATENCY) begin
                        clk_en_div <= 4'b0001;
                    end else begin
                        clk_en_div <= 4'b0000;
                    end
                    if (s_count >= SQRT_LATENCY + DIV_LATENCY + 2 * PRE_LATENCY - 1 && s_count <= SQRT_LATENCY + DIV_LATENCY + 2 * PRE_LATENCY + MAC_LATENCY) begin
                        clk_en_mac <= 10'b10_0000_0000;
                    end else begin
                        clk_en_mac <= 10'b00_0000_0000;
                    end

                    if (s_count == PRE_LATENCY) begin
                        sqrt_data <= pre_sub_sq_out;
                    end
                    if (s_count == SQRT_LATENCY + 2 * PRE_LATENCY) begin
                        div_divisor <= sqrt_out;
                        div_dividend[0] <= pre_sub_1_out;
                    end
                end
                S_COL_5: begin
                    if (s_count == S_COL_N_LAT) begin
                        if (A_valid) begin
                            state <= S_COL_1;
                            s_count <= 8'b0000_0001;

                            clk_en_sqrt <= 1'b1;
                            sqrt_data <= A_11;
                        end else begin
                            state <= S_IDLE;
                            s_count <= 8'b0000_0000;

                            clk_en_sqrt <= 1'b0;
                            sqrt_data <= {32{1'b0}};
                        end
                    end else begin
                        state <= S_COL_5;
                        s_count <= s_count + 8'b0000_0001;
                    end

                    if (s_count == PRE_LATENCY) begin
                        sqrt_data <= pre_sub_sq_out;
                    end
                end
            endcase
        end
    end

    /* Set data valid signals
     * ----------------------
     */
    always @(posedge clk) begin
        sqrt_data_valid_d1 <= clk_en_sqrt;
        sqrt_data_valid_d2 <= sqrt_data_valid_d1;

        div_dividend_valid_d1 <= clk_en_div;
        div_dividend_valid_d2 <= div_dividend_valid_d1;
    end

    assign sqrt_data_valid = sqrt_data_valid_d1 & ~sqrt_data_valid_d2;
    assign div_dividend_valid = div_dividend_valid_d1 & ~div_dividend_valid_d2;
    assign div_divisor_valid = |div_dividend_valid; // Divisor input is valid anytime a dividend input is valid.

// ================================================================================
    /* Square root module
     * ------------------
     * Latency is SQRT_LATENCY
     */

    cholesky_ip_sqrt sqrt_1 (
        .aclk                    (clk),
        .aclken                  (clk_en_sqrt),
        .aresetn                 (~rst),
        .s_axis_cartesian_tvalid (sqrt_data_valid),
        .s_axis_cartesian_tdata  (sqrt_data),
        .m_axis_dout_tvalid      (), // Not connected, since latency is known beforehand, we know when to sample
        .m_axis_dout_tdata       (sqrt_out_t)
        );
    assign sqrt_out_tt = { {8{1'b0}}, sqrt_out_t };
    always @(*) begin
        if (rst) begin
            sqrt_out = {32{1'b0}};
        end else begin
            if (count == SQRT_LATENCY ||
                count == COL_1_LATENCY + PRE_LATENCY + SQRT_LATENCY ||
                count == COL_2_LATENCY + PRE_LATENCY + SQRT_LATENCY ||
                count == COL_3_LATENCY + PRE_LATENCY + SQRT_LATENCY ||
                count == COL_4_LATENCY + PRE_LATENCY + SQRT_LATENCY) begin
                sqrt_out = sqrt_out_tt;
            end
        end
    end

// ================================================================================
    /* N - 1 Divider modules
     * ---------------------
     * Latency for Divider IP is DIV_LATENCY
     * Total latency is DIV_LATENCY + 1
     * Since the Divider Generator IP uses Radix2 algorithm and outputs both 
     * quotient and remainder signed, the additional 1 is due to the subtraction 
     * to match the Divider IP output with our number representation
     *
     * All division operations for a particular column j have as divisor L_jj
     */

    cholesky_ip_div div_1 (
        .aclk                   (clk),
        .aclken                 (clk_en_div[0]),
        .aresetn                (~rst),
        .s_axis_divisor_tvalid  (div_divisor_valid),
        .s_axis_divisor_tdata   (div_divisor),
        .s_axis_dividend_tvalid (div_dividend_valid[0]),
        .s_axis_dividend_tdata  (div_dividend[0]),
        .m_axis_dout_tvalid     (), // Not connected, since latency is known beforehand, we know when to sample
        .m_axis_dout_tdata      (div_1_out_t)
        );
    cholesky_ip_sub_const div_sub_1 (
        .A   (div_1_out_t[48 : 17]),
        .CLK (clk),
        .CE  (clk_en_div[0]),
        .S   (div_1_sub_out)
        );
    assign div_1_out = (div_1_out_t[16]) ? {div_1_sub_out[15 : 0], div_1_out_t[15 : 0]} : {div_1_out_t[32 : 17], div_1_out_t[15 : 0]};

// --------------------------------------------------------------------------------
    cholesky_ip_div div_2 (
        .aclk                   (clk),
        .aclken                 (clk_en_div[1]),
        .aresetn                (~rst),
        .s_axis_divisor_tvalid  (div_divisor_valid),
        .s_axis_divisor_tdata   (div_divisor),
        .s_axis_dividend_tvalid (div_dividend_valid[1]),
        .s_axis_dividend_tdata  (div_dividend[1]),
        .m_axis_dout_tvalid     (), // Not connected, since latency is known beforehand, we know when to sample
        .m_axis_dout_tdata      (div_2_out_t)
        );
    cholesky_ip_sub_const div_sub_2 (
        .A   (div_2_out_t[48 : 17]),
        .CLK (clk),
        .CE  (clk_en_div[1]),
        .S   (div_2_sub_out)
        );
    assign div_2_out = (div_2_out_t[16]) ? {div_2_sub_out[15 : 0], div_2_out_t[15 : 0]} : {div_2_out_t[32 : 17], div_2_out_t[15 : 0]};

// --------------------------------------------------------------------------------
    cholesky_ip_div div_3 (
        .aclk                   (clk),
        .aclken                 (clk_en_div[2]),
        .aresetn                (~rst),
        .s_axis_divisor_tvalid  (div_divisor_valid),
        .s_axis_divisor_tdata   (div_divisor),
        .s_axis_dividend_tvalid (div_dividend_valid[2]),
        .s_axis_dividend_tdata  (div_dividend[2]),
        .m_axis_dout_tvalid     (), // Not connected, since latency is known beforehand, we know when to sample
        .m_axis_dout_tdata      (div_3_out_t)
        );
    cholesky_ip_sub_const div_sub_3 (
        .A   (div_3_out_t[48 : 17]),
        .CLK (clk),
        .CE  (clk_en_div[2]),
        .S   (div_3_sub_out)
        );
    assign div_3_out = (div_3_out_t[16]) ? {div_3_sub_out[15 : 0], div_3_out_t[15 : 0]} : {div_3_out_t[32 : 17], div_3_out_t[15 : 0]};

// --------------------------------------------------------------------------------
    cholesky_ip_div div_4 (
        .aclk                   (clk),
        .aclken                 (clk_en_div[3]),
        .aresetn                (~rst),
        .s_axis_divisor_tvalid  (div_divisor_valid),
        .s_axis_divisor_tdata   (div_divisor),
        .s_axis_dividend_tvalid (div_dividend_valid[3]),
        .s_axis_dividend_tdata  (div_dividend[3]),
        .m_axis_dout_tvalid     (),  // Not connected, since latency is known beforehand, we know when to sample
        .m_axis_dout_tdata      (div_4_out_t)
        );
    cholesky_ip_sub_const div_sub_4 (
        .A   (div_4_out_t[48 : 17]),
        .CLK (clk),
        .CE  (clk_en_div[3]),
        .S   (div_4_sub_out)
        );
    assign div_4_out = (div_4_out_t[16]) ? {div_4_sub_out[15 : 0], div_4_out_t[15 : 0]} : {div_4_out_t[32 : 17], div_4_out_t[15 : 0]};

// ================================================================================
    /* (1 / 2) * (N - 1) * (N) Multiply-ACcumulate (MAC) modules
     * ---------------------------------------------------------
     * Latency is MAC_LATENCY
     * Module mac_ij is paired to L_ij, and mac_ij performs (j - 1) MAC operations.
     */

    assign sclr_mac_22 = rst;
    assign sclr_mac_32 = rst;
    assign sclr_mac_42 = rst;
    assign sclr_mac_52 = rst;
    assign sclr_mac_33 = rst;
    assign sclr_mac_43 = rst;
    assign sclr_mac_53 = rst;
    assign sclr_mac_44 = rst;
    assign sclr_mac_54 = rst;
    assign sclr_mac_55 = rst;

    // Paired to L_22 (square module)
    pe_matrix_ip_mac mac_22 (
        .CLK      (clk),
        .SCLR     (sclr_mac_22),
        .CE       (clk_en_mac[0]),
        .A        (mac_22_a),
        .B        (mac_22_a),
        .C        (run_sum_22),
        .SUBTRACT (1'b0), // Add
        .P        (mac_22_p),
        .PCOUT    () // Not connected since pe_matrix_ip_mac spans multiple DSP slices
        );
    always @(*) begin
        if (rst) begin
            run_sum_22 = {64{1'b0}};
        end else begin
            if (count == SQRT_LATENCY + DIV_LATENCY + MAC_LATENCY) begin
                run_sum_22 = mac_22_p;
            end
        end
    end

    // Paired to L_32
    pe_matrix_ip_mac mac_32 (
        .CLK      (clk),
        .SCLR     (sclr_mac_32),
        .CE       (clk_en_mac[1]),
        .A        (mac_32_a),
        .B        (mac_32_b),
        .C        (run_sum_32),
        .SUBTRACT (1'b0), // Add
        .P        (mac_32_p),
        .PCOUT    () // Not connected since pe_matrix_ip_mac spans multiple DSP slices
        );
    always @(*) begin
        if (rst) begin
            run_sum_32 = {64{1'b0}};
        end else begin
            if (count == SQRT_LATENCY + DIV_LATENCY + MAC_LATENCY) begin
                run_sum_32 = mac_32_p;
            end
        end
    end

    // Paired to L_42
    pe_matrix_ip_mac mac_42 (
        .CLK      (clk),
        .SCLR     (sclr_mac_42),
        .CE       (clk_en_mac[2]),
        .A        (mac_42_a),
        .B        (mac_42_b),
        .C        (run_sum_42),
        .SUBTRACT (1'b0), // Add
        .P        (mac_42_p),
        .PCOUT    () // Not connected since pe_matrix_ip_mac spans multiple DSP slices
        );
    always @(*) begin
        if (rst) begin
            run_sum_42 = {64{1'b0}};
        end else begin
            if (count == SQRT_LATENCY + DIV_LATENCY + MAC_LATENCY) begin
                run_sum_42 = mac_42_p;
            end
        end
    end

    // Paired to L_52
    pe_matrix_ip_mac mac_52 (
        .CLK      (clk),
        .SCLR     (sclr_mac_52),
        .CE       (clk_en_mac[3]),
        .A        (mac_52_a),
        .B        (mac_52_b),
        .C        (run_sum_52),
        .SUBTRACT (1'b0), // Add
        .P        (mac_52_p),
        .PCOUT    () // Not connected since pe_matrix_ip_mac spans multiple DSP slices
        );
    always @(*) begin
        if (rst) begin
            run_sum_52 = {64{1'b0}};
        end else begin
            if (count == SQRT_LATENCY + DIV_LATENCY + MAC_LATENCY) begin
                run_sum_52 = mac_52_p;
            end
        end
    end

// --------------------------------------------------------------------------------
    // Paired to L_33 (square module)
    pe_matrix_ip_mac mac_33 (
        .CLK      (clk),
        .SCLR     (sclr_mac_33),
        .CE       (clk_en_mac[4]),
        .A        (mac_33_a),
        .B        (mac_33_a),
        .C        (run_sum_33),
        .SUBTRACT (1'b0), // Add
        .P        (mac_33_p),
        .PCOUT    () // Not connected since pe_matrix_ip_mac spans multiple DSP slices
        );
    always @(*) begin
        if (rst) begin
            run_sum_33 = {64{1'b0}};
        end else begin
            if ((count == SQRT_LATENCY + DIV_LATENCY + MAC_LATENCY) ||
                (count == COL_1_LATENCY + PRE_LATENCY + SQRT_LATENCY + PRE_LATENCY + DIV_LATENCY + MAC_LATENCY)) begin
                run_sum_33 = mac_33_p;
            end
        end
    end

    // Paired to L_43
    pe_matrix_ip_mac mac_43 (
        .CLK      (clk),
        .SCLR     (sclr_mac_43),
        .CE       (clk_en_mac[5]),
        .A        (mac_43_a),
        .B        (mac_43_b),
        .C        (run_sum_43),
        .SUBTRACT (1'b0), // Add
        .P        (mac_43_p),
        .PCOUT    () // Not connected since pe_matrix_ip_mac spans multiple DSP slices
        );
    always @(*) begin
        if (rst) begin
            run_sum_43 = {64{1'b0}};
        end else begin
            if ((count == SQRT_LATENCY + DIV_LATENCY + MAC_LATENCY) ||
                (count == COL_1_LATENCY + PRE_LATENCY + SQRT_LATENCY + PRE_LATENCY + DIV_LATENCY + MAC_LATENCY)) begin
                run_sum_43 = mac_43_p;
            end
        end
    end

    // Paired to L_53
    pe_matrix_ip_mac mac_53 (
        .CLK      (clk),
        .SCLR     (sclr_mac_53),
        .CE       (clk_en_mac[6]),
        .A        (mac_53_a),
        .B        (mac_53_b),
        .C        (run_sum_53),
        .SUBTRACT (1'b0), // Add
        .P        (mac_53_p),
        .PCOUT    () // Not connected since pe_matrix_ip_mac spans multiple DSP slices
        );
    always @(*) begin
        if (rst) begin
            run_sum_53 = {64{1'b0}};
        end else begin
            if ((count == SQRT_LATENCY + DIV_LATENCY + MAC_LATENCY) ||
                (count == COL_1_LATENCY + PRE_LATENCY + SQRT_LATENCY + PRE_LATENCY + DIV_LATENCY + MAC_LATENCY)) begin
                run_sum_53 = mac_53_p;
            end
        end
    end

// --------------------------------------------------------------------------------
    // Paired to L_44 (square module)
    pe_matrix_ip_mac mac_44 (
        .CLK      (clk),
        .SCLR     (sclr_mac_44),
        .CE       (clk_en_mac[7]),
        .A        (mac_44_a),
        .B        (mac_44_a),
        .C        (run_sum_44),
        .SUBTRACT (1'b0), // Add
        .P        (mac_44_p),
        .PCOUT    () // Not connected since pe_matrix_ip_mac spans multiple DSP slices
        );
    always @(*) begin
        if (rst) begin
            run_sum_44 = {64{1'b0}};
        end else begin
            if ((count == SQRT_LATENCY + DIV_LATENCY + MAC_LATENCY) ||
                (count == COL_1_LATENCY + PRE_LATENCY + SQRT_LATENCY + PRE_LATENCY + DIV_LATENCY + MAC_LATENCY) ||
                (count == COL_2_LATENCY + PRE_LATENCY + SQRT_LATENCY + PRE_LATENCY + DIV_LATENCY + MAC_LATENCY)) begin
                run_sum_44 = mac_44_p;
            end
        end
    end

    // Paired to L_54
    pe_matrix_ip_mac mac_54 (
        .CLK      (clk),
        .SCLR     (sclr_mac_54),
        .CE       (clk_en_mac[8]),
        .A        (mac_54_a),
        .B        (mac_54_b),
        .C        (run_sum_54),
        .SUBTRACT (1'b0), // Add
        .P        (mac_54_p),
        .PCOUT    () // Not connected since pe_matrix_ip_mac spans multiple DSP slices
        );
    always @(*) begin
        if (rst) begin
            run_sum_54 = {64{1'b0}};
        end else begin
            if ((count == SQRT_LATENCY + DIV_LATENCY + MAC_LATENCY) ||
                (count == COL_1_LATENCY + PRE_LATENCY + SQRT_LATENCY + PRE_LATENCY + DIV_LATENCY + MAC_LATENCY) ||
                (count == COL_2_LATENCY + PRE_LATENCY + SQRT_LATENCY + PRE_LATENCY + DIV_LATENCY + MAC_LATENCY)) begin
                run_sum_54 = mac_54_p;
            end
        end
    end

// --------------------------------------------------------------------------------
    // Paired to L_55 (square module)
    pe_matrix_ip_mac mac_55 (
        .CLK      (clk),
        .SCLR     (sclr_mac_55),
        .CE       (clk_en_mac[9]),
        .A        (mac_55_a),
        .B        (mac_55_a),
        .C        (run_sum_55),
        .SUBTRACT (1'b0), // Add
        .P        (mac_55_p),
        .PCOUT    () // Not connected since pe_matrix_ip_mac spans multiple DSP slices
        );
    always @(*) begin
        if (rst) begin
            run_sum_55 = {64{1'b0}};
        end else begin
            if ((count == SQRT_LATENCY + DIV_LATENCY + MAC_LATENCY) ||
                (count == COL_1_LATENCY + PRE_LATENCY + SQRT_LATENCY + PRE_LATENCY + DIV_LATENCY + MAC_LATENCY) ||
                (count == COL_2_LATENCY + PRE_LATENCY + SQRT_LATENCY + PRE_LATENCY + DIV_LATENCY + MAC_LATENCY) ||
                (count == COL_3_LATENCY + PRE_LATENCY + SQRT_LATENCY + PRE_LATENCY + DIV_LATENCY + MAC_LATENCY)) begin
                run_sum_55 = mac_55_p;
            end
        end
    end

// ================================================================================
    /* (N - 1) Subtractor modules to "pre-format"
     * ------------------------------------------
     * Latency is PRE_LATENCY
     */

    cholesky_ip_sub pre_sub_1 (
        .A   (pre_sub_1_a),
        .B   (pre_sub_1_b),
        .CLK (clk),
        .S   (pre_sub_1_out)
        );

    cholesky_ip_sub pre_sub_2 (
        .A   (pre_sub_2_a),
        .B   (pre_sub_2_b),
        .CLK (clk),
        .S   (pre_sub_2_out)
        );

    cholesky_ip_sub pre_sub_3 (
        .A   (pre_sub_3_a),
        .B   (pre_sub_3_b),
        .CLK (clk),
        .S   (pre_sub_3_out)
        );

    // Dedicated for square root
    cholesky_ip_sub pre_sub_sq (
        .A   (pre_sub_sq_a),
        .B   (pre_sub_sq_b),
        .CLK (clk),
        .S   (pre_sub_sq_out)
        );

// ================================================================================
    /* Setup input data signals
     * ------------------------
     */

    assign mac_22_a = div_1_out;
    assign mac_32_a = div_1_out;
    assign mac_32_b = div_2_out;
    assign mac_42_a = div_1_out;
    assign mac_42_b = div_3_out;
    assign mac_52_a = div_1_out;
    assign mac_52_b = div_4_out;

    assign mac_33_a = (count >= COL_1_LATENCY + PRE_LATENCY + SQRT_LATENCY) ? div_1_out : div_2_out;
    assign mac_43_a = (count >= COL_1_LATENCY + PRE_LATENCY + SQRT_LATENCY) ? div_1_out : div_2_out;
    assign mac_43_b = (count >= COL_1_LATENCY + PRE_LATENCY + SQRT_LATENCY) ? div_2_out : div_3_out;
    assign mac_53_a = (count >= COL_1_LATENCY + PRE_LATENCY + SQRT_LATENCY) ? div_1_out : div_2_out;
    assign mac_53_b = (count >= COL_1_LATENCY + PRE_LATENCY + SQRT_LATENCY) ? div_3_out : div_4_out;

    assign mac_44_a = (count >= COL_2_LATENCY + PRE_LATENCY + SQRT_LATENCY) ? div_1_out :
                      (count >= COL_1_LATENCY + PRE_LATENCY + SQRT_LATENCY) ? div_2_out : div_3_out;
    assign mac_54_a = (count >= COL_2_LATENCY + PRE_LATENCY + SQRT_LATENCY) ? div_1_out :
                      (count >= COL_1_LATENCY + PRE_LATENCY + SQRT_LATENCY) ? div_2_out : div_3_out;
    assign mac_54_b = (count >= COL_2_LATENCY + PRE_LATENCY + SQRT_LATENCY) ? div_2_out :
                      (count >= COL_1_LATENCY + PRE_LATENCY + SQRT_LATENCY) ? div_3_out : div_4_out;

    assign mac_55_a = (count >= COL_3_LATENCY + PRE_LATENCY + SQRT_LATENCY) ? div_1_out :
                      (count >= COL_2_LATENCY + PRE_LATENCY + SQRT_LATENCY) ? div_2_out :
                      (count >= COL_1_LATENCY + PRE_LATENCY + SQRT_LATENCY) ? div_3_out : div_4_out;


    assign pre_sub_sq_a = (count >= COL_4_LATENCY) ? A_55 :
                          (count >= COL_3_LATENCY) ? A_44 :
                          (count >= COL_2_LATENCY) ? A_33 : A_22;
    assign pre_sub_sq_b = (count >= COL_4_LATENCY) ? run_sum_55[47 : 16] :
                          (count >= COL_3_LATENCY) ? run_sum_44[47 : 16] :
                          (count >= COL_2_LATENCY) ? run_sum_33[47 : 16] : run_sum_22[47 : 16];


    assign pre_sub_1_a  = (count >= COL_3_LATENCY) ? A_54 :
                          (count >= COL_2_LATENCY) ? A_43 : A_32;
    assign pre_sub_1_b  = (count >= COL_3_LATENCY) ? run_sum_54[47 : 16] :
                          (count >= COL_2_LATENCY) ? run_sum_43[47 : 16] : run_sum_32[47 : 16];

    assign pre_sub_2_a  = (count >= COL_2_LATENCY) ? A_53 : A_42;
    assign pre_sub_2_b  = (count >= COL_2_LATENCY) ? run_sum_53[47 : 16] : run_sum_42[47 : 16];

    assign pre_sub_3_a  = A_52;
    assign pre_sub_3_b  = run_sum_52[47 : 16];

// ================================================================================
    /* Extract elements of the lower Cholesky factor
     * ---------------------------------------------
     */

    always @(posedge clk) begin
        if (rst) begin
            L <= {480{1'b0}};
        end else begin
            if (count == COL_1_LATENCY) begin
                L[31 : 0]    <= sqrt_out;  // L_11
                L[63 : 32]   <= div_1_out; // L_21
                L[127 : 96]  <= div_2_out; // L_31
                L[223 : 192] <= div_3_out; // L_41
                L[351 : 320] <= div_4_out; // L_51
            end else if (count == COL_2_LATENCY) begin
                L[95 : 64]   <= sqrt_out;  // L_22
                L[159 : 128] <= div_1_out; // L_32
                L[255 : 224] <= div_2_out; // L_42
                L[383 : 352] <= div_3_out; // L_52
            end else if (count == COL_3_LATENCY) begin
                L[191 : 160] <= sqrt_out;  // L_33
                L[287 : 256] <= div_1_out; // L_43
                L[415 : 384] <= div_2_out; // L_53
            end else if (count == COL_4_LATENCY) begin
                L[319 : 288] <= sqrt_out;  // L_44
                L[447 : 416] <= div_1_out; // L_54
             end else if (count == COL_5_LATENCY) begin
                L[479 : 448] <= sqrt_out;  // L_55
            end
        end
    end

endmodule
