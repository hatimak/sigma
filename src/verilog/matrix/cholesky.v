/* 3 machines used,
 *   - traversal,
 *   - diagonal compute, and
 *   - off-diagonal compute.
 *
 * TODO -
 *   1. Handle underflow, overflow, inexact, exception and invalid signals.
 *   2. In Traversal, change conditionals to use ready_*_p (pulse) signals instead of ready_* (level) signals (cf. fpu_mul_ik_ready_p, fpu_add_ik_ready_p, etc.)
 *   3. Reduce module usage by reusing FPU instances for multiple types of operations. (Any other reuses possible?)
 *   4. Reduce reg usage by offdiag_ij and offdiag_ij_sel, more than half stores "meaningless" values.
 *   5. Fix whitespace and indentations.
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
    localparam S_D_MUL    = 2'b11;
    localparam S_D_SQRT   = 2'b10;

    // State declarations for Off-diagonal machine.
    localparam S_O_IDLE   = 2'b00;
    localparam S_O_CTRL   = 2'b01;
    localparam S_O_MUL    = 2'b11;
    localparam S_O_DIV    = 2'b10;

    // Off-diagonal element store (used by Off-diagonal machine). Only around 
    // half of the vector holds "meaningful" values, but additional elements used 
    // to allow easy indexing and to ensure indices don't go negative for lower SIZEs.
    localparam OD_IN      = ((SIZE-1)*(SIZE-1)*64);

    wire                     sqrt_ready_a11, en_trav, ready_li2, fpu_mul_22_ready, fpu_add_22_ready, sqrt_22_ready, fpu_add_offdiag_ready;
    wire                     fpu_mul_ik_ready, fpu_add_ik_ready, fpu_add_diag_ready, sqrt_diag_ready, fpu_mul_ijk_ready, fpu_add_ijk_ready, fpu_div_offdiag_ready;
    wire                     fpu_mul_ik_ready_p, fpu_add_ik_ready_p, sqrt_diag_ready_p, fpu_mul_ijk_ready_p, fpu_add_ijk_ready_p, fpu_div_offdiag_ready_p;
    reg [1:0]                sr_fpu_mul_ik_ready, sr_fpu_add_ik_ready, sr_sqrt_diag_ready, sr_fpu_mul_ijk_ready, sr_fpu_add_ijk_ready, sr_fpu_div_offdiag_ready;
    wire [63:0]              fpu_mul_22_out, fpu_add_22_out, fpu_mul_ik_out, fpu_add_ik_out, fpu_add_diag_out, sqrt_diag_y;
    wire [63:0]              fpu_mul_ijk_out, fpu_add_ijk_out, fpu_div_offdiag_out, fpu_add_offdiag_out;
    reg [63:0]               diag_trans_sum, diag_trans_prod, fpu_mul_ik_op, diag_aii, offdiag_ljj;
    reg [63:0]               offdiag_trans_sum, offdiag_trans_prod, fpu_mul_ijk_opa, fpu_mul_ijk_opb, offdiag_aij;
    wire [SIZE-2:0]          fpu_i1_ready;
    // Since SIZE is at least 2, keep an additional bit (MSB) which will remain unused.
    // For SIZE=2, compute array for l_i,2 (i > 2) is NOT triggered.
    wire [SIZE-2:0]          fpu_mul_i2_ready, fpu_add_i2_ready, fpu_div_i2_ready;
    wire [((SIZE-1)*64)-1:0] fpu_mul_i2_out, fpu_add_i2_out; // Keep an additional vector (MSB).
    reg [((SIZE-1)*64)-1:0]  sqrt_diag, sqrt_diag_sel; // Two most significant 64-bit wide slices unused (declared because SIZE >= 2).
    reg [OD_IN-1:0]          offdiag_ij, offdiag_ij_sel; // TODO: Refer top comment (4).
    reg [1:0]                state_trav, state_diag;
    reg [2:0]                state_offdiag;
    reg                      en_i2, ready_trav, en_diag, ready_diag, en_offdiag, ready_offdiag;
    reg                      en_fpu_mul_ik, en_fpu_add_ik, en_fpu_sumsqrt_ik, en_fpu_mul_ijk, en_fpu_add_ijk, en_fpu_sumdiv_ijk;
    reg [2:0]                tmr_i2, tmr_diag, tmr_offdiag, tmr_fpu_mul_ik, tmr_fpu_add_ik, tmr_fpu_sumsqrt_ik;
    reg [2:0]                tmr_fpu_mul_ijk, tmr_fpu_add_ijk, tmr_fpu_sumdiv_ijk;
    reg [7:0]                trav_i, trav_j, diag_k, offdiag_k; // 8-bit wide should limit SIZE to a maximum of 256.

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

    // Off-diagonal machine, triggered by en_offdiag.
    //     l_ij = (a_ij - MAC_sum) / l_jj when MAC_sum = sum(l_ik * l_jk) from k=1 to j-1 
    //         i, j correspond to trav_i, trav_j respectively and are set by Traversal 
    //         so both are effectively constants for a single run of Off-diagonal.
    // It can be noted that the off-diagonal and diagonal element computations are very similar.
    always @(posedge clk or negedge clk) begin
        if (rst && clk) begin
            // Do initialisations.
            offdiag_k <= 0;
            offdiag_trans_sum <= 0;
            offdiag_trans_prod <= 0;
            fpu_mul_ijk_opa <= 0;
            fpu_mul_ijk_opb <= 0;
            en_fpu_mul_ijk <= 0;
            tmr_fpu_mul_ijk <= 0;
            en_fpu_add_ijk <= 0;
            tmr_fpu_add_ijk <= 0;
            en_fpu_sumdiv_ijk <= 0;
            tmr_fpu_sumdiv_ijk <= 0;
            offdiag_ij <= 0;
            offdiag_ij_sel <= 0;
            offdiag_aij <= 0;
            offdiag_ljj <= 0;
            ready_offdiag <= 0;
        end else if (!rst && clk) begin
            case (state_offdiag)
                S_O_IDLE: begin
                    if (en_offdiag) begin
                        // Start machine.
                        // Compute and set the constants for this run of Off-diagonal.
                        offdiag_ij_sel <= MASK << ((trav_i-3)*(SIZE-3) + (trav_j-2))*64;
                        offdiag_aij <= (matrix & (MASK << (trav_i*SIZE + trav_j)*64)) >> (trav_i*SIZE + trav_j)*64; // a_i,j
                        offdiag_ljj <= (factor & (MASK << (trav_j*SIZE + trav_j)*64)) >> (trav_j*SIZE + trav_j)*64; // l_j,j
                        // Reset offdiag_k (subscript k in following comments).
                        offdiag_k <= 0;
                        // Reset transient MAC_sum.
                        offdiag_trans_sum <= 0;
                        ready_offdiag <= 0;
                        state_diag <= S_O_MUL;
                    end else begin
                        state_diag <= S_O_IDLE;
                    end
                end
                S_O_MUL: begin
                    fpu_mul_ijk_opa <= (factor & (MASK << (trav_i*SIZE + offdiag_k)*64)) >> (trav_i*SIZE + offdiag_k)*64; // l_i,k
                    fpu_mul_ijk_opb <= (factor & (MASK << (trav_j*SIZE + offdiag_k)*64)) >> (trav_j*SIZE + offdiag_k)*64; // l_j,k
                    tmr_fpu_mul_ijk <= TMR_LOAD;
                    state_offdiag <= S_O_CTRL;
                end
                S_O_CTRL: begin
                    if (fpu_mul_ijk_ready_p) begin
                        // Increment diag_k, check if within bound, and trigger addition. 
                        // If within bounds, then setup operands and also trigger multiplication.
                        offdiag_trans_prod <= fpu_mul_ijk_out;
                        tmr_fpu_add_ijk <= TMR_LOAD;
                        if (offdiag_k < trav_j - 1) begin // Setup operands and trigger multiplication. 
                            offdiag_k <= offdiag_k + 1;
                            state_offdiag <= S_O_MUL;
                        end else begin
                            state_offdiag <= S_O_CTRL; 
                        end                        
                    end else if (fpu_add_ijk_ready_p) begin
                        offdiag_trans_sum <= fpu_add_ijk_out;
                        if (offdiag_k == trav_j - 1) begin // Whether multiply-accumulate (MAC) operations should be concluded.
                            // If MAC operations are done, offdiag_trans_sum holds final MAC-ed value 
                            // for given iteration.
                            //     l_ij = (a_ij - MAC_sum)) / l_jj;
                            tmr_fpu_sumdiv_ijk <= TMR_LOAD;
                            state_offdiag <= S_O_DIV;
                        end else begin
                            state_offdiag <= S_O_CTRL;
                        end
                    end else begin
                        state_offdiag <= S_O_CTRL;
                    end
                end
                S_O_DIV: begin
                    if (fpu_div_offdiag_ready_p) begin
                        // This signals end of computation for l_i,j. Store the result in respective 
                        // offdiag_ij[] register (which should drive the corresponding factor[], wired 
                        // below in a generate block).
                        offdiag_ij <= (offdiag_ij & ~offdiag_ij_sel) | (fpu_div_offdiag_out << ((trav_i-3)*(SIZE-3) + (trav_j-2))*64);
                        ready_offdiag <= 1;
                        state_offdiag <= S_O_IDLE;
                    end else begin
                        state_offdiag <= S_O_DIV;
                    end
                end
            endcase
        end else if (!rst && !clk) begin
            // Manage timers and enable triggers.
            if (tmr_fpu_mul_ijk != 0 && en_fpu_mul_ijk) begin
                tmr_fpu_mul_ijk <= tmr_fpu_mul_ijk - 1;
            end else if (tmr_fpu_mul_ijk == 0 && en_fpu_mul_ijk) begin
                en_fpu_mul_ijk <= 0;
            end else if (tmr_fpu_mul_ijk != 0 && !en_fpu_mul_ijk) begin
                en_fpu_mul_ijk <= 1;
            end
            if (tmr_fpu_add_ijk != 0 && en_fpu_add_ijk) begin
                tmr_fpu_add_ijk <= tmr_fpu_add_ijk - 1;
            end else if (tmr_fpu_add_ijk == 0 && en_fpu_add_ijk) begin
                en_fpu_add_ijk <= 0;
            end else if (tmr_fpu_add_ijk != 0 && !en_fpu_add_ijk) begin
                en_fpu_add_ijk <= 1;
            end
            if (tmr_fpu_sumdiv_ijk != 0 && en_fpu_sumdiv_ijk) begin
                tmr_fpu_sumdiv_ijk <= tmr_fpu_sumdiv_ijk - 1;
            end else if (tmr_fpu_sumdiv_ijk == 0 && en_fpu_sumdiv_ijk) begin
                en_fpu_sumdiv_ijk <= 0;
            end else if (tmr_fpu_sumdiv_ijk != 0 && !en_fpu_sumdiv_ijk) begin
                en_fpu_sumdiv_ijk <= 1;
            end
        end
    end

    fpu fpu_mul_ijk (
        .clk       (clk),
        .rst       (rst),
        .enable    (en_fpu_mul_ijk),
        .rmode     (ROUND),
        .fpu_op    (FPU_OP_MUL),
        .opa       (fpu_mul_ijk_opa), // l_i,k
        .opb       (fpu_mul_ijk_opb), // l_j,k
        .out       (fpu_mul_ijk_out), // l_i,k * l_j,k
        .ready     (fpu_mul_ijk_ready),
        .underflow (),
        .overflow  (),
        .inexact   (),
        .exception (),
        .invalid   ()
        );
    fpu fpu_add_ijk (
        .clk       (clk),
        .rst       (rst),
        .enable    (en_fpu_add_ijk),
        .rmode     (ROUND),
        .fpu_op    (FPU_OP_ADD),
        .opa       (offdiag_trans_prod), // l_i,k * l_j,k
        .opb       (offdiag_trans_sum), // Transient sum upto previous iteration(s).
        .out       (fpu_add_ijk_out),
        .ready     (fpu_add_ijk_ready),
        .underflow (),
        .overflow  (),
        .inexact   (),
        .exception (),
        .invalid   ()
        );

    fpu fpu_add_offdiag (
        .clk       (clk),
        .rst       (rst),
        .enable    (en_fpu_sumdiv_ijk),
        .rmode     (ROUND),
        .fpu_op    (FPU_OP_ADD),
        .opa       (offdiag_aij), // a_i,j (i, j from Traversal)
        .opb       (offdiag_trans_sum | (1 << 63)), // -(MAC_sum)
        .out       (fpu_add_offdiag_out), // a_i,j - MAC_sum
        .ready     (fpu_add_offdiag_ready),
        .underflow (),
        .overflow  (),
        .inexact   (),
        .exception (),
        .invalid   ()
        );
    fpu fpu_div_offdiag (
        .clk       (clk),
        .rst       (rst),
        .enable    (fpu_add_offdiag_ready),
        .rmode     (ROUND),
        .fpu_op    (FPU_OP_DIV),
        .opa       (fpu_add_offdiag_out), // a_i,j - MAC_sum
        .opb       (offdiag_ljj), // l_j,j
        .out       (fpu_div_offdiag_out), // (a_i,j - MAC_sum) / l_j,j
        .ready     (fpu_div_offdiag_ready),
        .underflow (),
        .overflow  (),
        .inexact   (),
        .exception (),
        .invalid   ()
        );

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
            ready_diag <= 0;
        end else if (!rst && clk) begin
            case (state_diag)
                S_D_IDLE: begin
                    if (en_diag) begin
                        // Start machine.
                        // Compute and set the constants for this run of Diagonal.
                        sqrt_diag_sel <= MASK << (trav_i-2)*64;
                        diag_aii <= (matrix & (MASK << (trav_i*SIZE + trav_i)*64)) >> (trav_i*SIZE + trav_i)*64;
                        // Reset diag_k (subscript k in following comments).
                        diag_k <= 0;
                        // Reset transient MAC_sum.
                        diag_trans_sum <= 0;
                        ready_diag <= 0;
                        state_diag <= S_D_MUL;
                    end else begin
                        state_diag <= S_D_IDLE;
                    end
                end
                S_D_MUL: begin
                    fpu_mul_ik_op <= (factor & (MASK << (trav_i*SIZE + diag_k)*64)) >> (trav_i*SIZE + diag_k)*64;
                    tmr_fpu_mul_ik <= TMR_LOAD;
                    state_diag <= S_D_CTRL;
                end
                S_D_CTRL: begin
                    if (fpu_mul_ik_ready_p) begin
                        // Increment diag_k, check if within bound, and trigger addition. 
                        // If within bounds, then setup operands and also trigger multiplication.
                        diag_trans_prod <= fpu_mul_ik_out;
                        tmr_fpu_add_ik <= TMR_LOAD;
                        if (diag_k < trav_i - 1) begin // Setup operands and trigger multiplication. 
                            diag_k <= diag_k + 1;
                            state_diag <= S_D_MUL;
                        end else begin
                            state_diag <= S_D_CTRL; 
                        end                        
                    end else if (fpu_add_ik_ready_p) begin
                        diag_trans_sum <= fpu_add_ik_out;
                        if (diag_k == trav_i - 1) begin // Whether multiply-accumulate (MAC) operations should be concluded.
                            // If MAC operations are done, diag_trans_sum holds final MAC-ed value 
                            // for given iteration.
                            //     l_ii = sqrt(a_ii - MAC_sum))
                            tmr_fpu_sumsqrt_ik <= TMR_LOAD;
                            state_diag <= S_D_SQRT;
                        end else begin
                            state_diag <= S_D_CTRL;
                        end
                    end else begin
                        state_diag <= S_D_CTRL;
                    end
                end
                S_D_SQRT: begin
                    if (sqrt_diag_ready_p) begin
                        // This signals end of computation for l_ii. Store the result in 
                        // respective sqrt_diag[] register (which should drive the corresponding 
                        // factor[], wired below in a generate block).
                        sqrt_diag <= (sqrt_diag & ~sqrt_diag_sel) | (sqrt_diag_y << (trav_i-2)*64);
                        ready_diag <= 1;
                        state_diag <= S_D_IDLE;
                    end else begin
                        state_diag <= S_D_SQRT;
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
        .out       (fpu_add_ik_out),
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

    always @(negedge clk) begin
        if (rst) begin
            sr_fpu_add_ik_ready <= 0;
            sr_fpu_mul_ik_ready <= 0;
            sr_sqrt_diag_ready <= 0;
            sr_fpu_mul_ijk_ready <= 0;
            sr_fpu_add_ijk_ready <= 0;
            sr_fpu_div_offdiag_ready <= 0;
        end else begin
            sr_fpu_add_ik_ready <= {sr_fpu_add_ik_ready[0], fpu_add_ik_ready};
            sr_fpu_mul_ik_ready <= {sr_fpu_mul_ik_ready[0], fpu_mul_ik_ready};
            sr_sqrt_diag_ready <= {sr_sqrt_diag_ready[0], sqrt_diag_ready};
            sr_fpu_mul_ijk_ready <= {sr_fpu_mul_ijk_ready[0], fpu_mul_ijk_ready};
            sr_fpu_add_ijk_ready <= {sr_fpu_add_ijk_ready[0], fpu_add_ijk_ready};
            sr_fpu_div_offdiag_ready <= {sr_fpu_div_offdiag_ready[0], fpu_div_offdiag_ready};
        end
    end

    assign fpu_add_ik_ready_p = ~sr_fpu_add_ik_ready[1] & fpu_add_ik_ready;
    assign fpu_mul_ik_ready_p = ~sr_fpu_mul_ik_ready[1] & fpu_mul_ik_ready;
    assign sqrt_diag_ready_p = ~sr_sqrt_diag_ready[1] & sqrt_diag_ready;
    assign fpu_mul_ijk_ready_p = ~sr_fpu_mul_ijk_ready[1] & fpu_mul_ijk_ready;
    assign fpu_add_ijk_ready_p = ~sr_fpu_add_ijk_ready[1] & fpu_add_ijk_ready;
    assign fpu_div_offdiag_ready_p = ~sr_fpu_div_offdiag_ready[1] & fpu_div_offdiag_ready;

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

    // Connect off-diagonal elements from offdiag_ij[] reg store (where Off-diagonal 
    // machine stores computed values) to respective factor[] elements.
    generate
        genvar ods_i, ods_j; // ods = Off-diag store.
        for (ods_j = 2; ods_j <= SIZE-2; ods_j = ods_j + 1) begin
            for (ods_i = ods_j + 1; ods_i <= SIZE-1; ods_i = ods_i + 1) begin
                localparam ODS_F = ( (ods_i*SIZE + ods_j)*64 );
                localparam ODS_O = ( ((ods_i-3)*(SIZE-3) + (ods_j-2))*64 );
                assign factor[ODS_F+63:ODS_F] = offdiag_ij[ODS_O+63:ODS_O];
            end
        end
    endgenerate

    // Connect diagonal elements from sqrt_diag[] reg store (where Diagonal 
    // machine stores computed values) to resepective output factor[] elements.
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
