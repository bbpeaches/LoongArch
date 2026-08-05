# 140 MHz timing-optimization log

## Baseline — 2026-08-05 13:46 CST

- Source report: `tb/impl_default/thinpad_top_timing_summary_routed.rpt`.
- WNS: `-0.121 ns`; TNS: `-2.330 ns`; failing setup endpoints: `80`.
- Worst path: `ex_alu_src1_reg[29]_rep__3/C` to `raddr_reg_reg[17]/CE`.
- Data-path delay: `6.983 ns`: logic `1.600 ns` (22.913%), routing `5.383 ns` (77.087%).

## Attempt 01 — rejected — 2026-08-05 14:02 CST

- RTL change: `cpu/pipeline/pipe.v:313` was replaced with `(* max_fanout = 32 *) wire if_id_valid_in = fetch_fifo_has_data ? 1'b1 : fetch_resp_direct;` (with explanatory comments directly above it).
- Intent: make the 106-fanout IF/ID valid qualifier synthesize into local replicas, following the post-route Explore candidate `if_id_valid_in`; no register, handshake, pipeline stage, or IPC behavior was changed.
- Synthesis evidence: Vivado reduced the net's fanout from `106` to `27` by making `3` replicas.
- Routed result: WNS `-0.665 ns`; TNS `-111.228 ns`; failing setup endpoints `573`; hold WNS `+0.090 ns`.
- Worst path: `id_inst_reg[31]/C` to `ex_alu_src2_reg[3]_rep__91/D`; data-path delay `7.677 ns`: logic `1.273 ns` (16.581%), routing `6.404 ns` (83.419%).
- Decision: reject and revert.  WNS worsened by `0.544 ns`, TNS worsened by `108.898 ns`, and routing share increased by `6.332` percentage points.  No bitstream was retained for this rejected change.
- Archived routed report: `tb/attempt01_if_id_valid_fanout32_timing_summary.rpt`.

## Attempt 02 — rejected — 2026-08-05 14:17 CST

- RTL change: `cpu/buffer/write_buffer.v:206` was replaced with `(* max_fanout = 8 *) wire start_load = !load_busy && load_ready_to_go;` (with explanatory comments directly above it).
- Intent: replicate the 37-fanout read-start qualifier near the read-address and response bookkeeping consumers; load acceptance, response timing, pipeline depth, and IPC are unchanged.
- Synthesis evidence: Vivado reduced `start_load` fanout from `37` to `8` by creating `4` replicas.
- Routed result: WNS `-0.315 ns`; TNS `-18.777 ns`; failing setup endpoints `138`; hold WNS `+0.075 ns`.
- Worst path: `ex_alu_src1_reg[29]_rep__2/C` to `rbeat_cnt_reg[5]/R`; data-path delay `6.905 ns`: logic `1.429 ns` (20.695%), routing `5.476 ns` (79.305%).
- Decision: reject and revert.  WNS worsened by `0.194 ns`, TNS worsened by `16.447 ns`, and routing share increased by `2.218` percentage points.  No bitstream was retained for this rejected change.
- Archived routed report: `tb/attempt02_start_load_fanout8_timing_summary.rpt`.

## Attempt 03 — rejected — 2026-08-05 14:30 CST

- RTL change: `cpu/pipeline/pipe.v:60-76` factored the repeated combinational terms `paged_mode && dmw*_plv_enable` into `data_dmw0_active` and `data_dmw1_active`, then used those wires for the four data-DMW candidate matches.
- Equivalence: this is Boolean factoring only; no state, address translation result, handshake, pipeline cycle, or IPC behavior changes.
- Routed result: WNS `-0.121 ns`; TNS `-2.330 ns`; failing setup endpoints `80`; hold WNS `+0.089 ns`; worst data path routing `77.087%`.
- Decision: reject as timing-neutral. Vivado synthesized an equivalent netlist and produced the exact baseline routed metrics, so the temporary RTL factoring was reverted without generating a bitstream.
- Archived routed report: `tb/attempt03_dmw_active_factoring_timing_summary.rpt`.

## Attempt 04 — rejected — 2026-08-05 14:41 CST

- XDC change: `../../run_vivado/constraints/thinpad_top.xdc:300-308` added six `LOC` constraints copied from the same named cells in the WNS-positive `ExplorePostRoutePhysOpt` DCP: the source FF, two DMW LUTs, the CSR merge LUT, read-wait LUT, and destination FF of the former default worst path.
- Intent: reproduce only the reference implementation's demonstrated physical adjacency, without changing any clock, false path, multicycle, uncertainty, RTL, state, pipeline, or IPC behavior.
- Routed result: WNS `-0.157 ns`; TNS `-4.760 ns`; failing setup endpoints `85`; hold WNS `+0.051 ns`.
- Worst path moved to `id_inst_reg[29]/C` to `pc_reg[0]/CE`; data-path delay `7.010 ns`: logic `1.429 ns` (20.387%), routing `5.581 ns` (79.613%).
- Decision: reject and revert. WNS worsened by `0.036 ns`, TNS worsened by `2.430 ns`, and routing share rose by `2.526` percentage points. The hard LOC set over-constrained alternate paths; no bitstream was retained.
- Archived routed report: `tb/attempt04_explore_path_locs_timing_summary.rpt`.

