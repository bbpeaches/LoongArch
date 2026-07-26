module stage_id (
    input  wire        clk,
    input  wire        resetn,
    input  wire        stall_id,
    input  wire        ex_fw_valid,

    input  wire [31:0] id_pc,
    input  wire [31:0] id_inst,

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
    output wire [11:0] id_alu_op,
    output wire [31:0] id_alu_src1,
    output wire [31:0] id_alu_src2,
    output wire [31:0] id_rdata2,

    output wire        id_br_taken,
    output wire [31:0] id_br_target,
    output wire        id_is_branch,
    output wire [ 4:0] id_rs1,
    output wire [ 4:0] id_rs2,

    // --- 接收 IF 级的预测信息 ---
    input  wire        id_pred_taken,
    input  wire [31:0] id_pred_target,
    input  wire [ 7:0] id_pred_ghr,

    // --- 向 BPU 输出模型训练(更新)信号 ---
    output wire        upd_bpu_en,
    output wire [31:0] upd_bpu_pc,
    output wire [ 7:0] upd_bpu_ghr,
    output wire [ 1:0] upd_bpu_br_type_out,
    output wire        upd_bpu_taken,
    output wire [31:0] upd_bpu_target
);
    wire        id_rf_we_raw;
    wire [ 4:0] id_waddr_raw;
    wire [ 1:0] id_wb_sel_raw;
    wire        id_mem_en_raw;
    wire        id_is_st_w_raw, id_is_st_b_raw, id_is_ld_b_raw, id_is_ld_bu_raw;
    wire [11:0] id_alu_op_raw;
    wire [31:0] id_imm;
    wire        id_use_imm, id_invalid;
    wire        inst_b, inst_beq, inst_bne, inst_blt, inst_bge, inst_bltu, inst_bgeu, is_bl, is_jirl, is_pcaddu12i;
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
        .is_ld_bu(id_is_ld_bu_raw)
    );
    
    assign id_rs1 = dec_rs1;
    assign id_rs2 = dec_rs2;

    assign id_rf_we = resetn && !id_invalid && id_rf_we_raw && (id_waddr_raw != 5'd0);
    assign id_waddr = id_invalid ? 5'd0 : id_waddr_raw;
    assign id_wb_sel = id_invalid ? 2'd0 : id_wb_sel_raw;
    assign id_mem_en = !id_invalid && id_mem_en_raw;
    assign id_is_st_w = !id_invalid && id_is_st_w_raw;
    assign id_is_st_b = !id_invalid && id_is_st_b_raw;
    assign id_is_ld_b = !id_invalid && id_is_ld_b_raw;
    assign id_is_ld_bu= !id_invalid && id_is_ld_bu_raw;
    assign id_alu_op  = id_invalid ? 12'd0 : id_alu_op_raw;

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

    wire id_rj_eq_rd, id_rj_lt_rd_signed, id_rj_lt_rd_unsigned;
    
    branch_cmp _branch_cmp (
        .val1  (id_fwd_rdata1), 
        .val2  (id_fwd_rdata2), 
        .is_eq (id_rj_eq_rd),
        .is_lt (id_rj_lt_rd_signed),
        .is_ltu(id_rj_lt_rd_unsigned)
    );

    wire inst_cond_branch = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;
    
    // 剥离 invalid 检查，让判断逻辑高速并行
    assign id_is_branch = (inst_b | is_bl | is_jirl | inst_cond_branch);

    // 并行计算跳转目标：不需要等寄存器读出的普通跳转，直接并线算 pc+imm
    wire [31:0] normal_br_target = id_pc + id_imm;
    wire [31:0] jirl_br_target   = id_fwd_rdata1 + id_imm;
    wire [31:0] actual_target    = is_jirl ? jirl_br_target : normal_br_target;

    // 分支比对全速执行，不需要等待 !id_invalid
    wire actual_taken = (inst_b | is_bl | is_jirl |
                         (inst_beq  & id_rj_eq_rd) |
                         (inst_bne  & ~id_rj_eq_rd) |
                         (inst_blt  & id_rj_lt_rd_signed) |
                         (inst_bge  & ~id_rj_lt_rd_signed) |
                         (inst_bltu & id_rj_lt_rd_unsigned) |
                         (inst_bgeu & ~id_rj_lt_rd_unsigned));

    wire pred_wrong = (id_pred_taken && !actual_taken) || 
                      (actual_taken && !id_pred_taken) || 
                      (actual_taken && (actual_target != id_pred_target));

    assign id_br_taken  = pred_wrong && !id_invalid;
    assign id_br_target = actual_taken ? actual_target : (id_pc + 32'd4);

    wire is_call = is_bl | (is_jirl & (id_waddr_raw == 5'd1));
    wire is_ret  = is_jirl & (dec_rs1 == 5'd1) & (id_waddr_raw == 5'd0);

    assign upd_bpu_en          = (id_is_branch || id_pred_taken) && !stall_id && !id_invalid;
    assign upd_bpu_pc          = id_pc;
    assign upd_bpu_ghr         = id_pred_ghr;
    assign upd_bpu_br_type_out = is_call ? 2'b10 :
                                 is_ret  ? 2'b11 :
                                 inst_cond_branch ? 2'b00 : 2'b01;
    assign upd_bpu_taken       = actual_taken;
    assign upd_bpu_target      = actual_target;

    assign id_alu_src1 = id_invalid ? 32'd0 : (is_pcaddu12i ? id_pc : id_fwd_rdata1);
    assign id_alu_src2 = id_invalid ? 32'd0 : (id_use_imm ? id_imm : id_fwd_rdata2);
    assign id_rdata2   = id_invalid ? 32'd0 : id_fwd_rdata2;

endmodule