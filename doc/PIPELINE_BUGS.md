# Z-Core Pipeline Timing Bugs: An Educational Guide

This document captures the timing bugs found during development of the Z-Core 5-stage RISC-V pipeline. These are common pitfalls when designing pipelined processors and serve as educational examples for future reference.

---

## Table of Contents

1. [Overview](#overview)
2. [Bug 1: Instruction Replay (11x Execution)](#bug-1-instruction-replay-11x-execution)
3. [Bug 2: Fetch PC Mismatch After Flush](#bug-2-fetch-pc-mismatch-after-flush)
4. [Bug 3: Old Fetch Overlapping With New Fetch](#bug-3-old-fetch-overlapping-with-new-fetch)
5. [Bug 4: Load Data Timing Issue](#bug-4-load-data-timing-issue)
6. [Bug 5: AXI Master Read Timing](#bug-5-axi-master-read-timing)
7. [Bug 6: Arbiter Race Condition](#bug-6-arbiter-race-condition)
8. [Key Lessons Learned](#key-lessons-learned)

---

## Overview

When building a pipelined processor with a multi-cycle memory interface (like AXI-Lite), timing coordination becomes critical. The core challenge is that:

1. **Memory operations take multiple cycles** - Unlike single-cycle designs, reads/writes don't complete instantly
2. **Pipeline stages advance independently** - When one stage stalls, others may continue
3. **Control flow changes (branches/jumps) must flush the pipeline** - Instructions already in-flight must be discarded

These six bugs illustrate common timing issues that arise when these factors interact incorrectly.

---

## Bug 1: Instruction Replay (11x Execution)

### Symptom
Every instruction was executing 11 times instead of once. The `x10` counter in branch tests showed 22 instead of 8.

### Root Cause
The IF/ID pipeline register's `if_id_valid` flag was never cleared when an instruction was consumed by the decode stage.

**What happened:**
1. Instruction arrived in IF/ID with `if_id_valid = 1`
2. Decode stage loaded instruction into ID/EX
3. `if_id_valid` stayed 1 (no one cleared it!)
4. Next cycle: Decode stage loaded the SAME instruction again
5. This repeated for ~11 cycles until the next fetch completed

### The Faulty Mental Model
```
WRONG: "The decode stage reads IF/ID and advances it"
RIGHT: "The decode stage reads IF/ID, and someone must explicitly mark it consumed"
```

### The Fix
Added explicit clearing of `if_id_valid` when the instruction is consumed and no replacement is arriving:

```verilog
// Clear if_id_valid when instruction is consumed by decode stage
// (unless a new instruction is arriving to replace it)
if (!stall && if_id_valid && 
    !(!stall && fetch_buffer_valid) && 
    !(fetch_wait && mem_ready && !stall && !fetch_buffer_valid)) begin
    if_id_valid <= 1'b0;  // Instruction consumed, mark empty
end
```

### Lesson Learned
> **In a pipelined design, every pipeline register must have clear ownership and explicit valid/invalid transitions. Never assume "reading" a register consumes it.**

---

## Bug 2: Fetch PC Mismatch After Flush

### Symptom
After a branch was taken, the target instruction was associated with the skip instruction's address. PC=0x1C showed the instruction actually from address 0x18.

### Root Cause
When a flush occurred during an in-flight memory read:
1. A fetch was started for address 0x18 (next sequential instruction)
2. Branch resolved, flush redirected PC to 0x1C
3. Memory read for 0x18 completed
4. Code used current PC (now 0x1C) to record the instruction
5. Result: Instruction from 0x18 was tagged as PC=0x1C

**The problem:** The code used `PC` when the fetch completed, not the address that was actually requested.

### Timeline Diagram
```
Cycle N:   Fetch start for PC=0x18
Cycle N+1: AXI read in progress, PC=0x18
Cycle N+2: Branch resolves, FLUSH! PC <- 0x1C
Cycle N+3: AXI read completes, data from 0x18
           WRONG: if_id_pc <= PC (which is 0x1C!)
           RIGHT: if_id_pc <= fetch_pc (saved 0x18)
```

### The Fix
Track the PC separately when a fetch starts:

```verilog
// When starting fetch
fetch_wait <= 1'b1;
fetch_pc <= PC;  // Capture the address we're fetching from

// When fetch completes
if_id_pc <= fetch_pc;  // Use captured PC, not current PC
PC <= fetch_pc + 4;    // Advance from correct address
```

### Lesson Learned
> **When operations span multiple cycles, capture all relevant state at the START. Never rely on signals that may change during the operation.**

---

## Bug 3: Old Fetch Overlapping With New Fetch

### Symptom
Same as Bug 2 - wrong instruction at target address after branch.

### Root Cause
Even after capturing `fetch_pc`, the old AXI transaction could overlap with a new fetch:

1. Fetch for 0x18 started, `fetch_wait = 1`
2. Flush occurred: `fetch_wait <= 0` (cancel fetch)
3. New fetch for 0x1C started: `fetch_wait <= 1`, `fetch_pc <= 0x1C`
4. Old AXI read completes: `mem_ready = 1`
5. Condition `fetch_wait && mem_ready` is TRUE (1 && 1)
6. Old data stored with new `fetch_pc = 0x1C`!

### Timeline Diagram
```
Cycle N:   Old fetch in progress (addr=0x18)
Cycle N+1: FLUSH! fetch_wait <= 0, PC <= 0x1C
Cycle N+2: New fetch starts! fetch_wait <= 1, fetch_pc <= 0x1C
           BUT: AXI master still has old read active!
Cycle N+3: Old read completes, mem_ready = 1
           fetch_wait = 1 (new fetch), fetch_pc = 0x1C
           WRONG: We process old data with new PC!
```

### The Fix
Check `mem_busy` before starting a new fetch - wait for the AXI master to return to IDLE:

```verilog
if (!fetch_wait && !mem_op_pending && !mem_busy &&  // <-- Added !mem_busy
    !(ex_mem_valid && (ex_mem_is_load || ex_mem_is_store)) && 
    (!fetch_buffer_valid || !stall)) begin
    // Safe to start new fetch
end
```

### Lesson Learned
> **When cancelling an asynchronous operation, ensure the underlying hardware has fully completed before starting a new operation. Use "busy" signals to track this.**

---

## Bug 4: Load Data Timing Issue

### Symptom
LW (load word) instructions returned data from the PREVIOUS load address. Load from address 256 returned 0, load from address 260 returned 42 (which was at 256).

### Root Cause
Classic sequential assignment timing issue:

```verilog
// Memory stage - sequential assignments
always @(posedge clk) begin
    mem_load_data <= mem_rdata;      // Captured on clock edge
end

// Writeback stage - also sequential
always @(posedge clk) begin
    mem_wb_result <= mem_load_data;  // Uses OLD mem_load_data!
end
```

Both use `<=` (non-blocking), so when `mem_ready` goes high:
- `mem_load_data` is assigned the NEW value (available next cycle)
- `mem_wb_result` reads the OLD value of `mem_load_data`

### The Fix
Make `mem_load_data` combinational so it's available immediately:

```verilog
// Combinational - available same cycle
reg [31:0] mem_load_data;
always @* begin
    case (ex_mem_funct3)
        3'b010: mem_load_data = mem_rdata;  // LW
        3'b000: // LB with sign extension...
        // etc.
    endcase
end
```

### Lesson Learned
> **In a pipeline, when two sequential blocks need to communicate on the same cycle, the source must be combinational, not registered. Alternatively, add a pipeline stage (extra cycle).**

---

## Bug 5: AXI Master Read Timing

### Symptom
Initial debugging showed `mem_rdata` had stale values when `mem_ready` was sampled.

### Root Cause
In `axil_master.v`, both `mem_rdata` and `mem_ready` were registered outputs assigned in the same always block:

```verilog
always @(posedge clk) begin
    if (m_axil_rvalid) begin
        mem_rdata <= m_axil_rdata;  // Registered
        mem_ready <= 1'b1;          // Also registered, same cycle!
    end
end
```

From the consumer's perspective, when they see `mem_ready = 1`:
- `mem_rdata` still has the OLD value (new value takes effect next cycle)

### The Fix
Add a `STATE_READ_DONE` state to ensure data is stable before asserting ready:

```verilog
STATE_READ_DATA: begin
    if (m_axil_rvalid) begin
        mem_rdata <= m_axil_rdata;  // Capture data
        state <= STATE_READ_DONE;    // Go to DONE, don't assert ready yet
    end
end

STATE_READ_DONE: begin
    mem_ready <= 1'b1;  // NOW assert ready - data is stable
    state <= STATE_IDLE;
end
```

### Lesson Learned
> **When a module produces both a "data" signal and a "valid" signal, ensure the data is stable BEFORE valid is asserted. This often requires an extra cycle/state.**

---

## Bug 6: Arbiter Race Condition

### Symptom
The same memory address was being fetched twice in a row.

### Root Cause
The arbiter logic was:

```verilog
if (fetch_wait && !mem_ready) begin
    mem_req = 1;  // Assert request
    mem_addr = PC;
end
```

When a fetch completed (`mem_ready = 1`):
1. Arbiter sees `fetch_wait = 1` (still - sequential update pending)
2. `!mem_ready` is false, so no new request... right?

Actually, the issue was the NEXT cycle:
1. `fetch_wait` was cleared (`fetch_wait <= 0`)
2. PC was advanced (`PC <= PC + 4`)
3. But in the brief window, the arbiter might see inconsistent state

### The Fix
Explicitly check `!mem_ready` to prevent any request while completing:

```verilog
end else if (fetch_wait && !mem_ready) begin
    mem_req_comb = 1'b1;
    mem_addr = fetch_pc;  // Also use fetch_pc instead of PC
end
```

### Lesson Learned
> **Combinational logic (arbiters, muxes) sees the CURRENT state of all signals. When registered signals are about to update, there's a brief window where combinational logic may make wrong decisions. Guard against this with explicit "completion" checks.**

---

## Key Lessons Learned

### 1. Pipeline Register Ownership
Every pipeline register needs:
- Clear ownership (who writes to it)
- Explicit valid/invalid transitions
- Awareness of stall and flush conditions

### 2. Multi-Cycle Operations Need State Capture
When an operation takes multiple cycles:
- Capture ALL relevant state at the START
- Use the captured state when the operation COMPLETES
- Never rely on signals that may change during execution

### 3. Registered vs Combinational Outputs
- **Registered outputs** are stable but delayed by one cycle
- **Combinational outputs** are immediate but may glitch
- Choose carefully based on timing requirements
- Use extra states/cycles when needed for stability

### 4. Busy Signals Are Essential
For any asynchronous operation:
- Track "busy" state explicitly
- Don't start new operations until previous ones complete
- Consider what happens if an operation is cancelled mid-flight

### 5. The Two-Assignment Rule
In Verilog, when you see:
```verilog
A <= B;   // Sequential
C <= A;   // Sequential, reads OLD A
```
Signal `C` gets the OLD value of `A`, not the new one being assigned.

To get immediate propagation, `B` or an intermediate must be combinational.

---

## Debugging Techniques That Helped

1. **Timestamped Debug Output**: Adding `$time` to all debug prints made it possible to trace exact cycle-by-cycle behavior.

2. **Tracking Valid Bits**: Logging `if_id_valid`, `id_ex_valid`, etc. showed exactly when instructions were present in each stage.

3. **Instruction Commit Tracing**: Logging every register write with its source PC revealed duplicate/missing commits.

4. **Memory Bus Tracing**: Logging AXI master state, addresses, and data showed timing mismatches.

5. **Focused Filtering**: Using `grep` with specific patterns to filter massive debug output to relevant events.

---

## Summary Table

| Bug | Category | Impact | Key Fix |
|-----|----------|--------|---------|
| Instruction Replay | Pipeline Control | 11x execution | Clear `if_id_valid` on consume |
| PC Mismatch | State Capture | Wrong PC on target | Track `fetch_pc` separately |
| Fetch Overlap | Async Completion | Old data, new PC | Check `!mem_busy` |
| Load Timing | Register vs Combo | Off-by-one loads | Combinational `mem_load_data` |
| AXI Ready Timing | Output Stability | Stale data | `STATE_READ_DONE` |
| Arbiter Race | Combinational Race | Duplicate fetches | Gate with `!mem_ready` |

---

*Document created during Z-Core development for educational reference.*
