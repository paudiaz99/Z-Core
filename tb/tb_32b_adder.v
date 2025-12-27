`timescale 1ns / 1ps
`include "rtl/adder_32b.v"

module tb_32b_adder;

    // Test inputs
    reg [31:0] op1;
    reg [31:0] op2;
    reg cin;

    // Test outputs
    wire [31:0] result;
    wire cout;

    // Expected values for verification
    reg [32:0] expected;
    integer test_count;
    integer pass_count;

    // Instantiate the Unit Under Test (UUT)
    adder_32b uut (
        .op1(op1),
        .op2(op2),
        .cin(cin),
        .result(result),
        .cout(cout)
    );

    // Task to check result
    task check_result;
        input [31:0] exp_result;
        input exp_cout;
        begin
            test_count = test_count + 1;
            if (result === exp_result && cout === exp_cout) begin
                $display("PASS: op1=%h, op2=%h, cin=%b => result=%h, cout=%b",
                         op1, op2, cin, result, cout);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: op1=%h, op2=%h, cin=%b => result=%h (expected %h), cout=%b (expected %b)",
                         op1, op2, cin, result, exp_result, cout, exp_cout);
            end
        end
    endtask

    initial begin
        // Initialize
        test_count = 0;
        pass_count = 0;
        op1 = 0;
        op2 = 0;
        cin = 0;
        
        $display("========================================");
        $display("  32-bit Adder Testbench");
        $display("========================================");
        
        // Wait for global reset
        #10;

        // Test 1: Simple addition (0 + 0 + 0)
        op1 = 32'h00000000; op2 = 32'h00000000; cin = 0;
        #10;
        expected = op1 + op2 + cin;
        check_result(expected[31:0], expected[32]);

        // Test 2: Simple addition (1 + 1 + 0)
        op1 = 32'h00000001; op2 = 32'h00000001; cin = 0;
        #10;
        expected = op1 + op2 + cin;
        check_result(expected[31:0], expected[32]);

        // Test 3: Addition with carry-in (1 + 1 + 1)
        op1 = 32'h00000001; op2 = 32'h00000001; cin = 1;
        #10;
        expected = op1 + op2 + cin;
        check_result(expected[31:0], expected[32]);

        // Test 4: Max value + 0 (no overflow)
        op1 = 32'hFFFFFFFF; op2 = 32'h00000000; cin = 0;
        #10;
        expected = op1 + op2 + cin;
        check_result(expected[31:0], expected[32]);

        // Test 5: Max value + 1 (overflow, cout = 1)
        op1 = 32'hFFFFFFFF; op2 = 32'h00000001; cin = 0;
        #10;
        expected = op1 + op2 + cin;
        check_result(expected[31:0], expected[32]);

        // Test 6: Max value + 0 + cin (overflow)
        op1 = 32'hFFFFFFFF; op2 = 32'h00000000; cin = 1;
        #10;
        expected = op1 + op2 + cin;
        check_result(expected[31:0], expected[32]);

        // Test 7: Max + Max (double overflow)
        op1 = 32'hFFFFFFFF; op2 = 32'hFFFFFFFF; cin = 0;
        #10;
        expected = op1 + op2 + cin;
        check_result(expected[31:0], expected[32]);

        // Test 8: Max + Max + 1 (double overflow + cin)
        op1 = 32'hFFFFFFFF; op2 = 32'hFFFFFFFF; cin = 1;
        #10;
        expected = op1 + op2 + cin;
        check_result(expected[31:0], expected[32]);

        // Test 9: Alternating bit patterns
        op1 = 32'hAAAAAAAA; op2 = 32'h55555555; cin = 0;
        #10;
        expected = op1 + op2 + cin;
        check_result(expected[31:0], expected[32]);

        // Test 10: Alternating bit patterns with cin
        op1 = 32'hAAAAAAAA; op2 = 32'h55555555; cin = 1;
        #10;
        expected = op1 + op2 + cin;
        check_result(expected[31:0], expected[32]);

        // Test 11: Carry propagation test (0x0000FFFF + 1)
        op1 = 32'h0000FFFF; op2 = 32'h00000001; cin = 0;
        #10;
        expected = op1 + op2 + cin;
        check_result(expected[31:0], expected[32]);

        // Test 12: Long carry chain (0x7FFFFFFF + 1)
        op1 = 32'h7FFFFFFF; op2 = 32'h00000001; cin = 0;
        #10;
        expected = op1 + op2 + cin;
        check_result(expected[31:0], expected[32]);

        // Test 13: Random values
        op1 = 32'h12345678; op2 = 32'h87654321; cin = 0;
        #10;
        expected = op1 + op2 + cin;
        check_result(expected[31:0], expected[32]);

        // Test 14: Random values with cin
        op1 = 32'hDEADBEEF; op2 = 32'hCAFEBABE; cin = 1;
        #10;
        expected = op1 + op2 + cin;
        check_result(expected[31:0], expected[32]);

        // Test 15: Power of 2 additions
        op1 = 32'h80000000; op2 = 32'h80000000; cin = 0;
        #10;
        expected = op1 + op2 + cin;
        check_result(expected[31:0], expected[32]);

        // Test 16: Single bit high
        op1 = 32'h00010000; op2 = 32'h00010000; cin = 0;
        #10;
        expected = op1 + op2 + cin;
        check_result(expected[31:0], expected[32]);

        // Display final results
        #10;
        $display("========================================");
        $display("  Test Results: %0d / %0d passed", pass_count, test_count);
        $display("========================================");
        
        if (pass_count == test_count) begin
            $display("  ALL TESTS PASSED!");
        end else begin
            $display("  SOME TESTS FAILED!");
        end
        
        $display("========================================");
        $finish;
    end

    // Optional: Generate VCD for waveform viewing
    initial begin
        $dumpfile("32b_adder_tb.vcd");
        $dumpvars(0, tb_32b_adder);
    end

endmodule
