`timescale 1ps / 1ps

module sqrt_tb ();

    reg         clk, rst, enable;
    reg [63:0]  x;
    wire        ready1, ready2, ready3, ready4;
    wire [63:0] y1, y2, y3, y4;

    localparam x1   = 64'h40d0f22e726636c1; // 17352.7257323775
    localparam x1_r = 64'h4060775a124d7451; // sqrt(17352.7257323775) = 131.72974505546384
    localparam x2   = 64'h401bb14742b4b076; // 6.9231234
    localparam x2_r = 64'h40050ca99d6ea71d; // sqrt(6.9231234) = 2.631182889880519
    localparam x3   = 64'h3fc70a0cf96ca3d1; // 0.17999422244
    localparam x3_r = 64'h3fdb2707ebea7323; // sqrt(0.17999422244) = 0.424257259737532

    sqrt #(.ITER(1)) UUT_1 (
        .y      (y1),
        .ready  (ready1),
        .x      (x),
        .enable (enable),
        .clk    (clk),
        .rst    (rst)
        );

    sqrt #(.ITER(2)) UUT_2 (
        .y      (y2),
        .ready  (ready2),
        .x      (x),
        .enable (enable),
        .clk    (clk),
        .rst    (rst)
        );

    sqrt #(.ITER(3)) UUT_3 (
        .y      (y3),
        .ready  (ready3),
        .x      (x),
        .enable (enable),
        .clk    (clk),
        .rst    (rst)
        );

    sqrt #(.ITER(4)) UUT_4 (
        .y      (y4),
        .ready  (ready4),
        .x      (x),
        .enable (enable),
        .clk    (clk),
        .rst    (rst)
        );

    initial begin
        $dumpfile("sqrt.vcd");
        $dumpvars(0, sqrt_tb);
        rst = 1'b1;
        clk = 1'b0;
        enable = 1'b0;
        #20000;
        rst = 1'b0;
        x = x1;
        $display("Square root of x = 0x%h (this is floating point representation of real number)", x);
        #20000;
        enable = 1'b1;
        #20000;
        enable = 1'b0;
        #3000000;
        $display("\t1 iteration of Newton approximation,  sqrt(x) = 0x%h", y1);
        #3000000;
        $display("\t2 iterations of Newton approximation, sqrt(x) = 0x%h", y2);
        #3000000;
        $display("\t3 iterations of Newton approximation, sqrt(x) = 0x%h", y3);
        #3000000;
        $display("\t4 iterations of Newton approximation, sqrt(x) = 0x%h", y4);
        $display("\t                              Actual, sqrt(x) = 0x%h", x1_r);

        x = x2;
        $display("Square root of x = 0x%h (this is floating point representation of real number)", x);
        #20000;
        enable = 1'b1;
        #20000;
        enable = 1'b0;
        #3000000;
        $display("\t1 iteration of Newton approximation,  sqrt(x) = 0x%h", y1);
        #3000000;
        $display("\t2 iterations of Newton approximation, sqrt(x) = 0x%h", y2);
        #3000000;
        $display("\t3 iterations of Newton approximation, sqrt(x) = 0x%h", y3);
        #3000000;
        $display("\t4 iterations of Newton approximation, sqrt(x) = 0x%h", y4);
        $display("\t                              Actual, sqrt(x) = 0x%h", x2_r);

        x = x3;
        $display("Square root of x = 0x%h (this is floating point representation of real number)", x);
        #20000;
        enable = 1'b1;
        #20000;
        enable = 1'b0;
        #3000000;
        $display("\t1 iteration of Newton approximation,  sqrt(x) = 0x%h", y1);
        #3000000;
        $display("\t2 iterations of Newton approximation, sqrt(x) = 0x%h", y2);
        #3000000;
        $display("\t3 iterations of Newton approximation, sqrt(x) = 0x%h", y3);
        #3000000;
        $display("\t4 iterations of Newton approximation, sqrt(x) = 0x%h", y4);
        $display("\t                              Actual, sqrt(x) = 0x%h", x3_r);

        $finish;
    end

    always begin
        #5000;
        clk = ~clk;
    end

endmodule
