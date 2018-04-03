`timescale 1ns / 1ps

/* The "Inverse-Cholesky" matrix differs from the lower Cholesky matrix only 
 * in the diagonal elements - the "Inverese-Cholesky" matrix stores the 
 * fast-inverse-square-roots of the diagonal elements in place of the actual 
 * diagonal elements. Refer to the proposed algorithm for computation of 
 * inverse of covariance for explanation.
 */

module inv_chol_2 (
    input wire          clk,
    input wire          clk_en, // TODO: Does not handle this right now, but kept around for future use.
    input wire          rst,
    input wire [95 : 0] A,
    input wire          A_valid,

    output reg [95 : 0] S,
    output reg          S_valid
    );

    localparam N             = 2; // Size of the matrix.
    localparam COUNT_WIDTH   = 8; // Enough bits to hold the maximum number of cycles a column can take.
    localparam STATE_WIDTH   = 3;
    localparam INV_SQRT_ITER = 1;

    // Number of clock cycles to wait for sampling output after input valid signal.
    localparam MULT_SAMPLE     = 7;
    localparam INV_SQRT_SAMPLE = 39 + ((INV_SQRT_ITER - 1) * 18) + 1;
    localparam MAC_SAMPLE      = 10;

    /* Computation of column I of "Inverse-Cholesky" matrix takes INV_SQRT_SAMPLE + MULT_SAMPLE + MAC_SAMPLE cycles, for I = 1..N-1 
     * Computation of column N of "Inverse-Cholesky" matrix takes INV_SQRT_SAMPLE cycles
     */
    localparam COL_I_LATENCY = INV_SQRT_SAMPLE + MULT_SAMPLE + MAC_SAMPLE;
    localparam COL_N_LATENCY = INV_SQRT_SAMPLE;

    // State machine encoding
    localparam S_IDLE  = 6'b001;
    localparam S_COL_1 = 6'b010;
    localparam S_COL_2 = 6'b100;

    wire [31 : 0] A_11 = A[31 : 0],
                  A_21 = A[63 : 32],
                  A_22 = A[95 : 64];

    wire          inv_sqrt_data_valid;
    wire [31 : 0] mult_out [0 : 0], inv_sqrt_out;
    wire [63 : 0] mac_p [0 : 0];
    reg           clk_en_inv_sqrt, clk_en_inv_sqrt_d1;
    reg           clk_en_mult [0 : 0];
    reg  [31 : 0] inv_sqrt_data, mult_a, mult_b [0 : 0], mac_a [0 : 0], mac_b [0 : 0];
    reg  [63 : 0] mac_c [0 : 0];
    reg  [63 : 0] run_sum [0 : 0];

    reg [STATE_WIDTH-1 : 0] state;
    reg [COUNT_WIDTH-1 : 0] s_count;

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            s_count <= 6'b00_0000;

            clk_en_inv_sqrt <= 1'b0;
            clk_en_mult[0] <= 1'b0;

            inv_sqrt_data <= {32{1'b0}};
            mult_a <= {32{1'b0}};
            mult_b[0] <= {32{1'b0}};
            mac_a[0] <= {32{1'b0}};
            mac_b[0] <= {32{1'b0}};
            mac_c[0] <= {64{1'b0}};
            run_sum[0] <= {64{1'b0}};

            S <= {96{1'b0}};
            S_valid <= 1'b0;
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
                        s_count <= 6'b00_0001;
                    end else begin
                        s_count <= 6'b00_0000;
                    end

                    // Setup signals prior to commencing operations
                    // --------------------------------------------
                    if (A_valid) begin
                        S_valid <= 1'b0;

                        inv_sqrt_data <= A_11;
                        clk_en_inv_sqrt <= 1'b1; // Enable clock for the first operation, fast inverse square root.
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
                        s_count <= 6'b00_0001;
                    end else begin
                        s_count <= s_count + 6'b00_0001;
                    end

                    // Clock enable signals
                    // --------------------
                    if (s_count == INV_SQRT_SAMPLE) begin
                        clk_en_mult[0] <= 1'b1;
                        clk_en_inv_sqrt <= 1'b0;
                    end else if (s_count == INV_SQRT_SAMPLE + MULT_SAMPLE) begin
                        clk_en_mult[0] <= 1'b0;
                    end else if (s_count == COL_I_LATENCY) begin
                        clk_en_inv_sqrt <= 1'b1;
                    end

                    // Data input signals
                    // --------------------
                    if (s_count == INV_SQRT_SAMPLE) begin
                        mult_a <= inv_sqrt_out;
                        mult_b[0] <= A_21;
                    end else if (s_count == INV_SQRT_SAMPLE + MULT_SAMPLE) begin
                        mac_a[0] <= mult_out[0];
                        mac_b[0] <= mult_out[0];
                        mac_c[0] <= A_22[31] ? {16'hffff, A_22, 16'h0000} : {16'h0000, A_22, 16'h0000};
                    end else if (s_count == COL_I_LATENCY) begin
                        inv_sqrt_data <= mac_p[0][47 : 16];
                    end

                    // Extract running sum from MAC units
                    // ----------------------------------
                    if (s_count == COL_I_LATENCY) begin
                        run_sum[0] <= mac_p[0]; // S_22
                    end

                    // Extract elements of the lower "Inverse-Cholesky" matrix
                    // -------------------------------------------------------
                    if (s_count == INV_SQRT_SAMPLE) begin
                        S[31 : 0]  <= inv_sqrt_out; // S_11
                    end else if (s_count == INV_SQRT_SAMPLE + MULT_SAMPLE) begin
                        S[63 : 32] <= mult_out[0];  // S_21
                    end
                end
                S_COL_2: begin
                    if (s_count == COL_N_LATENCY) begin
                        state <= S_IDLE;
                    end else begin
                        state <= S_COL_2;
                    end

                    // State counter
                    // -------------
                    if (s_count == COL_N_LATENCY) begin
                        s_count <= 6'b00_0000;
                    end else begin
                        s_count <= s_count + 6'b00_0001;
                    end

                    // Clock enable signals
                    // --------------------
                    if (s_count == COL_N_LATENCY) begin
                        clk_en_inv_sqrt <= 1'b0;
                    end

                    // Reset running sum for columns that are computed
                    // -----------------------------------------------
                    if (s_count == COL_N_LATENCY) begin
                        run_sum[0] <= {64{1'b0}}; // S_22
                    end

                    // Extract elements of the lower "Inverse-Cholesky" matrix
                    // -------------------------------------------------------
                    if (s_count == INV_SQRT_SAMPLE) begin
                        S[95 : 64] <= inv_sqrt_out;  // S_22
                        S_valid <= 1'b1;
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
        for (i = 0; i < 1; i = i + 1) begin: MULT_BLOCK
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
        for (j = 0; j < 1; j = j + 1) begin: MAC_BLOCK
            chol_mac mac (
                .clk   (clk),
                .clken (1'b1),
                .rst   (rst),
                .a     (mac_a[j]),
                .b     (mac_b[j]),
                .c     (mac_c[j]),
                .out   (mac_p[j])
            );
        end
    endgenerate

endmodule
