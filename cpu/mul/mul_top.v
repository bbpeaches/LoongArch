module mul_top (
    input  wire        clk, 
    input  wire        ce,   
    input  wire        resetn,
    input  wire        issue_valid,
    input  wire [31:0] x,   
    input  wire [31:0] y,   
    output wire [31:0] result,
    output wire        result_valid
);
    // Keep this shift register in lockstep with the configured Mult Gen
    // latency.  The IP has C_LATENCY = 2.  It has no reset input, so the
    // valid pipeline also prevents pre-reset contents from being observed.
    reg [1:0] valid_pipe;

    always @(posedge clk) begin
        if (~resetn) begin
            valid_pipe <= 2'b00;
        end else if (ce) begin
            valid_pipe <= {valid_pipe[0], issue_valid};
        end
    end

    wire [63:0] mult_result_full;
    mult_gen_0 u_mult (
        .CLK (clk),
        .CE  (ce),    
        .A   (x),
        .B   (y),
        .P   (mult_result_full)
    );
    assign result = mult_result_full[31:0];
    assign result_valid = valid_pipe[1];
endmodule
