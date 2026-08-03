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
    // The CPU observes a product two clocks after issue.  Registering the
    // operands first and the complete product next preserves that contract
    // while keeping a load-forwarded operand out of the DSP input setup path.
    reg [1:0] valid_pipe;
    reg signed [31:0] operand_a_pipe;
    reg signed [31:0] operand_b_pipe;
    (* use_dsp = "yes" *) reg signed [63:0] product_pipe;

    always @(posedge clk) begin
        if (~resetn) begin
            valid_pipe    <= 2'b00;
            operand_a_pipe <= 32'sd0;
            operand_b_pipe <= 32'sd0;
            product_pipe   <= 64'sd0;
        end else if (ce) begin
            operand_a_pipe <= x;
            operand_b_pipe <= y;
            product_pipe   <= operand_a_pipe * operand_b_pipe;
            valid_pipe     <= {valid_pipe[0], issue_valid};
        end
    end

    assign result = product_pipe[31:0];
    assign result_valid = valid_pipe[1];
endmodule
