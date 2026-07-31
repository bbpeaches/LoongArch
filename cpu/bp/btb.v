module btb (
    input  wire        clk,
    input  wire        resetn,
    
    // --- 预测读取端口 ---
    input  wire [31:2] pc,
    output wire        btb_hit,
    output wire [ 1:0] btb_type,
    output wire [31:0] btb_target,
    
    // --- 训练更新端口 ---
    input  wire        upd_we,
    input  wire        upd_inv_en,
    input  wire [31:2] upd_pc,
    input  wire [ 1:0] upd_br_type,
    input  wire [31:0] upd_target
);
    // 64-entry direct-mapped BTB, indexed by PC[7:2].
    reg        valid      [0:63];
    reg  [ 1:0] entry_type [0:63];
    reg  [23:0] tag        [0:63];
    reg  [31:0] target     [0:63];

    wire [ 5:0] fetch_idx = pc[7:2];
    wire [23:0] fetch_tag = pc[31:8];
    
    assign btb_hit    = valid[fetch_idx] && (tag[fetch_idx] == fetch_tag);
    assign btb_type   = entry_type[fetch_idx];
    assign btb_target = target[fetch_idx];

    wire [ 5:0] upd_idx = upd_pc[7:2];
    wire [23:0] upd_tag = upd_pc[31:8];

    integer i;
    always @(posedge clk) begin
        if (~resetn) begin
            for (i = 0; i < 64; i = i + 1) valid[i] <= 1'b0;
        end
        else if (upd_inv_en) begin
            if (valid[upd_idx] && (tag[upd_idx] == upd_tag)) begin
                valid[upd_idx] <= 1'b0;
            end
        end
        else if (upd_we) begin
            valid[upd_idx]      <= 1'b1;
            tag[upd_idx]        <= upd_tag;
            target[upd_idx]     <= upd_target;
            entry_type[upd_idx] <= upd_br_type;
        end
    end
endmodule
