module stage_mem (
    input  wire [ 1:0] mem_wb_sel,
    input  wire        mem_is_ld_b,
    input  wire        mem_is_ld_bu,
    input  wire [ 1:0] mem_addr_align,
    input  wire [31:0] mem_result,
    input  wire        mem_valid,

    input  wire [31:0] data_sram_rdata,
    input  wire        data_sram_resp_valid,

    output wire [31:0] mem_final_data,
    output wire        mem_done,
    output wire        mem_wait
);
    wire [ 7:0] lb_data = (mem_addr_align == 2'b00) ? data_sram_rdata[ 7:0] :
                          (mem_addr_align == 2'b01) ? data_sram_rdata[15:8] :
                          (mem_addr_align == 2'b10) ? data_sram_rdata[23:16] :
                                                      data_sram_rdata[31:24];

    wire mem_is_load = (mem_wb_sel == 2'b01);
    wire [31:0] mem_ram_rdata = mem_is_ld_b  ? {{24{lb_data[7]}}, lb_data} : 
                                mem_is_ld_bu ? {24'd0, lb_data}            : 
                                data_sram_rdata;

    assign mem_done       = !mem_valid || !mem_is_load || data_sram_resp_valid;
    assign mem_wait       = mem_valid && mem_is_load && !data_sram_resp_valid;
    assign mem_final_data = mem_is_load ? mem_ram_rdata : mem_result;

endmodule