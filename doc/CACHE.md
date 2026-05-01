# Z-Core Data Cache Verification Plan

## Cache Architecture

`rtl/z_core_data_cache.v` — 2-way set-associative, write-back, write-allocate. Writebacks
and refills are **handled externally by the LSU**; the cache exposes the raw signals
needed to drive that handshake.

| Parameter | Value |
|-----------|-------|
| Total entries | 1024 words (2 ways × 512 sets) |
| Sets (CACHE_DEPTH) | 512 |
| Index bits | 9 (`addr[10:2]`) |
| Tag bits | 21 (`addr[31:11]`) |
| Byte offset | `addr[1:0]` (ignored — word-granularity) |
| Write policy | Write-back, write-allocate |
| Replacement | 1-bit LRU per index |
| Refill | External LSU (cache asserts `request_refill`, LSU drives `refill_complete`) |

### Port Summary

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `clk`, `rstn` | in | 1 | Clock, active-low reset |
| `cs` | in | 1 | Chip-select — gates all access (0 = idle) |
| `wen` | in | 1 | Write enable (1=write, 0=read), only meaningful when `cs=1` |
| `addr` | in | 32 | Word-aligned address |
| `data_in` | in | 32 | Write data (or refill data when `refill_complete=1`) |
| `refill_complete` | in | 1 | LSU signal: install line at `addr` with `data_in` |
| `data_out` | out | 32 | Read result (registered, 1-cycle latency) |
| `cache_hit` | out | 1 | Hit indicator (registered, 1-cycle latency) |
| `request_refill` | out | 1 | Set on miss; tells LSU to fetch (and writeback if needed) |
| `dirty_writeback_enabled` | out | 1 | Set with `request_refill` when victim is dirty |
| `dirty_writeback_addr` | out | 32 | Drives miss `addr` (see Bug 8) |
| `dirty_writeback_data` | out | 32 | Victim line data to be written back |

**Important:** `cache_hit`, `data_out`, `request_refill`, `dirty_writeback_*` are all
registered — sample on the cycle **after** applying stimulus.

### LSU ↔ Cache protocol

```
   request_refill ── 1 ─────────────── 1 ─── 0  ← cache
   refill_complete ─ 0 ─────────────── 1 ─── 0  ← LSU drives
   addr            : miss_addr (LSU holds it stable through complete)
   data_in         :         ?         ↑
                                       └── LSU drives fetched word (for read)
                                           or store data    (for write-allocate)
   dirty_writeback_*: valid the cycle request_refill rises; LSU must capture
                      and perform the AXI writeback before refill_complete.
```

The LSU is responsible for:
1. Sampling `dirty_writeback_addr` / `_data` when `dirty_writeback_enabled=1`,
   issuing the AXI writeback, then
2. Reading the missed line from memory, then
3. Driving `addr=miss_addr`, `data_in=fetched/store_word`, `refill_complete=1` for
   one cycle to install the line.

---

## Known Bugs / RTL Quirks

