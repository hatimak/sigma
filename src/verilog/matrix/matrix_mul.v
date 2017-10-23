module matrix_mul #(parameter SIZE = 4) (
    output reg [(SIZE*SIZE*64)-1:0] prod,
    output reg                      ready,
    input wire [(SIZE*SIZE*64)-1:0] op_a,
    input wire [(SIZE*SIZE*64)-1:0] op_b,
    input wire                      enable,
    input wire                      clk,
    input wire                      rst
    );

    localparam S_IDLE = 2'b00;
    localparam S_I    = 2'b01;
    localparam S_J    = 2'b10;
    localparam S_K    = 2'b11;
    localparam FPU_OP_ADD = 3'b000;
    localparam FPU_OP_MUL = 3'b010;

    reg [1:0] state;
    reg [7:0] i, j, k;
    reg       ack;

    reg [2:0]   fpu_op;
    reg         enable_op;
    reg [63:0]  fpu_opa, fpu_opb;
    wire [63:0] fpu_out;
    wire        fpu_ready, fpu_underflow, fpu_overflow, fpu_inexact, fpu_exception, fpu_invalid;

    fpu fpu (
        .clk       (clk),
        .rst       (rst),
        .enable    (enable_op),
        .rmode     (2'b00),
        .fpu_op    (fpu_op),
        .opa       (fpu_opa),
        .opb       (fpu_opb),
        .out       (fpu_out),
        .ready     (fpu_ready),
        .underflow (fpu_underflow),
        .overflow  (fpu_overflow),
        .inexact   (fpu_inexact),
        .exception (fpu_exception),
        .invalid   (fpu_invalid)
        );

    always @(posedge clk) begin
        if (rst) begin
            // Do initialisations.
            state <= S_IDLE;
            i <= 0;
            j <= 0;
            k <= 0;
            ack <= 0;
            prod <= 0;
            ready <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (enable) begin
                        i <= 0;
                        j <= 0;
                        k <= 0;
                        ready <= 1'b0;
                        state <= S_K;
                    end
                end
                S_I: begin
                    if (i < SIZE) begin
                        j <= 0;
                        state <= S_J;
                    end else begin
                        state <= S_IDLE;
                        ready <= 1'b1;
                    end
                end
                S_J: begin
                    if (j < SIZE) begin
                        k <= 0;
                        state <= S_K;
                    end else begin
                        i <= i + 1;
                        state <= S_I;
                    end
                end
                S_K: begin
                    if (!ack) begin
                        state <= S_K;
                    end else if (ack && k < SIZE) begin
                        state <= S_K;
                        k <= k + 1;
                    end else if (ack && k >= SIZE) begin
                        j <= j + 1;
                        state <= S_J;
                    end
                end
            endcase
        end
    end

endmodule
