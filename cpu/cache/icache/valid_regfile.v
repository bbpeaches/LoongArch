module valid_regfile (
    input  wire       clk,
    input  wire       resetn,
    input  wire       r_en,
    input  wire [6:0] r_addr,
    output wire       r_v,
    input  wire       w_en,
    input  wire [6:0] w_addr,
    input  wire       w_v
);

    reg [127:0] valid_array;
    reg [6:0]   r_addr_reg;

    // 写操作与一拍全复位
    always @(posedge clk) begin
        if (~resetn) begin
            valid_array <= 128'b0; // 硬件复位时，一拍清零所有 Valid 位
        end else if (w_en) begin
            valid_array[w_addr] <= w_v;
        end
    end

    // 读地址打一拍，确保 Valid 的输出时序和上述 BRAM 完全对齐
    always @(posedge clk) begin
        if (r_en) begin
            r_addr_reg <= r_addr;
        end
    end

    assign r_v = valid_array[r_addr_reg];

endmodule