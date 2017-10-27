/* References -
 * - Fast Inverse Square Root; Chris Lomont (http://www.lomont.org/Math/Papers/2003/InvSqrt.pdf)
 */

module sqrt #(parameter N_ITER = 2) (
    output reg [63:0] y,
    output reg        ready,
    input wire [63:0] x,
    input wire        enable,
    input wire        clk,
    input wire        rst
    );

    localparam MAGIC = 64'h5fe6ec85e7de30da;
    localparam TMR_LOAD = 3'b110;

    reg [3:0]  state;
    reg [3:0]  tmr_pc, tmr_mul1, tmr_mul2, tmr_sub, tmr_mul3;
    reg [63:0] inv_y;
    reg        init_guess, en_pc, en_mul1, en_mul2, en_sub, en_mul3;
    wire       ready_pc, ready_mul1, ready_mul2, ready_sub, ready_mul3;

    localparam S_IDLE = 3'b111;
    localparam S_PC   = 3'b110;
    localparam S_ITER = 3'b100;
    localparam S_MUL1 = 3'b000;
    localparam S_MUL2 = 3'b001;
    localparam S_SUB  = 3'b011;
    localparam S_MUL3 = 3'b010;

    always @(posedge clk or negedge clk) begin
        if (rst && clk) begin
            // Do initialisations.
            tmr_pc <= 0;
            en_pc <= 0;
            tmr_mul1 <= 0;
            en_mul1 <= 0;
            inv_y <= 0;
            state <= S_IDLE;
        end else if (!rst && clk) begin
            case (state)
                S_IDLE: begin
                    if (enable) begin
                        // Setup operands for S_PC.
                        tmr_pc <= TMR_LOAD;
                        inv_y <= MAGIC - (x >> 1); // Load initial guess.
                        state <= S_PC;
                    end else begin
                        state <= S_IDLE;
                    end
                end
                S_PC: begin // Calculate 0.5 * x
                    if (ready_pc && tmr_pc == 0) begin
                        // Store result of pc calculation.
                        state <= S_ITER;
                    end else begin
                        state <= S_PC;
                    end
                end
                S_ITER: begin
                    // Setup operands for S_MUL1.
                    tmr_mul1 <= TMR_LOAD;
                    state <= S_MUL1;
                end
                S_MUL1: begin // Calculate y_n * y_n
                    if (ready_mul1 && tmr_mul1 == 0) begin
                        // Store result of mul1 calculation.
                        // Setup operands for S_MUL2.
                        tmr_mul2 <= TMR_LOAD;
                        state <= S_MUL2;
                    end else begin
                        state <= S_MUL1;
                    end
                end
                S_MUL2: begin // Calculate (0.5 * x) * (y_n * y_n) 
                    if (ready_mul2 && tmr_mul2 == 0) begin
                        // Store result of mul2 operation.
                        // Setup operands for S_SUB.
                        tmr_sub <= TMR_LOAD;
                        state <= S_SUB;
                    end else begin
                        state <= S_MUL2;
                    end
                end
                S_SUB: begin // Calculate 1.5 - 0.5 * x * y_n * y_n
                    if (ready_sub && tmr_sub == 0) begin
                        // Store result of sub operation.
                        // Setup operands for S_MUL3.
                        tmr_mul3 <= TMR_LOAD;
                        state <= S_MUL3;
                    end else begin
                        state <= S_SUB;
                    end
                end
                S_MUL3: begin // Calculate y_n * (1.5 - 0.5 * x * y_n * y_n)
                    if (ready_mul3 && tmr_mul3 == 0) begin
                        // Store result of mul3 operation and update y_n.
                        // Decide whether to run another iteration or terminate.
                    end else begin
                        state <= S_MUL3;
                    end
                end
            endcase
        end else if (!rst && !clk) begin
            // Manage timers and enable triggers.
            if (tmr_pc != 0 && en_pc) begin
                tmr_pc <= tmr_pc - 1;
            end else if (tmr_pc == 0 && en_pc) begin
                en_pc <= 0;
            end else if (tmr_pc != 0 && !en_pc) begin
                en_pc <= 1;
            end
            if (tmr_mul1 != 0 && en_mul1) begin
                tmr_mul1 <= tmr_mul1 - 1;
            end else if (tmr_mul1 == 0 && en_mul1) begin
                en_mul1 <= 0;
            end else if (tmr_mul1 != 0 && !en_mul1) begin
                en_mul1 <= 1;
            end
            if (tmr_mul2 != 0 && en_mul2) begin
                tmr_mul2 <= tmr_mul2 - 1;
            end else if (tmr_mul2 == 0 && en_mul2) begin
                en_mul2 <= 0;
            end else if (tmr_mul2 != 0 && !en_mul2) begin
                en_mul2 <= 1;
            end
            if (tmr_sub != 0 && en_sub) begin
                tmr_sub <= tmr_sub - 1;
            end else if (tmr_sub == 0 && en_sub) begin
                en_sub <= 0;
            end else if (tmr_sub != 0 && !en_sub) begin
                en_sub <= 1;
            end
            if (tmr_mul3 != 0 && en_mul3) begin
                tmr_mul3 <= tmr_mul3 - 1;
            end else if (tmr_mul3 == 0 && en_mul3) begin
                en_mul3 <= 0;
            end else if (tmr_mul3 != 0 && !en_mul3) begin
                en_mul3 <= 1;
            end
        end
    end

endmodule