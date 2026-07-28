module hazard_ctrl (
    input  wire        clk,
    input  wire        resetn,
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
    
    output wire [ 4:0] stall,
    output wire [ 4:0] flush
);
    wire dep_rs1_raw   = (ex_waddr != 5'd0) && (ex_waddr == id_inst[9:5]);
    wire dep_rs2_14_10 = (ex_waddr != 5'd0) && (ex_waddr == id_inst[14:10]);
    wire dep_rs2_4_0   = (ex_waddr != 5'd0) && (ex_waddr == id_inst[4:0]);

    wire fast_dest_is_raddr2 = (id_inst[31:26] == 6'b0101_10) | // beq
                               (id_inst[31:26] == 6'b0101_11) | // bne
                               (id_inst[31:26] == 6'b0110_00) | // blt
                               (id_inst[31:26] == 6'b0110_01) | // bge
                               (id_inst[31:26] == 6'b0110_10) | // bltu
                               (id_inst[31:26] == 6'b0110_11) | // bgeu
                               (id_inst[31:22] == 10'b0010_1001_10) | // st.w
                               (id_inst[31:22] == 10'b0010_1001_00);  // st.b

    wire dep_rs2_raw = fast_dest_is_raddr2 ? dep_rs2_4_0 : dep_rs2_14_10;

    wire ex_dep_hit = id_valid && (dep_rs1_raw || dep_rs2_raw);

    wire is_store = (id_inst[31:22] == 10'b0010_1001_10) | (id_inst[31:22] == 10'b0010_1001_00);
    wire store_data_dep = is_store && !dep_rs1_raw && dep_rs2_raw;
    wire normal_load_use = ex_mem_read && ex_dep_hit && !store_data_dep;

    wire mul_use_hazard  = ex_is_mul && ex_dep_hit;

    (* max_fanout = 8 *) wire stall_req_from_id = normal_load_use || mul_use_hazard;

    reg mul_stall_q;
    always @(posedge clk) begin
        if (~resetn) begin
            mul_stall_q <= 1'b0;
        end else if (mem_wait) begin
            mul_stall_q <= mul_stall_q; 
        end else if (ex_is_mul && ex_valid_inst && !mul_stall_q) begin
            mul_stall_q <= 1'b1;        
        end else begin
            mul_stall_q <= 1'b0;        
        end
    end
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