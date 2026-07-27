module valid_regfile (
    input  wire       clk,
    input  wire       resetn,
    input  wire       r_en,
    input  wire [6:0] r_addr,
    output wire       r_v,
    input  wire       w_en,
    input  wire [6:0] w_addr,
    input  wire       w_v
);

    reg [127:0] valid_array;
    reg [6:0]   r_addr_reg;

    always @(posedge clk) begin
        if (~resetn) begin
            valid_array <= 128'b0; 
        end else if (w_en) begin
            valid_array[w_addr] <= w_v;
        end
    end

    always @(posedge clk) begin
        if (r_en) begin
            r_addr_reg <= r_addr;
        end
    end

    assign r_v = valid_array[r_addr_reg];

endmodule