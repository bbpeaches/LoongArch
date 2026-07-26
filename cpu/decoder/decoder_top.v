module decoder_top (
    input  wire [31:0] inst,
    output wire [ 4:0] rf_raddr1,
    output wire [ 4:0] rf_raddr2,
    output wire        rf_we,
    output wire [ 4:0] rf_waddr,
    output wire [31:0] imm,
    output wire        use_imm,
    output wire [11:0] alu_op,
    output wire        mem_en,
    output wire        invalid,
    output wire [ 1:0] wb_sel,    
    output wire        inst_b,
    output wire        inst_beq,
    output wire        inst_bne,
    output wire        inst_blt,
    output wire        inst_bge,
    output wire        inst_bltu,
    output wire        inst_bgeu,
    output wire        is_bl,
    output wire        is_jirl,
    output wire        is_pcaddu12i,
    output wire        is_ld_b,
    output wire        is_st_b,
    output wire        is_st_w,
    output wire        is_ld_bu
);
    wire [21:0] op_22 = inst[31:10];
    wire [16:0] op_17 = inst[31:15];
    wire [ 9:0] op_10 = inst[31:22];
    wire [ 6:0] op_7  = inst[31:25];
    wire [ 5:0] op_6  = inst[31:26];

    wire inst_cpucfg    = (op_22 == 22'b0000_0000_0001_1011_0100_00);

    // 算术 / 逻辑 / 移位
    wire inst_add_w     = (op_17 == 17'b0000_0000_0001_00000);
    wire inst_sub_w     = (op_17 == 17'b0000_0000_0001_00010);
    wire inst_and       = (op_17 == 17'b0000_0000_0001_01001);
    wire inst_or        = (op_17 == 17'b0000_0000_0001_01010);
    wire inst_xor       = (op_17 == 17'b0000_0000_0001_01011);
    wire inst_nor       = (op_17 == 17'b0000_0000_0001_01000);
    wire inst_slt       = (op_17 == 17'b0000_0000_0001_00100);
    wire inst_sltu      = (op_17 == 17'b0000_0000_0001_00101);
    wire inst_mul_w     = (op_17 == 17'b0000_0000_0001_11000);
    wire inst_sll_w     = (op_17 == 17'b0000_0000_0001_01110);
    wire inst_srl_w     = (op_17 == 17'b0000_0000_0001_01111);
    wire inst_sra_w     = (op_17 == 17'b0000_0000_0001_10000);

    // 移位 / 立即数
    wire inst_slli_w    = (op_17 == 17'b0000_0000_0100_00001);
    wire inst_srli_w    = (op_17 == 17'b0000_0000_0100_01001);
    wire inst_srai_w    = (op_17 == 17'b0000_0000_0100_10001);
    wire inst_slti      = (op_10 == 10'b0000_0010_00);
    wire inst_sltui     = (op_10 == 10'b0000_0010_01);
    wire inst_addi_w    = (op_10 == 10'b0000_0010_10);
    wire inst_ori       = (op_10 == 10'b0000_0011_10);
    wire inst_andi      = (op_10 == 10'b0000_0011_01);
    wire inst_xori      = (op_10 == 10'b0000_0011_11);

    // 访存
    wire inst_ld_w      = (op_10 == 10'b0010_1000_10);
    wire inst_st_w      = (op_10 == 10'b0010_1001_10);
    wire inst_ld_b      = (op_10 == 10'b0010_1000_00);
    wire inst_st_b_raw  = (op_10 == 10'b0010_1001_00);
    wire inst_ld_bu     = (op_10 == 10'b0010_1010_00); 

    // 跳转 / PC 相对
    wire inst_pcaddu12i = (op_7  == 7'b0001_110);
    wire inst_lu12i_w   = (op_7  == 7'b0001_010);
    wire inst_bl_raw    = (op_6  == 6'b0101_01);
    wire inst_jirl_raw  = (op_6  == 6'b0100_11);
    assign inst_b       = (op_6  == 6'b0101_00);
    assign inst_beq     = (op_6  == 6'b0101_10);
    assign inst_bne     = (op_6  == 6'b0101_11);
    assign inst_blt     = (op_6  == 6'b0110_00); 
    assign inst_bge     = (op_6  == 6'b0110_01); 
    assign inst_bltu    = (op_6  == 6'b0110_10);
    assign inst_bgeu    = (op_6  == 6'b0110_11);
    
    // rj 永远在 inst[9:5]，直接盲读
    assign rf_raddr1 = inst[9:5];   

    // 直接用高 6 位和高 10 位的硬编码粗略判断 rkd，避开慢速译码链
    wire fast_dest_is_raddr2 = (inst[31:26] == 6'b0101_10) | // beq
                               (inst[31:26] == 6'b0101_11) | // bne
                               (inst[31:26] == 6'b0110_00) | // blt
                               (inst[31:26] == 6'b0110_01) | // bge
                               (inst[31:26] == 6'b0110_10) | // bltu
                               (inst[31:26] == 6'b0110_11) | // bgeu
                               (inst[31:22] == 10'b0010_1001_10) | // st.w
                               (inst[31:22] == 10'b0010_1001_00);  // st.b

    assign rf_raddr2 = fast_dest_is_raddr2 ? inst[4:0] : inst[14:10];
    assign rf_waddr  = (inst_bl_raw) ? 5'd1 : inst[4:0];  

    assign invalid = ~(inst_add_w | inst_sub_w | inst_and | inst_or | inst_xor |
                       inst_nor | inst_slt | inst_sltu | inst_mul_w | inst_sll_w | inst_srl_w | inst_sra_w |
                       inst_slli_w | inst_srli_w | inst_srai_w | inst_slti | inst_sltui |
                       inst_addi_w | inst_ori | inst_andi | inst_xori | inst_ld_w | inst_st_w |
                       inst_ld_b | inst_st_b_raw | inst_pcaddu12i | inst_lu12i_w |
                       inst_bl_raw | inst_jirl_raw | inst_cpucfg | inst_b |
                       inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu | inst_ld_bu);

    id_ctrl_gen _id_ctrl_gen (
        .inst_sltu      (inst_sltu),
        .inst_nor       (inst_nor),
        .inst_srai_w    (inst_srai_w),
        .inst_add_w     (inst_add_w),
        .inst_sub_w     (inst_sub_w),
        .inst_and       (inst_and),
        .inst_mul_w     (inst_mul_w),
        .inst_slli_w    (inst_slli_w),
        .inst_slti      (inst_slti),
        .inst_addi_w    (inst_addi_w),
        .inst_ori       (inst_ori),
        .inst_ld_w      (inst_ld_w),
        .inst_st_w      (inst_st_w),
        .inst_lu12i_w   (inst_lu12i_w),
        .inst_pcaddu12i (inst_pcaddu12i),
        .inst_slt       (inst_slt),
        .inst_or        (inst_or),
        .inst_xor       (inst_xor),
        .inst_sll_w     (inst_sll_w),
        .inst_srli_w    (inst_srli_w),
        .inst_andi      (inst_andi),
        .inst_xori      (inst_xori),
        .inst_srl_w     (inst_srl_w),
        .inst_sra_w     (inst_sra_w),
        .inst_sltui     (inst_sltui),
        .inst_ld_b      (inst_ld_b),
        .inst_st_b      (inst_st_b_raw),
        .inst_bl        (inst_bl_raw),
        .inst_jirl      (inst_jirl_raw),
        .inst_cpucfg    (inst_cpucfg),
        .inst_ld_bu     (inst_ld_bu), 

        .rf_we          (rf_we),
        .use_imm        (use_imm),
        .alu_op         (alu_op),
        .mem_en         (mem_en),
        .wb_sel         (wb_sel),
        .is_bl          (is_bl),
        .is_jirl        (is_jirl),
        .is_pcaddu12i   (is_pcaddu12i),
        .is_ld_b        (is_ld_b),
        .is_st_b        (is_st_b),
        .is_st_w        (is_st_w),
        .is_ld_bu       (is_ld_bu)
    );

    id_imm_ext _id_imm_ext (
        .inst         (inst[25:0]),
        .inst_ld_w    (inst_ld_w | inst_ld_b | inst_ld_bu), 
        .inst_st_w    (inst_st_w | inst_st_b_raw),
        .inst_addi_w  (inst_addi_w),
        .inst_slti    (inst_slti | inst_sltui),
        .inst_ori     (inst_ori | inst_andi | inst_xori),
        .inst_b       (inst_b | inst_bl_raw),
        .inst_beq     (inst_beq | inst_jirl_raw | inst_blt | inst_bge | inst_bltu | inst_bgeu),
        .inst_bne     (inst_bne),
        .inst_lu12i_w (inst_lu12i_w | inst_pcaddu12i),
        .inst_slli_w  (inst_slli_w | inst_srli_w | inst_srai_w),
        .imm_32       (imm)
    );

endmodule