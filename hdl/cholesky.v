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

    localparam N           = 5; // Size of the matrix.
    localparam COUNT_WIDTH = 8; // Enough bits to hold the maximum number of cycles a column can take.

    // Number of clock cycles to wait for sampling output after input valid signal.
    localparam DIV_SAMPLE  = 55;
    localparam SQRT_SAMPLE = 27;
    localparam MAC_SAMPLE  = 10;
    localparam PRE_SAMPLE  = 2;

    /* Computation of column 1 of Cholesky factor takes (SQRT_SAMPLE + DIV_SAMPLE + MAC_SAMPLE) cycles
     * Computation of column I of Cholesky factor takes ((PRE_SAMPLE + SQRT_SAMPLE) + (PRE_SAMPLE + DIV_SAMPLE) + (MAC_SAMPLE)) cycles, for I = 2..N-1
     * Computation of column N of Cholesky factor takes (PRE_SAMPLE + SQRT_SAMPLE) cycles
     */
    localparam COL_1_LATENCY = SQRT_SAMPLE + DIV_SAMPLE + MAC_SAMPLE;
    localparam COL_I_LATENCY = (PRE_SAMPLE + SQRT_SAMPLE) + (PRE_SAMPLE + DIV_SAMPLE) + (MAC_SAMPLE);
    localparam COL_N_LATENCY = PRE_SAMPLE + SQRT_SAMPLE;

    // State machine encoding
    localparam S_IDLE  = 6'b00_0001;
    localparam S_COL_1 = 6'b00_0010;
    localparam S_COL_2 = 6'b00_0100;
    localparam S_COL_3 = 6'b00_1000;
    localparam S_COL_4 = 6'b01_0000;
    localparam S_COL_5 = 6'b10_0000;

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

    wire          sqrt_data_valid, div_divisor_valid;
    wire  [3 : 0] div_dividend_valid;
    wire [23 : 0] sqrt_out_t;
    wire [31 : 0] div_1_sub_out, div_2_sub_out, div_3_sub_out, div_4_sub_out,
                  div_1_out, div_2_out, div_3_out, div_4_out,
                  sqrt_out,
                  pre_sub_1_out, pre_sub_2_out, pre_sub_3_out, pre_sub_sq_out;
    wire [55 : 0] div_1_out_t, div_2_out_t, div_3_out_t, div_4_out_t;
    wire [63 : 0] mac_0_p, mac_1_p, mac_2_p, mac_3_p;
    reg           clk_en_sqrt, sqrt_data_valid_d1, sqrt_data_valid_d2, count_en;
    reg   [3 : 0] clk_en_div, clk_en_mac, clk_en_pre_sub, div_dividend_valid_d1, div_dividend_valid_d2;
    reg   [5 : 0] state;
    reg  [31 : 0] pre_sub_1_a, pre_sub_1_b, pre_sub_2_a, pre_sub_2_b, pre_sub_3_a, pre_sub_3_b, pre_sub_sq_a, pre_sub_sq_b,
                  sqrt_data,
                  div_divisor, div_dividend [3 : 0],
                  mac_0_a, mac_1_a, mac_1_b, mac_2_a, mac_2_b, mac_3_a, mac_3_b;
    reg  [63 : 0] mac_c [3 : 0];
    reg  [63 : 0] run_sum [9 : 0];

    reg [COUNT_WIDTH-1 : 0] s_count;

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            s_count <= 8'b0000_0000;

            clk_en_pre_sub <= 4'b0000;
            clk_en_sqrt <= 1'b0;
            clk_en_div <= 4'b0000;
            clk_en_mac <= 4'b0000;

            pre_sub_1_a <= {32{1'b0}};
            pre_sub_1_b <= {32{1'b0}};
            pre_sub_2_a <= {32{1'b0}};
            pre_sub_2_b <= {32{1'b0}};
            pre_sub_3_a <= {32{1'b0}};
            pre_sub_3_b <= {32{1'b0}};
            pre_sub_sq_a <= {32{1'b0}};
            pre_sub_sq_b <= {32{1'b0}};
            sqrt_data <= {32{1'b0}};
            div_divisor <= {{15{1'b0}}, 1'b1, {16{1'b0}}}; // Don't want 0.0 in the denominator, so 1.0.
            div_dividend[0] <= {32{1'b0}};
            div_dividend[1] <= {32{1'b0}};
            div_dividend[2] <= {32{1'b0}};
            div_dividend[3] <= {32{1'b0}};
            mac_0_a <= {32{1'b0}};
            mac_c[0] <= {64{1'b0}};
            mac_1_a <= {32{1'b0}};
            mac_1_b <= {32{1'b0}};
            mac_c[1] <= {64{1'b0}};
            mac_2_a <= {32{1'b0}};
            mac_2_b <= {32{1'b0}};
            mac_c[2] <= {64{1'b0}};
            mac_3_a <= {32{1'b0}};
            mac_3_b <= {32{1'b0}};
            mac_c[3] <= {64{1'b0}};
            run_sum[0] <= {64{1'b0}};
            run_sum[1] <= {64{1'b0}};
            run_sum[2] <= {64{1'b0}};
            run_sum[3] <= {64{1'b0}};
            run_sum[4] <= {64{1'b0}};
            run_sum[5] <= {64{1'b0}};
            run_sum[6] <= {64{1'b0}};
            run_sum[7] <= {64{1'b0}};
            run_sum[8] <= {64{1'b0}};
            run_sum[9] <= {64{1'b0}};

            L <= {480{1'b0}};
            L_valid <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (A_valid) begin
                        state <= S_COL_1;
                    end else begin
                        state <= S_IDLE;
                    end

                    // State counter
                    // -------------
                    if (A_valid) begin
                        s_count <= 8'b0000_0001;
                    end else begin
                        s_count <= 8'b0000_0000;
                    end

                    // Setup signals prior to commencing operations
                    // --------------------------------------------
                    if (A_valid) begin
                        sqrt_data <= A_11;
                        mac_0_a <= {32{1'b0}};
                        mac_c[0] <= {64{1'b0}};
                        mac_1_a <= {32{1'b0}};
                        mac_1_b <= {32{1'b0}};
                        mac_c[1] <= {64{1'b0}};
                        mac_2_a <= {32{1'b0}};
                        mac_2_b <= {32{1'b0}};
                        mac_c[2] <= {64{1'b0}};
                        mac_3_a <= {32{1'b0}};
                        mac_3_b <= {32{1'b0}};
                        mac_c[3] <= {64{1'b0}};

                        L <= {480{1'b0}};
                        L_valid <= 1'b0;

                        clk_en_sqrt <= 1'b1; // Enable clock for the first operation, square root
                    end
                end
                S_COL_1: begin
                    if (s_count == COL_1_LATENCY) begin
                        state <= S_COL_2;
                    end else begin
                        state <= S_COL_1;
                    end

                    // State counter
                    // -------------
                    if (s_count == COL_1_LATENCY) begin
                        s_count <= 8'b0000_0001;
                    end else begin
                        s_count <= s_count + 8'b0000_0001;
                    end

                    // Clock enable signals
                    // --------------------
                    if (s_count == SQRT_SAMPLE - 1) begin
                        clk_en_div <= 4'b1111;
                    end else if (s_count == SQRT_SAMPLE) begin
                        clk_en_sqrt <= 1'b0;
                    end else if (s_count == SQRT_SAMPLE + DIV_SAMPLE) begin
                        clk_en_div <= 4'b0000;
                        clk_en_mac <= 4'b1111;
                    end else if (s_count == COL_1_LATENCY) begin
                        clk_en_mac <= 4'b0111;
                        clk_en_pre_sub <= 4'b1000; // Enable clock to Pre-formatter module dedicated to square root module (MSB).
                        clk_en_sqrt <= 1'b1;
                    end

                    // Data input signals
                    // --------------------
                    if (s_count == SQRT_SAMPLE) begin
                        div_divisor <= sqrt_out;
                        div_dividend[0] <= A_21;
                        div_dividend[1] <= A_31;
                        div_dividend[2] <= A_41;
                        div_dividend[3] <= A_51;
                    end else if (s_count == SQRT_SAMPLE + DIV_SAMPLE) begin
                        mac_0_a <= div_1_out;
                        mac_1_a <= div_1_out;
                        mac_1_b <= div_2_out;
                        mac_2_a <= div_1_out;
                        mac_2_b <= div_3_out;
                        mac_3_a <= div_1_out;
                        mac_3_b <= div_4_out;
                    end else if (s_count == COL_1_LATENCY) begin
                        pre_sub_sq_a <= A_22;
                        pre_sub_sq_b <= mac_0_p[47 : 16];

                        // Reset input signals to unused modules.
                        div_dividend[3] <= {32{1'b0}};
                    end

                    // Extract running sum from MAC units
                    // ----------------------------------
                    if (s_count == COL_1_LATENCY) begin
                        run_sum[0] <= mac_0_p; // L_22
                        run_sum[1] <= mac_1_p; // L_32
                        run_sum[2] <= mac_2_p; // L_42
                        run_sum[3] <= mac_3_p; // L_52
                    end

                    // Extract elements of the lower Cholesky factor
                    // ---------------------------------------------
                    if (s_count == COL_1_LATENCY) begin
                        L[31 : 0]    <= sqrt_out;  // L_11
                        L[63 : 32]   <= div_1_out; // L_21
                        L[127 : 96]  <= div_2_out; // L_31
                        L[223 : 192] <= div_3_out; // L_41
                        L[351 : 320] <= div_4_out; // L_51
                    end
                end
                S_COL_2: begin
                    if (s_count == COL_I_LATENCY) begin
                        state <= S_COL_3;
                    end else begin
                        state <= S_COL_2;
                    end

                    // State counter
                    // -------------
                    if (s_count == COL_I_LATENCY) begin
                        s_count <= 8'b0000_0001;
                    end else begin
                        s_count <= s_count + 8'b0000_0001;
                    end

                    // Clock enable signals
                    // --------------------
                    if (s_count == 1 + MAC_SAMPLE) begin
                        clk_en_mac <= 4'b0011;
                    end else if (s_count == 1 + 2 * MAC_SAMPLE) begin
                        clk_en_mac <= 4'b0001;
                    end else if (s_count == 1 + 3 * MAC_SAMPLE) begin
                        clk_en_mac <= 4'b0000;
                    end else if (s_count == PRE_SAMPLE) begin
                        clk_en_pre_sub <= 4'b0000; // Disable clock to Pre-formatter module dedicated to square root module (MSB).
                    end else if (s_count == PRE_SAMPLE + SQRT_SAMPLE) begin
                        clk_en_pre_sub <= 4'b0111; // Enable clock to Pre-formatter module (non square root modules).
                        clk_en_sqrt <= 1'b0;
                    end else if (s_count == PRE_SAMPLE + SQRT_SAMPLE + PRE_SAMPLE - 1) begin
                        clk_en_div <= 4'b0111;
                    end else if (s_count == PRE_SAMPLE + SQRT_SAMPLE + PRE_SAMPLE) begin
                        clk_en_pre_sub <= 4'b0000;
                    end else if (s_count == PRE_SAMPLE + SQRT_SAMPLE + PRE_SAMPLE + DIV_SAMPLE) begin
                        clk_en_div <= 4'b0000;
                        clk_en_mac <= 4'b0111;
                    end else if (s_count == COL_I_LATENCY) begin
                        clk_en_mac <= 4'b0011;
                        clk_en_pre_sub <= 4'b1000; // Enable clock to Pre-formatter module dedicated to square root module (MSB).
                        clk_en_sqrt <= 1'b1;
                    end

                    // "Lazy forward accumulations"
                    // ----------------------------
                    if (s_count == 1) begin
                        mac_0_a <= div_2_out;
                        mac_1_a <= div_2_out;
                        mac_1_b <= div_3_out;
                        mac_2_a <= div_2_out;
                        mac_2_b <= div_4_out;
                    end else if (s_count == 1 + MAC_SAMPLE) begin
                        mac_0_a <= div_3_out;
                        mac_1_a <= div_3_out;
                        mac_1_b <= div_4_out;

                        run_sum[4] <= mac_0_p; // L_33
                        run_sum[5] <= mac_1_p; // L_43
                        run_sum[6] <= mac_2_p; // L_53
                    end else if (s_count == 1 + 2 * MAC_SAMPLE) begin
                        mac_0_a <= div_4_out;

                        run_sum[7] <= mac_0_p; // L_44
                        run_sum[8] <= mac_1_p; // L_54
                    end else if (s_count == 1 + 3 * MAC_SAMPLE) begin
                        run_sum[9] <= mac_0_p; // L_55
                    end

                    // Data input signals
                    // --------------------
                    if (s_count == PRE_SAMPLE) begin
                        sqrt_data <= pre_sub_sq_out;
                    end else if (s_count == PRE_SAMPLE + SQRT_SAMPLE) begin
                        pre_sub_1_a <= A_32;
                        pre_sub_1_b <= run_sum[1][47 : 16];
                        pre_sub_2_a <= A_42;
                        pre_sub_2_b <= run_sum[2][47 : 16];
                        pre_sub_3_a <= A_52;
                        pre_sub_3_b <= run_sum[3][47 : 16];
                    end else if (s_count == PRE_SAMPLE + SQRT_SAMPLE + PRE_SAMPLE) begin
                        div_divisor <= sqrt_out;
                        div_dividend[0] <= pre_sub_1_out;
                        div_dividend[1] <= pre_sub_2_out;
                        div_dividend[2] <= pre_sub_3_out;
                    end else if (s_count == PRE_SAMPLE + SQRT_SAMPLE + PRE_SAMPLE + DIV_SAMPLE) begin
                        mac_0_a <= div_1_out;
                        mac_c[0] <= run_sum[4]; // L_33
                        mac_1_a <= div_1_out;
                        mac_1_b <= div_2_out;
                        mac_c[1] <= run_sum[5]; // L_43
                        mac_2_a <= div_1_out;
                        mac_2_b <= div_3_out;
                        mac_c[2] <= run_sum[6]; // L_53
                    end else if (s_count == COL_I_LATENCY) begin // Set up inputs for first operation of next state.
                        pre_sub_sq_a <= A_33;
                        pre_sub_sq_b <= mac_0_p[47 : 16];

                        // Reset input signals to unused modules.
                        div_dividend[2] <= {32{1'b0}};
                        pre_sub_3_a <= {32{1'b0}};
                        pre_sub_3_b <= {32{1'b0}};
                        run_sum[0] <= {64{1'b0}}; // L_22
                        run_sum[1] <= {64{1'b0}}; // L_32
                        run_sum[2] <= {64{1'b0}}; // L_42
                        run_sum[3] <= {64{1'b0}}; // L_52
                    end

                    // Extract running sum from MAC units
                    // ----------------------------------
                    if (s_count == COL_I_LATENCY) begin
                        run_sum[4] <= mac_0_p; // L_33
                        run_sum[5] <= mac_1_p; // L_43
                        run_sum[6] <= mac_2_p; // L_53
                    end

                    // Extract elements of the lower Cholesky factor
                    // ---------------------------------------------
                    if (s_count == COL_I_LATENCY) begin
                        L[95 : 64]   <= sqrt_out;  // L_22
                        L[159 : 128] <= div_1_out; // L_32
                        L[255 : 224] <= div_2_out; // L_42
                        L[383 : 352] <= div_3_out; // L_52
                    end
                end
                S_COL_3: begin
                    if (s_count == COL_I_LATENCY) begin
                        state <= S_COL_4;
                    end else begin
                        state <= S_COL_3;
                    end

                    // State counter
                    // -------------
                    if (s_count == COL_I_LATENCY) begin
                        s_count <= 8'b0000_0001;
                    end else begin
                        s_count <= s_count + 8'b0000_0001;
                    end

                    // Clock enable signals
                    // --------------------
                    if (s_count == 1 + MAC_SAMPLE) begin
                        clk_en_mac <= 4'b0001;
                    end else if (s_count == 1 + 2 * MAC_SAMPLE) begin
                        clk_en_mac <= 4'b0000;
                    end else if (s_count == PRE_SAMPLE) begin
                        clk_en_pre_sub <= 4'b0000; // Disable clock to Pre-formatter module dedicated to square root module (MSB).
                    end else if (s_count == PRE_SAMPLE + SQRT_SAMPLE) begin
                        clk_en_sqrt <= 1'b0;
                        clk_en_pre_sub <= 4'b0011; // Enable clock to Pre-formatter module (non square root modules).
                    end else if (s_count == PRE_SAMPLE + SQRT_SAMPLE + PRE_SAMPLE - 1) begin
                        clk_en_div <= 4'b0011;
                    end else if (s_count == PRE_SAMPLE + SQRT_SAMPLE + PRE_SAMPLE) begin
                        clk_en_pre_sub <= 4'b0000;
                    end else if (s_count == PRE_SAMPLE + SQRT_SAMPLE + PRE_SAMPLE + DIV_SAMPLE) begin
                        clk_en_div <= 4'b0000;
                        clk_en_mac <= 4'b0011;
                    end else if (s_count == COL_I_LATENCY) begin
                        clk_en_mac <= 4'b0001;
                        clk_en_pre_sub <= 4'b1000; // Enable clock to Pre-formatter module dedicated to square root module (MSB).
                        clk_en_sqrt <= 1'b1;
                    end

                    // "Lazy forward accumulations"
                    // ----------------------------
                    if (s_count == 1) begin
                        mac_0_a <= div_2_out;
                        mac_c[0] <= run_sum[7]; // L_44
                        mac_1_a <= div_2_out;
                        mac_1_b <= div_3_out;
                        mac_c[1] <= run_sum[8]; // L_54
                    end else if (s_count == 1 + MAC_SAMPLE) begin
                        mac_0_a <= div_3_out;
                        mac_c[0] <= run_sum[9]; // L_55

                        run_sum[7] <= mac_0_p; // L_44
                        run_sum[8] <= mac_1_p; // L_54
                    end else if (s_count == 1 + 2 * MAC_SAMPLE) begin
                        run_sum[9] <= mac_0_p; // L_55
                    end

                    // Data input signals
                    // --------------------
                    if (s_count == PRE_SAMPLE) begin
                        sqrt_data <= pre_sub_sq_out;
                    end else if (s_count == PRE_SAMPLE + SQRT_SAMPLE) begin
                        pre_sub_1_a <= A_43;
                        pre_sub_1_b <= run_sum[5][47 : 16];
                        pre_sub_2_a <= A_53;
                        pre_sub_2_b <= run_sum[6][47 : 16];
                    end else if (s_count == PRE_SAMPLE + SQRT_SAMPLE + PRE_SAMPLE) begin
                        div_divisor <= sqrt_out;
                        div_dividend[0] <= pre_sub_1_out;
                        div_dividend[1] <= pre_sub_2_out;
                    end else if (s_count == PRE_SAMPLE + SQRT_SAMPLE + PRE_SAMPLE + DIV_SAMPLE) begin
                        mac_0_a <= div_1_out;
                        mac_c[0] <= run_sum[7]; // L_44
                        mac_1_a <= div_1_out;
                        mac_1_b <= div_2_out;
                        mac_c[1] <= run_sum[8]; // L_54
                    end else if (s_count == COL_I_LATENCY) begin // Set up inputs for first operation of next state.
                        pre_sub_sq_a <= A_44;
                        pre_sub_sq_b <= mac_0_p[47 : 16];

                        // Reset input signals to unused modules.
                        div_dividend[1] <= {32{1'b0}};
                        pre_sub_2_a <= {32{1'b0}};
                        pre_sub_2_b <= {32{1'b0}};
                        run_sum[4] <= {64{1'b0}}; // L_33
                        run_sum[5] <= {64{1'b0}}; // L_43
                        run_sum[6] <= {64{1'b0}}; // L_53
                    end

                    // Extract running sum from MAC units
                    // ----------------------------------
                    if (s_count == COL_I_LATENCY) begin
                        run_sum[7] <= mac_0_p; // L_44
                        run_sum[8] <= mac_1_p; // L_54
                    end

                    // Extract elements of the lower Cholesky factor
                    // ---------------------------------------------
                    if (s_count == COL_I_LATENCY) begin
                        L[191 : 160] <= sqrt_out;  // L_33
                        L[287 : 256] <= div_1_out; // L_43
                        L[415 : 384] <= div_2_out; // L_53
                    end
                end
                S_COL_4: begin
                    if (s_count == COL_I_LATENCY) begin
                        state <= S_COL_5;
                    end else begin
                        state <= S_COL_4;
                    end

                    // State counter
                    // -------------
                    if (s_count == COL_I_LATENCY) begin
                        s_count <= 8'b0000_0001;
                    end else begin
                        s_count <= s_count + 8'b0000_0001;
                    end

                    // Clock enable signals
                    // --------------------
                    if (s_count == 1 + MAC_SAMPLE) begin
                        clk_en_mac <= 4'b0000;
                    end else if (s_count == PRE_SAMPLE) begin
                        clk_en_pre_sub <= 4'b0000; // Disable clock to Pre-formatter module dedicated to square root module (MSB).
                    end else if (s_count == PRE_SAMPLE + SQRT_SAMPLE) begin
                        clk_en_pre_sub <= 4'b0001; // Enable clock to Pre-formatter module (non square root modules).
                        clk_en_sqrt <= 1'b0;
                    end else if (s_count == PRE_SAMPLE + SQRT_SAMPLE + PRE_SAMPLE - 1) begin
                        clk_en_div <= 4'b0001;
                    end else if (s_count == PRE_SAMPLE + SQRT_SAMPLE + PRE_SAMPLE) begin
                        clk_en_pre_sub <= 4'b0000;
                    end else if (s_count == PRE_SAMPLE + SQRT_SAMPLE + PRE_SAMPLE + DIV_SAMPLE) begin
                        clk_en_div <= 4'b0000;
                        clk_en_mac <= 4'b0001;
                    end else if (s_count == COL_I_LATENCY) begin
                        clk_en_mac <= 4'b0000;
                        clk_en_pre_sub <= 4'b1000; // Enable clock to Pre-formatter module dedicated to square root module (MSB).
                        clk_en_sqrt <= 1'b1;
                    end

                    // "Lazy forward accumulations"
                    // ----------------------------
                    if (s_count == 1 + MAC_SAMPLE) begin
                        run_sum[9] <= mac_0_p; // L_55
                    end else if (s_count == 1) begin
                        mac_0_a <= div_2_out;
                        mac_c[0] <= run_sum[9]; // L_55
                    end

                    // Data input signals
                    // --------------------
                    if (s_count == PRE_SAMPLE) begin
                        sqrt_data <= pre_sub_sq_out;
                    end else if (s_count == PRE_SAMPLE + SQRT_SAMPLE) begin
                        pre_sub_1_a <= A_54;
                        pre_sub_1_b <= run_sum[8][47 : 16];
                    end else if (s_count == PRE_SAMPLE + SQRT_SAMPLE + PRE_SAMPLE) begin
                        div_divisor <= sqrt_out;
                        div_dividend[0] <= pre_sub_1_out;
                    end else if (s_count == PRE_SAMPLE + SQRT_SAMPLE + PRE_SAMPLE + DIV_SAMPLE) begin
                        mac_0_a <= div_1_out;
                        mac_c[0] <= run_sum[9]; // L_55
                    end else if (s_count == COL_I_LATENCY) begin // Set up inputs for first operation of next state.
                        pre_sub_sq_a <= A_55;
                        pre_sub_sq_b <= mac_0_p[47 : 16];

                        // Reset input signals to unused modules.
                        div_dividend[0] <= {32{1'b0}};
                        div_divisor <= {32{1'b0}};
                        pre_sub_1_a <= {32{1'b0}};
                        pre_sub_1_b <= {32{1'b0}};
                        run_sum[7] <= {64{1'b0}}; // L_44
                        run_sum[8] <= {64{1'b0}}; // L_54
                    end

                    // Extract running sum from MAC units
                    // ----------------------------------
                    if (s_count == COL_I_LATENCY) begin
                        L[479 : 448] <= mac_0_p[47 : 16]; // L_55
                    end

                    // Extract elements of the lower Cholesky factor
                    // ---------------------------------------------
                    if (s_count == COL_I_LATENCY) begin
                        L[319 : 288] <= sqrt_out;  // L_44
                        L[447 : 416] <= div_1_out; // L_54
                    end
                end
                S_COL_5: begin
                    if (s_count == COL_N_LATENCY) begin
                        state <= S_IDLE;
                    end else begin
                        state <= S_COL_5;
                    end

                    // State counter
                    // -------------
                    if (s_count == COL_I_LATENCY) begin
                        s_count <= 8'b0000_0001;
                    end else begin
                        s_count <= s_count + 8'b0000_0001;
                    end

                    // Clock enable signals
                    // --------------------
                    if (s_count == PRE_SAMPLE) begin
                        clk_en_pre_sub <= 4'b0000; // Disable clock to Pre-formatter module dedicated to square root module (MSB).
                    end else if (s_count == COL_N_LATENCY) begin
                        clk_en_sqrt <= 1'b0;
                    end

                    // Data input signals
                    // --------------------
                    if (s_count == PRE_SAMPLE) begin
                        sqrt_data <= pre_sub_sq_out;
                    end else if (s_count == COL_N_LATENCY) begin
                        // Reset input signals to unused modules.
                        pre_sub_sq_a <= {32{1'b0}};
                        pre_sub_sq_b <= {32{1'b0}};
                        run_sum[9] <= {64{1'b0}}; // L_55
                    end

                    // Extract elements of the lower Cholesky factor
                    // ---------------------------------------------
                    if (s_count == COL_N_LATENCY) begin
                        L[479 : 448] <= sqrt_out;  // L_55
                        L_valid <= 1'b1;
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
     * Latency is SQRT_SAMPLE
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
    assign sqrt_out = { {8{1'b0}}, sqrt_out_t };

// ================================================================================
    /* N - 1 Divider modules
     * ---------------------
     * Latency for Divider IP is DIV_SAMPLE
     * Total latency is DIV_SAMPLE + 1
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
    /* N - 1 Multiply-ACcumulate (MAC) modules
     * ---------------------------------------------------------
     * Latency is MAC_SAMPLE
     */

    pe_matrix_ip_mac mac_0 (
        .CLK      (clk),
        .SCLR     (rst),
        .CE       (clk_en_mac[0]),
        .A        (mac_0_a),
        .B        (mac_0_a),
        .C        (mac_c[0]),
        .SUBTRACT (1'b0), // Add
        .P        (mac_0_p),
        .PCOUT    () // Not connected since pe_matrix_ip_mac spans multiple DSP slices
        );

    pe_matrix_ip_mac mac_1 (
        .CLK      (clk),
        .SCLR     (rst),
        .CE       (clk_en_mac[1]),
        .A        (mac_1_a),
        .B        (mac_1_b),
        .C        (mac_c[1]),
        .SUBTRACT (1'b0), // Add
        .P        (mac_1_p),
        .PCOUT    () // Not connected since pe_matrix_ip_mac spans multiple DSP slices
        );

    pe_matrix_ip_mac mac_2 (
        .CLK      (clk),
        .SCLR     (rst),
        .CE       (clk_en_mac[2]),
        .A        (mac_2_a),
        .B        (mac_2_b),
        .C        (mac_c[2]),
        .SUBTRACT (1'b0), // Add
        .P        (mac_2_p),
        .PCOUT    () // Not connected since pe_matrix_ip_mac spans multiple DSP slices
        );

    pe_matrix_ip_mac mac_3 (
        .CLK      (clk),
        .SCLR     (rst),
        .CE       (clk_en_mac[3]),
        .A        (mac_3_a),
        .B        (mac_3_b),
        .C        (mac_c[3]),
        .SUBTRACT (1'b0), // Add
        .P        (mac_3_p),
        .PCOUT    () // Not connected since pe_matrix_ip_mac spans multiple DSP slices
        );

// ================================================================================
    /* (N - 1) Subtractor modules to "pre-format"
     * ------------------------------------------
     * Latency is PRE_SAMPLE
     */

    cholesky_ip_sub pre_sub_1 (
        .A   (pre_sub_1_a),
        .B   (pre_sub_1_b),
        .CLK (clk),
        .CE  (clk_en_pre_sub[0]),
        .S   (pre_sub_1_out)
        );

    cholesky_ip_sub pre_sub_2 (
        .A   (pre_sub_2_a),
        .B   (pre_sub_2_b),
        .CLK (clk),
        .CE  (clk_en_pre_sub[1]),
        .S   (pre_sub_2_out)
        );

    cholesky_ip_sub pre_sub_3 (
        .A   (pre_sub_3_a),
        .B   (pre_sub_3_b),
        .CLK (clk),
        .CE  (clk_en_pre_sub[2]),
        .S   (pre_sub_3_out)
        );

    // Dedicated for square root
    cholesky_ip_sub pre_sub_sq (
        .A   (pre_sub_sq_a),
        .B   (pre_sub_sq_b),
        .CLK (clk),
        .CE  (clk_en_pre_sub[3]),
        .S   (pre_sub_sq_out)
        );

endmodule
