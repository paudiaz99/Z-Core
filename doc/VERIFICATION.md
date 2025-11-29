# Z-Core Verification Documentation

## Overview

This document describes the verification strategy, test coverage, and results for the Z-Core RISC-V processor.

## Test Architecture

```
┌────────────────────────────────────────────────────────────────────────────┐
│                         Z-Core Test Environment                             │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    z_core_control_u_tb.sv                             │  │
│  │  ┌────────────────────────────────────────────────────────────────┐  │  │
│  │  │                    Test Orchestration                           │  │  │
│  │  │  - Program Loading (load_testN tasks)                          │  │  │
│  │  │  - CPU Reset Management                                         │  │  │
│  │  │  - Result Verification (check_reg, check_mem tasks)            │  │  │
│  │  │  - Pass/Fail Reporting                                          │  │  │
│  │  └────────────────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                    │                                        │
│                                    ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    Device Under Test (DUT)                            │  │
│  │  ┌────────────────────┐      AXI-Lite      ┌────────────────────┐   │  │
│  │  │  z_core_control_u  │◄──────────────────►│     axil_ram       │   │  │
│  │  │    (CPU Core)      │                    │    (64KB Memory)   │   │  │
│  │  └────────────────────┘                    └────────────────────┘   │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  Output: VCD Waveforms, Test Results, Coverage Report                       │
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

## Instruction Coverage

### RV32I Base Integer Instructions

| Category | Instructions | Tested | Coverage |
|----------|-------------|--------|----------|
| Arithmetic | ADD, SUB, ADDI | Yes | 100% |
| Logical | AND, OR, XOR, ANDI, ORI, XORI | Yes | 100% |
| Shifts | SLL, SRL, SRA, SLLI, SRLI, SRAI | Yes | 100% |
| Compare | SLT, SLTU, SLTI, SLTIU | Yes | 100% |
| Branch | BEQ, BNE, BLT, BGE, BLTU, BGEU | Yes | 100% |
| Jump | JAL, JALR | Yes | 100% |
| Upper Imm | LUI, AUIPC | Yes | 100% |
| Load | LW | Yes | 100% |
| Store | SW | Yes | 100% |
| **NOT IMPLEMENTED** | LB, LH, LBU, LHU, SB, SH | N/A | 0% |
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
║                   RV32I Instruction Set                    ║
╚═══════════════════════════════════════════════════════════╝

--- Loading Test 1: Arithmetic Operations ---
=== Test 1 Results: Arithmetic ===
  [PASS] ADDI x2, x0, 10: x2 = 10
  [PASS] ADD x4, x2, x3: x4 = 17
  ...

╔═══════════════════════════════════════════════════════════╗
║                    TEST SUMMARY                            ║
╠═══════════════════════════════════════════════════════════╣
║  Total Tests:  68                                          ║
║  Passed:       68                                          ║
║  Failed:        0                                          ║
╠═══════════════════════════════════════════════════════════╣
║         ALL TESTS PASSED SUCCESSFULLY                      ║
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

## Known Limitations

1. **Word-only memory access**: LB, LH, LBU, LHU, SB, SH not implemented
2. **No system instructions**: FENCE, ECALL, EBREAK not implemented
3. **No interrupts**: Interrupt handling not implemented
4. **No pipeline**: Multi-cycle execution only

## Future Verification Plans

1. [ ] RISC-V official compliance tests (riscv-tests)
2. [ ] Random instruction testing
3. [ ] Stress testing with longer programs
4. [ ] Formal verification of critical paths
5. [ ] Coverage-driven verification

