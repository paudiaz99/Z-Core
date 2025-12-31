# Z-Core RISC-V Pipeline Architecture

## Overview

The Z-Core implements a **5-stage in-order stalling pipeline** for the RV32IM instruction set. This document describes the complete pipeline architecture, data flow, hazard handling, memory interface, and implementation details.

---

## Pipeline Stages

```mermaid
graph LR
    IF["IF\nInstruction Fetch"] --> ID["ID\nDecode"]
    ID --> EX["EX\nExecute"]
    EX --> MEM["MEM\nMemory"]
    MEM --> WB["WB\nWriteback"]
    
    style IF fill:#e1f5fe
    style ID fill:#fff3e0
    style EX fill:#e8f5e9
    style MEM fill:#fce4ec
    style WB fill:#f3e5f5
```

### Stage Descriptions

| Stage | Function | Key Operations | Latency |
|-------|----------|----------------|---------|
| **IF** | Instruction Fetch | Read instruction via AXI-Lite, manage PC, handle fetch buffer | 10-11 cycles (AXI) |
| **ID** | Instruction Decode | Decode opcode, read register file, generate immediates, detect hazards | 1 cycle |
| **EX** | Execute | ALU operations, branch condition evaluation, target calculation | 1 cycle |
| **MEM** | Memory Access | Load/Store via AXI-Lite, byte/halfword extraction | 10-11 cycles (AXI) |
| **WB** | Writeback | Write results to register file | 1 cycle |

---

## Detailed Stage Architecture

> [!IMPORTANT]
> Some of the diagrams may not be up to date with the current implementation and the instruction cache.

### IF Stage (Instruction Fetch)

The IF stage manages instruction fetching with these key components:

```mermaid
graph TD
    PC[Program Counter] --> ARBITER[Memory Arbiter]
    ARBITER --> AXI[AXI Master]
    AXI --> |mem_rdata| FETCH_CTRL[Fetch Controller]
    FETCH_CTRL --> |Direct| IF_ID[IF/ID Register]
    FETCH_CTRL --> |Buffered| BUFFER[Fetch Buffer]
    BUFFER --> IF_ID
    
    FLUSH[Flush Signal] --> |"PC ← target"| PC
    FLUSH --> |invalidate| IF_ID
    FLUSH --> |invalidate| BUFFER
```

**Key Features:**
- **Fetch Buffer**: Decouples fetch from pipeline stalls. If IF/ID is busy, fetched instruction goes to buffer.
- **PC Tracking**: `fetch_pc` register captures PC when fetch starts, ensuring correct PC association even if flush occurs mid-fetch.
- **Flush Handling**: On flush, both IF/ID and fetch buffer are invalidated, PC is redirected to target.

**Key Signals:**
| Signal | Description |
|--------|-------------|
| `fetch_wait` | Fetch operation in progress |
| `fetch_pc` | PC value for current fetch (captured at start) |
| `fetch_buffer_valid` | Fetch buffer contains valid instruction |
| `if_id_valid` | IF/ID register contains valid instruction |

### ID Stage (Instruction Decode)

The ID stage decodes instructions and handles data hazard detection:

```mermaid
graph LR
    IF_ID[IF/ID Register] --> DECODER[Decoder]
    DECODER --> IMM[Immediate Generator]
    DECODER --> CTRL[Control Signals]
    IF_ID --> REG[Register File Read]
    
    REG --> FWD[Forwarding Mux]
    EX_MEM[EX/MEM] --> FWD
    MEM_WB[MEM/WB] --> FWD
    
    FWD --> ID_EX[ID/EX Register]
    IMM --> ID_EX
    CTRL --> ID_EX
```

**Forwarding to Decode:**
The decode stage can receive forwarded data for immediate use in ID/EX:

```verilog
dec_fwd_rs1 = (ex_mem_valid && ex_mem_reg_write && ex_mem_rd == dec_rs1 && dec_rs1 != 0) 
                ? ex_mem_alu_result :
              (mem_wb_valid && mem_wb_reg_write && mem_wb_rd == dec_rs1 && mem_wb_rd != 0) 
                ? mem_wb_result :
              rf_rs1_data;
```

