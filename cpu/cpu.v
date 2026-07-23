module cpu(
    input           clk, resetn,
    
    // ==========================================
    // Inst SRAM (类SRAM握手接口)
    // ==========================================
    output          inst_sram_req,
    output          inst_sram_wr,
    output [ 1:0]   inst_sram_size,
    output [31:0]   inst_sram_addr,
    output [ 3:0]   inst_sram_wstrb,
    output [31:0]   inst_sram_wdata,
    input           inst_sram_addr_ok,
    input           inst_sram_data_ok,
    input  [31:0]   inst_sram_rdata,
    
    // ==========================================
    // Data SRAM (类SRAM握手接口)
    // ==========================================
    output          data_sram_req,
    output          data_sram_wr,
    output [ 1:0]   data_sram_size,
    output [31:0]   data_sram_addr,
    output [ 3:0]   data_sram_wstrb,
    output [31:0]   data_sram_wdata,
    input           data_sram_addr_ok,
    input           data_sram_data_ok,
    input  [31:0]   data_sram_rdata,
    
    // ==========================================
    // Debug 接口
    // ==========================================
    output [31:0]   debug_wb_pc,
    output          debug_wb_rf_wen,
    output [ 4:0]   debug_wb_rf_wnum,
    output [31:0]   debug_wb_rf_wdata
);
    wire [4:0] stall;
    wire [4:0] flush;

    // ==========================================
    // 取指类SRAM握手转接与缓存逻辑
    // ==========================================
    wire        internal_inst_en;
    wire [31:0] internal_inst_addr;
    wire        inst_sram_wait;

    reg inst_addr_rcv;
    always @(posedge clk) begin
        if (~resetn || flush[1]) begin
            inst_addr_rcv <= 1'b0;
        end else if ((inst_sram_req && inst_sram_addr_ok) && !inst_sram_data_ok) begin
            inst_addr_rcv <= 1'b1;
        end else if (inst_sram_data_ok) begin
            inst_addr_rcv <= 1'b0;
        end
    end

    reg         inst_buf_valid;
    reg  [31:0] inst_buf_data;
    reg  [31:0] inst_buf_pc;
    reg         inst_buf_pred_taken;
    reg  [31:0] inst_buf_pred_target;
    reg  [7:0]  inst_buf_pred_ghr;

    assign inst_sram_req   = internal_inst_en & ~inst_addr_rcv & ~inst_buf_valid;
    assign inst_sram_wr    = 1'b0;       
    assign inst_sram_size  = 2'b10;      
    assign inst_sram_wstrb = 4'b0000;
    assign inst_sram_addr  = internal_inst_addr;
    assign inst_sram_wdata = 32'd0;

    assign inst_sram_wait  = internal_inst_en & ~inst_sram_data_ok & ~inst_buf_valid;

    // ==========================================
    // 访存类SRAM握手转接逻辑
    // ==========================================
    wire        internal_data_en;
    wire [ 3:0] internal_data_wen;
    wire [31:0] internal_data_addr;
    wire [31:0] internal_data_wdata;
    wire        mem_wait;

    reg data_addr_rcv;
    always @(posedge clk) begin
        if (~resetn) begin
            data_addr_rcv <= 1'b0;
        end else if ((data_sram_req && data_sram_addr_ok) && !data_sram_data_ok) begin
            data_addr_rcv <= 1'b1;
        end else if (data_sram_data_ok) begin
            data_addr_rcv <= 1'b0;
        end
    end

    wire is_data_write = (internal_data_wen != 4'b0000);

    assign data_sram_req   = internal_data_en & ~data_addr_rcv;
    assign data_sram_wr    = is_data_write;
    assign data_sram_size  = (internal_data_wen == 4'b0001 || internal_data_wen == 4'b0010 || 
                              internal_data_wen == 4'b0100 || internal_data_wen == 4'b1000) ? 2'b00 : 
                             (internal_data_wen == 4'b0011 || internal_data_wen == 4'b1100) ? 2'b01 : 
                             2'b10; 

    assign data_sram_wstrb = is_data_write ? internal_data_wen : 4'b0000;
    assign data_sram_addr  = internal_data_addr;
    assign data_sram_wdata = internal_data_wdata;

    assign mem_wait = internal_data_en & ~data_sram_data_ok;

    // ==========================================
    // 分支预测单元
    // ==========================================
    wire        if_pred_taken, id_pred_taken;
    wire [31:0] if_pred_target, id_pred_target;
    wire [7:0]  if_pred_ghr, id_pred_ghr;
    wire        upd_bpu_en, upd_bpu_taken;
    wire [ 1:0] upd_bpu_br_type;
    wire [7:0]  upd_bpu_ghr;
    wire [31:0] upd_bpu_pc, upd_bpu_target;
    wire [31:0] stat_btb_hits, stat_cond_preds, stat_pred_correct, stat_pred_wrong;
    wire [31:0] stat_loop_overrides, stat_ret_preds, stat_ret_correct, stat_ret_wrong, stat_ras_fallbacks, stat_ras_valid_preds;
    wire [31:0] stat_loop_hits, stat_loop_confident, stat_loop_correct, stat_loop_wrong, stat_loop_override_taken, stat_loop_override_wrong;

    // ==========================================
    // IF 阶段
    // ==========================================
    wire [31:0] if_pc, id_br_target;
    wire        id_br_taken, if_req_fire;

    bpu _bpu (
        .clk(clk), .resetn(resetn),
        .pc(if_pc), .pred_taken(if_pred_taken), .pred_target(if_pred_target), .pred_ghr(if_pred_ghr),
        .upd_en(upd_bpu_en), .upd_pc(upd_bpu_pc), .upd_ghr(upd_bpu_ghr),
        .upd_br_type(upd_bpu_br_type),
        .upd_actually_taken(upd_bpu_taken), .upd_target(upd_bpu_target),
        .stat_btb_hits(stat_btb_hits), .stat_cond_preds(stat_cond_preds), .stat_pred_correct(stat_pred_correct), .stat_pred_wrong(stat_pred_wrong),
        .stat_loop_overrides(stat_loop_overrides), .stat_ret_preds(stat_ret_preds), .stat_ret_correct(stat_ret_correct), .stat_ret_wrong(stat_ret_wrong), .stat_ras_fallbacks(stat_ras_fallbacks), .stat_ras_valid_preds(stat_ras_valid_preds),
        .stat_loop_hits(stat_loop_hits), .stat_loop_confident(stat_loop_confident), .stat_loop_correct(stat_loop_correct), .stat_loop_wrong(stat_loop_wrong),
        .stat_loop_override_taken(stat_loop_override_taken), .stat_loop_override_wrong(stat_loop_override_wrong)
    );

    stage_if _stage_if (
        .clk(clk), .resetn(resetn), .stall_if(stall[0]),
        .id_pred_wrong(id_br_taken), .id_correct_pc(id_br_target),
        .if_pred_taken(if_pred_taken), .if_pred_target(if_pred_target),
        .inst_sram_en(internal_inst_en),       
        .inst_sram_addr(internal_inst_addr),   
        .if_pc(if_pc), .if_req_fire(if_req_fire)
    );

    always @(posedge clk) begin
        if (~resetn || flush[1]) begin
            inst_buf_valid <= 1'b0;
        end else begin
            if (inst_sram_data_ok && stall[1]) begin
                inst_buf_valid       <= 1'b1;
                inst_buf_data        <= inst_sram_rdata;
                inst_buf_pc          <= if_pc;           // <--- 直接保存当前完全正确的 if_pc
                inst_buf_pred_taken  <= if_pred_taken;
                inst_buf_pred_target <= if_pred_target;
                inst_buf_pred_ghr    <= if_pred_ghr;
            end else if (!stall[1]) begin
                inst_buf_valid <= 1'b0;
            end
        end
    end

    wire [31:0] id_pc, id_inst;
    wire        id_valid;
    
    // 流入 ID 级的数据，优先看缓存，其次直接使用总线数据和当前的 if_pc
    wire        if_id_valid_in       = inst_buf_valid ? 1'b1                 : inst_sram_data_ok;
    wire [31:0] if_id_pc_in          = inst_buf_valid ? inst_buf_pc          : if_pc;          // <--- 解决错位的杀手锏
    wire [31:0] if_id_inst_in        = inst_buf_valid ? inst_buf_data        : inst_sram_rdata;
    wire        if_id_pred_taken_in  = inst_buf_valid ? inst_buf_pred_taken  : if_pred_taken;
    wire [31:0] if_id_pred_target_in = inst_buf_valid ? inst_buf_pred_target : if_pred_target;
    wire [7:0]  if_id_pred_ghr_in    = inst_buf_valid ? inst_buf_pred_ghr    : if_pred_ghr;

    if_id_reg _if_id_reg (
        .clk(clk), .resetn(resetn), .stall(stall[1]), .flush(flush[1]), .if_valid(if_id_valid_in),
        .if_pc(if_id_pc_in), .if_inst(if_id_inst_in), .if_pred_taken(if_id_pred_taken_in), .if_pred_target(if_id_pred_target_in), .if_pred_ghr(if_id_pred_ghr_in),
        .id_pc(id_pc), .id_inst(id_inst), .id_valid(id_valid),
        .id_pred_taken(id_pred_taken), .id_pred_target(id_pred_target), .id_pred_ghr(id_pred_ghr)
    );

    wire [31:0] safe_id_inst = id_valid ? id_inst : 32'h03400000;

    // ==========================================
    // ID 阶段
    // ==========================================
    wire        wb_rf_we, ex_rf_we, mem_rf_we;
    wire [ 4:0] wb_waddr, ex_waddr, mem_waddr;
    wire [31:0] wb_data, ex_result, mem_final_data;

    wire        id_rf_we, id_mem_en, id_is_st_w, id_is_st_b, id_is_ld_b, id_is_ld_bu, id_is_branch;
    wire [ 1:0] id_wb_sel;
    wire [ 4:0] id_waddr, id_rs1, id_rs2;
    wire [11:0] id_alu_op;
    wire [31:0] id_alu_src1, id_alu_src2, id_rdata2;

    stage_id _stage_id (
        .clk(clk), .resetn(resetn), .stall_id(stall[1]),
        .id_pc(id_pc), .id_inst(safe_id_inst),
        .wb_rf_we(wb_rf_we), .wb_waddr(wb_waddr), .wb_data(wb_data),
        .ex_rf_we(ex_rf_we), .ex_waddr(ex_waddr), .ex_result(ex_result),
        .mem_rf_we(mem_rf_we), .mem_waddr(mem_waddr), .mem_final_data(mem_final_data),
        .id_rf_we(id_rf_we), .id_waddr(id_waddr), .id_wb_sel(id_wb_sel),
        .id_mem_en(id_mem_en), .id_is_st_w(id_is_st_w), .id_is_st_b(id_is_st_b), .id_is_ld_b(id_is_ld_b),
        .id_is_ld_bu(id_is_ld_bu),
        .id_alu_op(id_alu_op), .id_alu_src1(id_alu_src1), .id_alu_src2(id_alu_src2), .id_rdata2(id_rdata2),
        .id_br_taken(id_br_taken), .id_br_target(id_br_target), .id_is_branch(id_is_branch),
        .id_rs1(id_rs1), .id_rs2(id_rs2),
        .id_pred_taken(id_pred_taken), .id_pred_target(id_pred_target), .id_pred_ghr(id_pred_ghr),
        .upd_bpu_en(upd_bpu_en), .upd_bpu_pc(upd_bpu_pc), .upd_bpu_ghr(upd_bpu_ghr),
        .upd_bpu_br_type_out(upd_bpu_br_type), .upd_bpu_taken(upd_bpu_taken), .upd_bpu_target(upd_bpu_target)
    );

    wire [31:0] ex_pc, ex_alu_src1, ex_alu_src2, ex_rdata2;
    wire [ 1:0] ex_wb_sel;
    wire        ex_mem_en, ex_is_st_w, ex_is_st_b, ex_is_ld_b, ex_is_ld_bu; 
    wire [11:0] ex_alu_op;

    id_ex_reg _id_ex_reg (
        .clk(clk), .resetn(resetn), .stall(stall[1]), .flush(flush[2]),
        .id_pc(id_pc), .id_rf_we(id_rf_we), .id_waddr(id_waddr), .id_wb_sel(id_wb_sel),
        .id_mem_en(id_mem_en), .id_is_st_w(id_is_st_w), .id_is_st_b(id_is_st_b), .id_is_ld_b(id_is_ld_b),
        .id_is_ld_bu(id_is_ld_bu),
        .id_alu_op(id_alu_op), .id_alu_src1(id_alu_src1), .id_alu_src2(id_alu_src2), .id_rdata2(id_rdata2),
        .ex_pc(ex_pc), .ex_rf_we(ex_rf_we), .ex_waddr(ex_waddr), .ex_wb_sel(ex_wb_sel),
        .ex_mem_en(ex_mem_en), .ex_is_st_w(ex_is_st_w), .ex_is_st_b(ex_is_st_b), .ex_is_ld_b(ex_is_ld_b),
        .ex_is_ld_bu(ex_is_ld_bu), 
        .ex_alu_op(ex_alu_op), .ex_alu_src1(ex_alu_src1), .ex_alu_src2(ex_alu_src2), .ex_rdata2(ex_rdata2)
    );

    // ==========================================
    // EX 阶段
    // ==========================================
    wire [ 1:0] ex_addr_align;
    wire        ex_mem_read;

    stage_ex _stage_ex (
        .ex_pc(ex_pc), .ex_wb_sel(ex_wb_sel), .ex_mem_en(ex_mem_en),
        .ex_is_st_w(ex_is_st_w), .ex_is_st_b(ex_is_st_b), .ex_alu_op(ex_alu_op),
        .ex_alu_src1(ex_alu_src1), .ex_alu_src2(ex_alu_src2), .ex_rdata2(ex_rdata2),
        .ex_result(ex_result), .ex_addr_align(ex_addr_align),
        .data_sram_en(internal_data_en),       
        .data_sram_wen(internal_data_wen),     
        .data_sram_addr(internal_data_addr),   
        .data_sram_wdata(internal_data_wdata), 
        .ex_mem_read(ex_mem_read)
    );

    wire [31:0] mem_pc, mem_result;
    wire [ 1:0] mem_wb_sel, mem_addr_align;
    wire        mem_is_ld_b, mem_is_ld_bu, mem_valid;

    ex_mem_reg _ex_mem_reg (
        .clk(clk), .resetn(resetn), .stall(stall[2]), .flush(flush[3]),
        .ex_pc(ex_pc), .ex_rf_we(ex_rf_we), .ex_waddr(ex_waddr), .ex_wb_sel(ex_wb_sel),
        .ex_is_ld_b(ex_is_ld_b), .ex_is_ld_bu(ex_is_ld_bu), 
        .ex_addr_align(ex_addr_align), .ex_result(ex_result),
        .mem_pc(mem_pc), .mem_rf_we(mem_rf_we), .mem_waddr(mem_waddr), .mem_wb_sel(mem_wb_sel),
        .mem_is_ld_b(mem_is_ld_b), .mem_is_ld_bu(mem_is_ld_bu), 
        .mem_addr_align(mem_addr_align), .mem_result(mem_result), .mem_valid(mem_valid)
    );

    // ==========================================
    // MEM 阶段
    // ==========================================
    wire mem_done;

    stage_mem _stage_mem (
        .mem_wb_sel(mem_wb_sel), .mem_is_ld_b(mem_is_ld_b), 
        .mem_is_ld_bu(mem_is_ld_bu), 
        .mem_addr_align(mem_addr_align), .mem_result(mem_result), .mem_valid(mem_valid),
        .data_sram_rdata(data_sram_rdata),              
        .data_sram_resp_valid(data_sram_data_ok),       
        .mem_final_data(mem_final_data), .mem_done(mem_done), .mem_wait() 
    );

    wire [31:0] wb_pc;
    mem_wb_reg _mem_wb_reg (
        .clk(clk), .resetn(resetn), .stall(stall[3]), .flush(flush[4]),
        .mem_pc(mem_pc), .mem_rf_we(mem_rf_we), .mem_waddr(mem_waddr), .mem_final_data(mem_final_data), .mem_done(mem_done),
        .wb_pc(wb_pc), .wb_rf_we(wb_rf_we), .wb_waddr(wb_waddr), .wb_data(wb_data)
    );

    // ==========================================
    // WB 阶段
    // ==========================================
    stage_wb _stage_wb (
        .wb_pc(wb_pc), .wb_rf_we(wb_rf_we), .wb_waddr(wb_waddr), .wb_data(wb_data),
        .debug_wb_pc(debug_wb_pc), .debug_wb_rf_wen(debug_wb_rf_wen),
        .debug_wb_rf_wnum(debug_wb_rf_wnum), .debug_wb_rf_wdata(debug_wb_rf_wdata)
    );

    // ==========================================
    // Hazard
    // ==========================================
    hazard_ctrl _hazard_ctrl (
        .id_is_branch(id_is_branch), .id_rs1(id_rs1), .id_rs2(id_rs2),
        .ex_waddr(ex_waddr), .ex_mem_read(ex_mem_read),
        .id_br_taken(id_br_taken),
        .if_wait(inst_sram_wait),  
        .mem_wait(mem_wait),       
        .stall(stall), .flush(flush)
    );

endmodule