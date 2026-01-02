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


module z_core_decoder_tb;

    // Input instruction
    reg [31:0] inst;
    
    initial begin
        
    end

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

    // Instantiate the decoder module
    z_core_decoder dec (
        .inst, // Corrected: Connect testbench signal 'inst' to decoder's 'inst' port
        .op,
        .rs1,
        .rs2,
        .rd,
        .Iimm,
        .Simm,
        .Uimm,
        .Bimm,
        .Jimm,
        .funct3,
        .funct7
    );

    // Monitor the outputs
    initial begin

        $dumpfile("z_core_decoder_tb.vcd");
        $dumpvars(0, z_core_decoder_tb);

        # 0;
        inst = 32'b00000000001000001000100000100011;

        # 10;
        inst = 32'b00000000001100000000000100010011; // ADDI x2, x0, 3

        # 10;

        $display("Test completed");

    end

endmodule