### EX Stage (Execute)

The EX stage performs ALU operations, evaluates branches, and handles division:

```mermaid
graph TD
    ID_EX[ID/EX Register] --> ALU_MUX1[ALU Input 1 Mux]
    ID_EX --> ALU_MUX2[ALU Input 2 Mux]
    ALU_MUX1 --> ALU[ALU]
    ALU_MUX2 --> ALU
    ALU_MUX1 --> DIV[Division Unit]
    ALU_MUX2 --> DIV
    
    ALU --> RESULT_MUX[Result Mux]
    DIV --> |div_result| RESULT_MUX
    ID_EX --> |PC+4| RESULT_MUX
    ID_EX --> |Immediate| RESULT_MUX
    
    ID_EX --> BRANCH[Branch Evaluator]
    BRANCH --> |taken?| FLUSH[Flush Control]
    
    RESULT_MUX --> EX_MEM[EX/MEM Register]
    ID_EX --> |Target| EX_MEM
```

**ALU Input Selection:**
```
alu_in1 = (LUI)   ? 0
        : (AUIPC) ? id_ex_pc
        :          fwd_rs1_data

alu_in2 = (I-type|Load|Store|LUI|AUIPC|Jump) ? immediate
        :                                       fwd_rs2_data
```

**Result Selection:**
```
ex_result = (LUI)        ? immediate
          : (AUIPC)      ? pc + immediate  
          : (JAL|JALR)   ? pc + 4          (return address)
          : (DIV/REM)    ? div_result      (division/remainder)
          :                alu_out
```

### MEM Stage (Memory Access)

The MEM stage handles load/store operations with byte/halfword support:

```mermaid
graph TD
    EX_MEM[EX/MEM Register] --> ADDR[Address]
    EX_MEM --> WDATA[Write Data]
    
    ADDR --> ARBITER[Memory Arbiter]
    WDATA --> AXI[AXI Master]
    ARBITER --> AXI
    
    AXI --> |mem_rdata| EXTRACT[Byte/Halfword Extraction]
    EXTRACT --> |Combinational| MEM_WB[MEM/WB Register]
    
    EX_MEM --> |ALU Result| MEM_WB
```

**Load Data Extraction (Combinational):**
```verilog
always @* begin
    case (ex_mem_funct3)
        3'b000: mem_load_data = {{24{mem_rdata[byte_pos+7]}}, mem_rdata[...]}; // LB
        3'b001: mem_load_data = {{16{mem_rdata[hw_pos+15]}}, mem_rdata[...]};  // LH
        3'b010: mem_load_data = mem_rdata;                                      // LW
        3'b100: mem_load_data = {24'b0, mem_rdata[...]};                        // LBU
        3'b101: mem_load_data = {16'b0, mem_rdata[...]};                        // LHU
    endcase
end
```

> **Important**: `mem_load_data` is **combinational** (not registered) to ensure the correct data is available to WB on the same cycle `mem_ready` goes high.

### WB Stage (Writeback)

The WB stage writes results back to the register file:

```verilog
// Register file write condition
assign write_enable = mem_wb_valid && mem_wb_reg_write && 
                      mem_wb_rd != 5'b0;
assign write_data = mem_wb_result;
assign write_addr = mem_wb_rd;
```

---

## Pipeline Registers

