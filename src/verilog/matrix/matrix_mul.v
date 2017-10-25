module matrix_mul #(parameter SIZE = 4) (
    output reg [(SIZE*SIZE*64)-1:0] prod,
    output reg                      ready,
    input wire [(SIZE*SIZE*64)-1:0] op_a,
    input wire [(SIZE*SIZE*64)-1:0] op_b,
    input wire                      enable,
    input wire                      clk,
    input wire                      rst
    );

    parameter  ROUND_MODE = 2'b00; // Nearest even.

    localparam S_IDLE = 2'b00;
    localparam S_I    = 2'b01;
    localparam S_J    = 2'b10;
    localparam FPU_OP_ADD = 3'b000;
    localparam FPU_OP_MUL = 3'b010;
    localparam DELAY_MUL = 4;
    localparam DELAY_ADD = 3;
    localparam DELAY_OP_EN = 2;
    localparam MASK = ((1 << 64) - 1);

    reg [1:0]             state;
    reg [7:0]             i, j, k; // This should limit SIZE to a maximum of 256.
    reg                   enable_op_mul, enable_op_add, op_trigger, ack;
    reg [63:0]            fpu_mul_opa, fpu_mul_opb, fpu_add_opa, fpu_add_opb, op_sum;
    wire [63:0]           fpu_mul_out, fpu_add_out;
    wire                  fpu_mul_ready, fpu_mul_underflow, fpu_mul_overflow, fpu_mul_inexact, fpu_mul_exception, fpu_mul_invalid;
    wire                  fpu_add_ready, fpu_add_underflow, fpu_add_overflow, fpu_add_inexact, fpu_add_exception, fpu_add_invalid;
    wire                  fpu_mul_ready_d, fpu_add_ready_d, enable_op_mul_d, enable_op_add_d; // Delayed versions of original signals by DELAY_* clock cycles, to ensure signal stability.
    reg [DELAY_MUL-1:0]   shift_mul_ready;
    reg [DELAY_ADD-1:0]   shift_add_ready;
    reg [DELAY_OP_EN-1:0] shift_enable_op_mul, shift_enable_op_add;

    always @(posedge clk) begin
        if (rst) begin
            shift_mul_ready <= 0;
            shift_add_ready <= 0;
            shift_enable_op_mul <= 0;
            shift_enable_op_add <= 0;
        end else begin
            shift_mul_ready <= {shift_mul_ready[DELAY_MUL-2:0], fpu_mul_ready};
            shift_add_ready <= {shift_add_ready[DELAY_ADD-2:0], fpu_add_ready};
            shift_enable_op_mul <= {shift_enable_op_mul[DELAY_OP_EN-2:0], enable_op_mul};
            shift_enable_op_add <= {shift_enable_op_add[DELAY_OP_EN-2:0], enable_op_add};
        end
    end

    assign fpu_mul_ready_d = shift_mul_ready[DELAY_MUL-1];
    assign fpu_add_ready_d = shift_add_ready[DELAY_ADD-1];
    assign enable_op_mul_d = shift_enable_op_mul[DELAY_OP_EN-1];
    assign enable_op_add_d = shift_enable_op_add[DELAY_OP_EN-1];

    // Every op_trigger, fpu_mul_ready_d and fpu_add_ready_d coincide with positive edges of clk (because shift_*_ready shifts out only at posedge clk).
    always @(posedge op_trigger or posedge fpu_mul_ready_d or posedge fpu_add_ready_d or negedge clk) begin
        if (!clk) begin // This block can never be active when the parent procedural block is triggered either by op_trigger or fpu_*_ready_d.
            enable_op_mul <= 0;
            enable_op_add <= 0;
        end else if (op_trigger) begin
            k <= 0;
            ack <= 0;
            op_sum <= 0;
            enable_op_add <= 0;
            fpu_mul_opa <= (op_a & (MASK << (i*SIZE+k)*64)) >> (i*SIZE+k)*64;
            fpu_mul_opb <= (op_b & (MASK << (k*SIZE+j)*64)) >> (k*SIZE+j)*64;
            enable_op_mul <= 1;
        end else if (fpu_mul_ready_d) begin
            fpu_add_opa <= fpu_mul_out;
            fpu_add_opb <= op_sum;
            enable_op_add <= 1;
            if (k < (SIZE - 1)) begin
                k <= k  + 1;
                fpu_mul_opa <= (op_a & (MASK << (i*SIZE+k)*64)) >> (i*SIZE+k)*64;
                fpu_mul_opb <= (op_b & (MASK << (k*SIZE+j)*64)) >> (k*SIZE+j)*64;
                enable_op_mul <= 1;
            end
        end else if (fpu_add_ready_d) begin
            op_sum <= fpu_add_out;
            if (k >= (SIZE - 1)) begin
                ack <= 1;
            end
        end
    end

    fpu fpu_mul (
        .clk       (clk),
        .rst       (rst),
        .enable    (enable_op_mul_d),
        .rmode     (ROUND_MODE),
        .fpu_op    (FPU_OP_MUL),
        .opa       (fpu_mul_opa),
        .opb       (fpu_mul_opb),
        .out       (fpu_mul_out),
        .ready     (fpu_mul_ready),
        .underflow (fpu_mul_underflow),
        .overflow  (fpu_mul_overflow),
        .inexact   (fpu_mul_inexact),
        .exception (fpu_mul_exception),
        .invalid   (fpu_mul_invalid)
        );

    fpu fpu_add (
        .clk       (clk),
        .rst       (rst),
        .enable    (enable_op_add_d),
        .rmode     (ROUND_MODE),
        .fpu_op    (FPU_OP_ADD),
        .opa       (fpu_add_opa),
        .opb       (fpu_add_opb),
        .out       (fpu_add_out),
        .ready     (fpu_add_ready),
        .underflow (fpu_add_underflow),
        .overflow  (fpu_add_overflow),
        .inexact   (fpu_add_inexact),
        .exception (fpu_add_exception),
        .invalid   (fpu_add_invalid)
        );

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            i <= 0;
            j <= 0;
            prod <= 0;
            ready <= 0;
            op_trigger <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (enable) begin
                        i <= 0;
                        j <= 0;
                        ready <= 1'b0;
                        state <= S_J;
                        op_trigger <= 1'b1;
                    end else begin
                        state <= S_IDLE;
                    end
                end
                S_I: begin
                    if (i < (SIZE - 1)) begin
                        i <= i + 1;
                        j <= 0;
                        op_trigger <= 1'b1; // op_trigger is guranteed to be low prior to raising here.
                        state <= S_J;
                    end else begin
                        state <= S_IDLE;
                        ready <= 1'b1;
                    end
                end
                S_J: begin
                    if (!ack) begin
                        state <= S_J;
                        op_trigger <= 1'b0; // Multiply and accumulate operation takes multiple cycles so op_trigger can be safely lowered here.
                    end else if (ack && j < (SIZE - 1)) begin
                        state <= S_J;
                        j <= j + 1;
                        prod <= (prod & ~(MASK << (i*SIZE+j)*64)) | (op_sum << (i*SIZE+j)*64);
                        op_trigger <= 1'b1;
                    end else if (ack && j >= (SIZE - 1)) begin
                        state <= S_I;
                    end
                end
            endcase
        end
    end

endmodule
