`timescale 1ns / 1ps
`include "Core/z_core_control_u.v"

module z_core_control_u_tb;

    // Inputs
    reg clk = 0; // Initialize Clk to 0
    reg reset;
    reg [31:0] mem_data_in;

    // Outputs
    wire mem_write_en;
    wire [31:0] mem_data_out;
    wire [31:0] mem_addr;

    z_core_control_u uut(
        .clk
        ,.reset
        ,.mem_data_in
        ,.mem_write_en
        ,.mem_data_out
        ,.mem_addr
    );

    initial begin

        $dumpfile("z_core_control_u_tb.vcd");
        $dumpvars(0, z_core_control_u_tb);

        reset = 1;

        # 10;
        reset = 0;
        mem_data_in = 32'b00000000001100000000000100010011; // ADDI x2, x0, 3

        # 10; // Fetch -> Decode

        # 10; // Decode -> Execute

        # 10; // Execute -> Writeback

        # 10; // Writeback -> Fetch
        mem_data_in = 32'b00100000001000100000000000100011; // SB x2, 512(x4)

        # 10; // Fetch -> Decode

        # 10; // Decode -> Execute

        # 10; // Execute -> Memory

        # 10; // Memory -> Fetch
        $display("Test Finished");
        $finish;

    end


    always #5 begin
        clk = ~clk;
    end
endmodule