# Zicsr Extension & M-Mode Exception/Interrupt Architecture

## Overview

Z-Core implements the **RISC-V Zicsr Extension** and a subset of the **Machine-Mode (M-mode) Privileged Architecture** (Privileged Spec v1.12). This enables:

- **CSR Register Access**: Atomic read-modify-write access to Control and Status Registers via 6 instruction variants.
- **Trap Handling Infrastructure**: Unified trap entry/exit logic for both **Exceptions** (synchronous) and **Interrupts** (asynchronous).
- **Performance Counters**: Hardware cycle and retired instruction counters (`mcycle`, `minstret`).

> [!NOTE]
> Z-Core implements **M-mode only**. Exceptions (Illegal Instruction, ECALL, EBREAK, Misaligned Access) and Interrupts (External, Software, Timer) are fully supported and validated via RISCOF.

## Zicsr Instructions

The Zicsr extension adds 6 CSR instructions. All perform an **atomic read-modify-write** on the addressed CSR: the old value is read into `rd`, and a new value is written based on the operation and source operand.

| Instruction | Encoding (funct3) | Operation | Source |
|-------------|-------------------|-----------|--------|
| `CSRRW rd, csr, rs1` | 001 | Write `rs1` to CSR | Register |
| `CSRRS rd, csr, rs1` | 010 | Set bits from `rs1` in CSR | Register |
| `CSRRC rd, csr, rs1` | 011 | Clear bits from `rs1` in CSR | Register |
| `CSRRWI rd, csr, zimm` | 101 | Write `zimm` to CSR | 5-bit Immediate |
| `CSRRSI rd, csr, zimm` | 110 | Set bits from `zimm` in CSR | 5-bit Immediate |
| `CSRRCI rd, csr, zimm` | 111 | Clear bits from `zimm` in CSR | 5-bit Immediate |

### Write Suppression (Per RISC-V Spec §2.8)

To avoid unnecessary side effects on read-only CSRs:
- **CSRRS/CSRRC**: If `rs1 = x0`, the write is suppressed (read-only access).
- **CSRRSI/CSRRCI**: If `zimm = 0`, the write is suppressed.
- **CSRRW/CSRRWI**: Always write, regardless of operand value.

### System Instructions

| Instruction | Encoding | Description |
|-------------|----------|-------------|
| `MRET` | `0x30200073` | Return from Machine-mode trap handler |
| `ECALL` | `0x00000073` | Environment call (triggers exception, cause=11) |
| `EBREAK` | `0x00100073` | Breakpoint (triggers exception, cause=3) |

## CSR Register Map

All CSRs are accessed through the 12-bit CSR address field in the instruction (`inst[31:20]`).

### Machine Information Registers

| Address | Name | Access | Description |
|---------|------|--------|-------------|
| `0x301` | `misa` | RO | ISA description — hardwired to RV32IM (`0x40001100`) |

### Machine Trap Setup

| Address | Name | Access | Description |
|---------|------|--------|-------------|
| `0x300` | `mstatus` | RW | Machine status (global interrupt enable) |
| `0x304` | `mie` | RW | Machine interrupt enable |
| `0x305` | `mtvec` | RW | Machine trap vector base address |

### Machine Trap Handling

| Address | Name | Access | Description |
|---------|------|--------|-------------|
| `0x340` | `mscratch` | RW | Scratch register for trap handlers |
| `0x341` | `mepc` | RW | Machine exception program counter |
| `0x342` | `mcause` | RW | Machine trap cause |
| `0x343` | `mtval` | RW | Machine trap value (faulting instruction or address) |
| `0x344` | `mip` | RO | Machine interrupt pending |

### Machine Counters

| Address | Name | Access | Description |
|---------|------|--------|-------------|
| `0xB00` | `mcycle` | RO | Cycle counter (low 32 bits) |
| `0xB80` | `mcycleh` | RO | Cycle counter (high 32 bits) |
| `0xB02` | `minstret` | RO | Retired instruction counter (low 32 bits) |
| `0xB82` | `minstreth` | RO | Retired instruction counter (high 32 bits) |

