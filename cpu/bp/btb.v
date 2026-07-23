module btb (
    input  wire        clk,
    input  wire        resetn,
    
    // --- 预测读取端口 ---
    input  wire [31:2] pc,
    output wire        btb_hit,
    output wire [ 1:0] btb_type,
    output wire [31:0] btb_target,
    
    // --- 训练更新端口 ---
    input  wire        upd_en,
    input  wire [31:2] upd_pc,
    input  wire [ 1:0] upd_br_type,
    input  wire [31:0] upd_target
);
    reg         valid      [0:1023];
    reg  [ 1:0] entry_type [0:1023];
    reg  [19:0] tag        [0:1023];
    reg  [31:0] target     [0:1023];

    // 读取逻辑
    wire [ 9:0] fetch_idx = pc[11:2];
    wire [19:0] fetch_tag = pc[31:12];
    
    assign btb_hit    = valid[fetch_idx] && (tag[fetch_idx] == fetch_tag);
    assign btb_type   = entry_type[fetch_idx];
    assign btb_target = target[fetch_idx];

    // 更新逻辑
    wire [ 9:0] upd_idx = upd_pc[11:2];
    wire [19:0] upd_tag = upd_pc[31:12];

    integer i;
    always @(posedge clk) begin
        if (~resetn) begin
            for (i = 0; i < 1024; i = i + 1) valid[i] <= 1'b0;
        end
        else if (upd_en) begin
            valid[upd_idx]      <= 1'b1;
            tag[upd_idx]        <= upd_tag;
            target[upd_idx]     <= upd_target;
            entry_type[upd_idx] <= upd_br_type;
        end
    end
endmodule