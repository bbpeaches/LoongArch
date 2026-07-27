module if_id_reg (
    input  wire        clk,
    input  wire        resetn,
    input  wire        stall,
    input  wire        flush,
    input  wire        if_valid,

    input  wire [31:0] if_pc,
    input  wire [31:0] if_inst,
    input  wire        if_pred_taken,
    input  wire [31:0] if_pred_target,
    input  wire [ 7:0] if_pred_ghr,

    output reg  [31:0] id_pc,
    output reg  [31:0] id_inst,
    output reg         id_valid,
    output reg         id_pred_taken,
    output reg  [31:0] id_pred_target,
    output reg  [ 7:0] id_pred_ghr
);
    always @(posedge clk) begin
        if (~resetn) begin
            id_pc          <= 32'd0;
            id_inst        <= 32'h03400000;
            id_valid       <= 1'b0;
            id_pred_taken  <= 1'b0;
            id_pred_target <= 32'd0;
            id_pred_ghr    <= 8'd0;
        end else if (flush) begin
            id_valid       <= 1'b0;
            id_pred_taken  <= 1'b0;
        end else if (stall) begin
            id_pc          <= id_pc;
            id_inst        <= id_inst;
            id_valid       <= id_valid;
            id_pred_taken  <= id_pred_taken;
            id_pred_target <= id_pred_target;
            id_pred_ghr    <= id_pred_ghr;
        end else if (if_valid) begin
            id_pc          <= if_pc;
            id_inst        <= if_inst;
            id_valid       <= 1'b1;
            id_pred_taken  <= if_pred_taken;
            id_pred_target <= if_pred_target;
            id_pred_ghr    <= if_pred_ghr;
        end else begin
            id_pc          <= 32'd0;
            id_inst        <= 32'h03400000;
            id_valid       <= 1'b0;
            id_pred_taken  <= 1'b0;
            id_pred_target <= 32'd0;
            id_pred_ghr    <= 8'd0;
        end
    end
endmodule
