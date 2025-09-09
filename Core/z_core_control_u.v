// **************************************************
//                    TODO LIST
// 1. Instance ALU Control Module and Wire Up
// 2. Implement Testbench (Once All Modules are Done and Tested)
// 3. Verify correctness of the Control Unit using Simulation
//
// **************************************************

module z_core_control_u 
(
    // Inputs
    input clk,
    input reset,
    input [31:0] mem_data_in,

    // Outputs
    output mem_write_en,
    output [31:0] mem_data_out,
    output [31:0] mem_addr
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
//                Memory Addressing
// **************************************************

assign mem_addr = state[STATE_MEM_b] ? ALUOut_r : PC;

assign mem_write_en = state[STATE_MEM_b] ? isStore : 0;

assign mem_data_out = state[STATE_MEM_b] ? mem_data_out_r : 32'h0;

reg [31:0] MDR;
reg [31:0] mem_data_out_r;

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
wire [31:0] PC_plus4     = PC + 4;
wire [31:0] PC_plus_Imm = PC + Imm_r;

// Program Counter Mux
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

// Decoder Combiational Logic

wire [31:0] Imm_mux_out = isIimm ? Iimm :
                          isSimm ? Simm :
                          isBimm ? Bimm :
                          isJAL  ? Jimm :
                          isUimm ? Uimm :
                          32'h0;

// Decode Stage Registers

// ALU Input Registers
reg [31:0] alu_in1_r;
reg [31:0] alu_in2_r;
reg [6:0] alu_op_r;
reg [2:0] alu_funct3_r;
reg [6:0] alu_funct7_r;

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
    ,.reset(reset)
    ,.rs1_out(rs1_out)
    ,.rs2_out(rs2_out)
);


// Write Enable Control
wire write_enable = state[STATE_WRITE_b];

// **************************************************
//                    ALU Control
// **************************************************

// TODO: Instance z_core_alu_ctrl and wire up

// **************************************************
//                       ALU
// **************************************************

// Output Register
reg [31:0] ALUOut_r;

// Outputs
wire [31:0] alu_out;
wire alu_branch;

z_core_alu alu (
    .alu_in1(alu_in1_r)
    ,.alu_in2(alu_in2_r)
    ,.alu_inst_type(alu_op_r)
    ,.alu_funct3(alu_funct3_r)
    ,.alu_funct7(alu_funct7_r)
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

localparam N_STATES = 5;

localparam STATE_FETCH_b   = 0;
localparam STATE_DECODE_b  = 1;
localparam STATE_EXECUTE_b = 2;
localparam STATE_MEM_b     = 3;
localparam STATE_WRITE_b   = 4;

localparam STATE_FETCH =    1 << STATE_FETCH_b;
localparam STATE_DECODE =   1 << STATE_DECODE_b;
localparam STATE_EXECUTE =  1 << STATE_EXECUTE_b;
localparam STATE_MEM =      1 << STATE_MEM_b;
localparam STATE_WRITE =    1 << STATE_WRITE_b;

reg [N_STATES-1:0] state;

always @(posedge clk) begin

    if(reset) begin 
        state <= STATE_FETCH;
        PC <= PC_INIT;
    end
    else begin
        if (state[STATE_FETCH_b]) begin
            // Update Instruction Register
            IR <= mem_data_in;

            state <= STATE_DECODE;
        end
        else if (state[STATE_DECODE_b]) begin
            // Update ALU Registers
            alu_in1_r <= rs1_out;
            alu_in2_r <= alu_in2_mux;
            alu_op_r <= op;
            alu_funct3_r <= funct3;
            alu_funct7_r <= funct7;

            // Store Immediate for later use
            Imm_r <= Imm_mux_out;

            // Store rs2_out for memory store
            mem_data_out_r <= rs2_out;

            state <= STATE_EXECUTE;
        end
        else if (state[STATE_EXECUTE_b]) begin
            // Update Program Counter
            PC <= PC_mux;

            // Store ALU Results
            ALUOut_r <= alu_out;

            state <= (isLoad || isStore) ? STATE_MEM : (isWB ? STATE_WRITE : STATE_FETCH);
        end
        else if (state[STATE_MEM_b]) begin
            // Store Memory Data Register
            if (isLoad) MDR <= mem_data_in;

            state <= isWB ? STATE_WRITE : STATE_FETCH;
        end
        else if (state[STATE_WRITE_b]) begin
            state <= STATE_FETCH;
        end
    end

end

endmodule