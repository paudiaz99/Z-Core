<div align="center">
<pre>
███████╗       ██████╗ ██████╗ ██████╗ ███████╗
╚══███╔╝      ██╔════╝██╔═══██╗██╔══██╗██╔════╝
  ███╔╝ █████╗██║     ██║   ██║██████╔╝█████╗  
 ███╔╝  ╚════╝██║     ██║   ██║██╔══██╗██╔══╝  
███████╗      ╚██████╗╚██████╔╝██║  ██║███████╗
╚══════╝       ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝
</pre>
</div>

<div align="center">

**A lightweight RISC-V RV32IMZicsr processor**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Verilog](https://img.shields.io/badge/HDL-Verilog-blue.svg)](https://en.wikipedia.org/wiki/Verilog)
![RISC-V](https://img.shields.io/badge/RISC--V-RV32IMZicsr-green?logo=riscv)
[![Compliance](https://img.shields.io/badge/RISCOF-RV32IMZicsr%20Passed-brightgreen.svg)](https://github.com/riscv-software-src/riscof)

</div>

---

## Features

- **5-Stage Pipeline** - Classic RISC-V 5-stage pipeline implementation
- **RV32IM+Zicsr Implementation** - Base integer ISA + Multiplication/Division + CSR access
- **M-Mode Trap Handling** - Exceptions (ECALL, EBREAK, Illegal) and Interrupts (Timer, External, Software)

- **AXI4-Lite Interface** - Industry-standard memory bus protocol
- **Modular Design** - Clean separation of concerns with individual modules
- **Comprehensive Testbenches** - Automated testing for all components
- **Well Documented** - Extensive documentation and code comments
- **Educational Focus** - Perfect for learning computer architecture

## Block Diagram

<div align="center">
  <img src="https://github.com/user-attachments/assets/fec3a0e0-5cef-46e4-a3fd-7f07b1387a11" alt="centered image">
  <br>
  <sup>Z-Core SoC Architecture.</sup>
</div>

> [!WARNING]
> The SoC diagram does not include neither the Timer and Branch Predictor modules.

## Z-Core RV32IM Architecture
<div align="center">
  <img src="https://github.com/user-attachments/assets/4634f470-e526-4054-b2ef-d4ed0da07c22" alt="centered image">
  <br>
  <sup>Z-Core RV32IM Architecture Diagram.</sup>
</div>

> [!NOTE]
> For a more detailed description of the Z-Core architecture, see the **[Z-Core Architecture Document](doc/Z_CORE_ARCHITECTURE.md)**

## Supported Instructions

| Type | Instructions | Description |
|------|-------------|-------------|
| **R-Type** | `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND`, `MUL`, `MULH`, `MULHSU`, `MULHU`, `DIV`, `DIVU`, `REM`, `REMU` | Register-register operations |
| **I-Type** | `ADDI`, `SLTI`, `SLTIU`, `XORI`, `ORI`, `ANDI`, `SLLI`, `SRLI`, `SRAI` | Immediate operations |
| **Load** | `LB`, `LH`, `LW`, `LBU`, `LHU` | Memory load |
| **Store** | `SB`, `SH`, `SW` | Memory store |
| **Branch** | `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU` | Conditional branching |
| **Jump** | `JAL`, `JALR` | Jump and link |
| **Upper** | `LUI`, `AUIPC` | Upper immediate |
| **Zicsr** | `CSRRW`, `CSRRS`, `CSRRC`, `CSRRWI`, `CSRRSI`, `CSRRCI` | CSR read-modify-write |
| **System** | `MRET`, `ECALL`, `EBREAK` | Trap return, environment call, breakpoint |

## Project Structure

```
Z-Core/
├── rtl/                       # RTL source files
│   ├── z_core_top_model.v     # Top-level SoC
│   ├── z_core_control_u.v     # Control unit / CPU core
│   ├── z_core_decoder.v       # Instruction decoder
│   ├── z_core_reg_file.v      # 32x32-bit register file
│   ├── z_core_alu.v           # Arithmetic logic unit
│   ├── z_core_alu_ctrl.v      # ALU control
│   ├── z_core_mult_tree.v     # Multiplier unit (Tree version)
│   ├── z_core_mult_synth.v    # Multiplier unit (Synthesis version)
│   ├── z_core_mult_unit.v     # Multiplier unit top level
│   ├── z_core_div_unit.v      # Divider unit
│   ├── z_core_instr_cache.v   # Instruction cache
│   ├── z_core_branch_pred.v   # Branch Predictor
│   ├── z_core_csr_file.v      # CSR Register File (Zicsr)
│   ├── axil_interconnect.v    # AXI-Lite Interconnect
│   ├── axil_master.v          # AXI-Lite Master
│   ├── axil_uart.v            # UART Module
│   ├── axil_gpio.v            # GPIO Module
│   ├── axil_timer.v           # Timer Module
│   ├── z_core_32b_timer.v     # 32-bit Timer Module
│   ├── arbiter.v              # AXI-Lite Arbiter
│   ├── priority_encoder.v     # Priority Encoder Module
│   ├── axi_mem.v              # AXI-Lite RAM
│   └── flist.vc               # File list for simulation
│
├── tb/                        # Testbenches
│   ├── questa/                # QuestaSim scripts
│   │   ├── plot_axi.tcl       # AXI plot script
│   │   └── sim.tcl            # Simulation script
│   ├── Makefile               # Makefile for testbenches
│   ├── z_core_control_u_tb.sv # Full system test
│   ├── z_core_alu_tb.v        # ALU unit test
│   ├── z_core_alu_ctrl_tb.v   # ALU control test
│   ├── z_core_decoder_tb.v    # Decoder test
│   ├── z_core_reg_file_tb.v   # Register file test
│   ├── z_core_mult_unit_tb.v  # Multiplier unit test
│   ├── z_core_div_unit_tb.v   # Divider unit test
│   ├── axil_gpio_tb.v         # GPIO testbench
│   ├── axil_timer_tb.sv       # Timer testbench
│   ├── z_core_instr_cache_tb.sv # Instruction cache testbench
│   ├── z_core_branch_pred_tb.sv # Branch Predictor testbench
│   └── z_core_riscof_tb.sv    # RISCOF compliance testbench
│
└── doc/                       # Documentation
    ├── AXI_INTERFACE.md       # AXI protocol details
    ├── GPIO.md                # GPIO module documentation
    ├── UART.md                # UART module documentation
    ├── TIMER.md               # Timer module documentation
    ├── Z_CORE_ARCHITECTURE.md # Architecture overview
    ├── PIPELINE.md            # Pipeline implementation details
    ├── VERIFICATION.md        # Verification details
    └── EXCEPTIONS_AND_INTERRUPTS.md # Exception & interrupt handling
```

## Quick Start

### Prerequisites

- [QuestaSim FPGA Edition](https://www.altera.com/downloads/simulation-tools/questa-fpgas-pro-edition-software-version-25-3) (questa) or [Altair DSim](https://learn.altair.com/courses/getting-started-with-dsim-elearning) (dsim) for simulation
- [GTKWave](http://gtkwave.sourceforge.net/) or [Surfer](https://gitlab.com/surfer-project/surfer) for waveform viewing (optional)
- [Slang - System Verilog Language Services](https://github.com/MikePopoloski/slang) for linting (optional)

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/Z-Core.git
cd Z-Core

# Create simulation directory
mkdir -p sim
```

### Running Tests
- assumes Questa FPGA Edition or Altair DSim is installed and contained in user's PATH environment variable 

```bash
# Run full system batch-mode test using Questa Sim (default)
cd sim
make -f ../tb/Makefile run

# Run full system batch-mode test using Icarus Verilog
cd sim
make -f ../tb/Makefile run SIM=iverilog

# Run full system debug test using Questa Sim
cd sim
make -f ../tb/Makefile run debug=1

# Run full system batch-mode test using Altair Dsim
cd sim
make -f ../tb/Makefile run SIM=dsim

# Run full system debug test using Altair Dsim
cd sim
make -f ../tb/Makefile run SIM=dsim debug=1
```

### Expected Output

```
  ___________________________________________________________
 |           Z-Core RISC-V Processor Test Suite              |
 |                   RV32I Instruction Set                   |
 |___________________________________________________________|
 
 --- Loading Test 1: Arithmetic Operations ---
 
 === Test 1 Results: Arithmetic ===
   [PASS] ADDI x2, x0, 10: x2 = 10 (10 signed)
   [PASS] ADDI x3, x0, 7: x3 = 7 (7 signed)
  ...

 ___________________________________________________________
|                    TEST SUMMARY                           |
|___________________________________________________________|
|  Total Tests: 218                                         |
|  Passed:      218                                         |
|  Failed:        0                                         |
|___________________________________________________________|
|         ALL TESTS PASSED SUCCESSFULLY                     |
|  Test Duration: 743825 ns                                 |
|  Clock Cycles:  74382                                     |
|  Instructions:  59801                                     |
|  Writes=         81, Reads=         28                    |
|___________________________________________________________|

```

### Viewing Waveforms

```bash
# With GTK Wave
gtkwave sim/z_core_control_u_tb.vcd

# With Surfer
surfer sim/z_core_control_u_tb.vcd
```

## Test Coverage

The processor has been verified with a comprehensive system-level testbench (`tb/z_core_control_u_tb.sv`) plus dedicated module/unit testbenches.

| Test Suite | Description |
|------------|-------------|
| Arithmetic | ADD, SUB, ADDI |
| Logical | AND, OR, XOR, ANDI, ORI, XORI |
| Shifts | SLL, SRL, SRA, SLLI, SRLI, SRAI |
| Memory | LW, SW with AXI transactions |
| Compare | SLT, SLTU, SLTI, SLTIU |
| Upper Immediate | LUI, AUIPC |
| Integration | Fibonacci sequence |
| Branches | BEQ, BNE, BLT, BGE, BLTU, BGEU |
| Jumps | JAL, JALR, JALR+offset |
| Loop | Backward branch (sum 0..4) |
| IO Access | UART STATUS register |
| GPIO | Bidirectional GPIO |
| Byte/Halfword | LB, LH, LBU, LHU, SB, SH |
| UART Loopback | TX→RX data verification |
| M Extension | MUL, DIV, REM, Forwarding Stress |
| Stress Tests | RAW hazards, ALU coverage, Nested Loops, Mem Patterns |
| I-Cache Stress | Locality loops + direct-mapped conflict-miss thrash |
| Timer | Timer overflow and underflow |
| External Counter Timer | External counter timer mode |
| CSR Read/Write (Zicsr) | CSRRW, CSRRS, CSRRC, CSRRWI, CSRRSI, CSRRCI |
| Exceptions | ECALL, EBREAK, Illegal instruction traps |
| Timer Interrupt | Timer compare-match interrupt with MRET return |
| IRQ + Branch Pred Loop | Timer IRQ during actively predicted branch loop |
| Exception at Branch Target | Synchronous exception at mispredicted branch target |
| MRET Into Branch | MRET return into branch with predictor state |
| **RISCOF Compliance** | **Official RISC-V RV32IM Architectural Tests** |


## Performance

| Metric | Value |
|--------|-------|
| Pipeline Stages | 5-Stage (IF, ID, EX, MEM, WB) |
| Throughput | ~1 cycle per instruction (ideal, depends on instruction locality) |
| Register File | 32 x 32-bit |
| Memory Interface | AXI4-Lite |
| Memory Size | 64KB (configurable) |
| Cache Size | 256 Entries (configurable) |

## Performance Monitoring

Z-Core includes a basic hardware performance-monitoring facility. The **mcycle** CSR counts the number of clock cycles executed by the processor core on which the hart is running. The **minstret** CSR counts the number of instructions the hart has retired. Additionally, Z-Core has eight additional performance counters accessible through **mhpmcountert3–mhpmcounter10**. 

| Counter Name | Event |
|--------------|-------|
| mhpmcountert3 | Instruction Cache Hits |
| mhpmcountert4 | Data Cache Hits (Not implemented yet) |
| mhpmcountert5 | Load Requests |
| mhpmcountert6 | Store Requests |
| mhpmcountert7 | Branch Misspredictions |
| mhpmcountert8 | Pipeline flushes |
| mhpmcountert9 | Instruction Cache Misses |
| mhpmcountert10 | Memory Instruction Fetches |

> [!NOTE]
> For additional information regarding performance monitoring, refer to the RISC-V Privileged Specification Version 1.12.


## Configuration

The processor is parameterizable through top-level parameters:

```verilog
module z_core_top #(
    parameter DATA_WIDTH = 32,      // Data bus width
    parameter ADDR_WIDTH = 32,      // Address bus width
    parameter MEM_ADDR_WIDTH = 16,  // Memory size (2^16 = 64KB)
    parameter PIPELINE_OUTPUT = 0   // Memory pipeline stage
    parameter CACHE_DEPTH = 256      // Cache size (2^8 = 256 entries)
)(
    input wire clk,
    input wire rstn
);
```

## Documentation

Detailed documentation is available in the `doc/` directory:

- **[Architecture](doc/Z_CORE_ARCHITECTURE.md)** - Detailed architecture overview
- **[AXI Interface](doc/AXI_INTERFACE.md)** - Complete AXI-Lite protocol documentation
- **[Pipeline](doc/PIPELINE.md)** - Pipeline implementation details
- **[GPIO](doc/GPIO.md)** - Bidirectional GPIO module
- **[UART](doc/UART.md)** - Serial UART module
- **[Timer](doc/TIMER.md)** - Serial Timer module
- **[Exceptions & Interrupts](doc/EXCEPTIONS_AND_INTERRUPTS.md)** - M-mode trap handling details
- **[Verification](doc/VERIFICATION.md)** - Test coverage and verification methodology

## Roadmap

- [x] RV32I base integer instructions
- [x] AXI4-Lite memory interface
- [x] Comprehensive testbench
- [x] Modular IO (UART, GPIO)
- [x] Pipelining for improved throughput
- [x] FPGA synthesis and validation **[Z-Core-FPGA repository](https://github.com/paudiaz99/Z-Core-FPGA)** 
- [x] M extension (multiply/divide)
- [x] Instruction cache (simple direct-mapped, 1-word lines)
- [x] **Timer**
- [x] **Branch prediction**
- [x] **Interrupt support**
- [x] **CSR Unit & Zicsr extension (CSR instructions)**
- [x] **Exception / Trap Handling (Illegal Inst, ECALL, EBREAK)**
- [ ] VGA Controller
- [ ] Data Cache
- [ ] RISC-V A extension (atomic instructions)
- [ ] RISC-V C extension (compressed instructions)
- [ ] Fix all lint warnings

## Contributing

Contributions are welcome. Please feel free to submit a Pull Request.

### Possible Contributions

- Any feature in the roadmap.
- AXI4 interface for memory, replacing the current AXI4-Lite interface.
- Extensive verification of corner cases and error handling. UVM Verification is welcomed.
- Any cool feature you can think of!:D

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [RISC-V Foundation](https://riscv.org/) for the open ISA specification
- [Alex Forencich](https://github.com/alexforencich) for the AXI-Lite RAM module
- The open-source hardware community

## About the Project

The aim of this project is to gain a practical understanding of Computer Architecture and SoC design by building a system-on-chip. The implementation blends custom RTL, written from scratch, with established open-source modules (such as the AXI-Lite infrastructure) and utilizes AI tools to assist in development and verification. This project demonstrates the ability to architect a system, integrate third-party IP, and adopt modern engineering workflows.

---

<div align="center">

**Built for learning computer architecture and SoC design :D**

</div>
