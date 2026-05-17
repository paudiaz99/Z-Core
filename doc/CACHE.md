# Z-Core Caches

## Overview

Z-Core includes two parameterizable, 1-cycle latency caches designed to decouple the processor pipeline from AXI-Lite memory latency:
1. **Instruction Cache**: Direct-mapped, read-only cache integrated into the IF (Instruction Fetch) stage.
2. **Data Cache**: Single cycle 2-way set-associative, write-back, write-allocate cache integrated into the MEM (Memory) stage. Uses LRU policy to avoid potential conflicts.

---

## 1. Instruction Cache (`z_core_instr_cache.v`)

The Instruction Cache is designed for high-throughput sequential and branching instruction fetches, delivering 1 instruction per cycle.

### Architecture

| Parameter | Value |
|-----------|-------|
| Organization | Direct-mapped |
| Default Size | 4096 words (16 KB) |
| Sets (`CACHE_DEPTH`) | 4096 (configurable) |
| Line Size | 32 bits (1 word) |
| Latency | 1 cycle (synchronous read) |
| Replacement | Implicit (overwrite on index match) |

### Key Features
- **Atomic Storage**: Uses a single packed array `{tag, data}` enabling single inferred BRAM mapping.
- **Sideband Valid Bits**: Valid bits are stored in registers for cheap clear-on-reset capability.
- **RAW Bypass**: Safe Read-After-Write bypass. If a refill writes to the same index being read in the same cycle, the cache forwards the freshly-written data.

### Pipeline Integration (IF Stage)
The fetch FSM presents `addr_rd` combinationally from the next-PC multiplexer every cycle. The cache returns the lookup result (`data_out`, `valid_d`) on the next clock edge.
On a miss (`!valid_d`), the fetch stage stalls (`fetch_wait`), requests a 32-bit AXI read, and upon receiving the data, writes it into the cache via the `wen`, `addr_wr`, and `data_in` ports.

---

## 2. Data Cache (`z_core_data_cache.v`)

The Data Cache is a 2-way set-associative cache handling load/store memory operations. It significantly reduces stall cycles for memory-intensive workloads exhibiting data locality. The cache is built in a pipelined manner so that it can achieve single cycle throughput while maintaining synchronous reads and writes, enabling the synthesis to BRAM in FPGAs.

### Architecture

| Parameter | Value |
|-----------|-------|
| Organization | 2-way set-associative |
| Default Size | 8192 words (2 ways × 4096 sets, 32 KB) |
| Sets (`CACHE_DEPTH`) | 4096 (configurable) |
| Line Size | 32 bits (1 word) |
| Write Policy | Write-back, write-allocate |
| Replacement | LRU (1-bit per way) |
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
| `dirty_writeback_addr` | out | 32 | Drives miss `addr`|
| `dirty_writeback_data` | out | 32 | Victim line data to be written back |

**Important:** `cache_hit`, `data_out`, `request_refill`, `dirty_writeback_*` are all registered — they must be sampled on the cycle **after** applying stimulus.

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
1. Sampling `dirty_writeback_addr` / `_data` when `dirty_writeback_enabled=1`, issuing the AXI writeback, then
2. Reading the missed line from memory, then
3. Driving `addr=miss_addr`, `data_in=fetched/store_word`, `refill_complete=1` for one cycle to install the line.

## 3. Verification Plan

### Phase 1: Data Cache Unit-Level Testbench

**File:** `tb/z_core_data_cache_tb.sv`
**Run:** `cd sim && make -f ../tb/Makefile run TB_FILE=z_core_data_cache_tb.sv [SIM=iverilog]`

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
| T1.13 | LRU replacement correctness |
| T1.14 | Read-fill leaves dirty=1 |
| T1.15 | `dirty_writeback_addr` observation |
| T1.16 | Capacity stress (all 512 × 2) | depth |
| T1.17 | Hit-rate tracking | mixed sequence |
| T1.18 | `dirty_writeback_enabled` stickiness |
| T1.19 | `addr` stability contract during refill |
| T1.20 | No interlock on pending refill |

T1.13–T1.15, T1.18–T1.20 print `[INFO]` without hard-failing — they document RTL behavior and serve as regression oracles.

### Phase 2: Integration-Level Tests

**File:** `tb/z_core_control_u_tb.sv` (new test tasks)
**Run:** `cd sim && make -f ../tb/Makefile run TB_FILE=z_core_control_u_tb.sv`

These tests exercise both caches running concurrently within the pipeline.

| ID | Name | Key Check |
|----|------|-----------|
| T2.01 | Basic SW then LW (cache hit) | `check_reg`, `mhpmcounter4 >= 1` |
| T2.02 | Store-load with 4 NOPs | `check_reg` |
| T2.03 | Byte/halfword through cache | LB/LBU/LH/LHU correctness |
| T2.04 | Cache miss + AXI refill | First load misses, second hits |
| T2.05 | Dirty eviction writeback verification | `check_mem` on victim's addr |
| T2.06 | Multi-address stress loop (64 addrs) | x15 error count == 0 |
| T2.07 | Cache + branch predictor (20-iter loop) | accumulated value + counters |
| T2.08 | Cache + timer interrupt | cache coherent after MRET |
| T2.09 | D-cache performance counter | `mhpmcounter4` matches expected hits |
| T2.10 | Mixed I-cache + D-cache (100-iter loop) | both counters non-zero, independent |

### Verification Summary

| Phase | Command | Gate |
|-------|---------|------|
| Compile check | `make compile TB_FILE=z_core_data_cache_tb.sv` | Anytime |
| Unit tests | `make run TB_FILE=z_core_data_cache_tb.sv` | Phase 1 |
| Integration tests | `make run TB_FILE=z_core_control_u_tb.sv` | Phase 2 |
