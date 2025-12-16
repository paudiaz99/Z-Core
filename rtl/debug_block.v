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

// DEBUG LOGGING
always @(posedge clk) begin
    if (rstn) begin
        $display("Time: %0t | PC: %h | Stall: %b | Flush: %b | SquashNow: %b", $time, PC, stall, flush, squash_now);
        $display("  IF/ID : Valid=%b PC=%h IR=%h", if_id_valid, if_id_pc, if_id_ir);
        $display("  ID/EX : Valid=%b PC=%h Rd=%d Imm=%h Branch=%b Jump=%b", id_ex_valid, id_ex_pc, id_ex_rd, id_ex_imm, id_ex_is_branch, (id_ex_is_jal || id_ex_is_jalr));
        $display("  EX/MEM: Valid=%b PC=%h Rd=%d Res=%h", ex_mem_valid, ex_mem_pc, ex_mem_rd, ex_mem_alu_result);
        $display("  MEM/WB: Valid=%b Rd=%d Res=%h", mem_wb_valid, mem_wb_rd, mem_wb_result);
        if (flush) $display("  !!! FLUSH TRAIGGERED !!! Target=%h", next_pc);
    end
end
