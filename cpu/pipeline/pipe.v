module pipe(
    input  wire        clk,
    input  wire        resetn,
    
    output wire        inst_sram_req,
    output wire        inst_sram_wr,
    output wire [ 1:0] inst_sram_size,
    output wire [31:0] inst_sram_addr,
    output wire [ 3:0] inst_sram_wstrb,
    output wire [31:0] inst_sram_wdata,
    input  wire        inst_sram_addr_ok,
    input  wire        inst_sram_data_ok,
    input  wire [31:0] inst_sram_rdata,
    output wire        icache_cacop_valid,
    output wire [ 4:0] icache_cacop_code,
    output wire [31:0] icache_cacop_addr,
    input  wire        icache_cacop_busy,
    
    output wire        data_sram_req,
    output wire        data_sram_wr,
    output wire [ 1:0] data_sram_size,
    output wire [31:0] data_sram_addr,
    output wire [ 3:0] data_sram_wstrb,
    output wire [31:0] data_sram_wdata,
    input  wire        data_sram_addr_ok,
    input  wire        data_sram_data_ok,
    input  wire [31:0] data_sram_rdata,
    
    output wire [31:0] debug_wb_pc,
    output wire        debug_wb_rf_wen,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
    wire [4:0] stall;
    wire [4:0] flush;

    wire         internal_inst_en;
    wire [31:0] internal_inst_addr;
    wire         inst_sram_wait;
    wire         fetch_issue_valid;
    wire         fetch_pc_stall;
    wire         internal_data_en;
    wire [ 3:0]  internal_data_wen;
    wire [31:0]  internal_data_addr;
    wire [31:0]  internal_data_wdata;

    assign inst_sram_req   = internal_inst_en & fetch_issue_valid;
    assign inst_sram_wr    = 1'b0;       
    assign inst_sram_size  = 2'b10;      
    assign inst_sram_wstrb = 4'b0000;
    wire [31:0] csr_crmd, csr_dmw0, csr_dmw1;
    wire paged_mode = csr_crmd[4] && !csr_crmd[3];
    wire dmw0_plv_enable = ((csr_crmd[1:0] == 2'd0) && csr_dmw0[0]) ||
                           ((csr_crmd[1:0] == 2'd3) && csr_dmw0[3]);
    wire dmw1_plv_enable = ((csr_crmd[1:0] == 2'd0) && csr_dmw1[0]) ||
                           ((csr_crmd[1:0] == 2'd3) && csr_dmw1[3]);

    (* keep = "true" *) wire inst_dmw0_vseg_match = (internal_inst_addr[31:29] == csr_dmw0[31:29]);
    (* keep = "true" *) wire inst_dmw1_vseg_match = (internal_inst_addr[31:29] == csr_dmw1[31:29]);
    (* keep = "true" *) wire data_dmw0_vseg_match = (internal_data_addr[31:29] == csr_dmw0[31:29]);
    (* keep = "true" *) wire data_dmw1_vseg_match = (internal_data_addr[31:29] == csr_dmw1[31:29]);

    wire inst_dmw0_match = paged_mode && dmw0_plv_enable && inst_dmw0_vseg_match;
    wire inst_dmw1_match = paged_mode && dmw1_plv_enable && inst_dmw1_vseg_match;
    wire data_dmw0_match = paged_mode && dmw0_plv_enable && data_dmw0_vseg_match;
    wire data_dmw1_match = paged_mode && dmw1_plv_enable && data_dmw1_vseg_match;

    wire [2:0] internal_inst_pseg = inst_dmw0_match ? csr_dmw0[27:25] :
                                      inst_dmw1_match ? csr_dmw1[27:25] : internal_inst_addr[31:29];
    wire [2:0] internal_data_pseg = data_dmw0_match ? csr_dmw0[27:25] :
                                      data_dmw1_match ? csr_dmw1[27:25] : internal_data_addr[31:29];
    wire [31:0] internal_inst_paddr = {internal_inst_pseg, internal_inst_addr[28:0]};
    wire [31:0] internal_data_paddr = {internal_data_pseg, internal_data_addr[28:0]};

    assign inst_sram_addr  = internal_inst_paddr;
    assign inst_sram_wdata = 32'd0;

    assign inst_sram_wait  = fetch_pc_stall;

    wire         mem_wait;
    wire         data_mem_wait;
    wire         mul_mem_wait;
    wire         ex_is_st_w;
    wire         ex_is_st_b;
    wire         ex_is_ld_b;
    wire         ex_is_ld_bu;

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

    wire is_data_write = ex_is_st_w | ex_is_st_b;
    wire is_data_byte  = is_data_write
                       ? (internal_data_wen == 4'b0001 || internal_data_wen == 4'b0010 ||
                          internal_data_wen == 4'b0100 || internal_data_wen == 4'b1000)
                       : (ex_is_ld_b | ex_is_ld_bu);
    wire is_data_half  = is_data_write &&
                         (internal_data_wen == 4'b0011 || internal_data_wen == 4'b1100);

    assign data_sram_req   = internal_data_en & ~data_addr_rcv;
    assign data_sram_wr    = is_data_write;
    assign data_sram_size  = is_data_byte ? 2'b00 :
                             is_data_half ? 2'b01 :
                             2'b10;

    assign data_sram_wstrb = is_data_write ? internal_data_wen : 4'b0000;
    assign data_sram_addr  = internal_data_paddr;
    assign data_sram_wdata = internal_data_wdata;

    assign data_mem_wait = internal_data_en & ~data_sram_data_ok;
    assign mem_wait      = data_mem_wait | icache_cacop_busy;

    wire         if_pred_taken, id_pred_taken;
    wire [31:0] if_pred_target, id_pred_target;
    wire [7:0]  if_pred_ghr, id_pred_ghr;
    
    wire         upd_bpu_en, upd_bpu_taken, upd_bpu_pred_taken;
    wire [ 1:0] upd_bpu_br_type;
    wire [7:0]  upd_bpu_ghr;
    wire [31:0] upd_bpu_pc, upd_bpu_target;
    wire         ex_br_taken;
    wire [31:0] ex_br_target;

    wire [31:0] stat_btb_hits, stat_cond_preds, stat_pred_correct, stat_pred_wrong;
    wire [31:0] stat_loop_overrides, stat_ret_preds, stat_ret_correct, stat_ret_wrong, stat_ras_fallbacks, stat_ras_valid_preds;
    wire [31:0] stat_loop_hits, stat_loop_confident, stat_loop_correct, stat_loop_wrong, stat_loop_override_taken, stat_loop_override_wrong;

    reg        upd_bpu_en_r;
    reg [31:0] upd_bpu_pc_r;
    reg [ 7:0] upd_bpu_ghr_r;
    reg [ 1:0] upd_bpu_br_type_r;
    reg        upd_bpu_taken_r;
    reg        upd_bpu_pred_taken_r;
    reg [31:0] upd_bpu_target_r;

    always @(posedge clk) begin
        if (~resetn) begin
            upd_bpu_en_r      <= 1'b0;
            upd_bpu_pc_r      <= 32'd0;
            upd_bpu_ghr_r     <= 8'd0;
            upd_bpu_br_type_r <= 2'd0;
            upd_bpu_taken_r   <= 1'b0;
            upd_bpu_pred_taken_r <= 1'b0;
            upd_bpu_target_r  <= 32'd0;
        end else begin
            upd_bpu_en_r      <= upd_bpu_en;
            upd_bpu_pc_r      <= upd_bpu_pc;
            upd_bpu_ghr_r     <= upd_bpu_ghr;
            upd_bpu_br_type_r <= upd_bpu_br_type;
            upd_bpu_taken_r   <= upd_bpu_taken;
            upd_bpu_pred_taken_r <= upd_bpu_pred_taken;
            upd_bpu_target_r  <= upd_bpu_target;
        end
    end

    // ==========================================
    // IF 阶段
    // ==========================================
    wire [31:0] if_pc;
    wire         if_req_fire;

    bpu _bpu (
        .clk(clk), .resetn(resetn),
        .pc(if_pc),
        .pred_taken(if_pred_taken), .pred_target(if_pred_target), .pred_ghr(if_pred_ghr),
        .upd_en(upd_bpu_en_r), .upd_pc(upd_bpu_pc_r), .upd_ghr(upd_bpu_ghr_r),
        .upd_br_type(upd_bpu_br_type_r), .upd_pred_taken(upd_bpu_pred_taken_r),
        .upd_actually_taken(upd_bpu_taken_r), .upd_target(upd_bpu_target_r),
        .stat_btb_hits(stat_btb_hits), .stat_cond_preds(stat_cond_preds), .stat_pred_correct(stat_pred_correct), .stat_pred_wrong(stat_pred_wrong),
        .stat_loop_overrides(stat_loop_overrides), .stat_ret_preds(stat_ret_preds), .stat_ret_correct(stat_ret_correct), .stat_ret_wrong(stat_ret_wrong), .stat_ras_fallbacks(stat_ras_fallbacks), .stat_ras_valid_preds(stat_ras_valid_preds),
        .stat_loop_hits(stat_loop_hits), .stat_loop_confident(stat_loop_confident), .stat_loop_correct(stat_loop_correct), .stat_loop_wrong(stat_loop_wrong),
        .stat_loop_override_taken(stat_loop_override_taken), .stat_loop_override_wrong(stat_loop_override_wrong)
    );

    stage_if _stage_if (
        .clk(clk), .resetn(resetn), .stall_if(fetch_pc_stall),
        .id_pred_wrong(ex_br_taken), .id_correct_pc(ex_br_target), 
        .if_pred_taken(if_pred_taken), .if_pred_target(if_pred_target),
        .inst_sram_en(internal_inst_en),
        .inst_sram_addr(internal_inst_addr),
        .if_pc(if_pc), .if_req_fire(if_req_fire)
    );

    reg         fetch_pending_valid;
    reg [31:0]  fetch_pending_pc;
    reg         fetch_pending_pred_taken;
    reg [31:0]  fetch_pending_pred_target;
    reg [ 7:0]  fetch_pending_pred_ghr;

    reg [ 1:0]  fetch_fifo_count;
    reg [31:0]  fetch_fifo_pc0, fetch_fifo_pc1;
    reg [31:0]  fetch_fifo_inst0, fetch_fifo_inst1;
    reg         fetch_fifo_pred_taken0, fetch_fifo_pred_taken1;
    reg [31:0]  fetch_fifo_pred_target0, fetch_fifo_pred_target1;
    reg [ 7:0]  fetch_fifo_pred_ghr0, fetch_fifo_pred_ghr1;

    reg [ 2:0]  inst_discard_cnt;

    wire fetch_fifo_pop = (fetch_fifo_count != 2'd0) && !stall[1] && !flush[1];
    wire fetch_resp_real = inst_sram_data_ok && (inst_discard_cnt == 3'd0) && fetch_pending_valid;
    wire fetch_resp_direct = fetch_resp_real && (fetch_fifo_count == 2'd0) && !stall[1] && !flush[1];
    wire fetch_resp_to_fifo = fetch_resp_real && !fetch_resp_direct;
    wire fetch_id_consume = fetch_fifo_pop || fetch_resp_direct;

    wire current_fetch_abandoned = flush[1] && fetch_pending_valid && !inst_sram_data_ok;
    wire old_fetch_returned = inst_sram_data_ok && (inst_discard_cnt != 3'd0);

    always @(posedge clk) begin
        if (~resetn) begin
            inst_discard_cnt <= 3'd0;
        end else begin
            inst_discard_cnt <= inst_discard_cnt
                            + (current_fetch_abandoned ? 3'd1 : 3'd0)
                            - (old_fetch_returned ? 3'd1 : 3'd0);
        end
    end

    wire [2:0] fetch_occupancy = {2'b00, fetch_pending_valid} + {1'b0, fetch_fifo_count};
    wire [2:0] fetch_occupancy_after_consume = fetch_occupancy - (fetch_id_consume ? 3'd1 : 3'd0);

    assign fetch_issue_valid = !flush[1] && (!fetch_pending_valid || inst_sram_data_ok) &&
                               (fetch_occupancy_after_consume < 3'd2);

    wire fetch_req_fire = inst_sram_req && inst_sram_addr_ok;
    assign fetch_pc_stall = !fetch_req_fire;

    always @(posedge clk) begin
        if (~resetn || flush[1]) begin
            fetch_pending_valid <= 1'b0;
            fetch_fifo_count    <= 2'd0;
        end else begin
            if (fetch_resp_to_fifo && !fetch_fifo_pop) begin
                fetch_fifo_count <= fetch_fifo_count + 2'd1;
            end else if (!fetch_resp_to_fifo && fetch_fifo_pop) begin
                fetch_fifo_count <= fetch_fifo_count - 2'd1;
            end

            if (fetch_fifo_pop) begin
                if (fetch_fifo_count == 2'd2) begin
                    fetch_fifo_pc0          <= fetch_fifo_pc1;
                    fetch_fifo_inst0        <= fetch_fifo_inst1;
                    fetch_fifo_pred_taken0  <= fetch_fifo_pred_taken1;
                    fetch_fifo_pred_target0 <= fetch_fifo_pred_target1;
                    fetch_fifo_pred_ghr0    <= fetch_fifo_pred_ghr1;
                end
            end

            if (fetch_resp_to_fifo) begin
                if (fetch_fifo_pop) begin
                    if (fetch_fifo_count == 2'd1) begin
                        fetch_fifo_pc0          <= fetch_pending_pc;
                        fetch_fifo_inst0        <= inst_sram_rdata;
                        fetch_fifo_pred_taken0  <= fetch_pending_pred_taken;
                        fetch_fifo_pred_target0 <= fetch_pending_pred_target;
                        fetch_fifo_pred_ghr0    <= fetch_pending_pred_ghr;
                    end else begin
                        fetch_fifo_pc1          <= fetch_pending_pc;
                        fetch_fifo_inst1        <= inst_sram_rdata;
                        fetch_fifo_pred_taken1  <= fetch_pending_pred_taken;
                        fetch_fifo_pred_target1 <= fetch_pending_pred_target;
                        fetch_fifo_pred_ghr1    <= fetch_pending_pred_ghr;
                    end
                end else begin
                    if (fetch_fifo_count == 2'd0) begin
                        fetch_fifo_pc0          <= fetch_pending_pc;
                        fetch_fifo_inst0        <= inst_sram_rdata;
                        fetch_fifo_pred_taken0  <= fetch_pending_pred_taken;
                        fetch_fifo_pred_target0 <= fetch_pending_pred_target;
                        fetch_fifo_pred_ghr0    <= fetch_pending_pred_ghr;
                    end else begin
                        fetch_fifo_pc1          <= fetch_pending_pc;
                        fetch_fifo_inst1        <= inst_sram_rdata;
                        fetch_fifo_pred_taken1  <= fetch_pending_pred_taken;
                        fetch_fifo_pred_target1 <= fetch_pending_pred_target;
                        fetch_fifo_pred_ghr1    <= fetch_pending_pred_ghr;
                    end
                end
            end

            if (fetch_req_fire) begin
                fetch_pending_valid      <= 1'b1;
                fetch_pending_pc         <= if_pc;
                fetch_pending_pred_taken <= if_pred_taken;
                fetch_pending_pred_target<= if_pred_target;
                fetch_pending_pred_ghr   <= if_pred_ghr;
            end else if (inst_sram_data_ok) begin
                fetch_pending_valid <= 1'b0;
            end
        end
    end

    wire [31:0] id_pc, id_inst;
    wire         id_valid;

    wire fetch_fifo_has_data = (fetch_fifo_count != 2'd0);
    wire if_id_valid_in = fetch_fifo_has_data ? 1'b1 : fetch_resp_direct;
    wire [31:0] if_id_pc_in = fetch_fifo_has_data ? fetch_fifo_pc0 : fetch_pending_pc;
    wire [31:0] if_id_inst_in = fetch_fifo_has_data ? fetch_fifo_inst0 : inst_sram_rdata;
    wire if_id_pred_taken_in = fetch_fifo_has_data ? fetch_fifo_pred_taken0 : fetch_pending_pred_taken;
    wire [31:0] if_id_pred_target_in = fetch_fifo_has_data ? fetch_fifo_pred_target0 : fetch_pending_pred_target;
    wire [7:0] if_id_pred_ghr_in = fetch_fifo_has_data ? fetch_fifo_pred_ghr0 : fetch_pending_pred_ghr;

    if_id_reg _if_id_reg (
        .clk(clk), .resetn(resetn), .stall(stall[1]), .flush(flush[1]), .if_valid(if_id_valid_in),
        .if_pc(if_id_pc_in), .if_inst(if_id_inst_in), .if_pred_taken(if_id_pred_taken_in), .if_pred_target(if_id_pred_target_in), .if_pred_ghr(if_id_pred_ghr_in),
        .id_pc(id_pc), .id_inst(id_inst), .id_valid(id_valid),
        .id_pred_taken(id_pred_taken), .id_pred_target(id_pred_target), .id_pred_ghr(id_pred_ghr)
    );

    // ==========================================
    // ID 阶段
    // ==========================================
    wire         wb_rf_we, ex_rf_we, mem_rf_we;
    wire [ 4:0] wb_waddr, ex_waddr, mem_waddr;
    wire [31:0] wb_data, ex_result, mem_final_data;

    wire         id_rf_we, id_mem_en, id_is_st_w, id_is_st_b, id_is_ld_b, id_is_ld_bu, id_is_branch;
    wire         id_is_cpucfg, id_is_cacop;
    wire [ 1:0] id_wb_sel;
    wire [ 1:0] id_csr_op;
    wire [13:0] id_csr_num;
    wire [ 4:0] id_cacop_code;
    wire [ 4:0] id_waddr, id_rs1, id_rs2;
    wire [11:0] id_alu_op; 
    wire [31:0] id_alu_src1, id_alu_src2, id_rdata2;
    
    wire [31:0] id_imm;
    wire [11:0] id_br_info;
    wire        id_valid_inst;
    wire [31:0] id_normal_br_target;
    wire        ex_fw_valid;

    wire mul_issue = resetn && id_valid_inst && (id_wb_sel == 2'b10) &&
                     !stall[1] && !flush[2];
    wire [31:0] mul_operand_a = id_alu_src1;
    wire [31:0] mul_operand_b = id_alu_src2;
    wire [31:0] mul_result;
    wire        mul_result_valid;

    mul_top _mul_top (
        .clk     (clk),
        .ce      (1'b1),
        .resetn  (resetn),
        .issue_valid(mul_issue),
        .x       (mul_operand_a),
        .y       (mul_operand_b),
        .result  (mul_result),
        .result_valid(mul_result_valid)
    );

    stage_id _stage_id (
        .clk(clk), .resetn(resetn), .ex_fw_valid(ex_fw_valid),
        .id_pc(id_pc),
        .id_inst(id_inst),      
        .id_valid(id_valid),
        .wb_rf_we(wb_rf_we), .wb_waddr(wb_waddr), .wb_data(wb_data),
        .ex_rf_we(ex_rf_we), .ex_waddr(ex_waddr), .ex_result(ex_result),
        .mem_rf_we(mem_rf_we), .mem_waddr(mem_waddr), .mem_final_data(mem_final_data),
        
        .id_rf_we(id_rf_we), .id_waddr(id_waddr), .id_wb_sel(id_wb_sel),
        .id_mem_en(id_mem_en), .id_is_st_w(id_is_st_w), .id_is_st_b(id_is_st_b), .id_is_ld_b(id_is_ld_b),
        .id_is_ld_bu(id_is_ld_bu),
        .id_is_cpucfg(id_is_cpucfg), .id_csr_op(id_csr_op), .id_csr_num(id_csr_num),
        .id_is_cacop(id_is_cacop), .id_cacop_code(id_cacop_code),
        .id_alu_op(id_alu_op), .id_alu_src1(id_alu_src1), .id_alu_src2(id_alu_src2), .id_rdata2(id_rdata2),
        .id_rs1(id_rs1), .id_rs2(id_rs2),
        
        .id_imm(id_imm), .id_br_info(id_br_info), .id_is_branch(id_is_branch), .id_valid_inst(id_valid_inst),
        .id_normal_br_target(id_normal_br_target) 
    );

    wire [31:0] ex_pc, ex_alu_src1, ex_alu_src2, ex_rdata2;
    wire [ 1:0] ex_wb_sel;
    wire         ex_mem_en;
    wire         ex_is_cpucfg, ex_is_cacop;
    wire [ 1:0] ex_csr_op;
    wire [13:0] ex_csr_num;
    wire [ 4:0] ex_cacop_code;
    wire [11:0] ex_alu_op;  
    
    wire [11:0] ex_br_info;
    wire        ex_is_branch, ex_pred_taken, ex_valid_inst;
    wire [31:0] ex_pred_target;
    wire [ 7:0] ex_pred_ghr;
    wire [31:0] ex_normal_br_target; 
    wire [ 4:0] ex_rs2;

    id_ex_reg _id_ex_reg (
        .clk(clk), .resetn(resetn), .stall(stall[1]), .flush(flush[2]),
        .id_pc(id_pc), .id_rf_we(id_rf_we), .id_waddr(id_waddr), .id_wb_sel(id_wb_sel),
        .id_mem_en(id_mem_en), .id_is_st_w(id_is_st_w), .id_is_st_b(id_is_st_b), .id_is_ld_b(id_is_ld_b),
        .id_is_ld_bu(id_is_ld_bu),
        .id_is_cpucfg(id_is_cpucfg), .id_csr_op(id_csr_op), .id_csr_num(id_csr_num),
        .id_is_cacop(id_is_cacop), .id_cacop_code(id_cacop_code),
        .id_alu_op(id_alu_op), .id_alu_src1(id_alu_src1), .id_alu_src2(id_alu_src2), .id_rdata2(id_rdata2),
        
        .id_rs2(id_rs2),  

        .id_br_info(id_br_info), .id_is_branch(id_is_branch),
        .id_pred_taken(id_pred_taken), .id_pred_target(id_pred_target), .id_pred_ghr(id_pred_ghr), .id_valid_inst(id_valid_inst),
        .id_normal_br_target(id_normal_br_target), 
        
        .ex_pc(ex_pc), .ex_rf_we(ex_rf_we), .ex_waddr(ex_waddr), .ex_wb_sel(ex_wb_sel),
        .ex_mem_en(ex_mem_en), .ex_is_st_w(ex_is_st_w), .ex_is_st_b(ex_is_st_b), .ex_is_ld_b(ex_is_ld_b),
        .ex_is_ld_bu(ex_is_ld_bu), 
        .ex_is_cpucfg(ex_is_cpucfg), .ex_csr_op(ex_csr_op), .ex_csr_num(ex_csr_num),
        .ex_is_cacop(ex_is_cacop), .ex_cacop_code(ex_cacop_code),
        .ex_alu_op(ex_alu_op), .ex_alu_src1(ex_alu_src1), .ex_alu_src2(ex_alu_src2), .ex_rdata2(ex_rdata2),
        
        .ex_rs2(ex_rs2),  
        
        .ex_br_info(ex_br_info), .ex_is_branch(ex_is_branch),
        .ex_pred_taken(ex_pred_taken), .ex_pred_target(ex_pred_target), .ex_pred_ghr(ex_pred_ghr), .ex_valid_inst(ex_valid_inst),
        .ex_normal_br_target(ex_normal_br_target)  
    );

    // ==========================================
    // EX 阶段
    // ==========================================
    
    wire [31:0] mem_pc, mem_result;
    wire [ 1:0] mem_wb_sel, mem_addr_align;
    wire         mem_is_ld_b, mem_is_ld_bu, mem_valid;
    wire [ 1:0] ex_addr_align;
    wire         ex_mem_read;
    wire         csr_we;
    wire [13:0]  csr_waddr;
    wire [31:0]  csr_wdata, csr_wmask, csr_rdata;
    wire         ex_is_mul = ex_valid_inst && (ex_wb_sel == 2'b10);
    assign ex_fw_valid = !ex_is_mul && !ex_mem_read;

    wire mem_is_load = mem_valid && mem_rf_we && (mem_wb_sel == 2'b01);
    wire mem_is_mul  = mem_valid && mem_rf_we && (mem_wb_sel == 2'b10);

    stage_ex _stage_ex (
        .stall_ex(stall[2]),
        .ex_pc(ex_pc), .ex_wb_sel(ex_wb_sel), .ex_mem_en(ex_mem_en),
        .ex_is_st_w(ex_is_st_w), .ex_is_st_b(ex_is_st_b), .ex_alu_op(ex_alu_op),
        .ex_alu_src1(ex_alu_src1), .ex_alu_src2(ex_alu_src2), .ex_rdata2(ex_rdata2),
        .ex_is_cpucfg(ex_is_cpucfg), .ex_csr_op(ex_csr_op), .ex_csr_num(ex_csr_num), .csr_rdata(csr_rdata),
        .ex_is_cacop(ex_is_cacop), .ex_cacop_code(ex_cacop_code),
        .ex_rs2(ex_rs2),
        .mem_is_load(mem_is_load),
        .mem_waddr(mem_waddr),
        .mem_final_data(mem_final_data),
        .ex_br_info(ex_br_info), .ex_is_branch(ex_is_branch),
        .ex_pred_taken(ex_pred_taken), .ex_pred_target(ex_pred_target), .ex_pred_ghr(ex_pred_ghr), .ex_valid_inst(ex_valid_inst),
        .ex_normal_br_target(ex_normal_br_target), 
        
        .ex_result(ex_result), .ex_addr_align(ex_addr_align),
        .data_sram_en(internal_data_en),       
        .data_sram_wen(internal_data_wen),     
        .data_sram_addr(internal_data_addr),   
        .data_sram_wdata(internal_data_wdata), 
        .ex_mem_read(ex_mem_read),
        .csr_we(csr_we), .csr_waddr(csr_waddr), .csr_wdata(csr_wdata), .csr_wmask(csr_wmask),
        .ex_cacop_valid(icache_cacop_valid), .ex_cacop_code_out(icache_cacop_code), .ex_cacop_addr(icache_cacop_addr),
        
        .ex_br_taken(ex_br_taken), .ex_br_target(ex_br_target),
        .upd_bpu_en(upd_bpu_en), .upd_bpu_pc(upd_bpu_pc), .upd_bpu_ghr(upd_bpu_ghr),
        .upd_bpu_br_type_out(upd_bpu_br_type), .upd_bpu_pred_taken(upd_bpu_pred_taken),
        .upd_bpu_taken(upd_bpu_taken), .upd_bpu_target(upd_bpu_target)
    );

    csr_file _csr_file (
        .clk(clk), .resetn(resetn),
        .csr_num(ex_csr_num), .csr_rdata(csr_rdata),
        .csr_we(csr_we), .csr_waddr(csr_waddr), .csr_wdata(csr_wdata), .csr_wmask(csr_wmask),
        .crmd(csr_crmd), .dmw0(csr_dmw0), .dmw1(csr_dmw1)
    );

    localparam MUL_RESULT_FIFO_DEPTH = 4;
    reg [31:0] mul_result_fifo [0:MUL_RESULT_FIFO_DEPTH-1];
    reg [1:0]  mul_result_fifo_head;
    reg [1:0]  mul_result_fifo_tail;
    reg [2:0]  mul_result_fifo_count;

    wire        mul_result_fifo_empty = (mul_result_fifo_count == 3'd0);
    wire        mul_result_available  = !mul_result_fifo_empty || mul_result_valid;
    wire [31:0] mem_mul_result = mul_result_fifo_empty ? mul_result :
                                                        mul_result_fifo[mul_result_fifo_head];

    wire mul_result_consume = mem_is_mul && mul_result_available;
    wire mul_result_push    = mul_result_valid &&
                              !(mul_result_fifo_empty && mul_result_consume);
    wire mul_result_pop     = !mul_result_fifo_empty && mul_result_consume;

    always @(posedge clk) begin
        if (~resetn) begin
            mul_result_fifo_head  <= 2'd0;
            mul_result_fifo_tail  <= 2'd0;
            mul_result_fifo_count <= 3'd0;
        end else begin
            if (mul_result_push) begin
                mul_result_fifo[mul_result_fifo_tail] <= mul_result;
                mul_result_fifo_tail <= mul_result_fifo_tail + 2'd1;
            end
            if (mul_result_pop) begin
                mul_result_fifo_head <= mul_result_fifo_head + 2'd1;
            end
            case ({mul_result_push, mul_result_pop})
                2'b10: mul_result_fifo_count <= mul_result_fifo_count + 3'd1;
                2'b01: mul_result_fifo_count <= mul_result_fifo_count - 3'd1;
                default: mul_result_fifo_count <= mul_result_fifo_count;
            endcase
        end
    end

    ex_mem_reg _ex_mem_reg (
        .clk(clk), .resetn(resetn), .stall(stall[2]), .flush(flush[3]),
        .ex_pc(ex_pc), .ex_rf_we(ex_rf_we), .ex_waddr(ex_waddr), .ex_wb_sel(ex_wb_sel),
        .ex_is_ld_b(ex_is_ld_b), .ex_is_ld_bu(ex_is_ld_bu),
        .ex_addr_align(ex_addr_align), .ex_result(ex_result),
        .ex_valid_inst(ex_valid_inst),
        .mem_pc(mem_pc), .mem_rf_we(mem_rf_we), .mem_waddr(mem_waddr), .mem_wb_sel(mem_wb_sel),
        .mem_is_ld_b(mem_is_ld_b), .mem_is_ld_bu(mem_is_ld_bu),
        .mem_addr_align(mem_addr_align), .mem_result(mem_result), .mem_valid(mem_valid)
    );

    reg [31:0] data_rdata_buf;
    wire [ 7:0] response_byte = (ex_addr_align == 2'b00) ? data_sram_rdata[ 7:0] :
                                (ex_addr_align == 2'b01) ? data_sram_rdata[15:8] :
                                (ex_addr_align == 2'b10) ? data_sram_rdata[23:16] :
                                                            data_sram_rdata[31:24];
    wire [31:0] response_load_data = ex_is_ld_b  ? {{24{response_byte[7]}}, response_byte} :
                                      ex_is_ld_bu ? {24'd0, response_byte} : data_sram_rdata;
    always @(posedge clk) begin
        if (data_sram_data_ok) begin
            data_rdata_buf <= response_load_data;
        end
    end
    wire [31:0] actual_data_rdata = data_sram_data_ok ? data_sram_rdata : data_rdata_buf;
    
    // ==========================================
    // MEM 阶段
    // ==========================================
    wire mem_done;

    stage_mem _stage_mem (
        .mem_wb_sel(mem_wb_sel), .mem_rf_we(mem_rf_we), .mem_is_ld_b(mem_is_ld_b),
        .mem_is_ld_bu(mem_is_ld_bu),
        .mem_addr_align(mem_addr_align), .mem_result(mem_result), .mem_mul_result(mem_mul_result), .mem_valid(mem_valid),
        .data_sram_rdata(actual_data_rdata),
        .data_sram_resp_valid(1'b1),
        .mul_result_valid(mul_result_available),
        .mem_final_data(mem_final_data), .mem_done(mem_done), .mem_wait(mul_mem_wait)
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
    // Hazard Ctrl
    // ==========================================
    hazard_ctrl _hazard_ctrl (
        .ex_valid_inst (ex_valid_inst),
        .id_valid      (id_valid),     
        .id_inst       (id_inst),       
        
        .id_rs1(id_rs1), .id_rs2(id_rs2),
        .ex_waddr(ex_waddr), .ex_mem_read(ex_mem_read), .ex_is_mul(ex_is_mul),
        .ex_br_taken(ex_br_taken), 
        .if_wait(inst_sram_wait),  
        .mem_wait(mem_wait),
        .mem_stage_wait(mul_mem_wait),
        .stall(stall), .flush(flush)
    );

endmodule
