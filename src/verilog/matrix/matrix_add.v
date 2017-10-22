// TODO: Support any-sized square matrix (only even-sized for now).
// TODO: Handle underflow, overflow, inexact, exception, invalid signals.

module matrix_add
  #(parameter SIZE = 4
   )(
    output wire [(SIZE*SIZE*64)-1:0] sum,
    output wire                      ready,
    input wire [(SIZE*SIZE*64)-1:0]  op_a,
    input wire [(SIZE*SIZE*64)-1:0]  op_b,
    input wire                       enable,
    input wire                       clk,
    input wire                       rst
    );

wire [SIZE*SIZE-1:0] enable_op;
wire [SIZE*SIZE-1:0] ready_op, underflow_op, overflow_op, inexact_op, exception_op, invalid_op;

generate
    genvar i, j;
    for (i = 0; i < SIZE; i = i + 1) begin
        for (j = 0; j < SIZE; j = j + 1) begin
            localparam INDEX = ((i * SIZE) + j);
            fpu fpu_adder(
                .clk       (clk),
                .rst       (rst),
                .enable    (enable_op[INDEX]),
                .rmode     (2'b00),
                .fpu_op    (3'b000),
                .opa       (op_a[(INDEX * 64) + 63:INDEX * 64]),
                .opb       (op_b[(INDEX * 64) + 63:INDEX * 64]),
                .out       (sum[(INDEX * 64) + 63:INDEX * 64]),
                .ready     (ready_op[INDEX]),
                .underflow (underflow_op[INDEX]),
                .overflow  (overflow_op[INDEX]),
                .inexact   (inexact_op[INDEX]),
                .exception (exception_op[INDEX]),
                .invalid   (invalid_op[INDEX])
                );
        end
    end
endgenerate

assign enable_op = {(SIZE*SIZE){enable}};
assign ready = &ready_op;

endmodule
