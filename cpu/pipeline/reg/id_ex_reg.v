module id_ex_reg (
    input  wire        clk, resetn, stall, flush,
    
    input  wire [31:0] id_pc,
    input  wire        id_rf_we,
    input  wire [ 4:0] id_waddr,
    input  wire [ 1:0] id_wb_sel,
    input  wire        id_mem_en, id_is_st_w, id_is_st_b, id_is_ld_b, id_is_ld_bu,
    input  wire [11:0] id_alu_op,
    input  wire [31:0] id_alu_src1, id_alu_src2, id_rdata2,
    
    input  wire [ 4:0] id_rs2,
    
    input  wire [11:0] id_br_info,
    input  wire        id_is_branch, id_pred_taken,
    input  wire [31:0] id_pred_target,
    input  wire [ 7:0] id_pred_ghr,
    input  wire        id_valid_inst,
    input  wire [31:0] id_normal_br_target, 

    output reg  [31:0] ex_pc,
    output reg         ex_rf_we,
    output reg  [ 4:0] ex_waddr,
    output reg  [ 1:0] ex_wb_sel,
    output reg         ex_mem_en, ex_is_st_w, ex_is_st_b, ex_is_ld_b, ex_is_ld_bu, 
    output reg  [11:0] ex_alu_op,
    output reg  [31:0] ex_alu_src1, ex_alu_src2, ex_rdata2,
    
    output reg  [ 4:0] ex_rs2, 
    
    output reg  [11:0] ex_br_info,
    output reg         ex_is_branch, ex_pred_taken,
    output reg  [31:0] ex_pred_target,
    output reg  [ 7:0] ex_pred_ghr,
    output reg         ex_valid_inst,
    output reg  [31:0] ex_normal_br_target  
);
    always @(posedge clk) begin
        if (~resetn) begin
            ex_rf_we      <= 1'b0;  ex_mem_en     <= 1'b0;
            ex_is_st_w    <= 1'b0;  ex_is_st_b    <= 1'b0;
            ex_is_ld_b    <= 1'b0;  ex_is_ld_bu   <= 1'b0;
            ex_is_branch  <= 1'b0;  ex_pred_taken <= 1'b0;
            ex_valid_inst <= 1'b0;
        end else if (flush) begin
            ex_rf_we      <= 1'b0;  ex_mem_en     <= 1'b0;
            ex_is_st_w    <= 1'b0;  ex_is_st_b    <= 1'b0;
            ex_is_ld_b    <= 1'b0;  ex_is_ld_bu   <= 1'b0;
            ex_is_branch  <= 1'b0;  ex_pred_taken <= 1'b0;
            ex_valid_inst <= 1'b0; 
        end else if (!stall) begin
            ex_rf_we      <= id_rf_we;      ex_mem_en     <= id_mem_en;
            ex_is_st_w    <= id_is_st_w;    ex_is_st_b    <= id_is_st_b;
            ex_is_ld_b    <= id_is_ld_b;    ex_is_ld_bu   <= id_is_ld_bu; 
            ex_is_branch  <= id_is_branch;  ex_pred_taken <= id_pred_taken;
            ex_valid_inst <= id_valid_inst;
        end
    end

    always @(posedge clk) begin
        if (~resetn) begin
            ex_pc <= 32'd0; ex_waddr <= 5'd0; ex_wb_sel <= 2'd0; ex_alu_op <= 12'd0;
            ex_alu_src1 <= 32'd0; ex_alu_src2 <= 32'd0; ex_rdata2 <= 32'd0; ex_rs2 <= 5'd0;
            ex_br_info <= 12'd0; ex_pred_target <= 32'd0; 
            ex_pred_ghr <= 8'd0; ex_normal_br_target <= 32'd0;
        end else if (!stall) begin
            ex_pc <= id_pc; ex_waddr <= id_waddr; ex_wb_sel <= id_wb_sel; ex_alu_op <= id_alu_op;
            ex_alu_src1 <= id_alu_src1; ex_alu_src2 <= id_alu_src2; ex_rdata2 <= id_rdata2; ex_rs2 <= id_rs2;
            ex_br_info <= id_br_info; ex_pred_target <= id_pred_target; 
            ex_pred_ghr <= id_pred_ghr; ex_normal_br_target <= id_normal_br_target; 
        end
    end
endmodule
