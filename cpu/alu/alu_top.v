module alu_top (
    input  [11:0] alu_op,
    input  [31:0] alu_src1,
    input  [31:0] alu_src2,
    output [31:0] alu_result
);
    wire op_add  = alu_op[0];
    wire op_sub  = alu_op[1];
    wire op_slt  = alu_op[2];
    wire op_sltu = alu_op[3];
    wire op_and  = alu_op[4];
    wire op_nor  = alu_op[5];
    wire op_or   = alu_op[6];
    wire op_xor  = alu_op[7];
    wire op_sll  = alu_op[8];
    wire op_srl  = alu_op[9];
    wire op_sra  = alu_op[10];
    wire op_lui  = alu_op[11]; 

    // 如果是减法或比较指令，对 B 取反，并且 Cin 置 1
    wire        adder_cin = op_sub | op_slt | op_sltu;
    wire [31:0] adder_b   = adder_cin ? ~alu_src2 : alu_src2;
    wire [31:0] adder_res;
    wire        adder_cout;

    // 32位加法器
    adder _adder(
        .A(alu_src1),
        .B(adder_b),
        .Cin(adder_cin),
        .F(adder_res),
        .Cout(adder_cout)
    );

    // --- 各条运算支路的结果 ---
    wire [31:0] add_sub_res = adder_res; // 加法和减法直接用加法器输出
    
    // 有符号比较: 符号相异看正负，符号相同看减法结果
    wire src1_is_neg = alu_src1[31];
    wire src2_is_neg = alu_src2[31];
    wire slt_res_bit = (src1_is_neg & ~src2_is_neg) | 
                       (~(src1_is_neg ^ src2_is_neg) & adder_res[31]);
    wire [31:0] slt_res  = {31'b0, slt_res_bit};

    // 无符号比较: 减法没产生进位说明 A < B
    wire [31:0] sltu_res = {31'b0, ~adder_cout};

    // 逻辑运算
    wire [31:0] and_res  = alu_src1 & alu_src2;
    wire [31:0] or_res   = alu_src1 | alu_src2;
    wire [31:0] nor_res  = ~or_res;
    wire [31:0] xor_res  = alu_src1 ^ alu_src2;

    // 移位运算 (算术右移用 $signed 转换)
    wire [4:0]  shift_amt = alu_src2[4:0];
    wire [31:0] sll_res  = alu_src1 << shift_amt;
    wire [31:0] srl_res  = alu_src1 >> shift_amt;
    wire [31:0] sra_res  = $signed(alu_src1) >>> shift_amt;
    // 直接输出 B
    wire [31:0] lui_res  = alu_src2; 

    // 结果合并，只有对应的 op_xxx 为 1 时，那一条支路的结果才会被放行，其余全被 & 成了 0，最后通过 | 汇总。
    assign alu_result = ({32{op_add | op_sub}} & add_sub_res)
                      | ({32{op_slt}}          & slt_res)
                      | ({32{op_sltu}}         & sltu_res)
                      | ({32{op_and}}          & and_res)
                      | ({32{op_nor}}          & nor_res)
                      | ({32{op_or}}           & or_res)
                      | ({32{op_xor}}          & xor_res)
                      | ({32{op_sll}}          & sll_res)
                      | ({32{op_srl}}          & srl_res)
                      | ({32{op_sra}}          & sra_res)
                      | ({32{op_lui}}          & lui_res);

endmodule