| # | Location | Description | Severity |
|---|----------|-------------|----------|
| 1 | Read path | Read does not update LRU bits | Functional |
| 2 | Refill path | `dirty_bits<=1'b1` on refill_complete unconditionally — read fills are marked dirty | Functional |
| 3 | Eviction path | `dirty_writeback_addr <= addr` uses **miss addr** instead of victim's reconstructed addr (`{tags[victim][index], index, 2'b00}`) — LSU cannot tell where to write back the victim from this signal alone | Functional |
| 4 | Refill buffer | `refill_buffer_data/tag/index/set` are written but **never read** (refill_complete branch uses live inputs) — LSU must hold `addr` stable through `refill_complete`. If `addr` changes between miss and complete, the line is installed at the wrong location. | Protocol gotcha |
| 5 | `dirty_writeback_enabled` | Only assigned on write-miss path; only cleared by reset. After a write-miss with clean victim it stays at the previous value. | Functional |
| 6 | No `wstrb` port | Byte/halfword writes (SB/SH) cannot be expressed | Missing feature |
| 7 | No interlock on `request_refill` | If a new `cs && wen` arrives while `request_refill=1` is pending, the cache overwrites the buffer/state. LSU contract must hold off. | Missing feature / protocol contract |

---

## Phase 1: Unit-Level Testbench

**File:** `tb/z_core_data_cache_tb.sv`
**Run:** `cd sim && make -f ../tb/Makefile run TB_FILE=z_core_data_cache_tb.sv [SIM=iverilog]`

### Test Cases

| ID | Name | Coverage |
|----|------|----------|
| T1.01 | Reset clears all state | reset, port defaults |
| T1.02 | `cs=0` keeps cache idle | chip-select gating |
| T1.03 | Read miss asserts `request_refill` | miss path basics |
| T1.04 | Read-miss refill installs line; next read hits | refill handshake |
| T1.05 | Write hit updates data, no refill request | hit-write path |
| T1.06 | Write miss with clean victim — no writeback | clean-victim allocate |
| T1.07 | Write miss + refill completes write-allocate | full write-allocate |
| T1.08 | Same tag, different indices | indexing |
| T1.09 | Two-way fill (both sets at same index) | associativity |
| T1.10 | Eviction with dirty victim — writeback signals exposed | dirty eviction |
| T1.11 | Refill / writeback signals stable during 20-cycle stall | LSU pacing |
| T1.12 | `request_refill` clears after `refill_complete` | handshake teardown |
| T1.13 | LRU replacement correctness | catches Bug 1 (LRU on read) |
| T1.14 | Read-fill leaves dirty=1 | documents Bug 2 |
| T1.15 | `dirty_writeback_addr` observation | documents Bug 3 |
| T1.16 | Capacity stress (all 512 × 2) | depth |
| T1.17 | Hit-rate tracking | mixed sequence |
| T1.18 | `dirty_writeback_enabled` stickiness | documents Bug 5 |
| T1.19 | `addr` stability contract during refill | documents Bug 4 |
| T1.20 | No interlock on pending refill | documents Bug 7 |

T1.13–T1.15, T1.18–T1.20 print [INFO] without hard-failing — they
document RTL behavior and serve as regression oracles whether the
bug is present or has been fixed.

---

## Phase 2: Integration-Level Tests

**Prerequisites:**
- Data cache instantiated in `z_core_control_u.v` between MEM stage and `axil_master`
- LSU/control logic that consumes `request_refill` / `dirty_writeback_*` and
  drives `refill_complete` after AXI traffic
- `wstrb` support for SB/SH (Bug 6)
- `dcache_hit_pulse` wired to `mhpmcounter4` in `rtl/z_core_csr_file.v`

**File:** `tb/z_core_control_u_tb.sv` (new test tasks)
**Run:** `cd sim && make -f ../tb/Makefile run TB_FILE=z_core_control_u_tb.sv`

### Test Cases

| ID | Name | Key Check |
|----|------|-----------|
| T2.01 | Basic SW then LW (cache hit) | `check_reg`, `mhpmcounter4 >= 1` |
| T2.02 | Store-load with 4 NOPs | `check_reg` |
| T2.03 | Byte/halfword through cache | LB/LBU/LH/LHU correctness (Bug 6) |
| T2.04 | Cache miss + AXI refill | First load misses, second hits |
| T2.05 | Dirty eviction writeback verification | `check_mem` on victim's addr |
| T2.06 | Multi-address stress loop (64 addrs) | x15 error count == 0 |
| T2.07 | Cache + branch predictor (20-iter loop) | accumulated value + counters |
| T2.08 | Cache + timer interrupt | cache coherent after MRET |
| T2.09 | D-cache performance counter | `mhpmcounter4` matches expected hits |
| T2.10 | Mixed I-cache + D-cache (100-iter loop) | both counters non-zero, independent |

### Integration point in `z_core_control_u.v`

```
MEM stage
  ex_mem_alu_result  → cache addr
  ex_mem_rs2_data    → cache data_in
  ex_mem_is_load     → cache cs (or load|store)
  ex_mem_is_store    → cache wen
         ↓
  z_core_data_cache
         ↓ hit:                cache_hit=1, data_out → mem_rdata, mem_ready=1
         ↓ request_refill=1:   LSU forwards to axil_master; if
                               dirty_writeback_enabled=1, first issues
                               an AXI write of dirty_writeback_data.
                               After AXI read returns, drives
                               refill_complete=1 with the fetched word.
```

---

## Verification Summary

| Phase | Command | Gate |
|-------|---------|------|
| Compile check | `make compile TB_FILE=z_core_data_cache_tb.sv` | Anytime |
| Lint | `make lint` | Anytime |
| Unit tests | `make run TB_FILE=z_core_data_cache_tb.sv` | Phase 1 |
| Integration tests | `make run TB_FILE=z_core_control_u_tb.sv` | Phase 2 |
| Full regression | `make all` | After Phase 2 |

---

## Related Files

| File | Role |
|------|------|
| `rtl/z_core_data_cache.v` | Cache RTL under test |
| `rtl/z_core_control_u.v` | Pipeline — integration point |
| `rtl/z_core_csr_file.v` | `mhpmcounter4` wiring |
| `rtl/flist.vc` | RTL file list |
| `tb/z_core_data_cache_tb.sv` | Unit testbench |
| `tb/z_core_instr_cache_tb.sv` | Reference TB (style guide) |
| `tb/z_core_control_u_tb.sv` | System TB (Phase 2 tests added here) |
| `tb/Makefile` | Build system |
