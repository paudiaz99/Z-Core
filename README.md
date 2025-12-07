<div align="center">

```
                    ███████╗       ██████╗ ██████╗ ██████╗ ███████╗
                    ╚══███╔╝      ██╔════╝██╔═══██╗██╔══██╗██╔════╝
                      ███╔╝ █████╗██║     ██║   ██║██████╔╝█████╗  
                     ███╔╝  ╚════╝██║     ██║   ██║██╔══██╗██╔══╝  
                    ███████╗      ╚██████╗╚██████╔╝██║  ██║███████╗
                    ╚══════╝       ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝
```

**A lightweight, educational RISC-V RV32I processor core**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Verilog](https://img.shields.io/badge/HDL-Verilog-blue.svg)](https://en.wikipedia.org/wiki/Verilog)
[![RISC-V](https://img.shields.io/badge/ISA-RISC--V%20RV32I-green.svg)](https://riscv.org/)

</div>

---

## Features

- **5-Stage Pipeline** - Classic RISC-V 5-stage pipeline implementation
- **AXI4-Lite Interface** - Industry-standard memory bus protocol
- **Modular Design** - Clean separation of concerns with individual modules
- **Comprehensive Testbenches** - Automated testing for all components
- **Well Documented** - Extensive documentation and code comments
- **Educational Focus** - Perfect for learning computer architecture

## Architecture

```
                    ┌─────────────────────────────────────────────────────┐
                    │                   Z-Core CPU                        │
                    │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐ │
                    │  │ Decoder │  │Reg File │  │ALU Ctrl │  │   ALU   │ │
                    │  └────┬────┘  └────┬────┘  └───┬─────┘  └────┬────┘ │
                    │       └────────────┼───────────┼─────────────┘      │
                    │                    │           │                    │
                    │        ┌───►┌────────┐──►┌────────┐──►┌────────┐──►┌────────┐ │
                    │        │    │ FETCH  │   │ DECODE │   │EXECUTE │   │WB/MEM  │ │
                    │        │    └────────┘   └────────┘   └────────┘   └────────┘ │
                    │        │         ▲            ▲            ▲            ▲     │
                    │        └─────────┴────────────┴────────────┴────────────┘     │
                    │                      Control Unit (Pipeline)                  │
                    │                          │                          │
                    │            ┌─────────────┴──────────────┐           │
                    │            │      AXI-Lite Master       │           │
                    │            └─────────────┬──────────────┘           │
                    └──────────────────────────┼──────────────────────────┘
                                               │ AXI-Lite Bus
                                               ▼
                                  ┌─────────────────────────┐
                                  │  AXI-Lite Interconnect  │
                                  └─┬──────────┬──────────┬─┘
                                    │          │          │
                ┌───────────────────▼─┐  ┌─────▼────┐  ┌──▼───────┐
                │    Memory (RAM)     │  │   UART   │  │   GPIO   │
                └─────────────────────┘  └──────────┘  └──────────┘
```

## Supported Instructions

| Type | Instructions | Description |
|------|-------------|-------------|
| **R-Type** | `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND` | Register-register operations |
| **I-Type** | `ADDI`, `SLTI`, `SLTIU`, `XORI`, `ORI`, `ANDI`, `SLLI`, `SRLI`, `SRAI` | Immediate operations |
| **Load** | `LB`, `LH`, `LW`, `LBU`, `LHU` | Memory load |
| **Store** | `SB`, `SH`, `SW` | Memory store |
| **Branch** | `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU` | Conditional branching |
| **Jump** | `JAL`, `JALR` | Jump and link |
| **Upper** | `LUI`, `AUIPC` | Upper immediate |

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
│   ├── axil_interconnect.v    # AXI-Lite Interconnect
│   ├── axil_slave.v           # Generic AXI-Lite Slave
│   ├── axil_uart.v            # UART Module
│   ├── axil_gpio.v            # GPIO Module
│   └── axi_mem.v              # AXI-Lite RAM
│
├── tb/                        # Testbenches
│   ├── z_core_control_u_tb.v  # Full system test
│   ├── z_core_alu_tb.v        # ALU unit test
│   ├── z_core_alu_ctrl_tb.v   # ALU control test
│   ├── z_core_decoder_tb.v    # Decoder test
│   └── z_core_reg_file_tb.v   # Register file test
│
├── sim/                       # Simulation outputs
│   ├── *.vvp                  # Compiled simulations
│   └── *.vcd                  # Waveform files
│
└── doc/                       # Documentation
    ├── AXI_INTERFACE.md       # AXI protocol details
    ├── GPIO.md                # GPIO module documentation
    ├── UART.md                # UART module documentation
    ├── Z_CORE_ARCHITECTURE.md # Architecture overview
    └── VERIFICATION.md        # Verification details
```

## Quick Start

### Prerequisites

- [Icarus Verilog](http://iverilog.icarus.com/) (iverilog) for simulation
- [GTKWave](http://gtkwave.sourceforge.net/) for waveform viewing (optional)

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/Z-Core.git
cd Z-Core

# Create simulation directory
mkdir -p sim
```

### Running Tests

```bash
# Run individual module tests
iverilog -o sim/z_core_alu_tb.vvp tb/z_core_alu_tb.v && vvp sim/z_core_alu_tb.vvp

# Run full system test (comprehensive)
iverilog -g2012 -o sim/z_core_control_u_tb.vvp tb/z_core_control_u_tb.v
vvp sim/z_core_control_u_tb.vvp
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
║  Total Tests:  133                                         ║
║  Passed:       133                                         ║
║  Failed:        0                                          ║
╠═══════════════════════════════════════════════════════════╣
║         ✓ ALL TESTS PASSED SUCCESSFULLY ✓                ║
╚═══════════════════════════════════════════════════════════╝
```

### Viewing Waveforms

```bash
gtkwave sim/z_core_control_u_tb.vcd
```

## Test Coverage

The processor has been verified with **133 comprehensive tests** across 15 test suites:

| Test Suite | Description | Tests |
|------------|-------------|-------|
| Arithmetic | ADD, SUB, ADDI | 6 |
| Logical | AND, OR, XOR, ANDI, ORI, XORI | 8 |
| Shifts | SLL, SRL, SRA, SLLI, SRLI, SRAI | 8 |
| Memory | LW, SW with AXI transactions | 8 |
| Compare | SLT, SLTU, SLTI, SLTIU | 8 |
| Upper Immediate | LUI, AUIPC | 4 |
| Integration | Fibonacci sequence | 9 |
| Branches | BEQ, BNE, BLT, BGE, BLTU, BGEU | 7 |
| Jumps | JAL, JALR, JALR+offset | 7 |
| Loop | Backward branch (sum 0..4) | 3 |
| IO Access | UART STATUS register | 1 |
| GPIO | Bidirectional GPIO | 2 |
| Byte/Halfword | LB, LH, LBU, LHU, SB, SH | 8 |
| UART Loopback | TX→RX data verification | 1 |
| Stress Tests | RAW hazards, ALU coverage, Nested Loops, Mem Patterns | 53 |

## Performance

| Metric | Value |
|--------|-------|
| Pipeline Stages | 5-Stage (IF, ID, EX, MEM, WB) |
| Throughput | ~1 cycle per instruction (ideal) |
| Register File | 32 x 32-bit |
| Memory Interface | AXI4-Lite |
| Memory Size | 64KB (configurable) |

## Configuration

The processor is parameterizable through top-level parameters:

```verilog
module z_core_top #(
    parameter DATA_WIDTH = 32,      // Data bus width
    parameter ADDR_WIDTH = 32,      // Address bus width
    parameter MEM_ADDR_WIDTH = 16,  // Memory size (2^16 = 64KB)
    parameter PIPELINE_OUTPUT = 0   // Memory pipeline stage
)(
    input wire clk,
    input wire rstn
);
```

## Documentation

Detailed documentation is available in the `doc/` directory:

- **[Architecture](doc/Z_CORE_ARCHITECTURE.md)** - Detailed architecture overview
- **[AXI Interface](doc/AXI_INTERFACE.md)** - Complete AXI-Lite protocol documentation
- **[GPIO](doc/GPIO.md)** - Bidirectional GPIO module
- **[UART](doc/UART.md)** - Serial UART module
- **[Verification](doc/VERIFICATION.md)** - Test coverage and verification methodology

## Roadmap

- [x] RV32I base integer instructions
- [x] AXI4-Lite memory interface
- [x] Comprehensive testbench
- [x] Modular IO (UART, GPIO)
- [x] Pipelining for improved throughput
- [ ] Branch prediction
- [ ] M extension (multiply/divide)
- [ ] C extension (compressed instructions)
- [ ] Interrupt support
- [ ] FPGA synthesis and validation
- [ ] Cache subsystem

## Contributing

Contributions are welcome. Please feel free to submit a Pull Request.

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

---

<div align="center">

**Built for learning computer architecture**

</div>
