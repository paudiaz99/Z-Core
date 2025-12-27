# Z-Core AXI-Lite Interface Documentation

## Overview

The Z-Core processor communicates with external memory through an AXI4-Lite interface. This document describes the interface architecture, signal descriptions, and timing requirements.

## Architecture

```
┌───────────────────────────────────────────────────────────────────┐
│                          z_core_control_u                         │
│┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │
││   Decoder   │  │  Reg File   │  │  ALU Ctrl   │  │     ALU     │ │
│└─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘ │
│                                                                   │
│┌─────────────────────────────────────────────────────────────────┐│
││                    FSM Controller                               ││
││  FETCH → FETCH_WAIT → DECODE → EXECUTE → [MEM] → [WRITE]        ││
│└─────────────────────────────────────────────────────────────────┘│
│                              │                                    │
│                   ┌──────────┴──────────┐                         │
│                   │  Simple Memory I/F  │                         │
│                   │  mem_req, mem_wen   │                         │
│                   │  mem_addr, mem_rdata│                         │
│                   └──────────┬──────────┘                         │
│                              │                                    │
│                   ┌──────────┴──────────┐                         │
│                   │    axil_master      │                         │
│                   │  (Protocol Handler) │                         │
│                   └──────────┬──────────┘                         │
│                              │                                    │
└──────────────────────────────┼────────────────────────────────────┘
                               │ AXI-Lite Interface
                               ▼
┌───────────────────────────────────────────────────────────────────┐
│                          axil_ram                                 │
│                     (Memory Subsystem)                            │
└───────────────────────────────────────────────────────────────────┘
```

## AXI-Lite Signal Description

### Parameters

| Parameter    | Default | Description                          |
|-------------|---------|--------------------------------------|
| DATA_WIDTH  | 32      | Data bus width in bits               |
| ADDR_WIDTH  | 32      | Address bus width in bits            |
| STRB_WIDTH  | 4       | Write strobe width (DATA_WIDTH/8)    |

### Write Address Channel

