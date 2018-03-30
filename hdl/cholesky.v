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
    localparam DIV_SAMPLE  = 56;
    localparam SQRT_SAMPLE = 27;
    localparam MAC_SAMPLE  = 10;

    /* Computation of column I of Cholesky factor takes SQRT_SAMPLE + DIV_SAMPLE + MAC_SAMPLE cycles, for I = 2..N-1 
     * Computation of column N of Cholesky factor takes SQRT_SAMPLE cycles
     */
    localparam COL_I_LATENCY = SQRT_SAMPLE + DIV_SAMPLE + MAC_SAMPLE;
    localparam COL_N_LATENCY = SQRT_SAMPLE;

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
    wire          div_dividend_valid [3 : 0];
    wire [31 : 0] div_out [3 : 0], sqrt_out;
    wire [63 : 0] mac_p [3 : 0];
    reg           clk_en_sqrt, sqrt_data_valid_d1, count_en;
    reg           clk_en_div [3 : 0], clk_en_mac [3 : 0], div_dividend_valid_d1 [3 : 0];
    reg   [5 : 0] state;
    reg  [31 : 0] sqrt_data, div_divisor, div_dividend [3 : 0], mac_a [3 : 0], mac_b [3 : 0];
    reg  [63 : 0] mac_c [3 : 0];
    reg  [63 : 0] run_sum [9 : 0];

    reg [COUNT_WIDTH-1 : 0] s_count;

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            s_count <= 8'b0000_0000;

            clk_en_sqrt <= 1'b0;
            clk_en_div[0] <= 1'b0;
            clk_en_div[1] <= 1'b0;
            clk_en_div[2] <= 1'b0;
            clk_en_div[3] <= 1'b0;
            clk_en_mac[0] <= 1'b0;
            clk_en_mac[1] <= 1'b0;
            clk_en_mac[2] <= 1'b0;
            clk_en_mac[3] <= 1'b0;

            sqrt_data <= {32{1'b0}};
            div_divisor <= {{15{1'b0}}, 1'b1, {16{1'b0}}}; // Don't want 0.0 in the denominator, so 1.0.
            div_dividend[0] <= {32{1'b0}};
            div_dividend[1] <= {32{1'b0}};
            div_dividend[2] <= {32{1'b0}};
            div_dividend[3] <= {32{1'b0}};
            mac_a[0] <= {32{1'b0}};
            mac_b[0] <= {32{1'b0}};
            mac_c[0] <= {64{1'b0}};
            mac_a[1] <= {32{1'b0}};
            mac_b[1] <= {32{1'b0}};
            mac_c[1] <= {64{1'b0}};
            mac_a[2] <= {32{1'b0}};
            mac_b[2] <= {32{1'b0}};
            mac_c[2] <= {64{1'b0}};
            mac_a[3] <= {32{1'b0}};
            mac_b[3] <= {32{1'b0}};
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
                        L_valid <= 1'b0;

                        sqrt_data <= A_11;
                        clk_en_sqrt <= 1'b1; // Enable clock for the first operation, square root
                    end
                end
                S_COL_1: begin
                    if (s_count == COL_I_LATENCY) begin
                        state <= S_COL_2;
                    end else begin
                        state <= S_COL_1;
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
                    if (s_count == SQRT_SAMPLE) begin
                        clk_en_div[0] <= 1'b1;
                        clk_en_div[1] <= 1'b1;
                        clk_en_div[2] <= 1'b1;
                        clk_en_div[3] <= 1'b1;

                        clk_en_sqrt <= 1'b0;
                    end else if (s_count == SQRT_SAMPLE + DIV_SAMPLE) begin
                        clk_en_div[0] <= 1'b0;
                        clk_en_div[1] <= 1'b0;
                        clk_en_div[2] <= 1'b0;
                        clk_en_div[3] <= 1'b0;
                        clk_en_mac[0] <= 1'b1;
                        clk_en_mac[1] <= 1'b1;
                        clk_en_mac[2] <= 1'b1;
                        clk_en_mac[3] <= 1'b1;
                    end else if (s_count == COL_I_LATENCY) begin
                        clk_en_mac[0] <= 1'b0;
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
                        mac_a[0] <= div_out[0];
                        mac_b[0] <= div_out[0];
                        mac_c[0] <= A_22[31] ? {16'hffff, A_22, 16'h0000} : {16'h0000, A_22, 16'h0000};
                        mac_a[1] <= div_out[0];
                        mac_b[1] <= div_out[1];
                        mac_c[1] <= A_32[31] ? {16'hffff, A_32, 16'h0000} : {16'h0000, A_32, 16'h0000};
                        mac_a[2] <= div_out[0];
                        mac_b[2] <= div_out[2];
                        mac_c[2] <= A_42[31] ? {16'hffff, A_42, 16'h0000} : {16'h0000, A_42, 16'h0000};
                        mac_a[3] <= div_out[0];
                        mac_b[3] <= div_out[3];
                        mac_c[3] <= A_52[31] ? {16'hffff, A_52, 16'h0000} : {16'h0000, A_52, 16'h0000};
                    end else if (s_count == COL_I_LATENCY) begin
                        sqrt_data <= mac_p[0][47 : 16];
                    end

                    // Extract running sum from MAC units
                    // ----------------------------------
                    if (s_count == COL_I_LATENCY) begin
                        run_sum[0] <= mac_p[0]; // L_22
                        run_sum[1] <= mac_p[1]; // L_32
                        run_sum[2] <= mac_p[2]; // L_42
                        run_sum[3] <= mac_p[3]; // L_52
                    end

                    // Extract elements of the lower Cholesky factor
                    // ---------------------------------------------
                    if (s_count == COL_I_LATENCY) begin
                        L[31 : 0]    <= sqrt_out;  // L_11
                        L[63 : 32]   <= div_out[0]; // L_21
                        L[127 : 96]  <= div_out[1]; // L_31
                        L[223 : 192] <= div_out[2]; // L_41
                        L[351 : 320] <= div_out[3]; // L_51
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
                        clk_en_mac[3] <= 1'b0;
                    end else if (s_count == 1 + 2 * MAC_SAMPLE) begin
                        clk_en_mac[2] <= 1'b0;
                    end else if (s_count == 1 + 3 * MAC_SAMPLE) begin
                        clk_en_mac[1] <= 1'b0;
                    end else if (s_count == SQRT_SAMPLE) begin
                        clk_en_div[1] <= 1'b1;
                        clk_en_div[2] <= 1'b1;
                        clk_en_div[3] <= 1'b1;

                        clk_en_sqrt <= 1'b0;
                    end else if (s_count == SQRT_SAMPLE + DIV_SAMPLE) begin
                        clk_en_div[1] <= 1'b0;
                        clk_en_div[2] <= 1'b0;
                        clk_en_div[3] <= 1'b0;

                        clk_en_mac[1] <= 1'b1;
                        clk_en_mac[2] <= 1'b1;
                        clk_en_mac[3] <= 1'b1;
                    end else if (s_count == COL_I_LATENCY) begin
                        clk_en_mac[1] <= 1'b0;
                        clk_en_sqrt <= 1'b1;
                    end

                    // "Lazy forward accumulations"
                    // ----------------------------
                    if (s_count == 1) begin
                        mac_a[1] <= div_out[1];
                        mac_b[1] <= div_out[1];
                        mac_c[1] <= A_33[31] ? {16'hffff, A_33, 16'h0000} : {16'h0000, A_33, 16'h0000};
                        mac_a[2] <= div_out[1];
                        mac_b[2] <= div_out[2];
                        mac_c[2] <= A_43[31] ? {16'hffff, A_43, 16'h0000} : {16'h0000, A_43, 16'h0000};
                        mac_a[3] <= div_out[1];
                        mac_b[3] <= div_out[3];
                        mac_c[3] <= A_53[31] ? {16'hffff, A_53, 16'h0000} : {16'h0000, A_53, 16'h0000};
                    end else if (s_count == 1 + MAC_SAMPLE) begin
                        mac_a[1] <= div_out[2];
                        mac_b[1] <= div_out[2];
                        mac_c[1] <= A_44[31] ? {16'hffff, A_44, 16'h0000} : {16'h0000, A_44, 16'h0000};
                        mac_a[2] <= div_out[2];
                        mac_b[2] <= div_out[3];
                        mac_c[2] <= A_54[31] ? {16'hffff, A_54, 16'h0000} : {16'h0000, A_54, 16'h0000};

                        run_sum[4] <= mac_p[1]; // L_33
                        run_sum[5] <= mac_p[2]; // L_43
                        run_sum[6] <= mac_p[3]; // L_53
                    end else if (s_count == 1 + 2 * MAC_SAMPLE) begin
                        mac_a[1] <= div_out[3];
                        mac_b[1] <= div_out[3];
                        mac_c[1] <= A_55[31] ? {16'hffff, A_55, 16'h0000} : {16'h0000, A_55, 16'h0000};

                        run_sum[7] <= mac_p[1]; // L_44
                        run_sum[8] <= mac_p[2]; // L_54
                    end else if (s_count == 1 + 3 * MAC_SAMPLE) begin
                        run_sum[9] <= mac_p[1]; // L_55
                    end

                    // Data input signals
                    // --------------------
                    if (s_count == SQRT_SAMPLE) begin
                        div_divisor <= sqrt_out;
                        div_dividend[1] <= run_sum[1][47 : 16];
                        div_dividend[2] <= run_sum[2][47 : 16];
                        div_dividend[3] <= run_sum[3][47 : 16];
                    end else if (s_count == SQRT_SAMPLE + DIV_SAMPLE) begin
                        mac_a[1] <= div_out[1];
                        mac_b[1] <= div_out[1];
                        mac_c[1] <= run_sum[4]; // L_33
                        mac_a[2] <= div_out[1];
                        mac_b[2] <= div_out[2];
                        mac_c[2] <= run_sum[5]; // L_43
                        mac_a[3] <= div_out[1];
                        mac_b[3] <= div_out[3];
                        mac_c[3] <= run_sum[6]; // L_53
                    end else if (s_count == COL_I_LATENCY) begin // Set up inputs for first operation of next state.
                        sqrt_data <= mac_p[1][47 : 16];

                        // Reset running sum for columns that are computed.
                        run_sum[0] <= {64{1'b0}}; // L_22
                        run_sum[1] <= {64{1'b0}}; // L_32
                        run_sum[2] <= {64{1'b0}}; // L_42
                        run_sum[3] <= {64{1'b0}}; // L_52
                    end

                    // Extract running sum from MAC units
                    // ----------------------------------
                    if (s_count == COL_I_LATENCY) begin
                        run_sum[4] <= mac_p[1]; // L_33
                        run_sum[5] <= mac_p[2]; // L_43
                        run_sum[6] <= mac_p[3]; // L_53
                    end

                    // Extract elements of the lower Cholesky factor
                    // ---------------------------------------------
                    if (s_count == COL_I_LATENCY) begin
                        L[95 : 64]   <= sqrt_out;  // L_22
                        L[159 : 128] <= div_out[1]; // L_32
                        L[255 : 224] <= div_out[2]; // L_42
                        L[383 : 352] <= div_out[3]; // L_52
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
                        clk_en_mac[3] <= 1'b0;
                    end else if (s_count == 1 + 2 * MAC_SAMPLE) begin
                        clk_en_mac[2] <= 1'b0;
                    end else if (s_count == SQRT_SAMPLE) begin
                        clk_en_div[2] <= 1'b1;
                        clk_en_div[3] <= 1'b1;

                        clk_en_sqrt <= 1'b0;
                    end else if (s_count == SQRT_SAMPLE + DIV_SAMPLE) begin
                        clk_en_div[2] <= 1'b0;
                        clk_en_div[3] <= 1'b0;

                        clk_en_mac[2] <= 1'b1;
                        clk_en_mac[3] <= 1'b1;
                    end else if (s_count == COL_I_LATENCY) begin
                        clk_en_mac[2] <= 1'b0;
                        clk_en_sqrt <= 1'b1;
                    end

                    // "Lazy forward accumulations"
                    // ----------------------------
                    if (s_count == 1) begin
                        mac_a[2] <= div_out[2];
                        mac_b[2] <= div_out[2];
                        mac_c[2] <= run_sum[7]; // L_44
                        mac_a[3] <= div_out[2];
                        mac_b[3] <= div_out[3];
                        mac_c[3] <= run_sum[8]; // L_54
                    end else if (s_count == 1 + MAC_SAMPLE) begin
                        mac_a[2] <= div_out[3];
                        mac_b[2] <= div_out[3];
                        mac_c[2] <= run_sum[9]; // L_55

                        run_sum[7] <= mac_p[2]; // L_44
                        run_sum[8] <= mac_p[3]; // L_54
                    end else if (s_count == 1 + 2 * MAC_SAMPLE) begin
                        run_sum[9] <= mac_p[2]; // L_55
                    end

                    // Data input signals
                    // --------------------
                    if (s_count == SQRT_SAMPLE) begin
                        div_divisor <= sqrt_out;
                        div_dividend[2] <= run_sum[5][47 : 16];
                        div_dividend[3] <= run_sum[6][47 : 16];
                    end else if (s_count == SQRT_SAMPLE + DIV_SAMPLE) begin
                        mac_a[2] <= div_out[2];
                        mac_b[2] <= div_out[2];
                        mac_c[2] <= run_sum[7]; // L_44
                        mac_a[3] <= div_out[2];
                        mac_b[3] <= div_out[3];
                        mac_c[3] <= run_sum[8]; // L_54
                    end else if (s_count == COL_I_LATENCY) begin // Set up inputs for first operation of next state.
                        sqrt_data <= mac_p[2][47 : 16];

                        // Reset running sum for columns that are computed.
                        run_sum[4] <= {64{1'b0}}; // L_33
                        run_sum[5] <= {64{1'b0}}; // L_43
                        run_sum[6] <= {64{1'b0}}; // L_53
                    end

                    // Extract running sum from MAC units
                    // ----------------------------------
                    if (s_count == COL_I_LATENCY) begin
                        run_sum[7] <= mac_p[2]; // L_44
                        run_sum[8] <= mac_p[3]; // L_54
                    end

                    // Extract elements of the lower Cholesky factor
                    // ---------------------------------------------
                    if (s_count == COL_I_LATENCY) begin
                        L[191 : 160] <= sqrt_out;  // L_33
                        L[287 : 256] <= div_out[2]; // L_43
                        L[415 : 384] <= div_out[3]; // L_53
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
                        clk_en_mac[3] <= 1'b0;
                    end else if (s_count == SQRT_SAMPLE) begin
                        clk_en_div[3] <= 1'b1;

                        clk_en_sqrt <= 1'b0;
                    end else if (s_count == SQRT_SAMPLE + DIV_SAMPLE) begin
                        clk_en_div[3] <= 1'b0;

                        clk_en_mac[3] <= 1'b1;
                    end else if (s_count == COL_I_LATENCY) begin
                        clk_en_mac[3] <= 1'b0;
                        clk_en_sqrt <= 1'b1;
                    end

                    // "Lazy forward accumulations"
                    // ----------------------------
                    if (s_count == 1) begin
                        mac_a[3] <= div_out[3];
                        mac_b[3] <= div_out[3];
                        mac_c[3] <= run_sum[9]; // L_55
                    end else if (s_count == 1 + MAC_SAMPLE) begin
                        run_sum[9] <= mac_p[3]; // L_55
                    end

                    // Data input signals
                    // --------------------
                    if (s_count == SQRT_SAMPLE) begin
                        div_divisor <= sqrt_out;
                        div_dividend[3] <= run_sum[8][47 : 16];
                    end else if (s_count == SQRT_SAMPLE + DIV_SAMPLE) begin
                        mac_a[3] <= div_out[3];
                        mac_b[3] <= div_out[3];
                        mac_c[3] <= run_sum[9]; // L_55
                    end else if (s_count == COL_I_LATENCY) begin // Set up inputs for first operation of next state.
                        sqrt_data <= mac_p[3][47 : 16];

                        // Reset running sum for columns that are computed.
                        run_sum[7] <= {64{1'b0}}; // L_44
                        run_sum[8] <= {64{1'b0}}; // L_54
                    end

                    // Extract running sum from MAC units
                    // ----------------------------------
                    if (s_count == COL_I_LATENCY) begin
                        run_sum[9] <= mac_p[3][47 : 16]; // L_55
                    end

                    // Extract elements of the lower Cholesky factor
                    // ---------------------------------------------
                    if (s_count == COL_I_LATENCY) begin
                        L[319 : 288] <= sqrt_out;  // L_44
                        L[447 : 416] <= div_out[3]; // L_54
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
                    if (s_count == COL_N_LATENCY) begin
                        s_count <= 8'b0000_0000;
                    end else begin
                        s_count <= s_count + 8'b0000_0001;
                    end

                    // Clock enable signals
                    // --------------------
                    if (s_count == COL_N_LATENCY) begin
                        clk_en_sqrt <= 1'b0;
                    end

                    // Reset running sum for columns that are computed.
                    if (s_count == COL_N_LATENCY) begin
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

        div_dividend_valid_d1[0] <= clk_en_div[0];
        div_dividend_valid_d1[1] <= clk_en_div[1];
        div_dividend_valid_d1[2] <= clk_en_div[2];
        div_dividend_valid_d1[3] <= clk_en_div[3];
    end

    assign sqrt_data_valid = ~sqrt_data_valid_d1 & clk_en_sqrt;
    assign div_dividend_valid[0] = ~div_dividend_valid_d1[0] & clk_en_div[0];
    assign div_dividend_valid[1] = ~div_dividend_valid_d1[1] & clk_en_div[1];
    assign div_dividend_valid[2] = ~div_dividend_valid_d1[2] & clk_en_div[2];
    assign div_dividend_valid[3] = ~div_dividend_valid_d1[3] & clk_en_div[3];

    // Divisor input is valid anytime a dividend input is valid.
    assign div_divisor_valid = div_dividend_valid[0] | div_dividend_valid[1] | div_dividend_valid[2] | div_dividend_valid[3];

// ================================================================================
    /* Square root module
     * ------------------
     * Latency is SQRT_SAMPLE
     */

    chol_sqrt sqrt_0 (
        .clk        (clk),
        .clken      (clk_en_sqrt),
        .rst        (rst),
        .data_valid (sqrt_data_valid),
        .data       (sqrt_data),
        .out        (sqrt_out)
    );

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

    chol_div div_0 (
        .clk            (clk),
        .clken          (clk_en_div[0]),
        .rst            (rst),
        .divisor_valid  (div_divisor_valid),
        .divisor        (div_divisor),
        .dividend_valid (div_dividend_valid[0]),
        .dividend       (div_dividend[0]),
        .out            (div_out[0])
    );

    chol_div div_1 (
        .clk            (clk),
        .clken          (clk_en_div[1]),
        .rst            (rst),
        .divisor_valid  (div_divisor_valid),
        .divisor        (div_divisor),
        .dividend_valid (div_dividend_valid[1]),
        .dividend       (div_dividend[1]),
        .out            (div_out[1])
    );

    chol_div div_2 (
        .clk            (clk),
        .clken          (clk_en_div[2]),
        .rst            (rst),
        .divisor_valid  (div_divisor_valid),
        .divisor        (div_divisor),
        .dividend_valid (div_dividend_valid[2]),
        .dividend       (div_dividend[2]),
        .out            (div_out[2])
    );

    chol_div div_3 (
        .clk            (clk),
        .clken          (clk_en_div[3]),
        .rst            (rst),
        .divisor_valid  (div_divisor_valid),
        .divisor        (div_divisor),
        .dividend_valid (div_dividend_valid[3]),
        .dividend       (div_dividend[3]),
        .out            (div_out[3])
    );

// ================================================================================
    /* N - 1 Multiply-ACcumulate (MAC) modules
     * ---------------------------------------------------------
     * Latency is MAC_SAMPLE
     */

    chol_mac mac_0 (
        .clk   (clk),
        .clken (clk_en_mac[0]),
        .rst   (rst),
        .a     (mac_a[0]),
        .b     (mac_a[0]),
        .c     (mac_c[0]),
        .out   (mac_p[0])
    );

    chol_mac mac_1 (
        .clk   (clk),
        .clken (clk_en_mac[1]),
        .rst   (rst),
        .a     (mac_a[1]),
        .b     (mac_b[1]),
        .c     (mac_c[1]),
        .out   (mac_p[1])
    );

    chol_mac mac_2 (
        .clk   (clk),
        .clken (clk_en_mac[2]),
        .rst   (rst),
        .a     (mac_a[2]),
        .b     (mac_b[2]),
        .c     (mac_c[2]),
        .out   (mac_p[2])
    );

    chol_mac mac_3 (
        .clk   (clk),
        .clken (clk_en_mac[3]),
        .rst   (rst),
        .a     (mac_a[3]),
        .b     (mac_b[3]),
        .c     (mac_c[3]),
        .out   (mac_p[3])
    );

endmodule
