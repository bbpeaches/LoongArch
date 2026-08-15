module agu (
    input  wire [31:0] base,
    input  wire [31:0] offset,
    output wire [31:0] addr,
    output wire [28:0] addr_lo,
    output wire        addr_carry29,
    output wire [ 2:0] addr_vseg_c0,
    output wire [ 2:0] addr_vseg_c1
);
    wire [29:0] low_sum = {1'b0, base[28:0]} + {1'b0, offset[28:0]};

    assign addr_lo      = low_sum[28:0];
    assign addr_carry29 = low_sum[29];
    assign addr_vseg_c0 = base[31:29] + offset[31:29];
    assign addr_vseg_c1 = addr_vseg_c0 + 3'd1;
    assign addr         = {addr_carry29 ? addr_vseg_c1 : addr_vseg_c0, addr_lo};

endmodule
