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

## Attempt 02 — one-cycle optimization in progress — 2026-08-05 07:45 CST

- Removed `TIMING-WAIVER-20260805-01` from the XDC (former lines 300–305).
- All sequential timing paths will again be checked at the native 150 MHz
  one-cycle requirement of `6.667 ns`.
- The prior passing bitstream is retained only as an audit artifact and is not
  a valid one-cycle timing-closure result.

## Attempt 03 — source-register replication in progress — 2026-08-05 07:59 CST

- Baseline after waiver removal: WNS `-0.776 ns`; TNS `-178.730 ns`; 683
  failing setup endpoints. The routed result exactly matches the original
  one-cycle report.
- RTL change: `cpu/pipeline/reg/id_ex_reg.v:33`, changed the synthesis
  attribute on `ex_alu_src2` from `max_fanout = 8` to `max_fanout = 1`.
- Intent: replicate the source register per consuming cone, reducing physical
  fanout and routing delay without changing pipeline depth, protocol timing,
  ISA-visible behavior, or IPC.

- Routed result: WNS `-0.484 ns`; TNS `-97.140 ns`; 639 failing setup
  endpoints; hold WNS `+0.074 ns`. The source was replicated as
  `ex_alu_src2_reg[0]_rep__95`; the bitstream was archived as
  `bitstream_20260805_0807.bit`.

## Attempt 04 — read-address CE cone simplification in progress — 2026-08-05 08:07 CST

- RTL change: `thinpad_top.v:201–224` moves `raddr_reg` updates from the
  response state-machine block into a dedicated, equivalent sequential block.
- Its enable is now only `read_fire || raddr_advance`; `raddr_advance` is a
  non-final accepted read beat. This preserves the cycle in which an address
  is captured or advanced, while removing unrelated wait-state logic from the
  enable cone.
- Routed result: WNS `-0.937 ns`; TNS `-511.323 ns`; 1,558 failing setup
  endpoints; hold WNS `+0.082 ns`. This is worse than Attempt 03, so the
  `thinpad_top.v` change was precisely reverted without another implementation
  run.

## Attempt 05 — DMW cone merge in progress — 2026-08-05 08:15 CST

- RTL change: `cpu/pipeline/pipe.v:60–61`, removed `keep = "true"` only from
  the data-address DMW segment comparisons.
- Intent: permit synthesis to merge the comparison with the DMW-enable/mux
  logic. The Boolean expressions and all address-translation behavior remain
  unchanged; no register, handshake, or pipeline stage is added.
- Routed result: WNS `-1.029 ns`; TNS `-736.701 ns`; 1,852 failing setup
  endpoints; hold WNS `+0.036 ns`. The result is worse than Attempt 03, so
  both `keep` attributes were restored without another implementation run.

## Attempt 06 — balanced source replication in progress — 2026-08-05 08:21 CST

- RTL change: `cpu/pipeline/reg/id_ex_reg.v:33`, changed `ex_alu_src2` from
  `max_fanout = 1` to `max_fanout = 2`.
- Intent: preserve local source-register replication for the address path but
  reduce the number of replicas and their ID-stage routing burden. No
  architectural state, control protocol, or clock-cycle behavior is changed.
- Routed result: WNS `-0.797 ns`; TNS `-295.074 ns`; 890 failing setup
  endpoints; hold WNS `+0.077 ns`. This is worse than Attempt 03, so
  `max_fanout = 1` was restored without another implementation run.

## Attempt 07 — DMW match replication in progress — 2026-08-05 08:28 CST

- RTL change: `cpu/pipeline/pipe.v:65–66`, added `max_fanout = 1` to
  `data_dmw0_match` and `data_dmw1_match` only.
- Intent: duplicate these small DMW match cones near their consumers to reduce
  their routed fanout. The expressions, datapath latency, and CPU protocol
  are unchanged.
- Superseded before implementation when the CSR-DMW predecode refactor was
  authorized; the two temporary `max_fanout` attributes were removed.

## Attempt 08 — CSR DMW predecode in progress — 2026-08-05 08:30 CST

- RTL changes: `cpu/cache/csr/csr_file.v:13–85` adds registered
  `dmw0_active`/`dmw1_active` flags; `cpu/pipeline/pipe.v:51–62,468–474`
  consumes them in the instruction/data DMW match cones.
