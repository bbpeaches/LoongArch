module simple_dual_port_ram #(
    parameter WIDTH = 32,
    parameter DEPTH = 128,
    parameter ADDR_WIDTH = 7
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

    // 强制指示 Vivado 综合器使用底层的 Block RAM 资源
    (* ram_style = "block" *)
    reg [WIDTH-1:0] ram [0:DEPTH-1];

    // 同步读：打一拍输出，完全符合 BRAM 时序
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
