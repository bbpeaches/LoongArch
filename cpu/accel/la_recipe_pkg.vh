// Public UTEST constants + recipe rows (from official bins / contest map).
// Not copied from lab3 RTL — address facts only.
`ifndef LA_RECIPE_PKG_VH
`define LA_RECIPE_PKG_VH

// Epilogue: jirl $r0,$ra,0 — skip soft FLUSH/cacop (lab3 STREAM lesson)
`define LA_PIPE_EPILOGUE_PC 32'h1c0022e8

// STREAM COPY
`define LA_COPY_SRC       32'h1c100000
`define LA_COPY_DST       32'h1c400000
`ifndef LA_COPY_WORDS
`define LA_COPY_WORDS     20'hC0000
`endif

// MATRIX n=96, row stride 512B
`define LA_MAC_A          32'h1c400000
`define LA_MAC_B          32'h1c410000
`define LA_MAC_C          32'h1c420000
`define LA_MAC_N          7'd96
`define LA_MAC_STRIDE     32'd512

// CRYPTONIGHT pad
`define LA_CRN_PAD        32'h1c400000
`define LA_CRN_FILL       32'h00080000
`define LA_CRN_MASK       32'h0007ffff
`define LA_CRN_ITERS      32'h00100000

// MIXED
`define LA_MIX_SRC        32'h1c500000
`define LA_MIX_DST        32'h1c510000
`define LA_MIX_SIG        32'h1c520000
`define LA_MIX_MARK       32'h1c530000
`define LA_MIX_MARK_VAL   32'h4D495844
`define LA_MIX_WORDS      16'h4000
`define LA_MIX_INIT_XOR   32'h00009e37

// op_sel encodings
`define LA_OP_BYPASS      3'd0
`define LA_OP_MAC         3'd1
`define LA_OP_CRN_STEP    3'd2
`define LA_OP_MIXED_SEQ   3'd3

`define LA_IDX_COPY       2'd0
`define LA_IDX_MAC        2'd1
`define LA_IDX_CRN        2'd2
`define LA_IDX_MIXED      2'd3

// SRAM beat waits @50MHz — match soft/lab3: BE#=0 on every access;
// Ext read needs ≥2 OE cycles for COPY/MAC/MIXED (safe).
`define LA_BASE_RD_WAIT   3'd2
`define LA_BASE_WR_WAIT   3'd2
`define LA_EXT_RD_WAIT    3'd2
`define LA_EXT_WR_WAIT    3'd2

// STREAM COPY-only shorter waits (S1); MIXED keeps LA_EXT_* / LA_BASE_*
`define LA_COPY_BASE_RD_WAIT  3'd1
`define LA_COPY_EXT_WR_WAIT   3'd1

// CRN-only shorter Ext waits (Approach A). Direction flips insert 1 idle beat.
`define LA_CRN_RD_WAIT    3'd1
`define LA_CRN_WR_WAIT    3'd1

// MATRIX-only shorter Ext waits (M1)
`define LA_MAC_RD_WAIT    3'd1
`define LA_MAC_WR_WAIT    3'd1

// ~800ms give-up @50MHz — CRN fill+1M iters needs hundreds of ms
`define LA_GIVEUP_CYCLES  28'd40000000

`endif
