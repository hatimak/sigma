/* 3 machines used,
 *   - traversal,
 *   - diagonal compute, and
 *   - off-diagonal compute.
 *
 * TODO -
 *   - Handle underflow, overflow, inexact, exception and invalid signals.
 * References -
 *   - https://rosettacode.org/wiki/Cholesky_decomposition (gives general formulae for computation)
 */

module cholesky #(parameter SIZE = 4) (
    output wire [(SIZE*SIZE*64)-1:0] factor, // Cholesky factor, lower triangular n x n matrix (elements referred as l_ij below in comments).
    output wire                      ready,
    input wire [(SIZE*SIZE*64)-1:0]  matrix, // Symmetric, positive definite n x n matrix (elements referred as a_ij below in comments).
    input wire                       enable,
    input wire                       clk,
    input wire                       rst
    );

    localparam ROUND      = 2'b00; // Nearest even.
    localparam FPU_OP_DIV = 3'b011;
    localparam FPU_OP_MUL = 3'b010;
    localparam FPU_OP_ADD = 3'b000;
    localparam TMR_LOAD   = 3'b011;

    // State declarations for Traversal machine.
    localparam S_T_IDLE   = 2'b00;
    localparam S_T_ROUTE  = 2'b01;
    localparam S_T_I2     = 2'b11;

    wire                     sqrt_ready_a11, en_trav, ready_li2, fpu_mul_22_ready, fpu_add_22_ready, sqrt_22_ready;
    wire [63:0]              fpu_mul_22_out, fpu_add_22_out;
    wire [SIZE-2:0]          fpu_i1_ready;
    // Since SIZE is at least 2, keep an additional bit (MSB) which will remain unused.
    // For SIZE=2, compute array for l_i,2 (i > 2) is NOT triggered.
    wire [SIZE-2:0]          fpu_mul_i2_ready, fpu_add_i2_ready, fpu_div_i2_ready;
    wire [((SIZE-1)*64)-1:0] fpu_mul_i2_out, fpu_add_i2_out; // Keep an additional vector (MSB).
    reg [1:0]                state_trav;
    reg                      en_i2;
    reg [2:0]                tmr_i2;

    sqrt sqrt_a11 (
        .y      (factor[63:0]), // l_11 = sqrt(a_11)
        .ready  (sqrt_ready_a11),
        .x      (matrix[63:0]), // a_11
        .enable (enable),
        .clk    (clk),
        .rst    (rst)
        );

    // Since l_11 = sqrt(a_11) and l_i,1 = a_i,1 / l_11 (for i > 1), so compute 
    // all l_i,1 (for i > 1) together imediately after l_11 is computed.
    generate
        genvar i1;
        for (i1 = 1; i1 < SIZE; i1 = i1 + 1) begin
            localparam IND_I1 = (i1*SIZE*64);
            fpu fpu_i1 (
                .clk       (clk),
                .rst       (rst),
                .enable    (sqrt_ready_a11),
                .rmode     (ROUND),
                .fpu_op    (FPU_OP_DIV),
                .opa       (matrix[IND_I1+63:IND_I1]), // a_i,1
                .opb       (factor[63:0]), // l_11
                .out       (factor[IND_I1+63:IND_I1]), // l_i,1
                .ready     (fpu_i1_ready[i1-1]),
                .underflow (),
                .overflow  (),
                .inexact   (),
                .exception (),
                .invalid   ()
                );
        end
    endgenerate

    // Since SIZE is at least 2, l_22 needs to be computed in any case.
    // l_22 = sqrt(a_22 - l_21 * l_21)
    fpu fpu_mul_22 (
            .clk       (clk),
            .rst       (rst),
            .enable    (fpu_i1_ready[0]), // Enable as soon as l_21 computation is ready (irrespective of other l_i,1).
            .rmode     (ROUND),
            .fpu_op    (FPU_OP_MUL),
            .opa       (factor[(SIZE*64)+63:SIZE*64]), // l_21
            .opb       (factor[(SIZE*64)+63:SIZE*64]), // l_21
            .out       (fpu_mul_22_out), // l_21 * l_21
            .ready     (fpu_mul_22_ready),
            .underflow (),
            .overflow  (),
            .inexact   (),
            .exception (),
            .invalid   ()
            );
    fpu fpu_add_22 (
            .clk       (clk),
            .rst       (rst),
            .enable    (fpu_mul_22_ready),
            .rmode     (ROUND),
            .fpu_op    (FPU_OP_ADD),
            .opa       (matrix[((SIZE+1)*64)+63:(SIZE+1)*64]), // a_22
            .opb       (fpu_mul_22_out | (1 << 63)), // -(l_21 * l_21)
            .out       (fpu_add_22_out), // a_22 - l_21 * l_21
            .ready     (fpu_add_22_ready),
            .underflow (),
            .overflow  (),
            .inexact   (),
            .exception (),
            .invalid   ()
            );
    sqrt sqrt_22 (
        .y      (factor[((SIZE+1)*64)+63:(SIZE+1)*64]), // l_22
        .ready  (sqrt_22_ready),
        .x      (fpu_add_22_out), // a_22 - l_21 * l_21
        .enable (fpu_add_22_ready),
        .clk    (clk),
        .rst    (rst)
        );

    // Trigger Traversal machine once all l_i,1 and l_22 are computed.
    assign en_trav = &fpu_i1_ready & sqrt_22_ready;

    // Traversal machine, triggered by en_trav.
    always @(posedge clk or negedge clk) begin
        if (rst && clk) begin
            // Do initialisations.
            state_trav <= S_T_IDLE;
            en_i2 <= 0;
            tmr_i2 <= 0;
        end else if (!rst && clk) begin
            case (state_trav)
                S_T_IDLE: begin
                    if (en_trav) begin
                        // Depending on size, check whether computations are needed. If size permits, 
                        // trigger array for l_i,2 (for i > 2) computaion using en_i2 and tmr_ir, 
                        // and wait (S_T_I2).
                    end else begin
                        state_trav <= S_T_IDLE;
                    end
                end
                S_T_ROUTE: begin
                    // Increment indices for factor matrix, route triggers to diagonal or off-diagonal 
                    // compute machines, decide whether end is reached, and wait while computes are busy.
                end
                S_T_I2: begin
                    // Wait for l_i,2 compute array to finish and when done move to S_T_ROUTE.
                end
            endcase
        end else if (!rst && !clk) begin
            // Manage timers and enable triggers.
        end
    end

    generate
        genvar i2;
        for (i2 = 2; i2 < SIZE; i2 = i2 + 1) begin
            localparam IND_I2_MULA = (i2*SIZE*64);
            localparam IND_I2_MULB = (SIZE*64);
            localparam IND_I2_MULO = ((i2-2)*64);
            localparam IND_I2_ADDA = ((i2*SIZE + 1)*64);
            localparam IND_I2_ADDO = ((i2-2)*64);
            localparam IND_I2_DIVB = ((SIZE + 1)*64);
            localparam IND_I2_DIVO = ((i2*SIZE + 1)*64);
            fpu fpu_mul_i2 (
                .clk       (clk),
                .rst       (rst),
                .enable    (en_i2),
                .rmode     (ROUND),
                .fpu_op    (FPU_OP_MUL),
                .opa       (factor[IND_I2_MULA+63:IND_I2_MULA]), // l_i,1
                .opb       (factor[IND_I2_MULB+63:IND_I2_MULB]), // l_21
                .out       (fpu_mul_i2_out[IND_I2_MULO+63:IND_I2_MULO]), // l_21 * l_i,1
                .ready     (fpu_mul_i2_ready[i2-2]),
                .underflow (),
                .overflow  (),
                .inexact   (),
                .exception (),
                .invalid   ()
                );

            fpu fpu_add_i2 (
                .clk       (clk),
                .rst       (rst),
                .enable    (fpu_mul_i2_ready[i2-2]),
                .rmode     (ROUND),
                .fpu_op    (FPU_OP_ADD),
                .opa       (matrix[IND_I2_ADDA+63:IND_I2_ADDA]), // a_i,2
                .opb       (fpu_mul_i2_out[IND_I2_MULO+63:IND_I2_MULO] | (1 << 63)), // -(l_21 * l_i,1)
                .out       (fpu_add_i2_out[IND_I2_ADDO+63:IND_I2_ADDO]), // a_i,2 - l_21 * l_i,1
                .ready     (fpu_add_i2_ready[i2-2]),
                .underflow (),
                .overflow  (),
                .inexact   (),
                .exception (),
                .invalid   ()
                );

            fpu fpu_div_i2 (
                .clk       (clk),
                .rst       (rst),
                .enable    (fpu_add_i2_ready[i2-2]),
                .rmode     (ROUND),
                .fpu_op    (FPU_OP_DIV),
                .opa       (fpu_add_i2_out[IND_I2_ADDO+63:IND_I2_ADDO]), // a_i,2 - l_21 * l_i,1
                .opb       (factor[IND_I2_DIVB+63:IND_I2_DIVB]), // l_22
                .out       (factor[IND_I2_DIVO+63:IND_I2_DIVO]), // l_i,2 = (a_i,2 - l_21 * l_i,1) / l_22
                .ready     (fpu_div_i2_ready[i2-2]),
                .underflow (),
                .overflow  (),
                .inexact   (),
                .exception (),
                .invalid   ()
                );
        end
    endgenerate

    assign fpu_div_i2_ready[SIZE-2] = 1'b1; // Set fpu_*_i2_ready[SIZE-2] to high (SIZE-2 is unused MSB).
    assign fpu_mul_i2_ready = &fpu_div_i2_ready; // Used in S_T_I2 which is only reached when SIZE > 2.

    // Cholesky factor is lower triangular, so l_ij = 0 for j > i (i = 1, 2, 3, ..., n-1).
    generate
        genvar i_zero, j_zero;
        for (i_zero = 0; i_zero <= SIZE-2; i_zero = i_zero + 1) begin
            for (j_zero = i_zero + 1; j_zero < SIZE; j_zero = j_zero + 1) begin
                localparam IND_ZERO = ((i_zero*SIZE + j_zero)*64);
                assign factor[IND_ZERO+63:IND_ZERO] = {64{1'b0}};
            end
        end
    endgenerate

endmodule
