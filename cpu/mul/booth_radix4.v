module booth_radix4_encoder #(
    parameter WIDTH = 32 // 默认被乘数位宽
)(
    input  wire [WIDTH-1:0] x,       // 被乘数 X
    input  wire [2:0]       y_vec,   // 乘数 Y 的 3 位滑动窗口 {Y[i+1], Y[i], Y[i-1]}
    output wire [WIDTH:0]   p,       // 生成的部分积 (由于可能有 2X 操作，多扩展 1 位)
    output wire             neg_c    // 负数操作标志 (用来作为末位 +1 的进位)
);
    wire add_x  = (y_vec == 3'b001) | (y_vec == 3'b010); // +1X
    wire add_2x = (y_vec == 3'b011);                     // +2X
    wire sub_x  = (y_vec == 3'b101) | (y_vec == 3'b110); // -1X
    wire sub_2x = (y_vec == 3'b100);                     // -2X

    wire sel_x  = add_x | sub_x;
    wire sel_2x = add_2x | sub_2x;
    wire neg    = sub_x | sub_2x;

    wire [WIDTH:0] ext_x = {x[WIDTH-1], x}; 
    
    wire [WIDTH:0] val = ({WIDTH+1{sel_x}}  & ext_x) | 
                         ({WIDTH+1{sel_2x}} & (ext_x << 1));

    assign p = neg ? ~val : val;
    assign neg_c = neg;

endmodule