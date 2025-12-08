// **************************************************
//                   TODO LIST
// 1. Implement ALU Operations [DONE]
// 2. Implement Branch Logic [DONE]
// 3. Implement Testbench
// 4. Verify All Instructions using Simulation
//
// **************************************************

module z_core_alu (
    input [31:0] alu_in1,
    input [31:0] alu_in2,
    input [3:0] alu_inst_type,
    output reg [31:0] alu_out,
    output reg alu_branch
);


// Instructions
localparam INST_ADD = 5'd0;  // Used For Multiple Instructions
localparam INST_SUB = 5'd1;
localparam INST_SLL = 5'd2;  // Both SLL and SLLI
localparam INST_SLT = 5'd3;  // Both SLT and SLTI
localparam INST_SLTU = 5'd4; // Both SLTU and SLTIU
localparam INST_XOR = 5'd5;  // Both XOR and XORI
localparam INST_SRL = 5'd6;  // Both SRL and SRLI
localparam INST_SRA = 5'd7;  // Both SRA and SRAI
localparam INST_OR = 5'd8;   // Both OR and ORI
localparam INST_AND = 5'd9;  // Both AND and ANDI
localparam INST_BEQ = 5'd10;
localparam INST_BNE = 5'd11;
localparam INST_BLT = 5'd12;
localparam INST_BGE = 5'd13;
localparam INST_BLTU = 5'd14;
localparam INST_BGEU = 5'd15;

always @(alu_inst_type or alu_in1 or alu_in2) begin
    // Initialize outputs to prevent latches
    alu_out = 32'd0;
    alu_branch = 1'b0;
    
    case (alu_inst_type) 
        INST_ADD: alu_out = alu_in1 + alu_in2;
        INST_SUB: alu_out = alu_in1 - alu_in2;
        INST_SLL: alu_out = alu_in1 << alu_in2[4:0];
        INST_SLT: alu_out = ($signed(alu_in1) < $signed(alu_in2)) ? 32'd1 : 32'd0;
        INST_SLTU: alu_out = (alu_in1 < alu_in2) ? 32'd1 : 32'd0;
        INST_XOR: alu_out = alu_in1 ^ alu_in2;
        INST_SRL: alu_out = alu_in1 >> alu_in2[4:0];
        INST_SRA: alu_out = $signed(alu_in1) >>> alu_in2[4:0];
        INST_OR:  alu_out = alu_in1 | alu_in2;
        INST_AND: alu_out = alu_in1 & alu_in2;
        INST_BEQ: alu_branch = (alu_in1 == alu_in2);
        INST_BNE: alu_branch = (alu_in1 != alu_in2);
        INST_BLT: alu_branch = ($signed(alu_in1) < $signed(alu_in2));
        INST_BGE: alu_branch = ($signed(alu_in1) >= $signed(alu_in2));
        INST_BLTU: alu_branch = (alu_in1 < alu_in2);
        INST_BGEU: alu_branch = (alu_in1 >= alu_in2);
        default: begin
            alu_out = 32'd0; // Default case to avoid latches
            alu_branch = 1'b0;
        end
    endcase
end


endmodule