- Each flag is calculated from the CSR next-state values and updated on the
  same CSR-write edge as CRMD/DMW0/DMW1. It is therefore equivalent to the
  prior `paged_mode && dmw*_plv_enable` expression at all instruction
  boundaries, while moving the page-mode/PLV decoding off the address path.
- No instruction pipeline register, handshake wait, or clock constraint was
  added or changed.
- Routed result: WNS `-0.783 ns`; TNS `-226.540 ns`; 1,115 failing setup
  endpoints; hold WNS `+0.048 ns`. This is worse than Attempt 03, so the
  predecode changes in `csr_file.v` and `pipe.v` were fully reverted without
  another implementation run.

## Attempt 09 — read-fire replication in progress — 2026-08-05 08:37 CST

- RTL change: `thinpad_top.v:197`, added `max_fanout = 1` to `read_fire`.
- Intent: replicate the AR handshake acceptance term into its consumers,
  especially the top-level read-address and beat-count register enables. This
  reduces physical control-net fanout without changing AXI handshakes, state
  transitions, latency, pipeline depth, or IPC.
- Routed result: WNS `-0.639 ns`; TNS `-208.503 ns`; 1,022 failing setup
  endpoints; hold WNS `+0.105 ns`. This is worse than Attempt 03, so the
  `read_fire` attribute was removed without another implementation run.

## Attempt 10 — dual AGU-operand replication in progress — 2026-08-05 08:46 CST

- RTL change: `cpu/pipeline/reg/id_ex_reg.v:32`, changed `ex_alu_src1` from
  `max_fanout = 8` to `max_fanout = 1`; `ex_alu_src2` remains at 1.
- Intent: replicate both AGU operands close to their address-generation and
  forwarding consumers. This is a synthesis/placement-only change: the same
  register values are available on the same clock edge, with no added stage,
  stall, latency, or IPC effect.
- Routed result: WNS `-0.901 ns`; TNS `-540.498 ns`. This is worse than
  Attempt 03, so `cpu/pipeline/reg/id_ex_reg.v:32` was restored to
  `max_fanout = 8` without another implementation run.

## Attempt 11 — write-buffer conflict comparator reduction in progress — 2026-08-05 08:52 CST

- RTL change: `cpu/buffer/write_buffer.v:65`, replaces the six separate
  three-bit equality tests in `same_word_addr` with
  `~|((addr_a ^ addr_b) & 32'h00ff_87fc)`.
- Equivalence: the mask selects exactly address bits `[10:2]` and `[23:15]`;
  bits `[14:11]` remain ignored as in the original code. This is purely
  combinational and changes neither transaction timing nor IPC.
- Routed result: WNS `-1.037 ns`; TNS `-664.163 ns`; 1,979 failing setup
  endpoints; hold WNS `+0.084 ns`. The worst path was
  `ex_alu_src2_reg[6]_rep__1/C` to `raddr_reg_reg[13]/D`, with `7.674 ns`
  data delay (36.606% logic, 63.394% routing). It is worse than Attempt 03,
  so `cpu/buffer/write_buffer.v:58-69` was restored exactly without another
  implementation run.

## Attempt 13 — targeted DMW1-match cone replication in progress — 2026-08-05 09:11 CST

- RTL change: `cpu/pipeline/pipe.v:66`, adds `max_fanout = 1` only to
  `data_dmw1_match`.
- Evidence: in the best strict one-cycle path this net has routed fanout 6,
  immediately following the AGU carry chain and DMW1 segment comparison. The
  routed design has no placement or router congestion above level 5, so no
  Pblock/LOC constraint is justified. This localized replication may shorten
  only the critical consumer route and is logically and cycle-equivalent.
- Routed result: WNS `-0.802 ns`; TNS `-525.308 ns`; 1,615 failing setup
  endpoints; hold WNS `+0.036 ns`. The worst path moved to
  `id_inst_reg[25]/C` to `ex_alu_src2_reg[0]_rep__7/D`, with `7.315 ns` data
  delay (18.837% logic, 81.163% routing). This is worse than Attempt 03, so
  `cpu/pipeline/pipe.v:66` was restored exactly without another implementation
  run.