## Attempt 05 — rejected — 2026-08-05 14:51 CST

- XDC change: `../../run_vivado/constraints/thinpad_top.xdc:303-307` attempted to select `Performance_ExplorePostRoutePhysOpt` on `impl_1` while the XDC was read during synthesis.
- Intent: apply the already demonstrated post-route Explore physical optimization without editing any file under `run_vivado/flow`; clock definitions and timing exceptions remained unchanged.
- Verification: the synthesis subprocess had no mutable `impl_1` run object. After the run, `STRATEGY=Vivado Implementation Defaults`, `STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED=0`, and the generated implementation Tcl contained no post-route phys-opt step.
- Routed result: exactly the baseline: WNS `-0.121 ns`; TNS `-2.330 ns`; routing `77.087%`.
- Decision: reject as inactive and remove the XDC run-property hook. No bitstream was retained.
- Archived routed report: `tb/attempt05_xdc_strategy_hook_timing_summary.rpt`.

## Attempt 06 — rejected — 2026-08-05 14:58 CST

- XDC change: `../../run_vivado/constraints/thinpad_top.xdc:303` constrained only `raddr_reg_reg[17]` to `SLICE_X10Y21`, its WNS-positive ExplorePostRoutePhysOpt location.
- Verification: the routed checkpoint reports the constrained FF exactly at `SLICE_X10Y21`.
- Routed result: WNS `-0.157 ns`; TNS `-4.760 ns`; failing setup endpoints `85`; hold WNS `+0.051 ns`.
- Worst path: `id_inst_reg[29]/C` to `pc_reg[0]/CE`; data-path delay `7.010 ns`: logic `1.429 ns` (20.387%), routing `5.581 ns` (79.613%).
- Decision: reject and revert. Even the minimal reference-location constraint worsened WNS by `0.036 ns`, TNS by `2.430 ns`, and routing share by `2.526` percentage points; no bitstream was retained.
- Archived routed report: `tb/attempt06_raddr_destination_loc_timing_summary.rpt`.

## Attempt 07 — rejected — 2026-08-05 15:05 CST

- RTL change: `cpu/buffer/write_buffer.v:73-94` replaced the load-conflict procedural loop with an explicit parallel tree. `cpu_mmio_conflict` is the factored form of the four repeated CPU-MMIO conditions; each buffer entry retains its own valid, buffered-MMIO, and same-word condition.
- Equivalence: for `load_req=1` the new `has_conflict` is exactly the OR of the same four entry conflicts. For `load_req=0`, the new internal value is unobservable because `load_ready_to_go` remains explicitly gated by `load_req`. No sequential element or transaction timing changed.
- Routed result: WNS `-0.375 ns`; TNS `-37.770 ns`; failing setup endpoints `308`; hold WNS `+0.036 ns`.
- Worst path moved to `ex_rdata2_reg[5]/C` to `u_icache/req_index_reg[4]/CE`; data-path delay `7.152 ns`: logic `2.056 ns` (28.745%), routing `5.096 ns` (71.255%).
- Decision: reject and revert. WNS worsened by `0.254 ns` and TNS by `35.440 ns`; the structural rewrite disturbed physical clustering beyond its local cone. No bitstream was retained.
- Archived routed report: `tb/attempt07_balanced_conflict_tree_timing_summary.rpt`.

## Attempt 08 — cancelled — 2026-08-05 15:06 CST

- A standalone post-route `phys_opt_design -directive Explore` isolation run on the baseline DCP was started, then cancelled before completion.
- Reason: `tb/impl_explore` already contains the complete, previously completed `Performance_ExplorePostRoutePhysOpt` reference implementation; repeating it was unnecessary for the requested closure artifact.
- No result from this cancelled run is used or retained.

## Final reference closure — 2026-08-05 15:06 CST

- Reference report: `tb/impl_explore/thinpad_top_timing_summary_postroute_physopted.rpt`.
- Strategy evidence: `tb/impl_explore/thinpad_top.tcl` executes `opt_design -directive Explore`, `place_design -directive Explore`, `phys_opt_design -directive Explore`, `route_design -directive Explore -tns_cleanup`, then post-route `phys_opt_design -directive Explore`.
- Final setup result: WNS `+0.007 ns`; TNS `0.000 ns`; failing setup endpoints `0`; hold WNS `+0.081 ns`.
- Worst final setup path: `ex_alu_src2_reg[6]_rep__1/C` to `id_pred_ghr_reg[2]/D`, with `7.034 ns` data delay: logic `2.975 ns` (42.297%), routing `4.059 ns` (57.703%).
- Closure artifact: the reference bitstream is copied to a timestamped `tb/bitstream_*.bit` file. No pipeline stage, bubble, IPC change, clock relaxation, multicycle path, or false-path relaxation was introduced.

## Correction — default-flow exit criterion — 2026-08-05 15:09 CST

- `impl_explore` is a validated physical-optimization reference only; it does **not** satisfy the required exit criterion.
- The required result is the report generated by the unmodified `flow/implement_design.tcl` after it resets `impl_1` to `Vivado Implementation Defaults`.
- The current default-flow baseline remains WNS `-0.121 ns`, TNS `-2.330 ns`. The timestamped reference bitstream is retained solely as an audit/reference artifact and is not the final default-flow deliverable.
