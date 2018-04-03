`timescale 1ns / 1ps

module cholesky_5 (
    input wire           clk,
    input wire           clk_en, // TODO: Does not handle this right now, but kept around for future use.
    input wire           rst,
    input wire [479 : 0] A,
    input wire           A_valid,

    output reg [479 : 0] L,
    output reg           L_valid
    );

    localparam N             = 5; // Size of the matrix.
    localparam COUNT_WIDTH   = 8; // Enough bits to hold the maximum number of cycles a column can take.
    localparam STATE_WIDTH   = 6;
    localparam INV_SQRT_ITER = 1;

    // Number of clock cycles to wait for sampling output after input valid signal.
    localparam MULT_SAMPLE     = 7;
    localparam INV_SQRT_SAMPLE = 39 + ((INV_SQRT_ITER - 1) * 18) + 1;
    localparam MAC_SAMPLE      = 10;
    localparam SQRT_SAMPLE     = 27;

    /* Computation of column I of Cholesky factor takes INV_SQRT_SAMPLE + MULT_SAMPLE + MAC_SAMPLE cycles, for I = 1..N-1 
     * Computation of column N of Cholesky factor takes INV_SQRT_SAMPLE cycles
     */
    localparam COL_I_LATENCY = INV_SQRT_SAMPLE + MULT_SAMPLE + MAC_SAMPLE;
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

    wire          inv_sqrt_data_valid;
    wire [31 : 0] mult_out [3 : 0], inv_sqrt_out, sqrt_out;
    wire [63 : 0] mac_out [3 : 0];
    reg           clk_en_inv_sqrt, clk_en_inv_sqrt_d1, clk_en_sqrt, clk_en_mult [3 : 0];
    reg  [31 : 0] inv_sqrt_data, mult_a, mult_b [3 : 0], mac_a [3 : 0], mac_b [3 : 0];
    reg  [63 : 0] mac_c [3 : 0], run_sum [9 : 0];

    reg [STATE_WIDTH-1 : 0] state;
    reg [COUNT_WIDTH-1 : 0] s_count;

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            s_count <= 8'b0000_0000;

            clk_en_inv_sqrt <= 1'b0;
            clk_en_sqrt <= 1'b0;
            clk_en_mult[0] <= 1'b0;
            clk_en_mult[1] <= 1'b0;
            clk_en_mult[2] <= 1'b0;
            clk_en_mult[3] <= 1'b0;

            inv_sqrt_data <= {32{1'b0}};
            mult_a <= {32{1'b0}};
            mult_b[0] <= {32{1'b0}};
            mult_b[1] <= {32{1'b0}};
            mult_b[2] <= {32{1'b0}};
            mult_b[3] <= {32{1'b0}};
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

                        inv_sqrt_data <= A_11;
                        // Enable clock for the first operation, square root and fast inverse square root
                        clk_en_inv_sqrt <= 1'b1;
                        clk_en_sqrt <= 1'b1;
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
                        clk_en_sqrt <= 1'b0;
                    end else if (s_count == INV_SQRT_SAMPLE) begin
                        clk_en_mult[0] <= 1'b1;
                        clk_en_mult[1] <= 1'b1;
                        clk_en_mult[2] <= 1'b1;
                        clk_en_mult[3] <= 1'b1;
                        clk_en_inv_sqrt <= 1'b0;
                    end else if (s_count == INV_SQRT_SAMPLE + MULT_SAMPLE) begin
                        clk_en_mult[0] <= 1'b0;
                        clk_en_mult[1] <= 1'b0;
                        clk_en_mult[2] <= 1'b0;
                        clk_en_mult[3] <= 1'b0;
                    end else if (s_count == COL_I_LATENCY) begin
                        clk_en_inv_sqrt <= 1'b1;
                        clk_en_sqrt <= 1'b1;
                    end

                    // Data input signals
                    // --------------------
                    if (s_count == INV_SQRT_SAMPLE) begin
                        mult_a <= inv_sqrt_out;
                        mult_b[0] <= A_21;
                        mult_b[1] <= A_31;
                        mult_b[2] <= A_41;
                        mult_b[3] <= A_51;
                    end else if (s_count == INV_SQRT_SAMPLE + MULT_SAMPLE) begin
                        mac_a[0] <= mult_out[0];
                        mac_b[0] <= mult_out[0];
                        mac_c[0] <= A_22[31] ? {16'hffff, A_22, 16'h0000} : {16'h0000, A_22, 16'h0000};
                        mac_a[1] <= mult_out[0];
                        mac_b[1] <= mult_out[1];
                        mac_c[1] <= A_32[31] ? {16'hffff, A_32, 16'h0000} : {16'h0000, A_32, 16'h0000};
                        mac_a[2] <= mult_out[0];
                        mac_b[2] <= mult_out[2];
                        mac_c[2] <= A_42[31] ? {16'hffff, A_42, 16'h0000} : {16'h0000, A_42, 16'h0000};
                        mac_a[3] <= mult_out[0];
                        mac_b[3] <= mult_out[3];
                        mac_c[3] <= A_52[31] ? {16'hffff, A_52, 16'h0000} : {16'h0000, A_52, 16'h0000};
                    end else if (s_count == COL_I_LATENCY) begin
                        inv_sqrt_data <= mac_out[0][47 : 16];
                    end

                    // Extract running sum from MAC units
                    // ----------------------------------
                    if (s_count == COL_I_LATENCY) begin
                        run_sum[0] <= mac_out[0]; // L_22
                        run_sum[1] <= mac_out[1]; // L_32
                        run_sum[2] <= mac_out[2]; // L_42
                        run_sum[3] <= mac_out[3]; // L_52
                    end

                    // Extract elements of the lower Cholesky factor
                    // ---------------------------------------------
                    if (s_count == SQRT_SAMPLE) begin
                        L[31 : 0]    <= sqrt_out;    // L_11
                    end else if (s_count == INV_SQRT_SAMPLE + MULT_SAMPLE) begin
                        L[63 : 32]   <= mult_out[0]; // L_21
                        L[127 : 96]  <= mult_out[1]; // L_31
                        L[223 : 192] <= mult_out[2]; // L_41
                        L[351 : 320] <= mult_out[3]; // L_51
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
                    if (s_count == SQRT_SAMPLE) begin
                        clk_en_sqrt <= 1'b0;
                    end else if (s_count == INV_SQRT_SAMPLE) begin
                        clk_en_mult[1] <= 1'b1;
                        clk_en_mult[2] <= 1'b1;
                        clk_en_mult[3] <= 1'b1;
                        clk_en_inv_sqrt <= 1'b0;
                    end else if (s_count == INV_SQRT_SAMPLE + MULT_SAMPLE) begin
                        clk_en_mult[1] <= 1'b0;
                        clk_en_mult[2] <= 1'b0;
                        clk_en_mult[3] <= 1'b0;
                    end else if (s_count == COL_I_LATENCY) begin
                        clk_en_inv_sqrt <= 1'b1;
                        clk_en_sqrt <= 1'b1;
                    end

                    // "Lazy forward accumulations"
                    // ----------------------------
                    if (s_count == 1) begin
                        mac_a[1] <= mult_out[1];
                        mac_b[1] <= mult_out[1];
                        mac_c[1] <= A_33[31] ? {16'hffff, A_33, 16'h0000} : {16'h0000, A_33, 16'h0000};
                        mac_a[2] <= mult_out[1];
                        mac_b[2] <= mult_out[2];
                        mac_c[2] <= A_43[31] ? {16'hffff, A_43, 16'h0000} : {16'h0000, A_43, 16'h0000};
                        mac_a[3] <= mult_out[1];
                        mac_b[3] <= mult_out[3];
                        mac_c[3] <= A_53[31] ? {16'hffff, A_53, 16'h0000} : {16'h0000, A_53, 16'h0000};
                    end else if (s_count == 1 + MAC_SAMPLE) begin
                        mac_a[1] <= mult_out[2];
                        mac_b[1] <= mult_out[2];
                        mac_c[1] <= A_44[31] ? {16'hffff, A_44, 16'h0000} : {16'h0000, A_44, 16'h0000};
                        mac_a[2] <= mult_out[2];
                        mac_b[2] <= mult_out[3];
                        mac_c[2] <= A_54[31] ? {16'hffff, A_54, 16'h0000} : {16'h0000, A_54, 16'h0000};

                        run_sum[4] <= mac_out[1]; // L_33
                        run_sum[5] <= mac_out[2]; // L_43
                        run_sum[6] <= mac_out[3]; // L_53
                    end else if (s_count == 1 + 2 * MAC_SAMPLE) begin
                        mac_a[1] <= mult_out[3];
                        mac_b[1] <= mult_out[3];
                        mac_c[1] <= A_55[31] ? {16'hffff, A_55, 16'h0000} : {16'h0000, A_55, 16'h0000};

                        run_sum[7] <= mac_out[1]; // L_44
                        run_sum[8] <= mac_out[2]; // L_54
                    end else if (s_count == 1 + 3 * MAC_SAMPLE) begin
                        run_sum[9] <= mac_out[1]; // L_55
                    end

                    // Data input signals
                    // --------------------
                    if (s_count == INV_SQRT_SAMPLE) begin
                        mult_a <= inv_sqrt_out;
                        mult_b[1] <= run_sum[1][47 : 16];
                        mult_b[2] <= run_sum[2][47 : 16];
                        mult_b[3] <= run_sum[3][47 : 16];
                    end else if (s_count == INV_SQRT_SAMPLE + MULT_SAMPLE) begin
                        mac_a[1] <= mult_out[1];
                        mac_b[1] <= mult_out[1];
                        mac_c[1] <= run_sum[4]; // L_33
                        mac_a[2] <= mult_out[1];
                        mac_b[2] <= mult_out[2];
                        mac_c[2] <= run_sum[5]; // L_43
                        mac_a[3] <= mult_out[1];
                        mac_b[3] <= mult_out[3];
                        mac_c[3] <= run_sum[6]; // L_53
                    end else if (s_count == COL_I_LATENCY) begin // Set up inputs for first operation of next state.
                        inv_sqrt_data <= mac_out[1][47 : 16];

                        // Reset running sum for columns that are computed.
                        run_sum[0] <= {64{1'b0}}; // L_22
                        run_sum[1] <= {64{1'b0}}; // L_32
                        run_sum[2] <= {64{1'b0}}; // L_42
                        run_sum[3] <= {64{1'b0}}; // L_52
                    end

                    // Extract running sum from MAC units
                    // ----------------------------------
                    if (s_count == COL_I_LATENCY) begin
                        run_sum[4] <= mac_out[1]; // L_33
                        run_sum[5] <= mac_out[2]; // L_43
                        run_sum[6] <= mac_out[3]; // L_53
                    end

                    // Extract elements of the lower Cholesky factor
                    // ---------------------------------------------
                    if (s_count == SQRT_SAMPLE) begin
                        L[95 : 64]   <= sqrt_out;  // L_22
                    end else if (s_count == INV_SQRT_SAMPLE + MULT_SAMPLE) begin
                        L[159 : 128] <= mult_out[1]; // L_32
                        L[255 : 224] <= mult_out[2]; // L_42
                        L[383 : 352] <= mult_out[3]; // L_52
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
                    if (s_count == SQRT_SAMPLE) begin
                        clk_en_sqrt <= 1'b0;
                    end else if (s_count == INV_SQRT_SAMPLE) begin
                        clk_en_mult[2] <= 1'b1;
                        clk_en_mult[3] <= 1'b1;
                        clk_en_inv_sqrt <= 1'b0;
                    end else if (s_count == INV_SQRT_SAMPLE + MULT_SAMPLE) begin
                        clk_en_mult[2] <= 1'b0;
                        clk_en_mult[3] <= 1'b0;
                    end else if (s_count == COL_I_LATENCY) begin
                        clk_en_inv_sqrt <= 1'b1;
                        clk_en_sqrt <= 1'b1;
                    end

                    // "Lazy forward accumulations"
                    // ----------------------------
                    if (s_count == 1) begin
                        mac_a[2] <= mult_out[2];
                        mac_b[2] <= mult_out[2];
                        mac_c[2] <= run_sum[7]; // L_44
                        mac_a[3] <= mult_out[2];
                        mac_b[3] <= mult_out[3];
                        mac_c[3] <= run_sum[8]; // L_54
                    end else if (s_count == 1 + MAC_SAMPLE) begin
                        mac_a[2] <= mult_out[3];
                        mac_b[2] <= mult_out[3];
                        mac_c[2] <= run_sum[9]; // L_55

                        run_sum[7] <= mac_out[2]; // L_44
                        run_sum[8] <= mac_out[3]; // L_54
                    end else if (s_count == 1 + 2 * MAC_SAMPLE) begin
                        run_sum[9] <= mac_out[2]; // L_55
                    end

                    // Data input signals
                    // --------------------
                    if (s_count == INV_SQRT_SAMPLE) begin
                        mult_a <= inv_sqrt_out;
                        mult_b[2] <= run_sum[5][47 : 16];
                        mult_b[3] <= run_sum[6][47 : 16];
                    end else if (s_count == INV_SQRT_SAMPLE + MULT_SAMPLE) begin
                        mac_a[2] <= mult_out[2];
                        mac_b[2] <= mult_out[2];
                        mac_c[2] <= run_sum[7]; // L_44
                        mac_a[3] <= mult_out[2];
                        mac_b[3] <= mult_out[3];
                        mac_c[3] <= run_sum[8]; // L_54
                    end else if (s_count == COL_I_LATENCY) begin // Set up inputs for first operation of next state.
                        inv_sqrt_data <= mac_out[2][47 : 16];

                        // Reset running sum for columns that are computed.
                        run_sum[4] <= {64{1'b0}}; // L_33
                        run_sum[5] <= {64{1'b0}}; // L_43
                        run_sum[6] <= {64{1'b0}}; // L_53
                    end

                    // Extract running sum from MAC units
                    // ----------------------------------
                    if (s_count == COL_I_LATENCY) begin
                        run_sum[7] <= mac_out[2]; // L_44
                        run_sum[8] <= mac_out[3]; // L_54
                    end

                    // Extract elements of the lower Cholesky factor
                    // ---------------------------------------------
                    if (s_count == SQRT_SAMPLE) begin
                        L[191 : 160] <= sqrt_out;  // L_33
                    end else if (s_count == INV_SQRT_SAMPLE + MULT_SAMPLE) begin
                        L[287 : 256] <= mult_out[2]; // L_43
                        L[415 : 384] <= mult_out[3]; // L_53
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
                    if (s_count == SQRT_SAMPLE) begin
                        clk_en_sqrt <= 1'b0;
                    end else if (s_count == INV_SQRT_SAMPLE) begin
                        clk_en_mult[3] <= 1'b1;
                        clk_en_inv_sqrt <= 1'b0;
                    end else if (s_count == INV_SQRT_SAMPLE + MULT_SAMPLE) begin
                        clk_en_mult[3] <= 1'b0;
                    end else if (s_count == COL_I_LATENCY) begin
                        clk_en_sqrt <= 1'b1;
                    end

                    // "Lazy forward accumulations"
                    // ----------------------------
                    if (s_count == 1) begin
                        mac_a[3] <= mult_out[3];
                        mac_b[3] <= mult_out[3];
                        mac_c[3] <= run_sum[9]; // L_55
                    end else if (s_count == 1 + MAC_SAMPLE) begin
                        run_sum[9] <= mac_out[3]; // L_55
                    end

                    // Data input signals
                    // --------------------
                    if (s_count == INV_SQRT_SAMPLE) begin
                        mult_a <= inv_sqrt_out;
                        mult_b[3] <= run_sum[8][47 : 16];
                    end else if (s_count == INV_SQRT_SAMPLE + MULT_SAMPLE) begin
                        mac_a[3] <= mult_out[3];
                        mac_b[3] <= mult_out[3];
                        mac_c[3] <= run_sum[9]; // L_55
                    end else if (s_count == COL_I_LATENCY) begin // Set up inputs for first operation of next state.
                        inv_sqrt_data <= mac_out[3][47 : 16];

                        // Reset running sum for columns that are computed.
                        run_sum[7] <= {64{1'b0}}; // L_44
                        run_sum[8] <= {64{1'b0}}; // L_54
                    end

                    // Extract running sum from MAC units
                    // ----------------------------------
                    if (s_count == COL_I_LATENCY) begin
                        run_sum[9] <= mac_out[3][47 : 16]; // L_55
                    end

                    // Extract elements of the lower Cholesky factor
                    // ---------------------------------------------
                    if (s_count == SQRT_SAMPLE) begin
                        L[319 : 288] <= sqrt_out;  // L_44
                    end else if (s_count == INV_SQRT_SAMPLE + MULT_SAMPLE) begin
                        L[447 : 416] <= mult_out[3]; // L_54
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
                    if (s_count == SQRT_SAMPLE) begin
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
        clk_en_inv_sqrt_d1 <= clk_en_inv_sqrt;
    end
    assign inv_sqrt_data_valid = ~clk_en_inv_sqrt_d1 & clk_en_inv_sqrt;

// ================================================================================
    /* Square root module
     * ------------------
     * Latency is SQRT_SAMPLE
     */

    chol_sqrt sqrt_0 (
        .clk        (clk),
        .clken      (clk_en_sqrt),
        .rst        (rst),
        .data_valid (inv_sqrt_data_valid),
        .data       (inv_sqrt_data),
        .out        (sqrt_out)
    );

// ================================================================================
    /* Fast inverse square root module
     * -------------------------------
     * Latency is INV_INV_SQRT_SAMPLE
     */

    // TODO: rst signal of inv_sqrt_0 is asserted as part of a "hack" to put the 
    // module in a sane state after every use. This is a problem with the 
    // chol_inv_sqrt module definition.
    chol_inv_sqrt #(
        .ITER       (INV_SQRT_ITER)
    ) inv_sqrt_0 (
        .clk        (clk),
        .clken      (clk_en_inv_sqrt),
        .rst        (rst | (~clk_en_inv_sqrt & clk_en_inv_sqrt_d1)),
        .data_valid (inv_sqrt_data_valid),
        .data       (inv_sqrt_data),
        .out        (inv_sqrt_out),
        .out_valid  () // Not connected since we know beforehand when to sample output
    );

// ================================================================================
    /* N - 1 Multiplier modules
     * ------------------------
     * Latency is MULT_SAMPLE
     */

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin: MULT_BLOCK
            cholesky_ip_mult mult (
                .CLK (clk),
                .A   (mult_a),
                .B   (mult_b[i]),
                .CE  (clk_en_mult[i]),
                .P   (mult_out[i])
            );
        end
    endgenerate

// ================================================================================
    /* N - 1 Multiply-ACcumulate (MAC) modules
     * ---------------------------------------------------------
     * Latency is MAC_SAMPLE
     */

    genvar j;
    generate
        for (j = 0; j < 4; j = j + 1) begin: MAC_BLOCK
            chol_mac mac (
                .clk   (clk),
                .clken (1'b1),
                .rst   (rst),
                .a     (mac_a[j]),
                .b     (mac_b[j]),
                .c     (mac_c[j]),
                .out   (mac_out[j])
            );
        end
    endgenerate

endmodule
