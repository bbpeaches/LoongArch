module adder(
    input  [31:0] A,
    input  [31:0] B,
    input         Cin,
    output [31:0] F,
    output        Cout
);
    assign {Cout, F} = A + B + Cin;

endmodule