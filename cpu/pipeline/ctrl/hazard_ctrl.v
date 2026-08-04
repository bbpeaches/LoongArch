module hazard_ctrl (
    input  wire        ex_valid_inst,
    input  wire        id_valid,    
    input  wire [31:0] id_inst,       
    
    input  wire [ 4:0] id_rs1,
    input  wire [ 4:0] id_rs2,
    input  wire [ 4:0] ex_waddr,
    input  wire        ex_mem_read,
    input  wire        ex_is_mul,
    
    input  wire        ex_br_taken, 
    input  wire        if_wait,  
    input  wire        mem_wait,
    input  wire        mem_stage_wait,
    
    output wire [ 4:0] stall,
    output wire [ 4:0] flush
);
    wire dep_rs1_raw = (ex_waddr != 5'd0) && (ex_waddr == id_rs1);
    wire dep_rs2_raw = (ex_waddr != 5'd0) && (ex_waddr == id_rs2);

    wire ex_dep_hit = id_valid && (dep_rs1_raw || dep_rs2_raw);

    wire is_store = (id_inst[31:22] == 10'b0010_1001_10) | (id_inst[31:22] == 10'b0010_1001_00);
    wire store_data_dep = is_store && !dep_rs1_raw && dep_rs2_raw;
    wire normal_load_use = ex_mem_read && ex_dep_hit && !store_data_dep;

    wire mul_use_hazard  = ex_valid_inst && ex_is_mul && ex_dep_hit;

    (* max_fanout = 8 *) wire stall_req_from_id = normal_load_use || mul_use_hazard;

    ctrl _sys_ctrl (
        .stall_from_ex  (1'b0),
        .stall_from_id  (stall_req_from_id),
        .stall_from_if  (if_wait),
        .stall_from_mem (mem_wait),
        .stall_from_mem_stage (mem_stage_wait),
        .flush_from_ex  (ex_br_taken), 
        .stall          (stall),
        .flush          (flush)
    );

endmodule
