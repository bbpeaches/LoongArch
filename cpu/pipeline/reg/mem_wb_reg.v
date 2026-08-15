module mem_wb_reg (
    input  wire        clk, resetn, stall, flush,

    input  wire        mem_rf_we,
    input  wire [ 4:0] mem_waddr,
    input  wire [31:0] mem_final_data,
    input  wire        mem_done,

    output reg         wb_rf_we,
    output reg  [ 4:0] wb_waddr,
    output reg  [31:0] wb_data
);
    always @(posedge clk) begin
        if (~resetn) begin
            wb_rf_we <= 1'b0;
        end else if (flush) begin
            wb_rf_we <= 1'b0;
        end else if (!stall) begin
            wb_rf_we <= mem_done ? mem_rf_we : 1'b0;
        end
    end

    always @(posedge clk) begin
        if (~resetn) begin
            wb_waddr <= 5'd0; wb_data <= 32'd0;
        end else if (!stall) begin
            wb_waddr <= mem_waddr;
            wb_data <= mem_final_data;
        end
    end
endmodule
