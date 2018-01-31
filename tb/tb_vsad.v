`timescale 1ns / 1ps

module tb_vsad ();

    reg            clk, ce, sclr;
    reg   [31 : 0] w_1, w_2;
    reg  [159 : 0] X_1;
    reg   [63 : 0] X_2;
    reg  [127 : 0] Y_2;
    reg  [319 : 0] Y_1;

    wire [127 : 0] P_2;
    wire [319 : 0] P_1;

    vector_scale_add #(
        .LENGTH(5)
    ) uut_1 (
        .sclr (sclr),
        .ce   (ce),
        .clk  (clk),
        .w    (w_1),
        .X    (X_1),
        .Y    (Y_1),
        .P    (P_1)
        );

    vector_scale_add #(
        .LENGTH(2)
    ) uut_2 (
        .sclr (sclr),
        .ce   (ce),
        .clk  (clk),
        .w    (w_2),
        .X    (X_2),
        .Y    (Y_2),
        .P    (P_2)
        );

    initial begin
        /* Allow initial time for GSR (Global Set/Reset) to occur, 
         * applicable in post-synthesis simulations; Xilinx 
         * documentation mentions GSR occurs for first 100ns.
         */
        #200;

        clk = 1'b0;
        sclr = 1'b1; // For vsad_ip_mac, SCLR takes precedence over CE
        ce = 1'b0;

        #30;
        sclr = 1'b0;
        ce = 1'b1;
        #30;

        w_1 = 32'h0000_8000;
        X_1 = 160'hffff_8000__0000_0000__0019_c000__0001_0000__0004_8000;
        Y_1 = 320'h00000000_00000000__00000064_80000000__00000000_00000000__00000000_00000000__00000000_00000000;

        #27;
        w_2 = 32'h0000_4000;
        X_2 = 64'h0000_0000__fff1_8000;
        Y_2 = 128'h00000004_00000000__00000000_00000000;

        #200;
        $display("[%h_%h %h_%h %h_%h %h_%h %h_%h]\n", P_1[303 : 288], P_1[287 : 272], P_1[239 : 224], P_1[223 : 208], P_1[175 : 160], P_1[159 : 144], P_1[111 : 96], P_1[95 : 80], P_1[47 : 32], P_1[31 : 16]);
        $display("[%h_%h %h_%h]\n", P_2[111 : 96], P_2[95 : 80], P_2[47 : 32], P_2[31 : 16]);
        $finish;
    end

    always begin
        #5;
        clk = (clk === 1'b0);
    end

endmodule