## Register Bit Fields

### mstatus (0x300)

| Bits | Field | Reset | Description |
|------|-------|-------|-------------|
| 31:13 | — | 0 | Reserved |
| 12:11 | MPP | `2'b11` | Machine Previous Privilege (hardwired to M-mode) |
| 10:8 | — | 0 | Reserved |
| 7 | MPIE | 0 | Machine Previous Interrupt Enable |
| 6:4 | — | 0 | Reserved |
| 3 | MIE | 0 | **Machine Interrupt Enable** (global) |
| 2:0 | — | 0 | Reserved |

### mie (0x304) — Interrupt Enable

| Bit | Field | Description |
|-----|-------|-------------|
| 11 | MEIE | Machine External Interrupt Enable |
| 7 | MTIE | Machine Timer Interrupt Enable |
| 3 | MSIE | Machine Software Interrupt Enable |

All other bits are hardwired to 0.

### mip (0x344) — Interrupt Pending

| Bit | Field | Source | Description |
|-----|-------|--------|-------------|
| 11 | MEIP | `meip` port | Machine External Interrupt Pending |
| 7 | MTIP | `mtip` port | Machine Timer Interrupt Pending |
| 3 | MSIP | `msip` port | Machine Software Interrupt Pending |

The `mip` register is **read-only** — pending bits are driven directly by the external interrupt input pins.

### mtvec (0x305) — Trap Vector

| Bits | Field | Description |
|------|-------|-------------|
| 31:2 | BASE | Trap handler base address (4-byte aligned) |
| 1:0 | MODE | Hardwired to `2'b00` (**Direct Mode**: all traps jump to BASE) |

### mcause (0x342) — Trap Cause

| Bits | Field | Description |
|------|-------|-------------|
| 31 | Interrupt | 1 = interrupt, 0 = exception |
| 30:0 | Code | Cause code |

**Supported Trap Causes:**

| Interrupt | Code | Name | Description |
|-----------|------|------|-------------|
| 1 | 11 | Machine External Interrupt | `meip` asserted |
| 1 | 7 | Machine Timer Interrupt | `mtip` asserted |
| 1 | 3 | Machine Software Interrupt | `msip` asserted |
| 0 | 0 | Instruction Address Misaligned | Branch/Jump to non-4-byte boundary |
| 0 | 2 | Illegal Instruction | Invalid opcode detected (excluding `0x0`) |
| 0 | 3 | Breakpoint | `EBREAK` instruction executed |
| 0 | 4 | Load Address Misaligned | LW/LH/LHU to non-naturally aligned address |
| 0 | 6 | Store/AMO Address Misaligned | SW/SH to non-naturally aligned address |
| 0 | 11 | Environment Call | `ECALL` instruction executed |

> [!NOTE]
> `0x00000000` (all-zeros instruction) acts as a NOP (architectural hint) and does **not** trigger an illegal instruction exception. This prevents infinite trap loops when executing uninitialized memory.

## Trap Handling Logic

### Trap Priority

The core prioritizes traps in the following order (highest first):

1. **Exceptions** (Synchronous): Misaligned Access > Illegal Instruction > ECALL > EBREAK.
2. **Interrupts** (Asynchronous): External > Software > Timer.

### Trap Entry Sequence

When a trap occurs, the hardware performs the following **atomically in one cycle**:

```
1. mepc   ← PC of the faulting instruction (Exceptions)
             OR PC of the next instruction (Interrupts)
2. mcause ← {interrupt_bit, cause_code}
3. mtval  ← Faulting instruction (Illegal Inst)
             OR Faulting address (Misaligned Access)
             OR PC of the instruction (EBREAK)
             OR 0 (ECALL, Interrupts)
4. mstatus.MPIE ← mstatus.MIE      (save current enable)
5. mstatus.MIE  ← 0                (disable interrupts)
6. PC     ← mtvec                   (jump to handler)
7. Pipeline flush                    (squash in-flight instructions)
```

