`timescale 1ns / 1ps


module vector_scale_add #(
    parameter LENGTH = 5
    ) (
    input wire                    sclr,
    input wire                    ce,
    input wire                    clk,
    input wire           [31 : 0] w,
    input wire  [32*LENGTH-1 : 0] X,
    input wire  [64*LENGTH-1 : 0] Y,

    output wire [64*LENGTH-1 : 0] P
    );

    generate
        genvar i;

        for (i = 0; i < LENGTH; i = i + 1) begin
            localparam X_LOW = 32 * i;
            localparam Y_LOW = 64 * i;
            vsad_ip_mac vsad_mac (
                .CLK      (clk),
                .CE       (ce),
                .SCLR     (sclr),
                .A        (w), // Scalar
                .B        (X[X_LOW+31 : X_LOW]),
                .C        (Y[Y_LOW+63 : Y_LOW]),
                .SUBTRACT (1'b0), // Add
                .P        (P[Y_LOW+63 : Y_LOW]),
                .PCOUT    () // Not connected
                );
        end
    endgenerate

endmodule
