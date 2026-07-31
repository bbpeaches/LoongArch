module bpu (
    input  wire        clk,
    input  wire        resetn,

    // --- 预测端口 (IF 阶段使用) ---
    input  wire [31:0] pc,
    output wire        pred_taken,
    output wire [31:0] pred_target,
    output wire [ 7:0] pred_ghr,

    // --- 更新端口 (ID 阶段使用) ---
    input  wire        upd_en,
    input  wire [31:0] upd_pc,
    input  wire [ 7:0] upd_ghr,
    input  wire [ 1:0] upd_br_type,
    input  wire        upd_actually_taken,
    input  wire [31:0] upd_target,

    // --- 统计输出 ---
    output reg  [31:0] stat_btb_hits,
    output reg  [31:0] stat_cond_preds,
    output reg  [31:0] stat_pred_correct,
    output reg  [31:0] stat_pred_wrong,
    output reg  [31:0] stat_loop_overrides,
    output reg  [31:0] stat_ret_preds,
    output reg  [31:0] stat_ret_correct,
    output reg  [31:0] stat_ret_wrong,
    output reg  [31:0] stat_ras_fallbacks,
    output reg  [31:0] stat_ras_valid_preds,
    output wire [31:0] stat_loop_hits,
    output wire [31:0] stat_loop_confident,
    output wire [31:0] stat_loop_correct,
    output wire [31:0] stat_loop_wrong,
    output wire [31:0] stat_loop_override_taken,
    output wire [31:0] stat_loop_override_wrong
);
    wire upd_cond_en = upd_en && (upd_br_type == 2'b00);
    wire upd_btb_inv_en = upd_en && (upd_br_type == 2'b01) && !upd_actually_taken;
    wire upd_btb_we = upd_en && !upd_btb_inv_en && ((upd_br_type != 2'b00) || upd_actually_taken);
    wire        btb_hit;
    wire [ 1:0] btb_type;
    wire [31:0] btb_target_out;
    btb _btb (
        .clk(clk), .resetn(resetn), .pc(pc[31:2]),
        .btb_hit(btb_hit), .btb_type(btb_type), .btb_target(btb_target_out),
        .upd_we(upd_btb_we), .upd_inv_en(upd_btb_inv_en),
        .upd_pc(upd_pc[31:2]), .upd_br_type(upd_br_type), .upd_target(upd_target)
    );

    wire meta_taken;
    wire [ 7:0] fetch_ghr;
    assign pred_ghr = fetch_ghr;
    tournament_bpu _tournament (
        .clk(clk), .resetn(resetn), .pc(pc[9:2]),
        .meta_taken(meta_taken), .fetch_ghr(fetch_ghr),
        .upd_cond_en(upd_cond_en), .upd_pc(upd_pc[9:2]), .upd_ghr(upd_ghr), .upd_actually_taken(upd_actually_taken)
    );

    // Timing @150MHz: loop_bpu tag mux was on next_pc critical path (WNS~0).
    // Drop IF override; keep tournament+BTB same-cycle for hot loops.
    assign stat_loop_hits            = 32'd0;
    assign stat_loop_confident       = 32'd0;
    assign stat_loop_correct         = 32'd0;
    assign stat_loop_wrong           = 32'd0;
    assign stat_loop_override_taken  = 32'd0;
    assign stat_loop_override_wrong  = 32'd0;

    wire [31:0] ras_target;
    wire        ras_valid;
    ras _ras (
        .clk(clk), .resetn(resetn),
        .ras_target(ras_target), .ras_valid(ras_valid),
        .upd_en(upd_en), .upd_br_type(upd_br_type), .upd_pc(upd_pc)
    );

    wire is_fetch_ret  = (btb_type == 2'b11);
    wire final_cond_pred = meta_taken;
    wire is_fetch_cond   = (btb_type == 2'b00);

    assign pred_target = (btb_hit && is_fetch_ret && ras_valid) ? ras_target : btb_target_out;
    assign pred_taken  = btb_hit && (!is_fetch_cond || final_cond_pred);

    wire pred_used_ret  = btb_hit && is_fetch_ret;
    wire pred_ret_taken = btb_hit && is_fetch_ret && ras_valid;

    always @(posedge clk) begin
        if (~resetn) begin
            stat_btb_hits       <= 32'd0;
            stat_cond_preds     <= 32'd0;
            stat_pred_correct   <= 32'd0;
            stat_pred_wrong     <= 32'd0;
            stat_loop_overrides <= 32'd0;
            stat_ret_preds      <= 32'd0;
            stat_ret_correct    <= 32'd0;
            stat_ret_wrong      <= 32'd0;
            stat_ras_fallbacks  <= 32'd0;
            stat_ras_valid_preds<= 32'd0;
        end else begin
            if (btb_hit) stat_btb_hits <= stat_btb_hits + 1;
            if (btb_hit && is_fetch_cond) stat_cond_preds <= stat_cond_preds + 1;
            if (pred_used_ret) stat_ret_preds <= stat_ret_preds + 1;
            if (pred_ret_taken) stat_ras_valid_preds <= stat_ras_valid_preds + 1;
            if (btb_hit && is_fetch_ret && !ras_valid) stat_ras_fallbacks <= stat_ras_fallbacks + 1;

            if (upd_cond_en) begin
                if (meta_taken == upd_actually_taken) stat_pred_correct <= stat_pred_correct + 1;
                else stat_pred_wrong <= stat_pred_wrong + 1;
            end

            if (upd_en && (upd_br_type == 2'b11)) begin
                if (pred_ret_taken == upd_actually_taken) stat_ret_correct <= stat_ret_correct + 1;
                else stat_ret_wrong <= stat_ret_wrong + 1;
            end
        end
    end

endmodule
