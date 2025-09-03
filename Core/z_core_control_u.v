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
localparam JAL_INST = 7'b0111111;
localparam LUI_INST = 7'b0110111;
localparam AUIPC = 7'b0010111;

// **************************************************
//                Memory Addressing
// **************************************************

assign mem_addr = (state == STATE_FETCH) ? PC : alu_out;

assign mem_write_en = (state == STATE_MEM) ? isStore : 0;

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
wire [31:0] PC_plus_Bimm = PC + Bimm;
wire [31:0] PC_plus_Jimm = PC + Jimm;

// Program Counter Mux
wire [31:0] PC_mux = (isIimm & op[3]) ? alu_out :
                          isBimm           ? (alu_branch ? PC_plus_Bimm : PC_plus4) :
                          isJAL            ? PC_plus_Jimm :
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

// **************************************************
//                  Register File
// **************************************************

// Input Register
reg [31:0] rd_in_r;

// Outputs
wire [31:0] rs1_out;
wire [31:0] rs2_out;

z_core_reg_file reg_file (
    .clk(clk)
    ,.rd(rd)
    ,.rd_in(rd_in_r)
    ,.rs1(rs1)
    ,.rs2(rs2)
    ,.reset(reset)
    ,.rs1_out(rs1_out)
    ,.rs2_out(rs2_out)
);

// RD Multiplexer
wire [31:0] rd_in_mux = isLoad   ? mem_data_in :
                   isJAL    ? PC_plus4 :
                   isJALR   ? PC_plus4 :
                   isUimm   ? Uimm :
                   alu_out;


// **************************************************
//                       ALU
// **************************************************

// Input Registers
reg [31:0] alu_in1_r;
reg [31:0] alu_in2_r;
reg [6:0] alu_op_r;
reg [2:0] alu_funct3_r;
reg [6:0] alu_funct7_r;

// Outputs
wire [31:0] alu_out;
wire alu_branch;

z_core_alu alu (
    .clk(clk)
    ,.alu_in1(alu_in1_r)
    ,.alu_in2(alu_in2_r)
    ,.alu_op(alu_op_r)
    ,.alu_funct3(alu_funct3_r)
    ,.alu_funct7(alu_funct7_r)
    ,.alu_out(alu_out)
    ,.alu_branch(alu_branch)
);

// ALU Input 2 Mux
wire [31:0] alu_in2_mux = isIimm ? Iimm :
                          isSimm ? Simm :
                          isBimm ? Bimm :
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
wire isUimm = (op == LUI_INST) || (op == AUIPC);
wire isJAL = (op == JAL_INST);

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
        mem_addr <= PC_INIT;
        PC <= PC_INIT;
        mem_write_en <= 0;
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
            state <= STATE_EXECUTE;
        end
        else if (state[STATE_EXECUTE_b]) begin
            // Update Program Counter
            PC <= PC_mux;
            state <= (isLoad || isStore) ? STATE_MEM : (isWB ? STATE_WRITE : STATE_FETCH);
        end
        else if (state[STATE_MEM_b]) begin
            // Read or Write Memory
            state <= isWB ? STATE_WRITE : STATE_FETCH;
        end
        else if (state[STATE_WRITE_b]) begin
            // Update Register File
            rd_in_r <= rd_in_mux;
            state <= STATE_FETCH;
        end
    end

end

endmodule