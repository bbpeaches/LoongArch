module loop_bpu (
    input  wire        clk,
    input  wire        resetn,

    // --- 预测读取端口 ---
    input  wire [21:2] pc,
    output wire        loop_valid_pred,
    output wire        loop_pred_taken,

    // --- 训练更新端口 ---
    input  wire        upd_loop_en,
    input  wire [21:2] upd_pc,
    input  wire        upd_actually_taken,

    // --- 统计输出 ---
    output reg  [31:0] stat_loop_hits,
    output reg  [31:0] stat_loop_confident,
    output reg  [31:0] stat_loop_correct,
    output reg  [31:0] stat_loop_wrong,
    output reg  [31:0] stat_override_taken,
    output reg  [31:0] stat_override_wrong
);
    reg         valid  [0:15];
    reg  [15:0] tag    [0:15];
    reg  [ 9:0] tcnt   [0:15];
    reg  [ 9:0] ccnt   [0:15];
    reg  [ 1:0] conf   [0:15];
    reg  [ 1:0] stable [0:15];

    wire [ 3:0] fetch_idx = pc[5:2];
    wire [15:0] fetch_tag = pc[21:6];

    wire hit = valid[fetch_idx] && (tag[fetch_idx] == fetch_tag);
    wire confident = (conf[fetch_idx] == 2'b11);
    wire stable_enough = (stable[fetch_idx] == 2'b11);
    assign loop_valid_pred = hit && confident && stable_enough;
    assign loop_pred_taken = (ccnt[fetch_idx] < tcnt[fetch_idx]);

    wire [ 3:0] upd_idx = upd_pc[5:2];
    wire [15:0] upd_tag = upd_pc[21:6];
    wire loop_pred_on_update = valid[upd_idx] && (tag[upd_idx] == upd_tag) && (conf[upd_idx] == 2'b11) && (stable[upd_idx] == 2'b11);
    wire loop_pred_taken_on_update = (ccnt[upd_idx] < tcnt[upd_idx]);

    integer i;
    always @(posedge clk) begin
        if (~resetn) begin
            stat_loop_hits      <= 32'd0;
            stat_loop_confident <= 32'd0;
            stat_loop_correct   <= 32'd0;
            stat_loop_wrong     <= 32'd0;
            stat_override_taken <= 32'd0;
            stat_override_wrong <= 32'd0;
            for (i = 0; i < 16; i = i + 1) begin
                valid[i]  <= 1'b0;
                tag[i]    <= 16'd0;
                tcnt[i]   <= 10'd0;
                ccnt[i]   <= 10'd0;
                conf[i]   <= 2'b00;
                stable[i] <= 2'b00;
            end
        end else if (upd_loop_en) begin
            if (valid[upd_idx] && (tag[upd_idx] == upd_tag)) begin
                stat_loop_hits <= stat_loop_hits + 1;
                if (loop_pred_on_update) begin
                    stat_override_taken <= stat_override_taken + 1;
                    if (loop_pred_taken_on_update == upd_actually_taken) stat_loop_correct <= stat_loop_correct + 1;
                    else stat_override_wrong <= stat_override_wrong + 1;
                end

                if (upd_actually_taken) begin
                    ccnt[upd_idx] <= ccnt[upd_idx] + 1;
                end else begin
                    if (ccnt[upd_idx] == tcnt[upd_idx]) begin
                        stat_loop_confident <= stat_loop_confident + 1;
                        if (conf[upd_idx] != 2'b11) conf[upd_idx] <= conf[upd_idx] + 1;
                        if (stable[upd_idx] != 2'b11) stable[upd_idx] <= stable[upd_idx] + 1;
                    end else begin
                        stat_loop_wrong <= stat_loop_wrong + 1;
                        tcnt[upd_idx]   <= ccnt[upd_idx];
                        conf[upd_idx]   <= 2'b00;
                        stable[upd_idx] <= 2'b00;
                    end
                    ccnt[upd_idx] <= 10'd0;
                end
            end else begin
                valid[upd_idx]  <= 1'b1;
                tag[upd_idx]    <= upd_tag;
                tcnt[upd_idx]   <= 10'd0;
                ccnt[upd_idx]   <= upd_actually_taken ? 10'd1 : 10'd0;
                conf[upd_idx]   <= 2'b00;
                stable[upd_idx] <= 2'b00;
            end
        end
    end
endmodule
