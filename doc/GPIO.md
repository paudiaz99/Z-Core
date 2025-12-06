# GPIO Module Documentation

## Overview

The `axil_gpio` module provides 64 bidirectional General Purpose Input/Output (GPIO) pins accessible via an AXI-Lite interface. Each pin can be independently configured as an input or output.

## Features

- 64 bidirectional GPIO pins
- Per-pin direction control
- AXI-Lite slave interface for register access
- Byte-addressable registers with strobe support

## Register Map

| Offset | Name      | Description           | Access |
|--------|-----------|----------------------|--------|
| 0x00   | DATA_LOW  | GPIO[31:0] data      | R/W    |
| 0x04   | DATA_HIGH | GPIO[63:32] data     | R/W    |
| 0x08   | DIR_LOW   | GPIO[31:0] direction | R/W    |
| 0x0C   | DIR_HIGH  | GPIO[63:32] direction| R/W    |

### DATA Registers (0x00, 0x04)
- **Write**: Sets the output value for pins configured as outputs
- **Read**: Returns the current state of the GPIO pins
  - For output pins: reads back the driven value
  - For input pins: reads the external signal

### DIR Registers (0x08, 0x0C)
- **Bit = 1**: Pin configured as **output**
- **Bit = 0**: Pin configured as **input** (high-impedance)

## Interface

### AXI-Lite Slave
Standard AXI-Lite slave interface with:
- 32-bit data bus
- 12-bit address (4KB address space)
- Byte strobes for partial writes

### GPIO Pins
```verilog
inout wire [N_GPIO-1:0] gpio
```
Bidirectional pins using tri-state buffers.

## Block Diagram

```
                    ┌──────────────────┐
    AXI-Lite        │                  │
    Slave IF ──────►│   axil_gpio      │◄────► GPIO[63:0]
                    │                  │
                    │  ┌────────────┐  │
                    │  │ DIR Regs   │  │
                    │  └────────────┘  │
                    │  ┌────────────┐  │
                    │  │ DATA Regs  │  │
                    │  └────────────┘  │
                    └──────────────────┘
```

## Usage Example

### Configure as Output and Drive
```c
// Set GPIO[31:0] as outputs
*(volatile uint32_t*)0x04001008 = 0xFFFFFFFF;  // DIR_LOW = all outputs

// Drive pattern on GPIO[31:0]
*(volatile uint32_t*)0x04001000 = 0x000000FF;  // DATA_LOW = 0xFF
```

### Configure as Input and Read
```c
// Set GPIO[31:0] as inputs
*(volatile uint32_t*)0x04001008 = 0x00000000;  // DIR_LOW = all inputs

// Read GPIO[31:0]
uint32_t value = *(volatile uint32_t*)0x04001000;  // Read DATA_LOW
```

## RTL Implementation

The module uses a generate block to create tri-state buffers for each GPIO pin:

```verilog
generate
    for (i = 0; i < N_GPIO; i = i + 1) begin : gpio_io_buffers
        assign gpio[i] = gpio_dir[i] ? gpio_data_out[i] : 1'bz;
    end
endgenerate
```

## Address Map in Z-Core System

| Peripheral | Base Address | Size |
|-----------|--------------|------|
| Memory    | 0x00000000   | 64MB |
| UART      | 0x04000000   | 4KB  |
| **GPIO**  | 0x04001000   | 4KB  |