## Attempt 12 — read-address valid-cycle mux simplification in progress — 2026-08-05 09:02 CST

- RTL change: `cpu/buffer/write_buffer.v:204`, changes the memory read address
  mux select from `start_load` to registered `load_busy`.
- Valid-cycle equivalence: when `mem_read_req=1`, either a new load is issued
  (`load_busy=0`, both expressions select `cpu_addr`) or a pending load is
  issued (`load_busy=1`, both expressions select `load_addr_latch`). The
  address can differ only while `mem_read_req=0`, when AXI does not sample it.
  No state update, request condition, response timing, pipeline stage, stall,
  or IPC behavior changes.
- Routed result: WNS `-0.825 ns`; TNS `-282.516 ns`; 1,138 failing setup
  endpoints; hold WNS `+0.036 ns`. The worst path moved to
  `ex_alu_op_reg[1]/C` to `ex_alu_src2_reg[0]_rep__81/D`, with `7.290 ns`
  data delay (35.691% logic, 64.309% routing). This is worse than Attempt 03,
  so `cpu/buffer/write_buffer.v:204` was restored exactly without another
  implementation run.

## Attempt 14 — carry-speculative data DMW translation in progress — 2026-08-05 09:18 CST

- RTL changes: `cpu/alu/agu.v:1-21`, `cpu/pipeline/stage/stage_ex.v:35-181`,
  and `cpu/pipeline/pipe.v:43-84,470-474` expose the low 29-bit sum, carry
  into bit 29, and both possible high-three-bit sums. The data DMW logic
  translates both candidates in parallel, then selects the corresponding
  physical segment with the low-sum carry.
- Equivalence: for `base=B_hi*2^29+B_lo` and `offset=O_hi*2^29+O_lo`,
  `B_lo+O_lo=c29*2^29+L`; the selected high segment is
  `(B_hi+O_hi+c29) mod 8`, exactly the high three bits of the original
  32-bit sum. Each candidate uses the original DMW0-over-DMW1 priority.
  The final physical address and all same-cycle handshake behavior are
  unchanged; no state, pipeline stage, bubble, or latency is added.
- Routed result: WNS `-0.345 ns`; TNS `-40.513 ns`; 363 failing setup
  endpoints; hold WNS `+0.090 ns`. The worst path moved to
  `raddr_reg_reg[26]/C` to `ex_alu_src2_reg[1]_rep__85/D`, with `6.859 ns`
  data delay (14.710% logic, 85.290% routing). This improves on Attempt 03,
  so the RTL change is retained. The routed bitstream was archived as
  `tb/bitstream_20260805_0929.bit` (1,482,862 bytes).

## Attempt 15 — bounded ID operand fanout replication in progress — 2026-08-05 09:30 CST

- RTL change: `cpu/pipeline/stage/stage_id.v:36`, applies `max_fanout = 16`
  to `id_alu_src2` only.
- Evidence: the new strict one-cycle critical path ends at an `ex_alu_src2`
  replica; its immediate data net has fanout 107 and `0.941 ns` routed delay.
  A limit of 16 requests local duplication of this one combinational output
  cone, rather than global replication. Data values, controls, registers,
  cycle timing, and IPC are unchanged.
- Routed result: WNS `-0.595 ns`; TNS `-159.832 ns`; 866 failing setup
  endpoints; hold WNS `+0.036 ns`. The worst path moved to
  `ex_alu_src1_reg[1]_rep__1/C` to `raddr_reg_reg[12]/D`, with `7.126 ns`
  data delay (34.226% logic, 65.774% routing). This is worse than Attempt 14,
  so `cpu/pipeline/stage/stage_id.v:36` was restored exactly without another
  implementation run.

## Attempt 16 — shared base/ext SRAM read decode in progress — 2026-08-05 09:38 CST

- RTL change: `thinpad_top.v:400-406`, replaces two mutually exclusive
  `[31:22]` comparisons for `10'h070` and `10'h071` with a shared
  `[31:23] == 9'h038` comparison and bit-22 base/ext data select.
