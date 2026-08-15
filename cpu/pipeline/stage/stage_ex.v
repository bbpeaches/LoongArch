module stage_ex (
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
    input  wire        ex_is_cpucfg,
    input  wire [ 1:0] ex_csr_op,
    input  wire [13:0] ex_csr_num,
    input  wire [31:0] csr_rdata,
    input  wire        ex_is_cacop,
    input  wire [ 4:0] ex_cacop_code,
    input  wire [ 4:0] ex_rs2,
    input  wire        mem_is_load,
    input  wire [ 4:0] mem_waddr,
    input  wire [31:0] mem_final_data,

    input  wire [11:0] ex_br_info,
    input  wire        ex_is_branch,
    input  wire        ex_pred_taken,
    input  wire [31:0] ex_pred_target,
    input  wire [ 7:0] ex_pred_ghr,
    input  wire        ex_valid_inst,
    input  wire [31:0] ex_normal_br_target, 

    output wire [31:0] ex_result,
    output wire [ 1:0] ex_addr_align,

    output wire        data_sram_en,
    output wire [ 3:0] data_sram_wen,
    output wire [28:0] data_sram_addr_lo,
    output wire        data_sram_addr_carry29,
    output wire [ 2:0] data_sram_addr_vseg_c0,
    output wire [ 2:0] data_sram_addr_vseg_c1,
    output wire [31:0] data_sram_wdata,
    output wire        ex_mem_read,

    output wire        csr_we,
    output wire [13:0] csr_waddr,
    output wire [31:0] csr_wdata,
    output wire [31:0] csr_wmask,
    output wire        ex_cacop_valid,
    output wire [ 4:0] ex_cacop_code_out,
    output wire [31:0] ex_cacop_addr,

    output wire        ex_br_taken,
    output wire [31:0] ex_br_target,
    output wire        upd_bpu_en,
    output wire [31:0] upd_bpu_pc,
    output wire [ 7:0] upd_bpu_ghr,
    output wire [ 1:0] upd_bpu_br_type_out,
    output wire        upd_bpu_pred_taken,
    output wire        upd_bpu_taken,
    output wire [31:0] upd_bpu_target
);
    wire [31:0] ex_alu_result;

    alu_top _alu_top (
        .alu_op(ex_alu_op), .alu_src1(ex_alu_src1), .alu_src2(ex_alu_src2), .alu_result(ex_alu_result)
    );

    wire [31:0] ex_mem_addr;
    wire [28:0] ex_mem_addr_lo;
    wire        ex_mem_addr_carry29;
    wire [ 2:0] ex_mem_addr_vseg_c0;
    wire [ 2:0] ex_mem_addr_vseg_c1;
    agu _agu (
        .base  (ex_alu_src1),
        .offset(ex_alu_src2),
        .addr  (ex_mem_addr),
        .addr_lo(ex_mem_addr_lo),
        .addr_carry29(ex_mem_addr_carry29),
        .addr_vseg_c0(ex_mem_addr_vseg_c0),
        .addr_vseg_c1(ex_mem_addr_vseg_c1)
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

    wire [31:0] jirl_br_target   = ex_mem_addr;
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
    assign upd_bpu_pred_taken  = ex_pred_taken;
    assign upd_bpu_target      = actual_target;

    function [31:0] cpucfg_value;
        input [31:0] index;
        begin
            case (index)
                // This core has a 2-way, 128-set, 32-byte-line L1 I-cache.
                32'h0000_0010: cpucfg_value = 32'h0000_0001;
                32'h0000_0011: cpucfg_value = 32'h0507_0001;
                // There is deliberately no D-cache in this configuration.
                32'h0000_0012: cpucfg_value = 32'h0000_0000;
                default:       cpucfg_value = 32'h0000_0000;
            endcase
        end
    endfunction

    assign csr_we    = ex_valid_inst && !stall_ex && (ex_csr_op == 2'd2 || ex_csr_op == 2'd3);
    assign csr_waddr = ex_csr_num;
    assign csr_wdata = ex_rdata2;
    assign csr_wmask = (ex_csr_op == 2'd2) ? 32'hffff_ffff : ex_alu_src1;

    assign ex_cacop_valid = ex_valid_inst && ex_is_cacop && !stall_ex;
    assign ex_cacop_code_out = ex_cacop_code;
    assign ex_cacop_addr = ex_mem_addr;

    assign ex_result = ex_is_cpucfg ? cpucfg_value(ex_alu_src1) :
                       (ex_csr_op != 2'd0) ? csr_rdata :
                       (ex_wb_sel == 2'b11) ? (ex_pc + 32'd4) : ex_alu_result;
    
    assign ex_addr_align = ex_mem_addr[1:0];
    wire [3:0] ex_st_b_we = 4'b0001 << ex_addr_align;

    wire forward_store_data = mem_is_load && (mem_waddr == ex_rs2) && (mem_waddr != 5'd0);
    wire [31:0] actual_store_data = forward_store_data ? mem_final_data : ex_rdata2;

    assign data_sram_en    = ex_mem_en;
    assign data_sram_wen   = ex_is_st_w ? 4'b1111 :
                             ex_is_st_b ? ex_st_b_we : 4'b0000;

    assign data_sram_addr_lo = ex_mem_addr_lo;
    assign data_sram_addr_carry29 = ex_mem_addr_carry29;
    assign data_sram_addr_vseg_c0 = ex_mem_addr_vseg_c0;
    assign data_sram_addr_vseg_c1 = ex_mem_addr_vseg_c1;
    assign data_sram_wdata = ex_is_st_b ? {4{actual_store_data[7:0]}} : actual_store_data;

    assign ex_mem_read = ex_mem_en && !(ex_is_st_w | ex_is_st_b);

endmodule
