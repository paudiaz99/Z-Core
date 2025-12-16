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
`include "rtl/z_core_reg_file.v"

module z_core_reg_file_tb;

    // Initialize clk to 0
    reg clk = 0;

    reg write_enable;
    reg [4:0] rd;
    reg [31:0] rd_in;
    reg [4:0] rs1;
    reg [4:0] rs2;
    reg reset;

    initial begin

        $dumpfile("z_core_reg_file_tb.vcd");
        $dumpvars(0, z_core_reg_file_tb);

        reset = 1'b1;
        rd = 5'b0;
        rs1 = 5'b0;
        rs2 = 5'b0;

        # 10;
        reset = 1'b0;
        write_enable = 1'b1;
        rd = 5'd5;
        rd_in = 32'd15;

        // Write in x8
        # 10;
        write_enable = 1'b1;
        rd = 5'd8;
        rd_in = 32'd25;

        // Async Read from x8 and x5
        # 10;
        write_enable = 1'b0;
        rs1 = 5'd5;
        rs2 = 5'd8;

        // Async Read from x8 and x5
        # 10;
        rs1 = 5'd8;
        rs2 = 5'd5;

        // Try to write with write_enable low
        # 10;
        write_enable = 1'b0;
        rd = 5'd10;
        rd_in = 32'd30;

        // Try to write on x0
        # 10;
        write_enable = 1'b1;
        rd = 5'd0;
        rd_in = 32'd40;

        // Read from x0 and x10
        # 10;
        write_enable = 1'b0;
        rs1 = 5'd0;
        rs2 = 5'd10;

        # 10;
    
        $display("Test completed");
        $finish;
    end

    always # 5 begin
        clk = ~clk;
    end

    wire [31:0] rs1_out;
    wire [31:0] rs2_out;

    z_core_reg_file reg_file (
        .clk
        ,.rd
        ,.rd_in
        ,.rs1
        ,.rs2
        ,.write_enable
        ,.reset
        ,.rs1_out
        ,.rs2_out
    );

endmodule