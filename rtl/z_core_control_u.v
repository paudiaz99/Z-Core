// **************************************************
//                 Z-Core Control Unit
//
// **************************************************

`timescale 1ns / 1ns

`include "rtl/z_core_decoder.v"
`include "rtl/z_core_reg_file.v"
`include "rtl/z_core_alu_ctrl.v"
`include "rtl/z_core_alu.v"
`include "rtl/axil_master.v"

module z_core_control_u #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter STRB_WIDTH = (DATA_WIDTH/8)
)(
    input  wire                   clk,
    input  wire                   rstn,

    // AXI-Lite Master Interface
    output wire [ADDR_WIDTH-1:0]  m_axil_awaddr,
    output wire [2:0]             m_axil_awprot,
    output wire                   m_axil_awvalid,
    input  wire                   m_axil_awready,
    output wire [DATA_WIDTH-1:0]  m_axil_wdata,
    output wire [STRB_WIDTH-1:0]  m_axil_wstrb,
    output wire                   m_axil_wvalid,
    input  wire                   m_axil_wready,
    input  wire [1:0]             m_axil_bresp,
    input  wire                   m_axil_bvalid,
    output wire                   m_axil_bready,
    output wire [ADDR_WIDTH-1:0]  m_axil_araddr,
    output wire [2:0]             m_axil_arprot,
    output wire                   m_axil_arvalid,
    input  wire                   m_axil_arready,
    input  wire [DATA_WIDTH-1:0]  m_axil_rdata,
    input  wire [1:0]             m_axil_rresp,
    input  wire                   m_axil_rvalid,
    output wire                   m_axil_rready,

    // Halt signal (ECALL/EBREAK detected - for RISCOF signature dump)
    output wire                   halt
);

// **************************************************
//                Instructions OP
// **************************************************

// R-Type Instructions
localparam R_INST = 7'b0110011;

// I-Type Instructions
localparam I_INST = 7'b0010011;
localparam I_LOAD_INST = 7'b0000011;
localparam JALR_INST = 7'b1100111;

// S/B-Type Instructions
localparam S_INST = 7'b0100011;
localparam B_INST = 7'b1100011;

// J/U-Type Instructions
localparam JAL_INST = 7'b1101111;
localparam LUI_INST = 7'b0110111;
localparam AUIPC_INST = 7'b0010111;

// System Instructions
localparam SYSTEM_INST = 7'b1110011;  // ECALL, EBREAK
localparam FENCE_INST  = 7'b0001111;  // FENCE

// **************************************************
//              AXI-Lite Master Interface
// **************************************************

// Internal memory interface signals
reg  [ADDR_WIDTH-1:0] mem_addr;
wire [DATA_WIDTH-1:0] mem_rdata;
wire                  mem_ready;
wire                  mem_busy;
reg                   mem_req;
reg                   mem_wen;

// Memory write data register
reg [31:0] mem_data_out_r;

// Memory write strobe register (for byte/halfword stores)
reg [STRB_WIDTH-1:0] mem_wstrb_r;

// Saved funct3 for load/store operations
reg [2:0] funct3_r;

// AXI-Lite Master Instance
axil_master #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH)
) u_axil_master (
    .clk(clk),
    .rstn(rstn),
    
    // Simple memory interface
    .mem_req(mem_req),
    .mem_wen(mem_wen),
    .mem_addr(mem_addr),
    .mem_wdata(mem_data_out_r),
    .mem_wstrb(mem_wstrb_r),  // Dynamic byte strobe for partial writes
    .mem_rdata(mem_rdata),
    .mem_ready(mem_ready),
    .mem_busy(mem_busy),
    
    // AXI-Lite signals
    .m_axil_awaddr(m_axil_awaddr),
    .m_axil_awprot(m_axil_awprot),
    .m_axil_awvalid(m_axil_awvalid),
    .m_axil_awready(m_axil_awready),
    .m_axil_wdata(m_axil_wdata),
    .m_axil_wstrb(m_axil_wstrb),
    .m_axil_wvalid(m_axil_wvalid),
    .m_axil_wready(m_axil_wready),
    .m_axil_bresp(m_axil_bresp),
    .m_axil_bvalid(m_axil_bvalid),
    .m_axil_bready(m_axil_bready),
    .m_axil_araddr(m_axil_araddr),
    .m_axil_arprot(m_axil_arprot),
    .m_axil_arvalid(m_axil_arvalid),
    .m_axil_arready(m_axil_arready),
    .m_axil_rdata(m_axil_rdata),
    .m_axil_rresp(m_axil_rresp),
    .m_axil_rvalid(m_axil_rvalid),
    .m_axil_rready(m_axil_rready)
);

