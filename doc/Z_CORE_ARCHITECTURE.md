# Z-Core RISC-V Processor Architecture

## Overview

Z-Core is a 32-bit RISC-V processor implementing the RV32I base integer instruction set. It uses a **5-stage pipelined architecture** (IF, ID, EX, MEM, WB) with an AXI4-Lite memory interface.

## Block Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                            Z-Core Top Module                                 │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                     Control Unit (Pipeline)                             │ │
│  │  ┌──────────┐  ┌───────────┐  ┌──────────┐  ┌───────────┐  ┌──────────┐ │ │
│  │  │ IF Stage │─►│ ID Stage  │─►│ EX Stage │─►│ MEM Stage │─►│ WB Stage │ │ │
│  │  └──────────┘  └───────────┘  └──────────┘  └───────────┘  └──────────┘ │ │
│  │                                                   │                     │ │
│  │                                              ┌────┴────┐                │ │
│  │                                              │ AXI Mst │                │ │
│  │                                              └────┬────┘                │ │
│  └───────────────────────────────────────────────────│─────────────────────┘ │
│                                                      │ AXI-Lite              │
│                                                      ▼                       │
│                                      ┌─────────────────────────┐             │
│                                      │  AXI-Lite Interconnect  │             │
│                                      └─┬──────────┬──────────┬─┘             │
│                                        │          │          │               │
│                    ┌───────────────────▼─┐  ┌─────▼────┐  ┌──▼───────┐       │
│                    │    Memory (RAM)     │  │   UART   │  │   GPIO   │       │
│                    └─────────────────────┘  └──────────┘  └──────────┘       │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Module Descriptions

### 1. Instruction Decoder (`z_core_decoder`)

Decodes 32-bit RISC-V instructions into control signals and immediate values.

**Inputs:**
- `inst[31:0]` - 32-bit instruction

**Outputs:**
- `op[6:0]` - Opcode
- `rs1[4:0]`, `rs2[4:0]`, `rd[4:0]` - Register addresses
- `funct3[2:0]`, `funct7[6:0]` - Function fields
- `Iimm`, `Simm`, `Uimm`, `Bimm`, `Jimm` - Immediate values (sign-extended)

### 2. Register File (`z_core_reg_file`)

32 x 32-bit general-purpose registers with asynchronous read and synchronous write.

**Features:**
- Register x0 is hardwired to zero
- Two read ports (rs1, rs2)
- One write port (rd)
- Synchronous reset

**Ports:**
| Port         | Direction | Width | Description          |
|--------------|-----------|-------|----------------------|
| clk          | Input     | 1     | Clock                |
| reset        | Input     | 1     | Synchronous reset    |
| write_enable | Input     | 1     | Write enable         |
| rd           | Input     | 5     | Destination register |
| rd_in        | Input     | 32    | Data to write        |
| rs1          | Input     | 5     | Source register 1    |
| rs2          | Input     | 5     | Source register 2    |
| rs1_out      | Output    | 32    | Data from rs1        |
| rs2_out      | Output    | 32    | Data from rs2        |

### 3. ALU Control (`z_core_alu_ctrl`)

Generates ALU operation codes based on instruction opcode and function fields.

**ALU Operations:**
| Code | Operation | Description         |
|------|-----------|---------------------|
| 0    | ADD       | Addition            |
| 1    | SUB       | Subtraction         |
| 2    | SLL       | Shift left logical  |
| 3    | SLT       | Set less than       |
| 4    | SLTU      | Set less than (u)   |
| 5    | XOR       | Bitwise XOR         |
| 6    | SRL       | Shift right logical |
| 7    | SRA       | Shift right arith.  |
| 8    | OR        | Bitwise OR          |
| 9    | AND       | Bitwise AND         |
| 10   | BEQ       | Branch if equal     |
| 11   | BNE       | Branch if not equal |
| 12   | BLT       | Branch if less than |
| 13   | BGE       | Branch if >= (s)    |
| 14   | BLTU      | Branch if < (u)     |
| 15   | BGEU      | Branch if >= (u)    |

### 4. ALU (`z_core_alu`)

Performs arithmetic, logical, and comparison operations.

**Ports:**
| Port          | Direction | Width | Description      |
|---------------|-----------|-------|------------------|
| alu_in1       | Input     | 32    | Operand 1        |
| alu_in2       | Input     | 32    | Operand 2        |
| alu_inst_type | Input     | 5     | Operation code   |
| alu_out       | Output    | 32    | Result           |
| alu_branch    | Output    | 1     | Branch condition |

### 5. Multiplication Unit (`z_core_mult_unit`)

A 32×32→64 bit multiplier supporting the full **RISC-V M Extension**:

| Instruction | Operands | Description |
|-------------|----------|-------------|
| MUL | any | Lower 32 bits of product |
| MULH | signed × signed | Upper 32 bits of signed multiplication |
| MULHSU | signed × unsigned | Upper 32 bits of signed × unsigned |
| MULHU | unsigned × unsigned | Upper 32 bits of unsigned multiplication |

#### Implementation Options

Two implementations are available, selectable via `define` in `z_core_mult_unit.v`:

