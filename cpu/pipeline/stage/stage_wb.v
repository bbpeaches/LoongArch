module stage_wb (
    input  wire [31:0] wb_pc,
    input  wire        wb_rf_we,
    input  wire [ 4:0] wb_waddr,
    input  wire [31:0] wb_data,
    
    output wire [31:0] debug_wb_pc,
    output wire        debug_wb_rf_wen,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
    assign debug_wb_pc       = wb_pc;
    assign debug_wb_rf_wen   = wb_rf_we;
    assign debug_wb_rf_wnum  = wb_waddr;
    assign debug_wb_rf_wdata = wb_data;

endmodule