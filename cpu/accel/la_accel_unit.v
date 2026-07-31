`include "la_recipe_pkg.vh"

module la_accel_unit #(
    parameter [3:0] ENABLE_MASK = 4'b1111
)(
    input  wire        clk_cpu,
    input  wire        resetn_cpu,
    input  wire        clk_sram,
    input  wire        resetn_sram,
    input  wire [31:0] if_addr,
    input  wire        if_addr_ok,
    input  wire        soft_idle,
    output wire        pipe_hold,
    output wire        pipe_retarget_en,
    output wire [31:0] pipe_retarget_pc,
    output wire        pipe_go,
    output wire [1:0]  pipe_idx,
    input  wire        pipe_busy_s,
    input  wire        pipe_done_s,
    input  wire        pipe_giveup_s,
    input  wire [31:0] pipe_retarget_pc_s
);
    wire [1:0]  rload_idx;
    wire        rload_go;
    wire        soft_fallback;
    wire        pipe_busy_c;
    wire        soft_fallback_set;

    la_recipe_loader #(
        .ENABLE_MASK(ENABLE_MASK)
    ) u_rload (
        .clk(clk_cpu), .resetn(resetn_cpu),
        .if_addr(if_addr), .if_addr_ok(if_addr_ok),
        .pipe_busy(pipe_busy_c),
        .soft_fallback_set(soft_fallback_set),
        .rload_idx(rload_idx), .rload_go(rload_go),
        .soft_fallback(soft_fallback)
    );

    la_pipe_cdc u_pipe_cdc (
        .clk_cpu(clk_cpu), .resetn_cpu(resetn_cpu),
        .clk_sram(clk_sram), .resetn_sram(resetn_sram),
        .rload_go(rload_go && !soft_fallback), .rload_idx(rload_idx),
        .soft_idle(soft_idle),
        .pipe_go(pipe_go), .pipe_idx(pipe_idx),
        .pipe_busy_s(pipe_busy_s), .pipe_done_s(pipe_done_s),
        .pipe_retarget_pc_s(pipe_retarget_pc_s), .pipe_giveup_s(pipe_giveup_s),
        .pipe_hold(pipe_hold), .pipe_retarget_en(pipe_retarget_en),
        .pipe_retarget_pc(pipe_retarget_pc), .pipe_busy_c(pipe_busy_c),
        .soft_fallback_set(soft_fallback_set)
    );
endmodule
