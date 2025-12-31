# Z-Core Verification Documentation

## Overview

This document describes the verification strategy, test coverage, and results for the Z-Core RISC-V processor.

## Test Architecture

```
┌────────────────────────────────────────────────────────────────────────────┐
│                         Z-Core Test Environment                            │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    z_core_control_u_tb.sv                            │  │
│  │  ┌────────────────────────────────────────────────────────────────┐  │  │
│  │  │                    Test Orchestration                          │  │  │
│  │  │  - Program Loading (load_testN tasks)                          │  │  │
│  │  │  - CPU Reset Management                                        │  │  │
│  │  │  - Result Verification (check_reg, check_mem tasks)            │  │  │
│  │  │  - Pass/Fail Reporting                                         │  │  │
│  │  └────────────────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                    │                                       │
│                                    ▼                                       │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    Device Under Test (DUT)                           │  │
│  │  ┌────────────────────┐      AXI-Lite      ┌────────────────────┐    │  │
│  │  │  z_core_control_u  │◄──────────────────►│ axil_interconnect  │    │  │
│  │  │    (CPU Core)      │                    │                    │    │  │
│  │  └────────────────────┘                    └─────────┬──────────┘    │  │
│  │                                                      │               │  │
│  │                                          ┌───────────▼───────────┐   │  │
│  │                                          │   AXI-Lite Slaves     │   │  │
│  │                                          │ - Memory (64KB)       │   │  │
│  │                                          │ - UART (Wrapper)      │   │  │
│  │                                          │ - GPIO (Wrapper)      │   │  │
│  │                                          └───────────────────────┘   │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                            │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

## Test Suites

### Test 1: Arithmetic Operations
**Purpose:** Verify basic integer arithmetic

| Instruction | Test Case | Expected |
|-------------|-----------|----------|
| ADDI | x2 = 0 + 10 | 10 |
| ADDI | x3 = 0 + 7 | 7 |
| ADD | x4 = x2 + x3 | 17 |
| SUB | x5 = x2 - x3 | 3 |
| ADDI | x6 = 0 + (-5) | -5 |
| ADD | x7 = x4 + x6 | 12 |

### Test 2: Logical Operations
**Purpose:** Verify bitwise operations

| Instruction | Test Case | Expected |
|-------------|-----------|----------|
| AND | 0xFF & 0x0F | 0x0F |
| OR | 0xFF \| 0x0F | 0xFF |
| XOR | 0xFF ^ 0x0F | 0xF0 |
| ANDI | 0xFF & 0x55 | 0x55 |
| ORI | 0x00 \| 0xAA | 0xAA |
| XORI | 0xAA ^ 0xFF | 0x55 |

### Test 3: Shift Operations
**Purpose:** Verify all shift variants

| Instruction | Test Case | Expected |
|-------------|-----------|----------|
| SLLI | 1 << 4 | 16 |
| SLLI | 1 << 8 | 256 |
| SRLI | 0xFFFFFFFF >>> 24 | 0xFF |
| SRAI | 0xFFFFFFFF >> 24 | 0xFFFFFFFF |
| SLL | 1 << 8 (reg) | 256 |
| SRL | 0xFFFFFFFF >>> 8 (reg) | 0x00FFFFFF |
| SRA | 0xFFFFFFFF >> 8 (reg) | 0xFFFFFFFF |

### Test 4: Memory Operations
**Purpose:** Verify load/store functionality via AXI

| Instruction | Test Case | Expected |
|-------------|-----------|----------|
| SW | Store 42 to addr 256 | mem[256] = 42 |
| SW | Store 100 to addr 260 | mem[260] = 100 |
| LW | Load from addr 256 | x4 = 42 |
| LW | Load from addr 260 | x5 = 100 |
| SW | Store 142 to addr 264 | mem[264] = 142 |

### Test 5: Compare Operations
**Purpose:** Verify signed and unsigned comparisons

| Instruction | Test Case | Expected |
|-------------|-----------|----------|
| SLT | 10 < 20 (signed) | 1 |
| SLT | 20 < 10 (signed) | 0 |
| SLTI | 10 < 15 (signed imm) | 1 |
| SLTI | 10 < 5 (signed imm) | 0 |
| SLTU | 0xFFFFFFFF < 10 | 0 |
| SLTIU | 10 < 100 (unsigned imm) | 1 |
| SLTIU | 0xFFFFFFFF < 1 | 0 |
| SLTU | 10 < 0xFFFFFFFF | 1 |

### Test 6: Upper Immediate
**Purpose:** Verify LUI and AUIPC

| Instruction | Test Case | Expected |
|-------------|-----------|----------|
| LUI | Load 0x12345 << 12 | 0x12345000 |
| ADDI | Add lower bits | 0x12345678 |
| AUIPC | PC + 0 | 8 (instruction address) |
| LUI | Load 0xFFFFF << 12 | 0xFFFFF000 |

### Test 7: Integration (Fibonacci)
**Purpose:** Verify multi-instruction sequences

```
Computes Fibonacci sequence: 1, 1, 2, 3, 5, 8, 13, 21
Stores result (21) to memory
```

### Test 8: Branch Operations
**Purpose:** Verify all conditional branches

| Instruction | Condition | Branch Taken? |
|-------------|-----------|---------------|
| BEQ | 5 == 5 | Yes |
| BNE | 5 != 10 | Yes |
| BLT | 5 < 10 (signed) | Yes |
| BGE | 10 >= 5 (signed) | Yes |
| BLTU | 5 < 0xFFFFFFFF | Yes |
| BGEU | 0xFFFFFFFF >= 5 | Yes |
| BEQ | 5 == 10 | No |
| BNE | 5 != 5 | No |

### Test 9: Jump Operations
**Purpose:** Verify JAL and JALR

| Instruction | Test Case | Verification |
|-------------|-----------|--------------|
| JAL | Jump +12, save return | x1 = PC+4 |
| JALR | Jump to reg | x4 = PC+4 |
| JALR+offset | Jump to reg+imm | x7 = PC+4 |

### Test 10: Backward Branch (Loop)
**Purpose:** Verify negative branch offsets

```c
// Equivalent C code:
int counter = 0, sum = 0;
while (counter < 5) {
    sum += counter;
    counter++;
}
// Result: sum = 0+1+2+3+4 = 10
```

### Test 11: IO Access (UART/GPIO)
**Purpose:** Verify AXI-Lite Interconnect routing to IO modules

| Instruction | Test Case | Expected |
|-------------|-----------|----------|
| SW | Write to UART Base (0x0400_0000) | OKAY Response |
| LW | Read from UART Base | Data = 0 |
| SW | Write to GPIO Base (0x0400_1000) | OKAY Response |
| LW | Read from GPIO Base | Data = 0 |

### Test 12: GPIO Bidirectional
**Purpose:** Verify GPIO bidirectional functionality via AXI-Lite

This test verifies that the GPIO module correctly handles:
1. **Output Mode**: CPU configures pins as outputs and drives data
2. **Input Mode**: CPU configures pins as inputs and reads external data

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Write 0xFFFFFFFF to DIR (0x08) | GPIO[31:0] = Output mode |
| 2 | Write 0xFF to DATA (0x00) | gpio[31:0] = 0x000000FF |
| 3 | Write 0x00 to DIR (0x08) | GPIO[31:0] = Input mode |
| 4 | TB drives 0xCAFEBABE | gpio[31:0] = 0xCAFEBABE |
| 5 | Read DATA (0x00) | x6 = 0xCAFEBABE |

### Test 13: Byte/Halfword Load/Store
**Purpose:** Verify LB, LH, LBU, LHU, SB, SH instructions

This test verifies sub-word memory access with proper sign/zero extension:

| Instruction | Offset | Source Data | Expected Result |
|-------------|--------|-------------|-----------------|
| LB  | 0 | 0xEF | 0xFFFFFFEF (sign-extend) |
| LBU | 0 | 0xEF | 0x000000EF (zero-extend) |
| LH  | 0 | 0xBEEF | 0xFFFFBEEF (sign-extend) |
| LHU | 0 | 0xBEEF | 0x0000BEEF (zero-extend) |
| LB  | 1 | 0xBE | 0xFFFFFFBE (sign-extend) |
| LBU | 2 | 0xAD | 0x000000AD (zero-extend) |
| LH  | 2 | 0xDEAD | 0xFFFFDEAD (sign-extend) |
| LHU | 2 | 0xDEAD | 0x0000DEAD (zero-extend) |

### Test 14: UART Loopback
**Purpose:** Verify UART TX and RX functionality via loopback

This test verifies that the UART module can transmit a byte and receive it back (either via external loopback or testbench connection):

1. **Write to TX**: CPU writes 0x55 to UART TX_DATA register.
2. **Transmission**: UART transmits the byte (start bit + 8 data bits + stop bit).
3. **Loopback**: The transmitted signal is fed back to the RX pin.
4. **Reception**: UART receives the byte and updates RX_DATA and STATUS registers.
5. **Verification**: CPU checks STATUS (TX_EMPTY=1, RX_VALID=1) and RX_DATA (0x55).

## Test 15: RAW Hazard Stress
**Purpose:** Stress test the forwarding unit with long chains of dependencies

```
ADDI x1, x0, 1
ADD x2, x1, x1  (Forward from WB or EX)
ADD x3, x2, x2
...
SLT x15, x13, x12
```

## Test 16: Full ALU Coverage
**Purpose:** Verify all ALU operations including corner cases
- Verify SRAI, SLTI, SLTIU
- Verify OR, XOR, SLL, SRL, SRA, SLT, SLTU
- Verify store-load with ALU results

## Test 17: Nested Loops
**Purpose:** Verify complex control flow and register persistence

```c
for (i=0; i<3; i++) {
    for (j=0; j<3; j++) {
        sum += i + j;
    }
}
```

## Test 18: Memory Access Pattern Stress
**Purpose:** extensive verification of byte/halfword loads and stores
- Writes sequences of bytes/halfwords
- Reads them back with mixed signed/unsigned instructions (LB, LBU, LH, LHU)
- Specific test for Store-Load hazards (Store followed immediately by Load to same address)

## Test 19: Mixed Instruction Stress
**Purpose:** Randomized-style mix of all instruction types to catch interaction bugs
- Interleaves ALU, Memory, Branch, and Jump instructions
- Verifies `LUI` + `ADDI` large constant generation
- Verifies `JAL` / `JALR` return address linking in complex flow

## Test 20: Multiplication (M Extension)
**Purpose:** Verify MUL, MULH, MULHSU, MULHU instructions

| Instruction | Test Case | Expected |
|-------------|-----------|----------|
| MUL | 6 × 7 | 42 |
| MUL | 100 × 200 | 20000 |
| MULH | 0x7FFFFFFF × 2 | 0 (upper 32 of signed) |
| MULHU | 0x80000000 × 2 | 1 (upper 32 of unsigned) |
| MULHSU | -1 × 0x80000000 | 0x7FFFFFFF |

## Test 21: Division (M Extension)
**Purpose:** Verify DIV, DIVU, REM, REMU instructions

| Instruction | Test Case | Expected |
|-------------|-----------|----------|
| DIVU | 100 / 7 | 14 |
| REMU | 100 % 7 | 2 |
| DIV | -100 / 7 | -14 |
| REM | -100 % 7 | -2 |
| DIVU | 1000000 / 1000 | 1000 |
| DIVU | 5 / 10 | 0 |

## Test 22: Division Forwarding
**Purpose:** Verify data forwarding works with division inputs

Tests three forwarding scenarios:
1. **ADD → DIVU**: Division immediately after ALU operation
2. **MUL → DIVU**: Division immediately after multiplication
3. **DIVU → DIVU**: Back-to-back divisions using previous result

## Test 23: M Extension + Control Flow
**Purpose:** Comprehensive stress test combining MUL, DIV, branches, and jumps

| Step | Operations | Verification |
|------|------------|-------------|
| 1 | MUL x4 = 6×7 | x4 = 42 |
| 2 | BLT (40 < 42?) | Branch taken |
| 3 | DIVU x6 = 42/3 | x6 = 14 (forwarding) |
| 4 | BEQ (x6 == 14?) | Branch taken |
| 5 | JAL to subroutine | x21 = return addr |
| 6 | MUL x8 = 14×7 (in sub) | x8 = 98 |
| 7 | JALR return | Jump back |
| 8 | DIVU x9 = 98/7 | x9 = 14 |

## Test 24: Cache Locality Exploitation (Instruction Cache)
**Purpose:** Exercise the instruction cache with tight loops and nested control flow to validate high cache-hit behavior while preserving architectural correctness.

- Runs multiple short loops designed to remain in a small hot working set.
- Verifies final register/memory results and prints cache performance counters.

## Test 25: I-Cache Conflict Miss Thrash (Direct-Mapped)
**Purpose:** Stress the instruction cache’s **direct-mapped** behavior by alternating execution between two hot code regions that intentionally **alias** to the same cache indices (separated by `0x400` bytes).

- Validates that control flow remains correct under heavy conflict misses (correctness first).
- Helps catch tag/index or valid-bit corner cases that don’t show up in pure-locality loops.

## Instruction Coverage

### RV32IM Base Integer Instructions

| Category | Instructions | Tested | Coverage |
|----------|-------------|--------|----------|
| Arithmetic | ADD, SUB, ADDI | Yes | 100% |
| Logical | AND, OR, XOR, ANDI, ORI, XORI | Yes | 100% |
| Shifts | SLL, SRL, SRA, SLLI, SRLI, SRAI | Yes | 100% |
| Compare | SLT, SLTU, SLTI, SLTIU | Yes | 100% |
| Branch | BEQ, BNE, BLT, BGE, BLTU, BGEU | Yes | 100% |
| Jump | JAL, JALR | Yes | 100% |
| Upper Imm | LUI, AUIPC | Yes | 100% |
| Load | LW, LB, LH, LBU, LHU | Yes | 100% |
| Store | SW, SB, SH | Yes | 100% |
| M Extension | MUL, MULH, MULHSU, MULHU | Yes | 100% |
| M Extension | DIV, DIVU, REM, REMU | Yes | 100% |
| **NOT IMPLEMENTED** | FENCE, ECALL, EBREAK | N/A | 0% |

## Test Flow Diagram

```
                    ┌─────────────┐
                    │    Start    │
                    └──────┬──────┘
                           │
              ┌────────────▼────────────┐
              │  Initialize Testbench   │
              │  - Create VCD dump      │
              │  - Setup clock          │
              └────────────┬────────────┘
                           │
         ┌─────────────────▼─────────────────┐
         │          For each test:           │
         │  ┌─────────────────────────────┐  │
         │  │  1. Load program to memory  │  │
         │  │  2. Reset CPU               │  │
         │  │  3. Wait for execution      │  │
         │  │  4. Check register values   │  │
         │  │  5. Check memory values     │  │
         │  │  6. Record pass/fail        │  │
         │  └─────────────────────────────┘  │
         └─────────────────┬─────────────────┘
                           │
              ┌────────────▼────────────┐
              │   Print Test Summary    │
              │   - Total tests         │
              │   - Passed/Failed       │
              └────────────┬────────────┘
                           │
                    ┌──────▼──────┐
                    │    End      │
                    └─────────────┘
