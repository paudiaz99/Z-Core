# Z-Core Data Cache Verification Plan

## Cache Architecture

`rtl/z_core_data_cache.v` — 2-way set-associative, write-back, write-allocate.

| Parameter | Value |
|-----------|-------|
| Total entries | 1024 words (2 ways × 512 sets) |
| Sets (CACHE_DEPTH) | 512 |
| Index bits | 9 (`addr[10:2]`) |
| Tag bits | 21 (`addr[31:11]`) |
| Byte offset | `addr[1:0]` (ignored — word-granularity) |
| Write policy | Write-back, write-allocate |
| Replacement | 1-bit LRU per index |
| Eviction | External signal handshake (`eviction_complete`) |

### Port Summary

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `clk`, `rstn` | in | 1 | Clock, active-low reset |
| `wen` | in | 1 | Write enable (1=write, 0=read) |
| `addr` | in | 32 | Word-aligned address |
| `data_in` | in | 32 | Write data |
| `eviction_complete` | in | 1 | External: dirty line flushed to memory |
| `data_out` | out | 32 | Read result (registered, 1-cycle latency) |
| `cache_hit` | out | 1 | Hit indicator (registered, 1-cycle latency) |
| `wait_for_eviction_complete` | out | 1 | Stall: waiting for dirty writeback |

**Important:** `cache_hit` and `data_out` are registered — check outputs on the cycle **after** applying stimulus.

---

## Known Bugs

| # | Location | Description | Severity |
|---|----------|-------------|----------|
| 1 | Line 27 | `valid_bits` missing `[CACHE_DEPTH-1:0]` dimension — only 2 bits | Compile/functional |
| 2 | Line 119–126 | Read path does not update LRU bits | Functional |
| 3 | Line 46 | `cache_hit` declared as both `wire` and `output reg` | Compile error |
| 4 | Line 123 | Read-miss returns 0 with no memory-fetch mechanism | Missing feature |
| 5 | Line 118 | `else (!wen)` — syntax error | Compile error |
| 6 | Lines 88–97 | Eviction path does not expose dirty data/address to external logic | Missing feature |
| 7 | Port list | No `wstrb` port for byte/halfword writes (SB/SH) | Missing feature |

Bugs 1, 3, 5 are **compile blockers** — fixed before any test can run.

---

## Phase 1: Compile-Blocker Fixes (prerequisite)

Fix in `rtl/z_core_data_cache.v`:
1. Line 27: `reg valid_bits [ASSOCIATIVITY-1:0];` → `reg valid_bits [ASSOCIATIVITY-1:0] [CACHE_DEPTH-1:0];`
2. Line 46: rename `wire cache_hit` → `wire cache_hit_comb` (avoid conflict with `output reg cache_hit`)
3. Line 118: `else (!wen) begin` → `else begin`
4. Update all uses of old `cache_hit` wire inside the always block to `cache_hit_comb`

Also: add `z_core_data_cache.v` to `rtl/flist.vc`.

---

## Phase 2: Unit-Level Testbench

**File:** `tb/z_core_data_cache_tb.sv`  
**Run:** `cd sim && make -f ../tb/Makefile run TB_FILE=z_core_data_cache_tb.sv [SIM=iverilog]`

### Test Cases

| ID | Name | Bugs Caught |
|----|------|-------------|
| T1.01 | Reset clears all state | Bug 1 (valid_bits) |
| T1.02 | Read miss on empty cache | Bug 5 (syntax) |
| T1.03 | Write-allocate + read hit | Bug 1, 3, 5 |
| T1.04 | Write-then-read back-to-back | Bug 3 (wire/reg) |
| T1.05 | Read-then-write same address | — |
| T1.06 | Same tag, different indices | — |
| T1.07 | Overwrite existing data | — |
| T1.08 | Two-way fill (both sets at same index) | Bug 1 |
| T1.09 | Same index, different tags (3-way alias → eviction) | — |
| T1.10 | LRU replacement correctness | Bug 2 (LRU on reads) |
| T1.11 | Dirty eviction flow | Bug 6 (documents gap) |
| T1.12 | Eviction buffer stability (20-cycle stall) | — |
| T1.13 | Capacity stress — fill all 512 indices | Bug 1 |
| T1.14 | Hit-rate tracking (mixed 100-op sequence) | — |

