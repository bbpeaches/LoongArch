// 已经弃用
module calc_next_pc (
    input  wire [31:0] pc,
    input  wire [31:0] rj_val,    
    input  wire        jump,
    input  wire        is_jirl,
    input  wire [31:0] imm_32,
    output wire [31:0] next_pc
);
    wire [31:0] seq_pc = pc + 32'd4;
    // 如果是 jirl，基地址是 rj 的值；否则是当前 PC
    wire [31:0] base_pc = is_jirl ? rj_val : pc;
    assign next_pc = jump ? (base_pc + imm_32) : seq_pc;
endmodule