```mermaid
graph TD
    subgraph MEM_WB["MEM/WB Register"]
        D1["result: 32-bit"]
        D2["pc: 32-bit (for debug)"]
        D3["rd: 5-bit"]
        D4["reg_write: 1-bit"]
        D5["valid: 1-bit"]
    end

    subgraph EX_MEM["EX/MEM Register"]
        C1["pc: 32-bit"]
        C2["alu_result: 32-bit"]
        C3["rs2_data: 32-bit (for stores)"]
        C4["rd: 5-bit"]
        C5["funct3: 3-bit"]
        C6["is_load, is_store, is_div, reg_write"]
        C7["valid: 1-bit"]
    end

    subgraph ID_EX["ID/EX Register"]
        B1["pc: 32-bit"]
        B2["rs1_data, rs2_data: 32-bit"]
        B3["imm: 32-bit"]
        B4["rd, rs1_addr, rs2_addr: 5-bit"]
        B5["alu_op: 5-bit"]
        B6["funct3: 3-bit"]
        B7["is_load, is_store, is_branch, is_jal, is_jalr"]
        B8["is_lui, is_auipc, is_r_type, is_i_alu, is_div"]
        B9["reg_write: 1-bit"]
        B10["valid: 1-bit"]
    end

    subgraph IF_ID["IF/ID Register"]
        A1["pc: 32-bit"]
        A2["ir: 32-bit instruction"]
        A3["valid: 1-bit"]
    end
```

---

## Hazard Handling

### Data Forwarding

The pipeline implements full forwarding from EX/MEM and MEM/WB stages:

```mermaid
graph LR
    subgraph "EX Stage"
        EX_RS1[rs1 needed]
        EX_RS2[rs2 needed]
    end
    
    subgraph "Forward Sources"
        EX_MEM[EX/MEM result]
        MEM_WB[MEM/WB result]
    end
    
    EX_MEM --> |Priority 1| EX_RS1
    MEM_WB --> |Priority 2| EX_RS1
    EX_MEM --> |Priority 1| EX_RS2
    MEM_WB --> |Priority 2| EX_RS2
```

**Forwarding Logic (EX Stage):**
```verilog
fwd_rs1_data = (ex_mem_valid && ex_mem_reg_write && ex_mem_rd == id_ex_rs1_addr && ex_mem_rd != 0) 
                 ? ex_mem_alu_result :
               (mem_wb_valid && mem_wb_reg_write && mem_wb_rd == id_ex_rs1_addr && mem_wb_rd != 0) 
                 ? mem_wb_result :
               id_ex_rs1_data;
```

> **Critical Fix**: `mem_wb_reg_write` must be explicitly cleared when the pipeline stalls (inserting a bubble). Otherwise, stalled, invalid instructions in the pipeline could be interpreted as valid writes, causing incorrect forwarding of "ghost" data.


### Load-Use Hazard (Stall)

When a load is followed by an instruction that uses the loaded value:

```
LW  x2, 0(x1)     ; Load into x2
ADD x3, x2, x4    ; Uses x2 - STALL required!
```

**Detection:**
```verilog
load_use_hazard = id_ex_valid && id_ex_is_load && if_id_valid &&
    ((id_ex_rd == dec_rs1 && dec_rs1 != 0) ||
     (id_ex_rd == dec_rs2 && dec_rs2 != 0 && (dec_is_r_type || dec_is_store || dec_is_branch)));
```

**Action:** Stall IF, ID for 1 cycle; insert bubble in ID/EX.

### Control Hazards (Flush)

When a branch is taken or jump executes:

```mermaid
sequenceDiagram
    participant IF
    participant ID
    participant EX
    
    Note over EX: Branch evaluated
    EX->>IF: Flush! PC ← target
    EX->>ID: Insert bubble
    Note over IF: Start fetch from target
```

**Flush Actions:**
1. `if_id_valid <= 0` (invalidate delay slot)
2. `if_id_ir <= NOP` (safe instruction)
3. `fetch_buffer_valid <= 0` (clear buffer)
4. `PC <= next_pc` (redirect to target)
5. `fetch_wait <= 0` (cancel in-flight fetch)
6. Insert bubble in ID/EX stage

---

## Memory Interface

### Unified Memory Arbiter

The pipeline uses a single AXI-Lite master for both instruction fetch and data access:

