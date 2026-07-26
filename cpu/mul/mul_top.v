module mul_top (
    input  wire        clk,     // 需要引入时钟
    input  wire        resetn,
    input  wire [31:0] x,       // 被乘数 rj
    input  wire [31:0] y,       // 乘数 rk
    output wire [31:0] result   // 乘法结果 rd
);

    wire [63:0] mult_result_full;

    mult_gen_0 u_mult (
        .CLK (clk),
        .A   (x),
        .B   (y),
        .P   (mult_result_full)
    );

    // 截取低 32 位
    assign result = mult_result_full[31:0];

endmodule