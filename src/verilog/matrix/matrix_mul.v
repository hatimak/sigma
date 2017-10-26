module matrix_mul #(parameter SIZE = 4) (
    output reg [(SIZE*SIZE*64)-1:0] prod,
    output reg                      ready,
    input wire [(SIZE*SIZE*64)-1:0] op_a,
    input wire [(SIZE*SIZE*64)-1:0] op_b,
    input wire                      enable,
    input wire                      clk,
    input wire                      rst
    );

    localparam S_IDLE  = 3'b000;
    localparam S_CTRL  = 3'b001;
    localparam S_SETUP = 3'b011;
    localparam S_BUSY  = 3'b111;
    localparam S_STORE = 3'b101;
    localparam MASK    = ((1 << 64) - 1);
    localparam ROUND   = 2'b00; // Nearest even.
    localparam FPU_ADD = 3'b000;

    reg [7:0]                   i, j, k; // 8-bit wide i, j, k should limit SIZE to a maximum of 256.
    reg [2:0]                   state;
    reg                         mac_start, add_en;
    reg [63:0]                  add_opa, add_opb, tmp_sum;
    wire [63:0]                 add_out;
    wire                        add_ready;
    reg [2:0]                   add_en_timer;
    reg [SIZE*SIZE*64-1:0]      select;
    reg [SIZE*SIZE*SIZE*64-1:0] trans_prod;

    fpu fpu_add (
    .clk       (clk),
    .rst       (rst),
    .enable    (add_en),
    .rmode     (ROUND),
    .fpu_op    (FPU_ADD),
    .opa       (add_opa),
    .opb       (add_opb),
    .out       (add_out),
    .ready     (add_ready),
    .underflow (),
    .overflow  (),
    .inexact   (),
    .exception (),
    .invalid   ()
    );

    always @(posedge clk or negedge clk) begin
        if (rst && clk) begin
            add_en <= 0;
            add_en_timer <= 0;
            ready <= 0;
            add_opa <= 0;
            add_opb <= 0;
            select <= 0;
            state <= S_IDLE;
        end else if (!rst && clk) begin
            case (state)
                S_IDLE: begin
                    if (mac_start) begin
                        i <= 0;
                        j <= 0;
                        k <= 0;
                        tmp_sum <= 0;
                        prod <= 0;
                        ready <= 0;
                        state <= S_SETUP; // SETUP OPERANDS
                    end else begin
                        state <= S_IDLE;
                    end
                end
                S_CTRL: begin
                    if (k < SIZE-1) begin
                        k <= k + 1;
                        state <= S_SETUP;
                    end else if (j < SIZE-1) begin
                        k <= 0;
                        tmp_sum <= 0;
                        j <= j + 1;
                        state <= S_SETUP;
                    end else if (i < SIZE-1) begin
                        k <= 0;
                        tmp_sum <= 0;
                        j <= 0;
                        i <= i + 1;
                        state <= S_SETUP;
                    end else begin
                        ready <= 1;
                        state <= S_IDLE;
                    end
                end
                S_SETUP: begin
                    add_opa <= tmp_sum;
                    add_opb <= (trans_prod & (MASK << (i*SIZE*SIZE + j*SIZE + k)*64)) >> (i*SIZE*SIZE + j*SIZE + k)*64;
                    add_en_timer <= 3'b100;
                    select <= MASK << (i*SIZE + j)*64;
                    state <= S_BUSY;
                end
                S_BUSY: begin
                    if (add_ready && add_en_timer == 0) begin // If add_en_timer != 0 && add_ready, then we would be operating on stale add_ready.
                        state <= S_STORE;
                    end else begin
                        state <= S_BUSY;
                    end
                end
                S_STORE: begin
                    if (k < SIZE-1) begin
                        tmp_sum <= add_out;
                    end else begin
                        // Flush the accumulated sum into respective prod[i,j].
                        prod <= (prod & ~select) | (add_out << (i*SIZE + j)*64);
                    end
                    state <= S_CTRL;
                end
            endcase
        end else if (!rst && !clk) begin
            if (add_en_timer != 0 && add_en) begin
                add_en_timer <= add_en_timer - 1;
            end else if (add_en_timer == 0 && add_en) begin
                add_en <= 0;
            end else if (add_en_timer != 0 && !add_en) begin
                add_en <= 1;
            end
        end
    end

endmodule
