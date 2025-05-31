// Basic structural logic modules for cache_controller

module and2(input a, input b, output y);
    assign y = a & b;
endmodule

module or4(
    input a, input b, input c, input d,
    output y
);
    assign y = a | b | c | d;
endmodule

module comparator19(
    input [18:0] a,
    input [18:0] b,
    output eq
);
    assign eq = (a == b);
endmodule

module mux2_32bit(
    input sel,
    input [31:0] in0,
    input [31:0] in1,
    output [31:0] out
);
    assign out = sel ? in1 : in0;
endmodule

module mux4_32bit(
    input [3:0] sel, // One-hot
    input [31:0] in0,
    input [31:0] in1,
    input [31:0] in2,
    input [31:0] in3,
    output [31:0] out
);
    assign out = (sel[0] ? in0 : 32'b0) |
                 (sel[1] ? in1 : 32'b0) |
                 (sel[2] ? in2 : 32'b0) |
                 (sel[3] ? in3 : 32'b0);
endmodule

module mux4_512bit(
    input [1:0] sel,
    input [511:0] in0,
    input [511:0] in1,
    input [511:0] in2,
    input [511:0] in3,
    output [511:0] out
);
    assign out = (sel == 2'd0) ? in0 :
                 (sel == 2'd1) ? in1 :
                 (sel == 2'd2) ? in2 : in3;
endmodule
