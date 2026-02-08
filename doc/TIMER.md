# Timer Module Documentation

## Overview

The `axil_timer` module provides a 64-bit programmable timer/counter accessible via an AXI-Lite interface. It supports basic timing, event counting, and cascading operations.

## Features

- 64-bit Timer (split into two 32-bit registers)
- Configurable as Timer (clock cycle count) or Counter (external event count)
- Direction control (Count Up / Count Down)
- Cascading support for 64-bit operation
- AXI-Lite slave interface for register access

## Register Map

| Offset | Name        | Description              | Access |
|--------|-------------|--------------------------|--------|
| 0x00   | TIMER_LO    | Timer Low [31:0]         | R/W    |
| 0x04   | TIMER_HI    | Timer High [63:32]       | R/W    |
| 0x08   | TIMER_CTRL  | Timer Control Register   | R/W    |

### TIMER Registers (0x00, 0x04)
- **Write**: Loads the timer/counter with a specific value.
- **Read**: Returns the current value of the timer/counter.
- **Note**: Writing to these registers updates the internal 32 bit counter after the next clock cycle.

### TIMER_CTRL Register (0x08)

| Bit | Name         | Description |
|-----|--------------|-------------|
| 0   | ENABLE       | **1**: Enable Timer/Counter<br>**0**: Disable (Stop) |
| 1   | DIR          | **1**: Count Up<br>**0**: Count Down |
| 2   | MODE         | **1**: Counter Mode (External Event)<br>**0**: Timer Mode (Internal Clock) |
| 3   | IRQ_EN       | *Reserved (Interrupt Enable - Not Implemented)* |
| 4   | IRQ_FLAG     | *Reserved (Interrupt Flag - Not Implemented)* |

## Modes of Operation

### Timer Mode (Mode = 0)
Increments or decrements on every clock cycle when enabled. Used for measuring time intervals or generating delays.

### Counter Mode (Mode = 1)
Increments or decrements on the rising edge of the external event signal (`ext_event_i`). Used for counting external events like sensor pulses.

### 64-bit Cascading
The module automatically handles 64-bit cascading. The High timer increments/decrements only when the Low timer overflows/underflows, ensuring a seamless 64-bit value properly distributed across the two 32-bit registers.

## Interface

### AXI-Lite Slave
Standard AXI-Lite slave interface with:
- 32-bit data bus
- 12-bit address (4KB address space)

### External Signals
```verilog
input wire ext_event_i  // External event input for Counter Mode
```

## Usage Examples

### 1. Basic Timer (Count Up)
```c
// 1. Reset Timer Low and High
*(volatile uint32_t*)0x04002000 = 0;
*(volatile uint32_t*)0x04002004 = 0;

// 2. Enable Timer (Bit 0=1) + Count Up (Bit 1=1) + Timer Mode (Bit 2=0) -> 0x3
*(volatile uint32_t*)0x04002008 = 0x3;
```

### 2. Event Counter
```c
// 1. Reset Timer
*(volatile uint32_t*)0x04002000 = 0;

// 2. Enable Counter (Bit 0=1) + Count Up (Bit 1=1) + Counter Mode (Bit 2=1) -> 0x7
*(volatile uint32_t*)0x04002008 = 0x7;

// 3. Read Count
uint32_t count = *(volatile uint32_t*)0x04002000;
```

## Address Map in Z-Core System

| Peripheral | Base Address | Size |
|-----------|--------------|------|
| Memory    | 0x00000000   | 64MB |
| UART      | 0x04000000   | 4KB  |
| GPIO      | 0x04001000   | 4KB  |
| **Timer** | 0x04002000   | 4KB  |
