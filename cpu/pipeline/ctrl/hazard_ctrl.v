module hazard_ctrl (
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

    ctrl _sys_ctrl (
        .stall_from_id  (stall_req_from_id),
        .stall_from_if  (if_wait),
        .stall_from_mem (mem_wait),
        .flush_from_ex  (ex_br_taken), // 改为由 EX 发起冲刷
        .stall          (stall),
        .flush          (flush)
    );
endmodule