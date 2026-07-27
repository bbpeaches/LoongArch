module stage_ex (
    input  wire        clk,
    input  wire        resetn,
    input  wire        stall_ex,

    input  wire [31:0] ex_pc,
    input  wire [ 1:0] ex_wb_sel,
    input  wire        ex_mem_en,
    input  wire        ex_is_st_w,
    input  wire        ex_is_st_b,
    input  wire [11:0] ex_alu_op,
    input  wire [31:0] ex_alu_src1,
    input  wire [31:0] ex_alu_src2,
    input  wire [31:0] ex_rdata2,

    input  wire [31:0] ex_imm,
    input  wire [11:0] ex_br_info,
    input  wire        ex_is_branch,
    input  wire        ex_pred_taken,
    input  wire [31:0] ex_pred_target,
    input  wire [ 7:0] ex_pred_ghr,
    input  wire        ex_valid_inst,
    input  wire [31:0] ex_normal_br_target, 

    output wire [31:0] ex_result,
    output wire [31:0] ex_mul_result,
    output wire [ 1:0] ex_addr_align,

    output wire        data_sram_en,
    output wire [ 3:0] data_sram_wen,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    output wire        ex_mem_read,

    output wire        ex_br_taken,
    output wire [31:0] ex_br_target,
    output wire        upd_bpu_en,
    output wire [31:0] upd_bpu_pc,
    output wire [ 7:0] upd_bpu_ghr,
    output wire [ 1:0] upd_bpu_br_type_out,
    output wire        upd_bpu_taken,
    output wire [31:0] upd_bpu_target
);
    wire [31:0] ex_alu_result;

    alu_top _alu_top (
        .alu_op(ex_alu_op), .alu_src1(ex_alu_src1), .alu_src2(ex_alu_src2), .alu_result(ex_alu_result)
    );

    mul_top _mul_top (
        .clk(clk), 
        .ce(1'b1),
        .resetn(resetn), 
        .x(ex_alu_src1), 
        .y(ex_alu_src2), 
        .result(ex_mul_result)
    );

    wire inst_b = ex_br_info[11];
    wire inst_beq = ex_br_info[10];
    wire inst_bne = ex_br_info[9];
    wire inst_blt = ex_br_info[8];
    wire inst_bge = ex_br_info[7];
    wire inst_bltu= ex_br_info[6];
    wire inst_bgeu= ex_br_info[5];
    wire is_bl    = ex_br_info[4];
    wire is_jirl  = ex_br_info[3];
    wire is_call  = ex_br_info[2];
    wire is_ret   = ex_br_info[1];
    wire inst_cond_branch = ex_br_info[0];

    wire ex_rj_eq_rd, ex_rj_lt_rd_signed, ex_rj_lt_rd_unsigned;
    branch_cmp _branch_cmp (
        .val1  (ex_alu_src1), 
        .val2  (ex_rdata2), 
        .is_eq (ex_rj_eq_rd),
        .is_lt (ex_rj_lt_rd_signed),
        .is_ltu(ex_rj_lt_rd_unsigned)
    );

    wire [31:0] jirl_br_target   = ex_alu_src1 + ex_imm;
    wire [31:0] actual_target    = is_jirl ? jirl_br_target : ex_normal_br_target; 

    wire jirl_target_wrong   = (jirl_br_target != ex_pred_target);
    wire normal_target_wrong = (ex_normal_br_target != ex_pred_target);
    wire target_wrong        = is_jirl ? jirl_target_wrong : normal_target_wrong; 

    wire actual_taken = (inst_b | is_bl | is_jirl |
                         (inst_beq  & ex_rj_eq_rd) |
                         (inst_bne  & ~ex_rj_eq_rd) |
                         (inst_blt  & ex_rj_lt_rd_signed) |
                         (inst_bge  & ~ex_rj_lt_rd_signed) |
                         (inst_bltu & ex_rj_lt_rd_unsigned) |
                         (inst_bgeu & ~ex_rj_lt_rd_unsigned));

    wire pred_wrong = (ex_pred_taken != actual_taken) || (actual_taken && target_wrong);

    (* max_fanout = 32 *) wire ex_br_taken_opt = pred_wrong && ex_valid_inst && !stall_ex;

    assign ex_br_taken  = ex_br_taken_opt;
    assign ex_br_target = actual_taken ? actual_target : (ex_pc + 32'd4);

    assign upd_bpu_en          = (ex_is_branch || ex_pred_taken) && ex_valid_inst && !stall_ex;
    assign upd_bpu_pc          = ex_pc;
    assign upd_bpu_ghr         = ex_pred_ghr;
    assign upd_bpu_br_type_out = is_call ? 2'b10 :
                                 is_ret  ? 2'b11 :
                                 inst_cond_branch ? 2'b00 : 2'b01;
    assign upd_bpu_taken       = actual_taken;
    assign upd_bpu_target      = actual_target;

    assign ex_result = (ex_wb_sel == 2'b11) ? (ex_pc + 32'd4) : ex_alu_result;
    assign ex_addr_align = ex_alu_result[1:0];
    wire [3:0] ex_st_b_we = 4'b0001 << ex_addr_align;

    assign data_sram_en    = ex_mem_en;
    assign data_sram_wen   = ex_is_st_w ? 4'b1111 :
                             ex_is_st_b ? ex_st_b_we : 4'b0000;
    assign data_sram_addr  = ex_alu_result;
    assign data_sram_wdata = ex_is_st_b ? {4{ex_rdata2[7:0]}} : ex_rdata2;

    assign ex_mem_read = ex_mem_en && !(ex_is_st_w | ex_is_st_b);

endmodule