// **************************************************
//                 Memory Data Registers
// **************************************************

reg [31:0] MDR;

// **************************************************
//              Instruction Register
// **************************************************

reg [31:0] IR;

// **************************************************
//                 Program Counter
// **************************************************

localparam PC_INIT = 32'd0;

// Program Counter Register
reg [31:0] PC;

// Saved PC for AUIPC and return address calculation
reg [31:0] PC_saved;

// Program Counter Plus 
wire [31:0] PC_plus4       = PC + 4;
wire [31:0] PC_plus_Imm    = PC + Imm_r;
wire [31:0] PC_saved_plus4 = PC_saved + 4;
wire [31:0] PC_saved_plus_Imm = PC_saved + Imm_r;

// Program Counter Mux
// Note: Use alu_branch (current output) not alu_branch_r (registered) for branches
wire [31:0] PC_mux = (isJALR) ? alu_out :
                          isBimm           ? (alu_branch ? PC_plus_Imm : PC_plus4) :
                          isJAL            ? PC_plus_Imm :
                          PC_plus4;

// **************************************************
//             Instruction Decoder
// **************************************************

// Outputs
wire [6:0] op;
wire [4:0] rs1;
wire [4:0] rs2;
wire [4:0] rd;
wire [31:0] Iimm;
wire [31:0] Simm;
wire [31:0] Uimm;
wire [31:0] Bimm;
wire [31:0] Jimm;
wire [2:0] funct3;
wire [6:0] funct7;

z_core_decoder decoder (
    .inst(IR)
    ,.op(op)
    ,.rs1(rs1)
    ,.rs2(rs2)
    ,.rd(rd)
    ,.Iimm(Iimm)
    ,.Simm(Simm)
    ,.Uimm(Uimm)
    ,.Bimm(Bimm)
    ,.Jimm(Jimm)
    ,.funct3(funct3)
    ,.funct7(funct7)
);

// Decoder Combinational Logic
wire [31:0] Imm_mux_out = isIimm ? Iimm :
                          isSimm ? Simm :
                          isBimm ? Bimm :
                          isJAL  ? Jimm :
                          isUimm ? Uimm :
                          32'h0;

// Immediate Register
reg [31:0] Imm_r;

// **************************************************
//                  Register File
// **************************************************

// RD_In Multiplexer
// Note: PC_saved is used for JAL/JALR/AUIPC since PC updates in EXECUTE before WRITE
wire [31:0] rd_in_mux = isLoad   ? MDR :
                        isJAL    ? PC_saved_plus4 :
                        isJALR   ? PC_saved_plus4 :
                        isLUI    ? Imm_r :
                        isAUIPC  ? PC_saved_plus_Imm :
                        ALUOut_r;

// Outputs
wire [31:0] rs1_out;
wire [31:0] rs2_out;

z_core_reg_file reg_file (
    .clk(clk)
    ,.rd(rd)
    ,.rd_in(rd_in_mux)
    ,.rs1(rs1)
    ,.rs2(rs2)
    ,.write_enable(write_enable)
    ,.reset(~rstn)
    ,.rs1_out(rs1_out)
    ,.rs2_out(rs2_out)
);

// Write Enable Control
wire write_enable = state[STATE_WRITE_b];

// **************************************************
//                    ALU Control
// **************************************************

wire [3:0] alu_inst_type;

z_core_alu_ctrl alu_ctrl (
    .alu_op(op)
    ,.alu_funct3(funct3)
    ,.alu_funct7(funct7)
    ,.alu_inst_type(alu_inst_type)
);

// **************************************************
//                       ALU
// **************************************************

// Output Register
reg [31:0] ALUOut_r;
reg alu_branch_r;

// Outputs
wire [31:0] alu_out;
wire alu_branch;

z_core_alu alu (
    .alu_in1(alu_in1_r)
    ,.alu_in2(alu_in2_r)
    ,.alu_inst_type(alu_inst_type_r)
    ,.alu_out(alu_out)
    ,.alu_branch(alu_branch)
);

