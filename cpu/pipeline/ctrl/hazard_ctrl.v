module hazard_ctrl (
    input  wire        clk,          
    input  wire        resetn,       
    input  wire        ex_valid_inst, 

    input  wire [ 4:0] id_rs1,
    input  wire [ 4:0] id_rs2,

    input  wire [ 4:0] ex_waddr,
    input  wire        ex_mem_read,
    input  wire        ex_is_mul,

    input  wire        ex_br_taken, // 从 EX 阶段传来的冲刷信号
    input  wire        if_wait,
    input  wire        mem_wait,

    output wire [ 4:0] stall,
    output wire [ 4:0] flush
);
    wire ex_dep_hit = (ex_waddr != 5'd0) &&
                      ((ex_waddr == id_rs1) || (ex_waddr == id_rs2));

    wire normal_load_use = ex_mem_read && ex_dep_hit;
    wire mul_use_hazard  = ex_is_mul && ex_dep_hit;

    wire stall_req_from_id = normal_load_use || mul_use_hazard;

    reg mul_stall_q;
    always @(posedge clk) begin
        if (~resetn) begin
            mul_stall_q <= 1'b0;
        end else if (mem_wait) begin
            // 如果遇到访存停顿，冻结状态机，等待访存结束
            mul_stall_q <= mul_stall_q; 
        end else if (ex_is_mul && ex_valid_inst && !mul_stall_q) begin
            // 第 1 个周期：检测到有效乘法，拉高状态寄存器，发起停顿
            mul_stall_q <= 1'b1;        
        end else begin
            // 第 2 个周期：运算完成，释放状态机
            mul_stall_q <= 1'b0;        
        end
    end
    
    // 生成 EX 级停顿信号
    wire stall_req_from_ex = ex_is_mul && ex_valid_inst && !mul_stall_q;

    ctrl _sys_ctrl (
        .stall_from_ex  (stall_req_from_ex), 
        .stall_from_id  (stall_req_from_id),
        .stall_from_if  (if_wait),
        .stall_from_mem (mem_wait),
        .flush_from_ex  (ex_br_taken),
        .stall          (stall),
        .flush          (flush)
    );
endmodule