| Implementation | File | Description | Use Case |
|----------------|------|-------------|----------|
| **Synth (default)** | `z_core_mult_synth.v` | Uses `*` operator | FPGA/ASIC synthesis |
| Tree | `z_core_mult_tree.v` | 62 `adder_32b` tree | Educational |

```verilog
// In z_core_mult_unit.v, line 14:
// `define USE_TREE_MULTIPLIER  // Uncomment for educational tree version
```

> [!TIP]
> The **synthesis-optimized version** is the default. It allows the synthesis tool to use DSP blocks on FPGAs or optimized multiplier cells on ASICs. The tree version is provided for educational purposes to understand the Patterson & Hennessy Figure 3.7 architecture.

#### Signed Multiplication Approach

Both implementations use the same area-efficient signed multiplication approach:

1. **Input Conversion**: Convert signed operands to absolute values
2. **Unsigned Multiplication**: Perform unsigned multiply
3. **Sign Correction**: Negate result if exactly one operand was negative

#### Tree Implementation Details (Educational)

The tree version follows Patterson & Hennessy Figure 3.7:
- 32 partial products summed in a binary tree
- 31 64-bit additions = 62 `adder_32b` instances
- O(log₂n) = 5 tree levels for 32-bit operands

**Ports:**
| Port       | Direction | Width | Description               |
|------------|-----------|-------|---------------------------|
| op1        | Input     | 32    | Multiplier                |
| op2        | Input     | 32    | Multiplicand              |
| op1_signed | Input     | 1     | Treat op1 as signed       |
| op2_signed | Input     | 1     | Treat op2 as signed       |
| result     | Output    | 64    | Product                   |

### 6. Division Unit (`z_core_div_unit`)

A 32÷32→32 bit divider supporting the **RISC-V M Extension** division instructions:

| Instruction | Operands | Description |
|-------------|----------|-------------|
| DIV | signed ÷ signed | Signed division quotient |
| DIVU | unsigned ÷ unsigned | Unsigned division quotient |
| REM | signed % signed | Signed division remainder |
| REMU | unsigned % unsigned | Unsigned division remainder |

#### Algorithm

Based on **Patterson & Hennessy "Computer Organization and Design" RISC-V Edition, Figure 3.8**:

```
1. Initialize: remainder = dividend, divisor in upper 32 bits
2. Repeat 33 times:
   a. remainder = remainder - divisor
   b. If result < 0: restore remainder, shift quotient left with 0
      If result ≥ 0: keep remainder, shift quotient left with 1
   c. Shift divisor right by 1
3. Apply sign correction for signed operations
```

#### Signed Division Handling

1. **Convert** operands to absolute values
2. **Divide** using unsigned algorithm
3. **Correct signs**:
   - Quotient: negative if operand signs differ
   - Remainder: same sign as dividend (per RISC-V spec)

#### Performance & Pipeline Integration

| Metric | Value |
|--------|-------|
| Latency | ~68 cycles (iterative) |
| Throughput | 1/68 instructions/cycle |
| Pipelining | Non-pipelined (stalls EX stage) |

**Pipeline Handling:**
1. **Stall Generation**: When a division instruction enters the EX stage (`id_ex_is_div`):
   - `div_start` triggers the division unit.
   - `div_running` signal from the unit causes `div_stall` in the Control Unit.
   - `ex_stall` logic freezes the PC, IF/ID, and ID/EX registers.
2. **Forwarding**: The Control Unit handles data forwarding from WB and MEM stages to the division unit inputs (`alu_in1`, `alu_in2`) just like standard ALU operations.
3. **Completion**: When `div_done` asserts:
   - `div_result` is captured.
   - Stall signals are released.
   - Result proceeds to MEM and WB stages.

**Ports:**
| Port           | Direction | Width | Description               |
|----------------|-----------|-------|---------------------------|
| dividend       | Input     | 32    | Dividend                  |
| divisor        | Input     | 32    | Divisor                   |
| is_signed      | Input     | 1     | 1 = signed (DIV/REM)      |
| quotient_or_rem| Input     | 1     | 1 = quotient, 0 = remainder|
| div_start      | Input     | 1     | Start division            |
| div_running    | Output    | 1     | Division in progress      |
| div_done       | Output    | 1     | Division complete         |
| div_result     | Output    | 32    | Quotient or remainder     |

### 7. Control Unit (`z_core_control_u`)

Pipelined control unit with Hazard Detection and Forwarding Unit.

**Pipeline Stages:**
```
   ┌──────┐      ┌──────┐      ┌──────┐       ┌───────┐      ┌──────┐
──►│  IF  │─────►│  ID  │─────►│  EX  │──────►│  MEM  │─────►│  WB  │──►
   └──────┘      └──────┘      └──────┘       └───────┘      └──────┘
   Fetch         Decode        Execute        Memory         Writeback