// ALU Input 2 Mux
wire [31:0] alu_in2_mux = isIimm ? Iimm :
                          isSimm ? Simm :
                          isBimm ? rs2_out :
                          isJAL  ? Jimm :
                          isUimm ? Uimm :
                          rs2_out;

// ALU Input Registers
reg [31:0] alu_in1_r;
reg [31:0] alu_in2_r;
reg [3:0] alu_inst_type_r;

// **************************************************
//                 Control Signals
// **************************************************

// Immediate Control
wire isIimm = (op == I_INST) || (op == I_LOAD_INST) || (op == JALR_INST);
wire isSimm = (op == S_INST);
wire isBimm = (op == B_INST);
wire isUimm = (op == LUI_INST) || (op == AUIPC_INST);
wire isLUI = (op == LUI_INST);
wire isAUIPC = (op == AUIPC_INST);
wire isJAL = (op == JAL_INST);
wire isJALR = (op == JALR_INST);

// Memory Control
wire isLoad = (op == I_LOAD_INST);
wire isStore = isSimm;

// System Instruction Control
wire isFENCE  = (op == FENCE_INST);
wire isSYSTEM = (op == SYSTEM_INST);
wire isECALL  = isSYSTEM && (funct3 == 3'b000) && (IR[31:20] == 12'h000);
wire isEBREAK = isSYSTEM && (funct3 == 3'b000) && (IR[31:20] == 12'h001);

// WriteBack Control (no writeback for branches, stores, FENCE, ECALL, EBREAK)
wire isWB = ~(isSimm | isBimm | isFENCE | isECALL | isEBREAK);

// Halt signal for RISCOF compliance testing (ECALL/EBREAK triggers signature dump)
assign halt = (isECALL | isEBREAK) & state[STATE_EXECUTE_b];

// **************************************************
//                   FSM - OneHot
// **************************************************

localparam N_STATES = 6;

localparam STATE_FETCH_b      = 0;
localparam STATE_FETCH_WAIT_b = 1;
localparam STATE_DECODE_b     = 2;
localparam STATE_EXECUTE_b    = 3;
localparam STATE_MEM_b        = 4;
localparam STATE_WRITE_b      = 5;

localparam STATE_FETCH      = 1 << STATE_FETCH_b;
localparam STATE_FETCH_WAIT = 1 << STATE_FETCH_WAIT_b;
localparam STATE_DECODE     = 1 << STATE_DECODE_b;
localparam STATE_EXECUTE    = 1 << STATE_EXECUTE_b;
localparam STATE_MEM        = 1 << STATE_MEM_b;
localparam STATE_WRITE      = 1 << STATE_WRITE_b;

reg [N_STATES-1:0] state;