```mermaid
graph TD
    subgraph "Memory Arbiter"
        direction TB
        FETCH[Fetch Request] --> |Priority 2| ARB{Arbiter}
        DATA[Load/Store Request] --> |Priority 1| ARB
    end
    
    ARB --> AXI[AXI-Lite Master]
    AXI --> INTERCONNECT[AXI Interconnect]
    
    INTERCONNECT --> RAM[RAM]
    INTERCONNECT --> UART[UART]
    INTERCONNECT --> GPIO[GPIO]
```

**Arbiter Priority:**
```verilog
always @* begin
    if (mem_op_pending && !mem_ready) begin
        // Data access has priority
        mem_req = 1; mem_addr = ex_mem_alu_result;
    end else if (fetch_wait && !mem_ready) begin
        // Instruction fetch
        mem_req = 1; mem_addr = fetch_pc;
    end else begin
        mem_req = 0;
    end
end
```

### AXI-Lite Master State Machine

```mermaid
stateDiagram-v2
    [*] --> IDLE
    
    IDLE --> READ_ADDR: mem_req && !mem_wen
    IDLE --> WRITE_ADDR: mem_req && mem_wen
    
    READ_ADDR --> READ_DATA: arready
    READ_DATA --> READ_DONE: rvalid
    READ_DONE --> IDLE: (assert mem_ready)
    
    WRITE_ADDR --> WRITE_DATA: awready
    WRITE_DATA --> WRITE_RESP: wready  
    WRITE_RESP --> IDLE: bvalid
```

> **Note**: The `READ_DONE` state ensures `mem_rdata` is stable before `mem_ready` is asserted. This prevents timing issues where the consumer reads stale data.

### Memory Timing

```
Cycle:  1    2    3    4    5    6    7    8    9    10   11   12
        |----AXI Read Transaction (10 cycles)-----|
        IDLE ADDR DATA ........................... DONE IDLE
                                                    ↑
                                                 mem_ready
                                                 mem_rdata stable
```

---

## Pipeline Timing Diagrams

### Normal Instruction Flow (1-cycle CPI fetching from cache)

```
Cycle:    1    2    3    4    5    6    7    ...
I1:       IF   ID   EX   MEM  WB
I2:            IF   ID   EX   MEM  WB
I3:                 IF   ID   EX   MEM  WB
```

### With Multi-Cycle Fetch (11-cycle AXI latency fetching from memory)

```
Cycle:    1----11  12   13   14   15   16----23  24   25   26   27
I1:       IF       ID   EX   MEM  WB
I2:                IF                        ID  EX        MEM  WB
```

---

## Control Signals Reference

### Pipeline Control

| Signal | Description |
|--------|-------------|
| `stall` | Freezes IF, ID stages (load-use hazard or EX stall) |
| `flush` | Invalidates IF/ID, redirects PC (branch taken / jump) |
| `squash_now` | Set for one cycle after JAL/JALR enters ID/EX |
| `mem_stall` | Stalls when load/store in progress |
| `div_stall` | Stalls when division instruction is executing |
| `ex_stall` | Stalls EX when MEM is busy, waiting for AXI, or division in progress |

### Memory Control

| Signal | Description |
|--------|-------------|
| `fetch_wait` | Fetch operation in progress |
| `fetch_pc` | Captured PC for current fetch |
| `mem_op_pending` | Load/Store operation in progress |
| `mem_busy` | AXI master not in IDLE state |
| `mem_ready` | Memory operation complete, data valid |

### Valid Bits

| Signal | Description |
|--------|-------------|
| `*_valid` | Stage contains valid instruction to process |

---

### Performance Characteristics

- **CPI (ideal)**: 1 cycle per instruction (ideally, depends on code locality and memory access patterns)
- **Branch Penalty**: 2-11 cycles (flush + re-fetch from cache or memory)
- **Load Penalty**: 10 cycles for memory access
- **Forwarding**: Zero-cycle penalty for RAW hazards (except load-use)

---

## References

- [RISC-V Specification](https://riscv.org/specifications/)
- Patterson & Hennessy, "Computer Organization and Design: RISC-V Edition"
