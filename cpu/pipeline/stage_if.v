module stage_if (
    input  wire        clk,
    input  wire        resetn,
    input  wire        stall_if,

    input  wire        id_pred_wrong,
    input  wire [31:0] id_correct_pc,

    input  wire        if_pred_taken,
    input  wire [31:0] if_pred_target,

    output wire        inst_sram_en,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] if_pc,
    output wire        if_req_fire
);
    wire [31:0] seq_pc = if_pc + 32'd4;

    wire [31:0] next_pc = id_pred_wrong ? id_correct_pc :
                          if_pred_taken ? if_pred_target : seq_pc;

    pc_reg _pc_reg (
        .clk(clk), 
        .resetn(resetn), 
        .stall_pc(stall_if), 
        .flush_pc(id_pred_wrong), 
        .next_pc(next_pc), 
        .pc(if_pc)
    );
    
    assign inst_sram_en   = resetn;
    assign inst_sram_addr = if_pc;
    assign if_req_fire    = resetn && !stall_if;

endmodule