### MRET Sequence

The `MRET` instruction returns from the trap handler:

```
1. mstatus.MIE  ← mstatus.MPIE     (restore interrupt enable)
2. mstatus.MPIE ← 1                 (set MPIE to 1)
3. PC           ← mepc              (return to interrupted code)
4. Pipeline flush                    (squash delay slot)
```

## Pipeline Integration

### CSR Instructions in the Pipeline

CSR instructions flow through the standard 5-stage pipeline:

| Stage | CSR Action |
|-------|------------|
| **IF** | Fetch CSR instruction |
| **ID** | Decode: extract `csr_addr`, `csr_zimm`, detect `is_csr`/`is_mret`. Propagate to ID/EX registers. |
| **EX** | CSR read-modify-write executes. Old CSR value → `ex_result` (for rd). New value written to CSR file. |
| **MEM** | CSR result passes through (no memory access). |
| **WB** | CSR read value written to register file `rd`. |

### Trap/MRET Pipeline Flush

When a trap or MRET occurs, the pipeline is flushed identically to a branch:

- `if_id_valid` is cleared (squash instruction in decode)
- `id_ex` is bubbled (squash instruction in execute)
- Fetch buffer is invalidated
- PC is redirected to `mtvec` (trap) or `mepc` (MRET)

**PC redirect priority** (highest first):
```
trap_enter → mtvec  >  MRET → mepc  >  JALR → jalr_target  >  branch → branch_target
```

## Module Interface

### CSR File (`z_core_csr_file`)

```verilog
module z_core_csr_file #(
    parameter DATA_WIDTH = 32
) (
    input  wire                  clk,
    input  wire                  rstn,

    // CSR Read-Modify-Write Interface
    input  wire [11:0]           csr_addr,        // CSR address
    input  wire [DATA_WIDTH-1:0] csr_write_data,  // Data to write
    input  wire                  csr_wen,          // Write enable
    output wire [DATA_WIDTH-1:0] csr_read_data,   // Read data (old value)

    // Trap Interface
    input  wire                  trap_enter,       // Trap entry pulse
    input  wire [DATA_WIDTH-1:0] trap_mepc,        // PC to save
    input  wire [DATA_WIDTH-1:0] trap_mcause,      // Cause code
    input  wire [DATA_WIDTH-1:0] trap_mtval,       // Trap value (insn or addr)
    input  wire                  mret_exec,        // MRET execution pulse

    // External Interrupt Inputs
    input  wire                  meip,             // External interrupt
    input  wire                  mtip,             // Timer interrupt
    input  wire                  msip,             // Software interrupt

    // Performance Counter
    input  wire                  instret_pulse,    // Instruction retired

    // Status Outputs
    output wire                  mstatus_mie,      // Global interrupt enable
    output wire [DATA_WIDTH-1:0] mtvec_out,        // Trap vector
    output wire [DATA_WIDTH-1:0] mepc_out,         // Exception PC
    output wire                  irq_pending,      // Any interrupt pending
    output wire                  mie_meie_out,     // External IRQ enable
    output wire                  mie_mtie_out,     // Timer IRQ enable
    output wire                  mie_msie_out      // Software IRQ enable
);
```

## Usage Examples

### 1. Setting Up a Trap Handler

```asm
# Set trap handler address
la   t0, trap_handler       # Load handler address
csrw mtvec, t0              # Write to mtvec

# Enable timer interrupt
li   t0, 0x80               # Bit 7 = MTIE
csrw mie, t0                # Enable timer interrupt in mie

# Enable global interrupts
csrsi mstatus, 0x8          # Set MIE bit (bit 3) in mstatus
```

### 2. Trap Handler

