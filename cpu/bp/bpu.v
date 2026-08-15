module bpu (
    input  wire        clk,
    input  wire        resetn,

    // --- 单级预测端口（IF 阶段） ---
    input  wire [31:0] pc,
    output wire        pred_taken,
    output wire [31:0] pred_target,
    output wire [ 7:0] pred_ghr,

    // --- 更新端口（EX 阶段） ---
    input  wire        upd_en,
    input  wire [31:0] upd_pc,
    input  wire [ 7:0] upd_ghr,
    input  wire [ 1:0] upd_br_type,
    input  wire        upd_pred_taken,
    input  wire        upd_actually_taken,
    input  wire [31:0] upd_target

);
    wire upd_cond_en = upd_en && (upd_br_type == 2'b00);

    wire upd_btb_inv_en = upd_en && (upd_br_type == 2'b01) && !upd_actually_taken;
    wire upd_btb_we = upd_en && !upd_btb_inv_en;
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
    wire [7:0] fetch_ghr;
    assign pred_ghr = fetch_ghr;
    tournament_bpu _tournament (
        .clk(clk), .resetn(resetn), .pc(pc[9:2]),
        .meta_taken(meta_taken), .fetch_ghr(fetch_ghr),
        .upd_cond_en(upd_cond_en), .upd_pc(upd_pc[9:2]),
        .upd_ghr(upd_ghr), .upd_actually_taken(upd_actually_taken)
    );

    wire [31:0] ras_target;
    wire        ras_valid;
    ras _ras (
        .clk(clk), .resetn(resetn),
        .ras_target(ras_target), .ras_valid(ras_valid),
        .upd_en(upd_en), .upd_br_type(upd_br_type), .upd_pc(upd_pc)
    );

    wire is_fetch_ret  = (btb_type == 2'b11);
    wire is_fetch_cond = (btb_type == 2'b00);

    assign pred_target = (btb_hit && is_fetch_ret && ras_valid) ? ras_target : btb_target_out;
    assign pred_taken  = btb_hit && (!is_fetch_cond || meta_taken);

endmodule
