/* References -
 * - Fast Inverse Square Root; Chris Lomont (http://www.lomont.org/Math/Papers/2003/InvSqrt.pdf)
 * - http://bits.stephan-brumme.com/squareRoot.html
 * - http://www.azillionmonkeys.com/qed/sqroot.html#calcmeth
 */

module sqrt #(parameter ITER = 2) (
    output reg [63:0] y,
    output reg        ready,
    input wire [63:0] x,
    input wire        enable,
    input wire        clk,
    input wire        rst
    );

    // Used for bit shifting to get a best initial guess, refer paper 
    // by Chris Lomont for similar explanation of single precision floats.
    localparam MAGIC      = 64'h5fe6ec85e7de30da;
    localparam TMR_LOAD   = 3'b011;
    localparam ROUND      = 2'b00; // Nearest even.

    localparam FPU_OP_ADD = 3'b000;
    localparam FPU_OP_MUL = 3'b010;
    localparam FPU_OP_DIV = 3'b011;

    localparam S_IDLE     = 3'b101;
    localparam S_PC       = 3'b111;
    localparam S_ITER     = 3'b110;
    localparam S_MUL1     = 3'b100;
    localparam S_MUL2     = 3'b000;
    localparam S_SUB      = 3'b001;
    localparam S_MUL3     = 3'b011;
    localparam S_DIV      = 3'b010;

    reg [2:0]   state;
    reg [2:0]   n_iter; // 3-bit wide n_iter limits ITER to a maximum of 7.
    reg [3:0]   tmr;
    reg [63:0]  inv_y, out_pc, fpu_opa, fpu_opb;
    wire [63:0] fpu_out;
    reg         fpu_en;
    reg [2:0]   fpu_op;
    wire        fpu_ready;

    // TODO: Handle underflow, overflow, inexact, exception and invalid signals.
    fpu fpu (
        .clk       (clk),
        .rst       (rst),
        .enable    (fpu_en),
        .rmode     (ROUND),
        .fpu_op    (fpu_op),
        .opa       (fpu_opa),
        .opb       (fpu_opb),
        .out       (fpu_out),
        .ready     (fpu_ready),
        .underflow (),
        .overflow  (),
        .inexact   (),
        .exception (),
        .invalid   ()
        );

    always @(posedge clk or negedge clk) begin
        if (rst && clk) begin
            // Do initialisations.
            tmr <= 0;
            fpu_en <= 0;
            inv_y <= 0;
            out_pc <= 0;
            fpu_opa <= 0;
            fpu_opb <= 0;
            n_iter <= 0;
            ready <= 0;
            state <= S_IDLE;
        end else if (!rst && clk) begin
            case (state)
                S_IDLE: begin
                    if (enable) begin
                        fpu_opa <= 64'h3fe0000000000000; // 0.5
                        fpu_opb <= x;
                        fpu_op <= FPU_OP_MUL;
                        tmr <= TMR_LOAD;
                        inv_y <= MAGIC - (x >> 1); // Load initial guess.
                        n_iter <= 0;
                        ready <= 0;
                        state <= S_PC;
                    end else begin
                        state <= S_IDLE;
                    end
                end
                S_PC: begin // Calculate 0.5 * x
                    if (fpu_ready && tmr == 0) begin
                        out_pc <= fpu_out; // Store result of pc calculation.
                        state <= S_ITER;
                    end else begin
                        state <= S_PC;
                    end
                end
                S_ITER: begin
                    fpu_opa <= inv_y;
                    fpu_opb <= inv_y;
                    fpu_op <= FPU_OP_MUL;
                    tmr <= TMR_LOAD;
                    state <= S_MUL1;
                end
                S_MUL1: begin // Calculate y_n * y_n
                    if (fpu_ready && tmr == 0) begin
                        fpu_opa <= out_pc; // (0.5 * x)
                        fpu_opb <= fpu_out; // (y_n * y_n)
                        fpu_op <= FPU_OP_MUL;
                        tmr <= TMR_LOAD;
                        state <= S_MUL2;
                    end else begin
                        state <= S_MUL1;
                    end
                end
                S_MUL2: begin // Calculate (0.5 * x) * (y_n * y_n) 
                    if (fpu_ready && tmr == 0) begin
                        fpu_opa <= 64'h3ff8000000000000; // 1.5
                        fpu_opb <= {~fpu_out[63], fpu_out[62:0]}; // - (0.5 * x * y_n * y_n)
                        fpu_op <= FPU_OP_ADD; // Using identity, a - b = a + (-b).
                        tmr <= TMR_LOAD;
                        state <= S_SUB;
                    end else begin
                        state <= S_MUL2;
                    end
                end
                S_SUB: begin // Calculate (1.5) - (0.5 * x * y_n * y_n)
                    if (fpu_ready && tmr == 0) begin
                        fpu_opa <= fpu_out; // (1.5 - 0.5 * x * y_n * y_n)
                        fpu_opb <= inv_y; // y_n
                        fpu_op <= FPU_OP_MUL;
                        tmr <= TMR_LOAD;
                        state <= S_MUL3;
                    end else begin
                        state <= S_SUB;
                    end
                end
                S_MUL3: begin // Calculate y_n * (1.5 - 0.5 * x * y_n * y_n)
                    if (fpu_ready && tmr == 0) begin
                        inv_y <= fpu_out; // Update y_n.
                        // Decide whether to run another iteration or terminate.
                        if (n_iter < ITER-1) begin
                            n_iter <= n_iter + 1;
                            state <= S_ITER;
                        end else begin
                            // Setup operands for S_DIV.
                            fpu_opa <= 64'h3ff0000000000000; // 1.0
                            fpu_opb <= inv_y;
                            fpu_op <= FPU_OP_DIV;
                            tmr <= TMR_LOAD;
                            state <= S_DIV;
                        end
                    end else begin
                        state <= S_MUL3;
                    end
                end
                S_DIV: begin
                    if (fpu_ready && tmr == 0) begin
                        y <= fpu_out;
                        ready <= 1;
                        state <= S_IDLE;
                    end else begin
                        state <= S_DIV;
                    end
                end
            endcase
        end else if (!rst && !clk) begin
            // Manage timers and enable triggers.
            if (tmr != 0 && fpu_en) begin
                tmr <= tmr - 1;
            end else if (tmr == 0 && fpu_en) begin
                fpu_en <= 0;
            end else if (tmr != 0 && !fpu_en) begin
                fpu_en <= 1;
            end
        end
    end

endmodule