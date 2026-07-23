module id_ex_reg (
    input  wire        clk, resetn,
    input  wire        stall,
    input  wire        flush,

    input  wire [31:0] id_pc,
    input  wire        id_rf_we,
    input  wire [ 4:0] id_waddr,
    input  wire [ 1:0] id_wb_sel,
    input  wire        id_mem_en,
    input  wire        id_is_st_w, id_is_st_b, id_is_ld_b, id_is_ld_bu,
    input  wire [11:0] id_alu_op,
    input  wire [31:0] id_alu_src1, id_alu_src2, id_rdata2,

    output reg  [31:0] ex_pc,
    output reg         ex_rf_we,
    output reg  [ 4:0] ex_waddr,
    output reg  [ 1:0] ex_wb_sel,
    output reg         ex_mem_en,
    output reg         ex_is_st_w, ex_is_st_b, ex_is_ld_b, ex_is_ld_bu, 
    output reg  [11:0] ex_alu_op,
    output reg  [31:0] ex_alu_src1, ex_alu_src2, ex_rdata2
);
    always @(posedge clk) begin
        if (~resetn || flush) begin
            ex_pc <= 32'd0;       ex_rf_we <= 1'b0;      ex_waddr <= 5'd0;
            ex_wb_sel <= 2'd0;    ex_mem_en <= 1'b0;
            ex_is_st_w <= 1'b0;   ex_is_st_b <= 1'b0;    ex_is_ld_b <= 1'b0; ex_is_ld_bu <= 1'b0;
            ex_alu_op <= 12'd0;   ex_alu_src1 <= 32'd0;  ex_alu_src2 <= 32'd0; ex_rdata2 <= 32'd0;
        end else if (!stall) begin
            ex_pc <= id_pc;       ex_rf_we <= id_rf_we;  ex_waddr <= id_waddr;
            ex_wb_sel <= id_wb_sel; ex_mem_en <= id_mem_en;
            ex_is_st_w <= id_is_st_w; ex_is_st_b <= id_is_st_b; ex_is_ld_b <= id_is_ld_b; ex_is_ld_bu <= id_is_ld_bu; 
            ex_alu_op <= id_alu_op; ex_alu_src1 <= id_alu_src1; ex_alu_src2 <= id_alu_src2; ex_rdata2 <= id_rdata2;
        end
    end
endmodule