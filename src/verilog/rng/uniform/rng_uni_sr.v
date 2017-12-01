module rng_uni_sr #(parameter K = 32) (
    output wire dout,
    input wire  din,
    input wire  ce,
    input wire  rst,
    input wire  clk
    );

    reg [K : 0] bits;

    always @(posedge clk) begin
        casez ({rst, ce})
            2'b1?: begin
                bits <= 0;
            end
            2'b01: begin
               bits <= {bits[K-1 : 0], din}; 
            end
            2'b00: begin
                bits <= {bits[K-1 : 0], bits[K]};
            end
        endcase
    end

    assign dout = bits[K];

endmodule
