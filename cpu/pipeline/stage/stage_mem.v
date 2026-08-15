module stage_mem (
    input  wire [ 1:0] mem_wb_sel,
    input  wire        mem_rf_we,
    input  wire        mem_is_ld_b,
    input  wire        mem_is_ld_bu,
    input  wire [ 1:0] mem_addr_align,
    input  wire [31:0] mem_result,
    input  wire [31:0] mem_mul_result,
    input  wire        mem_valid,

    input  wire [31:0] data_sram_rdata,
    input  wire        data_sram_resp_valid,
    input  wire        mul_result_valid,

    output wire [31:0] mem_final_data,
    output wire        mem_done,
    output wire        mem_wait
);
    wire mem_is_load = mem_valid && mem_rf_we && (mem_wb_sel == 2'b01);
    wire mem_is_mul  = mem_valid && mem_rf_we && (mem_wb_sel == 2'b10);
    wire [31:0] mem_ram_rdata = data_sram_rdata;

    assign mem_done       = !mem_valid ||
                            (!mem_is_load && !mem_is_mul) ||
                            (mem_is_load && data_sram_resp_valid) ||
                            (mem_is_mul && mul_result_valid);
    assign mem_wait       = mem_valid &&
                            ((mem_is_load && !data_sram_resp_valid) ||
                             (mem_is_mul  && !mul_result_valid));
    assign mem_final_data = mem_is_load ? mem_ram_rdata :
                            mem_is_mul  ? mem_mul_result : mem_result;

endmodule
