module if_id_reg (
    input  wire        clk, resetn,
    input  wire        stall, flush,
    input  wire        if_valid,
    input  wire [31:0] if_pc, if_inst,
    input  wire        if_pred_taken,
    input  wire [31:0] if_pred_target,
    input  wire [ 7:0] if_pred_ghr,

    output reg  [31:0] id_pc, id_inst,
    output reg         id_valid, id_pred_taken,
    output reg  [31:0] id_pred_target,
    output reg  [ 7:0] id_pred_ghr
);
    always @(posedge clk) begin
        if (~resetn) begin
            id_valid       <= 1'b0;
            id_pred_taken  <= 1'b0;
        end else if (flush) begin
            id_valid       <= 1'b0;
            id_pred_taken  <= 1'b0;
        end else if (stall) begin
            id_valid       <= id_valid;
            id_pred_taken  <= id_pred_taken;
        end else if (if_valid) begin
            id_valid       <= 1'b1;
            id_pred_taken  <= if_pred_taken;
        end else begin
            id_valid       <= 1'b0;
            id_pred_taken  <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (~resetn) begin
            id_pc          <= 32'd0;
            id_inst        <= 32'h03400000;
            id_pred_target <= 32'd0;
            id_pred_ghr    <= 8'd0;
        end else if (!stall) begin
            id_pc          <= if_valid ? if_pc          : 32'd0;
            id_inst        <= if_valid ? if_inst        : 32'h03400000;
            id_pred_target <= if_valid ? if_pred_target : 32'd0;
            id_pred_ghr    <= if_valid ? if_pred_ghr    : 8'd0;
        end
    end
endmodule
