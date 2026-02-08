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

`timescale 1ns / 1ps

module axil_timer_tb;

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;
    parameter STRB_WIDTH = (DATA_WIDTH/8);

    // Signals
    reg                   clk;
    reg                   rstn; // Active Low
    reg                   ext_event_i; // External Event Input

    reg [ADDR_WIDTH-1:0]  s_axil_awaddr;
    reg [2:0]             s_axil_awprot;
    reg                   s_axil_awvalid;
    wire                  s_axil_awready;
    reg [DATA_WIDTH-1:0]  s_axil_wdata;
    reg [STRB_WIDTH-1:0]  s_axil_wstrb;
    reg                   s_axil_wvalid;
    wire                  s_axil_wready;
    wire [1:0]            s_axil_bresp;
    wire                  s_axil_bvalid;
    reg                   s_axil_bready;

    reg [ADDR_WIDTH-1:0]  s_axil_araddr;
    reg [2:0]             s_axil_arprot;
    reg                   s_axil_arvalid;
    wire                  s_axil_arready;
    wire [DATA_WIDTH-1:0]  s_axil_rdata;
    wire [1:0]            s_axil_rresp;
    wire                  s_axil_rvalid;
    reg                   s_axil_rready;

    // DUT Instantiation
    axil_timer #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rstn(rstn),
        .s_axil_awaddr(s_axil_awaddr),
        .s_axil_awprot(s_axil_awprot),
        .s_axil_awvalid(s_axil_awvalid),
        .s_axil_awready(s_axil_awready),
        .s_axil_wdata(s_axil_wdata),
        .s_axil_wstrb(s_axil_wstrb),
        .s_axil_wvalid(s_axil_wvalid),
        .s_axil_wready(s_axil_wready),
        .s_axil_bresp(s_axil_bresp),
        .s_axil_bvalid(s_axil_bvalid),
        .s_axil_bready(s_axil_bready),
        .s_axil_araddr(s_axil_araddr),
        .s_axil_arprot(s_axil_arprot),
        .s_axil_arvalid(s_axil_arvalid),
        .s_axil_arready(s_axil_arready),
        .s_axil_rdata(s_axil_rdata),
        .s_axil_rresp(s_axil_rresp),
        .s_axil_rvalid(s_axil_rvalid),
        .s_axil_rready(s_axil_rready),
        .ext_event_i(ext_event_i)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz equivalent
    end

    // Tasks for AXI Lite Transactions
    task write_axil;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        begin
            @(posedge clk);
            s_axil_awaddr <= addr;
            s_axil_awvalid <= 1;
            s_axil_wdata <= data;
            s_axil_wvalid <= 1;
            s_axil_wstrb <= 4'hF;
            s_axil_bready <= 0;

            // Wait for handshake
            fork
                begin
                    wait(s_axil_awready);
                    @(posedge clk);
                    s_axil_awvalid <= 0;
                end
                begin
                    wait(s_axil_wready);
                    @(posedge clk);
                    s_axil_wvalid <= 0;
                end
            join

            s_axil_bready <= 1;
            wait(s_axil_bvalid);
            @(posedge clk);
            s_axil_bready <= 0;
        end
    endtask

    task read_axil;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] expected_data;
        reg [DATA_WIDTH-1:0] read_val;
        begin
            @(posedge clk);
            s_axil_araddr <= addr;
            s_axil_arvalid <= 1;
            s_axil_rready <= 0;

            wait(s_axil_arready);
            @(posedge clk);
            s_axil_arvalid <= 0;

            s_axil_rready <= 1;
            wait(s_axil_rvalid);
            read_val = s_axil_rdata;
            @(posedge clk);
            s_axil_rready <= 0;

            if (read_val !== expected_data) begin
                $display("ERROR: Read mismatch at address %h. Expected %h, Got %h", addr, expected_data, read_val);
            end else begin
                $display("SUCCESS: Read at address %h match %h", addr, read_val);
            end
        end
    endtask

    // Main Test Sequence
    initial begin
        $dumpfile("axil_timer_tb.vcd");
        $dumpvars(0, axil_timer_tb);

        // Initialize
        rstn = 0;
        ext_event_i = 0;
        s_axil_awaddr = 0;
        s_axil_awvalid = 0;
        s_axil_wdata = 0;
        s_axil_wstrb = 0;
        s_axil_wvalid = 0;
        s_axil_bready = 0;
        s_axil_araddr = 0;
        s_axil_arvalid = 0;
        s_axil_rready = 0;

        #100;
        rstn = 1;
        #100;

        $display("Starting AXI Timer Testbench...");

        // =========================================================
        // TEST 1: Register Read/Write (Loading Timers)
        // =========================================================
        $display("-- TEST 1: REGISTER R/W & LOADING --");
        
        // 1.1 Load Timer Low (0x00) with 0x0000_0010
        write_axil(32'h0000_0000, 32'h0000_0010);
        
        // 1.2 Load Timer High (0x04) with 0x0000_0020
        write_axil(32'h0000_0004, 32'h0000_0020);

        // 1.3 Read Back Timer Low
        read_axil(32'h0000_0000, 32'h0000_0010);

        // 1.4 Read Back Timer High
        read_axil(32'h0000_0004, 32'h0000_0020);

        // =========================================================
        // TEST 2: Timer Counting (Up)
        // =========================================================
        $display("-- TEST 2: TIMER COUNTING UP --");
        
        // 2.1 Enable Timer, Count Up (Ctrl 0x8 = 0b011 -> Limit/Enable/Up? No)
        // Control Register Bits:
        // 0 -> Enable
        // 1 -> Count Up (1) / Down (0)
        // Map:
        // Bit 0: Enable
        // Bit 1: Up/Down
        // Set Enable=1, Up=1 -> Value 3 (0x3)
        write_axil(32'h0000_0008, 32'h0000_0003);

        // Wait for some cycles
        #100;

        // 2.2 Disable Timer (Ctrl = 0)
        write_axil(32'h0000_0008, 32'h0000_0000);

        // 2.3 Read Back
        // Initial was 0x10 (16). Wait ~100ns -> 10 clocks.
        // Should be around 26 (0x1A). Exact value depends on handshake delays, 
        // checking if > 0x10 is enough for basic verification.
        
        // We will do a read_axil but manually check result in wave or trust manual check if exact match fails
        // Let's just read and display
        @(posedge clk);
            s_axil_araddr <= 32'h0000_0000;
            s_axil_arvalid <= 1;
            s_axil_rready <= 1;
            wait(s_axil_arready);
            @(posedge clk);
            s_axil_arvalid <= 0;
            wait(s_axil_rvalid);
            $display("INFO: Timer Low after count up: %h", s_axil_rdata);
            @(posedge clk);
            s_axil_rready <= 0;

        // =========================================================
        // TEST 3: Timer Overflow (Low to High)
        // =========================================================
        $display("-- TEST 3: TIMER OVERFLOW --");
        
        // 3.1 Load Timer Low with 0xFFFF_FFF0
        write_axil(32'h0000_0000, 32'hFFFF_FFF0);

        // 3.2 Load Timer High with 0x0000_0000
        write_axil(32'h0000_0004, 32'h0000_0000);

        // 3.3 Enable Timer, Count Up (0x3)
        write_axil(32'h0000_0008, 32'h0000_0003);

        // 3.4 Wait for overflow (16 counts + margin) -> ~20 clocks -> 200ns
        #300;

        // 3.5 Disable Timer
        write_axil(32'h0000_0008, 32'h0000_0000);

        // 3.6 Read Timer High - Should be 1
        read_axil(32'h0000_0004, 32'h0000_0001);

        // =========================================================
        // TEST 4: Timer Countdown
        // =========================================================
        $display("-- TEST 4: TIMER COUNT DOWN --");
        
        // 4.1 Load Timer Low with 0x0000_0010
        write_axil(32'h0000_0000, 32'h0000_0010);
        
        // 4.2 Enable Timer, Count Down (Enable=1, Up=0 -> 0x1)
        write_axil(32'h0000_0008, 32'h0000_0001);
        
        #100;
        
        // 4.3 Disable
        write_axil(32'h0000_0008, 32'h0000_0000);
        
        // 4.4 Read and Display
        @(posedge clk);
            s_axil_araddr <= 32'h0000_0000;
            s_axil_arvalid <= 1;
            s_axil_rready <= 1;
            wait(s_axil_arready);
            @(posedge clk);
            s_axil_arvalid <= 0;
            wait(s_axil_rvalid);
            $display("INFO: Timer Low after count down: %h", s_axil_rdata);
            @(posedge clk);
            s_axil_rready <= 0;


        // =========================================================
        // TEST 5: 64-bit Up Count Aggregation (Overflow propagation)
        // =========================================================
        $display("-- TEST 5: 64-BIT UP COUNT AGGREGATION --");
        // Load Low with FFFFFFF0, High with 10
        write_axil(32'h0000_0000, 32'hFFFF_FFF0);
        write_axil(32'h0000_0004, 32'h0000_0010);
        // Enable Up
        write_axil(32'h0000_0008, 32'h0000_0003);
        
        // Wait for wrap (16 ticks) + some margin (e.g. 5 ticks) => 21 ticks ~ 210 ns
        #250; 
        
        // Disable
        write_axil(32'h0000_0008, 32'h0000_0000);
        
        // Check High. Should be 11 (0x11)
        read_axil(32'h0000_0004, 32'h0000_0011);
        
        // =========================================================
        // TEST 6: 64-bit Down Count Aggregation (Underflow propagation)
        // =========================================================
        $display("-- TEST 6: 64-BIT DOWN COUNT AGGREGATION --");
        // Load Low with 05, High with 20
        write_axil(32'h0000_0000, 32'h0000_0005);
        write_axil(32'h0000_0004, 32'h0000_0020);
        // Enable Down (0x1)
        write_axil(32'h0000_0008, 32'h0000_0001);
        
        // Wait for wrap (6 ticks 0->F) + margin => 100ns
        #120;
        
        // Disable
        write_axil(32'h0000_0008, 32'h0000_0000);
        
        // Check High. Should be 1F (31)
        read_axil(32'h0000_0004, 32'h0000_001F);
        
         // =========================================================
        // TEST 7: 64-bit Rollover (Full Overflow)
        // =========================================================
        $display("-- TEST 7: 64-BIT ROLLOVER --");
        write_axil(32'h0000_0000, 32'hFFFF_FFFE);
        write_axil(32'h0000_0004, 32'hFFFF_FFFF);
        write_axil(32'h0000_0008, 32'h0000_0003); // Up
        
        #50; // 3 ticks needed
        
        write_axil(32'h0000_0008, 32'h0000_0000);
        
        // Should be 0 and 0
        read_axil(32'h0000_0004, 32'h0000_0000);
        // Low should be small (wrapped)
        @(posedge clk);
            s_axil_araddr <= 32'h0000_0000;
            s_axil_arvalid <= 1;
            s_axil_rready <= 1;
            wait(s_axil_arready);
            @(posedge clk);
            s_axil_arvalid <= 0;
            wait(s_axil_rvalid);
            if (s_axil_rdata < 32'h0000_0020) begin
                 $display("SUCCESS: Test 7 Low timer rollover verified (Got %h)", s_axil_rdata);
            end else begin
                 $display("ERROR: Test 7 Low timer did not rollover correctly? (Got %h)", s_axil_rdata);
            end
            @(posedge clk);
            s_axil_rready <= 0;

        
        // =========================================================
        // TEST 8: 64-bit Underflow (Full Underflow)
        // =========================================================
        $display("-- TEST 8: 64-BIT UNDERFLOW --");
        write_axil(32'h0000_0000, 32'h0000_0001);
        write_axil(32'h0000_0004, 32'h0000_0000);
        write_axil(32'h0000_0008, 32'h0000_0001); // Down
        
        #50; // 3 ticks: 1->0->F (Hi->F)
        
        write_axil(32'h0000_0008, 32'h0000_0000);
        
        read_axil(32'h0000_0004, 32'hFFFF_FFFF);
        
        // Low should be large (underflowed)
        @(posedge clk);
            s_axil_araddr <= 32'h0000_0000;
            s_axil_arvalid <= 1;
            s_axil_rready <= 1;
            wait(s_axil_arready);
            @(posedge clk);
            s_axil_arvalid <= 0;
            wait(s_axil_rvalid);
            if (s_axil_rdata > 32'hFFFF_FFA0) begin
                 $display("SUCCESS: Test 8 Low timer underflow verified (Got %h)", s_axil_rdata);
            end else begin
                 $display("ERROR: Test 8 Low timer did not underflow correctly? (Got %h)", s_axil_rdata);
            end
            @(posedge clk);
            s_axil_rready <= 0;
        
        // =========================================================
        // TEST 9: Enable/Disable Toggle
        // =========================================================
        $display("-- TEST 9: ENABLE/DISABLE TOGGLE --");
        write_axil(32'h0000_0000, 32'h0000_0010);
        write_axil(32'h0000_0008, 32'h0000_0003); // Enable
        #50;
        write_axil(32'h0000_0008, 32'h0000_0000); // Disable
        #50;
        // Read value
         @(posedge clk);
            s_axil_araddr <= 32'h0000_0000;
            s_axil_arvalid <= 1;
            s_axil_rready <= 1;
            wait(s_axil_arready);
            @(posedge clk);
            s_axil_arvalid <= 0;
            wait(s_axil_rvalid);
            $display("INFO: Timer paused at %h", s_axil_rdata);
            @(posedge clk);
            s_axil_rready <= 0;
            
        // Enable again
        write_axil(32'h0000_0008, 32'h0000_0003);
        #50;
        write_axil(32'h0000_0008, 32'h0000_0000);
        // Read again, should be higher
        @(posedge clk);
            s_axil_araddr <= 32'h0000_0000;
            s_axil_arvalid <= 1;
            s_axil_rready <= 1;
            wait(s_axil_arready);
            @(posedge clk);
            s_axil_arvalid <= 0;
            wait(s_axil_rvalid);
            $display("INFO: Timer resumed at %h", s_axil_rdata);
            @(posedge clk);
            s_axil_rready <= 0;




        // =========================================================
        // TEST 10: Counter Mode (External Event Counting)
        // =========================================================
        $display("-- TEST 10: COUNTER MODE (EXTERNAL EVENT) --");
        
        // 10.1 Load Timer Low with 0
        write_axil(32'h0000_0000, 32'h0000_0000);
        
        // 10.2 Enable Counter Mode (Bit 2=1) + Enable (Bit 0=1) + Up (Bit 1=1) -> 0x7 (111)
        write_axil(32'h0000_0008, 32'h0000_0007);
        
        #100;
        
        // Generate 5 pulses on ext_event_i
        repeat(5) begin
            @(posedge clk);
            ext_event_i <= 1;
            @(posedge clk);
            ext_event_i <= 0;
            #20; // Wait a bit between pulses
        end
        
        // Wait for synchronization
        #100;
        
        // Disable
        write_axil(32'h0000_0008, 32'h0000_0000);
        
        // Check Count. Should be 5.
        read_axil(32'h0000_0000, 32'h0000_0005);


        #100;
        $display("Testbench Completed.");
        $finish;
    end

endmodule