```asm
trap_handler:
    csrrw sp, mscratch, sp   # Swap sp with mscratch (save user sp)

    # Save context (caller-saved registers)
    addi sp, sp, -64
    sw   ra, 0(sp)
    sw   t0, 4(sp)
    sw   t1, 8(sp)
    # ... save more registers as needed ...

    # Read cause
    csrr t0, mcause          # t0 = mcause
    # Bit 31 = 1 for interrupt, bits 30:0 = cause code
    blt  t0, x0, is_interrupt # If MSB set, it's an interrupt

is_exception:
    # Handle exception (ECALL, Illegal Inst, etc.)
    # IMPORTANT: Must advance mepc by 4 for synchronous exceptions!
    csrr t1, mepc
    addi t1, t1, 4
    csrw mepc, t1
    j    restore_context

is_interrupt:
    # Handle interrupt (Timer, External, etc.)
    # No need to advance mepc (returns to next instruction)
    j    restore_context

restore_context:
    # Restore context
    lw   ra, 0(sp)
    lw   t0, 4(sp)
    lw   t1, 8(sp)
    addi sp, sp, 64

    csrrw sp, mscratch, sp   # Restore user sp
    mret                      # Return from trap
```

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| M-mode only | Simplifies implementation; sufficient for embedded/bare-metal use |
| Combined Trap Logic | Unified logic for exceptions and interrupts reduces area |
| Direct mtvec mode | Vectored mode not needed for single-core embedded; simpler dispatch |
| `0x00000000` as NOP | Treats uninitialized memory as NOPs instead of illegal instructions to prevent trap loops |
| Single-cycle CSR RMW | No pipeline stall needed; CSR file does combinational read, sequential write |

## Verification Strategy Decisions (Exceptions/Interrupts)

### Testbench Architecture Decision

Use a **hybrid strategy**:
- Keep `tb/z_core_control_u_tb.sv` as the system-level regression/smoke suite.
- Add a new focused trap verification bench (recommended: `tb/z_core_trap_tb.sv`) for deep exception/interrupt coverage.

Rationale:
- `z_core_control_u_tb.sv` is already large and broad; adding all trap corner cases there reduces maintainability.
- Trap behavior needs tight control of asynchronous stimuli (`meip`, `mtip`, `msip`) and cycle-accurate checks of CSR side effects.
- Dedicated trap tests should run fast and fail with clear cause-specific diagnostics.

### Specification-Driven Verification Scope

The trap-focused suite should explicitly verify:
- **Exception causes**: Illegal instruction (2), Breakpoint (3), ECALL from M-mode (11).
- **Interrupt causes**: MSI (3), MTI (7), MEI (11) with `mcause[31]=1`.
- **Priority behavior** when multiple interrupts are pending simultaneously (MEI > MSI > MTI).
- **Trap entry semantics**:
  - `mepc` captures the faulting PC for synchronous exceptions.
  - `mepc` captures the next instruction boundary PC for interrupts.
  - `mstatus.MPIE <- MIE`, then `mstatus.MIE <- 0`.
  - `pc <- mtvec` (direct mode).
- **MRET semantics**:
  - `pc <- mepc`
  - `mstatus.MIE <- MPIE`
  - `mstatus.MPIE <- 1`
- **Masking/gating**:
  - Interrupt must not be taken when global `mstatus.MIE=0`.
  - Interrupt must not be taken when corresponding `mie` bit is 0.
- **CSR behavior constraints**:
  - `mip` is read-only and reflects pins.
  - CSR write suppression rules for CSRRS/CSRRC with zero source and CSRRSI/CSRRCI with zero immediate.

### Planned Implementation Phases

1. **Phase 1 - Base directed trap tests**
   - Re-home and tighten current exception tests.
   - Add first interrupt tests per source (MSI/MTI/MEI) with deterministic timing and handler signature checks.

2. **Phase 2 - Priority and masking matrix**
   - Add matrix tests for (`mstatus.MIE`, `mie`, pending inputs).
   - Add simultaneous pending-source tests to prove prioritization.

