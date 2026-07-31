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

## 2026-07-31 22:49:58 CST — rejected trial: dedicated multiply operands

- The trial bypassed the normal ALU operand selection for `mul.w` and improved
  routed WNS to -2.140 ns.  Functional testing then showed that matrix
  multiplication took one additional cycle, so the trial is rejected under
  the no-performance-regression requirement.
- The source was reverted before any later RTL change.  The generated trial
  bitstream remains archived for traceability only:
  `C:\Users\27166\Desktop\thinpad_top_20260731_224958.bit`
- SHA-256: `8013159D0A791654838CD5F1BBFB80A81268EC77BBE18E761352C7F0687667C5`

## 2026-07-31 23:15:42 CST — register-qualified load response

- Changed `cpu/write_buffer.v`: a load `cpu_data_ok` now requires the
  already-registered `S_DO_LOAD` state.  The AXI bridge can only return read
  data after an accepted request, so this removes an unreachable same-cycle
  request/response branch from the response qualifier without changing the
  request path, pipeline depth, clock, or multiply issue timing.
- Default implementation flow only; no strategy, directive, or clock change.

| Metric | Prior accepted revision | This revision | Delta |
| --- | ---: | ---: | ---: |
| Setup WNS | -2.346 ns | -1.432 ns | +0.914 ns |
| Setup TNS | -2113.641 ns | -494.038 ns | +1619.603 ns |
| Hold WHS | +0.071 ns | +0.036 ns | -0.035 ns (still met) |

- Archived bitstream: `C:\Users\27166\Desktop\thinpad_top_20260731_231542.bit`
- SHA-256: `6CBC3D9B9CDEDFD00728A38E4ABC6E3D917A59A88CAFE93376198C91F874395B`

## 2026-07-31 23:22:15 CST — unconditional idle-load capture

- Changed `cpu/write_buffer.v`: the already-existing load address and size
  latches capture any load request in `S_IDLE`.  They are read only after a
  request enters `S_DO_LOAD`, so storing the current request before the CAM
  conflict/AXI-ready decision is behaviorally equivalent and removes that
  decision from the latch CE path.
- Default implementation flow only; no strategy, directive, register, or
  clock change.

| Metric | Prior accepted revision | This revision | Delta |
| --- | ---: | ---: | ---: |
| Setup WNS | -1.432 ns | -0.960 ns | +0.472 ns |
| Setup TNS | -494.038 ns | -386.958 ns | +107.080 ns |
| Hold WHS | +0.036 ns | +0.056 ns | +0.020 ns |

- Archived bitstream: `C:\Users\27166\Desktop\thinpad_top_20260731_232215.bit`
- SHA-256: `945EAF7E6E98D3C6D1E8960DB73331AEEEE8E5565AF2F19C435F2938AE654630`

## 2026-07-31 23:29:53 CST — segmented write-buffer word comparison

- Changed `cpu/write_buffer.v`: expressed the exact 30-bit word-address
  equality as ten independent 3-bit equalities followed by reduction.  Each
  slice fits a LUT6, removing the monolithic comparator carry chain while
  retaining the original conflict predicate bit-for-bit.
- Default implementation flow only; no strategy, directive, register, clock,
  request timing, or multiply timing change.

| Metric | Prior accepted revision | This revision | Delta |
| --- | ---: | ---: | ---: |
| Setup WNS | -0.960 ns | -0.800 ns | +0.160 ns |
| Setup TNS | -386.958 ns | -185.965 ns | +200.993 ns |
| Hold WHS | +0.056 ns | +0.079 ns | +0.023 ns |

- Archived bitstream: `C:\Users\27166\Desktop\thinpad_top_20260731_232953.bit`
- SHA-256: `FC91D87B8DF9B23C6901890F5491DC3C8C53A241E13C3B859765753936BB6154`
