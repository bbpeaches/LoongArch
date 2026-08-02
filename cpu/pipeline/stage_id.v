module stage_id (
    input  wire        clk,
    input  wire        resetn,
    input  wire        ex_fw_valid,

    input  wire [31:0] id_pc,
    input  wire [31:0] id_inst,
    input  wire        id_valid,

    input  wire        wb_rf_we,
    input  wire [ 4:0] wb_waddr,
    input  wire [31:0] wb_data,

    input  wire        ex_rf_we,
    input  wire [ 4:0] ex_waddr,
    input  wire [31:0] ex_result,
    input  wire        mem_rf_we,
    input  wire [ 4:0] mem_waddr,
    input  wire [31:0] mem_final_data,

    output wire        id_rf_we,
    output wire [ 4:0] id_waddr,
    output wire [ 1:0] id_wb_sel,
    output wire        id_mem_en,
    output wire        id_is_st_w,
    output wire        id_is_st_b,
    output wire        id_is_ld_b,
    output wire        id_is_ld_bu,
    output wire        id_is_cpucfg,
    output wire [ 1:0] id_csr_op,
    output wire [13:0] id_csr_num,
    output wire        id_is_cacop,
    output wire [ 4:0] id_cacop_code,
    output wire [11:0] id_alu_op,
    output wire [31:0] id_alu_src1,
    output wire [31:0] id_alu_src2,
    output wire [31:0] id_rdata2,
    output wire [ 4:0] id_rs1,
    output wire [ 4:0] id_rs2,

    output wire [31:0] id_imm,
    output wire [11:0] id_br_info,
    output wire        id_is_branch,
    output wire        id_valid_inst,
    output wire [31:0] id_normal_br_target 
);
    wire        id_rf_we_raw;
    wire [ 4:0] id_waddr_raw;
    wire [ 1:0] id_wb_sel_raw;
    wire        id_mem_en_raw;
    wire        id_is_st_w_raw, id_is_st_b_raw, id_is_ld_b_raw, id_is_ld_bu_raw;
    wire [11:0] id_alu_op_raw;
    wire        id_use_imm, id_invalid;
    wire        inst_b, inst_beq, inst_bne, inst_blt, inst_bge, inst_bltu, inst_bgeu, is_bl, is_jirl, is_pcaddu12i;
    wire        id_is_cpucfg_raw, id_is_cacop_raw;
    wire [ 1:0] id_csr_op_raw;
    wire [13:0] id_csr_num_raw;
    wire [ 4:0] id_cacop_code_raw;
    wire [ 4:0] dec_rs1, dec_rs2;

    decoder_top _decoder_top (
        .inst      (id_inst),
        .rf_raddr1 (dec_rs1), .rf_raddr2 (dec_rs2),
        .rf_we     (id_rf_we_raw), .rf_waddr (id_waddr_raw),
        .imm       (id_imm),      .use_imm   (id_use_imm),
        .alu_op    (id_alu_op_raw), .mem_en   (id_mem_en_raw),
        .invalid   (id_invalid),  .wb_sel    (id_wb_sel_raw),
        .inst_b    (inst_b),      .inst_beq  (inst_beq),   .inst_bne  (inst_bne),
        .inst_blt  (inst_blt),    .inst_bge  (inst_bge),   .inst_bltu (inst_bltu), .inst_bgeu(inst_bgeu),
        .is_bl(is_bl), .is_jirl(is_jirl), .is_pcaddu12i(is_pcaddu12i),
        .is_ld_b(id_is_ld_b_raw), .is_st_b(id_is_st_b_raw), .is_st_w(id_is_st_w_raw),
        .is_ld_bu(id_is_ld_bu_raw),
        .is_cpucfg(id_is_cpucfg_raw), .csr_op(id_csr_op_raw), .csr_num(id_csr_num_raw),
        .is_cacop(id_is_cacop_raw), .cacop_code(id_cacop_code_raw)
    );

    assign id_valid_inst = id_valid && !id_invalid;

    assign id_rs1 = id_valid ? dec_rs1 : 5'd0;
    assign id_rs2 = id_valid ? dec_rs2 : 5'd0;

    assign id_rf_we   = resetn && id_valid_inst && id_rf_we_raw && (id_waddr_raw != 5'd0);
    assign id_waddr   = id_valid_inst ? id_waddr_raw : 5'd0;
    assign id_wb_sel  = id_valid_inst ? id_wb_sel_raw : 2'd0;
    assign id_mem_en  = id_valid_inst && id_mem_en_raw;
    assign id_is_st_w = id_valid_inst && id_is_st_w_raw;
    assign id_is_st_b = id_valid_inst && id_is_st_b_raw;
    assign id_is_ld_b = id_valid_inst && id_is_ld_b_raw;
    assign id_is_ld_bu= id_valid_inst && id_is_ld_bu_raw;
    assign id_is_cpucfg = id_valid_inst && id_is_cpucfg_raw;
    assign id_csr_op = id_valid_inst ? id_csr_op_raw : 2'd0;
    assign id_csr_num = id_valid_inst ? id_csr_num_raw : 14'd0;
    assign id_is_cacop = id_valid_inst && id_is_cacop_raw;
    assign id_cacop_code = id_valid_inst ? id_cacop_code_raw : 5'd0;
    assign id_alu_op  = id_valid_inst ? id_alu_op_raw : 12'd0;

    wire [31:0] rf_rdata1, rf_rdata2;
    regfile _regfile (
        .clk(clk),
        .raddr1(id_rs1), .rdata1(rf_rdata1),
        .raddr2(id_rs2), .rdata2(rf_rdata2),
        .we(wb_rf_we),   .waddr(wb_waddr), .wdata(wb_data)
    );

    wire [31:0] id_fwd_rdata1, id_fwd_rdata2;
    forward_ctrl _forward_ctrl (
        .id_rs1(id_rs1), .id_rs2(id_rs2),
        .ex_we(ex_rf_we && ex_fw_valid),   .ex_waddr(ex_waddr),   .ex_fw_data(ex_result),
        .mem_we(mem_rf_we), .mem_waddr(mem_waddr), .mem_fw_data(mem_final_data),
        .wb_we(wb_rf_we),   .wb_waddr(wb_waddr),   .wb_fw_data(wb_data),
        .rf_rdata1(rf_rdata1), .rf_rdata2(rf_rdata2),
        .id_fwd_rdata1(id_fwd_rdata1), .id_fwd_rdata2(id_fwd_rdata2)
    );

    wire inst_cond_branch = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;
    assign id_is_branch = (inst_b | is_bl | is_jirl | inst_cond_branch);

    wire is_call = is_bl | (is_jirl & (id_waddr_raw == 5'd1));
    wire is_ret  = is_jirl & (dec_rs1 == 5'd1) & (id_waddr_raw == 5'd0);
    
    assign id_br_info = {
        inst_b, inst_beq, inst_bne, inst_blt, inst_bge, inst_bltu, inst_bgeu,
        is_bl, is_jirl, is_call, is_ret, inst_cond_branch
    };

    assign id_alu_src1 = id_valid_inst ? (is_pcaddu12i ? id_pc : id_fwd_rdata1) : 32'd0;
    assign id_alu_src2 = id_valid_inst ? (id_use_imm ? id_imm : id_fwd_rdata2) : 32'd0;
    assign id_rdata2   = id_valid_inst ? id_fwd_rdata2 : 32'd0;
    
    assign id_normal_br_target = id_pc + id_imm;

endmodule
