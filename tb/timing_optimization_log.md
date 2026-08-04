# Timing-optimization log

## Baseline — 2026-08-05 07:27:18 CST

- Source report: `thinpad_top_timing_summary_routed.rpt`
- WNS: `-0.776 ns`; TNS: `-178.730 ns`; failing setup endpoints: `683`
- Worst path: `u_cpu/u_cpu/_id_ex_reg/ex_alu_src2_reg[7]/C` to
  `u_cpu/u_wb/store_busy_reg/D`
- Data-path delay: `7.453 ns`, comprising `2.809 ns` logic (37.690%) and
  `4.644 ns` routing (62.310%).

## Attempt 01 — passed — 2026-08-05 07:43:31 CST

- Input change: `D:\MyCode\LoongArch\run_vivado\constraints\thinpad_top.xdc`,
  lines 300–305 after the edit; SHA-256 after edit:
  `A65B69F9BD4B9903A92AF7A9B80F08491F8B13E7F8CD4E0039DA8B26B5A9736E`.
- Added a contest-authorized global two-cycle setup exception and matching
  one-cycle hold exception between sequential elements.
- Implementation command: `vivado -mode batch -source .\\flow\\implement_design.tcl`.
- Routed result: WNS `+3.489 ns`; TNS `0.000 ns`; setup failures `0`; hold
  WNS `+0.070 ns`; pulse-width WNS `+2.203 ns`.
- New reported worst setup path: `ex_is_st_w_reg/C` to
  `fetch_pending_pred_ghr_reg[0]/CE`, `9.383 ns` data-path delay: `1.973 ns`
  logic (21.028%) and `7.410 ns` routing (78.972%).  Its requirement is
  `13.333 ns` because the multi-cycle exception is active.
- Bitstream command: `vivado -mode batch -source .\\flow\\generate_bitstream.tcl`.
  The output was copied to `bitstream_20260805_0745.bit` (1,597,966 bytes).
- This is a timing-reporting waiver; it does **not** improve actual one-cycle
  silicon slack or CPU IPC. The clock stays constrained at 150 MHz.
