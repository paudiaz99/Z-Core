`timescale 1ns / 1ps

// Testbench for the synchronous I-cache.
//
// Cache contract under test:
//   - addr_rd is sampled at posedge clk.
//   - data_out / cache_hit / cache_miss / valid / addr_rd_d are valid
//     on the cycle AFTER the posedge that sampled addr_rd.
//   - Same-cycle write to the index being read is forwarded via an
//     internal RAW bypass register (next-cycle output reflects the new
//     line if the read address aliases to the write address).
//   - Tag mismatch with same index -> miss.
//   - Steady state: a new addr_rd every cycle yields a result every
//     cycle (1-cycle pipeline latency, 1 lookup/cycle throughput).
//
// All checks fire on the cycle the result is observable.

module z_core_instr_cache_tb;

    parameter DATA_WIDTH  = 32;
    parameter ADDR_WIDTH  = 32;
    parameter CACHE_DEPTH = 256;

    reg                    clk;
    reg                    rstn;
    reg                    wen;
    reg  [ADDR_WIDTH-1:0]  addr_rd;
    reg  [ADDR_WIDTH-1:0]  addr_wr;
    reg  [DATA_WIDTH-1:0]  data_in;

    wire [ADDR_WIDTH-1:0]  addr_rd_d;
    wire [DATA_WIDTH-1:0]  data_out;
    wire                   valid;
    wire                   cache_hit;
    wire                   cache_miss;

    int pass_count = 0;
    int fail_count = 0;

    z_core_instr_cache #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .CACHE_DEPTH(CACHE_DEPTH)
    ) uut (
        .clk(clk),
        .rstn(rstn),
        .wen(wen),
        .addr_rd(addr_rd),
        .addr_rd_d(addr_rd_d),
        .addr_wr(addr_wr),
        .data_in(data_in),
        .data_out(data_out),
        .valid(valid),
        .cache_hit(cache_hit),
        .cache_miss(cache_miss)
    );

    // 100 MHz clock
    always #5 clk = ~clk;

    // -----------------------------------------------------------------
    //  Helpers
    // -----------------------------------------------------------------

    // Drive a single read at addr A starting at the next posedge; check the
    // result on the cycle after that posedge.
    task automatic do_read(input [ADDR_WIDTH-1:0] A,
                           input                   exp_hit,
                           input [DATA_WIDTH-1:0]  exp_data,
                           input string            label);
        begin
            @(negedge clk);          // present addr_rd before the next posedge
            addr_rd = A;
            wen     = 1'b0;
            @(posedge clk);          // cache samples here
            #1;                       // small delta so cache outputs settle
            if (cache_hit !== exp_hit) begin
                $display("[FAIL] %s: addr=0x%08h hit=%0d expected=%0d",
                         label, A, cache_hit, exp_hit);
                fail_count++;
            end else if (exp_hit && data_out !== exp_data) begin
                $display("[FAIL] %s: addr=0x%08h data=0x%08h expected=0x%08h",
                         label, A, data_out, exp_data);
                fail_count++;
            end else if (addr_rd_d !== A) begin
                $display("[FAIL] %s: addr_rd_d=0x%08h expected=0x%08h",
                         label, addr_rd_d, A);
                fail_count++;
            end else begin
                $display("[PASS] %s: addr=0x%08h hit=%0d data=0x%08h",
                         label, A, cache_hit, data_out);
                pass_count++;
            end
        end
    endtask

    // Drive a single fill at addr A with data D on the next posedge.
    task automatic do_write(input [ADDR_WIDTH-1:0] A,
                            input [DATA_WIDTH-1:0] D);
        begin
            @(negedge clk);
            addr_wr = A;
            data_in = D;
            wen     = 1'b1;
            @(posedge clk);
            #1;
            wen = 1'b0;
        end
    endtask

    // -----------------------------------------------------------------
    //  Tests
    // -----------------------------------------------------------------
    initial begin
        $display("=================================================");
        $display("  Synchronous I-cache testbench");
        $display("=================================================\n");

        clk     = 0;
        rstn    = 0;
        wen     = 0;
        addr_rd = '0;
        addr_wr = '0;
        data_in = '0;

        // ---- Test 1: reset clears valid bits, every read misses ----
        $display("Test 1: post-reset reads all miss");
        repeat (3) @(posedge clk);
        rstn = 1;
        @(posedge clk);
        do_read(32'h0000_1000, 1'b0, 32'h0, "post-reset read");
        do_read(32'h0000_2000, 1'b0, 32'h0, "post-reset read at different idx");

        // ---- Test 2: write then read with 1-cycle latency ----
        $display("\nTest 2: write then read (1-cycle latency)");
        do_write(32'h0000_1000, 32'hDEAD_BEEF);
        do_read (32'h0000_1000, 1'b1, 32'hDEAD_BEEF, "read after write");

        // ---- Test 3: aliasing (different tag, same index) misses ----
        $display("\nTest 3: alias to same index but different tag misses");
        // For CACHE_DEPTH=256, index = addr[9:2], tag = addr[31:10].
        // 0x1000 and 0x1400 share index 0 but differ in bit 10 (tag).
        do_read(32'h0000_1400, 1'b0, 32'h0, "aliased read same idx");

        // ---- Test 4: replacement -- new tag, new data ----
        $display("\nTest 4: replacement at same index");
        do_write(32'h0000_1400, 32'h1234_5678);
        do_read (32'h0000_1400, 1'b1, 32'h1234_5678, "read after replacement");
        do_read (32'h0000_1000, 1'b0, 32'h0,         "old tag now misses");

        // ---- Test 5: many lines, sequential read-back ----
        $display("\nTest 5: prefill 8 lines, read sequentially");
        for (int i = 0; i < 8; i++)
            do_write(32'h0000_2000 + (i << 2), 32'hA000_0000 + i);
        for (int i = 0; i < 8; i++)
            do_read (32'h0000_2000 + (i << 2),
                     1'b1, 32'hA000_0000 + i,
                     $sformatf("seq read %0d", i));

        // ---- Test 6: sustained 1-per-cycle throughput ----
        // Drive a fresh addr_rd every cycle and observe one valid hit per
        // cycle. With this cache, addr_rd presented just before posedge T
        // produces line_q (= data_out) that reflects cache[addr_rd@T] in
        // the time slot AFTER posedge T. We re-assign addr_rd immediately
        // after each posedge and check the result for THAT posedge before
        // the next one.
        $display("\nTest 6: sustained throughput (1 lookup/cycle)");
        begin : throughput_test
            int T = 16;
            int hits = 0;
            @(negedge clk);  // align so the first iteration's posedge is clean
            for (int i = 0; i < T; i++) begin
                addr_rd = 32'h0000_2000 + ((i % 8) << 2);
                wen     = 1'b0;
                @(posedge clk);   // cache samples addr_rd at this posedge
                #1;                // settle
                if (cache_hit && data_out === (32'hA000_0000 + (i % 8)) &&
                    addr_rd_d === (32'h0000_2000 + ((i % 8) << 2))) begin
                    hits++;
                end else begin
                    $display("[FAIL] throughput cyc=%0d expected hit data=0x%08h got hit=%0d data=0x%08h addr_rd_d=0x%08h",
                             i, 32'hA000_0000 + (i % 8), cache_hit, data_out, addr_rd_d);
                end
            end
            if (hits == T) begin
                $display("[PASS] sustained throughput: %0d/%0d hits in %0d cycles", hits, T, T);
                pass_count++;
            end else begin
                $display("[FAIL] sustained throughput: %0d/%0d hits", hits, T);
                fail_count++;
            end
        end

        // ---- Test 7: same-cycle RAW bypass ----
        // Issue a write to address A on the same posedge a read of address A
        // is sampled. Next cycle data_out must be the just-written value
        // and cache_hit must assert.
        $display("\nTest 7: RAW bypass (write+read same addr same cycle)");
        @(negedge clk);
        // Pick a fresh address that has not been written yet.
        addr_rd = 32'h0000_3008;
        addr_wr = 32'h0000_3008;
        data_in = 32'hCAFE_F00D;
        wen     = 1'b1;
        @(posedge clk);
        #1;
        wen = 1'b0;
        if (cache_hit && data_out === 32'hCAFE_F00D && addr_rd_d === 32'h0000_3008) begin
            $display("[PASS] RAW bypass: data=0x%08h", data_out);
            pass_count++;
        end else begin
            $display("[FAIL] RAW bypass: hit=%0d data=0x%08h addr_rd_d=0x%08h",
                     cache_hit, data_out, addr_rd_d);
            fail_count++;
        end

        // ---- Test 8: same-cycle write to ALIASED index (different tag) ----
        // Read addr A while writing addr A' that aliases to the same index
        // but different tag. The bypass should NOT report a hit (tag mismatch).
        $display("\nTest 8: same-cycle write aliased index, different tag misses");
        // Pre-fill A so it currently hits on its own.
        do_write(32'h0000_3010, 32'h1111_2222);
        // Now read 0x3010 while writing 0x3410 (same idx, different tag).
        @(negedge clk);
        addr_rd = 32'h0000_3010;
        addr_wr = 32'h0000_3410;
        data_in = 32'h3333_4444;
        wen     = 1'b1;
        @(posedge clk);
        #1;
        wen = 1'b0;
        // After this cycle, 0x3010 should be EVICTED from cache (write at
        // same idx replaces the line). The output should report miss.
        if (!cache_hit && addr_rd_d === 32'h0000_3010) begin
            $display("[PASS] aliased same-cycle write evicts old line");
            pass_count++;
        end else begin
            $display("[FAIL] aliased same-cycle write: hit=%0d data=0x%08h addr_rd_d=0x%08h",
                     cache_hit, data_out, addr_rd_d);
            fail_count++;
        end
        // And 0x3410 should now be a hit on its own.
        do_read(32'h0000_3410, 1'b1, 32'h3333_4444, "evicted-by-replacement target");

        // ---- Summary ----
        $display("\n=================================================");
        $display("  PASSED: %0d", pass_count);
        $display("  FAILED: %0d", fail_count);
        $display("=================================================");
        if (fail_count == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** SOME TESTS FAILED ***");

        $finish;
    end

    initial begin
        $dumpfile("z_core_instr_cache_tb.vcd");
        $dumpvars(0, z_core_instr_cache_tb);
    end

    // Watchdog
    initial begin
        #20000;
        $display("[FATAL] watchdog timeout");
        $finish;
    end

endmodule
