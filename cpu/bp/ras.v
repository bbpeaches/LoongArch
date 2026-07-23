module ras #(
    parameter DEPTH = 32,
    parameter PTR_W = 5,
    parameter DEPTH_W = 6
)(
    input  wire        clk,
    input  wire        resetn,

    // --- 预测读取端口 ---
    output wire [31:0] ras_target,
    output wire        ras_valid,

    // --- 训练更新端口 ---
    input  wire        upd_en,
    input  wire [ 1:0] upd_br_type,
    input  wire [31:0] upd_pc
);
    reg  [31:0] stack [0:DEPTH-1];
    reg  [PTR_W-1:0]   tos;
    reg  [DEPTH_W-1:0] depth;

    assign ras_valid  = (depth != {DEPTH_W{1'b0}});
    assign ras_target = stack[(tos - 1'b1) & (DEPTH-1)];

    always @(posedge clk) begin
        if (~resetn) begin
            tos   <= {PTR_W{1'b0}};
            depth <= {DEPTH_W{1'b0}};
        end
        else if (upd_en) begin
            if (upd_br_type == 2'b10) begin
                stack[tos] <= upd_pc + 32'd4;
                tos        <= tos + 1'b1;
                if (depth != DEPTH[DEPTH_W-1:0]) depth <= depth + 1'b1;
            end
            else if (upd_br_type == 2'b11) begin
                if (depth != {DEPTH_W{1'b0}}) begin
                    tos   <= tos - 1'b1;
                    depth <= depth - 1'b1;
                end
            end
        end
    end
endmodule
