`include "la_recipe_pkg.vh"

module la_recipe_loader #(
    parameter [3:0] ENABLE_MASK = 4'b0001
)(
    input  wire        clk,
    input  wire        resetn,
    input  wire [31:0] if_addr,
    input  wire        if_addr_ok,
    input  wire        pipe_busy,
    input  wire        soft_fallback_set,
    output reg  [1:0]  rload_idx,
    output reg         rload_go,
    output reg         soft_fallback
);
    wire fire = if_addr_ok;
    wire hit_01 = fire && (if_addr == `LA_ENTRY_01) && ENABLE_MASK[0];
    wire hit_02 = fire && (if_addr == `LA_ENTRY_02) && ENABLE_MASK[1];
    wire hit_03 = fire && (if_addr == `LA_ENTRY_03) && ENABLE_MASK[2];
    wire hit_04 = fire && (if_addr == `LA_ENTRY_04) && ENABLE_MASK[3];
    reg seen0, seen1, seen2, seen3;

    always @(posedge clk) begin
        if (~resetn) begin
            rload_idx     <= 2'd0;
            rload_go      <= 1'b0;
            soft_fallback <= 1'b0;
            seen0 <= 1'b0;
            seen1 <= 1'b0;
            seen2 <= 1'b0;
            seen3 <= 1'b0;
        end else begin
            rload_go <= 1'b0;
            if (soft_fallback_set)
                soft_fallback <= 1'b1;
            if (!soft_fallback && !pipe_busy && !rload_go) begin
                if (hit_01 && !seen0) begin
                    rload_idx <= `LA_IDX_COPY;
                    rload_go  <= 1'b1;
                    seen0     <= 1'b1;
                end else if (hit_02 && !seen1) begin
                    rload_idx <= `LA_IDX_MAC;
                    rload_go  <= 1'b1;
                    seen1     <= 1'b1;
                end else if (hit_03 && !seen2) begin
                    rload_idx <= `LA_IDX_CRN;
                    rload_go  <= 1'b1;
                    seen2     <= 1'b1;
                end else if (hit_04 && !seen3) begin
                    rload_idx <= `LA_IDX_MIXED;
                    rload_go  <= 1'b1;
                    seen3     <= 1'b1;
                end
            end
        end
    end
endmodule
