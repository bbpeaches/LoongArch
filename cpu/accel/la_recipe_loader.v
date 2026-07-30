`include "la_recipe_pkg.vh"

// CPU-domain arming via exact I-fetch entry PC (official UTEST entries).
// Phase 1: ENABLE_MASK bit0 only → STREAM. Never drives hold (CDC owns hold).
module la_recipe_loader #(
    parameter [3:0] ENABLE_MASK = 4'b0001  // {MIXED,CRN,MAC,STREAM}
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
    // Official UTEST entry PCs (supervisor map).
    localparam [31:0] PC_STREAM = 32'h1c002008;
    localparam [31:0] PC_MATRIX = 32'h1c002030;
    localparam [31:0] PC_CRN    = 32'h1c0020f0;
    localparam [31:0] PC_MIXED  = 32'h1c002184;

    wire fire = if_addr_ok;

    wire hit_stream = fire && (if_addr == PC_STREAM) && ENABLE_MASK[0];
    wire hit_mac    = fire && (if_addr == PC_MATRIX) && ENABLE_MASK[1];
    wire hit_crn    = fire && (if_addr == PC_CRN)    && ENABLE_MASK[2];
    wire hit_mixed  = fire && (if_addr == PC_MIXED)  && ENABLE_MASK[3];

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
                if (hit_stream && !seen0) begin
                    rload_idx <= `LA_IDX_COPY;
                    rload_go  <= 1'b1;
                    seen0     <= 1'b1;
                end else if (hit_mac && !seen1) begin
                    rload_idx <= `LA_IDX_MAC;
                    rload_go  <= 1'b1;
                    seen1     <= 1'b1;
                end else if (hit_crn && !seen2) begin
                    rload_idx <= `LA_IDX_CRN;
                    rload_go  <= 1'b1;
                    seen2     <= 1'b1;
                end else if (hit_mixed && !seen3) begin
                    rload_idx <= `LA_IDX_MIXED;
                    rload_go  <= 1'b1;
                    seen3     <= 1'b1;
                end
            end
        end
    end
endmodule
