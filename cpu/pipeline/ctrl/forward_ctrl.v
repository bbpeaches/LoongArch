module forward_ctrl (
    input  wire [ 4:0] id_rs1,
    input  wire [ 4:0] id_rs2,

    input  wire        ex_we,
    input  wire [ 4:0] ex_waddr,
    input  wire [31:0] ex_fw_data,  

    input  wire        mem_we,
    input  wire [ 4:0] mem_waddr,
    input  wire [31:0] mem_fw_data, 

    input  wire        wb_we,
    input  wire [ 4:0] wb_waddr,
    input  wire [31:0] wb_fw_data, 

    input  wire [31:0] rf_rdata1,
    input  wire [31:0] rf_rdata2,

    output wire [31:0] id_fwd_rdata1,
    output wire [31:0] id_fwd_rdata2
);

    assign id_fwd_rdata1 = 
        (ex_we  && (ex_waddr != 5'd0)  && (ex_waddr == id_rs1)) ? ex_fw_data  :
        (mem_we && (mem_waddr != 5'd0) && (mem_waddr == id_rs1)) ? mem_fw_data :
        (wb_we  && (wb_waddr != 5'd0)  && (wb_waddr == id_rs1)) ? wb_fw_data  :
        rf_rdata1;

    assign id_fwd_rdata2 = 
        (ex_we  && (ex_waddr != 5'd0)  && (ex_waddr == id_rs2)) ? ex_fw_data  :
        (mem_we && (mem_waddr != 5'd0) && (mem_waddr == id_rs2)) ? mem_fw_data :
        (wb_we  && (wb_waddr != 5'd0)  && (wb_waddr == id_rs2)) ? wb_fw_data  :
        rf_rdata2;

endmodule