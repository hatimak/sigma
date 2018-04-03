`timescale 1ns / 1ps

/* Computes the inverse of the input "Inverse-Cholesky" matrix. The 
 * "Inverse-Cholesky" matrix is just a Cholesky lower factor except that 
 * the diagonal terms are replaced by their inverses. The output is the 
 * inverse of the original lower Cholesky factor, the output itself being 
 * a lower triangular matrix.
 */

module inv_lower_2 (
    input wire          clk,
    input wire          clk_en, // TODO: Does not handle this right now, but kept around for future use.
    input wire          rst,
    input wire [95 : 0] S,
    input wire          S_valid,

    output reg [95 : 0] Z,
    output reg          Z_valid
    );

    // Number of clock cycles to wait for sampling output after input valid signal.
    localparam MAC_SAMPLE  = 10;
    localparam MULT_SAMPLE = 7;

    localparam STATE_WIDTH = 3;
    localparam COUNT_WIDTH = 8;

    localparam S_IDLE     = 3'b001;
    localparam S_DIA_1    = 3'b010;
    localparam S_DIA_2    = 3'b100;

    localparam S_DIA_1_LATENCY = MAC_SAMPLE;
    localparam S_DIA_2_LATENCY = MULT_SAMPLE;

    wire [31 : 0] mult_out [0 : 0];
    wire [63 : 0] mac_out [0 : 0];
    reg           clk_en_mult [0 : 0];
    reg  [31 : 0] mac_a [0 : 0], mac_b [0 : 0], mult_a [0 : 0], mult_b [0 : 0];
    reg  [63 : 0] mac_c [0 : 0], run_sum [0 : 0];

    reg [STATE_WIDTH-1 : 0] state;
    reg [COUNT_WIDTH-1 : 0] s_count;

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            s_count <= 0;

            clk_en_mult[0] <= 1'b0;

            mac_a[0] <= 0;
            mac_b[0] <= 0;
            mac_c[0] <= 0;
            mult_a[0] <= 0;
            mult_b[0] <= 0;
            run_sum[0] <= 0;

            Z <= 0;
            Z_valid <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (S_valid) begin
                        state <= S_DIA_1;
                    end else begin
                        state <= S_IDLE;
                    end

                    // State counter
                    // -------------
                    if (S_valid) begin
                        s_count <= 1;
                    end else begin
                        s_count <= 0;
                    end

                    // Setup signals prior to commencing operations
                    // --------------------------------------------
                    if (S_valid) begin
                        Z_valid <= 0;
                    
                        mac_a[0] <= S[31 : 0]; // X_11 = S_11
                        mac_b[0] <= S[63 : 32]; // S_21
                        mac_c[0] <= {64{1'b0}}; 
                    end
                end
                S_DIA_1: begin
                    if (s_count == S_DIA_1_LATENCY) begin
                        state <= S_DIA_2;
                    end else begin
                        state <= S_DIA_1;
                    end

                    // State counter
                    // -------------
                    if (s_count == S_DIA_1_LATENCY) begin
                        s_count <= 1;
                    end else begin
                        s_count <= s_count + 1;
                    end

                    // Clock enable signals
                    // --------------------
                    if (s_count == MAC_SAMPLE) begin
                        clk_en_mult[0] <= 1'b1;
                    end

                    // Setup input signals
                    // -------------------
                    if (s_count == S_DIA_1_LATENCY) begin
                        mult_a[0] <= mac_out[0][47 : 16];
                        mult_b[0] <= S[95 : 64]; // S_22 
                    end

                    // Extract running sums
                    // --------------------
                    if (s_count == S_DIA_1_LATENCY) begin
                        run_sum[0] <= mac_out[0];
                    end

                    // Extract principal diagonal of output inverse
                    // --------------------------------------------
                    if (s_count == S_DIA_1_LATENCY) begin
                        Z[31 : 0]  <= S[31 : 0];  // X_11
                        Z[95 : 64] <= S[95 : 64]; // X_22
                    end
                end
                S_DIA_2: begin
                    if (s_count == S_DIA_2_LATENCY) begin
                        state <= S_IDLE;
                    end else begin
                        state <= S_DIA_2;
                    end

                    // State counter
                    // -------------
                    if (s_count == S_DIA_2_LATENCY) begin
                        s_count <= 1;
                    end else begin
                        s_count <= s_count + 1;
                    end

                    // Clock enable signals
                    // --------------------
                    if (s_count == MULT_SAMPLE) begin
                        clk_en_mult[0] <= 1'b0; 
                    end

                    // Extract second diagonal
                    // -----------------------
                    if (s_count == S_DIA_2_LATENCY) begin
                        Z[63 : 32] <= mult_out[0];
                        Z_valid <= 1'b1;
                    end

                    // Reset running sums
                    // ------------------
                    if (s_count == S_DIA_2_LATENCY) begin
                        run_sum[0] <= 0;
                    end
                end
            endcase
        end
    end

    chol_mac mac_0 (
        .clk   (clk),
        .clken (1'b1),
        .rst   (rst),
        .a     (mac_a[0]),
        .b     (mac_b[0]),
        .c     (mac_c[0]),
        .sub   (1'b1),
        .out   (mac_out[0])
    );

    cholesky_ip_mult mult_0 (
        .CLK (clk),
        .A   (mult_a[0]),
        .B   (mult_b[0]),
        .CE  (clk_en_mult[0]),
        .P   (mult_out[0])
    );

endmodule
