module ex_mem_reg (
    input  wire        clk, resetn, stall, flush,

    input  wire        ex_rf_we,
    input  wire [ 4:0] ex_waddr,
    input  wire [ 1:0] ex_wb_sel,
    input  wire        ex_is_ld_b, ex_is_ld_bu,
    input  wire [ 1:0] ex_addr_align,
    input  wire [31:0] ex_result,
    input  wire        ex_valid_inst,

    output reg         mem_rf_we,
    output reg  [ 4:0] mem_waddr,
    output reg  [ 1:0] mem_wb_sel,
    output reg         mem_is_ld_b, mem_is_ld_bu,
    output reg  [ 1:0] mem_addr_align,
    output reg  [31:0] mem_result,
    output reg         mem_valid
);
    always @(posedge clk) begin
        if (~resetn) begin
            mem_valid <= 1'b0;
            mem_rf_we <= 1'b0;
        end else if (flush) begin
            mem_valid <= 1'b0;
            mem_rf_we <= 1'b0;
        end else if (!stall) begin
            mem_valid <= ex_valid_inst;
            mem_rf_we <= ex_rf_we;
        end
    end

    always @(posedge clk) begin
        if (~resetn) begin
            mem_waddr <= 5'd0; mem_wb_sel <= 2'd0;
            mem_is_ld_b <= 1'b0; mem_is_ld_bu <= 1'b0; 
            mem_addr_align <= 2'b00; mem_result <= 32'd0;
        end else if (flush) begin
            mem_waddr  <= 5'd0;
            mem_wb_sel <= 2'd0;
            mem_is_ld_b  <= 1'b0;
            mem_is_ld_bu <= 1'b0;
        end else if (!stall) begin
            mem_waddr <= ex_waddr; mem_wb_sel <= ex_wb_sel;
            mem_is_ld_b <= ex_is_ld_b; mem_is_ld_bu <= ex_is_ld_bu; 
            mem_addr_align <= ex_addr_align; mem_result <= ex_result;
        end
    end
endmodule
