`timescale 1ns / 1ps

module z_core_instr_cache_tb;

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;
    parameter CACHE_DEPTH = 256;

    // Inputs
    reg clk;
    reg rstn;
    reg wen;
    reg [ADDR_WIDTH-1:0] address;
    reg [DATA_WIDTH-1:0] data_in;

    // Outputs
    wire [DATA_WIDTH-1:0] data_out;
    wire valid;
    wire cache_hit;
    wire cache_miss;

    // Test counters
    int pass_count = 0;
    int fail_count = 0;

    // Instantiate the Unit Under Test (UUT)
    z_core_instr_cache #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .CACHE_DEPTH(CACHE_DEPTH)
    ) uut (
        .clk(clk),
        .rstn(rstn),
        .wen(wen),
        .address(address),
        .data_in(data_in),
        .data_out(data_out),
        .valid(valid),
        .cache_hit(cache_hit),
        .cache_miss(cache_miss)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Test Procedure
    initial begin
        $display("==============================================");
        $display("  Asynchronous Read Cache Testbench");
        $display("==============================================\n");

        // Initialize Inputs
        clk = 0;
        rstn = 0;
        wen = 0;
        address = 0;
        data_in = 0;

        // =============================================
        // Test 1: Reset Behavior
        // =============================================
        $display("Test 1: Reset Behavior");
        #20;
        rstn = 1;
        #10;
        $display("[INFO] Reset deasserted\n");

        // =============================================
        // Test 2: Async Read Miss on Empty Cache
        // =============================================
        $display("Test 2: Asynchronous Read Miss on Empty Cache");
        address = 32'h0000_1000;
        #1; // Small propagation delay for combinational logic
        
        if (cache_miss && !cache_hit && !valid) begin
            $display("[PASS] Immediate miss detected (no clock edge needed)");
            pass_count++;
        end else begin
            $display("[FAIL] Expected immediate miss, got valid=%b hit=%b miss=%b", valid, cache_hit, cache_miss);
            fail_count++;
        end

        // =============================================
        // Test 3: Write to Cache (still synchronous)
        // =============================================
        $display("\nTest 3: Write Operation (synchronous on posedge clk)");
        address = 32'h0000_1000;
        data_in = 32'hDEAD_BEEF;
        wen = 1;
        @(posedge clk); // Write happens on clock edge
        #1;
        wen = 0;
        $display("[INFO] Write to 0x1000 = 0xDEADBEEF completed");

        // =============================================
        // Test 4: Async Read Hit - Immediate Response
        // =============================================
        $display("\nTest 4: Asynchronous Read Hit - Immediate Response");
        // Address is still 0x1000, data should be available immediately
        #1; // Small delay for combinational propagation
        
        if (valid && cache_hit && !cache_miss && data_out == 32'hDEAD_BEEF) begin
            $display("[PASS] Immediate read hit. Data: 0x%h", data_out);
            pass_count++;
        end else begin
            $display("[FAIL] Read Hit failed. valid=%b hit=%b miss=%b data=0x%h", valid, cache_hit, cache_miss, data_out);
            fail_count++;
        end

        // =============================================
        // Test 5: Async Read - Address Change Propagation
        // =============================================
        $display("\nTest 5: Asynchronous Read - Address Change Propagation");
        // Write a second entry first
        address = 32'h0000_1004;
        data_in = 32'hCAFE_BABE;
        wen = 1;
        @(posedge clk);
        #1;
        wen = 0;
        
        // Now rapidly switch between addresses and check async response
        address = 32'h0000_1000;
        #1; // Combinational delay only
        if (data_out == 32'hDEAD_BEEF && cache_hit) begin
            $display("[PASS] Addr 0x1000: Immediate data=0x%h", data_out);
            pass_count++;
        end else begin
            $display("[FAIL] Addr 0x1000: Expected 0xDEADBEEF, got 0x%h", data_out);
            fail_count++;
        end

        address = 32'h0000_1004;
        #1; // Combinational delay only
        if (data_out == 32'hCAFE_BABE && cache_hit) begin
            $display("[PASS] Addr 0x1004: Immediate data=0x%h", data_out);
            pass_count++;
        end else begin
            $display("[FAIL] Addr 0x1004: Expected 0xCAFEBABE, got 0x%h", data_out);
            fail_count++;
        end

        // =============================================
        // Test 6: Async Tag Mismatch Detection
        // =============================================
        $display("\nTest 6: Asynchronous Tag Mismatch Detection");
        // Address 0x1400 maps to same index as 0x1000 but different tag
        address = 32'h0000_1400;
        #1; // Immediate combinational response
        
        if (!valid && !cache_hit && cache_miss) begin
            $display("[PASS] Immediate miss on tag mismatch (aliased index)");
            pass_count++;
        end else begin
            $display("[FAIL] Aliasing check failed. valid=%b hit=%b miss=%b", valid, cache_hit, cache_miss);
            fail_count++;
        end

        // =============================================
        // Test 7: Cache Line Replacement
        // =============================================
        $display("\nTest 7: Cache Line Replacement");
        address = 32'h0000_1400;
        data_in = 32'h1234_5678;
        wen = 1;
        @(posedge clk);
        #1;
        wen = 0;
        
        // Check new value is immediately readable
        #1;
        if (valid && cache_hit && data_out == 32'h1234_5678) begin
            $display("[PASS] Replacement successful. New Data: 0x%h", data_out);
            pass_count++;
        end else begin
            $display("[FAIL] Replacement failed. Data: 0x%h", data_out);
            fail_count++;
        end

        // Old address (0x1000) should now miss immediately
        address = 32'h0000_1000;
        #1;
        if (!valid && !cache_hit && cache_miss) begin
            $display("[PASS] Old tag correctly invalidated (immediate miss)");
            pass_count++;
        end else begin
            $display("[FAIL] Old data still hitting? valid=%b hit=%b", valid, cache_hit);
            fail_count++;
        end

        // =============================================
        // Test 8: Rapid Address Switching (Stress Test)
        // =============================================
        $display("\nTest 8: Rapid Address Switching (No Clock Edges)");
        // Pre-populate multiple cache lines
        for (int i = 0; i < 8; i++) begin
            address = 32'h0000_2000 + (i << 2);
            data_in = 32'hA000_0000 + i;
            wen = 1;
            @(posedge clk);
            #1;
        end
        wen = 0;

        // Now read them all back rapidly without waiting for clock edges
        for (int i = 0; i < 8; i++) begin
            address = 32'h0000_2000 + (i << 2);
            #1; // Only combinational delay
            if (data_out == (32'hA000_0000 + i) && cache_hit) begin
                $display("[PASS] Rapid read addr[%0d]: 0x%h", i, data_out);
                pass_count++;
            end else begin
                $display("[FAIL] Rapid read addr[%0d]: Expected 0x%h, got 0x%h", i, 32'hA000_0000 + i, data_out);
                fail_count++;
            end
        end

        // =============================================
        // Test 9: Same-Cycle Address and Data Change
        // =============================================
        $display("\nTest 9: Same-Cycle Address and Data Verification");
        // Change address in middle of clock cycle, verify immediate response
        address = 32'h0000_2000;
        #2;
        if (cache_hit && data_out == 32'hA000_0000) begin
            $display("[PASS] Mid-cycle read at 0x2000: 0x%h", data_out);
            pass_count++;
        end else begin
            $display("[FAIL] Mid-cycle read failed");
            fail_count++;
        end
        
        address = 32'h0000_2004;
        #2;
        if (cache_hit && data_out == 32'hA000_0001) begin
            $display("[PASS] Mid-cycle read at 0x2004: 0x%h", data_out);
            pass_count++;
        end else begin
            $display("[FAIL] Mid-cycle read failed");
            fail_count++;
        end

        // =============================================
        // Test Summary
        // =============================================
        $display("\n==============================================");
        $display("  Test Summary");
        $display("==============================================");
        $display("  PASSED: %0d", pass_count);
        $display("  FAILED: %0d", fail_count);
        $display("==============================================\n");
        
        if (fail_count == 0) begin
            $display("*** ALL TESTS PASSED ***\n");
        end else begin
            $display("*** SOME TESTS FAILED ***\n");
        end

        $finish;
    end
    
    // Create VCD dump
    initial begin
        $dumpfile("z_core_instr_cache_tb.vcd");
        $dumpvars(0, z_core_instr_cache_tb);
    end

endmodule
