`timescale 1ns / 1ps

module tb_inv_2 ();

    reg           clk, clk_en, rst, A_valid;
    reg  [95 : 0] A;
    reg          B_valid;
//    wire [31 : 0] B_11, B_21, B_22;
    reg [95 : 0] B;

//    inv_2 uut (
//        .clk     (clk),
//        .clk_en  (clk_en),
//        .rst     (rst),
//        .A       (A),
//        .A_valid (A_valid),

//        .B       ({B_22, B_21, B_11}),
//        .B_valid (B_valid)
//    );

    initial begin
        #200; // Global Set/Reset (GSR) is in effect for the first 100ns so apply stimulus afterwards
        clk = 1'b0;
        clk_en = 1'b1;
        rst = 1'b1;
        A_valid = 1'b0;
        /* +-         -+
         * | 1000  250 |
         * |  250  750 |
         * +-         -+
         */
        A = 96'h02ee_0000__00fa_0000__03e8_0000;
        #20;
        rst = 1'b0;
        #27;
        A_valid = 1'b1;
        #63;
        A_valid = 1'b0;
        #3000;
        /* +-              -+
         * | 0.2500  0.0625 |
         * | 0.0625  0.1250 |
         * +-              -+
         */
        A = 96'h0000_2000__0000_1000__0000_4000;
        #44;
        A_valid = 1'b1;
        #93;
        A_valid = 1'b0;
        #3000;
        $finish;
    end

    always begin
        #5;
        clk = (clk === 1'b0);
    end

    localparam N = 2;

    // Number of clock cycles to wait for sampling output after input valid signal.
    localparam INV_CHOL_SAMPLE  = 99;
    localparam INV_LOWER_SAMPLE = 19;
    localparam MAC_SAMPLE       = 10;
    localparam MULT_SAMPLE      = 7;

    localparam MAT_MULT_LATENCY = N * MAC_SAMPLE + 1;

    localparam STATE_WIDTH = 4;
    localparam COUNT_WIDTH = 8;

    localparam S_IDLE      = 4'b0001;
    localparam S_INV_CHOL  = 4'b0010;
    localparam S_INV_LOWER = 4'b0100;
    localparam S_MAT_MULT  = 4'b1000;

    wire          inv_chol_valid, inv_lower_valid;
    wire [31 : 0] mult_out [1 : 0];
    wire [63 : 0] mac_out [0 : 0];
    wire [95 : 0] S, Z;
    reg           inv_chol_clk_en, inv_chol_clk_en_d1, inv_lower_clk_en, inv_lower_clk_en_d1, clk_en_mult [1 : 0];
    reg  [31 : 0] mac_a [0 : 0], mac_b [0 : 0], mult_a [1 : 0], mult_b [1 : 0];
    reg  [63 : 0] run_sum [0 : 0];

    reg [STATE_WIDTH-1 : 0] state;
    reg [COUNT_WIDTH-1 : 0] s_count;

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            s_count <= 0;

            inv_chol_clk_en <= 1'b0;
            inv_lower_clk_en <= 1'b0;
            clk_en_mult[0] <= 0;
            clk_en_mult[1] <= 0;

            mac_a[0] <= 0;
            mac_b[0] <= 0;
            run_sum[0] <= 0;
            mult_a[0] <= 0;
            mult_b[0] <= 0;
            mult_a[1] <= 0;
            mult_b[1] <= 0;

            B <= 0;
            B_valid <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (A_valid) begin
                        state <= S_INV_CHOL;
                    end else begin
                        state <= S_IDLE;
                    end

                    // State counter
                    // -------------
                    if (A_valid) begin
                        s_count <= 1;
                    end else begin
                        s_count <= 0;
                    end

                    // Setup signals prior to commencing operations
                    // --------------------------------------------
                    if (A_valid) begin
                        B_valid <= 0;
                        inv_chol_clk_en <= 1'b1;
                    end
                end
                S_INV_CHOL: begin
                    if (s_count == INV_CHOL_SAMPLE) begin
                        state <= S_INV_LOWER;
                    end else begin
                        state <= S_INV_CHOL;
                    end

                    // State counter
                    // -------------
                    if (s_count == INV_CHOL_SAMPLE) begin
                        s_count <= 1;
                    end else begin
                        s_count <= s_count + 1;
                    end

                    // Clock enable signals
                    // --------------------
                    if (s_count == INV_CHOL_SAMPLE) begin
                        inv_chol_clk_en <= 1'b0;
                        inv_lower_clk_en <= 1'b1;
                    end


                end
                S_INV_LOWER: begin
                    if (s_count == INV_LOWER_SAMPLE) begin
                        state <= S_MAT_MULT;
                    end else begin
                        state <= S_INV_LOWER;
                    end

                    // State counter
                    // -------------
                    if (s_count == INV_LOWER_SAMPLE) begin
                        s_count <= 1;
                    end else begin
                        s_count <= s_count + 1;
                    end

                    // Clock enable signals
                    // --------------------
                    if (s_count == INV_LOWER_SAMPLE) begin
                        inv_lower_clk_en <= 1'b0;
                        clk_en_mult[0] <= 1'b1; // Z_21
                        clk_en_mult[1] <= 1'b1; // Z_22
                    end

                    // Setup input signals
                    // -------------------
                    if (s_count == INV_LOWER_SAMPLE) begin
                        mac_a[0] <= Z[31 : 0]; // Z_11
                        mac_b[0] <= Z[31 : 0]; // Z_11
                        run_sum[0] <= 0;

                        mult_a[0] <= Z[63 : 32]; // Z_21
                        mult_b[0] <= Z[95 : 64]; // Z_22
                        mult_a[1] <= Z[95 : 64]; // Z_22
                        mult_b[1] <= Z[95 : 64]; // Z_22
                    end
                end
                S_MAT_MULT: begin
                    if (s_count == MAT_MULT_LATENCY) begin
                        state <= S_IDLE;
                    end else begin
                        state <= S_MAT_MULT;
                    end

                    // State counter
                    // -------------
                    if (s_count == MAT_MULT_LATENCY) begin
                        s_count <= 0;
                    end else begin
                        s_count <= s_count + 1;
                    end

                    // Clock enable signals
                    // --------------------
                    if (s_count == MULT_SAMPLE) begin
                        clk_en_mult[0] <= 1'b0; // Z_21
                        clk_en_mult[1] <= 1'b0; // Z_22
                    end

                    // Setup input signals
                    // -------------------
                    if (s_count == MAC_SAMPLE) begin
                        mac_a[0] <= Z[63 : 32]; // Z_21
                        mac_b[0] <= Z[63 : 32]; // Z_21
                        run_sum[0] <= mac_out[0];
                    end

                    // Reset running sum
                    // ----------------
                    if (s_count == MAT_MULT_LATENCY) begin
                        run_sum[0] <= 0;
                    end

                    // Extract output
                    // --------------
                    if (s_count == MULT_SAMPLE) begin
                        B[63 : 32] <= mult_out[0]; // B_21
                        B[95 : 64] <= mult_out[1]; // B_22
                    end else if (s_count == MAT_MULT_LATENCY) begin
                        B[31 : 0] <= mac_out[0][47 : 16]; // B_11
                        B_valid <= 1'b1;
                    end
                end
            endcase
        end
    end

    always @(posedge clk) begin
        inv_chol_clk_en_d1 <= inv_chol_clk_en;
        inv_lower_clk_en_d1 <= inv_lower_clk_en;
    end
    assign inv_chol_valid = inv_chol_clk_en & ~inv_chol_clk_en_d1;
    assign inv_lower_valid = inv_lower_clk_en & ~inv_lower_clk_en_d1;

// ================================================================================
    /* "Inverse-Cholesky" module
     * -------------------------
     */

    inv_chol_2 inv_chol_0 (
        .clk     (clk),
        .clk_en  (inv_chol_clk_en),
        .rst     (rst),
        .A       (A),
        .A_valid (inv_chol_valid),

        .S       (S),
        .S_valid () // Not connected since we know the latency, hence know when to sample
    );

// ================================================================================
    /* "Inverse-Lower" module
     * ----------------------
     */

    inv_lower_2 inv_lower_0 (
        .clk     (clk),
        .clk_en  (inv_lower_clk_en),
        .rst     (rst),
        .S       (S),
        .S_valid (inv_lower_valid),
        
        .Z       (Z),
        .Z_valid () // Not connected since we know the latency, hence know when to sample
    );

// ================================================================================
    /* 0.5 * N * (N-1) Multiply-ACcumulate (MAC) modules
     * -------------------------------------------------
     * For matrix multiplication. Latency is MAC_SAMPLE. N is size of input matrix.
     */

    genvar i;
    generate
        for (i = 0; i < 1; i = i + 1) begin: MAC_BLOCK
            chol_mac mac (
                .clk   (clk),
                .clken (1'b1),
                .rst   (rst),
                .a     (mac_a[i]),
                .b     (mac_b[i]),
                .c     (run_sum[i]),
                .out   (mac_out[i])
            );
        end 
    endgenerate

// ================================================================================
    /* N Multiplier modules
     * --------------------
     * For matrix multiplication. Latency is MULT_SAMPLE. N is size of input matrix.
     */

    genvar j;
    generate
        for (j = 0; j < 2; j = j + 1) begin: MULT_BLOCK
            cholesky_ip_mult mult (
                .CLK (clk),
                .A   (mult_a[j]),
                .B   (mult_b[j]),
                .CE  (clk_en_mult[j]),
                .P   (mult_out[j])
            );
        end
    endgenerate

endmodule
