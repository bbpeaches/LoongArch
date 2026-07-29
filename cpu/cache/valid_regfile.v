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
    reg         r_v_reg;

    always @(posedge clk) begin
        if (~resetn) begin
            valid_array <= 128'b0; 
        end else if (w_en) begin
            valid_array[w_addr] <= w_v;
        end
    end

    always @(posedge clk) begin
        if (~resetn) begin
            r_v_reg <= 1'b0;
        end else if (r_en) begin
            r_v_reg <= valid_array[r_addr];
        end
    end
    assign r_v = r_v_reg;

endmodule