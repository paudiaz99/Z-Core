# Z-Core RISC-V Compliance Verification Report

**Date:** December 8, 2025
**Status:** PASSED (RV32I Base Integer Instruction Set)

## 1. Objective
Achieve architectural accuracy and compliance for the Z-Core RV32I processor using the official RISCOF (RISC-V Architectural Test Framework).

## 2. Test Environment
*   **Framework**: RISCOF (RISC-V Compliance Framework)
*   **Test Suite**: `riscv-arch-test` (RV32I Base Suite)
*   **DUT (Device Under Test)**: Z-Core (Verilog RTL)
    *   Simulator: Iverilog `v12.0` (via `vvp`)
    *   Wrapper: `riscof/z_core/run_sim.sh`
*   **Reference Model**: Sail-RISCV C Simulator (`sail_riscv_sim_RV32`)

## 3. Configuration Setup
Key files configured for the verification environment:
*   `riscof/config.ini`: Defines DUT (`z_core`) and Reference (`sail_cSim`) plugins.
*   `riscof/z_core/riscof_z_core.py`: Python plugin to compile tests, convert ELF to HEX, run simulation, and extract signatures.
*   `tb/z_core_riscof_tb.sv`: Dedicated testbench interfacing Z-Core with the compliance tests.

## 4. Issues Encountered & Solutions

### 4.1. ALU Latch / Logic Error
*   **Symptom**: Inconsistent branch behavior.
*   **Root Cause**: In `rtl/z_core_alu.v`, the signals `alu_out` and `alu_branch` were not explicitly initialized in all paths of the combinational logic, potentially invoking latch inference or undefined states.
*   **Fix**: Added explicit default initialization at the start of the `always @(*)` block.

### 4.2. Memory Size / Timeout
*   **Symptom**: Tests failing due to insufficient memory or "timeout" before completion.
*   **Root Cause**: RISCOF tests for branches (e.g., `beq-01.S`, `jal-01.S`) are large (>100KB code + data) and run for millions of cycles.
*   **Fix**: 
    1.  Increased Testbench RAM to 2MB (`ADDR_WIDTH = 21`).
    2.  Increased simulation timeout to 50,000,000 cycles.

### 4.3. High Address Truncation (Major Bug)
*   **Symptom**: Branch and Jump tests passed execution but produced empty/incorrect signatures (`0xdeadbeef`).
*   **Investigation**: 
    *   Debugging revealed that while the processor executed correctly, writes to the signature region (located at `0x3a110` and above) were not reaching the RAM model.
    *   Waveform analysis and minimal test cases (`test_high_mem.S`) showed CPU issuing correct write requests.
*   **Root Cause**: In `tb/z_core_riscof_tb.sv`, the AXI-Lite RAM instantiation hardcoded the address bus slice to 16 bits:
    ```verilog
    .s_axil_awaddr(m_axil_awaddr[0*ADDR_WIDTH +: 16]) // BUG: Truncates >64KB
    ```
*   **Fix**: Corrected the slice width to use the full `ADDR_WIDTH` (32 bits):
    ```verilog
    .s_axil_awaddr(m_axil_awaddr[0*ADDR_WIDTH +: ADDR_WIDTH])
    ```

## 5. Verification Results
After applying the fixes, the full RISCOF RV32I suite was run.

| Suite | Tests Run | Passed | Failed |
| :--- | :---: | :---: | :---: |
| **RV32I** | **41** | **41** | **0** |

**Conclusion**: Z-Core is fully compliant with the RV32I base user-level ISA.

## 6. Next Steps
1.  **Regression Testing**: Add RISCOF run to CI/CD pipeline.
2.  **Extensions**:
    *   Verify **M-Extension** (Multiplication/Division) if implemented.
    *   Verify **CSRs** (Zicsr) and Exception handling compliance.
3.  **Performance**: Analyze CPI (Cycles Per Instruction) using the compliance tests as micro-benchmarks.
