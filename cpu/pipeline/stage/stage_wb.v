module stage_wb (
    input  wire        wb_rf_we_i,
    input  wire [ 4:0] wb_waddr_i,
    input  wire [31:0] wb_data_i,

    output wire        wb_rf_we,
    output wire [ 4:0] wb_waddr,
    output wire [31:0] wb_data
);
    assign wb_rf_we = wb_rf_we_i;
    assign wb_waddr = wb_waddr_i;
    assign wb_data  = wb_data_i;
endmodule
