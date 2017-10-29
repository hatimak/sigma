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

    wire        sqrt_ready_a11, en_trav;
    wire [63:0] sqrt_y_a11;

    sqrt sqrt_a11 (
        .y      (sqrt_y_a11), // a_11
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
                .opb       (sqrt_y_a11), // sqrt(a_11)
                .out       (factor[IND_I1+63:IND_I1]),
                .ready     (en_trav),
                .underflow (),
                .overflow  (),
                .inexact   (),
                .exception (),
                .invalid   ()
                );
        end
    endgenerate

    assign factor[63:0] = sqrt_y_a11; // l_11 = sqrt(a_11)

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