```

## Running Tests

### Prerequisites
- Icarus Verilog (iverilog) v11.0+
- GTKWave (optional, for waveform viewing)

### Commands

```bash
# Compile testbench
iverilog -g2012 -o sim/z_core_control_u_tb.vvp tb/z_core_control_u_tb.sv

# Run simulation
vvp sim/z_core_control_u_tb.vvp

# View waveforms
gtkwave sim/z_core_control_u_tb.vcd
```

### Expected Output

```
╔═══════════════════════════════════════════════════════════╗
║           Z-Core RISC-V Processor Test Suite              ║
║                  RV32IM Instruction Set                   ║
╚═══════════════════════════════════════════════════════════╝

--- Loading Test 1: Arithmetic Operations ---
=== Test 1 Results: Arithmetic ===
  [PASS] ADDI x2, x0, 10: x2 = 10
  [PASS] ADD x4, x2, x3: x4 = 17
  ...

╔═══════════════════════════════════════════════════════════╗
║                    TEST SUMMARY                           ║
╠═══════════════════════════════════════════════════════════╣
║  Total Tests:  195                                        ║
║  Passed:       195                                        ║
║  Failed:        0                                         ║
╠═══════════════════════════════════════════════════════════╣
║         ✓ ALL TESTS PASSED SUCCESSFULLY ✓                 ║
╚═══════════════════════════════════════════════════════════╝
```

## Waveform Analysis

Key signals to observe in GTKWave:

| Signal | Description |
|--------|-------------|
| `uut.PC` | Program Counter |
| `uut.IR` | Instruction Register |
| `uut.state` | FSM State (one-hot) |
| `axil_arvalid/arready` | AXI Read handshake |
| `axil_awvalid/awready` | AXI Write handshake |
| `uut.reg_file.reg_r*_q` | Register values |


## RISCOF Compliance

Z-Core has passed all **official RISCOF architectural tests** for the **RV32IM** ISA.

| Test Suite | Status |
|------------|--------|
| **RV32IM Base Integer** | <font color="green">All Passed</font> |
| **RV32M Multiply/Divide** | <font color="green">All Passed</font> |
| **Total** | <font color="green">All Passed</font> |

### Extended Coverage Tests

In addition to the official RISCOF tests, Z-Core has been validated with **45 extended coverage tests** generated by `riscv_ctg` (RISC-V Compliance Test Generator). These tests provide additional coverage for corner cases.

| Test Suite | Status |
|------------|--------|
| **Generated RV32IM Tests** | <font color="green">All Passed</font> |

> **Note**: The RISCOF verification infrastructure is maintained in a separate `riscof/` directory (not included in the main repository). See the RISCOF directory's README for setup and usage instructions.

## Future Verification Plans

1. [x] RISC-V official compliance tests (RISCOF)
2. [x] Run full RISCOF test suite for RV32IM
3. [x] Extended coverage tests (riscv_ctg)
4. [ ] Formal verification of critical paths and corner cases
