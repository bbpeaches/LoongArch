module pc_reg (
    input  wire        clk,
    input  wire        resetn, 
    input  wire        stall_pc,
    input  wire        flush_pc,   // <--- 新增：强行冲刷PC更新使能
    input  wire [31:0] next_pc, 
    output reg  [31:0] pc        
);
    always @(posedge clk) begin
        if (~resetn) begin
            pc <= 32'h1c00_0000;
        end 
        else if (flush_pc) begin   // <--- 最高优先级：遇到分支预测错误，无视Stall强行跳转！
            pc <= next_pc;
        end
        else if (stall_pc) begin
            pc <= pc;              // 遇到冲突，PC 保持当前值不变
        end 
        else begin
            pc <= next_pc;         // 正常流动
        end
    end
endmodule