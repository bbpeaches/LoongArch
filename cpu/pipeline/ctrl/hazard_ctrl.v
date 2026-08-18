module hazard_ctrl (
    input  wire        ex_valid_inst,
    input  wire        id_valid,    
    input  wire [31:0] id_inst,       
    
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
    // Check the architectural register fields directly to avoid waiting for
    // the full ID decode and register-address mux chain.  Immediate fields
    // can cause conservative extra stalls, but all true dependencies remain
    // covered before the instruction enters EX.
    wire dep_rj_raw = (ex_waddr != 5'd0) && (ex_waddr == id_inst[ 9: 5]);
    wire dep_rd_raw = (ex_waddr != 5'd0) && (ex_waddr == id_inst[ 4: 0]);
    wire dep_rk_raw = (ex_waddr != 5'd0) && (ex_waddr == id_inst[14:10]);
    wire ex_dep_hit = id_valid && (dep_rj_raw || dep_rd_raw || dep_rk_raw);

    wire id_is_store = (id_inst[31:22] == 10'b0010_1001_10) ||
                       (id_inst[31:22] == 10'b0010_1001_00);
    // The load result is captured for the following store's data bypass; a
    // dependence through the store base address still needs an interlock.
    wire load_dep_needs_stall = id_is_store ? dep_rj_raw : ex_dep_hit;
    wire normal_load_use = ex_mem_read && load_dep_needs_stall;

    wire mul_use_hazard  = ex_valid_inst && ex_is_mul && ex_dep_hit;

    wire stall_req_from_id = normal_load_use || mul_use_hazard;

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
