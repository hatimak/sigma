module rng_uni (
    output reg [31 : 0] rng,
    output wire         s_out,
    input wire          s_in,
    input wire          ce,
    input wire          mode,
    input wire          rst,
    input wire          clk
    );

    wire [31 : 0] fifo_out;

    always @(posedge clk) begin
        casez ({rst, ce})
            2'b1?: begin
                rng <= 0;
            end
            2'b01: begin
                rng[21] <= mode ? fifo_out[0]  : (fifo_out[0]  ^ fifo_out[20] ^ fifo_out[4] );
                rng[5]  <= mode ? fifo_out[1]  : (fifo_out[0]  ^ fifo_out[1]  ^ fifo_out[12]);
                rng[16] <= mode ? fifo_out[2]  : (fifo_out[22] ^ fifo_out[18] ^ fifo_out[2] );
                rng[29] <= mode ? fifo_out[3]  : (fifo_out[3]  ^ fifo_out[19] ^ fifo_out[24]);
                rng[19] <= mode ? fifo_out[4]  : (fifo_out[0]  ^ fifo_out[4]  ^ fifo_out[24]);
                rng[0]  <= mode ? fifo_out[5]  : (fifo_out[5]  ^ fifo_out[11] ^ fifo_out[16]);
                rng[14] <= mode ? fifo_out[6]  : (fifo_out[30] ^ fifo_out[6]  ^ fifo_out[28]);
                rng[31] <= mode ? s_in         : (fifo_out[18] ^ fifo_out[7]                );
                rng[2]  <= mode ? fifo_out[8]  : (fifo_out[8]  ^ fifo_out[17] ^ fifo_out[13]);
                rng[13] <= mode ? fifo_out[9]  : (fifo_out[3]  ^ fifo_out[26] ^ fifo_out[9]);
                rng[28] <= mode ? fifo_out[10] : (fifo_out[5]  ^ fifo_out[10] ^ fifo_out[14]);
                rng[26] <= mode ? fifo_out[11] : (fifo_out[15] ^ fifo_out[11] ^ fifo_out[21]);
                rng[1]  <= mode ? fifo_out[12] : (fifo_out[30] ^ fifo_out[12]               );
                rng[20] <= mode ? fifo_out[13] : (fifo_out[6]  ^ fifo_out[13] ^ fifo_out[29]);
                rng[24] <= mode ? fifo_out[14] : (fifo_out[4]  ^ fifo_out[10] ^ fifo_out[14]);
                rng[7]  <= mode ? fifo_out[15] : (fifo_out[15] ^ fifo_out[27] ^ fifo_out[13]);
                rng[8]  <= mode ? fifo_out[16] : (fifo_out[2]  ^ fifo_out[16] ^ fifo_out[14]);
                rng[25] <= mode ? fifo_out[17] : (fifo_out[20] ^ fifo_out[17] ^ fifo_out[29]);
                rng[3]  <= mode ? fifo_out[18] : (fifo_out[3]  ^ fifo_out[18] ^ fifo_out[25]);
                rng[12] <= mode ? fifo_out[19] : (fifo_out[8]  ^ fifo_out[6]  ^ fifo_out[19]);
                rng[11] <= mode ? fifo_out[20] : (fifo_out[20] ^ fifo_out[19] ^ fifo_out[28]);
                rng[17] <= mode ? fifo_out[21] : (fifo_out[15] ^ fifo_out[23] ^ fifo_out[21]);
                rng[9]  <= mode ? fifo_out[22] : (fifo_out[1]  ^ fifo_out[22]               );
                rng[30] <= mode ? fifo_out[23] : (fifo_out[23] ^ fifo_out[9]  ^ fifo_out[31]);
                rng[18] <= mode ? fifo_out[24] : (fifo_out[1]  ^ fifo_out[2]  ^ fifo_out[24]);
                rng[27] <= mode ? fifo_out[25] : (fifo_out[8]  ^ fifo_out[23] ^ fifo_out[25]);
                rng[4]  <= mode ? fifo_out[26] : (fifo_out[26] ^ fifo_out[21] ^ fifo_out[31]);
                rng[22] <= mode ? fifo_out[27] : (fifo_out[27] ^ fifo_out[17] ^ fifo_out[25]);
                rng[15] <= mode ? fifo_out[28] : (fifo_out[27] ^ fifo_out[26] ^ fifo_out[28]);
                rng[6]  <= mode ? fifo_out[29] : (fifo_out[9]  ^ fifo_out[16] ^ fifo_out[29]);
                rng[23] <= mode ? fifo_out[30] : (fifo_out[5]  ^ fifo_out[30] ^ fifo_out[7] );
                rng[10] <= mode ? fifo_out[31] : (fifo_out[10] ^ fifo_out[11] ^ fifo_out[31]);
            end
            2'b00: begin
                // Do nothing.
                // TODO: Get rid of CE, maybe?
            end
        endcase
    end

    assign s_out = fifo_out[7];

    rng_uni_sr #(.K(32)) fifo_0 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[5]),
        .dout (fifo_out[0])
        );

    rng_uni_sr #(.K(32)) fifo_1 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[16]),
        .dout (fifo_out[1])
        );

    rng_uni_sr #(.K(30)) fifo_2 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[29]),
        .dout (fifo_out[2])
        );

    rng_uni_sr #(.K(32)) fifo_3 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[19]),
        .dout (fifo_out[3])
        );

    rng_uni_sr #(.K(32)) fifo_4 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[0]),
        .dout (fifo_out[4])
        );

    rng_uni_sr #(.K(32)) fifo_5 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[14]),
        .dout (fifo_out[5])
        );

    rng_uni_sr #(.K(31)) fifo_6 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[31]),
        .dout (fifo_out[6])
        );

    rng_uni_sr #(.K(30)) fifo_7 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[2]),
        .dout (fifo_out[7])
        );

    rng_uni_sr #(.K(32)) fifo_8 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[13]),
        .dout (fifo_out[8])
        );

    rng_uni_sr #(.K(32)) fifo_9 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[28]),
        .dout (fifo_out[9])
        );

    rng_uni_sr #(.K(32)) fifo_10 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[26]),
        .dout (fifo_out[10])
        );

    rng_uni_sr #(.K(32)) fifo_11 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[1]),
        .dout (fifo_out[11])
        );

    rng_uni_sr #(.K(32)) fifo_12 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[20]),
        .dout (fifo_out[12])
        );

    rng_uni_sr #(.K(32)) fifo_13 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[24]),
        .dout (fifo_out[13])
        );

    rng_uni_sr #(.K(29)) fifo_14 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[7]),
        .dout (fifo_out[14])
        );

    rng_uni_sr #(.K(32)) fifo_15 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[8]),
        .dout (fifo_out[15])
        );

    rng_uni_sr #(.K(29)) fifo_16 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[25]),
        .dout (fifo_out[16])
        );

    rng_uni_sr #(.K(32)) fifo_17 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[3]),
        .dout (fifo_out[17])
        );

    rng_uni_sr #(.K(32)) fifo_18 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[12]),
        .dout (fifo_out[18])
        );

    rng_uni_sr #(.K(32)) fifo_19 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[11]),
        .dout (fifo_out[19])
        );

    rng_uni_sr #(.K(32)) fifo_20 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[17]),
        .dout (fifo_out[20])
        );

    rng_uni_sr #(.K(32)) fifo_21 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[9]),
        .dout (fifo_out[21])
        );

    rng_uni_sr #(.K(32)) fifo_22 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[30]),
        .dout (fifo_out[22])
        );

    rng_uni_sr #(.K(29)) fifo_23 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[18]),
        .dout (fifo_out[23])
        );

    rng_uni_sr #(.K(25)) fifo_24 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[27]),
        .dout (fifo_out[24])
        );

    rng_uni_sr #(.K(28)) fifo_25 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[4]),
        .dout (fifo_out[25])
        );

    rng_uni_sr #(.K(32)) fifo_26 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[22]),
        .dout (fifo_out[26])
        );

    rng_uni_sr #(.K(32)) fifo_27 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[15]),
        .dout (fifo_out[27])
        );

    rng_uni_sr #(.K(31)) fifo_28 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[6]),
        .dout (fifo_out[28])
        );

    rng_uni_sr #(.K(30)) fifo_29 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[23]),
        .dout (fifo_out[29])
        );

    rng_uni_sr #(.K(32)) fifo_30 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[10]),
        .dout (fifo_out[30])
        );

    rng_uni_sr #(.K(28)) fifo_31 (
        .clk  (clk),
        .rst  (rst),
        .ce   (ce),
        .din  (rng[21]),
        .dout (fifo_out[31])
        );

endmodule
