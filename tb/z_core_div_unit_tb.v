`timescale 1ns / 1ns
`include "rtl/z_core_div_unit.v"

module z_core_div_unit_tb;

    //==========================================================================
    // Testbench Parameters
    //==========================================================================
    parameter CLK_PERIOD = 10; // 100 MHz clock
    parameter MAX_CYCLES = 100; // Maximum cycles to wait for division to complete

    //==========================================================================
    // Signals
    //==========================================================================
    // Inputs
    reg clk;
    reg rstn;
    reg [31:0] dividend;
    reg [31:0] divisor;
    reg div_start;
    reg is_signed;
    reg quotient_or_rem;

    // Outputs
    wire div_done;
    wire div_running;
    wire [31:0] div_result;

    //==========================================================================
    // DUT Instantiation
    //==========================================================================
    z_core_div_unit uut (
        .clk(clk),
        .rstn(rstn),
        .dividend(dividend),
        .divisor(divisor),
        .div_start(div_start),
        .is_signed(is_signed),
        .quotient_or_rem(quotient_or_rem),
        .div_done(div_done),
        .div_running(div_running),
        .div_result(div_result)
    );

    //==========================================================================
    // Test Tracking
    //==========================================================================
    integer test_count;
    integer pass_count;
    integer fail_count;
    integer cycle_count;

    //==========================================================================
    // Clock Generation
    //==========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //==========================================================================
    // Tasks for Testing
    //==========================================================================
    
    // Task to reset the DUT
    task reset_dut;
        begin
            rstn = 0;
            div_start = 0;
            dividend = 0;
            divisor = 0;
            is_signed = 0;
            quotient_or_rem = 0;
            repeat(5) @(posedge clk);
            rstn = 1;
            @(posedge clk);
        end
    endtask

    // Task to perform division and wait for result
    task perform_division;
        input [31:0] a;      // dividend
        input [31:0] b;      // divisor
        input signed_op;     // 1 = signed (DIV/REM), 0 = unsigned (DIVU/REMU)
        input get_quotient;  // 1 = quotient, 0 = remainder
        begin
            dividend = a;
            divisor = b;
            is_signed = signed_op;
            quotient_or_rem = get_quotient;
            @(posedge clk);
            div_start = 1;
            
            // Wait for division to complete or timeout
            cycle_count = 0;
            while (!div_done && cycle_count < MAX_CYCLES) begin
                @(posedge clk);
                cycle_count = cycle_count + 1;
            end
            
            div_start = 0;
            @(posedge clk);
        end
    endtask

    // Task to check unsigned division (DIV)
    task test_unsigned_div;
        input [31:0] a;
        input [31:0] b;
        input [31:0] expected_quotient;
        input [31:0] expected_remainder;
        begin
            test_count = test_count + 1;
            
            // Test quotient (unsigned: is_signed = 0)
            perform_division(a, b, 0, 1);
            if (div_result == expected_quotient) begin
                pass_count = pass_count + 1;
                $display("[PASS] Test %0d: DIVU %0d / %0d = %0d (expected %0d)", 
                         test_count, a, b, div_result, expected_quotient);
            end else begin
                fail_count = fail_count + 1;
                $display("[FAIL] Test %0d: DIVU %0d / %0d = %0d (expected %0d)", 
                         test_count, a, b, div_result, expected_quotient);
            end
            
            reset_dut();
            test_count = test_count + 1;
            
            // Test remainder (unsigned: is_signed = 0)
            perform_division(a, b, 0, 0);
            if (div_result == expected_remainder) begin
                pass_count = pass_count + 1;
                $display("[PASS] Test %0d: REMU %0d %% %0d = %0d (expected %0d)", 
                         test_count, a, b, div_result, expected_remainder);
            end else begin
                fail_count = fail_count + 1;
                $display("[FAIL] Test %0d: REMU %0d %% %0d = %0d (expected %0d)", 
                         test_count, a, b, div_result, expected_remainder);
            end
            
            reset_dut();
        end
    endtask

    // Task to check signed division (DIV)
    // Note: For signed division, operands are treated as 2's complement
    task test_signed_div;
        input signed [31:0] a;
        input signed [31:0] b;
        input signed [31:0] expected_quotient;
        input signed [31:0] expected_remainder;
        begin
            test_count = test_count + 1;
            
            // Test quotient (signed: is_signed = 1)
            perform_division(a, b, 1, 1);
            if ($signed(div_result) == expected_quotient) begin
                pass_count = pass_count + 1;
                $display("[PASS] Test %0d: DIV %0d / %0d = %0d (expected %0d)", 
                         test_count, a, b, $signed(div_result), expected_quotient);
            end else begin
                fail_count = fail_count + 1;
                $display("[FAIL] Test %0d: DIV %0d / %0d = %0d (expected %0d)", 
                         test_count, a, b, $signed(div_result), expected_quotient);
            end
            
            reset_dut();
            test_count = test_count + 1;
            
            // Test remainder (signed: is_signed = 1)
            perform_division(a, b, 1, 0);
            if ($signed(div_result) == expected_remainder) begin
                pass_count = pass_count + 1;
                $display("[PASS] Test %0d: REM %0d %% %0d = %0d (expected %0d)", 
                         test_count, a, b, $signed(div_result), expected_remainder);
            end else begin
                fail_count = fail_count + 1;
                $display("[FAIL] Test %0d: REM %0d %% %0d = %0d (expected %0d)", 
                         test_count, a, b, $signed(div_result), expected_remainder);
            end
            
            reset_dut();
        end
    endtask

    //==========================================================================
    // Main Test Sequence
    //==========================================================================
    initial begin
        // Waveform dump
        $dumpfile("z_core_div_unit_tb.vcd");
        $dumpvars(0, z_core_div_unit_tb);

        // Initialize counters
        test_count = 0;
        pass_count = 0;
        fail_count = 0;

        $display("============================================================");
        $display("Z-Core Division Unit Testbench");
        $display("============================================================");
        $display("");

        // Reset DUT
        reset_dut();

        //======================================================================
        // UNSIGNED DIVISION TESTS (DIVU/REMU)
        //======================================================================
        $display("--- Unsigned Division Tests (DIVU/REMU) ---");
        
        // Basic unsigned division
        test_unsigned_div(32'd100, 32'd10, 32'd10, 32'd0);     // 100 / 10 = 10, rem 0
        test_unsigned_div(32'd100, 32'd7, 32'd14, 32'd2);      // 100 / 7 = 14, rem 2
        test_unsigned_div(32'd255, 32'd16, 32'd15, 32'd15);    // 255 / 16 = 15, rem 15
        test_unsigned_div(32'd1, 32'd1, 32'd1, 32'd0);         // 1 / 1 = 1, rem 0
        test_unsigned_div(32'd0, 32'd5, 32'd0, 32'd0);         // 0 / 5 = 0, rem 0
        
        // Large unsigned numbers
        test_unsigned_div(32'hFFFFFFFF, 32'd2, 32'h7FFFFFFF, 32'd1);  // Max uint / 2
        test_unsigned_div(32'h80000000, 32'd2, 32'h40000000, 32'd0);  // 2^31 / 2
        test_unsigned_div(32'd1000000, 32'd1000, 32'd1000, 32'd0);    // 1M / 1K
        
        // Edge cases
        test_unsigned_div(32'd5, 32'd10, 32'd0, 32'd5);        // dividend < divisor
        test_unsigned_div(32'd1, 32'd2, 32'd0, 32'd1);         // 1 / 2 = 0, rem 1
        
        $display("");

        //======================================================================
        // SIGNED DIVISION TESTS (DIV/REM)
        //======================================================================
        $display("--- Signed Division Tests (DIV/REM) ---");
        
        // Positive / Positive
        test_signed_div(32'sd100, 32'sd10, 32'sd10, 32'sd0);   // 100 / 10 = 10, rem 0
        test_signed_div(32'sd100, 32'sd7, 32'sd14, 32'sd2);    // 100 / 7 = 14, rem 2
        
        // Negative / Positive (quotient negative, remainder has sign of dividend)
        test_signed_div(-32'sd100, 32'sd10, -32'sd10, 32'sd0); // -100 / 10 = -10, rem 0
        test_signed_div(-32'sd100, 32'sd7, -32'sd14, -32'sd2); // -100 / 7 = -14, rem -2
        
        // Positive / Negative (quotient negative, remainder has sign of dividend)
        test_signed_div(32'sd100, -32'sd10, -32'sd10, 32'sd0); // 100 / -10 = -10, rem 0
        test_signed_div(32'sd100, -32'sd7, -32'sd14, 32'sd2);  // 100 / -7 = -14, rem 2
        
        // Negative / Negative (quotient positive, remainder has sign of dividend)
        test_signed_div(-32'sd100, -32'sd10, 32'sd10, 32'sd0); // -100 / -10 = 10, rem 0
        test_signed_div(-32'sd100, -32'sd7, 32'sd14, -32'sd2); // -100 / -7 = 14, rem -2
        
        // Edge cases with MIN_INT
        test_signed_div(32'sh80000000, 32'sd2, -32'sd1073741824, 32'sd0); // MIN_INT / 2
        test_signed_div(32'sh80000000, -32'sd1, 32'sh80000000, 32'sd0);   // Overflow case: MIN_INT / -1
        
        $display("");

        //======================================================================
        // DIVISION BY ZERO TESTS
        //======================================================================
        $display("--- Division by Zero Tests ---");
        
        // RISC-V spec: division by zero returns all 1s for quotient, dividend for remainder
        test_count = test_count + 1;
        perform_division(32'd100, 32'd0, 0, 1);
        $display("[INFO] Test %0d: DIVU 100 / 0 = %0d (RISC-V spec: -1 / all 1s)", 
                 test_count, div_result);
        reset_dut();
        
        test_count = test_count + 1;
        perform_division(32'd100, 32'd0, 0, 0);
        $display("[INFO] Test %0d: REMU 100 %% 0 = %0d (RISC-V spec: dividend)", 
                 test_count, div_result);
        reset_dut();
        
        $display("");

        //======================================================================
        // POWER OF TWO TESTS
        //======================================================================
        $display("--- Power of Two Division Tests ---");
        
        test_unsigned_div(32'd256, 32'd2, 32'd128, 32'd0);     // 256 / 2
        test_unsigned_div(32'd256, 32'd4, 32'd64, 32'd0);      // 256 / 4
        test_unsigned_div(32'd256, 32'd8, 32'd32, 32'd0);      // 256 / 8
        test_unsigned_div(32'd256, 32'd256, 32'd1, 32'd0);     // 256 / 256
        test_unsigned_div(32'd1024, 32'd32, 32'd32, 32'd0);    // 1024 / 32
        
        $display("");

        //======================================================================
        // Test Summary
        //======================================================================
        $display("============================================================");
        $display("Test Summary");
        $display("============================================================");
        $display("Total Tests: %0d", test_count);
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", fail_count);
        $display("============================================================");
        
        if (fail_count == 0) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $display("SOME TESTS FAILED!");
        end
        
        $display("");
        $finish;
    end

    //==========================================================================
    // Timeout Watchdog
    //==========================================================================
    initial begin
        #1000000; // 1ms timeout
        $display("[ERROR] Simulation timed out!");
        $finish;
    end

endmodule
