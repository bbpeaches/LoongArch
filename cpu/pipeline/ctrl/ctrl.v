module ctrl (
    input  wire        stall_from_ex,
    input  wire        stall_from_id,
    input  wire        stall_from_if,
    input  wire        stall_from_mem,
    input  wire        stall_from_mem_stage,
    input  wire        flush_from_ex,

    output wire [4:0] stall,
    output wire [4:0] flush
);
    assign stall = stall_from_mem_stage ? 5'b01111 :
                   stall_from_mem ? 5'b00111 :
                   stall_from_ex  ? 5'b00111 :
                   stall_from_id  ? 5'b00011 :
                   stall_from_if  ? 5'b00001 : 5'b00000;

    assign flush[0] = 1'b0;
    assign flush[1] = flush_from_ex; 
    
    (* max_fanout = 8 *) wire flush_2_opt = flush_from_ex || (stall[1] && !stall[2]);
    assign flush[2] = flush_2_opt; 
    
    assign flush[3] = (stall[2] && !stall[3]);
    assign flush[4] = (stall[3] && !stall[4]);

endmodule
