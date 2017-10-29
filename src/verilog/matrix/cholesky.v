/* 3 machines used,
 *   - traversal,
 *   - diagonal compute, and
 *   - off-diagonal compute.
 *
 * TODO -
 *   - Handle underflow, overflow, inexact, exception and invalid signals.
 *   - Fix whitespace and indentations.
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
    localparam MASK       = ((1 << 64) - 1);

    // State declarations for Traversal machine.
    localparam S_T_IDLE   = 2'b00;
    localparam S_T_ROUTE  = 2'b01;
    localparam S_T_I2     = 2'b11;

    // State declarations for Diagonal machine.
    localparam S_D_IDLE   = 2'b00;
    localparam S_D_CTRL   = 2'b01;

    wire                     sqrt_ready_a11, en_trav, ready_li2, fpu_mul_22_ready, fpu_add_22_ready, sqrt_22_ready;
    wire                     fpu_mul_ik_ready, fpu_add_ik_ready, fpu_add_diag_ready, sqrt_diag_ready;
    wire [63:0]              fpu_mul_22_out, fpu_add_22_out, fpu_mul_ik_out, fpu_add_ik_out, fpu_add_diag_out, sqrt_diag_y;
    reg [63:0]               diag_trans_sum, diag_trans_prod, fpu_mul_ik_op, diag_aii;
    wire [SIZE-2:0]          fpu_i1_ready;
    // Since SIZE is at least 2, keep an additional bit (MSB) which will remain unused.
    // For SIZE=2, compute array for l_i,2 (i > 2) is NOT triggered.
    wire [SIZE-2:0]          fpu_mul_i2_ready, fpu_add_i2_ready, fpu_div_i2_ready;
    wire [((SIZE-1)*64)-1:0] fpu_mul_i2_out, fpu_add_i2_out; // Keep an additional vector (MSB).
    reg [((SIZE-1)*64)-1:0]  sqrt_diag, sqrt_diag_sel; // Two most significant 64-bit wide slices unused (declared because SIZE >= 2).
    reg [1:0]                state_trav;
    reg [2:0]                state_diag, state_offdiag;
    reg                      en_i2, ready_trav, en_diag, ready_diag, en_offdiag, ready_offdiag;
    reg                      en_fpu_mul_ik, en_fpu_add_ik, en_fpu_sumsqrt_ik;
    reg [2:0]                tmr_i2, tmr_diag, tmr_offdiag, tmr_fpu_mul_ik, tmr_fpu_add_ik, tmr_fpu_sumsqrt_ik;
    reg [7:0]                trav_i, trav_j, diag_k; // 8-bit wide should limit SIZE to a maximum of 256.

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
            state_trav <= S_T_IDLE;
            en_i2 <= 0;
            tmr_i2 <= 0;
            en_diag <= 0;
            tmr_diag <= 0;
            ready_trav <= 0;
            trav_i <= 0;
            trav_j <= 0;
        end else if (!rst && clk) begin
            case (state_trav)
                S_T_IDLE: begin
                    if (en_trav) begin
                        // Depending on size, check whether computations are needed. If size permits, 
                        // trigger array for l_i,2 (for i > 2) computaion using en_i2 and tmr_i2, 
                        // and wait (S_T_I2).
                        if (SIZE > 2) begin
                            tmr_i2 <= TMR_LOAD;
                            ready_trav <= 0;
                            state_trav <= S_T_I2;
                        end else begin // If SIZE = 2, all required computations are done by this time, so conclude.
                            ready_trav <= 1;
                            state_trav <= S_T_IDLE;
                        end
                    end else begin
                        state_trav <= S_T_IDLE;
                    end
                end
                S_T_ROUTE: begin
                    // Increment indices for factor matrix, route triggers to diagonal or off-diagonal 
                    // compute machines, decide whether end is reached, and wait while computes are busy.
                    // At a given time, only one of Diagonal or Off-diagonal machines are busy.
                    if (ready_diag && tmr_diag == 0) begin // Diagonal machine is done with compute task.
                        if (trav_i == SIZE-1 && trav_j == SIZE-1) begin
                            // The last element l_ij of factor to be computed will always reside on the diagonal.
                            ready_trav <= 1;
                            state_trav <= S_T_IDLE;
                        end else begin
                            // The last element l_ij of any row to be computed will always reside on the diagonal 
                            // so row index control is determined by Diagonal machine only.
                            trav_i <= trav_i + 1;
                            trav_j <= 2;
                            tmr_offdiag <= TMR_LOAD;
                            state_trav <= S_T_ROUTE;
                        end
                    end if (ready_offdiag && tmr_offdiag == 0) begin // Off-diagonal machine is done with compute task.
                        if (trav_j == trav_i - 1) begin // If next element resides on diagonal, trigger Diagonal machine.
                            tmr_diag <= TMR_LOAD;
                        end else begin // Trigger Off-diagonal machine.
                            tmr_offdiag <= TMR_LOAD;
                        end
                        trav_j <= trav_j + 1;
                        state_trav <= S_T_ROUTE;
                    end else begin
                        state_trav <= S_T_ROUTE;
                    end
                end
                S_T_I2: begin
                    if (ready_li2 && tmr_i2 == 0) begin
                        // Start computing l_ij from l_33 onwards.
                        trav_i <= 2;
                        trav_j <= 2;
                        tmr_diag <= TMR_LOAD;
                        state_trav <= S_T_ROUTE;
                    end else begin
                        state_trav <= S_T_I2;
                    end
                end
            endcase
        end else if (!rst && !clk) begin
            // Manage timers and enable triggers.
            if (tmr_i2 != 0 && en_i2) begin
                tmr_i2 <= tmr_i2 - 1;
            end else if (tmr_i2 == 0 && en_i2) begin
                en_i2 <= 0;
            end else if (tmr_i2 != 0 && !en_i2) begin
                en_i2 <= 1;
            end
            if (tmr_diag != 0 && en_diag) begin
                tmr_diag <= tmr_diag - 1;
            end else if (tmr_diag == 0 && en_diag) begin
                en_diag <= 0;
            end else if (tmr_diag != 0 && !en_diag) begin
                en_diag <= 1;
            end
            if (tmr_offdiag != 0 && en_offdiag) begin
                tmr_offdiag <= tmr_offdiag - 1;
            end else if (tmr_offdiag == 0 && en_offdiag) begin
                en_offdiag <= 0;
            end else if (tmr_offdiag != 0 && !en_offdiag) begin
                en_offdiag <= 1;
            end
        end
    end

    assign ready = sqrt_22_ready & ready_trav;

    // Diagonal machine, triggered by en_diag. trav_i is fixed by Traversal for a single run of Diagonal machine.
    always @(posedge clk or negedge clk) begin
        if (rst && clk) begin
            // Do initialisations.
            diag_k <= 0;
            diag_trans_sum <= 0;
            diag_trans_prod <= 0;
            en_fpu_mul_ik <= 0;
            tmr_fpu_mul_ik <= 0;
            en_fpu_add_ik <= 0;
            tmr_fpu_add_ik <= 0;
            en_fpu_sumsqrt_ik <= 0;
            tmr_fpu_sumsqrt_ik <= 0;
            sqrt_diag <= 0;
            sqrt_diag_sel <= 0;
            fpu_mul_ik_op <= 0;
            diag_aii <= 0;
        end else if (!rst && clk) begin
            case (state_diag)
                S_D_IDLE: begin
                    if (en_diag) begin
                        // Start machine.
                        sqrt_diag_sel <= MASK << (trav_i-2)*64;
                        diag_aii <= (matrix & (MASK << (trav_i*SIZE + trav_i)*64)) >> (trav_i*SIZE + trav_i)*64;
                    end else begin
                        state_diag <= S_D_IDLE;
                    end
                end
                S_D_CTRL: begin
                    if (fpu_mul_ik_ready) begin
                        diag_trans_prod <= fpu_mul_ik_out;
                        // Increment diag_k and check if within bounds. If within, 
                        // then setup operands and trigger multiplication.
                        fpu_mul_ik_op <= (factor & (MASK << (trav_i*SIZE + diag_k)*64)) >> (trav_i*SIZE + diag_k)*64;
                    end
                    if (fpu_add_ik_ready) begin
                        diag_trans_sum <= fpu_add_ik_out;
                        // Check bounds on diag_k and decide whether multiply-accumulate (MAC)
                        // operations should be concluded.
                        // If MAC operations are done, diag_trans_sum holds final MAC-ed value 
                        // for given iteration. Then set up operands for and trigger 
                        // sum-and-sqrt (via en_fpu_sumsqrt_ik) to get l_ii,
                        //     l_ii = sqrt(a_ii - MAC_sum))
                    end
                    if (sqrt_diag_ready) begin
                        // This signals end of computation for l_ii. Store the result in 
                        // respective sqrt_diag[] register (which should drive the corresponding 
                        // factor[], wired below in a generate block).
                        sqrt_diag <= (sqrt_diag & ~sqrt_diag_sel) | (sqrt_diag_y << (trav_i-2)*64) ;
                    end
                end
            endcase
        end else if (!rst && !clk) begin
            // Manage timers and enable triggers.
            if (tmr_fpu_mul_ik != 0 && en_fpu_mul_ik) begin
                tmr_fpu_mul_ik <= tmr_fpu_mul_ik - 1;
            end else if (tmr_fpu_mul_ik == 0 && en_fpu_mul_ik) begin
                en_fpu_mul_ik <= 0;
            end else if (tmr_fpu_mul_ik != 0 && !en_fpu_mul_ik) begin
                en_fpu_mul_ik <= 1;
            end
            if (tmr_fpu_add_ik != 0 && en_fpu_add_ik) begin
                tmr_fpu_add_ik <= tmr_fpu_add_ik - 1;
            end else if (tmr_fpu_add_ik == 0 && en_fpu_add_ik) begin
                en_fpu_add_ik <= 0;
            end else if (tmr_fpu_add_ik != 0 && !en_fpu_add_ik) begin
                en_fpu_add_ik <= 1;
            end
            if (tmr_fpu_sumsqrt_ik != 0 && en_fpu_sumsqrt_ik) begin
                tmr_fpu_sumsqrt_ik <= tmr_fpu_sumsqrt_ik - 1;
            end else if (tmr_fpu_sumsqrt_ik == 0 && en_fpu_sumsqrt_ik) begin
                en_fpu_sumsqrt_ik <= 0;
            end else if (tmr_fpu_sumsqrt_ik != 0 && !en_fpu_sumsqrt_ik) begin
                en_fpu_sumsqrt_ik <= 1;
            end
        end
    end

    fpu fpu_mul_ik (
        .clk       (clk),
        .rst       (rst),
        .enable    (en_fpu_mul_ik),
        .rmode     (ROUND),
        .fpu_op    (FPU_OP_MUL),
        .opa       (fpu_mul_ik_op), // l_i,k (i from Traversal, k from Diagonal)
        .opb       (fpu_mul_ik_op), // l_i,k
        .out       (fpu_mul_ik_out), // l_i,k * l_i,k
        .ready     (fpu_mul_ik_ready),
        .underflow (),
        .overflow  (),
        .inexact   (),
        .exception (),
        .invalid   ()
        );
    fpu fpu_add_ik (
        .clk       (clk),
        .rst       (rst),
        .enable    (en_fpu_add_ik),
        .rmode     (ROUND),
        .fpu_op    (FPU_OP_ADD),
        .opa       (diag_trans_prod), // l_i,k * l_i,k
        .opb       (diag_trans_sum), // Transient sum upto previous iteration(s).
        .out       (fpu_add_ik_out), // 
        .ready     (fpu_add_ik_ready),
        .underflow (),
        .overflow  (),
        .inexact   (),
        .exception (),
        .invalid   ()
        );

    fpu fpu_add_diag (
        .clk       (clk),
        .rst       (rst),
        .enable    (en_fpu_sumsqrt_ik),
        .rmode     (ROUND),
        .fpu_op    (FPU_OP_ADD),
        .opa       (diag_trans_sum | (1 << 63)), // -(MAC_sum)
        .opb       (diag_aii), // a_ii (i from Traversal)
        .out       (fpu_add_diag_out), // a_ii - MAC_sum
        .ready     (fpu_add_diag_ready),
        .underflow (),
        .overflow  (),
        .inexact   (),
        .exception (),
        .invalid   ()
        );
    sqrt sqrt_diag_ii (
        .y      (sqrt_diag_y), // l_ii = sqrt(a_ii - MAC_sum) (i from Traversal)
        .ready  (sqrt_diag_ready),
        .x      (fpu_add_diag_out), // a_ii - MAC_sum
        .enable (fpu_add_diag_ready),
        .clk    (clk),
        .rst    (rst)
        );

    // Array for l_i,2 computation (i > 2).
    // l_i,2 = (a_i,2 - l_21 * l_i,1) / l_22
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
    assign ready_li2 = &fpu_div_i2_ready; // Used in S_T_I2 (S_T_I2 reached only when SIZE > 2).

    // Cholesky factor is lower triangular, so l_ij = 0 for j > i (i = 1, 2, 3, ..., n-1).
    generate
        genvar i33_diag;
        for (i33_diag = 2; i33_diag < SIZE; i33_diag = i33_diag + 1) begin
            localparam IND_DIAG = ((i33_diag*SIZE + i33_diag)*64);
            assign factor[IND_DIAG+63:IND_DIAG] = sqrt_diag[((i33_diag-2)*64)+63:(i33_diag-2)*64];
        end
    endgenerate

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
