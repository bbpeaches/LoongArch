module agu (
    input  wire [31:0] base,
    input  wire [31:0] offset,
    output wire [31:0] addr
);
    // 专门用于访存指令的地址计算
    assign addr = base + offset;

endmodule