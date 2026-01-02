
module tb_mult_unit;

    // Test inputs
    reg [31:0] op1;
    reg [31:0] op2;
    reg op1_signed;
    reg op2_signed;

    // Test outputs
    wire [63:0] result;

    // Expected values for verification
    reg [63:0] expected;
    integer test_count;
    integer pass_count;

    // Instantiate the Unit Under Test (UUT)
    z_core_mult_unit uut (
        .op1(op1),
        .op2(op2),
        .op1_signed(op1_signed),
        .op2_signed(op2_signed),
        .result(result)
    );

    // Task to check unsigned result
    task check_unsigned;
        input [63:0] exp_result;
        begin
            test_count = test_count + 1;
            if (result === exp_result) begin
                $display("PASS: op1=%h * op2=%h => result=%h",
                         op1, op2, result);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: op1=%h * op2=%h => result=%h (expected %h)",
                         op1, op2, result, exp_result);
            end
        end
    endtask

    // Task to check signed result
    task check_signed;
        input [63:0] exp_result;
        input [127:0] desc;
        begin
            test_count = test_count + 1;
            if (result === exp_result) begin
                $display("PASS: %s => result=%h", desc, result);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: %s => result=%h (expected %h)", desc, result, exp_result);
            end
        end
    endtask

    initial begin
        // Initialize
        test_count = 0;
        pass_count = 0;
        op1 = 0;
        op2 = 0;
        op1_signed = 0;
        op2_signed = 0;
        
        $display("========================================");
        $display("  Tree Multiplier Testbench");
        $display("  (32-bit x 32-bit = 64-bit)");
        $display("  With Signed Support");
        $display("========================================");
        
        // Wait for initial propagation
        #10;

        // ========================================
        // UNSIGNED TESTS (op1_signed=0, op2_signed=0)
        // ========================================
        $display("\n--- UNSIGNED TESTS ---");
        op1_signed = 0; op2_signed = 0;
        
        // Test 1: 0 * 0
        op1 = 32'h00000000; op2 = 32'h00000000;
        #10; expected = op1 * op2; check_unsigned(expected);

        // Test 2: 1 * 1
        op1 = 32'h00000001; op2 = 32'h00000001;
        #10; expected = op1 * op2; check_unsigned(expected);

        // Test 3: 0xFF * 0xFF
        op1 = 32'h000000FF; op2 = 32'h000000FF;
        #10; expected = op1 * op2; check_unsigned(expected);

        // Test 4: Max * Max
        op1 = 32'hFFFFFFFF; op2 = 32'hFFFFFFFF;
        #10; expected = op1 * op2; check_unsigned(expected);

        // Test 5: 2^31 * 2
        op1 = 32'h80000000; op2 = 32'h00000002;
        #10; expected = op1 * op2; check_unsigned(expected);

        // Test 6: 7 * 6
        op1 = 32'd7; op2 = 32'd6;
        #10; expected = 64'd42; check_unsigned(expected);

        // ========================================
        // SIGNED x SIGNED TESTS (op1_signed=1, op2_signed=1)
        // ========================================
        $display("\n--- SIGNED x SIGNED TESTS ---");
        op1_signed = 1; op2_signed = 1;
        
        // Test 7: 7 * 6 = 42 (positive * positive)
        op1 = 32'd7; op2 = 32'd6;
        #10; expected = 64'd42; 
        check_signed(expected, "7 * 6 = 42");

        // Test 8: -1 * 1 = -1
        op1 = 32'hFFFFFFFF; op2 = 32'd1;  // -1 * 1
        #10; expected = 64'hFFFFFFFFFFFFFFFF;  // -1
        check_signed(expected, "-1 * 1 = -1");

        // Test 9: -1 * -1 = 1
        op1 = 32'hFFFFFFFF; op2 = 32'hFFFFFFFF;  // -1 * -1
        #10; expected = 64'd1;
        check_signed(expected, "-1 * -1 = 1");

        // Test 10: -10 * 5 = -50
        op1 = 32'hFFFFFFF6; op2 = 32'd5;  // -10 * 5
        #10; expected = 64'hFFFFFFFFFFFFFFCE;  // -50
        check_signed(expected, "-10 * 5 = -50");

        // Test 11: 10 * -5 = -50
        op1 = 32'd10; op2 = 32'hFFFFFFFB;  // 10 * -5
        #10; expected = 64'hFFFFFFFFFFFFFFCE;  // -50
        check_signed(expected, "10 * -5 = -50");

        // Test 12: -10 * -5 = 50
        op1 = 32'hFFFFFFF6; op2 = 32'hFFFFFFFB;  // -10 * -5
        #10; expected = 64'd50;
        check_signed(expected, "-10 * -5 = 50");

        // Test 13: 0x7FFFFFFF * 2 (max positive * 2)
        op1 = 32'h7FFFFFFF; op2 = 32'd2;
        #10; expected = 64'h00000000FFFFFFFE;
        check_signed(expected, "0x7FFFFFFF * 2");

        // Test 14: 0x80000000 * -1 (most negative * -1) - overflow case
        op1 = 32'h80000000; op2 = 32'hFFFFFFFF;  // -2147483648 * -1
        #10; expected = 64'h0000000080000000;  // result is 2147483648 (positive)
        check_signed(expected, "0x80000000 * -1");

        // ========================================
        // SIGNED x UNSIGNED TESTS (op1_signed=1, op2_signed=0)
        // (This is MULHSU mode)
        // ========================================
        $display("\n--- SIGNED x UNSIGNED TESTS (MULHSU) ---");
        op1_signed = 1; op2_signed = 0;
        
        // Test 15: -10 * 2 (signed * unsigned)
        op1 = 32'hFFFFFFF6; op2 = 32'd2;  // -10 * 2
        #10; expected = 64'hFFFFFFFFFFFFFFEC;  // -20
        check_signed(expected, "-10 * 2 (signed*unsigned)");

        // Test 16: -1 * 0xFFFFFFFF (signed * unsigned max)
        op1 = 32'hFFFFFFFF; op2 = 32'hFFFFFFFF;  // -1 * 4294967295
        #10; expected = 64'hFFFFFFFF00000001;  // -(4294967295) = -4294967295
        check_signed(expected, "-1 * 0xFFFFFFFF (signed*unsigned)");

        // Test 17: 1 * 0xFFFFFFFF (positive * unsigned max)
        op1 = 32'd1; op2 = 32'hFFFFFFFF;
        #10; expected = 64'h00000000FFFFFFFF;
        check_signed(expected, "1 * 0xFFFFFFFF (signed*unsigned)");

        // ========================================
        // UNSIGNED x UNSIGNED again (MULHU mode)
        // ========================================
        $display("\n--- UNSIGNED x UNSIGNED (MULHU mode) ---");
        op1_signed = 0; op2_signed = 0;

        // Test 18: 0xFFFFFFFF * 0xFFFFFFFF unsigned
        op1 = 32'hFFFFFFFF; op2 = 32'hFFFFFFFF;
        #10; expected = 64'hFFFFFFFE00000001;
        check_unsigned(expected);

        // Test 19: 0xFFFFFFFF * 2 unsigned
        op1 = 32'hFFFFFFFF; op2 = 32'd2;
        #10; expected = 64'h00000001FFFFFFFE;
        check_unsigned(expected);

        // Display final results
        #10;
        $display("\n========================================");
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
        $dumpfile("mult_unit_tb.vcd");
        $dumpvars(0, tb_mult_unit);
    end

endmodule
