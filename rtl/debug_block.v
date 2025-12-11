
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
