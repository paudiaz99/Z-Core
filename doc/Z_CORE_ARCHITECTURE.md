# Z-Core RISC-V Processor Architecture

## Overview

Z-Core is a 32-bit RISC-V processor implementing the RV32I base integer instruction set. It uses a multi-cycle architecture with an AXI4-Lite memory interface.

## Block Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│                            Z-Core Top Module                              │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐ │
│  │                        Control Unit (FSM)                            │ │
│  │  ┌────────┐  ┌────────────┐  ┌─────────┐  ┌──────────┐  ┌─────────┐ │ │
│  │  │ FETCH  │──│ FETCH_WAIT │──│ DECODE  │──│ EXECUTE  │──│  WRITE  │ │ │
│  │  └────────┘  └────────────┘  └─────────┘  └────┬─────┘  └─────────┘ │ │
│  │                                                │                     │ │
│  │                                           ┌────┴────┐                │ │
│  │                                           │   MEM   │                │ │
│  │                                           └─────────┘                │ │
│  └─────────────────────────────────────────────────────────────────────┘ │
│                                                                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────┐ │
│  │ Decoder  │  │ Reg File │  │ ALU Ctrl │  │   ALU    │  │ AXI Master │ │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  └────────────┘ │
│                                                                           │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ AXI-Lite Interface
                                    ▼
                           ┌──────────────────┐
                           │   Memory (RAM)   │
                           └──────────────────┘
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
| alu_inst_type | Input     | 4     | Operation code   |
| alu_out       | Output    | 32    | Result           |
| alu_branch    | Output    | 1     | Branch condition |

### 5. Control Unit (`z_core_control_u`)

Multi-cycle FSM that orchestrates instruction execution.

**FSM States:**
```
FETCH ──► FETCH_WAIT ──► DECODE ──► EXECUTE ──► WRITE
                                        │
                                        ▼
                                       MEM
```

| State      | Description                                    |
|------------|------------------------------------------------|
| FETCH      | Issue instruction fetch request                |
| FETCH_WAIT | Wait for memory response                       |
| DECODE     | Decode instruction, read registers             |
| EXECUTE    | Execute ALU operation, compute address/branch  |
| MEM        | Perform load/store memory operation            |
| WRITE      | Write result to register file                  |

### 6. AXI Master (`axil_master`)

Converts simple memory interface to AXI4-Lite protocol.

See [AXI_INTERFACE.md](AXI_INTERFACE.md) for detailed documentation.

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

| Address Range    | Description           |
|------------------|-----------------------|
| 0x00000000+      | Program memory (text) |
| Variable         | Data memory           |

**Note:** The current implementation uses word-aligned (4-byte) accesses only.

## Timing

Each instruction takes multiple clock cycles:

| Instruction Type | Cycles | States                              |
|------------------|--------|-------------------------------------|
| R-Type           | ~6     | FETCH→WAIT→DECODE→EXECUTE→WRITE    |
| I-Type (ALU)     | ~6     | FETCH→WAIT→DECODE→EXECUTE→WRITE    |
| Load             | ~10    | FETCH→WAIT→DECODE→EXECUTE→MEM→WRITE|
| Store            | ~8     | FETCH→WAIT→DECODE→EXECUTE→MEM      |
| Branch           | ~5     | FETCH→WAIT→DECODE→EXECUTE          |
| JAL/JALR         | ~6     | FETCH→WAIT→DECODE→EXECUTE→WRITE    |

## Files

| File                     | Description                    |
|--------------------------|--------------------------------|
| rtl/z_core_decoder.v     | Instruction decoder            |
| rtl/z_core_reg_file.v    | Register file                  |
| rtl/z_core_alu_ctrl.v    | ALU control                    |
| rtl/z_core_alu.v         | Arithmetic logic unit          |
| rtl/z_core_control_u.v   | Control unit / top module      |
| rtl/axil_master.v        | AXI-Lite master                |
| rtl/axi_mem.v            | AXI-Lite RAM                   |

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

1. **Multiple Data Sizes**: Support for byte/halfword load/store
2. **Pipeline**: Convert to pipelined architecture for higher throughput
3. **Caching**: Add instruction and data caches
4. **Interrupts**: Exception and interrupt handling
5. **M Extension**: Multiply/divide instructions
6. **C Extension**: Compressed instructions

