module mul_top (
    input  wire [31:0] x,       // 被乘数 rj
    input  wire [31:0] y,       // 乘数 rk
    output wire [31:0] result   // 乘法结果 rd
);
    wire [32:0] y_ext = {y, 1'b0};
    wire [32:0] pp [0:15]; 
    wire [15:0] neg_c;
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : gen_booth
            booth_radix4_encoder #(
                .WIDTH(32)
            ) _booth (
                .x      (x),
                .y_vec  (y_ext[i*2+2 : i*2]), 
                .p      (pp[i]),
                .neg_c  (neg_c[i])
            );
        end
    endgenerate

    reg [63:0] sum_all;
    integer j;
    
    always @(*) begin
        sum_all = 64'b0;
        for (j = 0; j < 16; j = j + 1) begin
            sum_all = sum_all + ( ({{31{pp[j][32]}}, pp[j]} + neg_c[j]) << (j * 2) );
        end
    end
    assign result = sum_all[31:0];

endmodule