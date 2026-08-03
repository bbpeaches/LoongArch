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
    wire [ 7:0] lb_data = (mem_addr_align == 2'b00) ? data_sram_rdata[ 7:0] :
                          (mem_addr_align == 2'b01) ? data_sram_rdata[15:8] :
                          (mem_addr_align == 2'b10) ? data_sram_rdata[23:16] :
                                                      data_sram_rdata[31:24];

    // Require a real completing op: bubbles may still carry a stale wb_sel.
    wire mem_is_load = mem_valid && mem_rf_we && (mem_wb_sel == 2'b01);
    wire mem_is_mul  = mem_valid && mem_rf_we && (mem_wb_sel == 2'b10);
    wire [31:0] mem_ram_rdata = mem_is_ld_b  ? {{24{lb_data[7]}}, lb_data} :
                                mem_is_ld_bu ? {24'd0, lb_data}            :
                                data_sram_rdata;

    // Loads and multiplies are the two result-producing operations that can
    // wait in MEM.  The multiply response is explicit rather than inferred
    // from a fixed number of pipeline cycles.
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
