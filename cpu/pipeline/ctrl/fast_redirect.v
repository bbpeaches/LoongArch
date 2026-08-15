module fast_redirect (
    input  wire [7:0]  br_info_normal,
    input  wire        is_jirl,
    input  wire        pred_taken,
    input  wire [31:0] pred_target,
    input  wire [31:0] normal_target,
    input  wire        eq,
    input  wire        lt,
    input  wire        ltu,
    input  wire        valid,
    input  wire        stall,
    output wire        redirect
);
    wire inst_b     = br_info_normal[7];
    wire inst_beq   = br_info_normal[6];
    wire inst_bne   = br_info_normal[5];
    wire inst_blt   = br_info_normal[4];
    wire inst_bge   = br_info_normal[3];
    wire inst_bltu  = br_info_normal[2];
    wire inst_bgeu  = br_info_normal[1];
    wire is_bl      = br_info_normal[0];

    wire normal_taken = inst_b | is_bl |
                        (inst_beq  & eq) |
                        (inst_bne  & ~eq) |
                        (inst_blt  & lt) |
                        (inst_bge  & ~lt) |
                        (inst_bltu & ltu) |
                        (inst_bgeu & ~ltu);
    wire pred_wrong = (pred_taken != normal_taken) ||
                      (normal_taken && (normal_target != pred_target));

    assign redirect = !is_jirl && pred_wrong && valid && !stall;
endmodule