always @(posedge clk) begin

    if (~rstn) begin 
        state <= STATE_FETCH;
        PC <= PC_INIT;
        mem_req <= 1'b0;
        mem_wen <= 1'b0;
        mem_addr <= {ADDR_WIDTH{1'b0}};
        IR <= 32'h0;
        MDR <= 32'h0;
        PC_saved <= 32'h0;
        ALUOut_r <= 32'h0;
        alu_branch_r <= 1'b0;
        alu_in1_r <= 32'h0;
        alu_in2_r <= 32'h0;
        alu_inst_type_r <= 4'h0;
        Imm_r <= 32'h0;
        mem_data_out_r <= 32'h0;
        mem_wstrb_r <= {STRB_WIDTH{1'b1}};
        funct3_r <= 3'b0;
    end
    else begin
        // Default: clear memory request after one cycle
        mem_req <= 1'b0;
        
        case (1'b1)
            state[STATE_FETCH_b]: begin
                // Set address and initiate instruction fetch
                mem_addr <= PC;
                mem_wen <= 1'b0;  // Read
                mem_req <= 1'b1;
                state <= STATE_FETCH_WAIT;
            end
            
            state[STATE_FETCH_WAIT_b]: begin
                // Wait for memory to respond
                if (mem_ready) begin
                    IR <= mem_rdata;
            state <= STATE_DECODE;
        end
            end
            
            state[STATE_DECODE_b]: begin
                // Save current PC for AUIPC/JAL/JALR (before it gets updated)
                PC_saved <= PC;
                
                // Update ALU Registers
                alu_in1_r <= rs1_out;
                alu_in2_r <= alu_in2_mux;
                alu_inst_type_r <= alu_inst_type;

                // Store Immediate for later use
                Imm_r <= Imm_mux_out;

                // Save funct3 for memory operations (load/store size)
                funct3_r <= funct3;

                // Position store data in correct byte lanes based on funct3
                // Byte: replicate across all lanes
                // Halfword: replicate in both halves
                // Word: pass through
                case (funct3[1:0])
                    2'b00: mem_data_out_r <= {4{rs2_out[7:0]}};   // SB: replicate byte
                    2'b01: mem_data_out_r <= {2{rs2_out[15:0]}};  // SH: replicate halfword
                    default: mem_data_out_r <= rs2_out;            // SW: full word
                endcase

                state <= STATE_EXECUTE;
            end
            
            state[STATE_EXECUTE_b]: begin
                // Update Program Counter
                PC <= PC_mux;

                // Store ALU Results
                ALUOut_r <= alu_out;
                alu_branch_r <= alu_branch;

                if (isLoad) begin
                    // Setup for load
                    mem_addr <= alu_out;
                    mem_wen <= 1'b0;  // Read
                    mem_req <= 1'b1;
                    mem_wstrb_r <= 4'b1111;  // Full word read (strobe doesn't matter for reads)
                    state <= STATE_MEM;
                end else if (isStore) begin
                    // Setup for store with proper byte strobe
                    mem_addr <= alu_out;
                    mem_wen <= 1'b1;  // Write
                    mem_req <= 1'b1;
                    // Generate byte strobe based on funct3 and address bits [1:0]
                    case (funct3_r[1:0])
                        2'b00: mem_wstrb_r <= 4'b0001 << alu_out[1:0];  // SB
                        2'b01: mem_wstrb_r <= 4'b0011 << alu_out[1:0];  // SH
                        default: mem_wstrb_r <= 4'b1111;                 // SW
                    endcase
                    state <= STATE_MEM;
                end else if (isWB) begin
                    state <= STATE_WRITE;
                end else begin
                    state <= STATE_FETCH;
                end
            end
            
            state[STATE_MEM_b]: begin
                // Wait for memory operation to complete
                if (mem_ready) begin
                    if (isLoad) begin
                        // Sign/zero extend loaded data based on funct3 and address
                        case (funct3_r)
                            3'b000: begin // LB (sign-extend byte)
                                case (ALUOut_r[1:0])
                                    2'b00: MDR <= {{24{mem_rdata[7]}}, mem_rdata[7:0]};
                                    2'b01: MDR <= {{24{mem_rdata[15]}}, mem_rdata[15:8]};
                                    2'b10: MDR <= {{24{mem_rdata[23]}}, mem_rdata[23:16]};
                                    2'b11: MDR <= {{24{mem_rdata[31]}}, mem_rdata[31:24]};
                                endcase
                            end
                            3'b001: begin // LH (sign-extend halfword)
                                case (ALUOut_r[1])
                                    1'b0: MDR <= {{16{mem_rdata[15]}}, mem_rdata[15:0]};
                                    1'b1: MDR <= {{16{mem_rdata[31]}}, mem_rdata[31:16]};
                                endcase
                            end
                            3'b010: MDR <= mem_rdata; // LW
                            3'b100: begin // LBU (zero-extend byte)
                                case (ALUOut_r[1:0])
                                    2'b00: MDR <= {24'b0, mem_rdata[7:0]};
                                    2'b01: MDR <= {24'b0, mem_rdata[15:8]};
                                    2'b10: MDR <= {24'b0, mem_rdata[23:16]};
                                    2'b11: MDR <= {24'b0, mem_rdata[31:24]};
                                endcase
                            end
                            3'b101: begin // LHU (zero-extend halfword)
                                case (ALUOut_r[1])
                                    1'b0: MDR <= {16'b0, mem_rdata[15:0]};
                                    1'b1: MDR <= {16'b0, mem_rdata[31:16]};
                                endcase
                            end
                            default: MDR <= mem_rdata;
                        endcase
                    end
                    state <= isWB ? STATE_WRITE : STATE_FETCH;
                end
            end
            
            state[STATE_WRITE_b]: begin
                state <= STATE_FETCH;
            end
            
            default: begin
            state <= STATE_FETCH;
        end
        endcase
    end

end

endmodule
