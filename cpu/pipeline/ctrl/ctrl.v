module ctrl (
    input  wire       stall_from_id,
    input  wire       stall_from_if,
    input  wire       stall_from_mem,
    input  wire       flush_from_id,

    output wire [4:0] stall,
    output wire [4:0] flush
);
    assign stall = stall_from_mem ? 5'b00111 :
                   stall_from_if  ? 5'b00011 :
                   stall_from_id  ? 5'b00011 : 5'b00000;

    assign flush[0] = 1'b0;
    assign flush[1] = flush_from_id;
    assign flush[2] = (stall[1] && !stall[2]);
    assign flush[3] = (stall[2] && !stall[3]);
    assign flush[4] = (stall[3] && !stall[4]);

endmodule