| Signal           | Direction | Width      | Description                      |
|------------------|-----------|------------|----------------------------------|
| m_axil_awaddr    | Output    | ADDR_WIDTH | Write address                    |
| m_axil_awprot    | Output    | 3          | Protection type (fixed: 3'b000)  |
| m_axil_awvalid   | Output    | 1          | Write address valid              |
| m_axil_awready   | Input     | 1          | Write address ready              |

### Write Data Channel

| Signal           | Direction | Width      | Description                      |
|------------------|-----------|------------|----------------------------------|
| m_axil_wdata     | Output    | DATA_WIDTH | Write data                       |
| m_axil_wstrb     | Output    | STRB_WIDTH | Write strobes (byte enables)     |
| m_axil_wvalid    | Output    | 1          | Write data valid                 |
| m_axil_wready    | Input     | 1          | Write data ready                 |

### Write Response Channel

| Signal           | Direction | Width | Description                           |
|------------------|-----------|-------|---------------------------------------|
| m_axil_bresp     | Input     | 2     | Write response (OKAY=2'b00)           |
| m_axil_bvalid    | Input     | 1     | Write response valid                  |
| m_axil_bready    | Output    | 1     | Write response ready                  |

### Read Address Channel

| Signal           | Direction | Width      | Description                      |
|------------------|-----------|------------|----------------------------------|
| m_axil_araddr    | Output    | ADDR_WIDTH | Read address                     |
| m_axil_arprot    | Output    | 3          | Protection type (fixed: 3'b000)  |
| m_axil_arvalid   | Output    | 1          | Read address valid               |
| m_axil_arready   | Input     | 1          | Read address ready               |

### Read Data Channel

| Signal           | Direction | Width      | Description                      |
|------------------|-----------|------------|----------------------------------|
| m_axil_rdata     | Input     | DATA_WIDTH | Read data                        |
| m_axil_rresp     | Input     | 2          | Read response (OKAY=2'b00)       |
| m_axil_rvalid    | Input     | 1          | Read data valid                  |
| m_axil_rready    | Output    | 1          | Read data ready                  |

## AXI Master State Machine

The `axil_master` module implements the AXI-Lite protocol with the following states:

```
                    ┌──────────┐
                    │   IDLE   │◄─────────────────────┐
                    └────┬─────┘                      │
                         │ mem_req                    │
            ┌────────────┴────────────┐               │
            │                         │               │
            ▼                         ▼               │
     ┌─────────────┐          ┌─────────────┐         │
     │ READ_ADDR   │          │ WRITE_ADDR  │         │
     │(arvalid=1)  │          │(awvalid=1)  │         │
     └──────┬──────┘          │(wvalid=1)   │         │
            │ arready         └──────┬──────┘         │
            ▼                        │ awready &      │
     ┌─────────────┐                 │ wready         │
     │ READ_DATA   │                 ▼                │
     │(rready=1)   │          ┌─────────────┐         │
     └──────┬──────┘          │ WRITE_RESP  │         │
            │ rvalid          │(bready=1)   │         │
            │                 └──────┬──────┘         │
            │                        │ bvalid         │
            │                        │                │
            └────────────────────────┴────────────────┘
                         mem_ready pulse
```

### State Descriptions

| State       | Description                                              |
|-------------|----------------------------------------------------------|
| IDLE        | Waiting for memory request                               |
| READ_ADDR   | Assert arvalid, wait for arready                         |
| READ_DATA   | Assert rready, wait for rvalid, capture data             |
| WRITE_ADDR  | Assert awvalid & wvalid, wait for ready signals          |
| WRITE_RESP  | Assert bready, wait for bvalid                           |

## Timing Diagrams

### Read Transaction

```
           ┌───┐   ┌───┐   ┌───┐   ┌───┐   ┌───┐   ┌───┐
clk        │   │   │   │   │   │   │   │   │   │   │   │
       ────┘   └───┘   └───┘   └───┘   └───┘   └───┘   └───

               ┌───────────────┐
mem_req    ────┘               └───────────────────────────
           
                   ┌───────────────────────┐
arvalid    ────────┘                       └───────────────

                       ┌───────────────┐
arready    ────────────┘               └───────────────────

                               ┌───────────────────────────
rready     ────────────────────┘                           

                               ┌───────────────┐
rvalid     ────────────────────┘               └───────────

                                       ┌───────┐
mem_ready  ────────────────────────────┘       └───────────
```

### Write Transaction

```
           ┌───┐   ┌───┐   ┌───┐   ┌───┐   ┌───┐   ┌───┐
clk        │   │   │   │   │   │   │   │   │   │   │   │
       ────┘   └───┘   └───┘   └───┘   └───┘   └───┘   └───

               ┌───────────────┐
mem_req    ────┘               └───────────────────────────
               ┌───────────────────────────────────────────
mem_wen    ────┘                                           

                   ┌───────────────────────┐
awvalid    ────────┘                       └───────────────
                   ┌───────────────────────┐
wvalid     ────────┘                       └───────────────

                       ┌───────────────┐
awready    ────────────┘               └───────────────────
                       ┌───────────────┐
wready     ────────────┘               └───────────────────

                               ┌───────────────────────────
bready     ────────────────────┘                           

                               ┌───────────────┐
bvalid     ────────────────────┘               └───────────

                                       ┌───────┐
mem_ready  ────────────────────────────┘       └───────────
```

## Control Unit FSM Integration

The Z-Core control unit uses a multi-cycle FSM that interfaces with memory through the AXI master:

| State       | Memory Operation | Description                           |
|-------------|------------------|---------------------------------------|
| FETCH       | Read (PC)        | Initiate instruction fetch            |
| FETCH_WAIT  | -                | Wait for instruction data             |
| DECODE      | -                | Decode instruction                    |
| EXECUTE     | Read/Write       | For load/store, initiate data access  |
| MEM         | -                | Wait for data memory operation        |
| WRITE       | -                | Write result to register file         |

### Memory Access Timing

- **Instruction Fetch**: ~4-5 clock cycles (request + AXI handshake)
- **Data Load**: ~4-5 clock cycles (same as fetch)
- **Data Store**: ~4-5 clock cycles (write + response)

## Usage Example

### Instantiation

```verilog
z_core_control_u #(
    .DATA_WIDTH(32),
    .ADDR_WIDTH(32),
    .STRB_WIDTH(4)
) u_core (
    .clk(clk),
    .rstn(rstn),
    
    // AXI-Lite Master Interface
    .m_axil_awaddr(axil_awaddr),
    .m_axil_awprot(axil_awprot),
    .m_axil_awvalid(axil_awvalid),
    .m_axil_awready(axil_awready),
    .m_axil_wdata(axil_wdata),
    .m_axil_wstrb(axil_wstrb),
    .m_axil_wvalid(axil_wvalid),
    .m_axil_wready(axil_wready),
    .m_axil_bresp(axil_bresp),
    .m_axil_bvalid(axil_bvalid),
    .m_axil_bready(axil_bready),
    .m_axil_araddr(axil_araddr),
    .m_axil_arprot(axil_arprot),
    .m_axil_arvalid(axil_arvalid),
    .m_axil_arready(axil_arready),
    .m_axil_rdata(axil_rdata),
    .m_axil_rresp(axil_rresp),
    .m_axil_rvalid(axil_rvalid),
    .m_axil_rready(axil_rready)
);
```

### Connecting to AXI-Lite RAM

```verilog
axil_ram #(
    .DATA_WIDTH(32),
    .ADDR_WIDTH(16),
    .PIPELINE_OUTPUT(0)
) u_ram (
    .clk(clk),
    .rstn(rstn),
    
    .s_axil_awaddr(axil_awaddr[15:0]),
    .s_axil_awprot(axil_awprot),
    .s_axil_awvalid(axil_awvalid),
    .s_axil_awready(axil_awready),
    // ... remaining signals
);
```

## Simulation

Run the testbench to verify AXI interface operation:

```bash
cd /path/to/Z-Core
iverilog -g2012 -o sim/z_core_control_u_tb.vvp tb/z_core_control_u_tb.v
vvp sim/z_core_control_u_tb.vvp
```

View waveforms:

```bash
gtkwave sim/z_core_control_u_tb.vcd
```

## Files

| File                      | Description                              |
|---------------------------|------------------------------------------|
| rtl/axil_master.v         | AXI-Lite master protocol handler         |
| rtl/axi_mem.v             | AXI-Lite RAM slave                       |
| rtl/z_core_control_u.v    | Control unit with AXI master integration |
| tb/z_core_control_u_tb.v  | Testbench for AXI interface verification |

## Acknowledgements

The AXI-Lite infrastructure used in this project is based on the open-source [Verilog AXI Components](https://github.com/alexforencich/verilog-axi) by [Alex Forencich](https://github.com/alexforencich). Specifically, the following modules are utilized:

- `axil_interconnect`: AXI-Lite Interconnect
- `axil_ram`: AXI-Lite RAM (modified as `axi_mem`)
- `arbiter`: Generic round-robin arbiter
- `priority_encoder`: Priority encoder logic

> [!NOTE]
> Future plans include replacing these modules with custom implementations to support full AXI4 burst operations.

## References

- [AMBA AXI4-Lite Protocol Specification](https://developer.arm.com/documentation/ihi0022/latest)
- Z-Core RISC-V Implementation Documentation

