module cpu(
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

    assign inst_sram_req   = internal_inst_en & fetch_issue_valid;
    assign inst_sram_wr    = 1'b0;       
    assign inst_sram_size  = 2'b10;      
    assign inst_sram_wstrb = 4'b0000;
    assign inst_sram_addr  = internal_inst_addr;
    assign inst_sram_wdata = 32'd0;

    assign inst_sram_wait  = fetch_pc_stall;

    wire         internal_data_en;
    wire [ 3:0] internal_data_wen;
    wire [31:0] internal_data_addr;
    wire [31:0] internal_data_wdata;
    wire         mem_wait;
    wire         ex_is_st_w;
    wire         ex_is_st_b;

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

    wire         if_pred_taken, id_pred_taken;
    wire [31:0] if_pred_target, id_pred_target;
    wire [7:0]  if_pred_ghr, id_pred_ghr;
    
    wire         upd_bpu_en, upd_bpu_taken;
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
    reg [31:0] upd_bpu_target_r;

    always @(posedge clk) begin
        if (~resetn) begin
            upd_bpu_en_r      <= 1'b0;
            upd_bpu_pc_r      <= 32'd0;
            upd_bpu_ghr_r     <= 8'd0;
            upd_bpu_br_type_r <= 2'd0;
            upd_bpu_taken_r   <= 1'b0;
            upd_bpu_target_r  <= 32'd0;
        end else begin
            upd_bpu_en_r      <= upd_bpu_en;
            upd_bpu_pc_r      <= upd_bpu_pc;
            upd_bpu_ghr_r     <= upd_bpu_ghr;
            upd_bpu_br_type_r <= upd_bpu_br_type;
            upd_bpu_taken_r   <= upd_bpu_taken;
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
        .pc(if_pc), .pred_taken(if_pred_taken), .pred_target(if_pred_target), .pred_ghr(if_pred_ghr),
        .upd_en(upd_bpu_en_r), .upd_pc(upd_bpu_pc_r), .upd_ghr(upd_bpu_ghr_r),
        .upd_br_type(upd_bpu_br_type_r),
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
    wire [ 1:0] id_wb_sel;
    wire [ 4:0] id_waddr, id_rs1, id_rs2;
    wire [11:0] id_alu_op; 
    wire [31:0] id_alu_src1, id_alu_src2, id_rdata2;
    
    wire [31:0] id_imm;
    wire [11:0] id_br_info;
    wire        id_valid_inst;
    wire [31:0] id_normal_br_target;
    wire        ex_fw_valid;

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
        .id_alu_op(id_alu_op), .id_alu_src1(id_alu_src1), .id_alu_src2(id_alu_src2), .id_rdata2(id_rdata2),
        .id_rs1(id_rs1), .id_rs2(id_rs2),
        
        .id_imm(id_imm), .id_br_info(id_br_info), .id_is_branch(id_is_branch), .id_valid_inst(id_valid_inst),
        .id_normal_br_target(id_normal_br_target) 
    );

    wire [31:0] ex_pc, ex_alu_src1, ex_alu_src2, ex_rdata2;
    wire [ 1:0] ex_wb_sel;
    wire         ex_mem_en, ex_is_ld_b, ex_is_ld_bu;
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
        .id_alu_op(id_alu_op), .id_alu_src1(id_alu_src1), .id_alu_src2(id_alu_src2), .id_rdata2(id_rdata2),
        
        .id_rs2(id_rs2),  

        .id_br_info(id_br_info), .id_is_branch(id_is_branch),
        .id_pred_taken(id_pred_taken), .id_pred_target(id_pred_target), .id_pred_ghr(id_pred_ghr), .id_valid_inst(id_valid_inst),
        .id_normal_br_target(id_normal_br_target), 
        
        .ex_pc(ex_pc), .ex_rf_we(ex_rf_we), .ex_waddr(ex_waddr), .ex_wb_sel(ex_wb_sel),
        .ex_mem_en(ex_mem_en), .ex_is_st_w(ex_is_st_w), .ex_is_st_b(ex_is_st_b), .ex_is_ld_b(ex_is_ld_b),
        .ex_is_ld_bu(ex_is_ld_bu), 
        .ex_alu_op(ex_alu_op), .ex_alu_src1(ex_alu_src1), .ex_alu_src2(ex_alu_src2), .ex_rdata2(ex_rdata2),
        
        .ex_rs2(ex_rs2),  
        
        .ex_br_info(ex_br_info), .ex_is_branch(ex_is_branch),
        .ex_pred_taken(ex_pred_taken), .ex_pred_target(ex_pred_target), .ex_pred_ghr(ex_pred_ghr), .ex_valid_inst(ex_valid_inst),
        .ex_normal_br_target(ex_normal_br_target)  
    );

    // ==========================================
    // EX 阶段
    // ==========================================
    
    wire [31:0] mem_pc, mem_result, mem_mul_result;
    wire [ 1:0] mem_wb_sel, mem_addr_align;
    wire         mem_is_ld_b, mem_is_ld_bu, mem_valid;
    wire [ 1:0] ex_addr_align;
    wire         ex_mem_read;
    wire [31:0] ex_mul_result;
    wire         ex_is_mul = (ex_wb_sel == 2'b10);
    assign ex_fw_valid = !ex_is_mul && !ex_mem_read;

    wire mem_is_load = (mem_wb_sel == 2'b01);

    stage_ex _stage_ex (
        .clk(clk),
        .resetn(resetn),
        .stall_ex(stall[2]),
        .ex_pc(ex_pc), .ex_wb_sel(ex_wb_sel), .ex_mem_en(ex_mem_en),
        .ex_is_st_w(ex_is_st_w), .ex_is_st_b(ex_is_st_b), .ex_alu_op(ex_alu_op),
        .ex_alu_src1(ex_alu_src1), .ex_alu_src2(ex_alu_src2), .ex_rdata2(ex_rdata2),
        .ex_rs2(ex_rs2),
        .mem_is_load(mem_is_load),
        .mem_waddr(mem_waddr),
        .mem_final_data(mem_final_data),
        .ex_br_info(ex_br_info), .ex_is_branch(ex_is_branch),
        .ex_pred_taken(ex_pred_taken), .ex_pred_target(ex_pred_target), .ex_pred_ghr(ex_pred_ghr), .ex_valid_inst(ex_valid_inst),
        .ex_normal_br_target(ex_normal_br_target), 
        
        .ex_result(ex_result), .ex_mul_result(ex_mul_result), .ex_addr_align(ex_addr_align),
        .data_sram_en(internal_data_en),       
        .data_sram_wen(internal_data_wen),     
        .data_sram_addr(internal_data_addr),   
        .data_sram_wdata(internal_data_wdata), 
        .ex_mem_read(ex_mem_read),
        
        .ex_br_taken(ex_br_taken), .ex_br_target(ex_br_target),
        .upd_bpu_en(upd_bpu_en), .upd_bpu_pc(upd_bpu_pc), .upd_bpu_ghr(upd_bpu_ghr),
        .upd_bpu_br_type_out(upd_bpu_br_type), .upd_bpu_taken(upd_bpu_taken), .upd_bpu_target(upd_bpu_target)
    );

    assign mem_mul_result = ex_mul_result;

    ex_mem_reg _ex_mem_reg (
        .clk(clk), .resetn(resetn), .stall(stall[2]), .flush(flush[3]),
        .ex_pc(ex_pc), .ex_rf_we(ex_rf_we), .ex_waddr(ex_waddr), .ex_wb_sel(ex_wb_sel),
        .ex_is_ld_b(ex_is_ld_b), .ex_is_ld_bu(ex_is_ld_bu),
        .ex_addr_align(ex_addr_align), .ex_result(ex_result),
        .mem_pc(mem_pc), .mem_rf_we(mem_rf_we), .mem_waddr(mem_waddr), .mem_wb_sel(mem_wb_sel),
        .mem_is_ld_b(mem_is_ld_b), .mem_is_ld_bu(mem_is_ld_bu),
        .mem_addr_align(mem_addr_align), .mem_result(mem_result), .mem_valid(mem_valid)
    );

    reg [31:0] data_rdata_buf;
    always @(posedge clk) begin
        if (data_sram_data_ok) begin
            data_rdata_buf <= data_sram_rdata;
        end
    end
    wire [31:0] actual_data_rdata = data_sram_data_ok ? data_sram_rdata : data_rdata_buf;
    
    // ==========================================
    // MEM 阶段
    // ==========================================
    wire mem_done;

    stage_mem _stage_mem (
        .mem_wb_sel(mem_wb_sel), .mem_is_ld_b(mem_is_ld_b),
        .mem_is_ld_bu(mem_is_ld_bu),
        .mem_addr_align(mem_addr_align), .mem_result(mem_result), .mem_mul_result(mem_mul_result), .mem_valid(mem_valid),
        .data_sram_rdata(actual_data_rdata),
        .data_sram_resp_valid(1'b1),
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
    // Hazard Ctrl
    // ==========================================
    hazard_ctrl _hazard_ctrl (
        .clk           (clk),
        .resetn        (resetn),
        .ex_valid_inst (ex_valid_inst),
        .id_valid      (id_valid),     
        .id_inst       (id_inst),       
        
        .id_rs1(id_rs1), .id_rs2(id_rs2),
        .ex_waddr(ex_waddr), .ex_mem_read(ex_mem_read), .ex_is_mul(ex_is_mul),
        .ex_br_taken(ex_br_taken), 
        .if_wait(inst_sram_wait),  
        .mem_wait(mem_wait),       
        .stall(stall), .flush(flush)
    );

endmodule