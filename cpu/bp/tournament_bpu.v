module tournament_bpu (
    input  wire        clk,
    input  wire        resetn,

    // --- 预测读取端口 ---
    input  wire [9:2]  pc,
    output wire        meta_taken, 
    output wire [ 7:0] fetch_ghr,

    // --- 训练更新端口 ---
    input  wire        upd_cond_en, 
    input  wire [9:2]  upd_pc,
    input  wire [ 7:0] upd_ghr,
    input  wire        upd_actually_taken
);
    reg  [ 1:0] bimodal_pht [0:255];
    reg  [ 7:0] ghr;
    reg  [ 1:0] gshare_pht  [0:255];
    reg  [ 1:0] chooser_pht [0:255];

    // 读取逻辑
    wire [ 7:0] fetch_pht_idx = pc[9:2];
    wire [ 7:0] fetch_gsh_idx = pc[9:2] ^ ghr;

    assign fetch_ghr = ghr;

    wire bimodal_taken = bimodal_pht[fetch_pht_idx][1];
    wire gshare_taken  = gshare_pht[fetch_gsh_idx][1];
    wire use_gshare    = chooser_pht[fetch_pht_idx][1];

    assign meta_taken  = use_gshare ? gshare_taken : bimodal_taken;

    // 更新逻辑
    wire [ 7:0] upd_pht_idx = upd_pc[9:2];
    wire [ 7:0] upd_gsh_idx = upd_pc[9:2] ^ upd_ghr;

    always @(posedge clk) begin
        if (~resetn) begin
            ghr <= 8'b0;
            
        end
        else if (upd_cond_en) begin
            if ( (bimodal_pht[upd_pht_idx][1] == upd_actually_taken) && (gshare_pht[upd_gsh_idx][1] != upd_actually_taken) ) begin
                if (chooser_pht[upd_pht_idx] != 2'b00) chooser_pht[upd_pht_idx] <= chooser_pht[upd_pht_idx] - 1;
            end
            else if ( (bimodal_pht[upd_pht_idx][1] != upd_actually_taken) && (gshare_pht[upd_gsh_idx][1] == upd_actually_taken) ) begin
                if (chooser_pht[upd_pht_idx] != 2'b11) chooser_pht[upd_pht_idx] <= chooser_pht[upd_pht_idx] + 1;
            end

            if (upd_actually_taken) begin
                if (bimodal_pht[upd_pht_idx] != 2'b11) bimodal_pht[upd_pht_idx] <= bimodal_pht[upd_pht_idx] + 1;
                if (gshare_pht[upd_gsh_idx] != 2'b11)  gshare_pht[upd_gsh_idx]  <= gshare_pht[upd_gsh_idx] + 1;
            end else begin
                if (bimodal_pht[upd_pht_idx] != 2'b00) bimodal_pht[upd_pht_idx] <= bimodal_pht[upd_pht_idx] - 1;
                if (gshare_pht[upd_gsh_idx] != 2'b00)  gshare_pht[upd_gsh_idx]  <= gshare_pht[upd_gsh_idx] - 1;
            end

            ghr <= {ghr[6:0], upd_actually_taken};
        end
    end
endmodule