```

| Stage | Description                                      |
|-------|--------------------------------------------------|
| IF    | Instruction Fetch from memory                    |
| ID    | Instruction Decode & Register Read               |
| EX    | ALU Operation / Address Calculation              |
| MEM   | Data Memory Access (Load/Store)                  |
| WB    | Write Back result to Register File               |

**Hazard Handling:**
- **Data Hazards**: Forwarding (EX->EX, MEM->EX) and Stalling (Load-Use)
- **Control Hazards**: Branch prediction (not implemented) / Flush on taken branch
- **Structural Hazards**: Memory arbiter for IF/MEM conflict

### 8. AXI-Lite Interconnect (`axil_interconnect`)

Connects the Control Unit (Master) to multiple Slaves based on the address map.

**Configuration:**
- 1 Slave Interface (from Control Unit)
- 3 Master Interfaces (to Memory, UART, GPIO)

### 9. Peripherals

#### UART (`axil_uart`)
- Base Address: `0x0400_0000`
- Size: 4KB
- Uses `axil_slave` wrapper to expose User Interface.

#### GPIO (`axil_gpio`)
- Base Address: `0x0400_1000`
- Size: 4KB
- Uses `axil_slave` wrapper to expose User Interface.

#### Generic Slave (`axil_slave`)
- Reusable AXI-Lite slave interface.
- Handles handshake and exposes simple Read/Write interface (`usr_addr`, `usr_wdata`, `usr_wen`, `usr_ren`, `usr_rdata`).

## Supported Instructions

### R-Type (Register-Register)
```
ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
```

### I-Type (Immediate)
```
ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
LB, LH, LW, LBU, LHU (Load instructions)
JALR
```

### S-Type (Store)
```
SB, SH, SW
```

### B-Type (Branch)
```
BEQ, BNE, BLT, BGE, BLTU, BGEU
```

### U-Type (Upper Immediate)
```
LUI, AUIPC
```

### J-Type (Jump)
```
JAL
```

## Memory Map

The processor uses a unified address space for instructions and data:

| Address Range             | Device        | Description           |
|---------------------------|---------------|-----------------------|
| `0x0000_0000` - `0x03FF_FFFF` | Memory (RAM)  | Program & Data (64MB) |
| `0x0400_0000` - `0x0400_0FFF` | UART          | Serial Communication  |
| `0x0400_1000` - `0x0400_1FFF` | GPIO          | General Purpose I/O   |

**Note:** The current implementation uses word-aligned (4-byte) accesses only.

## Timing

Each instruction takes multiple clock cycles:

| Instruction Type | Throughput | Latency |
|------------------|------------|---------|
| R-Type           | 1 cycle    | 5 cycles|
| I-Type (ALU)     | 1 cycle    | 5 cycles|
| Load             | 1 cycle    | 5 cycles|
| Store            | 1 cycle    | 5 cycles|
| Branch           | 1-3 cycles | 3 cycles|
| JAL/JALR         | 2 cycles   | 3 cycles|

## Files

| File                     | Description                    |
|--------------------------|--------------------------------|
| rtl/z_core_top_model.v   | Top-level wrapper              |
| rtl/z_core_control_u.v   | Control unit / CPU Core        |
| rtl/z_core_decoder.v     | Instruction decoder            |
| rtl/z_core_reg_file.v    | Register file                  |
| rtl/z_core_alu_ctrl.v    | ALU control                    |
| rtl/z_core_alu.v         | Arithmetic logic unit          |
| rtl/z_core_mult_unit.v   | Tree multiplier (32×32→64)     |
| rtl/z_core_div_unit.v    | Division unit (32÷32→32)       |
| rtl/adder_32b.v          | 32-bit ripple carry adder      |
| rtl/full_adder.v         | 1-bit full adder               |
| rtl/axil_interconnect.v  | AXI-Lite Interconnect          |
| rtl/axi_mem.v            | AXI-Lite RAM                   |
| rtl/axil_slave.v         | Generic AXI-Lite Slave         |
| rtl/axil_uart.v          | UART Module                    |
| rtl/axil_gpio.v          | GPIO Module                    |

## Simulation

### Running Tests

```bash
# Compile and run ALU test
iverilog -o sim/z_core_alu_tb.vvp tb/z_core_alu_tb.v
vvp sim/z_core_alu_tb.vvp

# Compile and run full system test
iverilog -g2012 -o sim/z_core_control_u_tb.vvp tb/z_core_control_u_tb.v
vvp sim/z_core_control_u_tb.vvp
```

### Viewing Waveforms

```bash
gtkwave sim/z_core_control_u_tb.vcd
```

## Future Enhancements

1. ~~**Multiple Data Sizes**: Support for byte/halfword load/store~~ ✓ Implemented
2. ~~**Pipeline**: Convert to pipelined architecture for higher throughput~~ ✓ Implemented
3. **Caching**: Add instruction and data caches
4. **Interrupts**: Exception and interrupt handling
5. **M Extension (Multiply/Divide)**: ✅ Implemented
   - MUL, MULH, MULHSU, MULHU: Functional multiplication implemented with 31-adder tree architecture.
   - DIV, DIVU, REM, REMU: Division unit implemented using Patterson & Hennessy algorithm (~68 cycles per division).
6. **C Extension**: Compressed instructions
7. ~~**Peripherals**: Capability to talk to the outter world~~ ✓ Implemented (UART, GPIO)