3. **Phase 3 - Robustness and hazard-oriented scenarios**
   - Back-to-back trap events.
   - Interrupt arrival during/near CSR writes and branch redirects.
   - MRET return-path correctness under repeated trap entry/exit.

4. **Phase 4 - Regression integration**
   - Keep 1-2 smoke trap tests in `z_core_control_u_tb.sv`.
   - Run full trap matrix in `z_core_trap_tb.sv` as a separate, fast-targeted CI stage.

### Pass/Fail Criteria

Each trap test should check all of the following:
- Final architectural state (`pc`, selected GPRs, memory signatures).
- CSR state (`mstatus`, `mie`, `mip`, `mtvec`, `mepc`, `mcause`, `mtval` when applicable).
- Counter sanity (`mcycle`, `minstret`) with expected qualitative behavior (no deadlock/livelock).

### Trap TB Implementation Decisions

- Dedicated trap TB file: `tb/z_core_trap_tb.sv`.
- Interrupt sources are driven directly from TB pins (`meip`, `mtip`, `msip`) for deterministic, cycle-controlled stimulus.
- A shared trap handler is installed at `mtvec=0x80` and logs fixed-size 16-byte records:
  - `[0] mcause`, `[+4] mepc (or mepc+4 for exceptions)`, `[+8] mtval`, `[+12] mstatus`.
- Exception tests use a spec-oriented handler path that advances `mepc` only for synchronous exceptions (not interrupts).
- Priority and back-to-back tests use level-held interrupt pulses where needed to avoid missing events during handler latency.

## Misaligned Memory Access Handling

Z-Core implements strict alignment checks in the **Execute (EX)** stage. Any misaligned access triggers an immediate pipeline flush and trap entry.

| Instruction Type | Alignment Requirement | mcause |
|------------------|-----------------------|--------|
| **Branch/Jump**  | 4-byte boundary (target[1:0] == 0) | 0 (Instruction Misaligned) |
| **LW**           | 4-byte boundary (addr[1:0] == 0)   | 4 (Load Misaligned) |
| **LH / LHU**     | 2-byte boundary (addr[0] == 0)     | 4 (Load Misaligned) |
| **SW**           | 4-byte boundary (addr[1:0] == 0)   | 6 (Store Misaligned) |
| **SH**           | 2-byte boundary (addr[0] == 0)     | 6 (Store Misaligned) |

> [!IMPORTANT]
> When a misaligned exception occurs, `mtval` is loaded with the **faulting virtual address** that caused the exception, assisting the trap handler in emulating the access if desired.

## Performance Characteristics (Dual-Port Cache)

The trap handling sub-system is optimized for low-latency entry and exit. By utilizing a **Dual-Port Instruction Cache**, Z-Core completely eliminates the fetcher stalls that previously occurred during cache-miss fill cycles.

- **Zero-Stall Traps**: The fetcher can redirect to the trap handler (`mtvec`) or return from it (`mepc`) in a single cycle, even if a memory-to-cache fill is concurrently finishing for a previous instruction.
- **Concurrent Fill/Fetch**: If a trap occurs while the memory system is populating the cache with instruction `N`, the fetcher can simultaneously read the trap handler's first instruction from Port A, restoring peak single-cycle throughput.

## Compliance Status (RISCOF)

Z-Core is fully compliant with the **RISC-V Privilege Architecture (M-mode)** as verified by the official RISCOF framework.

| Suite | Status | Total Tests |
|-------|--------|-------------|
| **RV32I Base Integer** | <font color="green">PASSED</font> | 48 |
| **RV32M Multiply/Divide** | <font color="green">PASSED</font> | 45 |
| **Zicsr (Privilege)** | <font color="green">PASSED</font> | 16 |

> [!NOTE]
> All 109 architectural tests pass with 100% success rate, including the robust `misalign` and `ebreak` test suites.

