# Timing optimization log

## 2026-07-31 22:41:12 CST — multiplier input mux removal

- Changed `cpu/cpu.v`: the multiplier now always receives the already-decoded
  ID operands.  `mul_issue` remains the sole valid marker, so non-multiply
  products are still ignored by the existing valid pipeline.  This removes
  the redundant per-bit zero-injection muxes without adding a register,
  changing the clock, or changing implementation strategy.
- Build prerequisite: the generated `mult_gen_0` simulation netlists were
  removed from the synthesis source tree because the fixed project-creation
  flow recursively includes them and Vivado rejects them as synthesis inputs.
  The XCI/DCP remains the implementation source for the multiplier.
- Default implementation flow only (`flow/create_vivado_project.tcl`, then
  `flow/implement_design.tcl`); no strategy, directive, or clock change.

| Metric | Default baseline | This revision | Delta |
| --- | ---: | ---: | ---: |
| Setup WNS | -2.505 ns | -2.346 ns | +0.159 ns |
| Setup TNS | -2251.205 ns | -2113.641 ns | +137.564 ns |
| Hold WHS | +0.094 ns | +0.071 ns | -0.023 ns (still met) |

- Archived bitstream: `C:\Users\27166\Desktop\thinpad_top_20260731_224112.bit`
- SHA-256: `AD070A085341647CD8B3B739956531DE0A75AAEBDCDDFA26B36ECF278B5883DB`

## 2026-07-31 22:49:58 CST — dedicated multiply operands

- Changed `cpu/pipeline/stage_id.v` and `cpu/cpu.v`: exposed the two raw
  forwarded register operands exclusively for the register-register `mul.w`
  datapath.  The existing `mul_issue` valid pipe is unchanged, and the normal
  ALU operand muxes remain unchanged for every non-multiply instruction.
- Default implementation flow only; no strategy, directive, register, or
  clock change.

| Metric | Previous revision | This revision | Delta |
| --- | ---: | ---: | ---: |
| Setup WNS | -2.346 ns | -2.140 ns | +0.206 ns |
| Setup TNS | -2113.641 ns | -1854.147 ns | +259.494 ns |
| Hold WHS | +0.071 ns | +0.086 ns | +0.015 ns |

- Archived bitstream: `C:\Users\27166\Desktop\thinpad_top_20260731_224958.bit`
- SHA-256: `8013159D0A791654838CD5F1BBFB80A81268EC77BBE18E761352C7F0687667C5`