- Equivalence: when `[31:23] != 9'h038`, both former comparisons are false.
  When it matches, bit 22 is 0 exactly for `10'h070` (base RAM) and 1 exactly
  for `10'h071` (extension RAM). UART and default return behavior are
  unchanged. No state, handshake, pipeline stage, bubble, latency, or IPC
  behavior changes.
- Routed result: WNS `-0.477 ns`; TNS `-78.558 ns`; 458 failing setup
  endpoints; hold WNS `+0.036 ns`. The worst path moved to
  `ex_alu_src1_reg[29]_rep__2/C` to `raddr_reg_reg[15]/D`, with `7.096 ns`
  data delay (20.899% logic, 79.101% routing). This is worse than Attempt 14,
  so `thinpad_top.v:400-406` was restored exactly without another
  implementation run.

## Attempt 17 — latency-neutral SRAM read-data pre-sampling in progress — 2026-08-05 09:46 CST

- RTL change: `thinpad_top.v:65,188-249,408-414`, captures the existing
  asynchronous SRAM/UART read-data mux into `rdata_sram_reg` only during
  `S_READ` while `RVALID=0`; the output interface consumes this register.
- Timing/IPC equivalence: `READ_WAIT_CYCLES=2`. For every accepted read beat,
  the address is held for two full wait cycles before `RVALID` is asserted;
  the new register samples in those existing cycles. `RVALID`, `RLAST`,
  `RREADY`, address progression, AXI handshake cycles, and all CPU-visible
  response timing remain unchanged. This adds no pipeline stage to the CPU
  and no bubble or execution-time increase.
- Routed result: WNS `-0.622 ns`; TNS `-122.329 ns`; 708 failing setup
  endpoints; hold WNS `+0.036 ns`. The worst path moved to
  `id_inst_reg[25]/C` to `ex_alu_src2_reg[3]_rep__53/D`, with `7.129 ns`
  data delay (19.330% logic, 80.670% routing). This is worse than Attempt 14,
  so `thinpad_top.v:65,188-249,408-414` was fully restored without another
  implementation run; no response register remains in the RTL.

## Attempt 18 — post-AGU balanced source replication in progress — 2026-08-05 09:56 CST

- RTL change: `cpu/pipeline/reg/id_ex_reg.v:33`, changes `ex_alu_src2` from
  `max_fanout = 1` to `max_fanout = 2` after the retained carry-speculative
  AGU/DMW refactor.
- Evidence: Attempt 14's new worst path ends at an automatically replicated
  `ex_alu_src2` D pin; its upstream data net has fanout 107. Limiting each
  replica to two consumers may reduce this input-side routing burden while
  retaining local AGU source replication. Register values, control behavior,
  pipeline depth, response timing, and IPC are unchanged.
- Routed result: WNS `-0.363 ns`; TNS `-40.614 ns`; 284 failing setup
  endpoints; hold WNS `+0.087 ns`. The worst path was
  `ex_alu_src2_reg[30]/C` to `rbeat_cnt_reg[7]/R`, with `6.553 ns` data
  delay (21.028% logic, 78.972% routing). Although its endpoint count is
  lower, WNS and TNS are both worse than Attempt 14; `id_ex_reg.v:33` was
  restored to `max_fanout = 1` without another implementation run.

## Attempt 19 — invalid-slot operand mux removal in progress — 2026-08-05 10:07 CST

- RTL change: `cpu/pipeline/stage/stage_id.v:127`, removes the outer
  `id_valid_inst ? ... : 32'd0` mux from `id_alu_src2`.
- Equivalence: when `id_valid_inst=1`, the value is bit-exactly unchanged.
  When it is 0, `id_rf_we`, `id_mem_en`, branch update/taken, CSR write,
  CACOP valid, and multiply issue are all already deasserted; the captured
  operand cannot affect architectural state, transactions, response timing,
  pipeline control, or IPC. This removes no register and adds no stage.
- Routed result: WNS `-0.427 ns`; TNS `-62.070 ns`; 520 failing setup
  endpoints; hold WNS `+0.036 ns`. This is worse than Attempt 14 in both WNS
  and TNS, so `cpu/pipeline/stage/stage_id.v:127` was restored to
  `id_valid_inst ? (id_use_imm ? id_imm : id_fwd_rdata2) : 32'd0` without
  another implementation run.
