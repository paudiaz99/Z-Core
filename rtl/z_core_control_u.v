// **************************************************
//                    TODO LIST
// 1. Implement Multiple Size Load/Store
// 2. Implement AXI4 Interface [DONE]
// 3. Implement Testbench (Once All Modules are Done and Tested)
// 4. Verify correctness of the Control Unit using Simulation
//
// **************************************************

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
    output wire                   m_axil_rready
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
    .mem_wstrb({STRB_WIDTH{1'b1}}),  // Full word write for now
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

// Program Counter Plus 
wire [31:0] PC_plus4    = PC + 4;
wire [31:0] PC_plus_Imm = PC + Imm_r;

// Program Counter Mux
wire [31:0] PC_mux = (isJALR) ? alu_out :
                          isBimm           ? (alu_branch_r ? PC_plus_Imm : PC_plus4) :
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
wire [31:0] rd_in_mux = isLoad   ? MDR :
                        isJAL    ? PC_plus4 :
                        isJALR   ? PC_plus4 :
                        isLUI    ? Imm_r :
                        isAUIPC  ? PC_plus_Imm :
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

// WriteBack Control
wire isWB = ~(isSimm | isBimm);

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
        ALUOut_r <= 32'h0;
        alu_branch_r <= 1'b0;
        alu_in1_r <= 32'h0;
        alu_in2_r <= 32'h0;
        alu_inst_type_r <= 4'h0;
        Imm_r <= 32'h0;
        mem_data_out_r <= 32'h0;
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
                // Update ALU Registers
                alu_in1_r <= rs1_out;
                alu_in2_r <= alu_in2_mux;
                alu_inst_type_r <= alu_inst_type;

                // Store Immediate for later use
                Imm_r <= Imm_mux_out;

                // Store rs2_out for memory store
                mem_data_out_r <= rs2_out;

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
                    state <= STATE_MEM;
                end else if (isStore) begin
                    // Setup for store
                    mem_addr <= alu_out;
                    mem_wen <= 1'b1;  // Write
                    mem_req <= 1'b1;
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
                        MDR <= mem_rdata;
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
