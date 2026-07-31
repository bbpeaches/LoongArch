module tournament_bpu (
    input  wire        clk,
    input  wire        resetn,

    // --- 单级预测读取端口 ---
    input  wire [9:2]  pc,
    output wire        meta_taken,
    output wire [7:0]  fetch_ghr,

    // --- 训练更新端口 ---
    input  wire        upd_cond_en,
    input  wire [9:2]  upd_pc,
    input  wire [7:0]  upd_ghr,
    input  wire        upd_actually_taken
);
    // 256-entry bimodal/gshare/chooser tables.  The counters are LUTRAM;
    // valid maps make unread entries deterministic weak-not-taken after reset.
    reg  [1:0] bimodal_pht [0:255];
    reg  [7:0] ghr;
    reg  [1:0] gshare_pht  [0:255];
    reg  [1:0] chooser_pht [0:255];
    reg  [255:0] pc_pht_valid;
    reg  [255:0] gshare_pht_valid;

    wire [7:0] fetch_pht_idx = pc[9:2];
    wire [7:0] fetch_gsh_idx = pc[9:2] ^ ghr;

    assign fetch_ghr = ghr;

    wire [1:0] bimodal_count = pc_pht_valid[fetch_pht_idx] ?
                                bimodal_pht[fetch_pht_idx] : 2'b01;
    wire [1:0] gshare_count  = gshare_pht_valid[fetch_gsh_idx] ?
                                gshare_pht[fetch_gsh_idx] : 2'b01;
    wire [1:0] chooser_count = pc_pht_valid[fetch_pht_idx] ?
                                chooser_pht[fetch_pht_idx] : 2'b01;
    wire bimodal_taken = bimodal_count[1];
    wire gshare_taken  = gshare_count[1];
    wire use_gshare    = chooser_count[1];

    assign meta_taken = use_gshare ? gshare_taken : bimodal_taken;

    wire [7:0] upd_pht_idx = upd_pc[9:2];
    wire [7:0] upd_gsh_idx = upd_pc[9:2] ^ upd_ghr;

    wire upd_bimodal_taken = pc_pht_valid[upd_pht_idx] ?
                              bimodal_pht[upd_pht_idx][1] : 1'b0;
    wire upd_gshare_taken  = gshare_pht_valid[upd_gsh_idx] ?
                              gshare_pht[upd_gsh_idx][1] : 1'b0;

    always @(posedge clk) begin
        if (~resetn) begin
            ghr <= 8'b0;
            pc_pht_valid     <= 256'b0;
            gshare_pht_valid <= 256'b0;
        end else if (upd_cond_en) begin
            if (!pc_pht_valid[upd_pht_idx]) begin
                pc_pht_valid[upd_pht_idx] <= 1'b1;
                bimodal_pht[upd_pht_idx]  <= upd_actually_taken ? 2'b10 : 2'b00;
                chooser_pht[upd_pht_idx]  <= 2'b01;
            end else begin
                if ((upd_bimodal_taken == upd_actually_taken) &&
                    (upd_gshare_taken != upd_actually_taken)) begin
                    if (chooser_pht[upd_pht_idx] != 2'b00)
                        chooser_pht[upd_pht_idx] <= chooser_pht[upd_pht_idx] - 1'b1;
                end else if ((upd_bimodal_taken != upd_actually_taken) &&
                             (upd_gshare_taken == upd_actually_taken)) begin
                    if (chooser_pht[upd_pht_idx] != 2'b11)
                        chooser_pht[upd_pht_idx] <= chooser_pht[upd_pht_idx] + 1'b1;
                end

                if (upd_actually_taken) begin
                    if (bimodal_pht[upd_pht_idx] != 2'b11)
                        bimodal_pht[upd_pht_idx] <= bimodal_pht[upd_pht_idx] + 1'b1;
                end else if (bimodal_pht[upd_pht_idx] != 2'b00) begin
                    bimodal_pht[upd_pht_idx] <= bimodal_pht[upd_pht_idx] - 1'b1;
                end
            end

            if (!gshare_pht_valid[upd_gsh_idx]) begin
                gshare_pht_valid[upd_gsh_idx] <= 1'b1;
                gshare_pht[upd_gsh_idx] <= upd_actually_taken ? 2'b10 : 2'b00;
            end else if (upd_actually_taken) begin
                if (gshare_pht[upd_gsh_idx] != 2'b11)
                    gshare_pht[upd_gsh_idx] <= gshare_pht[upd_gsh_idx] + 1'b1;
            end else if (gshare_pht[upd_gsh_idx] != 2'b00) begin
                gshare_pht[upd_gsh_idx] <= gshare_pht[upd_gsh_idx] - 1'b1;
            end

            ghr <= {ghr[6:0], upd_actually_taken};
        end
    end
endmodule
