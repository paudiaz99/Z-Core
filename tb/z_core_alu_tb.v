/*

Copyright (c) 2025 Pau Díaz Cuesta

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

`timescale 1ns / 1ns
`include "rtl/z_core_alu.v"

module z_core_alu_tb;

    // Inputs
    reg [31:0] alu_in1;
    reg [31:0] alu_in2;
    reg [3:0] alu_inst_type;

    // Outputs
    wire [31:0] alu_out;
    wire alu_branch;

    // Instantiate the ALU
    z_core_alu uut (
        .alu_in1(alu_in1),
        .alu_in2(alu_in2),
        .alu_inst_type(alu_inst_type),
        .alu_out(alu_out),
        .alu_branch(alu_branch)
    );

    // Test
    initial begin

        $dumpfile("z_core_alu_tb.vcd");
        $dumpvars(0, z_core_alu_tb);

        alu_in1 = 32'd2;
        alu_in2 = 32'd3;
        alu_inst_type = 4'd0; // ADD [2 + 3 = 5]
        
        #10;
        alu_in1 = 32'd5;
        alu_in2 = 32'd3;
        alu_inst_type = 4'd1; // SUB [5 - 3 = 2]

        #10;
        alu_in1 = 32'b00000000000000000000000000000010; // 2
        alu_in2 = 32'b00000000000000000000000000000001; // 1
        alu_inst_type = 4'd2; // SLL [2 << 1 = 4]

        #10;
        alu_in1 = 32'b00000000000000000000000000000010; // 2
        alu_in2 = 32'b00000000000000000000000000001000; // 8
        alu_inst_type = 4'd2; // SLL [2 << 8 = 512]

        #10;
        alu_in1 = 32'd10;
        alu_in2 = 32'd20;
        alu_inst_type = 4'd3; // SLT [10 < 20 = 1]

        #10;
        alu_in1 = 32'd20;
        alu_in2 = 32'd10;
        alu_inst_type = 4'd4; // SLT [20 < 10 = 0]

        #10;
        alu_in1 = 32'b00000000000000000000000000001100; // 12
        alu_in2 = 32'b00000000000000000000000000000101; // 5
        alu_inst_type = 4'd5; // XOR [12 ^ 5 = 9]

        #10;
        alu_in1 = 32'b00000000000000000000000000001100;
        alu_in2 = 32'b00000000000000000000000000000010; // 2
        alu_inst_type = 4'd6; // SRL [12 >> 2 = 3]
    
        #10;

        // TODO Add more tests for remaining instructions

        $display("All tests completed.");
        $finish;

    end


endmodule