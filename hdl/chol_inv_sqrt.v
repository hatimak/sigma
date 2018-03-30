`timescale 1ns / 1ps

module chol_inv_sqrt #(
    parameter ITER = 1
    ) (
    input wire        clk,
    input wire        clken,
    input wire        rst,
    input wire        data_valid,
    input wire [31:0] data,

    output reg [31:0] out,
    output reg        out_valid
    );

    localparam S_IDLE           = 7'b000_0001;
    localparam S_FIXED_TO_FLOAT = 7'b000_0010;
    localparam S_MAGIC          = 7'b000_0100;
    localparam S_FLOAT_TO_FIXED = 7'b000_1000;
    localparam S_MUL_1          = 7'b001_0000;
    localparam S_SUB            = 7'b010_0000;
    localparam S_MUL_2          = 7'b100_0000;

    // For explanation, refer http://h14s.p5r.org/2012/09/0x5f3759df.html
    localparam MAGIC_NUMBER     = 32'h5f3759df;
    localparam THREE_HALFS      = 32'h0001_8000;

    localparam SUB_LATENCY      = 3;
    localparam MUL_LATENCY      = 7;

    wire          valid_fixed_to_float, fixed_to_float_valid, valid_float_to_fixed, float_to_fixed_valid;
    wire [31 : 0] out_fixed_to_float, out_sub, out_float_to_fixed, out_mult_0, out_mult_1, out_mult_2;
    reg           clken_fixed_to_float, valid_fixed_to_float_d1, valid_fixed_to_float_d2, clken_sub, 
                  clken_float_to_fixed, valid_float_to_fixed_d1, valid_float_to_fixed_d2,
                  clken_mult_0, clken_mult_1, clken_mult_2;
    reg   [3 : 0] s_count, s_iter;
    reg   [6 : 0] state;
    reg  [31 : 0] a_sub, b_sub, a_mult_1, b_mult_1;

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            s_count <= 4'b0000;
            s_iter <= 4'b0000;

            clken_fixed_to_float <= 1'b0;
            clken_sub <= 1'b0;
            a_sub <= 32'h0000_0000;
            b_sub <= 32'h0000_0000;
            clken_float_to_fixed <= 1'b0;
            clken_mult_0 <= 1'b0;
            clken_mult_1 <= 1'b0;
            a_mult_1 <= 32'h0000_0000;
            b_mult_1 <= 32'h0000_0000;
            clken_mult_2 <= 1'b0;

            out <= 32'h0000_0000;
            out_valid <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    // Determine next state
                    if (data_valid) begin
                        state <= S_FIXED_TO_FLOAT;
                    end else begin
                        state <= S_IDLE;
                    end

                    // State counter
                    if (data_valid) begin
                        s_count <= 1;
                    end else begin
                        s_count <= 0;
                    end

                    if (data_valid) begin
                        out_valid <= 1'b0;
                        s_iter <= 0;
                        // Setup signals to fixed-to-float module
                        clken_fixed_to_float <= 1'b1;
                    end
                end
                S_FIXED_TO_FLOAT: begin
                    // Determine next state
                    if (fixed_to_float_valid) begin
                        state <= S_MAGIC;
                    end else begin
                        state <= S_FIXED_TO_FLOAT;
                    end

                    if (fixed_to_float_valid) begin
                        clken_fixed_to_float <= 1'b0;

                        // Setup signals to subtracter module
                        clken_sub <= 1'b1;
                        a_sub <= MAGIC_NUMBER;
                        b_sub <= {1'b0, out_fixed_to_float[31:1]};
                    end
                end
                S_MAGIC: begin
                    // Determine next state
                    if (s_count == SUB_LATENCY) begin
                        state <= S_FLOAT_TO_FIXED;
                    end else begin
                        state <= S_MAGIC;
                    end

                    // State counter
                    if (s_count == SUB_LATENCY) begin
                        s_count <= 1;
                    end else begin
                        s_count <= s_count + 1;
                    end

                    if (s_count == SUB_LATENCY) begin
                        clken_sub <= 1'b0;

                        // Setup signals to float-to-fixed module
                        clken_float_to_fixed <= 1'b1;
                    end 
                end
                S_FLOAT_TO_FIXED: begin
                    // Determine next state
                    if (float_to_fixed_valid) begin
                        state <= S_MUL_1;
                    end else begin
                        state <= S_FLOAT_TO_FIXED;
                    end
    
                    if (float_to_fixed_valid) begin
                        clken_float_to_fixed <= 1'b0;
                        out <= out_float_to_fixed;

                        // Setup signals to multiplier modules
                        clken_mult_0 <= 1'b1;
                        clken_mult_1 <= 1'b1;
                        a_mult_1 <= out_float_to_fixed;
                        b_mult_1 <= {1'b0, data[31 : 1]};
                        clken_mult_2 <= 1'b1;
                    end
                end
                S_MUL_1: begin
                    // Determine next state
                    if (s_count == MUL_LATENCY) begin
                        state <= S_MUL_2;
                    end else begin
                        state <= S_MUL_1;
                    end

                    // State counter
                    if (s_count == MUL_LATENCY) begin
                        s_count <= 1;
                    end else begin
                        s_count <= s_count + 1;
                    end

                    if (s_count == MUL_LATENCY) begin
                        clken_mult_0 <= 1'b0;
                        clken_mult_2 <= 1'b0;

                        // Setup signals to multiplier module
                        a_mult_1 <= out_mult_0;
                        b_mult_1 <= out_mult_1;
                    end
                end
                S_MUL_2: begin
                    // Determine next state
                    if (s_count == MUL_LATENCY) begin
                        state <= S_SUB;
                    end else begin
                        state <= S_MUL_2;
                    end

                    // State counter
                    if (s_count == MUL_LATENCY) begin
                        s_count <= 1;
                    end else begin
                        s_count <= s_count + 1;
                    end

                    if (s_count == MUL_LATENCY) begin
                        clken_mult_1 <= 1'b0;

                        // Setup signals to subtracter module
                        clken_sub <= 1'b1;
                        a_sub <= out_mult_2;
                        b_sub <= out_mult_1;
                    end
                end
                S_SUB: begin
                    // Determine next state
                    if (s_count == SUB_LATENCY) begin
                        if (s_iter == ITER - 1) begin
                            state <= S_IDLE;
                        end else begin
                            state <= S_MUL_1;
                        end
                    end else begin
                        state <= S_SUB;
                    end

                    // State counter
                    if (s_count == SUB_LATENCY) begin
                        s_count <= 0;
                    end else begin
                        s_count <= s_count + 1;
                    end

                    if (s_count == SUB_LATENCY) begin
                        clken_sub <= 1'b0;

                        if (s_iter == ITER - 1) begin
                            // Computation done, extract result and raise valid
                            out <= out_sub;
                            out_valid <= 1'b1;
                        end else begin
                            s_iter <= s_iter + 1;
                            // Setup signals to multiplier modules
                            clken_mult_0 <= 1'b1;
                            clken_mult_1 <= 1'b1;
                            a_mult_1 <= out_sub;
                            b_mult_1 <= {1'b0, data[31 : 1]};
                            clken_mult_2 <= 1'b1;
                        end
                    end
                end
            endcase
        end
    end

    always @(posedge clk) begin
        valid_fixed_to_float_d1 <= clken_fixed_to_float;
        valid_fixed_to_float_d2 <= valid_fixed_to_float_d1;
        valid_float_to_fixed_d1 <= clken_float_to_fixed;
        valid_float_to_fixed_d2 <= valid_float_to_fixed_d1;
    end
    assign valid_fixed_to_float = ~valid_fixed_to_float_d2 & clken_fixed_to_float;
    assign valid_float_to_fixed = ~valid_float_to_fixed_d2 & clken_float_to_fixed;

    cholesky_ip_fixed_to_float fixed_to_float_0 (
        .aclk                 (clk),
        .aclken               (clken_fixed_to_float),
        .aresetn              (~rst),
        .s_axis_a_tvalid      (valid_fixed_to_float),
        .s_axis_a_tready      (), // Not connected
        .s_axis_a_tdata       (data),
        .m_axis_result_tvalid (fixed_to_float_valid),
        .m_axis_result_tdata  (out_fixed_to_float)
    );

    cholesky_ip_sub sub_0 (
        .A   (a_sub),
        .B   (b_sub),
        .CLK (clk),
        .CE  (clken_sub),
        .S   (out_sub)
    );

    cholesky_ip_float_to_fixed float_to_fixed_0 (
        .aclk                 (clk),
        .aclken               (clken_float_to_fixed),
        .aresetn              (~rst),
        .s_axis_a_tvalid      (valid_float_to_fixed),
        .s_axis_a_tready      (), // Not connected
        .s_axis_a_tdata       (out_sub),
        .m_axis_result_tvalid (float_to_fixed_valid),
        .m_axis_result_tdata  (out_float_to_fixed)
    );

    cholesky_ip_mult mult_0 (
        .CLK (clk),
        .A   (out),
        .B   (out),
        .CE  (clken_mult_0),
        .P   (out_mult_0)
    );

    cholesky_ip_mult mult_1 (
        .CLK (clk),
        .A   (a_mult_1),
        .B   (b_mult_1),
        .CE  (clken_mult_1),
        .P   (out_mult_1)
    );

    cholesky_ip_mult mult_2 (
        .CLK (clk),
        .A   (out),
        .B   (THREE_HALFS),
        .CE  (clken_mult_2),
        .P   (out_mult_2)
    );

endmodule
