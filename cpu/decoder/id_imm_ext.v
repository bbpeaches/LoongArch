module id_imm_ext (
    input  wire [25:0] inst,
    input  wire        inst_ld_w,
    input  wire        inst_st_w,
    input  wire        inst_addi_w,
    input  wire        inst_slti,
    input  wire        inst_ori,
    input  wire        inst_b,
    input  wire        inst_beq,
    input  wire        inst_bne,
    input  wire        inst_lu12i_w,
    input  wire        inst_slli_w,
    output reg  [31:0] imm_32
);
    always @(*) begin
        if (inst_ori) begin
            imm_32 = {20'b0, inst[21:10]};
        end
        else if (inst_addi_w | inst_ld_w | inst_st_w | inst_slti) begin
            imm_32 = {{20{inst[21]}}, inst[21:10]};
        end
        else if (inst_beq | inst_bne) begin 
            imm_32 = {{14{inst[25]}}, inst[25:10], 2'b00};
        end
        else if (inst_b) begin 
            imm_32 = {{4{inst[9]}}, inst[9:0], inst[25:10], 2'b00};
        end
        else if (inst_lu12i_w) begin 
            imm_32 = {inst[24:5], 12'b0};
        end
        else if (inst_slli_w) begin
            imm_32 = {27'b0, inst[14:10]};
        end
        else begin
            imm_32 = 32'b0;
        end
    end
endmodule