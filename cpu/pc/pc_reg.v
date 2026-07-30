module pc_reg (
    input  wire        clk,
    input  wire        resetn,
    input  wire        stall_pc,
    input  wire        flush_pc,
    input  wire [31:0] next_pc,
    output reg  [31:0] pc
);
    always @(posedge clk) begin
        if (~resetn) begin
            pc <= 32'h1c00_0000;
        end
        else if (flush_pc) begin
            pc <= next_pc;
        end
        else if (stall_pc) begin
            pc <= pc;
        end
        else begin
            pc <= next_pc;
        end
    end
endmodule
