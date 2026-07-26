module stage_ex (
    input  wire        clk,
    input  wire        resetn,
    // --- 上游输入 (来自 ID/EX 寄存器) ---
    input  wire [31:0] ex_pc,
    input  wire [ 1:0] ex_wb_sel,
    input  wire        ex_mem_en,
    input  wire        ex_is_st_w,
    input  wire        ex_is_st_b,
    input  wire [11:0] ex_alu_op,
    input  wire [31:0] ex_alu_src1,
    input  wire [31:0] ex_alu_src2,
    input  wire [31:0] ex_rdata2,

    // --- 传给 EX/MEM 寄存器的输出 ---
    output wire [31:0] ex_result,
    output wire [31:0] ex_mul_result,
    output wire [ 1:0] ex_addr_align,

    // --- 传给外部 Data SRAM 的输出 ---
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_wen,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,

    // --- 传给 Hazard 的状态输出 ---
    output wire        ex_mem_read
);
    wire [31:0] ex_alu_result;

    alu_top _alu_top (
        .alu_op(ex_alu_op), .alu_src1(ex_alu_src1), .alu_src2(ex_alu_src2), .alu_result(ex_alu_result)
    );

    mul_top _mul_top (
        .clk(clk),
        .resetn(resetn),
        .x(ex_alu_src1),
        .y(ex_alu_src2),
        .result(ex_mul_result)
    );

    assign ex_result = (ex_wb_sel == 2'b11) ? (ex_pc + 32'd4) : ex_alu_result;

    assign ex_addr_align = ex_alu_result[1:0];
    wire [3:0] ex_st_b_we = 4'b0001 << ex_addr_align;

    assign data_sram_en    = ex_mem_en;
    assign data_sram_wen   = ex_is_st_w ? 4'b1111 :
                             ex_is_st_b ? ex_st_b_we : 4'b0000;
    assign data_sram_addr  = ex_alu_result;
    assign data_sram_wdata = ex_is_st_b ? {4{ex_rdata2[7:0]}} : ex_rdata2;

    assign ex_mem_read = ex_mem_en && (data_sram_wen == 4'b0000);

endmodule