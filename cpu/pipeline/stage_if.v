module stage_if (
    input  wire        clk,
    input  wire        resetn,
    input  wire        stall_if,

    input  wire        id_pred_wrong,
    input  wire [31:0] id_correct_pc,

    input  wire        if_pred_taken,
    input  wire [31:0] if_pred_target,

    input  wire        pipe_hold,
    input  wire        pipe_retarget_en,
    input  wire [31:0] pipe_retarget_pc,

    output wire        inst_sram_en,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] if_pc,
    output wire        if_req_fire
);
    wire [31:0] seq_pc = if_pc + 32'd4;

    wire [31:0] next_pc = pipe_retarget_en ? pipe_retarget_pc :
                          id_pred_wrong    ? id_correct_pc    :
                          if_pred_taken    ? if_pred_target   : seq_pc;

    wire flush_pc = pipe_retarget_en | id_pred_wrong;
    wire stall_pc = (stall_if | pipe_hold) & ~flush_pc;

    pc_reg _pc_reg (
        .clk(clk),
        .resetn(resetn),
        .stall_pc(stall_pc),
        .flush_pc(flush_pc),
        .next_pc(next_pc),
        .pc(if_pc)
    );

    assign inst_sram_en   = resetn & ~pipe_hold;
    assign inst_sram_addr = if_pc;
    assign if_req_fire    = resetn && !stall_if && !pipe_hold;

endmodule
