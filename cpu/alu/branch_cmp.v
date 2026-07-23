module branch_cmp (
    input  wire [31:0] val1,
    input  wire [31:0] val2,
    output wire        is_eq,
    output wire        is_lt,
    output wire        is_ltu
);
    assign is_eq  = (val1 === val2);
    
    // 有符号比较
    wire sign1 = val1[31];
    wire sign2 = val2[31];
    assign is_lt  = (sign1 != sign2) ? sign1 : (val1 < val2);
    
    // 无符号比较
    assign is_ltu = (val1 < val2);

endmodule