# Z-Core

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

## ✨ Features

- 🚀 **Full RV32I Implementation** - Complete base integer instruction set
- 🔌 **AXI4-Lite Interface** - Industry-standard memory bus protocol
- 📦 **Modular Design** - Clean separation of concerns with individual modules
- 🧪 **Comprehensive Testbenches** - Automated testing for all components
- 📖 **Well Documented** - Extensive documentation and code comments
- 🎯 **Educational Focus** - Perfect for learning computer architecture

## 🏗️ Architecture

```
                    ┌─────────────────────────────────────────────────────┐
                    │                   Z-Core CPU                         │
                    │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐ │
                    │  │ Decoder │  │Reg File │  │ALU Ctrl │  │   ALU   │ │
                    │  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘ │
                    │       └────────────┼───────────┼────────────┘       │
                    │                    │           │                     │
                    │            ┌───────┴───────────┴───────┐            │
                    │            │    Control Unit (FSM)      │            │
                    │            │  FETCH→DECODE→EXECUTE→WB   │            │
                    │            └─────────────┬──────────────┘            │
                    │                          │                           │
                    │            ┌─────────────┴──────────────┐            │
                    │            │      AXI-Lite Master       │            │
                    │            └─────────────┬──────────────┘            │
                    └──────────────────────────┼───────────────────────────┘
                                               │ AXI-Lite Bus
                    ┌──────────────────────────┴───────────────────────────┐
                    │                   Memory (64KB RAM)                   │
                    └──────────────────────────────────────────────────────┘
```

## 📋 Supported Instructions

| Type | Instructions | Description |
|------|-------------|-------------|
| **R-Type** | `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND` | Register-register operations |
| **I-Type** | `ADDI`, `SLTI`, `SLTIU`, `XORI`, `ORI`, `ANDI`, `SLLI`, `SRLI`, `SRAI` | Immediate operations |
| **Load** | `LB`, `LH`, `LW`, `LBU`, `LHU` | Memory load |
| **Store** | `SB`, `SH`, `SW` | Memory store |
| **Branch** | `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU` | Conditional branching |
| **Jump** | `JAL`, `JALR` | Jump and link |
| **Upper** | `LUI`, `AUIPC` | Upper immediate |

## 📁 Project Structure

```
Z-Core/
├── 📂 rtl/                    # RTL source files
│   ├── z_core_top_model.v     # Top-level SoC
│   ├── z_core_control_u.v     # Control unit / CPU core
│   ├── z_core_decoder.v       # Instruction decoder
│   ├── z_core_reg_file.v      # 32x32-bit register file
│   ├── z_core_alu.v           # Arithmetic logic unit
│   ├── z_core_alu_ctrl.v      # ALU control
│   ├── axil_master.v          # AXI-Lite master
│   └── axi_mem.v              # AXI-Lite RAM
│
├── 📂 tb/                     # Testbenches
│   ├── z_core_control_u_tb.v  # Full system test
│   ├── z_core_alu_tb.v        # ALU unit test
│   ├── z_core_alu_ctrl_tb.v   # ALU control test
│   ├── z_core_decoder_tb.v    # Decoder test
│   └── z_core_reg_file_tb.v   # Register file test
│
├── 📂 sim/                    # Simulation outputs
│   ├── *.vvp                  # Compiled simulations
│   └── *.vcd                  # Waveform files
│
└── 📂 doc/                    # Documentation
    ├── AXI_INTERFACE.md       # AXI protocol details
    └── Z_CORE_ARCHITECTURE.md # Architecture overview
```

## 🚀 Quick Start

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
║  Total Tests:  42                                          ║
║  Passed:       42                                          ║
║  Failed:        0                                          ║
╠═══════════════════════════════════════════════════════════╣
║         ✓ ALL TESTS PASSED SUCCESSFULLY ✓                 ║
╚═══════════════════════════════════════════════════════════╝
```

### Viewing Waveforms

```bash
gtkwave sim/z_core_control_u_tb.vcd
```

## ⚡ Performance

| Metric | Value |
|--------|-------|
| Pipeline Stages | Multi-cycle (5-6 stages) |
| Clock Cycles per Instruction | 5-10 (varies by type) |
| Register File | 32 x 32-bit |
| Memory Interface | AXI4-Lite |
| Memory Size | 64KB (configurable) |

## 🔧 Configuration

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

## 📚 Documentation

Detailed documentation is available in the `doc/` directory:

- **[AXI Interface](doc/AXI_INTERFACE.md)** - Complete AXI-Lite protocol documentation
- **[Architecture](doc/Z_CORE_ARCHITECTURE.md)** - Detailed architecture overview

## 🗺️ Roadmap

- [x] RV32I base integer instructions
- [x] AXI4-Lite memory interface
- [x] Comprehensive testbench
- [ ] Branch prediction
- [ ] Pipelining for improved throughput
- [ ] M extension (multiply/divide)
- [ ] C extension (compressed instructions)
- [ ] Interrupt support
- [ ] FPGA synthesis and validation
- [ ] Cache subsystem

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [RISC-V Foundation](https://riscv.org/) for the open ISA specification
- [Alex Forencich](https://github.com/alexforencich) for the AXI-Lite RAM module
- The open-source hardware community

---

<div align="center">

**Built with ❤️ for learning computer architecture**

*If you find this project helpful, please consider giving it a ⭐!*

</div>