**T1.10 note:** This test has two valid expected outcomes. With Bug 2 present, the read does not update LRU so the read-accessed way gets evicted. After Bug 2 is fixed, the opposite way (true LRU) gets evicted. The TB prints which behavior is observed without hard-failing, so it serves as a regression oracle for both states.

---

## Phase 3: Integration-Level Tests

**Prerequisites before Phase 3:**
- Data cache instantiated in `z_core_control_u.v` (between MEM stage and `axil_master`)
- Read-miss fill path implemented (Bug 4 fixed)
- Dirty-line eviction writeback to AXI implemented (Bug 6 fixed)
- `wstrb` port added (Bug 7 fixed)
- LRU updated on read hits (Bug 2 fixed)
- `dcache_hit_pulse` wired to `mhpmcounter4` in `rtl/z_core_csr_file.v`

**File:** `tb/z_core_control_u_tb.sv` (add new test tasks)  
**Run:** `cd sim && make -f ../tb/Makefile run TB_FILE=z_core_control_u_tb.sv`

### Test Cases

| ID | Name | Bugs Caught | Key Check |
|----|------|-------------|-----------|
| T2.01 | Basic SW then LW (cache hit) | — | `check_reg`, `mhpmcounter4 >= 1` |
| T2.02 | Store-load (no pipeline hazard, 4 NOPs) | — | `check_reg` |
| T2.03 | Byte/halfword through cache | Bug 7 (wstrb) | LB/LBU/LH/LHU correctness |
| T2.04 | Cache miss + AXI fill | Bug 4 (read-miss) | First load misses, second hits |
| T2.05 | Write-back verification | Bug 6 (eviction) | `check_mem` on evicted address |
| T2.06 | Multi-address stress loop (64 addrs) | — | x15 error count == 0 |
| T2.07 | Cache + branch predictor (20-iter loop) | — | Accumulated value + perf counters |
| T2.08 | Cache + timer interrupt | — | Cache coherent after MRET |
| T2.09 | D-cache performance counter | — | `mhpmcounter4 == 2` after 2 hits |
| T2.10 | Mixed I-cache + D-cache (100-iter loop) | — | Both counters non-zero, independent |

### Integration point in `z_core_control_u.v`

```
MEM stage
  ex_mem_alu_result  → cache addr
  ex_mem_rs2_data    → cache data_in
  mem_wstrb_r        → cache wstrb (new port)
  ex_mem_is_store    → cache wen
         ↓
  z_core_data_cache
         ↓ hit:  cache_hit=1, data_out → mem_rdata, assert mem_ready (1 cycle)
         ↓ miss: forward to axil_master; on completion fill cache + assert mem_ready
         ↓ eviction: write dirty line via axil_master before filling
```

---

## Bug Coverage Matrix

| Bug | T1 Tests | T2 Tests |
|-----|----------|----------|
| 1 — valid_bits dimension | T1.01, T1.03, T1.08, T1.13 | All (compile blocker) |
| 2 — LRU not updated on read | T1.10 | T2.05, T2.06 |
| 3 — wire/reg conflict | T1.04 (any test) | All (compile blocker) |
| 4 — no read-miss fill | T1.02 (documents) | T2.04 |
| 5 — syntax error | T1.02, T1.03 | All (compile blocker) |
| 6 — eviction writeback missing | T1.11 (documents) | T2.05 |
| 7 — no wstrb port | — | T2.03 |

---

## Verification Summary

| Phase | Command | Gate |
|-------|---------|------|
| Compile check | `make compile TB_FILE=z_core_data_cache_tb.sv` | After Phase 1 |
| Lint | `make lint` | After Phase 1 |
| Unit tests (14 checks) | `make run TB_FILE=z_core_data_cache_tb.sv` | Phase 2 |
| Integration tests (10 tests) | `make run TB_FILE=z_core_control_u_tb.sv` | Phase 3 |
| Full regression | `make all` | After Phase 3 |

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
| `tb/z_core_control_u_tb.sv` | System TB (Tier 2 tests added here) |
| `tb/Makefile` | Build system |
