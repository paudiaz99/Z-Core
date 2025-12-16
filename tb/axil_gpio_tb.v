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

module axil_gpio_tb;

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;
    parameter N_GPIO     = 64;
    parameter STRB_WIDTH = (DATA_WIDTH/8);

    // Signals
    reg                   clk;
    reg                   rst;

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
    wire [DATA_WIDTH-1:0] s_axil_rdata;
    wire [1:0]            s_axil_rresp;
    wire                  s_axil_rvalid;
    reg                   s_axil_rready;

    // Bidirectional GPIO Signal
    wire [N_GPIO-1:0]     gpio;
    reg  [N_GPIO-1:0]     gpio_drive_val; // Value to drive from external testbench
    reg  [N_GPIO-1:0]     gpio_drive_en;  // Enable driving from external testbench

    // Tri-state Driver for Testbench
    // If gpio_drive_en[i] is 1, testbench drives gpio[i]
    // Else, testbench floats gpio[i] (allowing DUT to drive or Z)
    genvar i;
    generate
        for (i = 0; i < N_GPIO; i = i + 1) begin
            assign gpio[i] = gpio_drive_en[i] ? gpio_drive_val[i] : 1'bz;
        end
    endgenerate

    // DUT Instantiation
    axil_gpio #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .N_GPIO(N_GPIO)
    ) dut (
        .clk(clk),
        .rst(rst),
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
        .gpio(gpio)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
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

            // Wait for handshake (Simplified sequential for simulation)
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
        // Initialize
        rst = 1;
        s_axil_awaddr = 0;
        s_axil_awvalid = 0;
        s_axil_wdata = 0;
        s_axil_wstrb = 0;
        s_axil_wvalid = 0;
        s_axil_bready = 0;
        s_axil_araddr = 0;
        s_axil_arvalid = 0;
        s_axil_rready = 0;
        
        gpio_drive_val = 0;
        gpio_drive_en = 0; // Default floating (High-Z)

        #100;
        rst = 0;
        #100;

        $display("Starting AXI GPIO Bidirectional Testbench...");

        // =========================================================
        // TEST 1: Output Mode
        // =========================================================
        $display("-- TEST 1: OUTPUT MODE --");
        
        // 1.1 Set Direction to Output for lower 32 bits (Write 1s to 0x08)
        write_axil(32'h0000_0008, 32'hFFFF_FFFF);
        
        // 1.2 Write Pattern A to Output Register (0x00)
        write_axil(32'h0000_0000, 32'hAAAA_5555);
        #10;
        if (gpio[31:0] !== 32'hAAAA_5555) $display("ERROR: GPIO[31:0] Output mismatch! Got %h", gpio[31:0]);
        else $display("SUCCESS: GPIO[31:0] driving %h", gpio[31:0]);

        // 1.3 Write Pattern B to Output Register (0x00)
        write_axil(32'h0000_0000, 32'h5555_AAAA);
        #10;
        if (gpio[31:0] !== 32'h5555_AAAA) $display("ERROR: GPIO[31:0] Output mismatch! Got %h", gpio[31:0]);
        else $display("SUCCESS: GPIO[31:0] driving %h", gpio[31:0]);

        // =========================================================
        // TEST 2: Input Mode
        // =========================================================
        $display("-- TEST 2: INPUT MODE --");

        // 2.1 Set Direction to Input for lower 32 bits (Write 0s to 0x08)
        write_axil(32'h0000_0008, 32'h0000_0000);
        
        // 2.2 Drive signals externally from Testbench
        gpio_drive_en[31:0] = 32'hFFFF_FFFF;
        gpio_drive_val[31:0] = 32'h1234_5678;
        #20; // Allow signal to propagate

        // 2.3 Read from Input Register (0x00)
        read_axil(32'h0000_0000, 32'h1234_5678);

        // 2.4 Change External Drive
        gpio_drive_val[31:0] = 32'h8765_4321;
        #20;
        read_axil(32'h0000_0000, 32'h8765_4321);

        // =========================================================
        // TEST 3: Mixed Mode (High Bits)
        // =========================================================
        $display("-- TEST 3: MIXED MODE (Upper 32 bits) --");
        // N_GPIO is 64. Let's set GPIO[63:32] (Address map: Data 0x04, Dir 0x0C)
        // We will make 32-47 Output, 48-63 Input.
        
        // Dir High Word (0x0C): 0x0000_FFFF (Lower half output, upper half input)
        // This maps to GPIO[47:32] = Output, GPIO[63:48] = Input.
        write_axil(32'h0000_000C, 32'h0000_FFFF);

        // Write Data to Upper Word (0x04): 0xDEAD_CAFE
        write_axil(32'h0000_0004, 32'hDEAD_CAFE);
        #10;

        // Check Outputs (GPIO[47:32]) -> Should match CAFE
        if (gpio[47:32] !== 16'hCAFE) $display("ERROR: GPIO[47:32] should be driving CAFE, got %h", gpio[47:32]);
        else $display("SUCCESS: GPIO[47:32] driving CAFE");

        // Check Inputs (GPIO[63:48]) -> Should be Z (floating) from DUT perspective
        // Testbench is not driving them yet, so they should be Z?
        // Wait, 'gpio' wire is driven by 'gpio_drive_val' (which is 0 for these bits) IF enabled.
        // gpio_drive_en was set to FFFFFFFF for [31:0], but 0 for upper bits.
        // So bits [63:32] are high-Z from TB side.
        // DUT side: [47:32] is driving. [63:48] is input (Z).
        // Theoretical check:
        if (gpio[63:48] !== 16'bz) $display("NOTE: GPIO[63:48] is not Z. It might be OK if pullups or previous state.");
        
        // Drive Inputs from TB (GPIO[63:48])
        gpio_drive_en[63:48] = 16'hFFFF;
        gpio_drive_val[63:48] = 16'hBEEF;
        #10;
        
        // Read Upper Word (0x04)
        // Expected: Upper half BEEF (from input), Lower half CAFE (loopback or just what we drove? 
        // NOTE: In standard GPIO, reading the PIN register usually returns the Pin state.
        // If Pin is Output, it reads what is being driven (CAFE).
        // If Pin is Input, it reads external drive (BEEF).
        // So we expect 0xBEEF_CAFE.
        read_axil(32'h0000_0004, 32'hBEEF_CAFE);


        #100;
        $display("Testbench Completed.");
        $finish;
    end

endmodule
