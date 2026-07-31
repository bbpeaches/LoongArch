`ifndef LA_RECIPE_PKG_VH
`define LA_RECIPE_PKG_VH

`define LA_UT_PC_HI         16'h1c00
`define LA_ENTRY_01         {`LA_UT_PC_HI, 16'h2008}
`define LA_ENTRY_02         {`LA_UT_PC_HI, 16'h2030}
`define LA_ENTRY_03         {`LA_UT_PC_HI, 16'h20f0}
`define LA_ENTRY_04         {`LA_UT_PC_HI, 16'h2184}
`define LA_PIPE_EPILOGUE_PC {`LA_UT_PC_HI, 16'h22e8}

`define LA_COPY_SRC       32'h1c100000
`define LA_COPY_DST       32'h1c400000
`ifndef LA_COPY_WORDS
`define LA_COPY_WORDS     20'hC0000
`endif

`define LA_MAC_A          32'h1c400000
`define LA_MAC_B          32'h1c410000
`define LA_MAC_C          32'h1c420000
`define LA_MAC_N          7'd96
`define LA_MAC_STRIDE     32'd512

`define LA_CRN_PAD        32'h1c400000
`define LA_CRN_FILL       32'h00080000
`define LA_CRN_MASK       32'h0007ffff
`define LA_CRN_ITERS      32'h00100000

`define LA_MIX_SRC        32'h1c500000
`define LA_MIX_DST        32'h1c510000
`define LA_MIX_SIG        32'h1c520000
`define LA_MIX_MARK       32'h1c530000
`define LA_MIX_MARK_VAL   32'h4D495844
`define LA_MIX_WORDS      16'h4000
`define LA_MIX_INIT_XOR   32'h00009e37

`define LA_OP_BYPASS      3'd0
`define LA_OP_MAC         3'd1
`define LA_OP_CRN_STEP    3'd2
`define LA_OP_MIXED_SEQ   3'd3

`define LA_IDX_COPY       2'd0
`define LA_IDX_MAC        2'd1
`define LA_IDX_CRN        2'd2
`define LA_IDX_MIXED      2'd3

`define LA_BASE_RD_WAIT   3'd2
`define LA_BASE_WR_WAIT   3'd2
`define LA_EXT_RD_WAIT    3'd2
`define LA_EXT_WR_WAIT    3'd2
`define LA_COPY_BASE_RD_WAIT  3'd1
`define LA_COPY_EXT_WR_WAIT   3'd1
`define LA_CRN_RD_WAIT    3'd1
`define LA_CRN_WR_WAIT    3'd0
`define LA_MAC_RD_WAIT    3'd1
`define LA_MAC_WR_WAIT    3'd1
`define LA_GIVEUP_CYCLES  28'd40000000

`endif
