// **************************************************
//                   TODO LIST
// 1. Implement ALU Operations
// 2. Implement Branch Logic
// 3. Implement Testbench
// 4. Verify All Instructions using Simulation
//
// **************************************************

module z_core_alu (
    input [31:0] alu_in1,
    input [31:0] alu_in2,
    input [6:0] alu_inst_type,
    input [2:0] alu_funct3,
    input [6:0] alu_funct7,
    output [31:0] alu_out,
    output alu_branch
);


always @(alu_op or alu_in1 or alu_in2) begin
    case (alu_op) 


    endcase
end


endmodule