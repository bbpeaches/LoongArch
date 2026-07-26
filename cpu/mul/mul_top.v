module mul_top (
    input  wire        clk, 
    input  wire        ce,     // <--- 新增
    input  wire        resetn,
    input  wire [31:0] x,   
    input  wire [31:0] y,   
    output wire [31:0] result  
);
    wire [63:0] mult_result_full;
    mult_gen_0 u_mult (
        .CLK (clk),
        .CE  (ce),         // <--- 连入
        .A   (x),
        .B   (y),
        .P   (mult_result_full)
    );
    assign result = mult_result_full[31:0];
endmodule