module icache_way (
    input  wire         clk,
    input  wire         resetn,

    input  wire         r_en,         // 读使能
    input  wire [ 6:0]  r_index,      // 读地址
    output wire [19:0]  r_tag_out,    // 读出的 Tag 值
    output wire         r_v_out,      // 读出的 Valid 值
    output wire [255:0] r_data_out,   // 读出的 8 个字的 Cache 行数据

    input  wire         w_tag_v_en,   // Tag 和 Valid 的写使能
    input  wire [ 6:0]  w_index,      // 写地址
    input  wire [19:0]  w_tag,        // 写入的 Tag 值
    input  wire         w_v,          // 写入的 Valid 值

    input  wire [ 7:0]  w_bank_en,    // 8个 Data Bank 的写使能
    input  wire [31:0]  w_bank_data   // 写入 Data Bank 的 32 位数据
);

    simple_dual_port_ram #(
        .WIDTH(20), 
        .DEPTH(128), 
        .ADDR_WIDTH(7),
        .RAM_STYLE("distributed")
    ) tag_ram (
        .clk    (clk),
        .r_en   (r_en),       .r_addr (r_index), .r_data (r_tag_out),
        .w_en   (w_tag_v_en), .w_addr (w_index), .w_data (w_tag)
    );

    valid_regfile v_reg (
        .clk    (clk),
        .resetn (resetn),
        .r_en   (r_en),       .r_addr (r_index), .r_v    (r_v_out),
        .w_en   (w_tag_v_en), .w_addr (w_index), .w_v    (w_v)
    );

    wire [31:0] r_bank_out [0:7];

    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : gen_data_bank
            simple_dual_port_ram #(
                .WIDTH(32), .DEPTH(128), .ADDR_WIDTH(7)
            ) data_ram (
                .clk    (clk),
                .r_en   (r_en),
                .r_addr (r_index),
                .r_data (r_bank_out[i]),
                .w_en   (w_bank_en[i]),
                .w_addr (w_index),
                .w_data (w_bank_data)
            );
        end
    endgenerate

    assign r_data_out = {r_bank_out[7], r_bank_out[6], r_bank_out[5], r_bank_out[4],
                         r_bank_out[3], r_bank_out[2], r_bank_out[1], r_bank_out[0]};

endmodule