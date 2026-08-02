module id_ctrl_gen (
    input  wire inst_sltu,
    input  wire inst_nor,
    input  wire inst_srai_w,
    input  wire inst_add_w,
    input  wire inst_sub_w,
    input  wire inst_and,
    input  wire inst_mul_w,
    input  wire inst_slli_w,
    input  wire inst_slti,
    input  wire inst_addi_w,
    input  wire inst_ori,
    input  wire inst_ld_w,
    input  wire inst_st_w,
    input  wire inst_lu12i_w,
    input  wire inst_pcaddu12i,
    input  wire inst_slt,
    input  wire inst_or,
    input  wire inst_xor,
    input  wire inst_sll_w,
    input  wire inst_srli_w,
    input  wire inst_andi,
    input  wire inst_xori,
    input  wire inst_srl_w,
    input  wire inst_sra_w,
    input  wire inst_sltui,
    input  wire inst_ld_b,
    input  wire inst_st_b,
    input  wire inst_bl,
    input  wire inst_jirl,
    input  wire inst_cpucfg,
    input  wire inst_ld_bu,
    input  wire inst_csr,
    input  wire inst_cacop,

    output wire        rf_we,         
    output wire        use_imm,       
    output wire [11:0] alu_op,        
    output wire        mem_en,        
    output wire [ 1:0] wb_sel,        
    output wire        is_bl,
    output wire        is_jirl,
    output wire        is_pcaddu12i,
    output wire        is_ld_b,
    output wire        is_st_b,
    output wire        is_st_w,
    output wire        is_ld_bu
);
    assign rf_we = inst_add_w | inst_sub_w | inst_and  | inst_mul_w |
                   inst_slli_w| inst_slti  | inst_sltui | inst_addi_w| inst_ori   |
                   inst_ld_w  | inst_lu12i_w |
                   inst_pcaddu12i | inst_slt | inst_or | inst_xor | inst_andi | inst_xori |
                   inst_sll_w | inst_srl_w | inst_sra_w | inst_srli_w | inst_ld_b | inst_ld_bu | inst_bl | inst_jirl | inst_cpucfg |
                   inst_sltu | inst_nor | inst_srai_w | inst_csr;

    assign use_imm = inst_slli_w | inst_srli_w | inst_srai_w | inst_slti | inst_sltui | inst_addi_w |
                     inst_ori | inst_andi | inst_xori | inst_ld_w | inst_ld_b | inst_ld_bu |
                     inst_st_w | inst_st_b | inst_lu12i_w | inst_pcaddu12i | inst_cpucfg | 
                     inst_jirl | inst_cacop;

    assign alu_op[0]  = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w | inst_ld_b | inst_ld_bu | inst_st_b | inst_pcaddu12i | inst_cacop;
    assign alu_op[1]  = inst_sub_w;
    assign alu_op[2]  = inst_slti | inst_slt;
    assign alu_op[3]  = inst_sltu | inst_sltui;
    assign alu_op[4]  = inst_and | inst_andi;
    assign alu_op[5]  = inst_nor;
    assign alu_op[6]  = inst_ori | inst_or;
    assign alu_op[7]  = inst_xor | inst_xori;
    assign alu_op[8]  = inst_slli_w | inst_sll_w;
    assign alu_op[9]  = inst_srli_w | inst_srl_w;
    assign alu_op[10] = inst_srai_w | inst_sra_w;
    assign alu_op[11] = inst_lu12i_w | inst_cpucfg;

    assign mem_en = inst_ld_w | inst_st_w | inst_ld_b | inst_ld_bu | inst_st_b;
    
    assign wb_sel = (inst_ld_w | inst_ld_b | inst_ld_bu)  ? 2'b01 : 
                    (inst_mul_w)             ? 2'b10 : 
                    (inst_bl | inst_jirl)    ? 2'b11 : 
                                               2'b00 ; 
    
    assign is_bl = inst_bl;
    assign is_jirl = inst_jirl;
    assign is_pcaddu12i = inst_pcaddu12i;
    assign is_ld_b = inst_ld_b;
    assign is_st_b = inst_st_b;
    assign is_st_w = inst_st_w;
    assign is_ld_bu = inst_ld_bu;

endmodule
