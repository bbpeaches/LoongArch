module adder(
    input  [31:0] A,
    input  [31:0] B,
    input         Cin,
    output [31:0] F,
    output        Cout
);
    // 32位加32位再加1位进位，结果最大33位。
    // 最高位自动赋给 Cout，低 32 位赋给 F。
    assign {Cout, F} = A + B + Cin;

endmodule