// **************************************************
//                    TODO LIST
// 1. Add more test cases
//
// **************************************************

`timescale 1ns / 1ps
`include "rtl/z_core_alu_ctrl.v"

module z_core_alu_ctrl_tb;

    // Inputs
    reg [6:0] alu_op;
    reg [2:0] alu_funct3;
    reg [6:0] alu_funct7;

    // Output
    wire [3:0] alu_inst_type;

    // Instantiate the ALU Control module
    z_core_alu_ctrl alu_ctrl (
        .alu_op(alu_op),
        .alu_funct3(alu_funct3),
        .alu_funct7(alu_funct7),
        .alu_inst_type(alu_inst_type)
    );

    initial begin
        $dumpfile("z_core_alu_ctrl_tb.vcd");
        $dumpvars(0, z_core_alu_ctrl_tb);

        // Test R-Type ADD
        alu_op = 7'b0110011; // R-Type
        alu_funct3 = 3'b000; // ADD/SUB
        alu_funct7 = 7'b0000000; // ADD
        #10;
        $display("R-Type ADD: alu_inst_type = %d (Expected: 0)", alu_inst_type);

        // Test R-Type SUB
        alu_funct7 = 7'b0100000; // SUB
        #10;
        $display("R-Type SUB: alu_inst_type = %d (Expected: 1)", alu_inst_type);

        // Test I-Type ADDI
        alu_op = 7'b0010011; // I-Type
        alu_funct3 = 3'b000; // ADDI
        alu_funct7 = 7'bxxxxxxx; // Don't care for I-Type
        #10;
        $display("I-Type ADDI: alu_inst_type = %d (Expected: 0)", alu_inst_type);

        // Test I-Type SLLI
        alu_funct3 = 3'b001; // SLLI
        #10;
        $display("I-Type SLLI: alu_inst_type = %d (Expected: 2)", alu_inst_type);

        // Test Invalid Instruction
        alu_op = 7'b1111111; // Invalid opcode
        alu_funct3 = 3'b111; 
        alu_funct7 = 7'b1111111; 
        #10;
        $display("Invalid Instruction: alu_inst_type = %b (Expected: xxxx)", alu_inst_type);

        $display("ALU Control Test Completed");
    end
endmodule
