# UART Module Documentation

## Overview

The `axil_uart` module provides a serial UART interface accessible via AXI-Lite. It supports 8N1 format (8 data bits, no parity, 1 stop bit) with configurable baud rate.

## Features

- 8N1 serial format
- 16x oversampling for reliable reception
- Configurable baud rate divisor
- TX and RX enable controls
- Status flags: TX_EMPTY, TX_BUSY, RX_VALID, RX_ERR

## Register Map

| Offset | Name     | Description              | Access |
|--------|----------|--------------------------|--------|
| 0x00   | TX_DATA  | Write byte to transmit   | W      |
| 0x04   | RX_DATA  | Read received byte       | R      |
| 0x08   | STATUS   | Status register          | R      |
| 0x0C   | CTRL     | Control register         | R/W    |
| 0x10   | BAUD_DIV | Baud rate divisor        | R/W    |

### STATUS Register (0x08)

| Bit | Name     | Description              |
|-----|----------|--------------------------|
| 0   | TX_EMPTY | TX buffer empty          |
| 1   | TX_BUSY  | TX shift register active |
| 2   | RX_VALID | RX data available        |
| 3   | RX_ERR   | RX framing error         |

### CTRL Register (0x0C)

| Bit | Name  | Description        |
|-----|-------|--------------------|
| 0   | TX_EN | Enable transmitter |
| 1   | RX_EN | Enable receiver    |

### BAUD_DIV Register (0x10)

16-bit baud rate divisor. Formula:
```
BAUD_DIV = clock_freq / (16 * baud_rate)
```

Example: For 100MHz clock and 115200 baud:
```
BAUD_DIV = 100000000 / (16 * 115200) ≈ 54
```

## Interface

### Physical Pins
```verilog
output wire uart_tx,  // Transmit output
input  wire uart_rx   // Receive input
```

### AXI-Lite Slave
- 32-bit data bus
- 12-bit address (4KB address space)

## Block Diagram

```
                ┌──────────────────────────────────┐
    AXI-Lite    │           axil_uart              │
    Slave IF ──►│                                  │
                │  ┌─────────────────────────────┐ │
                │  │      Baud Generator         │ │
                │  └─────────────┬───────────────┘ │
                │                │ baud_tick       │
                │  ┌─────────────┴───────────────┐ │
                │  │    TX FSM    │    RX FSM    │ │    uart_tx
                │  │ IDLE→START→  │  IDLE→START→ │──────►
                │  │ DATA→STOP    │  DATA→STOP   │◄────── uart_rx
                │  └─────────────────────────────┘ │
                └──────────────────────────────────┘
```

## Usage Example

### Transmit a Byte
```c
// Wait for TX empty
while (!(*(volatile uint32_t*)0x04000008 & 0x1));

// Write byte to transmit
*(volatile uint32_t*)0x04000000 = 'A';  // TX_DATA
```

### Receive a Byte
```c
// Wait for RX valid
while (!(*(volatile uint32_t*)0x04000008 & 0x4));

// Read received byte
char c = *(volatile uint32_t*)0x04000004;  // RX_DATA
```

### Configure Baud Rate
```c
// Set baud rate for 115200 @ 100MHz clock
*(volatile uint32_t*)0x04000010 = 54;  // BAUD_DIV
```

## Address Map in Z-Core System

| Peripheral | Base Address | Size |
|------------|--------------|------|
| Memory     | 0x00000000   | 64MB |
| **UART**   | 0x04000000   | 4KB  |
| GPIO       | 0x04001000   | 4KB  |
