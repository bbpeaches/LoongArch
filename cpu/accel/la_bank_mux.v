
module la_bank_mux (
    input  wire        pipe_port_sel,
    input  wire        soft_base_ce_n,
    input  wire        soft_base_oe_n,
    input  wire        soft_base_we_n,
    input  wire [3:0]  soft_base_be_n,
    input  wire [19:0] soft_base_addr,
    input  wire [31:0] soft_base_dout,
    input  wire        soft_base_doe,
    input  wire        soft_ext_ce_n,
    input  wire        soft_ext_oe_n,
    input  wire        soft_ext_we_n,
    input  wire [3:0]  soft_ext_be_n,
    input  wire [19:0] soft_ext_addr,
    input  wire [31:0] soft_ext_dout,
    input  wire        soft_ext_doe,
    input  wire        pipe_base_ce_n,
    input  wire        pipe_base_oe_n,
    input  wire        pipe_base_we_n,
    input  wire [3:0]  pipe_base_be_n,
    input  wire [19:0] pipe_base_addr,
    input  wire [31:0] pipe_base_dout,
    input  wire        pipe_base_doe,
    input  wire        pipe_ext_ce_n,
    input  wire        pipe_ext_oe_n,
    input  wire        pipe_ext_we_n,
    input  wire [3:0]  pipe_ext_be_n,
    input  wire [19:0] pipe_ext_addr,
    input  wire [31:0] pipe_ext_dout,
    input  wire        pipe_ext_doe,
    output wire        base_ce_n,
    output wire        base_oe_n,
    output wire        base_we_n,
    output wire [3:0]  base_be_n,
    output wire [19:0] base_addr,
    output wire [31:0] base_data_out,
    output wire        base_data_oe,
    output wire        ext_ce_n,
    output wire        ext_oe_n,
    output wire        ext_we_n,
    output wire [3:0]  ext_be_n,
    output wire [19:0] ext_addr,
    output wire [31:0] ext_data_out,
    output wire        ext_data_oe
);
    assign base_ce_n    = pipe_port_sel ? pipe_base_ce_n    : soft_base_ce_n;
    assign base_oe_n    = pipe_port_sel ? pipe_base_oe_n    : soft_base_oe_n;
    assign base_we_n    = pipe_port_sel ? pipe_base_we_n    : soft_base_we_n;
    assign base_be_n    = pipe_port_sel ? pipe_base_be_n    : soft_base_be_n;
    assign base_addr    = pipe_port_sel ? pipe_base_addr    : soft_base_addr;
    assign base_data_out= pipe_port_sel ? pipe_base_dout    : soft_base_dout;
    assign base_data_oe = pipe_port_sel ? pipe_base_doe     : soft_base_doe;
    assign ext_ce_n     = pipe_port_sel ? pipe_ext_ce_n     : soft_ext_ce_n;
    assign ext_oe_n     = pipe_port_sel ? pipe_ext_oe_n     : soft_ext_oe_n;
    assign ext_we_n     = pipe_port_sel ? pipe_ext_we_n     : soft_ext_we_n;
    assign ext_be_n     = pipe_port_sel ? pipe_ext_be_n     : soft_ext_be_n;
    assign ext_addr     = pipe_port_sel ? pipe_ext_addr     : soft_ext_addr;
    assign ext_data_out = pipe_port_sel ? pipe_ext_dout     : soft_ext_dout;
    assign ext_data_oe  = pipe_port_sel ? pipe_ext_doe      : soft_ext_doe;
endmodule
