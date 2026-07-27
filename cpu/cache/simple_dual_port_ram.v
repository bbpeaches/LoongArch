module simple_dual_port_ram #(
    parameter WIDTH = 32,
    parameter DEPTH = 128,
    parameter ADDR_WIDTH = 7,
    parameter RAM_STYLE = "block"
)(
    input  wire                  clk,
    // Read port
    input  wire                  r_en,
    input  wire [ADDR_WIDTH-1:0] r_addr,
    output reg  [WIDTH-1:0]      r_data,
    // Write port
    input  wire                  w_en,
    input  wire [ADDR_WIDTH-1:0] w_addr,
    input  wire [WIDTH-1:0]      w_data
);
    (* ram_style = RAM_STYLE *)
    reg [WIDTH-1:0] ram [0:DEPTH-1];

    // 同步读
    always @(posedge clk) begin
        if (r_en) begin
            r_data <= ram[r_addr];
        end
    end

    // 同步写
    always @(posedge clk) begin
        if (w_en) begin
            ram[w_addr] <= w_data;
        end
    end
endmodule