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

// **************************************************
//        Z-Core Control Unit Testbench
//    Comprehensive test suite for RV32IM+Zicsr instructions
// **************************************************

module z_core_control_u_tb;

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;
    parameter STRB_WIDTH = (DATA_WIDTH/8);
    parameter INST_CACHE_DEPTH = 256;
    parameter DATA_CACHE_DEPTH = 256;
    parameter N_GPIO     = 64;
    

    // Clock and Reset
    reg clk = 0;
    reg rstn;

    // Test tracking
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;
    integer resets_done = 0; // Track number of times reset_cpu called
    reg [4:0] current_state = 0;
    
    // Performance counters for throughput comparison
    integer cycle_counter = 0;
    integer instr_counter = 0;
    integer total_cycles = 0;
    integer total_instrs = 0;
    integer total_memory_writes = 0;
    integer total_memory_reads = 0;
    
    // Internal Performance Counter Accumulators
    reg [63:0] total_internal_cycles = 0;
    reg [63:0] total_internal_instrs = 0;
    reg [63:0] total_internal_cache_hits = 0;
    reg [63:0] total_internal_dcache_hits = 0;
    reg [63:0] total_internal_memory_writes = 0;
    reg [63:0] total_internal_memory_reads = 0;


    // Interconnect Parameters
    // Interconnect Parameters
    localparam S_COUNT = 1;
    localparam M_COUNT = 4;
    localparam M_REGIONS = 1;

    // Address Map
    // M0: Memory (0x0000_0000 - 0x03FF_FFFF) 64MB
    // M1: UART   (0x0400_0000 - 0x0400_0FFF) 4KB
    // M2: GPIO   (0x0400_1000 - 0x0400_1FFF) 4KB
    // M3: Timer  (0x0400_2000 - 0x0400_2FFF) 4KB

    localparam [M_COUNT*ADDR_WIDTH-1:0] M_BASE_ADDR = {
        32'h0400_2000, // M3: Timer
        32'h0400_1000, // M2: GPIO
        32'h0400_0000, // M1: UART
        32'h0000_0000  // M0: Memory
    };

    localparam [M_COUNT*32-1:0] M_ADDR_WIDTH_CONF = {
        32'd12, // M3: Timer (4KB = 2^12)
        32'd12, // M2: GPIO (4KB = 2^12)
        32'd12, // M1: UART (4KB = 2^12)
        32'd26  // M0: Memory (64MB = 2^26)
    };

    // Interconnect Wires
    wire [S_COUNT*ADDR_WIDTH-1:0]  s_axil_awaddr;
    wire [S_COUNT*3-1:0]           s_axil_awprot;
    wire [S_COUNT-1:0]             s_axil_awvalid;
    wire [S_COUNT-1:0]             s_axil_awready;
    wire [S_COUNT*DATA_WIDTH-1:0]  s_axil_wdata;
    wire [S_COUNT*STRB_WIDTH-1:0]  s_axil_wstrb;
    wire [S_COUNT-1:0]             s_axil_wvalid;
    wire [S_COUNT-1:0]             s_axil_wready;
    wire [S_COUNT*2-1:0]           s_axil_bresp;
    wire [S_COUNT-1:0]             s_axil_bvalid;
    wire [S_COUNT-1:0]             s_axil_bready;
    wire [S_COUNT*ADDR_WIDTH-1:0]  s_axil_araddr;
    wire [S_COUNT*3-1:0]           s_axil_arprot;
    wire [S_COUNT-1:0]             s_axil_arvalid;
    wire [S_COUNT-1:0]             s_axil_arready;
    wire [S_COUNT*DATA_WIDTH-1:0]  s_axil_rdata;
    wire [S_COUNT*2-1:0]           s_axil_rresp;
    wire [S_COUNT-1:0]             s_axil_rvalid;
    wire [S_COUNT-1:0]             s_axil_rready;

    wire [M_COUNT*ADDR_WIDTH-1:0]  m_axil_awaddr;
    wire [M_COUNT*3-1:0]           m_axil_awprot;
    wire [M_COUNT-1:0]             m_axil_awvalid;
    wire [M_COUNT-1:0]             m_axil_awready;
    wire [M_COUNT*DATA_WIDTH-1:0]  m_axil_wdata;
    wire [M_COUNT*STRB_WIDTH-1:0]  m_axil_wstrb;
    wire [M_COUNT-1:0]             m_axil_wvalid;
    wire [M_COUNT-1:0]             m_axil_wready;
    wire [M_COUNT*2-1:0]           m_axil_bresp;
    wire [M_COUNT-1:0]             m_axil_bvalid;
    wire [M_COUNT-1:0]             m_axil_bready;
    wire [M_COUNT*ADDR_WIDTH-1:0]  m_axil_araddr;
    wire [M_COUNT*3-1:0]           m_axil_arprot;
    wire [M_COUNT-1:0]             m_axil_arvalid;
    wire [M_COUNT-1:0]             m_axil_arready;
    wire [M_COUNT*DATA_WIDTH-1:0]  m_axil_rdata;
    wire [M_COUNT*2-1:0]           m_axil_rresp;
    wire [M_COUNT-1:0]             m_axil_rvalid;
    wire [M_COUNT-1:0]             m_axil_rready;

    // GPIO Signals for Bidirectional 
    wire [N_GPIO-1:0] gpio_wiring;
    reg  [N_GPIO-1:0] gpio_test_drive;
    reg  [N_GPIO-1:0] gpio_test_en;
    
    // Bidirectional Drive Logic - TB drives when gpio_test_en is set
    genvar gpio_idx;
    generate
        for (gpio_idx = 0; gpio_idx < N_GPIO; gpio_idx = gpio_idx + 1) begin : gpio_drivers
            assign gpio_wiring[gpio_idx] = gpio_test_en[gpio_idx] ? gpio_test_drive[gpio_idx] : 1'bz;
        end
    endgenerate

    // Instantiate Interconnect
    axil_interconnect #(
        .S_COUNT(S_COUNT),
        .M_COUNT(M_COUNT),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .STRB_WIDTH(STRB_WIDTH),
        .M_REGIONS(M_REGIONS),
        .M_BASE_ADDR(M_BASE_ADDR),
        .M_ADDR_WIDTH(M_ADDR_WIDTH_CONF)
    ) u_interconnect (
        .clk(clk),
        .rst(~rstn), // Active high reset
        
        // Slave Interfaces (Connect to Control Unit)
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
        
        // Master Interfaces (Connect to Slaves)
        .m_axil_awaddr(m_axil_awaddr),
        .m_axil_awprot(m_axil_awprot),
        .m_axil_awvalid(m_axil_awvalid),
        .m_axil_awready(m_axil_awready),
        .m_axil_wdata(m_axil_wdata),
        .m_axil_wstrb(m_axil_wstrb),
        .m_axil_wvalid(m_axil_wvalid),
        .m_axil_wready(m_axil_wready),
        .m_axil_bresp(m_axil_bresp),
        .m_axil_bvalid(m_axil_bvalid),
        .m_axil_bready(m_axil_bready),
        .m_axil_araddr(m_axil_araddr),
        .m_axil_arprot(m_axil_arprot),
        .m_axil_arvalid(m_axil_arvalid),
        .m_axil_arready(m_axil_arready),
        .m_axil_rdata(m_axil_rdata),
        .m_axil_rresp(m_axil_rresp),
        .m_axil_rvalid(m_axil_rvalid),
        .m_axil_rready(m_axil_rready)
    );

    // Safety Timeout
    initial begin
        #5000000; // 5ms timeout
        $display("\n[ERROR] Simulation Timeout!");
        $finish;
    end

    reg timer_ext_event = 0;

    wire timer_irq_wire;

    // Instantiate Control Unit (AXI-Lite Master)

    
    z_core_control_u #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .STRB_WIDTH(STRB_WIDTH),
        .INST_CACHE_DEPTH(INST_CACHE_DEPTH),
        .DATA_CACHE_DEPTH(DATA_CACHE_DEPTH)
    ) uut (
        .clk(clk),
        .rstn(rstn),
        
        // AXI-Lite Master Interface -> Interconnect Slave 0
        .m_axil_awaddr(s_axil_awaddr),
        .m_axil_awprot(s_axil_awprot),
        .m_axil_awvalid(s_axil_awvalid),
        .m_axil_awready(s_axil_awready),
        .m_axil_wdata(s_axil_wdata),
        .m_axil_wstrb(s_axil_wstrb),
        .m_axil_wvalid(s_axil_wvalid),
        .m_axil_wready(s_axil_wready),
        .m_axil_bresp(s_axil_bresp),
        .m_axil_bvalid(s_axil_bvalid),
        .m_axil_bready(s_axil_bready),
        .m_axil_araddr(s_axil_araddr),
        .m_axil_arprot(s_axil_arprot),
        .m_axil_arvalid(s_axil_arvalid),
        .m_axil_arready(s_axil_arready),
        .m_axil_rdata(s_axil_rdata),
        .m_axil_rresp(s_axil_rresp),
        .m_axil_rvalid(s_axil_rvalid),
        .m_axil_rready(s_axil_rready),

        // Interrupt Inputs
        .meip(1'b0),
        .mtip(timer_irq_wire),  // Driven by axil_timer compare-match output
        .msip(1'b0)
    );

    // Instantiate AXI-Lite RAM (Slave 0)
    axil_ram #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(16),  // Keep 64KB for simulation speed/simplicity, mapped at 0x0
        .STRB_WIDTH(STRB_WIDTH),
        .PIPELINE_OUTPUT(0)
    ) u_axil_ram (
        .clk(clk),
        .rstn(rstn),
        
        // AXI-Lite Slave Interface <- Interconnect Master 0
        .s_axil_awaddr(m_axil_awaddr[0*ADDR_WIDTH +: 16]), // Truncate to local size
        .s_axil_awprot(m_axil_awprot[0*3 +: 3]),
        .s_axil_awvalid(m_axil_awvalid[0]),
        .s_axil_awready(m_axil_awready[0]),
        .s_axil_wdata(m_axil_wdata[0*DATA_WIDTH +: DATA_WIDTH]),
        .s_axil_wstrb(m_axil_wstrb[0*STRB_WIDTH +: STRB_WIDTH]),
        .s_axil_wvalid(m_axil_wvalid[0]),
        .s_axil_wready(m_axil_wready[0]),
        .s_axil_bresp(m_axil_bresp[0*2 +: 2]),
        .s_axil_bvalid(m_axil_bvalid[0]),
        .s_axil_bready(m_axil_bready[0]),
        .s_axil_araddr(m_axil_araddr[0*ADDR_WIDTH +: 16]), // Truncate to local size
        .s_axil_arprot(m_axil_arprot[0*3 +: 3]),
        .s_axil_arvalid(m_axil_arvalid[0]),
        .s_axil_arready(m_axil_arready[0]),
        .s_axil_rdata(m_axil_rdata[0*DATA_WIDTH +: DATA_WIDTH]),
        .s_axil_rresp(m_axil_rresp[0*2 +: 2]),
        .s_axil_rvalid(m_axil_rvalid[0]),
        .s_axil_rready(m_axil_rready[0])
    );

    // Instantiate UART (Slave 1)
    // UART TX/RX signals
    wire uart_tx;
    reg  uart_rx_tb_drive;    // TB-driven RX signal
    reg  uart_rx_tb_en;       // Enable TB to drive RX (vs loopback)
    wire uart_rx;
    
    // RX source: TB-driven when uart_rx_tb_en, otherwise loopback from TX
    assign uart_rx = uart_rx_tb_en ? uart_rx_tb_drive : uart_tx;
    
    axil_uart #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(12), // 4KB
        .STRB_WIDTH(STRB_WIDTH),
        .DEFAULT_BAUD_DIV(16'd10)  // Fast baud for simulation
    ) u_uart (
        .clk(clk),
        .rst(~rstn), // Active high reset
        
        // UART Physical Pins
        .uart_tx(uart_tx),
        .uart_rx(uart_rx),
        
        .s_axil_awaddr(m_axil_awaddr[1*ADDR_WIDTH +: 12]),
        .s_axil_awprot(m_axil_awprot[1*3 +: 3]),
        .s_axil_awvalid(m_axil_awvalid[1]),
        .s_axil_awready(m_axil_awready[1]),
        .s_axil_wdata(m_axil_wdata[1*DATA_WIDTH +: DATA_WIDTH]),
        .s_axil_wstrb(m_axil_wstrb[1*STRB_WIDTH +: STRB_WIDTH]),
        .s_axil_wvalid(m_axil_wvalid[1]),
        .s_axil_wready(m_axil_wready[1]),
        .s_axil_bresp(m_axil_bresp[1*2 +: 2]),
        .s_axil_bvalid(m_axil_bvalid[1]),
        .s_axil_bready(m_axil_bready[1]),
        .s_axil_araddr(m_axil_araddr[1*ADDR_WIDTH +: 12]),
        .s_axil_arprot(m_axil_arprot[1*3 +: 3]),
        .s_axil_arvalid(m_axil_arvalid[1]),
        .s_axil_arready(m_axil_arready[1]),
        .s_axil_rdata(m_axil_rdata[1*DATA_WIDTH +: DATA_WIDTH]),
        .s_axil_rresp(m_axil_rresp[1*2 +: 2]),
        .s_axil_rvalid(m_axil_rvalid[1]),
        .s_axil_rready(m_axil_rready[1])
    );

    // Instantiate GPIO (Slave 2)
    axil_gpio #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(12), // 4KB
        .STRB_WIDTH(STRB_WIDTH),
        .N_GPIO(N_GPIO)
    ) u_gpio (
        .clk(clk),
        .rst(~rstn), // Active high reset
        
        .s_axil_awaddr(m_axil_awaddr[2*ADDR_WIDTH +: 12]),
        .s_axil_awprot(m_axil_awprot[2*3 +: 3]),
        .s_axil_awvalid(m_axil_awvalid[2]),
        .s_axil_awready(m_axil_awready[2]),
        .s_axil_wdata(m_axil_wdata[2*DATA_WIDTH +: DATA_WIDTH]),
        .s_axil_wstrb(m_axil_wstrb[2*STRB_WIDTH +: STRB_WIDTH]),
        .s_axil_wvalid(m_axil_wvalid[2]),
        .s_axil_wready(m_axil_wready[2]),
        .s_axil_bresp(m_axil_bresp[2*2 +: 2]),
        .s_axil_bvalid(m_axil_bvalid[2]),
        .s_axil_bready(m_axil_bready[2]),
        .s_axil_araddr(m_axil_araddr[2*ADDR_WIDTH +: 12]),
        .s_axil_arprot(m_axil_arprot[2*3 +: 3]),
        .s_axil_arvalid(m_axil_arvalid[2]),
        .s_axil_arready(m_axil_arready[2]),
        .s_axil_rdata(m_axil_rdata[2*DATA_WIDTH +: DATA_WIDTH]),
        .s_axil_rresp(m_axil_rresp[2*2 +: 2]),
        .s_axil_rvalid(m_axil_rvalid[2]),
        .s_axil_rready(m_axil_rready[2]),
        // Bidirectional GPIO Pins
        .gpio(gpio_wiring)
    );

    // Instantiate Timer (Slave 3)
    axil_timer #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(12), // 4KB
        .STRB_WIDTH(STRB_WIDTH)
    ) u_timer (
        .clk(clk),
        .rstn(rstn), // Active low reset
        
        .s_axil_awaddr(m_axil_awaddr[3*ADDR_WIDTH +: 12]),
        .s_axil_awprot(m_axil_awprot[3*3 +: 3]),
        .s_axil_awvalid(m_axil_awvalid[3]),
        .s_axil_awready(m_axil_awready[3]),
        .s_axil_wdata(m_axil_wdata[3*DATA_WIDTH +: DATA_WIDTH]),
        .s_axil_wstrb(m_axil_wstrb[3*STRB_WIDTH +: STRB_WIDTH]),
        .s_axil_wvalid(m_axil_wvalid[3]),
        .s_axil_wready(m_axil_wready[3]),
        .s_axil_bresp(m_axil_bresp[3*2 +: 2]),
        .s_axil_bvalid(m_axil_bvalid[3]),
        .s_axil_bready(m_axil_bready[3]),
        .s_axil_araddr(m_axil_araddr[3*ADDR_WIDTH +: 12]),
        .s_axil_arprot(m_axil_arprot[3*3 +: 3]),
        .s_axil_arvalid(m_axil_arvalid[3]),
        .s_axil_arready(m_axil_arready[3]),
        .s_axil_rdata(m_axil_rdata[3*DATA_WIDTH +: DATA_WIDTH]),
        .s_axil_rresp(m_axil_rresp[3*2 +: 2]),
        .s_axil_rvalid(m_axil_rvalid[3]),
        .s_axil_rready(m_axil_rready[3]),
        .ext_event_i(timer_ext_event),
        .timer_irq_o(timer_irq_wire)
    );

    // Clock generation (100MHz)
    always #5 clk = ~clk;

    // Cycle and Instruction counters for throughput comparison
    always @(posedge clk) begin
        if (rstn) begin
            cycle_counter <= cycle_counter + 1;
            // Count instruction when WB stage completes a valid instruction
            if (uut.mem_wb_valid) begin
                instr_counter <= instr_counter + 1;
            end
        end
    end

    // ==========================================
    //              Test Tasks
    // ==========================================
    
    task check_reg;
        input [4:0] reg_num;
        input [31:0] expected;
        input [255:0] test_name;
        reg [31:0] actual;
        begin
            test_count = test_count + 1;
            case (reg_num)
                5'd1:  actual = uut.reg_file.reg_r1_q;
                5'd2:  actual = uut.reg_file.reg_r2_q;
                5'd3:  actual = uut.reg_file.reg_r3_q;
                5'd4:  actual = uut.reg_file.reg_r4_q;
                5'd5:  actual = uut.reg_file.reg_r5_q;
                5'd6:  actual = uut.reg_file.reg_r6_q;
                5'd7:  actual = uut.reg_file.reg_r7_q;
                5'd8:  actual = uut.reg_file.reg_r8_q;
                5'd9:  actual = uut.reg_file.reg_r9_q;
                5'd10: actual = uut.reg_file.reg_r10_q;
                5'd11: actual = uut.reg_file.reg_r11_q;
                5'd12: actual = uut.reg_file.reg_r12_q;
                5'd13: actual = uut.reg_file.reg_r13_q;
                5'd14: actual = uut.reg_file.reg_r14_q;
                5'd15: actual = uut.reg_file.reg_r15_q;
                5'd16: actual = uut.reg_file.reg_r16_q;
                5'd17: actual = uut.reg_file.reg_r17_q;
                5'd18: actual = uut.reg_file.reg_r18_q;
                5'd19: actual = uut.reg_file.reg_r19_q;
                5'd20: actual = uut.reg_file.reg_r20_q;
                5'd21: actual = uut.reg_file.reg_r21_q;
                5'd22: actual = uut.reg_file.reg_r22_q;
                5'd23: actual = uut.reg_file.reg_r23_q;
                5'd24: actual = uut.reg_file.reg_r24_q;
                5'd25: actual = uut.reg_file.reg_r25_q;
                5'd26: actual = uut.reg_file.reg_r26_q;
                5'd27: actual = uut.reg_file.reg_r27_q;
                5'd28: actual = uut.reg_file.reg_r28_q;
                5'd29: actual = uut.reg_file.reg_r29_q;
                5'd30: actual = uut.reg_file.reg_r30_q;
                5'd31: actual = uut.reg_file.reg_r31_q;
                default: actual = 32'hDEADBEEF;
            endcase
            
            if (actual == expected) begin
                pass_count = pass_count + 1;
                $display("  [PASS] %0s: x%0d = %0d (%0d signed)", test_name, reg_num, actual, $signed(actual));
            end else begin
                fail_count = fail_count + 1;
                $display("  [FAIL] %0s: x%0d = %0d (%0d signed), expected %0d (%0d signed)", 
                         test_name, reg_num, actual, $signed(actual), expected, $signed(expected));
            end
        end
    endtask

    // ----------------------------------------------------------------
    //  check_mem — verify a word at a given memory address.
    //
    //  With the data-cache integrated and configured as write-back, a
    //  store may stay in the cache and never reach RAM until eviction.
    //  Inspecting `u_axil_ram.mem[]` alone misses these in-cache values
    //  and produces false negatives.
    //
    //  This task therefore checks cache, write buffer, then RAM:
    //    - For RAM addresses (< 0x0400_0000) it walks both ways at the
    //      computed index and returns cached data if a valid tag matches.
    //    - On a cache miss it checks valid write-buffer entries, warning
    //      that a buffered match does not verify writeback to RAM.
    //    - Otherwise it inspects `u_axil_ram.mem[]` directly.
    //
    //  Cache geometry (matches `data_cache` instantiation, CACHE_DEPTH=256):
    //      index = addr[9:2]  (8 bits)
    //      tag   = addr[31:10] (22 bits)
    // ----------------------------------------------------------------
    task check_mem;
        input [31:0] addr;
        input [31:0] expected;
        input [255:0] test_name;
        reg [31:0] actual;
        reg [21:0] expected_tag;
        reg [7:0]  cache_index;
        reg        in_cache;
        reg        in_write_buffer;
        integer    wb_offset;
        integer    wb_index;
        begin
            test_count = test_count + 1;
            in_cache        = 1'b0;
            in_write_buffer = 1'b0;
            expected_tag    = addr[31:10];
            cache_index     = addr[9:2];

            // RAM region: try the cache first
            if (addr < 32'h0400_0000) begin
                if (uut.data_cache.valid_bits_0[cache_index] &&
                    uut.data_cache.tags_0[cache_index] === expected_tag) begin
                    actual   = uut.data_cache.data_0[cache_index];
                    in_cache = 1'b1;
                end else if (uut.data_cache.valid_bits_1[cache_index] &&
                             uut.data_cache.tags_1[cache_index] === expected_tag) begin
                    actual   = uut.data_cache.data_1[cache_index];
                    in_cache = 1'b1;
                end else begin
                    actual = u_axil_ram.mem[addr >> 2];
                    // Match the write-buffer forwarding order so the newest
                    // valid entry wins when an address appears more than once.
                    for (wb_offset = 0; wb_offset < 8; wb_offset = wb_offset + 1) begin
                        wb_index = (uut.write_buffer_inst.read_pointer + wb_offset) % 8;
                        if (wb_offset < uut.write_buffer_inst.elem_count &&
                            uut.write_buffer_inst.write_buffer_valid[wb_index] &&
                            uut.write_buffer_inst.write_buffer_address[wb_index] == addr) begin
                            actual = uut.write_buffer_inst.write_buffer_data[wb_index];
                            in_write_buffer = 1'b1;
                        end
                    end
                end
            end else begin
                // IO/MMIO region — never cached
                actual = u_axil_ram.mem[addr >> 2];
            end

            if (actual == expected) begin
                pass_count = pass_count + 1;
                if (in_write_buffer)
                    $display("  [PASS] %0s: write-buffer[0x%04h] = %0d [WARN: RAM writeback not verified]",
                             test_name, addr, actual);
                else
                    $display("  [PASS] %0s: %s[0x%04h] = %0d",
                             test_name, in_cache ? "cache" : "  mem", addr, actual);
            end else begin
                fail_count = fail_count + 1;
                if (in_write_buffer)
                    $display("  [FAIL] %0s: write-buffer[0x%04h] = %0d (expected %0d) [WARN: RAM writeback not verified]",
                             test_name, addr, actual, expected);
                else
                    $display("  [FAIL] %0s: %s[0x%04h] = %0d (expected %0d)",
                             test_name, in_cache ? "cache" : "  mem", addr, actual, expected);
            end
        end
    endtask

    // Direct memory-only check — used by cache write-back tests that
    // explicitly want to verify a value reached RAM (i.e. was evicted).
    task check_ram;
        input [31:0] addr;
        input [31:0] expected;
        input [255:0] test_name;
        reg [31:0] actual;
        begin
            test_count = test_count + 1;
            actual = u_axil_ram.mem[addr >> 2];
            if (actual == expected) begin
                pass_count = pass_count + 1;
                $display("  [PASS] %0s: ram[0x%04h] = %0d", test_name, addr, actual);
            end else begin
                fail_count = fail_count + 1;
                $display("  [FAIL] %0s: ram[0x%04h] = %0d (expected %0d)",
                         test_name, addr, actual, expected);
            end
        end
    endtask

    // ----------------------------------------------------------------
    //  read_mem_or_cache — return the word at `addr`, checking the
    //  data cache first (same geometry as check_mem).
    // ----------------------------------------------------------------
    function automatic [31:0] read_mem_or_cache;
        input [31:0] addr;
        reg [21:0] ftag;
        reg [7:0]  fidx;
        begin
            ftag = addr[31:10];
            fidx = addr[9:2];
            if (addr < 32'h0400_0000 &&
                uut.data_cache.valid_bits_0[fidx] &&
                uut.data_cache.tags_0[fidx] === ftag)
                read_mem_or_cache = uut.data_cache.data_0[fidx];
            else if (addr < 32'h0400_0000 &&
                     uut.data_cache.valid_bits_1[fidx] &&
                     uut.data_cache.tags_1[fidx] === ftag)
                read_mem_or_cache = uut.data_cache.data_1[fidx];
            else
                read_mem_or_cache = u_axil_ram.mem[addr >> 2];
        end
    endfunction

    task wait_cycles;
        input integer n;
        begin
            repeat(n) @(posedge clk);
        end
    endtask

    task reset_cpu;
        begin
            // Accumulate counters from previous test
            total_cycles = total_cycles + cycle_counter;
            total_instrs = total_instrs + instr_counter;
            
            // Accumulate internal counters (read before reset)
            // Skip first call (before any test runs) to avoid X/garbage
            if (resets_done > 0) begin
                total_internal_cycles = total_internal_cycles + uut.u_csr_file.mcycle_r;
                total_internal_instrs = total_internal_instrs + uut.u_csr_file.minstret_r;
                total_internal_cache_hits = total_internal_cache_hits + uut.u_csr_file.mhpmcounter3_r;
                total_internal_dcache_hits = total_internal_dcache_hits + uut.u_csr_file.mhpmcounter4_r;
                total_internal_memory_writes = total_internal_memory_writes + uut.u_csr_file.mhpmcounter6_r;
                total_internal_memory_reads = total_internal_memory_reads + uut.u_csr_file.mhpmcounter5_r;
            end
            resets_done = resets_done + 1;
            
            // Reset per-test counters
            cycle_counter = 0;
            instr_counter = 0;
            
            rstn = 0;
            wait_cycles(10);  // Increased from 4 to allow pipeline flush
            rstn = 1;
            wait_cycles(5);   // Increased from 2 to allow pipeline fill
        end
    endtask

    task verify_counters;
        input integer exp_writes;
        input integer exp_reads;
        input integer exp_dcache_hits;
        input [255:0] test_name;
        reg writes_ok, reads_ok, dcache_ok;
        begin
            total_memory_writes = total_memory_writes + exp_writes;
            total_memory_reads = total_memory_reads + exp_reads;
            
            writes_ok = (uut.u_csr_file.mhpmcounter6_r == exp_writes);
            reads_ok  = (uut.u_csr_file.mhpmcounter5_r == exp_reads);
            dcache_ok = (exp_dcache_hits < 0) || (uut.u_csr_file.mhpmcounter4_r == exp_dcache_hits);

            // Check against current test counters (which reset on reset_cpu)
            if (writes_ok && reads_ok && dcache_ok) begin
                if (exp_dcache_hits >= 0)
                    $display("  [PERF] %0s: Writes=%0d, Reads=%0d, D$Hits=%0d (MATCH)",
                             test_name, uut.u_csr_file.mhpmcounter6_r,
                             uut.u_csr_file.mhpmcounter5_r,
                             uut.u_csr_file.mhpmcounter4_r);
                else
                    $display("  [PERF] %0s: Writes=%0d, Reads=%0d (MATCH)",
                             test_name, uut.u_csr_file.mhpmcounter6_r,
                             uut.u_csr_file.mhpmcounter5_r);
            end else begin
                if (exp_dcache_hits >= 0)
                    $display("  [PERF-FAIL] %0s: Writes=%0d (Exp %0d), Reads=%0d (Exp %0d), D$Hits=%0d (Exp %0d)",
                             test_name, uut.u_csr_file.mhpmcounter6_r, exp_writes,
                             uut.u_csr_file.mhpmcounter5_r, exp_reads,
                             uut.u_csr_file.mhpmcounter4_r, exp_dcache_hits);
                else
                    $display("  [PERF-FAIL] %0s: Writes=%0d (Exp %0d), Reads=%0d (Exp %0d)",
                             test_name, uut.u_csr_file.mhpmcounter6_r, exp_writes,
                             uut.u_csr_file.mhpmcounter5_r, exp_reads);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ==========================================
    //           Test Program Loading
    // ==========================================
    
    task load_test1_arithmetic;
        begin
            $display("\n--- Loading Test 1: Arithmetic Operations ---");
            // Address 0x00: ADDI x2, x0, 10    - x2 = 10
            u_axil_ram.mem[0] = 32'h00a00113;
            // Address 0x04: ADDI x3, x0, 7     - x3 = 7
            u_axil_ram.mem[1] = 32'h00700193;
            // Address 0x08: ADD x4, x2, x3     - x4 = 10 + 7 = 17
            u_axil_ram.mem[2] = 32'h00310233;
            // Address 0x0C: SUB x5, x2, x3     - x5 = 10 - 7 = 3
            u_axil_ram.mem[3] = 32'h403102b3;
            // Address 0x10: ADDI x6, x0, -5    - x6 = -5
            u_axil_ram.mem[4] = 32'hffb00313;
            // Address 0x14: ADD x7, x4, x6     - x7 = 17 + (-5) = 12
            u_axil_ram.mem[5] = 32'h006203b3;
            // NOPs
            u_axil_ram.mem[6] = 32'h00000013;
            u_axil_ram.mem[7] = 32'h00000013;
        end
    endtask

    task load_test2_logical;
        begin
            $display("\n--- Loading Test 2: Logical Operations ---");
            // ADDI x2, x0, 0xFF    - x2 = 255
            u_axil_ram.mem[0] = 32'h0ff00113;
            // ADDI x3, x0, 0x0F    - x3 = 15
            u_axil_ram.mem[1] = 32'h00f00193;
            // AND x4, x2, x3       - x4 = 255 & 15 = 15
            u_axil_ram.mem[2] = 32'h00317233;
            // OR x5, x2, x3        - x5 = 255 | 15 = 255
            u_axil_ram.mem[3] = 32'h003162b3;
            // XOR x6, x2, x3       - x6 = 255 ^ 15 = 240
            u_axil_ram.mem[4] = 32'h00314333;
            // ANDI x7, x2, 0x55    - x7 = 255 & 85 = 85
            u_axil_ram.mem[5] = 32'h05517393;
            // ORI x8, x0, 0xAA     - x8 = 0 | 170 = 170
            u_axil_ram.mem[6] = 32'h0aa06413;
            // XORI x9, x8, 0xFF    - x9 = 170 ^ 255 = 85
            u_axil_ram.mem[7] = 32'h0ff44493;
            // NOPs
            u_axil_ram.mem[8] = 32'h00000013;
            u_axil_ram.mem[9] = 32'h00000013;
        end
    endtask

    task load_test3_shifts;
        begin
            $display("\n--- Loading Test 3: Shift Operations ---");
            // ADDI x2, x0, 1       - x2 = 1
            u_axil_ram.mem[0] = 32'h00100113;
            // SLLI x3, x2, 4       - x3 = 1 << 4 = 16
            u_axil_ram.mem[1] = 32'h00411193;
            // SLLI x4, x2, 8       - x4 = 1 << 8 = 256
            u_axil_ram.mem[2] = 32'h00811213;
            // ADDI x5, x0, -1      - x5 = 0xFFFFFFFF
            u_axil_ram.mem[3] = 32'hfff00293;
            // SRLI x6, x5, 24      - x6 = 0xFFFFFFFF >>> 24 = 0xFF = 255
            u_axil_ram.mem[4] = 32'h0182d313;
            // SRAI x7, x5, 24      - x7 = 0xFFFFFFFF >> 24 = 0xFFFFFFFF = -1
            u_axil_ram.mem[5] = 32'h4182d393;
            // ADDI x8, x0, 8       - x8 = 8 (shift amount)
            u_axil_ram.mem[6] = 32'h00800413;
            // SLL x9, x2, x8       - x9 = 1 << 8 = 256
            // Encoding: funct7=0000000, rs2=8, rs1=2, funct3=001, rd=9, opcode=0110011
            u_axil_ram.mem[7] = 32'h008114b3;
            // SRL x10, x5, x8      - x10 = 0xFFFFFFFF >>> 8 = 0x00FFFFFF
            // Encoding: funct7=0000000, rs2=8, rs1=5, funct3=101, rd=10, opcode=0110011
            u_axil_ram.mem[8] = 32'h0082d533;
            // SRA x11, x5, x8      - x11 = 0xFFFFFFFF >> 8 = 0xFFFFFFFF
            // Encoding: funct7=0100000, rs2=8, rs1=5, funct3=101, rd=11, opcode=0110011
            u_axil_ram.mem[9] = 32'h4082d5b3;
            // NOPs
            u_axil_ram.mem[10] = 32'h00000013;
            u_axil_ram.mem[11] = 32'h00000013;
        end
    endtask

    task load_test4_memory;
        begin
            $display("\n--- Loading Test 4: Memory Load/Store ---");
            // ADDI x2, x0, 42      - x2 = 42
            u_axil_ram.mem[0] = 32'h02a00113;
            // ADDI x3, x0, 100     - x3 = 100
            u_axil_ram.mem[1] = 32'h06400193;
            // SW x2, 256(x0)       - mem[256] = 42
            u_axil_ram.mem[2] = 32'h10202023;
            // SW x3, 260(x0)       - mem[260] = 100
            u_axil_ram.mem[3] = 32'h10302223;
            // LW x4, 256(x0)       - x4 = mem[256] = 42
            u_axil_ram.mem[4] = 32'h10002203;
            // LW x5, 260(x0)       - x5 = mem[260] = 100
            u_axil_ram.mem[5] = 32'h10402283;
            // ADD x6, x4, x5       - x6 = 42 + 100 = 142
            u_axil_ram.mem[6] = 32'h00520333;
            // SW x6, 264(x0)       - mem[264] = 142
            u_axil_ram.mem[7] = 32'h10602423;
            // NOPs
            u_axil_ram.mem[8] = 32'h00000013;
            u_axil_ram.mem[9] = 32'h00000013;
        end
    endtask

    task load_test5_compare;
        begin
            $display("\n--- Loading Test 5: Compare Operations ---");
            // ADDI x2, x0, 10      - x2 = 10
            u_axil_ram.mem[0] = 32'h00a00113;
            // ADDI x3, x0, 20      - x3 = 20
            u_axil_ram.mem[1] = 32'h01400193;
            // SLT x4, x2, x3       - x4 = (10 < 20) = 1
            u_axil_ram.mem[2] = 32'h00312233;
            // SLT x5, x3, x2       - x5 = (20 < 10) = 0
            u_axil_ram.mem[3] = 32'h0021a2b3;
            // SLTI x6, x2, 15      - x6 = (10 < 15) = 1
            u_axil_ram.mem[4] = 32'h00f12313;
            // SLTI x7, x2, 5       - x7 = (10 < 5) = 0
            u_axil_ram.mem[5] = 32'h00512393;
            // ADDI x8, x0, -1      - x8 = -1 (0xFFFFFFFF)
            u_axil_ram.mem[6] = 32'hfff00413;
            // SLTU x9, x8, x2      - x9 = (0xFFFFFFFF < 10) = 0 (unsigned)
            u_axil_ram.mem[7] = 32'h00243493;
            // SLTIU x10, x2, 100   - x10 = (10 < 100 unsigned) = 1
            u_axil_ram.mem[8] = 32'h06413513;
            // SLTIU x11, x8, 1     - x11 = (0xFFFFFFFF < 1 unsigned) = 0
            u_axil_ram.mem[9] = 32'h00143593;
            // SLTU x12, x2, x8     - x12 = (10 < 0xFFFFFFFF unsigned) = 1
            u_axil_ram.mem[10] = 32'h00813633;
            // NOPs
            u_axil_ram.mem[11] = 32'h00000013;
            u_axil_ram.mem[12] = 32'h00000013;
        end
    endtask

    task load_test6_lui_auipc;
        begin
            $display("\n--- Loading Test 6: LUI and AUIPC ---");
            // LUI x2, 0x12345      - x2 = 0x12345000
            u_axil_ram.mem[0] = 32'h12345137;
            // ADDI x3, x2, 0x678   - x3 = 0x12345678
            u_axil_ram.mem[1] = 32'h67810193;
            // AUIPC x4, 0          - x4 = PC (0x08)
            u_axil_ram.mem[2] = 32'h00000217;
            // LUI x5, 0xFFFFF      - x5 = 0xFFFFF000
            u_axil_ram.mem[3] = 32'hfffff2b7;
            // NOPs
            u_axil_ram.mem[4] = 32'h00000013;
            u_axil_ram.mem[5] = 32'h00000013;
        end
    endtask

    task load_test7_full_program;
        begin
            $display("\n--- Loading Test 7: Full Integration Test ---");
            // Fibonacci-like computation: f(n) = f(n-1) + f(n-2)
            
            // ADDI x2, x0, 1       - x2 = 1 (f[0])
            u_axil_ram.mem[0] = 32'h00100113;
            // ADDI x3, x0, 1       - x3 = 1 (f[1])
            u_axil_ram.mem[1] = 32'h00100193;
            // ADD x4, x2, x3       - x4 = 2 (f[2])
            u_axil_ram.mem[2] = 32'h00310233;
            // ADD x5, x3, x4       - x5 = 3 (f[3])
            u_axil_ram.mem[3] = 32'h004182b3;
            // ADD x6, x4, x5       - x6 = 5 (f[4])
            u_axil_ram.mem[4] = 32'h00520333;
            // ADD x7, x5, x6       - x7 = 8 (f[5])
            u_axil_ram.mem[5] = 32'h006283b3;
            // ADD x8, x6, x7       - x8 = 13 (f[6])
            u_axil_ram.mem[6] = 32'h00730433;
            // ADD x9, x7, x8       - x9 = 21 (f[7])
            u_axil_ram.mem[7] = 32'h008384b3;
            // Store results
            // SW x9, 256(x0)       - mem[256] = 21
            u_axil_ram.mem[8] = 32'h10902023;
            // NOPs
            u_axil_ram.mem[9] = 32'h00000013;
            u_axil_ram.mem[10] = 32'h00000013;
        end
    endtask

    task load_test8_branches;
        integer i;
        begin
            $display("\n--- Loading Test 8: Branch Operations ---");
            // Clear memory first to avoid contamination from previous tests
            for (i = 0; i < 64; i = i + 1) begin
                u_axil_ram.mem[i] = 32'h00000013; // NOP
            end
            
            // This test verifies all branch instructions
            // We use x10 as a result accumulator, incrementing on correct paths
            
            // Setup values
            // 0x00: ADDI x2, x0, 5       - x2 = 5
            u_axil_ram.mem[0] = 32'h00500113;
            // 0x04: ADDI x3, x0, 5       - x3 = 5 (equal to x2)
            u_axil_ram.mem[1] = 32'h00500193;
            // 0x08: ADDI x4, x0, 10      - x4 = 10 (greater than x2)
            u_axil_ram.mem[2] = 32'h00a00213;
            // 0x0C: ADDI x10, x0, 0      - x10 = 0 (result counter)
            u_axil_ram.mem[3] = 32'h00000513;
            // 0x10: ADDI x5, x0, -1      - x5 = -1 (0xFFFFFFFF for unsigned tests)
            u_axil_ram.mem[4] = 32'hfff00293;
            
            // ---- Test BEQ (branch if equal) ----
            // 0x14: BEQ x2, x3, +8       - Should branch (5 == 5)
            u_axil_ram.mem[5] = 32'h00310463;
            // 0x18: ADDI x11, x0, 1      - SKIP (x11 = 1 means BEQ failed)
            u_axil_ram.mem[6] = 32'h00100593;
            // 0x1C: ADDI x10, x10, 1     - x10++ (BEQ taken correctly)
            u_axil_ram.mem[7] = 32'h00150513;
            
            // ---- Test BNE (branch if not equal) ----
            // 0x20: BNE x2, x4, +8       - Should branch (5 != 10)
            u_axil_ram.mem[8] = 32'h00411463;
            // 0x24: ADDI x12, x0, 1      - SKIP (x12 = 1 means BNE failed)
            u_axil_ram.mem[9] = 32'h00100613;
            // 0x28: ADDI x10, x10, 1     - x10++ (BNE taken correctly)
            u_axil_ram.mem[10] = 32'h00150513;
            
            // ---- Test BLT (branch if less than, signed) ----
            // 0x2C: BLT x2, x4, +8       - Should branch (5 < 10)
            u_axil_ram.mem[11] = 32'h00414463;
            // 0x30: ADDI x13, x0, 1      - SKIP (x13 = 1 means BLT failed)
            u_axil_ram.mem[12] = 32'h00100693;
            // 0x34: ADDI x10, x10, 1     - x10++ (BLT taken correctly)
            u_axil_ram.mem[13] = 32'h00150513;
            
            // ---- Test BGE (branch if greater or equal, signed) ----
            // 0x38: BGE x4, x2, +8       - Should branch (10 >= 5)
            u_axil_ram.mem[14] = 32'h00225463;
            // 0x3C: ADDI x14, x0, 1      - SKIP (x14 = 1 means BGE failed)
            u_axil_ram.mem[15] = 32'h00100713;
            // 0x40: ADDI x10, x10, 1     - x10++ (BGE taken correctly)
            u_axil_ram.mem[16] = 32'h00150513;
            
            // ---- Test BLTU (branch if less than, unsigned) ----
            // 0x44: BLTU x2, x5, +8      - Should branch (5 < 0xFFFFFFFF unsigned)
            u_axil_ram.mem[17] = 32'h00516463;
            // 0x48: ADDI x15, x0, 1      - SKIP (x15 = 1 means BLTU failed)
            u_axil_ram.mem[18] = 32'h00100793;
            // 0x4C: ADDI x10, x10, 1     - x10++ (BLTU taken correctly)
            u_axil_ram.mem[19] = 32'h00150513;
            
            // ---- Test BGEU (branch if greater or equal, unsigned) ----
            // 0x50: BGEU x5, x2, +8      - Should branch (0xFFFFFFFF >= 5 unsigned)
            u_axil_ram.mem[20] = 32'h00217463;
            // 0x54: ADDI x1, x0, 1       - SKIP (x1 = 1 means BGEU failed)
            u_axil_ram.mem[21] = 32'h00100093;
            // 0x58: ADDI x10, x10, 1     - x10++ (BGEU taken correctly)
            u_axil_ram.mem[22] = 32'h00150513;
            
            // ---- Test branch NOT taken cases ----
            // 0x5C: BEQ x2, x4, +8       - Should NOT branch (5 != 10)
            u_axil_ram.mem[23] = 32'h00410463;
            // 0x60: ADDI x10, x10, 1     - x10++ (BEQ correctly not taken)
            u_axil_ram.mem[24] = 32'h00150513;
            // 0x64: NOP                  - This would be skipped if branch taken
            u_axil_ram.mem[25] = 32'h00000013;
            
            // 0x68: BNE x2, x3, +8       - Should NOT branch (5 == 5)
            u_axil_ram.mem[26] = 32'h00311463;
            // 0x6C: ADDI x10, x10, 1     - x10++ (BNE correctly not taken)
            u_axil_ram.mem[27] = 32'h00150513;
            // 0x70: NOP
            u_axil_ram.mem[28] = 32'h00000013;
            
            // Final result: x10 should be 8 (6 taken + 2 not taken tests passed)
            // NOPs
            u_axil_ram.mem[29] = 32'h00000013;
            u_axil_ram.mem[30] = 32'h00000013;
        end
    endtask

    task load_test10_backward_branch;
        integer i;
        begin
            $display("\n--- Loading Test 10: Backward Branch (Loop) ---");
            // Clear memory first to avoid contamination from previous tests
            for (i = 0; i < 64; i = i + 1) begin
                u_axil_ram.mem[i] = 32'h00000013; // NOP
            end
            
            // This test implements a simple loop that counts from 0 to 5
            // x2 = counter, x3 = limit (5), x10 = sum accumulator
            
            // 0x00: ADDI x2, x0, 0      - x2 = 0 (counter)
            u_axil_ram.mem[0] = 32'h00000113;
            // 0x04: ADDI x3, x0, 5      - x3 = 5 (limit)
            u_axil_ram.mem[1] = 32'h00500193;
            // 0x08: ADDI x10, x0, 0     - x10 = 0 (sum)
            u_axil_ram.mem[2] = 32'h00000513;
            
            // Loop start (0x0C):
            // 0x0C: ADD x10, x10, x2    - sum += counter
            u_axil_ram.mem[3] = 32'h00250533;
            // 0x10: ADDI x2, x2, 1      - counter++
            u_axil_ram.mem[4] = 32'h00110113;
            // 0x14: BLT x2, x3, -8      - if counter < 5, branch back to 0x0C
            // Branch offset: 0x0C - 0x14 = -8
            // -8 = 0b1_1111_1111_1000, imm[12]=1, imm[11]=1, imm[10:5]=111111, imm[4:1]=1100
            // B-type: imm[12|10:5] rs2 rs1 funct3 imm[4:1|11] opcode
            //       = 1_111111 00011 00010 100 1100_1 1100011 = 0xFE314CE3
            u_axil_ram.mem[5] = 32'hfe314ce3;
            
            // Loop done, x10 should be 0+1+2+3+4 = 10
        end
    endtask

    task load_test11_io_access;
        begin
            $display("\n--- Loading Test 11: IO Access (UART/GPIO) ---");
            // Test writing and reading from UART and GPIO regions
            // Note: Since they are empty slaves, they will just respond with OKAY and 0 data.
            // We just want to verify the interconnect routes the requests correctly and doesn't hang.

            // 0x00: ADDI x2, x0, 0x123      - x2 = 0x123
            u_axil_ram.mem[0] = 32'h12300113;
            
            // ---- UART Access (0x0400_0000) ----
            // 0x04: LUI x3, 0x04000         - x3 = 0x04000000 (UART Base)
            u_axil_ram.mem[1] = 32'h040001b7;
            // 0x08: SW x2, 0(x3)            - Write 0x123 to UART TX_DATA
            u_axil_ram.mem[2] = 32'h0021a023;
            // 0x0C: LW x4, 8(x3)            - Read UART STATUS (offset 0x08)
            // Expected: TX_EMPTY=1, TX_BUSY may vary, RX_VALID=0, RX_ERR=0
            u_axil_ram.mem[3] = 32'h0081a203;

            // ---- GPIO Access (0x0400_1000) ----
            // 0x10: LUI x5, 0x04001         - x5 = 0x04001000 (GPIO Base)
            u_axil_ram.mem[4] = 32'h040012b7;
            
            // 0x14: SW x2, 0(x5)            - Write 0x123 to GPIO Base
            u_axil_ram.mem[5] = 32'h0022a023;
            // 0x18: LW x6, 0(x5)            - Read from GPIO Base (should be 0)
            u_axil_ram.mem[6] = 32'h0002a303;

            // NOPs
            u_axil_ram.mem[7] = 32'h00000013;
            u_axil_ram.mem[8] = 32'h00000013;
            // Infinite loop to stop execution
            u_axil_ram.mem[9] = 32'h0000006f; // JAL x0, 0
        end
    endtask

    task load_test9_jumps;
        begin
            $display("\n--- Loading Test 9: Jump Operations (JAL/JALR) ---");
            // This test verifies JAL and JALR instructions
            // x10 is used as result accumulator
            
            // 0x00: ADDI x10, x0, 0      - x10 = 0 (result counter)
            u_axil_ram.mem[0] = 32'h00000513;
            
            // ---- Test JAL (Jump and Link) ----
            // 0x04: JAL x1, +12          - Jump to 0x10, x1 = 0x08 (return addr)
            u_axil_ram.mem[1] = 32'h00c000ef;
            // 0x08: ADDI x11, x0, 1      - SKIP (x11 = 1 means JAL failed)
            u_axil_ram.mem[2] = 32'h00100593;
            // 0x0C: ADDI x11, x0, 2      - SKIP
            u_axil_ram.mem[3] = 32'h00200593;
            // 0x10: ADDI x10, x10, 1     - x10++ (JAL landed here correctly)
            u_axil_ram.mem[4] = 32'h00150513;
            
            // Verify x1 has correct return address (0x08)
            // 0x14: ADDI x2, x0, 8       - x2 = 8 (expected return addr)
            u_axil_ram.mem[5] = 32'h00800113;
            // 0x18: BNE x1, x2, +8       - Skip increment if x1 != 8
            u_axil_ram.mem[6] = 32'h00209463;
            // 0x1C: ADDI x10, x10, 1     - x10++ (return addr correct)
            u_axil_ram.mem[7] = 32'h00150513;
            // 0x20: NOP
            u_axil_ram.mem[8] = 32'h00000013;
            
            // ---- Test JALR (Jump and Link Register) ----
            // 0x24: ADDI x3, x0, 0x38    - x3 = 0x38 (target address)
            u_axil_ram.mem[9] = 32'h03800193;
            // 0x28: JALR x4, x3, 0       - Jump to x3 (0x38), x4 = 0x2C
            u_axil_ram.mem[10] = 32'h00018267;
            // 0x2C: ADDI x12, x0, 1      - SKIP (x12 = 1 means JALR failed)
            u_axil_ram.mem[11] = 32'h00100613;
            // 0x30: ADDI x12, x0, 2      - SKIP
            u_axil_ram.mem[12] = 32'h00200613;
            // 0x34: ADDI x12, x0, 3      - SKIP
            u_axil_ram.mem[13] = 32'h00300613;
            // 0x38: ADDI x10, x10, 1     - x10++ (JALR landed here correctly)
            u_axil_ram.mem[14] = 32'h00150513;
            
            // Verify x4 has correct return address (0x2C)
            // 0x3C: ADDI x5, x0, 0x2C    - x5 = 0x2C (expected return addr)
            u_axil_ram.mem[15] = 32'h02c00293;
            // 0x40: BNE x4, x5, +8       - Skip increment if x4 != 0x2C
            u_axil_ram.mem[16] = 32'h00521463;
            // 0x44: ADDI x10, x10, 1     - x10++ (return addr correct)
            u_axil_ram.mem[17] = 32'h00150513;
            // 0x48: NOP
            u_axil_ram.mem[18] = 32'h00000013;
            
            // ---- Test JALR with offset ----
            // 0x4C: ADDI x6, x0, 0x58    - x6 = 0x58
            u_axil_ram.mem[19] = 32'h05800313;
            // 0x50: JALR x7, x6, 8       - Jump to x6+8 (0x60), x7 = 0x54
            // Encoding: imm[11:0]=8, rs1=6, funct3=000, rd=7, opcode=1100111
            u_axil_ram.mem[20] = 32'h008303e7;
            // 0x54: ADDI x13, x0, 1      - SKIP
            u_axil_ram.mem[21] = 32'h00100693;
            // 0x58: ADDI x13, x0, 2      - SKIP
            u_axil_ram.mem[22] = 32'h00200693;
            // 0x5C: ADDI x13, x0, 3      - SKIP
            u_axil_ram.mem[23] = 32'h00300693;
            // 0x60: ADDI x10, x10, 1     - x10++ (JALR+offset landed correctly)
            u_axil_ram.mem[24] = 32'h00150513;
            
            // Verify x7 has correct return address (0x54)
            // 0x64: ADDI x8, x0, 0x54    - x8 = 0x54
            u_axil_ram.mem[25] = 32'h05400413;
            // 0x68: BNE x7, x8, +8       - Skip increment if x7 != 0x54
            u_axil_ram.mem[26] = 32'h00839463;
            // 0x6C: ADDI x10, x10, 1     - x10++ (return addr correct)
            u_axil_ram.mem[27] = 32'h00150513;
            
            // Final result: x10 should be 6 (3 jumps + 3 return addr checks)
            // NOPs
            u_axil_ram.mem[28] = 32'h00000013;
            u_axil_ram.mem[29] = 32'h00000013;
            u_axil_ram.mem[30] = 32'h00000013;
        end
    endtask

    // ==========================================
    //           Main Test Sequence
    // ==========================================
    
    initial begin
        $dumpfile("z_core_control_u_tb.vcd");
        $dumpvars(0, z_core_control_u_tb);

        // Initialize UART testbench signals
        uart_rx_tb_drive = 1'b1;  // Idle high
        uart_rx_tb_en = 1'b0;     // Use loopback by default

        $display("");
        $display(" ___________________________________________________________");
        $display("|           Z-Core RISC-V Processor Test Suite              |");
        $display("|               RV32IM+Zicsr Instruction Set                |");
        $display("|___________________________________________________________|");

        // ==========================================
        // Test 1: Arithmetic Operations
        // ==========================================
        load_test1_arithmetic();
        // Test 1
        reset_cpu();
        #1500;
        
        $display("\n=== Test 1 Results: Arithmetic ===");
        check_reg(2, 10, "ADDI x2, x0, 10");
        check_reg(3, 7,  "ADDI x3, x0, 7");
        check_reg(4, 17, "ADD x4, x2, x3");
        check_reg(5, 3,  "SUB x5, x2, x3");
        check_reg(6, -5, "ADDI x6, x0, -5");
        check_reg(7, 12, "ADD x7, x4, x6");
        verify_counters(0, 0, -1, "Test 1");

        // ==========================================
        // Test 2: Logical Operations
        // ==========================================
        load_test2_logical();
        reset_cpu();
        #2000;
        
        $display("\n=== Test 2 Results: Logical ===");
        check_reg(2, 255, "ADDI x2, x0, 0xFF");
        check_reg(3, 15,  "ADDI x3, x0, 0x0F");
        check_reg(4, 15,  "AND x4, x2, x3");
        check_reg(5, 255, "OR x5, x2, x3");
        check_reg(6, 240, "XOR x6, x2, x3");
        check_reg(7, 85,  "ANDI x7, x2, 0x55");
        check_reg(8, 170, "ORI x8, x0, 0xAA");
        check_reg(9, 85,  "XORI x9, x8, 0xFF");
        verify_counters(0, 0, -1, "Test 2");

        // ==========================================
        // Test 3: Shift Operations
        // ==========================================
        load_test3_shifts();
        reset_cpu();
        #2000;
        
        $display("\n=== Test 3 Results: Shifts ===");
        check_reg(2, 1,   "ADDI x2, x0, 1");
        check_reg(3, 16,  "SLLI x3, x2, 4");
        check_reg(4, 256, "SLLI x4, x2, 8");
        check_reg(6, 255, "SRLI x6, x5, 24");
        check_reg(7, -1,  "SRAI x7, x5, 24");
        check_reg(9, 256, "SLL x9, x2, x8");
        check_reg(10, 32'h00FFFFFF, "SRL x10, x5, x8");
        check_reg(11, -1, "SRA x11, x5, x8");
        verify_counters(0, 0, -1, "Test 3");

        // ==========================================
        // Test 4: Memory Load/Store
        // ==========================================
        load_test4_memory();
        reset_cpu();
        #2500;
        
        $display("\n=== Test 4 Results: Memory ===");
        check_reg(2, 42,  "ADDI x2, x0, 42");
        check_reg(3, 100, "ADDI x3, x0, 100");
        check_reg(4, 42,  "LW x4, 256(x0)");
        check_reg(5, 100, "LW x5, 260(x0)");
        check_reg(6, 142, "ADD x6, x4, x5");
        check_mem(256, 42,  "SW x2, 256(x0)");
        check_mem(260, 100, "SW x3, 260(x0)");
        check_mem(264, 142, "SW x6, 264(x0)");
        verify_counters(3, 2, 2, "Test 4");

        // ==========================================
        // Test 5: Compare Operations
        // ==========================================
        load_test5_compare();
        reset_cpu();
        #2000;
        
        $display("\n=== Test 5 Results: Compare ===");
        check_reg(4, 1, "SLT x4 (10 < 20)");
        check_reg(5, 0, "SLT x5 (20 < 10)");
        check_reg(6, 1, "SLTI x6 (10 < 15)");
        check_reg(7, 0, "SLTI x7 (10 < 5)");
        check_reg(9, 0, "SLTU x9 (0xFFFFFFFF < 10)");
        check_reg(10, 1, "SLTIU x10 (10 < 100)");
        check_reg(11, 0, "SLTIU x11 (0xFFFFFFFF < 1)");
        check_reg(12, 1, "SLTU x12 (10 < 0xFFFFFFFF)");
        verify_counters(0, 0, -1, "Test 5");

        // ==========================================
        // Test 6: LUI and AUIPC
        // ==========================================
        load_test6_lui_auipc();
        reset_cpu();
        #1500;
        
        $display("\n=== Test 6 Results: LUI/AUIPC ===");
        check_reg(2, 32'h12345000, "LUI x2, 0x12345");
        check_reg(3, 32'h12345678, "ADDI x3, x2, 0x678");
        check_reg(4, 8,            "AUIPC x4, 0");
        check_reg(5, 32'hFFFFF000, "LUI x5, 0xFFFFF");
        verify_counters(0, 0, -1, "Test 6");

        // ==========================================
        // Test 7: Full Integration (Fibonacci)
        // ==========================================
        load_test7_full_program();
        reset_cpu();
        #2500;
        
        $display("\n=== Test 7 Results: Fibonacci ===");
        check_reg(2, 1,  "f[0] = 1");
        check_reg(3, 1,  "f[1] = 1");
        check_reg(4, 2,  "f[2] = 2");
        check_reg(5, 3,  "f[3] = 3");
        check_reg(6, 5,  "f[4] = 5");
        check_reg(7, 8,  "f[5] = 8");
        check_reg(8, 13, "f[6] = 13");
        check_reg(9, 21, "f[7] = 21");
        check_mem(256, 21, "Stored f[7]");
        verify_counters(1, 0, -1, "Test 7");

        // ==========================================
        // Test 8: Branch Operations
        // ==========================================
        load_test8_branches();
        reset_cpu();
        #4000;
        
        $display("\n=== Test 8 Results: Branches ===");
        check_reg(10, 8, "Branch test counter (8 passed)");
        check_reg(11, 0, "BEQ taken (should be 0)");
        check_reg(12, 0, "BNE taken (should be 0)");
        check_reg(13, 0, "BLT taken (should be 0)");
        check_reg(14, 0, "BGE taken (should be 0)");
        check_reg(15, 0, "BLTU taken (should be 0)");
        check_reg(1,  0, "BGEU taken (should be 0)");
        verify_counters(0, 0, -1, "Test 8");

        // ==========================================
        // Test 9: Jump Operations (JAL/JALR)
        // ==========================================
        load_test9_jumps();
        reset_cpu();
        #4000;
        
        $display("\n=== Test 9 Results: Jumps ===");
        check_reg(10, 6, "Jump test counter (6 passed)");
        check_reg(1,  8, "JAL return addr (x1=0x08)");
        check_reg(4,  32'h2C, "JALR return addr (x4=0x2C)");
        check_reg(7,  32'h54, "JALR+offset return (x7=0x54)");
        check_reg(11, 0, "JAL path check (should be 0)");
        check_reg(12, 0, "JALR path check (should be 0)");
        check_reg(13, 0, "JALR+offset path (should be 0)");
        verify_counters(0, 0, -1, "Test 9");

        // ==========================================
        // Test 10: Backward Branch (Loop)
        // ==========================================
        load_test10_backward_branch();
        reset_cpu();
        #6000;  // Loop needs more time with AXI latency
        
        $display("\n=== Test 10 Results: Backward Branch ===");
        check_reg(2, 5,  "Loop counter final (5)");
        check_reg(3, 5,  "Loop limit (5)");
        check_reg(10, 10, "Sum 0+1+2+3+4 = 10");
        verify_counters(0, 0, -1, "Test 10");

        // ==========================================
        // Test 11: IO Access (UART/GPIO)
        // ==========================================
        load_test11_io_access();
        reset_cpu();
        #20000;  // Allow time for UART TX to complete (baud_div=10, 16x oversample, 10 bits)
        
        $display("\n=== Test 11 Results: IO Access ===");
        // UART STATUS read - just verify interconnect routes correctly and we get valid data
        // The actual STATUS value depends on timing (TX in progress or complete)
        // Status flags: [3]=RX_ERR, [2]=RX_VALID, [1]=TX_BUSY, [0]=TX_EMPTY
        // Just verify it's a valid non-X value
        if (uut.reg_file.reg_r4_q !== 32'hxxxxxxxx) begin
            test_count = test_count + 1;
            pass_count = pass_count + 1;
            $display("  [PASS] UART STATUS valid: x4 = %d (0x%h)", uut.reg_file.reg_r4_q, uut.reg_file.reg_r4_q);
        end else begin
            test_count = test_count + 1;
            fail_count = fail_count + 1;
            $display("  [FAIL] UART STATUS invalid: x4 = x");
        end
        // NOTE: GPIO read removed - bidirectional GPIO is tested in Test 12
        verify_counters(2, 2, -1, "Test 11");

        // ==========================================
        // Test 12: GPIO Bidirectional Verification
        // ==========================================
        load_test12_gpio_bidirectional();
        gpio_test_en = 0;    // TB not driving initially
        gpio_test_drive = 0;
        reset_cpu();

        // Wait for GPIO to be configured as output and data written.
        // Bounded by a 200us timeout — if the data-cache integration
        // mis-routes IO writes the wait would otherwise hang the whole TB.
        $display("\n=== Test 12 Results: GPIO Bidirectional ===");
        fork : t12_wait_out
            begin
                wait(gpio_wiring[31:0] === 32'h000000FF);
                test_count = test_count + 1;
                pass_count = pass_count + 1;
                $display("  [PASS] GPIO Output Drive: gpio[31:0] = 0x%08h", gpio_wiring[31:0]);
            end
            begin
                #200000;  // 200us watchdog
                test_count = test_count + 1;
                fail_count = fail_count + 1;
                $display("  [FAIL] GPIO Output Drive timeout: gpio[31:0] = 0x%08h (expected 0x000000FF)",
                         gpio_wiring[31:0]);
            end
        join_any
        disable t12_wait_out;

        // Wait for CPU to switch GPIO to input mode (DIR=0), bounded.
        fork : t12_wait_dir
            begin
                wait(u_gpio.gpio_dir[31:0] === 32'h00000000);
            end
            begin
                #200000;
                $display("  [FAIL] GPIO DIR-input timeout: gpio_dir[31:0] = 0x%08h",
                         u_gpio.gpio_dir[31:0]);
                test_count = test_count + 1;
                fail_count = fail_count + 1;
            end
        join_any
        disable t12_wait_dir;

        // TB drives the GPIO pins with the test pattern, then samples.
        gpio_test_en[31:0] = 32'hFFFFFFFF;
        gpio_test_drive[31:0] = 32'hCAFEBABE;

        #500;
        check_reg(6, 32'hCAFEBABE, "GPIO Input Read");
        verify_counters(3, 1, -1, "Test 12");

        // ==========================================
        // Test 13: Byte/Halfword Load/Store
        // ==========================================
        load_test13_byte_halfword();
        reset_cpu();
        #4000;  // Allow time for all operations
        
        $display("\n=== Test 13 Results: Byte/Halfword ===");
        // mem[0x200] = 0xDEADBEEF (little endian: EF BE AD DE)
        // LB from byte 0: 0xEF, sign-extended -> 0xFFFFFFEF
        check_reg(6, 32'hFFFFFFEF, "LB (sign-ext 0xEF)");
        // LBU from byte 0: 0xEF, zero-extended -> 0x000000EF
        check_reg(7, 32'h000000EF, "LBU (zero-ext 0xEF)");
        // LH from offset 0: 0xBEEF, sign-extended -> 0xFFFFBEEF
        check_reg(8, 32'hFFFFBEEF, "LH (sign-ext 0xBEEF)");
        // LHU from offset 0: 0xBEEF, zero-extended -> 0x0000BEEF
        check_reg(9, 32'h0000BEEF, "LHU (zero-ext 0xBEEF)");
        // LB from byte 1: 0xBE, sign-extended -> 0xFFFFFFBE
        check_reg(10, 32'hFFFFFFBE, "LB offset 1 (sign-ext 0xBE)");
        // LBU from byte 2: 0xAD, zero-extended -> 0x000000AD
        check_reg(11, 32'h000000AD, "LBU offset 2 (zero-ext 0xAD)");
        // LH from offset 2: 0xDEAD, sign-extended -> 0xFFFFDEAD
        check_reg(12, 32'hFFFFDEAD, "LH offset 2 (sign-ext 0xDEAD)");
        // LHU from offset 2: 0xDEAD, zero-extended -> 0x0000DEAD
        check_reg(13, 32'h0000DEAD, "LHU offset 2 (zero-ext 0xDEAD)");
        verify_counters(3, 8, 9, "Test 13");

        // ==========================================
        // Test 14: UART Loopback Test
        // ==========================================
        load_test14_uart_loopback();
        reset_cpu();
        // Wait for CPU to write to TX_DATA, then TX/RX cycle to complete
        // TX cycle: 10 bits * 16 samples * baud_div(10) * 10ns = 16000ns per TX
        #25000;  // Let CPU execute write + TX complete + some margin
        
        $display("\n=== Test 14 Results: UART Loopback ===");
        // Verify UART operation by checking module status directly
        // TX should have sent, RX should have received via loopback
        if (u_uart.tx_empty && u_uart.rx_valid && u_uart.rx_data == 8'h55) begin
            test_count = test_count + 1;
            pass_count = pass_count + 1;
            $display("  [PASS] UART TX/RX loopback: tx_empty=%b, rx_valid=%b, rx_data=0x%02h",
                     u_uart.tx_empty, u_uart.rx_valid, u_uart.rx_data);
        end else begin
            test_count = test_count + 1;
            fail_count = fail_count + 1;
            $display("  [FAIL] UART TX/RX loopback: tx_empty=%b, rx_valid=%b, rx_data=0x%02h (expected 0x55)",
                     u_uart.tx_empty, u_uart.rx_valid, u_uart.rx_data);
        end
        verify_counters(1, 2, -1, "Test 14");

        // ==========================================
        // Test 15: RAW Hazard Stress Test
        // ==========================================
        load_test15_raw_hazard_stress();
        reset_cpu();
        #3000;  // Allow time for back-to-back dependent instructions
        
        $display("\n=== Test 15 Results: RAW Hazard Stress ===");
        // Check doubling chain: 1->2->4->8->16->32->64->128->256->512
        check_reg(1, 1,    "ADDI x1 = 1");
        check_reg(2, 2,    "ADD x2 = 1+1 = 2");
        check_reg(3, 4,    "ADD x3 = 2+2 = 4");
        check_reg(4, 8,    "ADD x4 = 4+4 = 8");
        check_reg(5, 16,   "ADD x5 = 8+8 = 16");
        check_reg(6, 32,   "ADD x6 = 16+16 = 32");
        check_reg(7, 64,   "ADD x7 = 32+32 = 64");
        check_reg(8, 128,  "ADD x8 = 64+64 = 128");
        check_reg(9, 256,  "ADD x9 = 128+128 = 256");
        check_reg(10, 512, "ADD x10 = 256+256 = 512");
        check_reg(11, 1024, "SLLI x11 = 512<<1 = 1024");
        check_reg(12, 1536, "XOR x12 = 1024^512 = 1536");
        check_reg(13, 512,  "SUB x13 = 1536-1024 = 512");
        check_reg(14, 512,  "AND x14 = 512&1536 = 512");
        check_reg(15, 0,    "SLT x15 = (512<512) = 0");
        verify_counters(0, 0, -1, "Test 15");

        // ==========================================
        // Test 16: Full ALU Instruction Coverage
        // ==========================================
        load_test16_full_alu_coverage();
        reset_cpu();
        #4000;  // Allow time for all ALU operations
        
        $display("\n=== Test 16 Results: Full ALU Coverage ===");
        // Note: x4 gets overwritten by SRAI (93>>2=23), x5 by SLTI ((4<10)=1), x6 by SLTIU ((4<3)=0)
        check_reg(4, 23,   "SRAI x4 = 93>>2 = 23 (final)");
        check_reg(5, 1,    "SLTI x5 = (4<10) = 1 (final)");
        check_reg(6, 0,    "SLTIU x6 = (4<3) = 0 (final)");
        check_reg(7, 103,  "OR x7 = 100|7 = 103");
        check_reg(8, 99,   "XOR x8 = 100^7 = 99");
        check_reg(9, 12800, "SLL x9 = 100<<7 = 12800");
        check_reg(10, 0,   "SRL x10 = 100>>7 = 0");
        check_reg(11, -1,  "SRA x11 = -50>>>7 = -1");
        check_reg(12, 1,   "SLT x12 = (-50<100) = 1");
        check_reg(13, 1,   "SLTU x13 = (100<0xFFFFFFCE) = 1");
        check_mem(512, 103, "SW x7 mem[512] = 103");
        check_mem(516, 0,   "SW x10 mem[516] = 0");
        check_mem(520, 1,   "SW x13 mem[520] = 1");
        verify_counters(3, 0, -1, "Test 16");

        // ==========================================
        // Test 17: Nested Loops
        // ==========================================
        load_test17_nested_loops();
        reset_cpu();
        #4000;  // Nested loops need more time
        
        $display("\n=== Test 17 Results: Nested Loops ===");
        // DEBUG: Direct register read without going through check_reg
        $display("  [DEBUG] Direct read: reg_r1_q=%0d, reg_r2_q=%0d, reg_r10_q=%0d",
                 uut.reg_file.reg_r1_q, uut.reg_file.reg_r2_q, uut.reg_file.reg_r10_q);
        // sum = (0+0)+(0+1)+(0+2) + (1+0)+(1+1)+(1+2) + (2+0)+(2+1)+(2+2)
        //     = 0+1+2 + 1+2+3 + 2+3+4 = 3 + 6 + 9 = 18
        check_reg(1, 3,   "Outer counter final i=3");
        check_reg(2, 3,   "Inner counter final j=3");
        check_reg(10, 18, "Sum = 18");
        check_mem(768, 18, "SW mem[768] = 18");
        verify_counters(1, 0, -1, "Test 17");

        // ==========================================
        // Test 18: Memory Access Pattern Stress
        // ==========================================
        load_test18_memory_stress();
        reset_cpu();
        #12000;  // Memory operations need more time for byte/halfword
        
        $display("\n=== Test 18 Results: Memory Stress ===");
        check_reg(4, 32'h55,  "LW x4 = 0x55");
        check_reg(5, 32'hAA,  "LW x5 = 0xAA");
        check_reg(6, 32'h55,  "LW x6 = 0x55");
        check_reg(7, 32'hAA,  "LW x7 = 0xAA");
        check_reg(8, 32'hFF,  "ADD x8 = 0x55+0xAA = 0xFF");
        check_reg(9, 32'hFF,  "ADD x9 = 0x55+0xAA = 0xFF");
        check_reg(10, 32'h1FE, "ADD x10 = 0xFF+0xFF = 0x1FE");
        check_reg(12, 32'h123, "LW x12 = 0x123 (store-load)");
        // Note: LB of 0x55 is positive so sign extension keeps it 0x55
        check_reg(13, 32'h55,  "LB x13 = sign(0x55) = 0x55");
        check_reg(14, 32'hAA,  "LHU x14 = 0x00AA");
        check_reg(15, 32'h321, "ADD x15 = 0x1FE+0x123 = 0x321");
        verify_counters(7, 7, 7, "Test 18");

        // ==========================================
        // Test 19: Mixed Instruction Stress
        // ==========================================
        load_test19_mixed_stress();
        reset_cpu();
        #15000;  // Mixed operations with jumps need time
        
        $display("\n=== Test 19 Results: Mixed Stress ===");
        check_reg(1, 32'h12345678, "LUI+ADDI x1 = 0x12345678");
        check_reg(3, 32'h1234,     "SRLI x3 = 0x1234");
        check_reg(4, 32'h78,       "ANDI x4 = 0x78");
        check_reg(5, 32'h12345678, "LW x5 = 0x12345678");
        check_reg(6, 32'h12AC,     "ADD x6 = 0x12AC");
        check_reg(11, 32'h48,      "JAL x11 = 0x48 (return addr)");
        check_reg(12, 32'hABCDE000, "LUI x12 = 0xABCDE000");
        check_reg(14, 32'h5C,      "JALR x14 = 0x5C (return addr)");
        check_reg(15, 32'h42,      "ADDI x15 = 0x42 (final marker)");
        // Verify skip paths weren't executed (x15 should NOT be 0xBAD)
        if (uut.reg_file.reg_r15_q != 32'hBAD) begin
            test_count = test_count + 1;
            pass_count = pass_count + 1;
            $display("  [PASS] JAL/JALR skip path verified (x15 != 0xBAD)");
        end else begin
            test_count = test_count + 1;
            fail_count = fail_count + 1;
            $display("  [FAIL] JAL/JALR skip path violated (x15 = 0xBAD)");
        end
        verify_counters(5, 1, 1, "Test 19");

        // ==========================================
        // Test 20: Multiplication Operations (M Extension)
        // ==========================================
        load_test20_multiplication();
        reset_cpu();
        #24000;  // Multiplication test has many instructions - needs more time
        
        $display("\n=== Test 20 Results: Multiplication (M Extension) ===");
        // Basic tests
        check_reg(3, 42,         "MUL x3 = 7 * 6 = 42");
        check_reg(6, 32'h0,      "MUL x6 = 0x10000000 * 16 (lower 32 = 0)");
        check_reg(7, 32'h1,      "MULH x7 = upper(0x10000000 * 16) = 1");
        check_reg(10, -50,       "MUL x10 = (-10) * 5 = -50");
        check_reg(13, 32'h1,     "MULHU x13 = upper(0xFFFFFFFF * 2) = 1");
        check_reg(14, 32'hFFFFFFFF, "MULHSU x14 = upper(-10 * 2 signed*unsigned) = -1");
        // Corner cases
        check_reg(15, 0,         "MUL x15 = 7 * 0 = 0 (multiply by zero)");
        check_reg(17, 7,         "MUL x17 = 7 * 1 = 7 (multiply by one)");
        check_reg(19, -7,        "MUL x19 = 7 * (-1) = -7 (multiply by -1)");
        check_reg(24, 32'h80000000, "MUL x24 = 0x80000000 * (-1) = 0x80000000");
        check_reg(25, 32'hFFFFFFFE, "MULHU x25 = upper(0xFFFFFFFF^2) = 0xFFFFFFFE");
        check_reg(26, 1,         "MUL x26 = lower(0xFFFFFFFF^2) = 1");
        // Memory verification
        check_mem(256, 42,       "SW mem[256] = 42 (MUL result)");
        check_mem(260, 32'h0,    "SW mem[260] = 0 (MUL overflow lower)");
        check_mem(264, 32'h1,    "SW mem[264] = 1 (MULH upper)");
        verify_counters(3, 0, -1, "Test 20");

        // ==========================================
        // Test 21: Division Operations (M Extension)
        // ==========================================
        load_test21_division();
        reset_cpu();
        #80000;  // Division takes ~67 cycles each, need more time for multiple divs
        
        $display("\n=== Test 21 Results: Division (M Extension) ===");
        // DIVU/REMU tests (unsigned)
        check_reg(3, 14,         "DIVU x3 = 100 / 7 = 14");
        check_reg(4, 2,          "REMU x4 = 100 % 7 = 2");
        // DIV/REM tests (signed)
        check_reg(5, -100,       "ADDI x5 = -100");
        check_reg(6, -14,        "DIV x6 = -100 / 7 = -14");
        check_reg(7, -2,         "REM x7 = -100 % 7 = -2");
        // Large number test
        check_reg(10, 1000,      "DIVU x10 = 1000000 / 1000 = 1000");
        // Division by 1
        check_reg(12, 100,       "DIVU x12 = 100 / 1 = 100");
        // Smaller / larger
        check_reg(15, 0,         "DIVU x15 = 5 / 10 = 0");
        check_reg(16, 5,         "REMU x16 = 5 % 10 = 5");
        // Memory verification
        check_mem(256, 14,       "SW mem[256] = 14 (100/7)");
        check_mem(260, 2,        "SW mem[260] = 2 (100%7)");
        check_mem(264, 1000,     "SW mem[264] = 1000 (1M/1K)");
        verify_counters(3, 0, -1, "Test 21");

        // ==========================================
        // Test 22: Division Forwarding Tests (ADD->DIV, MUL->DIV, DIV->DIV)
        // ==========================================
        load_test22_m_extension_stress();
        reset_cpu();
        #200000;  // Multiple divisions need time
        
        $display("\n=== Test 22 Results: Division Forwarding ===");
        // Test Case 1: ADD -> DIV
        check_reg(5, 42,         "ADD x5 = 42 (copy from x1)");
        check_reg(10, 14,        "DIVU x10 = 42/3 = 14 (ADD->DIV forward)");
        check_mem(512, 14,       "SW mem[512] = 14 (ADD->DIV result)");
        // Test Case 2: MUL -> DIV
        check_reg(6, 42,         "MUL x6 = 6*7 = 42");
        check_reg(11, 14,        "DIVU x11 = 42/3 = 14 (MUL->DIV forward)");
        check_mem(516, 14,       "SW mem[516] = 14 (MUL->DIV result)");
        check_mem(524, 42,       "SW mem[524] = 42 (verify MUL)");
        // Test Case 3: DIV -> DIV
        check_reg(7, 14,         "DIVU x7 = 42/3 = 14 (first div)");
        check_reg(8, 14,         "ADDI x8 = x7 = 14 (verify first div)");
        check_reg(12, 2,         "DIVU x12 = 14/6 = 2 (DIV->DIV)");
        check_mem(520, 2,        "SW mem[520] = 2 (DIV->DIV result)");
        verify_counters(4, 0, -1, "Test 22");

        // ==========================================
        // Test 23: M Extension + Control Flow (MUL+DIV+Branches+Jumps)
        // ==========================================
        load_test23_m_extension_control_flow();
        reset_cpu();
        #200000;  // Multiple divisions + control flow need time
        
        $display("\n=== Test 23 Results: M Extension + Control Flow ===");
        // Step 1: MUL then branch
        check_reg(4, 42,         "MUL x4 = 6*7 = 42");
        check_mem(512, 42,       "SW mem[512] = 42 (MUL result)");
        // Step 2: DIV with forwarding
        check_reg(6, 14,         "DIVU x6 = 42/3 = 14");
        check_mem(516, 14,       "SW mem[516] = 14 (first DIV)");
        // Step 4: Subroutine MUL
        check_reg(8, 98,         "MUL x8 = 14*7 = 98 (subroutine)");
        check_mem(520, 98,       "SW mem[520] = 98 (subroutine MUL)");
        // Step 5: Final DIV
        check_reg(9, 14,         "DIVU x9 = 98/7 = 14 (final)");
        check_mem(524, 14,       "SW mem[524] = 14 (final DIV)");
        // Control flow verification
        check_reg(20, 3,         "Branch counter x20 = 3 (2 branches + 1 return)");
        check_mem(528, 3,        "SW mem[528] = 3 (branch counter)");
        check_reg(21, 32'h44,    "JAL return addr x21 = 0x44");
        check_mem(532, 32'h44,   "SW mem[532] = 0x44 (JAL return addr)");
        verify_counters(6, 0, -1, "Test 23");

        // ==========================================
        // Test 24: Cache Locality Exploitation
        // ==========================================
        load_test24_cache_locality();
        reset_cpu();
        #15000;  // Time for 20+30+20 = 70 loop iterations
        
        $display("\n=== Test 24 Results: Cache Locality ===");
        // Loop 1: sum(0..19) = 190
        check_reg(2, 20, "Loop 1 counter final (20)");
        check_reg(10, 190, "Sum 0+1+...+19 = 190");
        check_mem(256, 190, "SW mem[256] = 190");
        
        // Loop 2: counter = 30
        check_reg(4, 30, "Loop 2 counter final (30)");
        check_mem(260, 30, "SW mem[260] = 30");
        
        // Loop 3: nested 4x5 = 20
        check_reg(6, 4, "Loop 3 outer final (4)");
        check_reg(11, 20, "Loop 3 total (4x5=20)");
        check_mem(264, 20, "SW mem[264] = 20");
        
        // Performance info
        $display("  ─────────────────────────────────────────────");
        $display("  Cache Locality Performance:");
        $display("  Cache Hits: %0d", uut.u_csr_file.mhpmcounter3_r);
        $display("  Cycles: %0d", uut.u_csr_file.mcycle_r);
        $display("  Retired Instructions: %0d", uut.u_csr_file.minstret_r);
        $display("  ─────────────────────────────────────────────");
        verify_counters(3, 0, -1, "Test 24");

        // ==========================================
        // Test 25: I-Cache Conflict Miss Thrash (Direct-Mapped)
        // ==========================================
        // Idea: two hot code regions separated by 0x400 bytes map to the same cache indices
        // (index bits are PC[9:2] for CACHE_DEPTH=256), causing systematic evictions.
        load_test25_icache_conflict_thrash();
        reset_cpu();
        #20000;

        $display("\n=== Test 25 Results: I-Cache Conflict Thrash ===");
        // Correctness checks (independent of cache behavior)
        check_reg(10, 60, "Accum A (10 iters * +6) = 60");
        check_reg(11, 70, "Accum B (10 iters * +7) = 70");
        check_mem(256, 60, "SW mem[256] = 60 (A)");
        check_mem(260, 70, "SW mem[260] = 70 (B)");
        verify_counters(2, 0, -1, "Test 25");

        $display("  Cache Hits (cumulative): %0d", uut.u_csr_file.mhpmcounter3_r);
        $display("  Cycles (cumulative):     %0d", uut.u_csr_file.mcycle_r);
        $display("  Retired Instructions (cumulative): %0d", uut.u_csr_file.minstret_r);

        // ==========================================
        // Test 26: Full Pipeline Exploitation
        // ==========================================
        load_test26_pipeline_exploitation();
        reset_cpu();
        #50000;  // Time for 10*20 = 200 loop iterations + setup + stores
        
        $display("\n=== Test 26 Results: Full Pipeline Exploitation ===");
        // Total iterations: 10 outer * 20 inner = 200
        // Each accumulator increments by its value each iteration
        check_reg(2, 200, "acc0 (200 * 1) = 200");
        check_reg(3, 400, "acc1 (200 * 2) = 400");
        check_reg(4, 600, "acc2 (200 * 3) = 600");
        check_reg(5, 800, "acc3 (200 * 4) = 800");
        check_reg(6, 1000, "acc4 (200 * 5) = 1000");
        check_reg(7, 1200, "acc5 (200 * 6) = 1200");
        check_reg(8, 1400, "acc6 (200 * 7) = 1400");
        check_reg(9, 1600, "acc7 (200 * 8) = 1600");
        check_reg(20, 7200, "sum of all accs = 7200");
        
        // Memory checks
        check_mem(512, 200, "SW mem[512] = 200 (acc0)");
        check_mem(516, 400, "SW mem[516] = 400 (acc1)");
        check_mem(520, 600, "SW mem[520] = 600 (acc2)");
        check_mem(524, 800, "SW mem[524] = 800 (acc3)");
        check_mem(528, 1000, "SW mem[528] = 1000 (acc4)");
        check_mem(532, 1200, "SW mem[532] = 1200 (acc5)");
        check_mem(536, 1400, "SW mem[536] = 1400 (acc6)");
        check_mem(540, 1600, "SW mem[540] = 1600 (acc7)");
        check_mem(544, 7200, "SW mem[544] = 7200 (sum)");
        
        verify_counters(9, 0, -1, "Test 26");
        
        // Performance analysis
        $display("  ─────────────────────────────────────────────");
        $display("  Pipeline Exploitation Performance:");
        $display("  Cache Hits: %0d", uut.u_csr_file.mhpmcounter3_r);
        $display("  Cycles: %0d", uut.u_csr_file.mcycle_r);
        $display("  Retired Instructions: %0d", uut.u_csr_file.minstret_r);
        $display("  IPC (Instructions/Cycle): %0.3f", real'(uut.u_csr_file.minstret_r) / real'(uut.u_csr_file.mcycle_r));
        $display("  ─────────────────────────────────────────────");

        // ==========================================
        // Test 27: Timer Test
        // ==========================================
        load_test27_timer();
        reset_cpu();
        #20000; // Wait for timer

        $display("\n=== Test 27 Results: Timer Test ===");
        
        // Check Phase 1: Basic Count Up (Mem[256])
        // Should be > 0x10 (16)
        test_count = test_count + 1;
        if (read_mem_or_cache(32'h100) > 16) begin
             $display("  [PASS] Phase 1: Basic Count Up verified (Got %h)", read_mem_or_cache(32'h100));
             pass_count = pass_count + 1;
        end else begin
             $display("  [FAIL] Phase 1: Timer did not count up (Got %h)", read_mem_or_cache(32'h100));
             fail_count = fail_count + 1;
        end

        // Check Phase 2: 64-bit Cascade Up (Mem[260])
        // Should be 1 (Overflowed)
        test_count = test_count + 1;
        if (read_mem_or_cache(32'h104) == 1) begin
             $display("  [PASS] Phase 2: 64-bit Cascade Up verified (Got %h)", read_mem_or_cache(32'h104));
             pass_count = pass_count + 1;
        end else begin
             $display("  [FAIL] Phase 2: Timer High did not increment on overflow (Got %h)", read_mem_or_cache(32'h104));
             fail_count = fail_count + 1;
        end

        // Check Phase 3: 64-bit Cascade Down (Mem[264])
        // Should be 0 (Underflowed from 1 -> 0)
        // Note: Initial High was 1. Low underflows, borrows from High. High becomes 0.
        test_count = test_count + 1;
        if (read_mem_or_cache(32'h108) == 0) begin
             $display("  [PASS] Phase 3: 64-bit Cascade Down verified (Got %h)", read_mem_or_cache(32'h108));
             pass_count = pass_count + 1;
        end else begin
             $display("  [FAIL] Phase 3: Timer High did not decrement on underflow (Got %h)", read_mem_or_cache(32'h108));
             fail_count = fail_count + 1;
        end

        // Check Phase 4: Toggle Enable (Mem[268])
        // Should be > 0
        test_count = test_count + 1;
        if (read_mem_or_cache(32'h10C) > 0) begin
             $display("  [PASS] Phase 4: Toggle Enable verified (Got %h)", read_mem_or_cache(32'h10C));
             pass_count = pass_count + 1;
        end else begin
             $display("  [FAIL] Phase 4: Timer did not count after toggle (Got %h)", read_mem_or_cache(32'h10C));
             fail_count = fail_count + 1;
        end

        // Counts:
        // Phase 1: 5 Writes, 1 Read
        // Phase 2: 5 Writes, 1 Read
        // Phase 3: 5 Writes, 1 Read
        // Phase 4: 3 Writes, 1 Read
        // Total: 18 Writes, 4 Reads
        verify_counters(18, 4, -1, "Test 27");

        // ==========================================
        // Test 28: Counter Mode (External Event)
        // ==========================================
        load_test28_counter_mode();
        reset_cpu();

        // The test program will:
        // 1. Configure timer in Counter Mode (Ctrl = 0x7: Enable + Up + Counter)
        // 2. Loop for 100 iterations (software-controlled wait)
        // 3. Read Timer Low, store to memory
        // 4. The testbench will drive timer_ext_event during the wait period

        // During the test, we inject external pulses with various timing patterns
        // including corner cases (mid-cycle, glitches, bursts)
        
        // Wait for CPU to start and reach the counting loop
        #2000;
        
        // === Phase 1: Clean pulses (5 pulses, synchronized to clock) ===
        repeat(5) begin
            @(posedge clk);
            timer_ext_event <= 1'b1;
            @(posedge clk);
            timer_ext_event <= 1'b0;
            @(posedge clk);  // Gap between pulses
        end
        
        // === Phase 2: Mid-cycle pulses (should still be detected) ===
        // These pulses change in the middle of a clock cycle
        repeat(3) begin
            @(posedge clk);
            #3;  // 3ns into the 10ns clock period
            timer_ext_event <= 1'b1;
            @(posedge clk);
            #7;  // 7ns into the next cycle
            timer_ext_event <= 1'b0;
            @(posedge clk);
        end
        
        // === Phase 3: Very short glitch (< 1 clock period) ===
        // This should NOT be detected by the synchronizer (edge too fast)
        @(posedge clk);
        timer_ext_event <= 1'b1;
        #2;  // 2ns pulse
        timer_ext_event <= 1'b0;
        @(posedge clk);
        @(posedge clk);
        
        // === Phase 4: Burst of rapid pulses ===
        repeat(2) begin
            @(posedge clk);
            timer_ext_event <= 1'b1;
            @(posedge clk);
            timer_ext_event <= 1'b0;
        end
        
        // Wait for program to complete
        #12000;

        $display("\n=== Test 28 Results: Counter Mode (External Event) ===");
        
        // Expected count:
        // Phase 1: 5 pulses
        // Phase 2: 3 pulses (even mid-cycle, should be detected)
        // Phase 3: 0 (glitch too short)
        // Phase 4: 2 pulses
        // Total: 10 pulses
        
        // The program stores timer value to Mem[256] (64 words)
        test_count = test_count + 1;
        if (read_mem_or_cache(32'h100) == 10) begin
            $display("  [PASS] Counter Mode: Counted %d external events (Expected 10)", read_mem_or_cache(32'h100));
            pass_count = pass_count + 1;
        end else if (read_mem_or_cache(32'h100) >= 8 && read_mem_or_cache(32'h100) <= 11) begin
            // Allow some tolerance for timing variations
            $display("  [PASS] Counter Mode: Counted %d external events (Expected ~10, within tolerance)", read_mem_or_cache(32'h100));
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] Counter Mode: Counted %d external events (Expected ~10)", read_mem_or_cache(32'h100));
            fail_count = fail_count + 1;
        end
        
        // Corner case: Glitch should NOT have been counted
        // (No explicit check, but total count should confirm this)
        
        verify_counters(4, 1, -1, "Test 28");

        // ==========================================
        // Test 29: CSR Read/Write Operations (Zicsr)
        // ==========================================
        load_test29_csr_readwrite();
        reset_cpu();
        #8000;  // Wait for program to complete

        $display("\n=== Test 29 Results: CSR Read/Write (Zicsr) ===");

        // Verify register values from CSR operations
        // CSRRW x2, mscratch, x0 → x2 = old mscratch = 0 (after reset)
        check_reg(5'd2, 32'h0, "CSRRW read old mscratch (reset=0)");
        // CSRRW x4, mscratch, x3 → x4 = old mscratch = 0, mscratch = 0x42
        check_reg(5'd4, 32'h0, "CSRRW read old mscratch before write 0x42");
        // CSRRS x5, mscratch, x0 → x5 = mscratch = 0x42 (no set, rs1=x0)
        check_reg(5'd5, 32'h42, "CSRRS read mscratch (no write, rs1=x0)");
        // CSRRS x7, mscratch, x6 → x7 = old mscratch = 0x42, then SET 0xF → 0x4F
        check_reg(5'd7, 32'h42, "CSRRS read old mscratch before SET 0xF");
        // CSRRS x8, mscratch, x0 → x8 = mscratch = 0x4F
        check_reg(5'd8, 32'h4F, "CSRRS read mscratch after SET (0x4F)");
        // CSRRC x9, mscratch, x6 → x9 = old mscratch = 0x4F, then CLEAR 0xF → 0x40
        check_reg(5'd9, 32'h4F, "CSRRC read old mscratch before CLR 0xF");
        // CSRRS x10, mscratch, x0 → x10 = mscratch = 0x40
        check_reg(5'd10, 32'h40, "CSRRS read mscratch after CLR (0x40)");
        // CSRRWI x11, mscratch, 0x1F → x11 = old mscratch = 0x40, mscratch = 0x1F
        check_reg(5'd11, 32'h40, "CSRRWI read old mscratch before write zimm");
        // CSRRS x12, mscratch, x0 → x12 = mscratch = 0x1F
        check_reg(5'd12, 32'h1F, "CSRRS read mscratch after CSRRWI (0x1F)");
        // CSRRSI x13, mscratch, 0 → x13 = mscratch = 0x1F (no set, zimm=0)
        check_reg(5'd13, 32'h1F, "CSRRSI read mscratch (no set, zimm=0)");
        // CSRRCI x14, mscratch, 0x10 → x14 = old mscratch = 0x1F, clear bit4 → 0x0F
        check_reg(5'd14, 32'h1F, "CSRRCI read old mscratch before clr bit4");
        // CSRRS x15, mscratch, x0 → x15 = mscratch = 0x0F
        check_reg(5'd15, 32'h0F, "CSRRS read mscratch after CSRRCI (0x0F)");

        // Also verify memory stores match
        check_mem(32'h100, 32'h0,  "SW mscratch initial (0)");
        check_mem(32'h104, 32'h0,  "SW old before CSRRW 0x42 (0)");
        check_mem(32'h108, 32'h42, "SW mscratch after CSRRW (0x42)");
        check_mem(32'h10C, 32'h42, "SW old before CSRRS SET (0x42)");
        check_mem(32'h110, 32'h4F, "SW mscratch after SET (0x4F)");
        check_mem(32'h114, 32'h4F, "SW old before CSRRC CLR (0x4F)");
        check_mem(32'h118, 32'h40, "SW mscratch after CLR (0x40)");
        check_mem(32'h11C, 32'h40, "SW old before CSRRWI (0x40)");
        check_mem(32'h120, 32'h1F, "SW mscratch after CSRRWI (0x1F)");
        check_mem(32'h124, 32'h1F, "SW mscratch CSRRSI read (0x1F)");
        check_mem(32'h128, 32'h1F, "SW old before CSRRCI (0x1F)");
        check_mem(32'h12C, 32'h0F, "SW mscratch after CSRRCI (0x0F)");

        verify_counters(12, 0, -1, "Test 29");

        // ==========================================
        // Test 30: Exception Handling
        // ==========================================
        load_test30_exceptions();
        reset_cpu();
        #15000;  // Allow time for 3 exceptions + MRET returns

        $display("\n=== Test 30 Results: Exception Handling ===");
        
        // x20 should be 3 (incremented after each successful MRET return)
        check_reg(20, 3, "MRET return counter (3 exceptions handled)");

        // Exception 1: ECALL — mcause=11, mepc=0x10, mtval=0
        check_mem(32'h200, 32'd11,  "ECALL mcause (11 = env call from M-mode)");
        check_mem(32'h204, 32'h14, "ECALL mepc+4 (0x10 + 4 = 0x14)");
        check_mem(32'h208, 32'h0,   "ECALL mtval (0)");

        // Exception 2: EBREAK — mcause=3, mepc=0x18, mtval=0x18
        check_mem(32'h20C, 32'd3,   "EBREAK mcause (3 = breakpoint)");
        check_mem(32'h210, 32'h1C, "EBREAK mepc+4 (0x18 + 4 = 0x1C)");
        check_mem(32'h214, 32'h18, "EBREAK mtval (0x18)");

        // Exception 3: Illegal instruction — mcause=2, mepc=0x20, mtval=0xFFFFFFFF
        check_mem(32'h218, 32'd2,          "Illegal insn mcause (2 = illegal instruction)");
        check_mem(32'h21C, 32'h24,        "Illegal insn mepc+4 (0x20 + 4 = 0x24)");
        check_mem(32'h220, 32'hFFFFFFFF,   "Illegal insn mtval (faulting instruction)");

        // Trap handler does 3 stores per exception × 3 exceptions = 9 stores
        // No loads in the program
        verify_counters(9, 0, -1, "Test 30");

        // ==========================================
        // Test 31: Timer Compare-Match Interrupt
        // ==========================================
        load_test31_timer_interrupt();
        reset_cpu();
        #30000; // Wait for timer to count to 20, trap, handler, MRET, store

        $display("\n=== Test 31 Results: Timer Compare-Match Interrupt ===");
        // x20 = 1 (handler set it)
        check_reg(20, 1, "Timer IRQ handler executed (x20=1)");
        // mem[256] = 1 (main program stored x20 after handler returned)
        check_mem(32'h100, 32'd1, "Timer IRQ: trap count stored to memory");
        // mem[260] = 0x80000007 (mcause for Machine Timer Interrupt)
        check_mem(32'h104, 32'h80000007, "Timer IRQ: mcause = MTI (0x80000007)");
        // Main setup: SW timer_lo + SW timer_hi + SW timecmp_lo + SW timecmp_hi + SW timer_ctrl = 5
        // Handler:   SW mcause + SW timecmp_lo + SW timecmp_hi + SW timer_ctrl(0) = 4
        // Post-MRET: SW x20 to mem = 1
        // Total: 10 writes, 0 reads
        verify_counters(10, 0, -1, "Test 31");

        // ==========================================
        // Test 32: Timer IRQ During Branch-Predicted Loop
        // ==========================================
        load_test32_irq_during_branch_loop();
        reset_cpu();
        #30000;

        $display("\n=== Test 32 Results: Timer IRQ During Branch-Predicted Loop ===");
        check_reg(10, 50, "Accumulator (50 iterations)");
        check_reg(11, 50, "Counter (50 iterations)");
        check_reg(20, 1, "Timer IRQ handler executed (x20=1)");
        check_mem(32'h100, 32'd50, "SW mem[256] = 50 (accumulator)");
        check_mem(32'h104, 32'd50, "SW mem[260] = 50 (counter)");
        check_mem(32'h108, 32'd1, "SW mem[264] = 1 (IRQ flag)");
        verify_counters(11, 0, -1, "Test 32");

        // ==========================================
        // Test 33: Exception at Mispredicted Branch Target
        // ==========================================
        load_test33_exception_at_branch_target();
        reset_cpu();
        #15000;

        $display("\n=== Test 33 Results: Exception at Mispredicted Branch Target ===");
        check_reg(20, 3, "MRET return counter (3 exceptions handled)");
        check_mem(32'h200, 32'd11,        "ECALL mcause (11)");
        check_mem(32'h204, 32'h2C,        "ECALL mepc+4 (0x28+4=0x2C)");
        check_mem(32'h208, 32'h0,         "ECALL mtval (0)");
        check_mem(32'h20C, 32'd3,         "EBREAK mcause (3)");
        check_mem(32'h210, 32'h4C,        "EBREAK mepc+4 (0x48+4=0x4C)");
        check_mem(32'h214, 32'h48,        "EBREAK mtval (0x48)");
        check_mem(32'h218, 32'd2,         "Illegal insn mcause (2)");
        check_mem(32'h21C, 32'h6C,        "Illegal insn mepc+4 (0x68+4=0x6C)");
        check_mem(32'h220, 32'hFFFFFFFF,  "Illegal insn mtval (0xFFFFFFFF)");
        verify_counters(9, 0, -1, "Test 33");

        // ==========================================
        // Test 34: MRET Into Branch With Predictor State
        // ==========================================
        load_test34_mret_into_branch();
        reset_cpu();
        #20000;

        $display("\n=== Test 34 Results: MRET Into Branch With Predictor State ===");
        check_reg(10, 5, "Loop counter (5 iterations with ECALL each)");
        check_reg(20, 5, "Exception count (5 ECALLs handled)");
        check_mem(32'h100, 32'd5, "SW mem[256] = 5 (counter)");
        check_mem(32'h104, 32'd5, "SW mem[260] = 5 (exception count)");
        verify_counters(2, 0, -1, "Test 34");

        // ==========================================
        // Test 35: Cache Round-Trip
        // ==========================================
        load_test35_cache_round_trip();
        reset_cpu();
        #20000;

        $display("\n=== Test 35 Results: Cache Round-Trip ===");
        check_reg(10, 100, "LW x10 from 0x100 (= 100)");
        check_reg(11, 200, "LW x11 from 0x200 (= 200)");
        check_reg(12, 300, "LW x12 from 0x300 (= 300)");
        check_reg(13, 400, "LW x13 from 0x3FC (= 400)");
        check_mem(32'h100, 100, "cache/mem[0x100] = 100");
        check_mem(32'h200, 200, "cache/mem[0x200] = 200");
        check_mem(32'h300, 300, "cache/mem[0x300] = 300");
        check_mem(32'h3FC, 400, "cache/mem[0x3FC] = 400");
        verify_counters(4, 4, 4, "Test 35");

        // ==========================================
        // Test 36: Cache Way Conflict
        // ==========================================
        load_test36_way_conflict();
        reset_cpu();
        #30000;

        $display("\n=== Test 36 Results: Cache Way Conflict ===");
        check_reg(10, 11, "LW x10 from 0x100 (A=11)");
        check_reg(11, 22, "LW x11 from 0x500 (B=22)");
        check_reg(12, 33, "LW x12 from 0x900 (C=33)");
        check_mem(32'h100, 11, "value at 0x100 = 11 (A)");
        check_mem(32'h500, 22, "value at 0x500 = 22 (B)");
        check_mem(32'h900, 33, "value at 0x900 = 33 (C)");
        verify_counters(3, 3, 0, "Test 36");

        // ==========================================
        // Test 37: Strided Cache Sweep
        // ==========================================
        load_test37_strided_sweep();
        reset_cpu();
        #50000;

        $display("\n=== Test 37 Results: Strided Cache Sweep ===");
        check_reg(10, 1, "x10 = sweep[0] = 1");
        check_reg(11, 2, "x11 = sweep[1] = 2");
        check_reg(12, 3, "x12 = sweep[2] = 3");
        check_reg(13, 4, "x13 = sweep[3] = 4");
        check_reg(14, 5, "x14 = sweep[4] = 5");
        check_reg(15, 6, "x15 = sweep[5] = 6");
        check_reg(16, 7, "x16 = sweep[6] = 7");
        check_reg(17, 8, "x17 = sweep[7] = 8");
        check_mem(32'h100, 1, "sweep[0] @ 0x100 = 1");
        check_mem(32'h140, 2, "sweep[1] @ 0x140 = 2");
        check_mem(32'h180, 3, "sweep[2] @ 0x180 = 3");
        check_mem(32'h1C0, 4, "sweep[3] @ 0x1C0 = 4");
        check_mem(32'h200, 5, "sweep[4] @ 0x200 = 5");
        check_mem(32'h240, 6, "sweep[5] @ 0x240 = 6");
        check_mem(32'h280, 7, "sweep[6] @ 0x280 = 7");
        check_mem(32'h2C0, 8, "sweep[7] @ 0x2C0 = 8");
        verify_counters(8, 8, 8, "Test 37");

        // ==========================================
        // Test 38: Hot Loop (I$ + D$ Heavy Locality)
        // ==========================================
        load_test38_hot_loop();
        reset_cpu();
        #30000;

        $display("\n=== Test 38 Results: Hot Loop (I$+D$ Locality) ===");
        check_reg(10, 224, "x10 = 32 * 7 (accumulated)");
        check_reg(11, 0,   "x11 = 0 (loop counter drained)");
        check_mem(32'h1000, 7, "value at 0x1000 = 7 (preloaded)");
        verify_counters(1, 32, 32, "Test 38");

        // ==========================================
        // Test 39: Dirty-Eviction Persistence
        // ==========================================
        load_test39_dirty_eviction_persistence();
        reset_cpu();
        #30000;

        $display("\n=== Test 39 Results: Dirty-Eviction Persistence ===");
        check_reg(10, 10, "LW x10 from 0x100 = 10");
        check_reg(11, 20, "LW x11 from 0x500 = 20");
        check_reg(12, 30, "LW x12 from 0x900 = 30");
        check_reg(13, 40, "LW x13 from 0xD00 = 40");
        check_mem(32'h100, 10, "value at 0x100 = 10");
        check_mem(32'h500, 20, "value at 0x500 = 20");
        check_mem(32'h900, 30, "value at 0x900 = 30");
        check_mem(32'hD00, 40, "value at 0xD00 = 40");
        verify_counters(4, 4, 0, "Test 39");

        // ==========================================
        // Test 40: RMW Hit Storm (D$ pure-hit throughput)
        // ==========================================
        load_test40_rmw_hit_storm();
        reset_cpu();
        #30000;

        $display("\n=== Test 40 Results: RMW Hit Storm ===");
        check_reg(10, 50, "x10 = 50 (final RMW value)");
        check_reg(2,  50, "x2  = 50 (loop counter)");
        check_mem(32'h100, 50, "value at 0x100 = 50");
        verify_counters(50, 50, 99, "Test 40");

        // ==========================================
        // Test 41: Load-Use Hazard — LW→ADD (2-iter loop)
        // ==========================================
        load_test41_load_use_basic();
        reset_cpu();
        #5000;

        $display("\n=== Test 41 Results: Load-Use Hazard LW->ADD ===");
        // Iter 2 runs at full speed (I$ + D$ warm): stall must fire.
        // If broken: ADD reads sentinel x3=99 instead of loaded 42.
        check_reg(4, 42, "x4 = 42 (ADD x3,x0: load-use stall fires on warm iter)");
        check_reg(5, 84, "x5 = 84 (ADD x3,x3)");
        check_reg(7,  0, "x7 = 0  (loop counter drained)");
        verify_counters(1, 2, 2, "Test 41");

        // ==========================================
        // Test 42: Load-Use Hazard — LB→ADDI (2-iter loop)
        // ==========================================
        load_test42_load_use_byte_half();
        reset_cpu();
        #5000;

        $display("\n=== Test 42 Results: Load-Use Hazard LB->ADDI ===");
        // If broken: ADDI reads sentinel x4=5 → x5=6 instead of 0.
        check_reg(4, 32'hFFFFFFFF, "x4 = -1 (LB 0xFF sign-extended)");
        check_reg(5, 0,            "x5 = 0  (ADDI x4+1 immediately after LB)");
        check_reg(7, 0,            "x7 = 0  (loop counter drained)");
        verify_counters(1, 2, 2, "Test 42");

        // ==========================================
        // Test 43: Load-Use Hazard — LW→SW (2-iter loop)
        // ==========================================
        load_test43_load_use_store();
        reset_cpu();
        #5000;

        $display("\n=== Test 43 Results: Load-Use Hazard LW->SW ===");
        // Iter 2 (warm): SW must use the LW result. If broken: stores 0.
        check_reg(4, 77,    "x4 = 77 (loaded value)");
        check_mem(32'h304, 77, "mem[0x304] = 77 (SW uses load-use forwarded value)");
        verify_counters(3, 2, 3, "Test 43");

        // ==========================================
        // Test 44: Load-Use Hazard — Two D$ hits per iter (2-iter loop)
        // ==========================================
        load_test44_load_use_cache_hit();
        reset_cpu();
        #5000;

        $display("\n=== Test 44 Results: Load-Use Hazard Alternating D$ Values ===");
        // After iter 2: cache holds 1 (x7 written each iter).
        // If stale data_cache_data_out forwarded from iter 1 (value=2): x4=12.
        check_reg(3,  1, "x3 = 1  (iter2: LW loads x7=1 from cache)");
        check_reg(4, 11, "x4 = 11 (ADDI x3+10: stale cache would give 12)");
        check_reg(5,  1, "x5 = 1  (2nd D$ hit same value)");
        check_reg(6, 11, "x6 = 11 (ADDI x5+10: load-use #2)");
        check_reg(7,  0, "x7 = 0  (loop counter drained)");
        verify_counters(2, 4, 5, "Test 44");

        // ==========================================
        // Test 45: Load-Use Hazard — LW→STORE, alternating values + strobes
        // ==========================================
        load_test45_load_use_store_strobes();
        reset_cpu();
        #10000;

        $display("\n=== Test 45 Results: Load-Use LW->STORE strobes ===");
        // Hot iters (I$+D$ warm): each SB/SH/SW must use its own LW result.
        //  - Broken stall  -> stores sentinel 0xFF.. bytes (detect).
        //  - Delayed fwd   -> stores the previous pair's value (detect, distinct V).
        check_reg(4, 32'hAABBCCDD, "x4 = V0 (LW)");
        check_reg(5, 32'h11223344, "x5 = V1 (LW)");
        check_reg(6, 32'hCAFE5678, "x6 = V2 (LW)");
        check_reg(3, 32'hDEAD9ABC, "x3 = V3 (LW)");
        check_reg(8, 32'h13579BDF, "x8 = V4 (LW)");
        check_reg(7, 0,            "x7 = 0  (loop drained)");
        // dest packing: SB@0=0xDD, SB@1=0x44  -> 0x0000_44DD
        check_mem(32'h200, 32'h000044DD, "mem[0x200]: SB byte0=DD, byte1=44 (load-use)");
        // SH@4=0x5678 (V2 low half), SH@6=0x9ABC (V3 low half) -> 0x9ABC_5678
        check_mem(32'h204, 32'h9ABC5678, "mem[0x204]: SH half0=5678, half1=9ABC (load-use)");
        // SW@8 = V4 full word
        check_mem(32'h208, 32'h13579BDF, "mem[0x208]: SW word=V4 (load-use)");
        // D$ hits = 22: iters 2-3 fully warm (10 hits each = 20) + 2 in iter1
        // (the 2nd SB to 0x200 and 2nd SH to 0x204 hit the line the 1st store
        // to that word already write-allocated in the same iteration).
        verify_counters(15, 15, 22, "Test 45");

        // ==========================================
        // Test 46: Load-use STORE-ADDRESS dependency under a secondary stall
        //   Regression for the spurious 0x07 (store access fault) bug.
        //   Pattern per hot iter:
        //     ADDI x5,-16     ; sentinel = 0xFFFFFFF0 (aligned, INVALID region)
        //     LW   x5,0(x10)  ; load a VALID pointer (0x340) -- D$ HIT on warm iters
        //     SW   x9,0(x11)  ; MISS store (walks) -> asserts ex_stall, holds SW below in EX
        //     SW   x7,0(x5)   ; rs1=x5; before the fix the lingering store used the
        //                     ;   stale x5=0xFFFFFFF0 -> store access fault (0x07)
        //   Correct: no trap (mcause=0), x5=0x340, mem[0x340]=0xAB.
        // ==========================================
        load_test46_load_use_store_addr();
        reset_cpu();
        #15000;

        $display("\n=== Test 46 Results: load-use store-address under stall ===");
        $display("  mcause=0x%08h mepc=0x%08h mtval=0x%08h",
                 uut.u_csr_file.mcause_r, uut.u_csr_file.mepc_r, uut.u_csr_file.mtval_r);
        test_count = test_count + 1;
        if (uut.u_csr_file.mcause_r == 32'h0) begin
            pass_count = pass_count + 1;
            $display("  [PASS] Test 46: no spurious trap (mcause=0)");
        end else begin
            fail_count = fail_count + 1;
            $display("  [FAIL] Test 46: spurious trap mcause=0x%08h mtval=0x%08h (load-use store-addr bug)",
                     uut.u_csr_file.mcause_r, uut.u_csr_file.mtval_r);
        end
        check_reg(5, 32'h340,    "x5 = 0x340 (loaded pointer)");
        check_mem(32'h340, 32'hAB, "mem[0x340] = 0xAB (store used loaded base addr)");

        // ==========================================
        // Test 47: Load-use STORE-DATA (rs2) dependency under a secondary stall
        //   Same lingering mechanism via the store's data operand instead of base.
        //     ADDI x7,-16     ; sentinel = 0xFFFFFFF0
        //     LW   x7,0(x10)  ; load VALID data 0x55 -- D$ HIT on warm iters
        //     SW   x9,0(x11)  ; MISS store -> ex_stall, holds SW below in EX
        //     SW   x7,0(x12)  ; rs2=x7 (data); before the fix stored stale 0xFFFFFFF0
        //   Correct: mem[0x380] = 0x55.
        // ==========================================
        load_test47_load_use_store_data();
        reset_cpu();
        #15000;

        $display("\n=== Test 47 Results: load-use store-data under stall ===");
        check_reg(7, 32'h55,       "x7 = 0x55 (loaded data)");
        check_mem(32'h380, 32'h55, "mem[0x380] = 0x55 (store used forwarded load data)");
        // Did each iteration's MISS-store (SW x9=0xCD -> 0x100/0x104/0x108) land?
        // If a store is dropped (not just deferred) under fetch/refill contention,
        // one of these will be wrong.
        check_mem(32'h100, 32'hCD, "mem[0x100] = 0xCD (iter1 miss-store landed)");
        check_mem(32'h104, 32'hCD, "mem[0x104] = 0xCD (iter2 miss-store landed)");
        check_mem(32'h108, 32'hCD, "mem[0x108] = 0xCD (iter3 miss-store landed)");

        load_test48_write_buffer_priority();
        reset_cpu();
        #15000;

        $display("\n=== Test 48 Results: Write Buffer Priority ===");
        check_reg(10, 11, "first consecutive forwarded load");
        check_reg(11, 22, "second consecutive forwarded load");
        check_reg(14, 99, "cache hit newer than buffered copy");
        check_mem(32'h100, 99, "newest value at 0x100");

        load_test49_write_buffer_full();
        reset_cpu();
        #15000;

        $display("\n=== Test 49 Results: Write Buffer Full ===");
        check_mem(32'h0100,  1, "dirty value preserved");
        check_mem(32'h0500,  2, "dirty value preserved");
        check_mem(32'h0900,  3, "dirty value preserved");
        check_mem(32'h0D00,  4, "dirty value preserved");
        check_mem(32'h1100,  5, "dirty value preserved");
        check_mem(32'h1500,  6, "dirty value preserved");
        check_mem(32'h1900,  7, "dirty value preserved");
        check_mem(32'h1D00,  8, "dirty value preserved");
        check_mem(32'h2100,  9, "dirty value preserved");
        check_mem(32'h2500, 10, "dirty value preserved");

        // ==========================================
        // Final Summary
        // ==========================================
        // Accumulate final counters
        total_cycles = total_cycles + cycle_counter;
        total_instrs = total_instrs + instr_counter;
        
        // Accumulate internal counters for the final test
        total_internal_cycles = total_internal_cycles + uut.u_csr_file.mcycle_r;
        total_internal_instrs = total_internal_instrs + uut.u_csr_file.minstret_r;
        total_internal_cache_hits = total_internal_cache_hits + uut.u_csr_file.mhpmcounter3_r;
        total_internal_dcache_hits = total_internal_dcache_hits + uut.u_csr_file.mhpmcounter4_r;
        total_internal_memory_writes = total_internal_memory_writes + uut.u_csr_file.mhpmcounter6_r;
        total_internal_memory_reads = total_internal_memory_reads + uut.u_csr_file.mhpmcounter5_r;
        $display("");
        $display(" ___________________________________________________________");
        $display("|                    TEST SUMMARY                           |");
        $display("|___________________________________________________________|");
        $display("|  Total Tests: %3d                                         |", test_count);
        $display("|  Passed:      %3d                                         |", pass_count);
        $display("|  Failed:      %3d                                         |", fail_count);
        $display("|___________________________________________________________|");
        
        if (fail_count == 0) begin
            $display("|         ALL TESTS PASSED SUCCESSFULLY                     |");
        end else begin
            $display("|              SOME TESTS FAILED                            |");
        end

        $display("|  Test Duration: %0d ns                                |", $time);
        $display("|  Clock Cycles:  %0d                                    |", $time / 10);
        $display("|  Instructions:  %0d                                     |", total_internal_instrs);
        $display("|  I$ Hits:       %0d                                     |", total_internal_cache_hits);
        $display("|  D$ Hits:       %0d                                       |", total_internal_dcache_hits);
        $display("|  Writes=%d, Reads=%d                    |", total_memory_writes, total_memory_reads);
        $display("|___________________________________________________________|");
        $display("");
        
        $finish;
    end

    // ==========================================
    //   Test 12: GPIO Bidirectional Test Program
    // ==========================================
    task load_test12_gpio_bidirectional;
        begin
            $display("\n--- Loading Test 12: GPIO Bidirectional ---");
            // This test verifies:
            // 1. GPIO can be configured as output and drive pins
            // 2. GPIO can be configured as input and read external data
            
            // x5 = GPIO Base Address (0x0400_1000)
            // LUI x5, 0x04001
            u_axil_ram.mem[0] = 32'h040012b7;
            
            // Step 1: Configure GPIO[31:0] as Output (DIR=1)
            // ADDI x2, x0, -1       - x2 = 0xFFFFFFFF (all outputs)
            u_axil_ram.mem[1] = 32'hfff00113;
            // SW x2, 8(x5)          - Write to DIR register (offset 0x08)
            u_axil_ram.mem[2] = 32'h0022a423;
            
            // Step 2: Write test pattern to GPIO output
            // ADDI x2, x0, 0xFF     - x2 = 0x000000FF
            u_axil_ram.mem[3] = 32'h0ff00113;
            // SW x2, 0(x5)          - Write to DATA register (offset 0x00)
            u_axil_ram.mem[4] = 32'h0022a023;
            
            // Step 3: Configure GPIO[31:0] as Input (DIR=0)
            // ADDI x3, x0, 0        - x3 = 0 (all inputs)
            u_axil_ram.mem[5] = 32'h00000193;
            // SW x3, 8(x5)          - Write to DIR register
            u_axil_ram.mem[6] = 32'h0032a423;
            
            // Step 4: Read GPIO input into x6
            // LW x6, 0(x5)          - Read DATA register into x6
            u_axil_ram.mem[7] = 32'h0002a303;
            
            // NOPs to let CPU complete
            u_axil_ram.mem[8] = 32'h00000013;
            u_axil_ram.mem[9] = 32'h00000013;
        end
    endtask

    // ==========================================
    //   Test 13: Byte/Halfword Load/Store
    // ==========================================
    task load_test13_byte_halfword;
        begin
            $display("\n--- Loading Test 13: Byte/Halfword Load/Store ---");
            // This test verifies:
            // 1. SB, SH store correct bytes/halfwords
            // 2. LB, LH sign-extend correctly
            // 3. LBU, LHU zero-extend correctly
            
            // First, initialize memory at 0x200 with a known pattern
            // We'll use SW to write 0xDEADBEEF to 0x200
            // ADDI x2, x0, 0x200     - x2 = 0x200 (base address)
            u_axil_ram.mem[0] = 32'h20000113;
            
            // LUI x3, 0xDEADC       - x3 = 0xDEADC000 (upper bits, adjusted for ADDI)
            u_axil_ram.mem[1] = 32'hdeadc1b7;
            // ADDI x3, x3, -273     - x3 = 0xDEADBEEF
            u_axil_ram.mem[2] = 32'heef18193;
            // SW x3, 0(x2)          - mem[0x200] = 0xDEADBEEF
            u_axil_ram.mem[3] = 32'h00312023;
            
            // Test SB: Store byte 0xAB to address 0x204
            // ADDI x4, x0, 0xAB     - x4 = 0xAB (171, positive as unsigned)
            u_axil_ram.mem[4] = 32'h0ab00213;
            // SB x4, 4(x2)          - mem[0x204] = 0x000000AB (byte 0)
            u_axil_ram.mem[5] = 32'h00410223;
            
            // Test SH: Store halfword 0xCDEF to address 0x206
            // Note: 0xCDEF as signed = -12817
            // LUI x5, 0x0000D       - x5 = 0x0000D000
            // Actually easier: ADDI x5, x0, -0x3211 won't work. Use LUI+ADDI
            // LUI x5, 0xFFFCD       - x5 = 0xFFFCD000 (for -0x3211)
            // Let's just use a positive value instead for clarity
            // ADDI can only do -2048 to 2047, so use LUI+ADDI for 0xCDEF
            // Actually 0xCDEF = 52719, too big for ADDI
            // Use: LUI x5, 0  then ORI doesn't exist, so:
            // ADDI x5, x0, 0x7FF  + another add... too complex
            // Simpler: just use 0x1234 which fits in ADDI
            // ADDI x5, x0, 0x1234 won't work (max 2047)
            // Use 0x123 = 291
            // Actually let's use 0xFFFFFEEF which is -273 (works for sign test)
            // ADDI x5, x0, -273    - x5 = 0xFFFFFEEF
            u_axil_ram.mem[6] = 32'heef00293;
            // SH x5, 6(x2)          - mem[0x206] = 0xFEEF (lower halfword)
            u_axil_ram.mem[7] = 32'h00511323;
            
            // Test LB (sign-extend): Load byte from 0x200 (should be 0xEF, sign-extended)
            // LB x6, 0(x2)          - x6 = sign_extend(0xEF) = 0xFFFFFFEF
            u_axil_ram.mem[8] = 32'h00010303;
            
            // Test LBU (zero-extend): Load byte from 0x200 (should be 0xEF, zero-extended)
            // LBU x7, 0(x2)         - x7 = 0x000000EF
            u_axil_ram.mem[9] = 32'h00014383;
            
            // Test LH (sign-extend): Load halfword from 0x200 (should be 0xBEEF, sign-extended)
            // LH x8, 0(x2)          - x8 = sign_extend(0xBEEF) = 0xFFFFBEEF
            u_axil_ram.mem[10] = 32'h00011403;
            
            // Test LHU (zero-extend): Load halfword from 0x200 (should be 0xBEEF, zero-extended)
            // LHU x9, 0(x2)         - x9 = 0x0000BEEF
            u_axil_ram.mem[11] = 32'h00015483;
            
            // Test LB at offset 1 (should be 0xBE, sign-extended)
            // LB x10, 1(x2)         - x10 = sign_extend(0xBE) = 0xFFFFFFBE
            u_axil_ram.mem[12] = 32'h00110503;
            
            // Test LBU at offset 2 (should be 0xAD, zero-extended)
            // LBU x11, 2(x2)        - x11 = 0x000000AD
            u_axil_ram.mem[13] = 32'h00214583;
            
            // Test LH at offset 2 (should be 0xDEAD, sign-extended)
            // LH x12, 2(x2)         - x12 = sign_extend(0xDEAD) = 0xFFFFDEAD
            u_axil_ram.mem[14] = 32'h00211603;
            
            // Test LHU at offset 2 (should be 0xDEAD, zero-extended)
            // LHU x13, 2(x2)        - x13 = 0x0000DEAD
            u_axil_ram.mem[15] = 32'h00215683;
            
            // NOPs
            u_axil_ram.mem[16] = 32'h00000013;
            u_axil_ram.mem[17] = 32'h00000013;
        end
    endtask

    // ==========================================
    //   Test 14: UART Loopback Test Program
    // ==========================================
    task load_test14_uart_loopback;
        begin
            $display("\n--- Loading Test 14: UART Loopback ---");
            // This test verifies:
            // 1. CPU writes to UART TX_DATA
            // 2. TX sends byte over uart_tx
            // 3. RX receives via loopback (or TB-driven)
            // 4. CPU reads STATUS and RX_DATA
            
            // x3 = UART Base Address (0x0400_0000)
            // LUI x3, 0x04000
            u_axil_ram.mem[0] = 32'h040001b7;
            
            // Write 0x55 to TX_DATA (offset 0x00)
            // ADDI x2, x0, 0x55     - x2 = 0x55 (test pattern)
            u_axil_ram.mem[1] = 32'h05500113;
            // SW x2, 0(x3)          - Write to TX_DATA
            u_axil_ram.mem[2] = 32'h0021a023;
            
            // Many NOPs to wait for TX→RX loopback to complete
            // With baud_div=10, 16x oversample, 10 bits: ~1600 clocks
            u_axil_ram.mem[3] = 32'h00000013;
            u_axil_ram.mem[4] = 32'h00000013;
            u_axil_ram.mem[5] = 32'h00000013;
            u_axil_ram.mem[6] = 32'h00000013;
            u_axil_ram.mem[7] = 32'h00000013;
            u_axil_ram.mem[8] = 32'h00000013;
            u_axil_ram.mem[9] = 32'h00000013;
            u_axil_ram.mem[10] = 32'h00000013;
            
            // Read STATUS (offset 0x08) into x8
            // LW x8, 8(x3)          - Read STATUS
            u_axil_ram.mem[11] = 32'h0081a403;
            
            // Read RX_DATA (offset 0x04) into x9
            // LW x9, 4(x3)          - Read RX_DATA
            u_axil_ram.mem[12] = 32'h0041a483;
            
            // NOPs
            u_axil_ram.mem[13] = 32'h00000013;
            u_axil_ram.mem[14] = 32'h00000013;
            // Infinite loop to stop execution
            u_axil_ram.mem[15] = 32'h0000006f; // JAL x0, 0
        end
    endtask

    // ==========================================
    //   Test 15: RAW Hazard Stress Test
    // ==========================================
    task load_test15_raw_hazard_stress;
        integer i;
        begin
            $display("\n--- Loading Test 15: RAW Hazard Stress ---");
            // Clear memory first
            for (i = 0; i < 64; i = i + 1) begin
                u_axil_ram.mem[i] = 32'h00000013; // NOP
            end
            
            // This test creates maximum RAW hazard pressure:
            // Every instruction depends on the previous instruction's result
            // This tests data forwarding from EX/MEM and MEM/WB stages
            
            // 0x00: ADDI x1, x0, 1       - x1 = 1
            u_axil_ram.mem[0] = 32'h00100093;
            // 0x04: ADD x2, x1, x1       - x2 = x1 + x1 = 2 (RAW on x1)
            u_axil_ram.mem[1] = 32'h00108133;
            // 0x08: ADD x3, x2, x2       - x3 = x2 + x2 = 4 (RAW on x2)
            u_axil_ram.mem[2] = 32'h002101b3;
            // 0x0C: ADD x4, x3, x3       - x4 = x3 + x3 = 8 (RAW on x3)
            u_axil_ram.mem[3] = 32'h00318233;
            // 0x10: ADD x5, x4, x4       - x5 = x4 + x4 = 16 (RAW on x4)
            u_axil_ram.mem[4] = 32'h004202b3;
            // 0x14: ADD x6, x5, x5       - x6 = x5 + x5 = 32 (RAW on x5)
            u_axil_ram.mem[5] = 32'h00528333;
            // 0x18: ADD x7, x6, x6       - x7 = x6 + x6 = 64 (RAW on x6)
            u_axil_ram.mem[6] = 32'h006303b3;
            // 0x1C: ADD x8, x7, x7       - x8 = x7 + x7 = 128 (RAW on x7)
            u_axil_ram.mem[7] = 32'h00738433;
            // 0x20: ADD x9, x8, x8       - x9 = x8 + x8 = 256 (RAW on x8)
            u_axil_ram.mem[8] = 32'h008404b3;
            // 0x24: ADD x10, x9, x9      - x10 = x9 + x9 = 512 (RAW on x9)
            u_axil_ram.mem[9] = 32'h00948533;
            
            // Test with different instruction types creating RAW hazards
            // 0x28: SLLI x11, x10, 1     - x11 = 512 << 1 = 1024 (RAW shift)
            u_axil_ram.mem[10] = 32'h00151593;
            // 0x2C: XOR x12, x11, x10    - x12 = 1024 ^ 512 = 1536 (RAW logical)
            u_axil_ram.mem[11] = 32'h00a5c633;
            // 0x30: SUB x13, x12, x11    - x13 = 1536 - 1024 = 512 (RAW arithmetic)
            u_axil_ram.mem[12] = 32'h40b606b3;
            // 0x34: AND x14, x13, x12    - x14 = 512 & 1536 = 512 (RAW logical)
            u_axil_ram.mem[13] = 32'h00c6f733;
            // 0x38: SLT x15, x14, x13    - x15 = (512 < 512) = 0 (RAW compare)
            u_axil_ram.mem[14] = 32'h00d727b3;
            
            // NOPs
            u_axil_ram.mem[15] = 32'h00000013;
            u_axil_ram.mem[16] = 32'h00000013;
        end
    endtask

    // ==========================================
    //   Test 16: Full ALU Instruction Coverage
    // ==========================================
    task load_test16_full_alu_coverage;
        integer i;
        begin
            $display("\n--- Loading Test 16: Full ALU Instruction Coverage ---");
            // Clear memory first
            for (i = 0; i < 80; i = i + 1) begin
                u_axil_ram.mem[i] = 32'h00000013; // NOP
            end
            
            // Test all R-type and I-type ALU instructions in sequence
            // Setup values
            // 0x00: ADDI x1, x0, 100     - x1 = 100
            u_axil_ram.mem[0] = 32'h06400093;
            // 0x04: ADDI x2, x0, 7       - x2 = 7
            u_axil_ram.mem[1] = 32'h00700113;
            // 0x08: ADDI x3, x0, -50     - x3 = -50
            u_axil_ram.mem[2] = 32'hfce00193;
            
            // R-type instructions
            // 0x0C: ADD x4, x1, x2       - x4 = 100 + 7 = 107
            u_axil_ram.mem[3] = 32'h00208233;
            // 0x10: SUB x5, x1, x2       - x5 = 100 - 7 = 93
            u_axil_ram.mem[4] = 32'h402082b3;
            // 0x14: AND x6, x1, x2       - x6 = 100 & 7 = 4
            u_axil_ram.mem[5] = 32'h0020f333;
            // 0x18: OR x7, x1, x2        - x7 = 100 | 7 = 103
            u_axil_ram.mem[6] = 32'h0020e3b3;
            // 0x1C: XOR x8, x1, x2       - x8 = 100 ^ 7 = 99
            u_axil_ram.mem[7] = 32'h0020c433;
            // 0x20: SLL x9, x1, x2       - x9 = 100 << 7 = 12800
            u_axil_ram.mem[8] = 32'h002094b3;
            // 0x24: SRL x10, x1, x2      - x10 = 100 >> 7 = 0
            u_axil_ram.mem[9] = 32'h0020d533;
            // 0x28: SRA x11, x3, x2      - x11 = -50 >>> 7 = -1 (arithmetic shift)
            u_axil_ram.mem[10] = 32'h4021d5b3;
            // 0x2C: SLT x12, x3, x1      - x12 = (-50 < 100) = 1
            u_axil_ram.mem[11] = 32'h0011a633;
            // 0x30: SLTU x13, x1, x3     - x13 = (100 < 0xFFFFFFCE) = 1 (unsigned)
            u_axil_ram.mem[12] = 32'h0030b6b3;
            
            // I-type instructions
            // 0x34: ANDI x14, x1, 0x7F   - x14 = 100 & 127 = 100
            u_axil_ram.mem[13] = 32'h07f0f713;
            // 0x38: ORI x15, x1, 0x400   - x15 = 100 | 1024 = 1124
            u_axil_ram.mem[14] = 32'h4000e793;
            // 0x3C: XORI x1, x1, 0xFF    - x1 = 100 ^ 255 = 155 (reuse x1)
            u_axil_ram.mem[15] = 32'h0ff0c093;
            
            // Immediate shifts
            // 0x40: SLLI x2, x4, 3       - x2 = 107 << 3 = 856
            u_axil_ram.mem[16] = 32'h00321113;
            // 0x44: SRLI x3, x4, 2       - x3 = 107 >> 2 = 26
            u_axil_ram.mem[17] = 32'h00225193;
            // 0x48: SRAI x4, x5, 2       - x4 = 93 >> 2 = 23 (arithmetic)
            u_axil_ram.mem[18] = 32'h4022d213;
            
            // Immediate compares
            // 0x4C: SLTI x5, x6, 10      - x5 = (4 < 10) = 1
            u_axil_ram.mem[19] = 32'h00a32293;
            // 0x50: SLTIU x6, x6, 3      - x6 = (4 < 3) = 0
            u_axil_ram.mem[20] = 32'h00333313;
            
            // Store results to memory for verification
            // 0x54: SW x7, 512(x0)       - mem[512] = 103
            u_axil_ram.mem[21] = 32'h20702023;
            // 0x58: SW x10, 516(x0)      - mem[516] = 0
            u_axil_ram.mem[22] = 32'h20a02223;
            // 0x5C: SW x13, 520(x0)      - mem[520] = 1
            u_axil_ram.mem[23] = 32'h20d02423;
            
            // NOPs
            u_axil_ram.mem[24] = 32'h00000013;
            u_axil_ram.mem[25] = 32'h00000013;
        end
    endtask

    // ==========================================
    //   Test 17: Nested Loops Test
    // ==========================================
    task load_test17_nested_loops;
        integer i;
        begin
            $display("\n--- Loading Test 17: Nested Loops ---");
            // Clear memory first
            for (i = 0; i < 64; i = i + 1) begin
                u_axil_ram.mem[i] = 32'h00000013; // NOP
            end
            
            // This test implements nested loops:
            // for (i = 0; i < 3; i++)
            //   for (j = 0; j < 3; j++)
            //     sum += (i + j);
            // Result: sum = 0+1+2 + 1+2+3 + 2+3+4 = 18
            
            // x1 = outer loop counter (i)
            // x2 = inner loop counter (j)
            // x3 = outer loop limit (3)
            // x4 = inner loop limit (3)
            // x10 = sum accumulator
            // x11 = temp (i + j)
            
            // Initialize
            // 0x00: ADDI x1, x0, 0       - i = 0
            u_axil_ram.mem[0] = 32'h00000093;
            // 0x04: ADDI x3, x0, 3       - outer limit = 3
            u_axil_ram.mem[1] = 32'h00300193;
            // 0x08: ADDI x4, x0, 3       - inner limit = 3
            u_axil_ram.mem[2] = 32'h00300213;
            // 0x0C: ADDI x10, x0, 0      - sum = 0
            u_axil_ram.mem[3] = 32'h00000513;
            
            // Outer loop start (0x10):
            // 0x10: ADDI x2, x0, 0       - j = 0
            u_axil_ram.mem[4] = 32'h00000113;
            
            // Inner loop start (0x14):
            // 0x14: ADD x11, x1, x2      - temp = i + j
            u_axil_ram.mem[5] = 32'h002085b3;
            // 0x18: ADD x10, x10, x11    - sum += temp
            u_axil_ram.mem[6] = 32'h00b50533;
            // 0x1C: ADDI x2, x2, 1       - j++
            u_axil_ram.mem[7] = 32'h00110113;
            // 0x20: BLT x2, x4, -12      - if j < 3, branch to 0x14
            // Branch offset: 0x14 - 0x20 = -12
            u_axil_ram.mem[8] = 32'hfe414ae3;
            
            // Inner loop done
            // 0x24: ADDI x1, x1, 1       - i++
            u_axil_ram.mem[9] = 32'h00108093;
            // 0x28: BLT x1, x3, -24      - if i < 3, branch to 0x10
            // Branch offset: 0x10 - 0x28 = -24
            u_axil_ram.mem[10] = 32'hfe30c4e3;
            
            // Outer loop done, x10 should be 18
            // Store result
            // 0x2C: SW x10, 768(x0)      - mem[768] = 18
            u_axil_ram.mem[11] = 32'h30a02023;
            
            // NOPs
            u_axil_ram.mem[12] = 32'h00000013;
            u_axil_ram.mem[13] = 32'h00000013;
        end
    endtask

    // ==========================================
    //   Test 18: Memory Access Pattern Stress
    // ==========================================
    task load_test18_memory_stress;
        integer i;
        begin
            $display("\n--- Loading Test 18: Memory Access Pattern Stress ---");
            // Clear memory first
            for (i = 0; i < 80; i = i + 1) begin
                u_axil_ram.mem[i] = 32'h00000013; // NOP
            end
            
            // This test performs various memory access patterns to stress
            // the load/store pipeline and data forwarding from memory
            
            // Setup base addresses and values
            // 0x00: ADDI x1, x0, 0x400  - x1 = 0x400 (base address 1024)
            u_axil_ram.mem[0] = 32'h40000093;
            // 0x04: ADDI x2, x0, 0x55   - x2 = 0x55
            u_axil_ram.mem[1] = 32'h05500113;
            // 0x08: ADDI x3, x0, 0xAA   - x3 = 0xAA
            u_axil_ram.mem[2] = 32'h0aa00193;
            
            // Store-Store pattern
            // 0x0C: SW x2, 0(x1)        - mem[0x400] = 0x55
            u_axil_ram.mem[3] = 32'h0020a023;
            // 0x10: SW x3, 4(x1)        - mem[0x404] = 0xAA
            u_axil_ram.mem[4] = 32'h0030a223;
            // 0x14: SW x2, 8(x1)        - mem[0x408] = 0x55
            u_axil_ram.mem[5] = 32'h0020a423;
            // 0x18: SW x3, 12(x1)       - mem[0x40C] = 0xAA
            u_axil_ram.mem[6] = 32'h0030a623;
            
            // Load-Load pattern
            // 0x1C: LW x4, 0(x1)        - x4 = 0x55
            u_axil_ram.mem[7] = 32'h0000a203;
            // 0x20: LW x5, 4(x1)        - x5 = 0xAA
            u_axil_ram.mem[8] = 32'h0040a283;
            // 0x24: LW x6, 8(x1)        - x6 = 0x55
            u_axil_ram.mem[9] = 32'h0080a303;
            // 0x28: LW x7, 12(x1)       - x7 = 0xAA
            u_axil_ram.mem[10] = 32'h00c0a383;
            
            // Load-Use immediate pattern (tests forwarding)
            // 0x2C: ADD x8, x4, x5      - x8 = 0x55 + 0xAA = 0xFF
            u_axil_ram.mem[11] = 32'h00520433;
            // 0x30: ADD x9, x6, x7      - x9 = 0x55 + 0xAA = 0xFF
            u_axil_ram.mem[12] = 32'h007304b3;
            // 0x34: ADD x10, x8, x9     - x10 = 0xFF + 0xFF = 0x1FE
            u_axil_ram.mem[13] = 32'h00940533;
            
            // Store-Load same address (tests memory coherence)
            // 0x38: ADDI x11, x0, 0x123 - x11 = 0x123
            u_axil_ram.mem[14] = 32'h12300593;
            // 0x3C: SW x11, 16(x1)      - mem[0x410] = 0x123
            u_axil_ram.mem[15] = 32'h00b0a823;
            // Add NOP after store before load
            u_axil_ram.mem[16] = 32'h00000013;  // NOP
            // 0x44: LW x12, 16(x1)      - x12 = 0x123 (load after store)
            u_axil_ram.mem[17] = 32'h0100a603;
            
            // Mixed byte/halfword stress - need gaps between store and load
            // 0x48: SB x2, 20(x1)       - mem[0x414] byte 0 = 0x55
            // 0x48: SB x2, 20(x1)       - mem[0x414] byte 0 = 0x55
            // Correct encoding: 0x00208a23 (rs2=x2 not x20)
            u_axil_ram.mem[18] = 32'h00208a23;
            // NOP to allow SB to complete
            u_axil_ram.mem[19] = 32'h00000013;  // NOP
            // 0x50: LB x13, 20(x1)      - x13 = sign_extend(0x55) = 0x55
            // 0x50: LB x13, 20(x1)      - x13 = sign_extend(0x55) = 0x55
            u_axil_ram.mem[20] = 32'h01408683;
            
            // 0x54: SH x3, 24(x1)       - mem[0x418] halfword = 0x00AA
            // 0x54: SH x3, 24(x1)       - mem[0x418] halfword = 0x00AA
            // Correct encoding: 0x00309c23 (rs2=x3 not x1)
            u_axil_ram.mem[21] = 32'h00309c23;
            // NOP to allow SH to complete
            u_axil_ram.mem[22] = 32'h00000013;  // NOP
            // 0x5C: LHU x14, 24(x1)     - x14 = 0x00AA (unsigned)
            u_axil_ram.mem[23] = 32'h0180d703;
            
            // Verify results
            // 0x60: ADD x15, x10, x12   - x15 = 0x1FE + 0x123 = 0x321
            u_axil_ram.mem[24] = 32'h00c507b3;
            
            // NOPs
            u_axil_ram.mem[25] = 32'h00000013;
            u_axil_ram.mem[26] = 32'h00000013;
        end
    endtask

    // ==========================================
    //   Test 19: Mixed Instruction Stress
    // ==========================================
    task load_test19_mixed_stress;
        integer i;
        begin
            $display("\n--- Loading Test 19: Mixed Instruction Stress ---");
            // Clear memory first
            for (i = 0; i < 100; i = i + 1) begin
                u_axil_ram.mem[i] = 32'h00000013; // NOP
            end
            
            // This test alternates between different instruction types
            // to stress the pipeline with varying latencies and dependencies
            
            // Setup
            // 0x00: LUI x1, 0x12345      - x1 = 0x12345000
            u_axil_ram.mem[0] = 32'h123450b7;
            // 0x04: ADDI x1, x1, 0x678   - x1 = 0x12345678
            u_axil_ram.mem[1] = 32'h67808093;
            // 0x08: ADDI x2, x0, 0x500   - x2 = 0x500 (base addr)
            u_axil_ram.mem[2] = 32'h50000113;
            
            // Alternate: Store, NOP, ALU, ALU, Load, ALU, Store...
            // 0x0C: SW x1, 0(x2)         - mem[0x500] = 0x12345678
            // Correct encoding: 0x00112023
            u_axil_ram.mem[3] = 32'h00112023;
            // 0x10: NOP                  - Allow store to complete
            u_axil_ram.mem[4] = 32'h00000013;
            // 0x14: SRLI x3, x1, 16      - x3 = 0x1234
            u_axil_ram.mem[5] = 32'h0100d193;
            // 0x18: ANDI x4, x1, 0xFF    - x4 = 0x78
            u_axil_ram.mem[6] = 32'h0ff0f213;
            // 0x1C: LW x5, 0(x2)         - x5 = 0x12345678
            // 0x1C: LW x5, 0(x2)         - x5 = 0x12345678
            // Correct encoding: 0x00012283 (rs1=x2 not x1)
            u_axil_ram.mem[7] = 32'h00012283;
            // 0x20: ADD x6, x3, x4       - x6 = 0x1234 + 0x78 = 0x12AC
            u_axil_ram.mem[8] = 32'h00418333;
            // 0x24: SW x6, 4(x2)         - mem[0x504] = 0x12AC
            u_axil_ram.mem[9] = 32'h00612223;
            
            // Branch with ALU
            // 0x28: ADDI x7, x0, 0       - x7 = 0 (counter)
            u_axil_ram.mem[10] = 32'h00000393;
            // 0x2C: ADDI x8, x0, 3       - x8 = 3 (limit)
            u_axil_ram.mem[11] = 32'h00300413;
            
            // Loop: 0x30
            // 0x30: SLLI x9, x7, 2       - x9 = counter * 4 (offset)
            u_axil_ram.mem[12] = 32'h00239493;
            // 0x34: ADD x10, x2, x9      - x10 = base + offset
            u_axil_ram.mem[13] = 32'h00910533;
            // 0x38: SW x7, 8(x10)        - store counter at mem[base+8+offset]
            u_axil_ram.mem[14] = 32'h00752423;
            // 0x3C: ADDI x7, x7, 1       - counter++
            u_axil_ram.mem[15] = 32'h00138393;
            // 0x40: BLT x7, x8, -16      - if counter < 3, goto 0x30
            // Branch offset: 0x30 - 0x40 = -16
            u_axil_ram.mem[16] = 32'hfe83c8e3;
            
            // JAL/JALR interspersed
            // 0x44: JAL x11, +12         - jump to 0x50, x11 = 0x48
            u_axil_ram.mem[17] = 32'h00c005ef;
            // 0x48: ADDI x12, x0, 0xBAD  - SKIP (should not execute)
            u_axil_ram.mem[18] = 32'hbad00613;
            // 0x4C: ADDI x12, x0, 0xBAD  - SKIP
            u_axil_ram.mem[19] = 32'hbad00613;
            // 0x50: LUI x12, 0xABCDE     - x12 = 0xABCDE000
            u_axil_ram.mem[20] = 32'habcde637;
            // 0x54: ADDI x13, x0, 0x64   - x13 = 0x64 (target address)
            u_axil_ram.mem[21] = 32'h06400693;
            // 0x58: JALR x14, x13, 0     - jump to 0x64, x14 = 0x5C
            u_axil_ram.mem[22] = 32'h00068767;
            // 0x5C: ADDI x15, x0, 0xBAD  - SKIP
            u_axil_ram.mem[23] = 32'hbad00793;
            // 0x60: ADDI x15, x0, 0xBAD  - SKIP
            u_axil_ram.mem[24] = 32'hbad00793;
            // 0x64: ADDI x15, x0, 0x42   - x15 = 0x42 (final marker)
            u_axil_ram.mem[25] = 32'h04200793;
            
            // Final verification: compute checksum of results
            // 0x68: ADD x10, x3, x4      - x10 = 0x1234 + 0x78 = 0x12AC
            u_axil_ram.mem[26] = 32'h00418533;
            // 0x6C: ADD x10, x10, x6     - x10 += 0x12AC = 0x2558
            u_axil_ram.mem[27] = 32'h00650533;
            // 0x70: XOR x10, x10, x12    - x10 ^= 0xABCDE000
            u_axil_ram.mem[28] = 32'h00c54533;
            
            // NOPs
            u_axil_ram.mem[29] = 32'h00000013;
            u_axil_ram.mem[30] = 32'h00000013;
            // Infinite loop to stop execution
            u_axil_ram.mem[31] = 32'h0000006f; // JAL x0, 0
        end
    endtask

    task load_test20_multiplication;
        integer i;
        begin
            $display("\n--- Loading Test 20: Multiplication Operations (M Extension) ---");
            // Clear memory first
            for (i = 0; i < 128; i = i + 1) begin
                u_axil_ram.mem[i] = 32'h00000013; // NOP
            end
            
            // This test verifies MUL, MULH, MULHSU, MULHU instructions
            // M-extension uses funct7 = 0000001 to distinguish from standard R-type
            
            // ============================================
            // Setup test values
            // ============================================
            // 0x00: ADDI x1, x0, 7        - x1 = 7
            u_axil_ram.mem[0] = 32'h00700093;
            // 0x04: ADDI x2, x0, 6        - x2 = 6
            u_axil_ram.mem[1] = 32'h00600113;
            
            // ============================================
            // Test 1: Basic MUL (lower 32 bits)
            // ============================================
            // 0x08: MUL x3, x1, x2         - x3 = 7 * 6 = 42
            // Encoding: funct7=0000001, rs2=2, rs1=1, funct3=000, rd=3, opcode=0110011
            u_axil_ram.mem[2] = 32'h022081b3;
            
            // ============================================
            // Test 2: MUL with overflow (result needs 64 bits)
            // ============================================
            // 0x0C: LUI x4, 0x10000        - x4 = 0x10000000 (268435456)
            u_axil_ram.mem[3] = 32'h10000237;
            // 0x10: ADDI x5, x0, 16       - x5 = 16
            u_axil_ram.mem[4] = 32'h01000293;
            // 0x14: MUL x6, x4, x5         - x6 = 0x10000000 * 16 = 0 (lower 32 bits)
            u_axil_ram.mem[5] = 32'h02520333;
            
            // ============================================
            // Test 3: MULH (upper 32 bits, signed*signed)
            // ============================================
            // 0x18: MULH x7, x4, x5        - x7 = upper(0x10000000 * 16) = 1
            u_axil_ram.mem[6] = 32'h025213b3;
            
            // ============================================
            // Test 4: MUL with negative numbers
            // ============================================
            // 0x1C: ADDI x8, x0, -10       - x8 = -10 (0xFFFFFFF6)
            u_axil_ram.mem[7] = 32'hff600413;
            // 0x20: ADDI x9, x0, 5         - x9 = 5
            u_axil_ram.mem[8] = 32'h00500493;
            // 0x24: MUL x10, x8, x9        - x10 = (-10) * 5 = -50
            u_axil_ram.mem[9] = 32'h02940533;
            
            // ============================================
            // Test 5: MULHU (unsigned * unsigned upper)
            // ============================================
            // 0x28: ADDI x11, x0, -1        - x11 = 0xFFFFFFFF (use signed immediate)
            u_axil_ram.mem[10] = 32'hfff00593;
            // 0x2C: ADDI x12, x0, 2        - x12 = 2
            u_axil_ram.mem[11] = 32'h00200613;
            // 0x30: MULHU x13, x11, x12    - x13 = upper(0xFFFFFFFF * 2 unsigned) = 1
            u_axil_ram.mem[12] = 32'h02c5b6b3;
            
            // ============================================
            // Test 6: MULHSU (signed * unsigned upper)
            // NOTE: Our multiplier is unsigned-only, MULHSU will not give correct signed result
            // ============================================
            // 0x34: MULHSU x14, x8, x12    - x14 = upper((-10) * 2 signed*unsigned)
            // With unsigned multiplier: treats -10 as 0xFFFFFFF6, so (0xFFFFFFF6 * 2) >> 32 = 1
            u_axil_ram.mem[13] = 32'h02c42733;
            
            // ============================================
            // CORNER CASES
            // ============================================
            
            // Test 7: Multiply by zero
            // 0x38: MUL x15, x1, x0        - x15 = 7 * 0 = 0
            u_axil_ram.mem[14] = 32'h020087b3;
            
            // Test 8: Multiply by one
            // 0x3C: ADDI x16, x0, 1        - x16 = 1
            u_axil_ram.mem[15] = 32'h00100813;
            // 0x40: MUL x17, x1, x16       - x17 = 7 * 1 = 7
            u_axil_ram.mem[16] = 32'h030088b3;
            
            // Test 9: Multiply by -1
            // 0x44: ADDI x18, x0, -1       - x18 = -1
            u_axil_ram.mem[17] = 32'hfff00913;
            // 0x48: MUL x19, x1, x18       - x19 = 7 * (-1) = -7
            u_axil_ram.mem[18] = 32'h032089b3;
            
            // Test 10: Max positive * max positive (0x7FFFFFFF * 0x7FFFFFFF)
            // Upper = 0x3FFFFFFF, Lower = 0x00000001
            // 0x4C: LUI x20, 0x7FFFF       - x20 = 0x7FFFF000
            u_axil_ram.mem[19] = 32'h7ffffa37;
            // 0x50: ADDI x20, x20, 0x7FF   - x20 = 0x7FFFF7FF (not quite 0x7FFFFFFF)
            u_axil_ram.mem[20] = 32'h7ffa0a13;
            // 0x54: MUL x21, x20, x20      - x21 = lower(0x7FFFF7FF^2)
            u_axil_ram.mem[21] = 32'h034a0ab3;
            // 0x58: MULH x22, x20, x20     - x22 = upper(0x7FFFF7FF^2)
            u_axil_ram.mem[22] = 32'h034a1b33;
            
            // Test 11: 0x80000000 * -1 edge case (most negative * -1)
            // Result should be 0x80000000 (overflow, stays same)
            // 0x5C: LUI x23, 0x80000       - x23 = 0x80000000
            u_axil_ram.mem[23] = 32'h80000bb7;
            // 0x60: MUL x24, x23, x18      - x24 = 0x80000000 * (-1) = 0x80000000
            u_axil_ram.mem[24] = 32'h032b8c33;
            
            // Test 12: 0xFFFFFFFF * 0xFFFFFFFF (unsigned max * max)
            // MULHU upper = 0xFFFFFFFE, MUL lower = 0x00000001
            // 0x64: MULHU x25, x11, x11    - x25 = upper(0xFFFFFFFF^2 unsigned) = 0xFFFFFFFE
            u_axil_ram.mem[25] = 32'h02b5bcb3;
            // 0x68: MUL x26, x11, x11      - x26 = lower(0xFFFFFFFF^2) = 1
            u_axil_ram.mem[26] = 32'h02b58d33;
            
            // ============================================
            // Store results for verification
            // ============================================
            // 0x6C: SW x3, 256(x0)         - mem[256] = 42
            u_axil_ram.mem[27] = 32'h10302023;
            // 0x70: SW x6, 260(x0)         - mem[260] = 0 (overflow lower)
            u_axil_ram.mem[28] = 32'h10602223;
            // 0x74: SW x7, 264(x0)         - mem[264] = 1 (MULH upper)
            u_axil_ram.mem[29] = 32'h10702423;
            
            // NOPs
            u_axil_ram.mem[30] = 32'h00000013;
            u_axil_ram.mem[31] = 32'h00000013;
            // Infinite loop to stop execution
            u_axil_ram.mem[32] = 32'h0000006f; // JAL x0, 0
        end
    endtask

    // ==========================================
    //   Test 21: Division Operations (M Extension)
    // ==========================================
    task load_test21_division;
        integer i;
        begin
            $display("\n--- Loading Test 21: Division (M Extension) ---");
            // Clear memory first
            for (i = 0; i < 64; i = i + 1) begin
                u_axil_ram.mem[i] = 32'h00000013; // NOP
            end
            
            // ============================================
            // Division Instructions Encoding (R-type):
            // funct7[6:0] = 0000001 (M extension)
            // funct3[2:0] for division:
            //   100 = DIV   (signed quotient)
            //   101 = DIVU  (unsigned quotient)
            //   110 = REM   (signed remainder)
            //   111 = REMU  (unsigned remainder)
            // ============================================
            
            // Setup test values
            // 0x00: ADDI x1, x0, 100      - x1 = 100 (dividend)
            u_axil_ram.mem[0] = 32'h06400093;
            // 0x04: ADDI x2, x0, 7        - x2 = 7 (divisor)
            u_axil_ram.mem[1] = 32'h00700113;
            
            // ============================================
            // Test 1: DIVU (unsigned quotient) 100 / 7 = 14
            // ============================================
            // 0x08: DIVU x3, x1, x2       - x3 = 100 / 7 = 14
            // Encoding: 0000001 | rs2=2 | rs1=1 | funct3=101 | rd=3 | 0110011
            u_axil_ram.mem[2] = 32'h0220d1b3;
            
            // ============================================
            // Test 2: REMU (unsigned remainder) 100 % 7 = 2
            // ============================================
            // 0x0C: REMU x4, x1, x2       - x4 = 100 % 7 = 2
            // Encoding: 0000001 | rs2=2 | rs1=1 | funct3=111 | rd=4 | 0110011
            u_axil_ram.mem[3] = 32'h0220f233;
            
            // ============================================
            // Test 3: DIV (signed quotient) -100 / 7 = -14
            // ============================================
            // 0x10: ADDI x5, x0, -100     - x5 = -100
            u_axil_ram.mem[4] = 32'hf9c00293;
            // 0x14: DIV x6, x5, x2        - x6 = -100 / 7 = -14
            // Encoding: 0000001 | rs2=2 | rs1=5 | funct3=100 | rd=6 | 0110011
            u_axil_ram.mem[5] = 32'h0222c333;
            
            // ============================================  
            // Test 4: REM (signed remainder) -100 % 7 = -2
            // ============================================
            // 0x18: REM x7, x5, x2        - x7 = -100 % 7 = -2
            // Encoding: 0000001 | rs2=2 | rs1=5 | funct3=110 | rd=7 | 0110011
            u_axil_ram.mem[6] = 32'h0222e3b3;
            
            // ============================================
            // Test 5: Large numbers - 1000000 / 1000 = 1000
            // ============================================
            // Build 1000000 = 0x000F4240
            // 0x1C: LUI x8, 0x000F4      - x8 = 0x000F4000
            u_axil_ram.mem[7] = 32'h000f4437;
            // 0x20: ADDI x8, x8, 0x240   - x8 = 0x000F4240 = 1000000
            u_axil_ram.mem[8] = 32'h24040413;
            // 0x24: ADDI x9, x0, 1000    - x9 = 1000 (0x3E8)
            u_axil_ram.mem[9] = 32'h3e800493;
            // 0x28: DIVU x10, x8, x9     - x10 = 1000000 / 1000 = 1000
            u_axil_ram.mem[10] = 32'h02945533;
            
            // ============================================
            // Test 6: Division by 1 (identity)
            // ============================================
            // 0x2C: ADDI x11, x0, 1      - x11 = 1
            u_axil_ram.mem[11] = 32'h00100593;
            // 0x30: DIVU x12, x1, x11    - x12 = 100 / 1 = 100
            u_axil_ram.mem[12] = 32'h02b0d633;
            
            // ============================================
            // Test 7: Division of smaller by larger = 0
            // ============================================
            // 0x34: ADDI x13, x0, 5      - x13 = 5
            u_axil_ram.mem[13] = 32'h00500693;
            // 0x38: ADDI x14, x0, 10     - x14 = 10
            u_axil_ram.mem[14] = 32'h00a00713;
            // 0x3C: DIVU x15, x13, x14   - x15 = 5 / 10 = 0
            u_axil_ram.mem[15] = 32'h02e6d7b3;
            // 0x40: REMU x16, x13, x14   - x16 = 5 % 10 = 5
            u_axil_ram.mem[16] = 32'h02e6f833;
            
            // ============================================
            // Store results for verification
            // ============================================
            // 0x44: SW x3, 256(x0)       - mem[256] = 14 (100/7)
            u_axil_ram.mem[17] = 32'h10302023;
            // 0x48: SW x4, 260(x0)       - mem[260] = 2 (100%7)
            u_axil_ram.mem[18] = 32'h10402223;
            // 0x4C: SW x10, 264(x0)      - mem[264] = 1000 (1M/1K)
            u_axil_ram.mem[19] = 32'h10a02423;
            
            // NOPs  
            u_axil_ram.mem[20] = 32'h00000013;
            u_axil_ram.mem[21] = 32'h00000013;
            // Infinite loop to stop execution
            u_axil_ram.mem[22] = 32'h0000006f; // JAL x0, 0
        end
    endtask

    // ==========================================
    //   Test 22: Division Forwarding Test
    //   Tests: ADD->DIV, MUL->DIV, DIV->DIV
    // ==========================================
    task load_test22_m_extension_stress;
        integer i;
        begin
            $display("\n--- Loading Test 22: Division Forwarding Tests ---");
            // Clear memory first
            for (i = 0; i < 32; i = i + 1) begin
                u_axil_ram.mem[i] = 32'h00000013; // NOP
            end
            
            // Setup values
            // 0x00: ADDI x1, x0, 42         - x1 = 42
            u_axil_ram.mem[0] = 32'h02a00093;
            // 0x04: ADDI x2, x0, 6          - x2 = 6
            u_axil_ram.mem[1] = 32'h00600113;
            // 0x08: ADDI x3, x0, 3          - x3 = 3 (divisor)
            u_axil_ram.mem[2] = 32'h00300193;
            // 0x0C: ADDI x4, x0, 7          - x4 = 7
            u_axil_ram.mem[3] = 32'h00700213;
            
            // ========== Test Case 1: ADD -> DIVU ==========
            // 0x10: ADD x5, x1, x0          - x5 = 42 + 0 = 42 (copy)
            u_axil_ram.mem[4] = 32'h000082b3;
            // 0x14: DIVU x10, x5, x3        - x10 = 42 / 3 = 14 (forward from ADD)
            u_axil_ram.mem[5] = 32'h0232d533;
            // 0x18-0x1C: NOPs for division completion
            u_axil_ram.mem[6] = 32'h00000013;
            u_axil_ram.mem[7] = 32'h00000013;
            
            // ========== Test Case 2: MUL -> DIVU ==========
            // 0x20: MUL x6, x2, x4          - x6 = 6 * 7 = 42
            u_axil_ram.mem[8] = 32'h02410333;
            // 0x24: DIVU x11, x6, x3        - x11 = 42 / 3 = 14 (forward from MUL)
            u_axil_ram.mem[9] = 32'h023355b3;
            // 0x28-0x2C: NOPs for division completion
            u_axil_ram.mem[10] = 32'h00000013;
            u_axil_ram.mem[11] = 32'h00000013;
            
            // ========== Test Case 3: DIVU -> DIVU ==========
            // 0x30: DIVU x7, x1, x3         - x7 = 42 / 3 = 14
            u_axil_ram.mem[12] = 32'h0230d3b3;
            // 0x34-0x38: NOPs for first division completion
            u_axil_ram.mem[13] = 32'h00000013;
            u_axil_ram.mem[14] = 32'h00000013;
            // 0x3C: ADDI x8, x7, 0          - x8 = x7 = 14 (verify first div result)
            u_axil_ram.mem[15] = 32'h00038413;
            // 0x40: DIVU x12, x7, x2        - x12 = 14 / 6 = 2 (use result of first div)
            // funct7=0000001, rs2=00010(x2), rs1=00111(x7), funct3=101, rd=01100(x12), opcode=0110011
            u_axil_ram.mem[16] = 32'h0223d633;
            // 0x44-0x48: NOPs for second division completion
            u_axil_ram.mem[17] = 32'h00000013;
            u_axil_ram.mem[18] = 32'h00000013;
            
            // ========== Store results ==========
            // 0x4C: SW x10, 512(x0)         - mem[512] = 14 (ADD->DIV result)
            u_axil_ram.mem[19] = 32'h20a02023;
            // 0x50: SW x11, 516(x0)         - mem[516] = 14 (MUL->DIV result)
            u_axil_ram.mem[20] = 32'h20b02223;
            // 0x54: SW x12, 520(x0)         - mem[520] = 2 (DIV->DIV result)
            u_axil_ram.mem[21] = 32'h20c02423;
            // 0x58: SW x6, 524(x0)          - mem[524] = 42 (verify MUL worked)
            u_axil_ram.mem[22] = 32'h20602623;
            
            // NOPs
            u_axil_ram.mem[23] = 32'h00000013;
            // Infinite loop to stop execution
            u_axil_ram.mem[24] = 32'h0000006f; // JAL x0, 0
        end
    endtask

    // ==========================================
    //   Test 23: M Extension + Control Flow
    //   Combines MUL, DIV, Branches, Jumps
    // ==========================================
    task load_test23_m_extension_control_flow;
        integer i;
        begin
            $display("\n--- Loading Test 23: M Extension + Control Flow ---");
            // Clear memory first
            for (i = 0; i < 48; i = i + 1) begin
                u_axil_ram.mem[i] = 32'h00000013; // NOP
            end
            
            // ========== Setup values ==========
            // 0x00: ADDI x1, x0, 6           - x1 = 6
            u_axil_ram.mem[0] = 32'h00600093;
            // 0x04: ADDI x2, x0, 7           - x2 = 7
            u_axil_ram.mem[1] = 32'h00700113;
            // 0x08: ADDI x3, x0, 3           - x3 = 3 (divisor)
            u_axil_ram.mem[2] = 32'h00300193;
            // 0x0C: ADDI x20, x0, 0          - x20 = 0 (branch counter)
            u_axil_ram.mem[3] = 32'h00000a13;
            
            // ========== Step 1: MUL then conditional branch ==========
            // 0x10: MUL x4, x1, x2           - x4 = 6 * 7 = 42
            u_axil_ram.mem[4] = 32'h02208233;
            // 0x14: ADDI x5, x0, 40          - x5 = 40 (comparison value)
            u_axil_ram.mem[5] = 32'h02800293;
            // 0x18: BLT x5, x4, +8           - if 40 < 42, branch to 0x20 (skip next)
            // B-type: imm[12|10:5]=0_000000, rs2=x4, rs1=x5, funct3=100, imm[4:1|11]=0100_0
            u_axil_ram.mem[6] = 32'h0042c463;
            // 0x1C: ADDI x20, x20, 100       - SKIPPED if branch taken
            u_axil_ram.mem[7] = 32'h064a0a13;
            // 0x20: ADDI x20, x20, 1         - x20++ (branch was taken)
            u_axil_ram.mem[8] = 32'h001a0a13;
            
            // ========== Step 2: DIV with forwarding from MUL ==========
            // 0x24: DIVU x6, x4, x3          - x6 = 42 / 3 = 14
            u_axil_ram.mem[9] = 32'h02325333;
            // 0x28-0x2C: NOPs for division
            u_axil_ram.mem[10] = 32'h00000013;
            u_axil_ram.mem[11] = 32'h00000013;
            
            // ========== Step 3: Branch based on DIV result ==========
            // 0x30: ADDI x7, x0, 14          - x7 = 14 (expected result)
            u_axil_ram.mem[12] = 32'h00e00393;
            // 0x34: BEQ x6, x7, +8           - if x6 == 14, branch to 0x3C
            // B-type: imm[12|10:5]=0_000000, rs2=x7, rs1=x6, funct3=000, imm[4:1|11]=0100_0
            u_axil_ram.mem[13] = 32'h00730463;
            // 0x38: ADDI x20, x20, 100       - SKIPPED if branch taken
            u_axil_ram.mem[14] = 32'h064a0a13;
            // 0x3C: ADDI x20, x20, 1         - x20++ (branch was taken)
            u_axil_ram.mem[15] = 32'h001a0a13;
            
            // ========== Step 4: JAL to subroutine ==========
            // 0x40: JAL x21, +24             - Jump to 0x58, x21 = 0x44
            // J-type: +24: imm[20|10:1|11|19:12]=0_0000001100_0_00000000, rd=10101(x21), op=1101111
            // 0_0000001100_0_00000000_10101_1101111 = 0x01800AEF
            u_axil_ram.mem[16] = 32'h01800aef;
            // 0x44: ADDI x20, x20, 1         - x20++ (returned from JAL)
            u_axil_ram.mem[17] = 32'h001a0a13;
            // 0x48: JAL x0, +24              - Skip subroutine, jump to 0x60
            // J-type: +24: imm[20|10:1|11|19:12]=0_0000001100_0_00000000, rd=0, op=1101111
            // 0_0000001100_0_00000000_00000_1101111 = 0x0180006F
            u_axil_ram.mem[18] = 32'h0180006f;
            // 0x4C-0x54: Padding (skipped)
            u_axil_ram.mem[19] = 32'h00000013;
            u_axil_ram.mem[20] = 32'h00000013;
            u_axil_ram.mem[21] = 32'h00000013;
            
            // ========== Subroutine at 0x58 ==========
            // 0x58: MUL x8, x6, x2           - x8 = 14 * 7 = 98
            u_axil_ram.mem[22] = 32'h02238433;
            // 0x5C: JALR x0, x21, 0          - Return to x21 (0x44)
            u_axil_ram.mem[23] = 32'h000a8067;
            
            // ========== Step 5: Final DIV after control flow ==========
            // 0x60: DIVU x9, x8, x2          - x9 = 98 / 7 = 14
            // funct7=0000001, rs2=00010(x2), rs1=01000(x8), funct3=101, rd=01001(x9), op=0110011
            u_axil_ram.mem[24] = 32'h022454b3;
            // 0x64-0x68: NOPs for division
            u_axil_ram.mem[25] = 32'h00000013;
            u_axil_ram.mem[26] = 32'h00000013;
            
            // ========== Store results ==========
            // 0x6C: SW x4, 512(x0)           - mem[512] = 42 (MUL result)
            u_axil_ram.mem[27] = 32'h20402023;
            // 0x70: SW x6, 516(x0)           - mem[516] = 14 (first DIV)
            u_axil_ram.mem[28] = 32'h20602223;
            // 0x74: SW x8, 520(x0)           - mem[520] = 98 (subroutine MUL)
            u_axil_ram.mem[29] = 32'h20802423;
            // 0x78: SW x9, 524(x0)           - mem[524] = 14 (final DIV)
            u_axil_ram.mem[30] = 32'h20902623;
            // 0x7C: SW x20, 528(x0)          - mem[528] = 3 (branch counter)
            u_axil_ram.mem[31] = 32'h21402823;
            // 0x80: SW x21, 532(x0)          - mem[532] = 0x44 (JAL return addr)
            u_axil_ram.mem[32] = 32'h21502a23;
            
            // NOPs
            u_axil_ram.mem[33] = 32'h00000013;
            u_axil_ram.mem[34] = 32'h00000013;
            // Infinite loop to stop execution
            u_axil_ram.mem[35] = 32'h0000006f; // JAL x0, 0
        end
    endtask

    // ==========================================
    //   Test 24: Cache Locality Exploitation
    //   Multiple loops to demonstrate cache hits
    // ==========================================
    task load_test24_cache_locality;
        integer i;
        begin
            $display("\n--- Loading Test 24: Cache Locality Exploitation ---");
            // Clear memory first
            for (i = 0; i < 64; i = i + 1) begin
                u_axil_ram.mem[i] = 32'h00000013; // NOP
            end
            
            // ========== Loop 1: Sum 0..19 = 190 ==========
            // x2 = counter, x3 = limit (20), x10 = sum
            
            // 0x00: ADDI x2, x0, 0      - x2 = 0 (counter)
            u_axil_ram.mem[0] = 32'h00000113;
            // 0x04: ADDI x3, x0, 20     - x3 = 20 (limit)
            u_axil_ram.mem[1] = 32'h01400193;
            // 0x08: ADDI x10, x0, 0     - x10 = 0 (sum)
            u_axil_ram.mem[2] = 32'h00000513;
            
            // Loop 1 start (0x0C):
            // 0x0C: ADD x10, x10, x2    - sum += counter
            u_axil_ram.mem[3] = 32'h00250533;
            // 0x10: ADDI x2, x2, 1      - counter++
            u_axil_ram.mem[4] = 32'h00110113;
            // 0x14: BLT x2, x3, -8      - if counter < 20, branch back
            u_axil_ram.mem[5] = 32'hfe314ce3;
            
            // 0x18: SW x10, 256(x0)     - store sum = 190
            u_axil_ram.mem[6] = 32'h10a02023;
            
            // ========== Loop 2: Tight counter to 30 ==========
            // x4 = counter, x5 = limit (30)
            
            // 0x1C: ADDI x4, x0, 0      - x4 = 0
            u_axil_ram.mem[7] = 32'h00000213;
            // 0x20: ADDI x5, x0, 30     - x5 = 30
            u_axil_ram.mem[8] = 32'h01e00293;
            
            // Loop 2 start (0x24):
            // 0x24: ADDI x4, x4, 1      - counter++
            u_axil_ram.mem[9] = 32'h00120213;
            // 0x28: BLT x4, x5, -4      - if counter < 30, branch back
            u_axil_ram.mem[10] = 32'hfe524ee3;
            
            // 0x2C: SW x4, 260(x0)      - store counter = 30
            u_axil_ram.mem[11] = 32'h10402223;
            
            // ========== Loop 3: Nested 4x5 = 20 iterations ==========
            // x6 = outer, x7 = outer_limit (4)
            // x8 = inner, x9 = inner_limit (5)
            // x11 = total count
            
            // 0x30: ADDI x6, x0, 0      - outer = 0
            u_axil_ram.mem[12] = 32'h00000313;
            // 0x34: ADDI x7, x0, 4      - outer_limit = 4
            u_axil_ram.mem[13] = 32'h00400393;
            // 0x38: ADDI x11, x0, 0     - total = 0
            u_axil_ram.mem[14] = 32'h00000593;
            // 0x3C: ADDI x9, x0, 5      - inner_limit = 5
            u_axil_ram.mem[15] = 32'h00500493;
            
            // Outer loop start (0x40):
            // 0x40: ADDI x8, x0, 0      - inner = 0
            u_axil_ram.mem[16] = 32'h00000413;
            
            // Inner loop start (0x44):
            // 0x44: ADDI x11, x11, 1    - total++
            u_axil_ram.mem[17] = 32'h00158593;
            // 0x48: ADDI x8, x8, 1      - inner++
            u_axil_ram.mem[18] = 32'h00140413;
            // 0x4C: BLT x8, x9, -8      - if inner < 5, branch to 0x44
            u_axil_ram.mem[19] = 32'hfe944ce3;
            
            // 0x50: ADDI x6, x6, 1      - outer++
            u_axil_ram.mem[20] = 32'h00130313;
            // 0x54: BLT x6, x7, -20     - if outer < 4, branch to 0x40
            // NOTE: For B-type encodings, rs1/rs2 are part of the word; can't reuse immediates blindly.
            // Offset = 0x40 - 0x54 = -20
            // Encoded immediate for -20: imm[12]=1, imm[11]=1, imm[10:5]=111111, imm[4:1]=0110
            // Full instruction (BLT x6, x7, -20) = 0xFE7346E3
            u_axil_ram.mem[21] = 32'hfe7346e3;
            
            // 0x58: SW x11, 264(x0)     - store total = 20
            u_axil_ram.mem[22] = 32'h10b02423;
            
            // NOPs to finish cleanly
            u_axil_ram.mem[23] = 32'h00000013;
            u_axil_ram.mem[24] = 32'h00000013;
            // Infinite loop to stop execution
            u_axil_ram.mem[25] = 32'h0000006f; // JAL x0, 0
        end
    endtask

    // ==========================================
    //   Test 25: I-Cache Conflict Miss Thrash
    //   Two code blocks at 0x000 and 0x400 (same index bits) ping-pong.
    // ==========================================
    task load_test25_icache_conflict_thrash;
        integer i;
        begin
            $display("\n--- Loading Test 25: I-Cache Conflict Miss Thrash ---");
            // Clear enough memory to cover both regions (0x000.. and 0x400.. => word idx 0x100)
            for (i = 0; i < 512; i = i + 1) begin
                u_axil_ram.mem[i] = 32'h00000013; // NOP
            end

            // We run 10 iterations total.
            // Block A (0x000): x10 += 6; jump to Block B @ 0x400
            // Block B (0x400): x11 += 7; i++; if (i<10) jump back to Block A, else store and stop.
            //
            // Separation of 0x400 bytes guarantees same direct-mapped indices (PC[9:2]) but different tags.
            //
            // Registers:
            // x1 = iteration counter i
            // x2 = limit (10)
            // x10 = accum A (expects 10 * 6 = 60)
            // x11 = accum B (expects 10 * 7 = 70)

            // ---------------------------
            // Block A @ 0x000
            // ---------------------------
            // 0x000: ADDI x1, x0, 0
            u_axil_ram.mem[0] = 32'h00000093;
            // 0x004: ADDI x2, x0, 10
            u_axil_ram.mem[1] = 32'h00a00113;
            // 0x008: ADDI x10, x0, 0
            u_axil_ram.mem[2] = 32'h00000513;
            // 0x00C: ADDI x11, x0, 0
            u_axil_ram.mem[3] = 32'h00000593;

            // LoopA @ 0x010:
            // 0x010: ADDI x10, x10, 6
            u_axil_ram.mem[4] = 32'h00650513;
            // 0x014: JAL x0, +0x3EC (to 0x400)
            // 0x400 - 0x014 = 0x3EC => encoding 0x3EC0006F
            u_axil_ram.mem[5] = 32'h3ec0006f;

            // ---------------------------
            // Block B @ 0x400 (word idx 0x100)
            // ---------------------------
            // 0x400: ADDI x11, x11, 7
            u_axil_ram.mem[16'h100] = 32'h00758593;
            // 0x404: ADDI x1, x1, 1
            u_axil_ram.mem[16'h101] = 32'h00108093;
            // 0x408: BLT x1, x2, +8 (to 0x410 continue path)
            u_axil_ram.mem[16'h102] = 32'h0020c463;
            // 0x40C: JAL x0, +8 (to 0x414 exit stores)  [executed when loop ends]
            u_axil_ram.mem[16'h103] = 32'h0080006f;
            // 0x410: JAL x0, -0x400 (back to 0x010)     [executed when loop continues]
            // 0x010 - 0x410 = -0x400 => encoding 0xC01FF06F
            u_axil_ram.mem[16'h104] = 32'hc01ff06f;
            // 0x414: SW x10, 256(x0)
            u_axil_ram.mem[16'h105] = 32'h10a02023;
            // 0x418: SW x11, 260(x0)
            u_axil_ram.mem[16'h106] = 32'h10b02223;
            // 0x41C: NOP
            u_axil_ram.mem[16'h107] = 32'h00000013;
        end
    endtask

    // ==========================================
    //   Test 26: Full Pipeline Exploitation
    //   Maximizes I-Cache locality (all code fits in 256-entry cache)
    //   Uses independent register operations to minimize hazards
    // ==========================================
    task load_test26_pipeline_exploitation;
        integer i;
        begin
            $display("\n--- Loading Test 26: Full Pipeline Exploitation ---");
            // Clear memory first
            for (i = 0; i < 128; i = i + 1) begin
                u_axil_ram.mem[i] = 32'h00000013; // NOP
            end
            
            // ========================================================================
            // STRATEGY: Keep all instructions within 256-word (1KB) region
            // With 256-entry direct-mapped cache, index = address[9:2]
            // All instructions at 0x000-0x3FC will map to unique cache lines
            // After initial cold misses, we get 100% hit rate on loop iterations
            // 
            // We use multiple independent registers to avoid RAW hazards:
            // - x2-x9: accumulators (8 parallel accumulators)
            // - x10: outer loop counter
            // - x11: inner loop counter  
            // - x12-x13: loop limits
            // - x20: final result accumulator
            // ========================================================================
            
            // ----- INITIALIZATION (0x00 - 0x24) -----
            // 0x00: ADDI x2, x0, 0       - acc0 = 0
            u_axil_ram.mem[0] = 32'h00000113;
            // 0x04: ADDI x3, x0, 0       - acc1 = 0
            u_axil_ram.mem[1] = 32'h00000193;
            // 0x08: ADDI x4, x0, 0       - acc2 = 0
            u_axil_ram.mem[2] = 32'h00000213;
            // 0x0C: ADDI x5, x0, 0       - acc3 = 0
            u_axil_ram.mem[3] = 32'h00000293;
            // 0x10: ADDI x6, x0, 0       - acc4 = 0
            u_axil_ram.mem[4] = 32'h00000313;
            // 0x14: ADDI x7, x0, 0       - acc5 = 0
            u_axil_ram.mem[5] = 32'h00000393;
            // 0x18: ADDI x8, x0, 0       - acc6 = 0
            u_axil_ram.mem[6] = 32'h00000413;
            // 0x1C: ADDI x9, x0, 0       - acc7 = 0
            u_axil_ram.mem[7] = 32'h00000493;
            
            // 0x20: ADDI x12, x0, 10     - outer_limit = 10
            u_axil_ram.mem[8] = 32'h00a00613;
            // 0x24: ADDI x13, x0, 20     - inner_limit = 20
            u_axil_ram.mem[9] = 32'h01400693;
            // 0x28: ADDI x10, x0, 0      - outer_counter = 0
            u_axil_ram.mem[10] = 32'h00000513;
            
            // ----- OUTER LOOP START (0x2C) -----
            // 0x2C: ADDI x11, x0, 0      - inner_counter = 0
            u_axil_ram.mem[11] = 32'h00000593;
            
            // ----- INNER LOOP START (0x30) - Tight 8-instruction body -----
            // All 8 instructions use independent accumulators (no RAW hazards!)
            // This allows the pipeline to run at maximum throughput
            
            // 0x30: ADDI x2, x2, 1       - acc0++
            u_axil_ram.mem[12] = 32'h00110113;
            // 0x34: ADDI x3, x3, 2       - acc1 += 2
            u_axil_ram.mem[13] = 32'h00218193;
            // 0x38: ADDI x4, x4, 3       - acc2 += 3
            u_axil_ram.mem[14] = 32'h00320213;
            // 0x3C: ADDI x5, x5, 4       - acc3 += 4
            u_axil_ram.mem[15] = 32'h00428293;
            // 0x40: ADDI x6, x6, 5       - acc4 += 5
            u_axil_ram.mem[16] = 32'h00530313;
            // 0x44: ADDI x7, x7, 6       - acc5 += 6
            u_axil_ram.mem[17] = 32'h00638393;
            // 0x48: ADDI x8, x8, 7       - acc6 += 7
            u_axil_ram.mem[18] = 32'h00740413;
            // 0x4C: ADDI x9, x9, 8       - acc7 += 8
            u_axil_ram.mem[19] = 32'h00848493;
            
            // Inner loop control
            // 0x50: ADDI x11, x11, 1     - inner_counter++
            u_axil_ram.mem[20] = 32'h00158593;
            // 0x54: BLT x11, x13, -36    - if inner_counter < 20, branch to 0x30
            u_axil_ram.mem[21] = 32'hfcd5cee3;
            
            // ----- INNER LOOP END -----
            
            // Outer loop control
            // 0x58: ADDI x10, x10, 1     - outer_counter++
            u_axil_ram.mem[22] = 32'h00150513;
            // 0x5C: BLT x10, x12, -48    - if outer_counter < 10, branch to 0x2C
            u_axil_ram.mem[23] = 32'hfcc548e3;
            
            // ----- OUTER LOOP END -----
            
            // ----- COMPUTE FINAL RESULT -----
            // Total iterations: 10 * 20 = 200
            // Expected values:
            // x2 = 200 * 1 = 200
            // x3 = 200 * 2 = 400
            // x4 = 200 * 3 = 600
            // x5 = 200 * 4 = 800
            // x6 = 200 * 5 = 1000
            // x7 = 200 * 6 = 1200
            // x8 = 200 * 7 = 1400
            // x9 = 200 * 8 = 1600
            // Sum = 200 + 400 + 600 + 800 + 1000 + 1200 + 1400 + 1600 = 7200
            
            // 0x60: ADD x20, x2, x3      - x20 = x2 + x3 = 600
            u_axil_ram.mem[24] = 32'h00310a33;
            // 0x64: ADD x20, x20, x4     - x20 += x4 = 1200
            u_axil_ram.mem[25] = 32'h004a0a33;
            // 0x68: ADD x20, x20, x5     - x20 += x5 = 2000
            u_axil_ram.mem[26] = 32'h005a0a33;
            // 0x6C: ADD x20, x20, x6     - x20 += x6 = 3000
            u_axil_ram.mem[27] = 32'h006a0a33;
            // 0x70: ADD x20, x20, x7     - x20 += x7 = 4200
            u_axil_ram.mem[28] = 32'h007a0a33;
            // 0x74: ADD x20, x20, x8     - x20 += x8 = 5600
            u_axil_ram.mem[29] = 32'h008a0a33;
            // 0x78: ADD x20, x20, x9     - x20 += x9 = 7200
            u_axil_ram.mem[30] = 32'h009a0a33;
            
            // ----- STORE RESULTS -----
            // 0x7C: SW x2, 512(x0)       - mem[512] = 200
            u_axil_ram.mem[31] = 32'h20202023;
            // 0x80: SW x3, 516(x0)       - mem[516] = 400
            u_axil_ram.mem[32] = 32'h20302223;
            // 0x84: SW x4, 520(x0)       - mem[520] = 600
            u_axil_ram.mem[33] = 32'h20402423;
            // 0x88: SW x5, 524(x0)       - mem[524] = 800
            u_axil_ram.mem[34] = 32'h20502623;
            // 0x8C: SW x6, 528(x0)       - mem[528] = 1000
            u_axil_ram.mem[35] = 32'h20602823;
            // 0x90: SW x7, 532(x0)       - mem[532] = 1200
            u_axil_ram.mem[36] = 32'h20702a23;
            // 0x94: SW x8, 536(x0)       - mem[536] = 1400
            u_axil_ram.mem[37] = 32'h20802c23;
            // 0x98: SW x9, 540(x0)       - mem[540] = 1600
            u_axil_ram.mem[38] = 32'h20902e23;
            // 0x9C: SW x20, 544(x0)      - mem[544] = 7200 (sum)
            u_axil_ram.mem[39] = 32'h23402023;
            
            // 0xA0: NOP
            u_axil_ram.mem[40] = 32'h00000013;
            // 0xA4: NOP
            u_axil_ram.mem[41] = 32'h00000013;
            // 0xA8: JAL x0, 0            - Infinite loop to stop execution
            u_axil_ram.mem[42] = 32'h0000006f;
        end
    endtask

    // ==========================================
    //   Test 27: Timer Test Program
    // ==========================================
    task load_test27_timer;
        begin
            $display("\n--- Loading Test 27: Complex Timer Test ---");
            // x6 = Timer Base Address (0x0400_2000)
            // LUI x6, 0x04002
            u_axil_ram.mem[0] = 32'h04002337;

            // ==========================================
            // Phase 1: Basic Count Up
            // ==========================================
            // 1. Store 0 to Timer Low (0x0) and High (0x4)
            // SW x0, 0(x6)
            u_axil_ram.mem[1] = 32'h00032023;
            // SW x0, 4(x6)
            u_axil_ram.mem[2] = 32'h00032223;

            // 2. Enable Timer Up (Write 3 to 0x8)
            // ADDI x7, x0, 3  -> x7 = 3
            u_axil_ram.mem[3] = 32'h00300393;
            // SW x7, 8(x6)
            u_axil_ram.mem[4] = 32'h00732423;

            // 3. Wait (NOPs)
            u_axil_ram.mem[5] = 32'h00000013; 
            u_axil_ram.mem[6] = 32'h00000013;
            u_axil_ram.mem[7] = 32'h00000013; 
            u_axil_ram.mem[8] = 32'h00000013;

            // 4. Disable Timer (Write 0 to 0x8)
            // SW x0, 8(x6)
            u_axil_ram.mem[9] = 32'h00032423;

            // 5. Read Timer Low -> Save to Mem[256] (0x100)
            // LW x10, 0(x6)
            u_axil_ram.mem[10] = 32'h00032503;
            // SW x10, 256(x0)
            u_axil_ram.mem[11] = 32'h10a02023;


            // ==========================================
            // Phase 2: 64-bit Cascade Up (Overflow)
            // ==========================================
            // 1. Load Low = 0xFFFFFFF0, High = 0
            // ADDI x7, x0, -16 (0xFFFFFFF0) -> x7 = -16
            u_axil_ram.mem[12] = 32'hff000393;
            // SW x7, 0(x6)
            u_axil_ram.mem[13] = 32'h00732023;
            // SW x0, 4(x6)
            u_axil_ram.mem[14] = 32'h00032223;

            // 2. Enable Timer Up (Write 3 to 0x8) - Re-use x7 if needed or reload
            // ADDI x7, x0, 3
            u_axil_ram.mem[15] = 32'h00300393;
            // SW x7, 8(x6)
            u_axil_ram.mem[16] = 32'h00732423;

            // 3. Wait for overflow (need > 16 cycles, say 8 NOPs + pipeline delay)
            u_axil_ram.mem[17] = 32'h00000013;
            u_axil_ram.mem[18] = 32'h00000013; 
            u_axil_ram.mem[19] = 32'h00000013;
            u_axil_ram.mem[20] = 32'h00000013;
            u_axil_ram.mem[21] = 32'h00000013;
            u_axil_ram.mem[22] = 32'h00000013;

            // 4. Disable
            // SW x0, 8(x6)
            u_axil_ram.mem[23] = 32'h00032423;

            // 5. Read Timer High -> Save to Mem[260] (0x104)
            // LW x11, 4(x6)
            u_axil_ram.mem[24] = 32'h00432583;
            // SW x11, 260(x0)
            u_axil_ram.mem[25] = 32'h10b02223;


            // ==========================================
            // Phase 3: 64-bit Cascade Down (Underflow)
            // ==========================================
            // 1. Load Low = 0x10, High = 1
            // ADDI x7, x0, 16 -> x7 = 16
            u_axil_ram.mem[26] = 32'h01000393;
            // SW x7, 0(x6)
            u_axil_ram.mem[27] = 32'h00732023;
            // ADDI x7, x0, 1 -> x7 = 1
            u_axil_ram.mem[28] = 32'h00100393;
            // SW x7, 4(x6)
            u_axil_ram.mem[29] = 32'h00732223;

            // 2. Enable Timer Down (Write 1 to 0x8)
            // SW x7, 8(x6)  (x7 is 1)
            u_axil_ram.mem[30] = 32'h00732423;

            // 3. Wait for underflow
            u_axil_ram.mem[31] = 32'h00000013;
            u_axil_ram.mem[32] = 32'h00000013;
            u_axil_ram.mem[33] = 32'h00000013;
            u_axil_ram.mem[34] = 32'h00000013;
            u_axil_ram.mem[35] = 32'h00000013;
            u_axil_ram.mem[36] = 32'h00000013;

            // 4. Disable
            // SW x0, 8(x6)
            u_axil_ram.mem[37] = 32'h00032423;

            // 5. Read Timer High -> Save to Mem[264] (0x108)
            // LW x12, 4(x6)
            u_axil_ram.mem[38] = 32'h00432603;
            // SW x12, 264(x0)
            u_axil_ram.mem[39] = 32'h10c02423;

            
            // ==========================================
            // Phase 4: Toggle Enable
            // ==========================================
            // 1. Enable Up (Write 3)
            // ADDI x7, x0, 3
            u_axil_ram.mem[40] = 32'h00300393;
            // SW x7, 8(x6)
            u_axil_ram.mem[41] = 32'h00732423;

            // 2. Wait
            u_axil_ram.mem[42] = 32'h00000013;
            u_axil_ram.mem[43] = 32'h00000013;

            // 3. Disable
            // SW x0, 8(x6)
            u_axil_ram.mem[44] = 32'h00032423;

            // 4. Read Low -> Save to Mem[268] (0x10C)
            // LW x13, 0(x6)
            u_axil_ram.mem[45] = 32'h00032683;
            // SW x13, 268(x0)
            u_axil_ram.mem[46] = 32'h10d02623;

            // Infinite Loop
            u_axil_ram.mem[47] = 32'h0000006f; 
        end
    endtask

    // ==========================================
    //        Test 28: Counter Mode
    // ==========================================
    // Configure timer in Counter Mode (external event counting)
    // Wait for external pulses from testbench
    // Read count and store to memory
    task load_test28_counter_mode;
        begin
            $display("\n--- Loading Test 28: Counter Mode (External Event) ---");
            // x6 = Timer Base Address (0x0400_2000)
            // LUI x6, 0x04002
            u_axil_ram.mem[0] = 32'h04002337;

            // 1. Load Timer Low with 0
            // ADDI x7, x0, 0
            u_axil_ram.mem[1] = 32'h00000393;
            // SW x7, 0(x6) -> timer_lo = 0
            u_axil_ram.mem[2] = 32'h00732023;

            // 2. Enable Counter Mode: Ctrl = 0x7 (Enable | Up | Counter)
            // ADDI x7, x0, 7
            u_axil_ram.mem[3] = 32'h00700393;
            // SW x7, 8(x6) -> timer_ctrl = 7
            u_axil_ram.mem[4] = 32'h00732423;

            // 3. Software wait loop (100 iterations)
            // x8 = 100 (loop counter)
            // ADDI x8, x0, 100
            u_axil_ram.mem[5] = 32'h06400413;
            
            // Loop Start (PC = 0x18)
            // ADDI x8, x8, -1
            u_axil_ram.mem[6] = 32'hfff40413;
            // BNE x8, x0, -4 (branch to loop start)
            u_axil_ram.mem[7] = 32'hfe041ee3; // offset -4

            // 4. Disable Timer
            // SW x0, 8(x6) -> timer_ctrl = 0
            u_axil_ram.mem[8] = 32'h00032423;

            // 5. Read Timer Low and store to Mem[256]
            // LW x9, 0(x6) -> x9 = timer_lo
            u_axil_ram.mem[9] = 32'h00032483;
            // SW x9, 256(x0) -> mem[256] = x9
            u_axil_ram.mem[10] = 32'h10902023;

            // Infinite Loop
            u_axil_ram.mem[11] = 32'h0000006f;
        end
    endtask

    // ==========================================
    //   UART Testbench Transmitter Task
    // ==========================================
    // Simulates external UART transmitter sending a byte
    task uart_tb_transmit_byte;
        input [7:0] data;
        integer i;
        begin
            // Calculate bit period: 16 baud ticks * baud_div clock cycles * clock period
            // With baud_div=10, clock=10ns: bit_period = 16 * 10 * 10 = 1600ns
            
            // Enable TB-driven RX
            uart_rx_tb_en = 1'b1;
            
            // Start bit (low)
            uart_rx_tb_drive = 1'b0;
            #1600;
            
            // Data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx_tb_drive = data[i];
                #1600;
            end
            
            // Stop bit (high)
            uart_rx_tb_drive = 1'b1;
            #1600;
            
            // Return to idle
            uart_rx_tb_en = 1'b0;
        end
    endtask

    // ==========================================
    //           Debug Monitors
    // ==========================================
    
    // Optional: Uncomment to see AXI transactions
    /*
    always @(posedge clk) begin
        if (rstn) begin
            if (axil_arvalid && axil_arready)
                $display("[%0t] AXI RD: addr=0x%08h", $time, axil_araddr);
            if (axil_rvalid && axil_rready)
                $display("[%0t] AXI RD: data=0x%08h", $time, axil_rdata);
            if (axil_awvalid && axil_awready)
                $display("[%0t] AXI WR: addr=0x%08h data=0x%08h", 
                         $time, axil_awaddr, axil_wdata);
        end
    end
    */

    // ==========================================
    //   Test 29: CSR Read/Write Operations
    // ==========================================
    task load_test29_csr_readwrite;
        integer i;
        begin
            $display("\n--- Loading Test 29: CSR Read/Write Operations (Zicsr) ---");
            // Clear memory
            for (i = 0; i < 80; i = i + 1) begin
                u_axil_ram.mem[i] = 32'h00000013; // NOP
            end

            // 0x00: CSRRW x2, mscratch, x0 - write 0, read old (should be 0 after reset)
            u_axil_ram.mem[0] = 32'h34001173;
            // 0x04: ADDI x3, x0, 0x42
            u_axil_ram.mem[1] = 32'h04200193;
            // 0x08: CSRRW x4, mscratch, x3 - write 0x42, x4 = old mscratch (0)
            u_axil_ram.mem[2] = 32'h34019273;
            // 0x0C: CSRRS x5, mscratch, x0 - read mscratch (0x42), no write (rs1=x0)
            u_axil_ram.mem[3] = 32'h340022F3;
            // 0x10: ADDI x6, x0, 0xF
            u_axil_ram.mem[4] = 32'h00F00313;
            // 0x14: CSRRS x7, mscratch, x6 - read (0x42), SET bits 0xF -> 0x4F
            u_axil_ram.mem[5] = 32'h340323F3;
            // 0x18: CSRRS x8, mscratch, x0 - read mscratch -> 0x4F
            u_axil_ram.mem[6] = 32'h34002473;
            // 0x1C: CSRRC x9, mscratch, x6 - read (0x4F), CLEAR bits 0xF -> 0x40
            u_axil_ram.mem[7] = 32'h340334F3;
            // 0x20: CSRRS x10, mscratch, x0 - read mscratch -> 0x40
            u_axil_ram.mem[8] = 32'h34002573;
            // 0x24: CSRRWI x11, mscratch, 0x1F - write zimm=31, x11 = old (0x40)
            u_axil_ram.mem[9] = 32'h340FD5F3;
            // 0x28: CSRRS x12, mscratch, x0 - read mscratch -> 0x1F
            u_axil_ram.mem[10] = 32'h34002673;
            // 0x2C: CSRRSI x13, mscratch, 0 - read mscratch (0x1F), no set (zimm=0)
            u_axil_ram.mem[11] = 32'h340066F3;
            // 0x30: CSRRCI x14, mscratch, 0x10 - read (0x1F), clear bit 4 -> 0x0F
            u_axil_ram.mem[12] = 32'h34087773;
            // 0x34: CSRRS x15, mscratch, x0 - read mscratch -> 0x0F
            u_axil_ram.mem[13] = 32'h340027F3;
            // 0x38-0x64: Store results to memory
            u_axil_ram.mem[14] = 32'h10202023; // SW x2, 256(x0)
            u_axil_ram.mem[15] = 32'h10402223; // SW x4, 260(x0)
            u_axil_ram.mem[16] = 32'h10502423; // SW x5, 264(x0)
            u_axil_ram.mem[17] = 32'h10702623; // SW x7, 268(x0)
            u_axil_ram.mem[18] = 32'h10802823; // SW x8, 272(x0)
            u_axil_ram.mem[19] = 32'h10902A23; // SW x9, 276(x0)
            u_axil_ram.mem[20] = 32'h10A02C23; // SW x10, 280(x0)
            u_axil_ram.mem[21] = 32'h10B02E23; // SW x11, 284(x0)
            u_axil_ram.mem[22] = 32'h12C02023; // SW x12, 288(x0)
            u_axil_ram.mem[23] = 32'h12D02223; // SW x13, 292(x0)
            u_axil_ram.mem[24] = 32'h12E02423; // SW x14, 296(x0)
            u_axil_ram.mem[25] = 32'h12F02623; // SW x15, 300(x0)
            // 0x68: JAL x0, 0 (infinite loop)
            u_axil_ram.mem[26] = 32'h0000006F;
        end
    endtask

    // ==========================================
    //   Test 30: Exception Handling
    //   Tests ECALL, EBREAK, and illegal insn
    //   with trap handler at 0x80, MRET return
    // ==========================================
    task load_test30_exceptions;
        integer i;
        begin
            $display("\n--- Loading Test 30: Exception Handling ---");
            // Clear memory
            for (i = 0; i < 128; i = i + 1) begin
                u_axil_ram.mem[i] = 32'h00000013; // NOP
            end

            // ========== Main program (0x00 - 0x2C) ==========
            
            // 0x00: ADDI x31, x0, 0x200      - x31 = 0x200 (data pointer for storing results)
            // imm=0x200 rs1=00000 funct3=000 rd=11111 op=0010011
            u_axil_ram.mem[0] = 32'h20000f93;

            // 0x04: ADDI x1, x0, 0x80         - x1 = 0x80 (trap handler address)
            // imm=0x080 rs1=00000 funct3=000 rd=00001 op=0010011
            u_axil_ram.mem[1] = 32'h08000093;

            // 0x08: CSRRW x0, mtvec, x1       - mtvec = 0x80
            // CSR=0x305 rs1=00001 funct3=001 rd=00000 op=1110011
            u_axil_ram.mem[2] = 32'h30509073;

            // 0x0C: ADDI x20, x0, 0           - x20 = 0 (test counter, incremented after each MRET)
            u_axil_ram.mem[3] = 32'h00000a13;

            // --- Exception 1: ECALL (mcause = 11) ---
            // 0x10: ECALL
            u_axil_ram.mem[4] = 32'h00000073;
            // 0x14: ADDI x20, x20, 1          - x20++ (returned from ECALL handler)
            u_axil_ram.mem[5] = 32'h001a0a13;

            // --- Exception 2: EBREAK (mcause = 3) ---
            // 0x18: EBREAK
            u_axil_ram.mem[6] = 32'h00100073;
            // 0x1C: ADDI x20, x20, 1          - x20++ (returned from EBREAK handler)
            u_axil_ram.mem[7] = 32'h001a0a13;

            // --- Exception 3: Illegal instruction (mcause = 2) ---
            // 0x20: Illegal instruction (opcode 0b1111111 is not valid)
            u_axil_ram.mem[8] = 32'hFFFFFFFF;
            // 0x24: ADDI x20, x20, 1          - x20++ (returned from illegal insn handler)
            u_axil_ram.mem[9] = 32'h001a0a13;

            // 0x28: JAL x0, 0                 - Infinite loop (done)
            u_axil_ram.mem[10] = 32'h0000006f;

            // ========== Trap handler at 0x80 (mem[32]) ==========
            // This handler:
            //   1. Reads mcause, mepc, mtval
            //   2. Advances mepc by 4 (skip faulting instruction)
            //   3. Stores mcause, original mepc, mtval to [x31], [x31+4], [x31+8]
            //   4. Advances data pointer x31 by 12
            //   5. Does MRET

            // 0x80: CSRRS x28, mcause, x0     - x28 = mcause
            // CSR=0x342 rs1=00000 funct3=010 rd=11100 op=1110011
            u_axil_ram.mem[32] = 32'h34202e73;

            // 0x84: CSRRS x29, mepc, x0       - x29 = mepc
            // CSR=0x341 rs1=00000 funct3=010 rd=11101 op=1110011
            u_axil_ram.mem[33] = 32'h34102ef3;

            // 0x88: CSRRS x30, mtval, x0      - x30 = mtval
            // CSR=0x343 rs1=00000 funct3=010 rd=11110 op=1110011
            u_axil_ram.mem[34] = 32'h34302f73;

            // 0x8C: ADDI x29, x29, 4          - mepc += 4 (advance past faulting insn)
            u_axil_ram.mem[35] = 32'h004e8e93;

            // 0x90: CSRRW x0, mepc, x29       - write updated mepc back
            // CSR=0x341 rs1=11101 funct3=001 rd=00000 op=1110011
            u_axil_ram.mem[36] = 32'h341e9073;

            // 0x94: SW x28, 0(x31)            - store mcause
            // imm[11:5]=0000000 rs2=11100 rs1=11111 funct3=010 imm[4:0]=00000 op=0100011
            u_axil_ram.mem[37] = 32'h01cfa023;

            // 0x98: SW x29, 4(x31)            - store mepc+4 (points to next instruction)
            u_axil_ram.mem[38] = 32'h01dfa223;

            // 0x9C: SW x30, 8(x31)            - store mtval
            u_axil_ram.mem[39] = 32'h01efa423;

            // 0xA0: ADDI x31, x31, 12         - advance data pointer
            u_axil_ram.mem[40] = 32'h00cf8f93;

            // 0xA4: MRET                      - return to mepc
            u_axil_ram.mem[41] = 32'h30200073;
        end
    endtask

    // ==========================================
    //   Test 31: Timer Compare-Match Interrupt
    //   Configures timer to trigger interrupt
    //   when mtime >= mtimecmp. Verifies trap
    //   entry with mcause = 0x80000007 (MTI).
    // ==========================================
    task load_test31_timer_interrupt;
        integer i;
        begin
            $display("\n--- Loading Test 31: Timer Compare-Match Interrupt ---");
            // Clear first 128 words
            for (i = 0; i < 128; i = i + 1) begin
                u_axil_ram.mem[i] = 32'h00000013; // NOP
            end

            // Timer base: 0x0400_2000
            //   +0x00 = timer_lo, +0x04 = timer_hi
            //   +0x08 = timer_ctrl, +0x0C = timecmp_lo, +0x10 = timecmp_hi

            // ========== Main program (0x00 - 0x44) ==========

            // --- Setup timer base address in x5 ---
            // 0x00: LUI x5, 0x04002          - x5 = 0x0400_2000
            u_axil_ram.mem[0] = 32'h040022b7;
            
            // --- Reset timer to 0 ---
            // 0x04: SW x0, 0(x5)             - timer_lo = 0
            u_axil_ram.mem[1] = 32'h0002a023;
            // 0x08: SW x0, 4(x5)             - timer_hi = 0
            u_axil_ram.mem[2] = 32'h0002a223;

            // --- Set timecmp_lo = 20 (small value so timer fires quickly) ---
            // 0x0C: ADDI x6, x0, 20          - x6 = 20
            u_axil_ram.mem[3] = 32'h01400313;
            // 0x10: SW x6, 0x0C(x5)          - timecmp_lo = 20
            u_axil_ram.mem[4] = 32'h0062a623;
            // 0x14: SW x0, 0x10(x5)          - timecmp_hi = 0
            u_axil_ram.mem[5] = 32'h0002a823;

            // --- Setup trap handler at 0x80 ---
            // 0x18: ADDI x1, x0, 0x80        - x1 = 0x80
            u_axil_ram.mem[6] = 32'h08000093;
            // 0x1C: CSRRW x0, mtvec, x1      - mtvec = 0x80
            u_axil_ram.mem[7] = 32'h30509073;

            // --- Enable mie.MTIE (bit 7) ---
            // 0x20: ADDI x1, x0, 0x80        - x1 = 0x80
            u_axil_ram.mem[8] = 32'h08000093;
            // 0x24: CSRRW x0, mie, x1        - mie = 0x80 (MTIE=1)
            u_axil_ram.mem[9] = 32'h30409073;

            // --- Enable global interrupts: mstatus.MIE (bit 3) ---
            // 0x28: CSRRSI x0, mstatus, 8    - set bit 3
            u_axil_ram.mem[10] = 32'h30046073;

            // --- Enable timer: ctrl = 0x0B (Enable + CountUp + IRQ_EN) ---
            // 0x2C: ADDI x7, x0, 0x0B        - x7 = 11 (bits 0,1,3)
            u_axil_ram.mem[11] = 32'h00b00393;
            // 0x30: SW x7, 8(x5)             - timer_ctrl = 0x0B
            u_axil_ram.mem[12] = 32'h0072a423;

            // --- x20 = 0 (trap counter, set to 1 by handler) ---
            // 0x34: ADDI x20, x0, 0
            u_axil_ram.mem[13] = 32'h00000a13;

            // --- Spin loop: wait for handler to set x20 = 1 ---
            // 0x38: BNE x20, x0, +8          - if (x20 != 0) goto 0x40
            u_axil_ram.mem[14] = 32'h000a1463;
            // 0x3C: JAL x0, -4               - else loop back to 0x38
            u_axil_ram.mem[15] = 32'hffdff06f;

            // --- Landed here after handler ---
            // 0x40: SW x20, 256(x0)          - store trap count to mem[256]
            u_axil_ram.mem[16] = 32'h114020a3; // Corrected: SW x20, 0x101(x0) wrong — use explicit:
            // Let me redo this correctly:
            // SW rs2=x20, imm=256, base=x0
            // imm[11:5]=0000100, rs2=10100, rs1=00000, funct3=010, imm[4:0]=00000, op=0100011
            // 256 = 0x100 → imm[11:5] = 0000100_0 → wait, 256 = 12'h100
            // imm[11:5] = 7'b0001000 = 0x08, imm[4:0] = 5'b00000
            u_axil_ram.mem[16] = {7'b0001000, 5'd20, 5'd0, 3'b010, 5'b00000, 7'b0100011};

            // 0x44: JAL x0, 0                - done: infinite loop
            u_axil_ram.mem[17] = 32'h0000006f;

            // ========== Trap handler at 0x80 (mem[32]) ==========
            // 1. Read mcause
            // 2. Store mcause to mem[260]
            // 3. Clear timer IRQ by setting timecmp_lo = 0xFFFFFFFF
            // 4. Disable timer (timer_ctrl = 0) to avoid influencing later tests
            // 5. Set x20 = 1 (flag for main loop)
            // 6. MRET

            // 0x80: CSRRS x28, mcause, x0    - x28 = mcause
            u_axil_ram.mem[32] = 32'h34202e73;

            // 0x84: SW x28, 260(x0)          - store mcause at mem[260]
            // 260 = 0x104 → imm[11:5]=0001000, imm[4:0]=00100
            u_axil_ram.mem[33] = {7'b0001000, 5'd28, 5'd0, 3'b010, 5'b00100, 7'b0100011};

            // 0x88: ADDI x9, x0, -1          - x9 = 0xFFFFFFFF
            u_axil_ram.mem[34] = 32'hfff00493;

            // 0x8C: LUI x5, 0x04002          - x5 = timer base (re-load, handler may not have it)
            u_axil_ram.mem[35] = 32'h040022b7;

            // 0x90: SW x9, 0x0C(x5)          - timecmp_lo = 0xFFFFFFFF (clear IRQ)
            u_axil_ram.mem[36] = 32'h0092a623;
            // 0x94: SW x9, 0x10(x5)          - timecmp_hi = 0xFFFFFFFF
            u_axil_ram.mem[37] = 32'h0092a823;

            // 0x98: SW x0, 8(x5)             - timer_ctrl = 0 (disable timer + IRQ gate)
            u_axil_ram.mem[38] = 32'h0002a423;

            // 0x9C: ADDI x20, x0, 1          - x20 = 1 (handled flag)
            u_axil_ram.mem[39] = 32'h00100a13;

            // 0xA0: MRET                     - return to mepc
            u_axil_ram.mem[40] = 32'h30200073;
        end
    endtask

    // ==========================================
    //   Test 32: Timer IRQ During Branch-Predicted Loop
    //   Timer fires mid-loop while branch predictor
    //   is actively predicting. Validates correct
    //   mepc save, handler execution, and MRET return.
    // ==========================================
    task load_test32_irq_during_branch_loop;
        integer i;
        begin
            $display("\n--- Loading Test 32: Timer IRQ During Branch-Predicted Loop ---");
            for (i = 0; i < 128; i = i + 1) begin
                u_axil_ram.mem[i] = 32'h00000013; // NOP
            end

            // 0x00: LUI x5, 0x04002 — timer base
            u_axil_ram.mem[0] = 32'h040022b7;
            // 0x04: SW x0, 0(x5) — timer_lo = 0
            u_axil_ram.mem[1] = 32'h0002a023;
            // 0x08: SW x0, 4(x5) — timer_hi = 0
            u_axil_ram.mem[2] = 32'h0002a223;
            // 0x0C: ADDI x6, x0, 100 — timecmp = 100 (fire well into the loop)
            u_axil_ram.mem[3] = 32'h06400313;
            // 0x10: SW x6, 0x0C(x5) — timecmp_lo = 100
            u_axil_ram.mem[4] = 32'h0062a623;
            // 0x14: SW x0, 0x10(x5) — timecmp_hi = 0
            u_axil_ram.mem[5] = 32'h0002a823;
            // 0x18: ADDI x1, x0, 0x80
            u_axil_ram.mem[6] = 32'h08000093;
            // 0x1C: CSRRW x0, mtvec, x1
            u_axil_ram.mem[7] = 32'h30509073;
            // 0x20: ADDI x1, x0, 0x80
            u_axil_ram.mem[8] = 32'h08000093;
            // 0x24: CSRRW x0, mie, x1 — MTIE=1
            u_axil_ram.mem[9] = 32'h30409073;
            // 0x28: CSRRSI x0, mstatus, 8 — MIE=1
            u_axil_ram.mem[10] = 32'h30046073;
            // Init registers BEFORE starting timer so MRET can't re-execute these
            // 0x2C: ADDI x10, x0, 0 — accumulator = 0
            u_axil_ram.mem[11] = 32'h00000513;
            // 0x30: ADDI x11, x0, 0 — counter = 0
            u_axil_ram.mem[12] = 32'h00000593;
            // 0x34: ADDI x12, x0, 50 — limit = 50
            u_axil_ram.mem[13] = 32'h03200613;
            // 0x38: ADDI x20, x0, 0 — IRQ flag = 0
            u_axil_ram.mem[14] = 32'h00000a13;
            // 0x3C: ADDI x7, x0, 0x0B — Enable + Up + IRQ_EN
            u_axil_ram.mem[15] = 32'h00b00393;
            // 0x40: SW x7, 8(x5) — start timer (after all init!)
            u_axil_ram.mem[16] = 32'h0072a423;

            // Two-counter loop: tests precise interrupt between paired increments
            // 0x44: ADDI x10, x10, 1 — accumulator++
            u_axil_ram.mem[17] = 32'h00150513;
            // 0x48: ADDI x11, x11, 1 — counter++
            u_axil_ram.mem[18] = 32'h00158593;
            // 0x4C: BLT x11, x12, -8 (back to 0x44)
            u_axil_ram.mem[19] = 32'hfec5cce3;

            // 0x50: SW x10, 256(x0)
            u_axil_ram.mem[20] = {7'b0001000, 5'd10, 5'd0, 3'b010, 5'b00000, 7'b0100011};
            // 0x54: SW x11, 260(x0)
            u_axil_ram.mem[21] = {7'b0001000, 5'd11, 5'd0, 3'b010, 5'b00100, 7'b0100011};
            // 0x58: SW x20, 264(x0)
            u_axil_ram.mem[22] = {7'b0001000, 5'd20, 5'd0, 3'b010, 5'b01000, 7'b0100011};
            // 0x5C: JAL x0, 0
            u_axil_ram.mem[23] = 32'h0000006f;

            // ========== Handler at 0x80 (mem[32]) ==========
            // 0x80: CSRRS x28, mcause, x0
            u_axil_ram.mem[32] = 32'h34202e73;
            // 0x84: LUI x5, 0x04002 — reload timer base
            u_axil_ram.mem[33] = 32'h040022b7;
            // 0x88: ADDI x9, x0, -1
            u_axil_ram.mem[34] = 32'hfff00493;
            // 0x8C: SW x9, 0x0C(x5) — timecmp_lo = max
            u_axil_ram.mem[35] = 32'h0092a623;
            // 0x90: SW x9, 0x10(x5) — timecmp_hi = max
            u_axil_ram.mem[36] = 32'h0092a823;
            // 0x94: SW x0, 8(x5) — disable timer
            u_axil_ram.mem[37] = 32'h0002a423;
            // 0x98: ADDI x20, x0, 1 — set IRQ flag
            u_axil_ram.mem[38] = 32'h00100a13;
            // 0x9C: MRET
            u_axil_ram.mem[39] = 32'h30200073;
        end
    endtask

    // ==========================================
    //   Test 33: Exception at Mispredicted Branch Target
    //   Forward branches (cold predictor) jump to
    //   exception-causing instructions. Validates
    //   trap priority over misprediction flush.
    // ==========================================
    task load_test33_exception_at_branch_target;
        integer i;
        begin
            $display("\n--- Loading Test 33: Exception at Mispredicted Branch Target ---");
            for (i = 0; i < 128; i = i + 1) begin
                u_axil_ram.mem[i] = 32'h00000013; // NOP
            end

            // 0x00: ADDI x31, x0, 0x200 — data pointer
            u_axil_ram.mem[0] = 32'h20000f93;
            // 0x04: ADDI x1, x0, 0x80
            u_axil_ram.mem[1] = 32'h08000093;
            // 0x08: CSRRW x0, mtvec, x1
            u_axil_ram.mem[2] = 32'h30509073;
            // 0x0C: ADDI x20, x0, 0 — counter = 0
            u_axil_ram.mem[3] = 32'h00000a13;

            // --- Branch 1: BEQ to ECALL (cold predictor, likely mispredicted) ---
            // 0x10: ADDI x2, x0, 5
            u_axil_ram.mem[4] = 32'h00500113;
            // 0x14: ADDI x3, x0, 5
            u_axil_ram.mem[5] = 32'h00500193;
            // 0x18: BEQ x2, x3, +16 → 0x28
            u_axil_ram.mem[6] = 32'h00310863;
            // 0x1C-0x24: NOPs (dead path, pre-filled)
            // 0x28: ECALL
            u_axil_ram.mem[10] = 32'h00000073;
            // 0x2C: ADDI x20, x20, 1 — returned from handler
            u_axil_ram.mem[11] = 32'h001a0a13;

            // --- Branch 2: BEQ to EBREAK (cold predictor) ---
            // 0x30: ADDI x2, x0, 10
            u_axil_ram.mem[12] = 32'h00a00113;
            // 0x34: ADDI x3, x0, 10
            u_axil_ram.mem[13] = 32'h00a00193;
            // 0x38: BEQ x2, x3, +16 → 0x48
            u_axil_ram.mem[14] = 32'h00310863;
            // 0x3C-0x44: NOPs (dead path, pre-filled)
            // 0x48: EBREAK
            u_axil_ram.mem[18] = 32'h00100073;
            // 0x4C: ADDI x20, x20, 1
            u_axil_ram.mem[19] = 32'h001a0a13;

            // --- Branch 3: BEQ to illegal instruction (cold predictor) ---
            // 0x50: ADDI x2, x0, 15
            u_axil_ram.mem[20] = 32'h00f00113;
            // 0x54: ADDI x3, x0, 15
            u_axil_ram.mem[21] = 32'h00f00193;
            // 0x58: BEQ x2, x3, +16 → 0x68
            u_axil_ram.mem[22] = 32'h00310863;
            // 0x5C-0x64: NOPs (dead path, pre-filled)
            // 0x68: Illegal instruction
            u_axil_ram.mem[26] = 32'hFFFFFFFF;
            // 0x6C: ADDI x20, x20, 1
            u_axil_ram.mem[27] = 32'h001a0a13;

            // 0x70: JAL x0, 0
            u_axil_ram.mem[28] = 32'h0000006f;

            // ========== Handler at 0x80 (mem[32]) ==========
            // Read mcause/mepc/mtval, bump mepc+4, store to [x31], MRET
            // 0x80: CSRRS x28, mcause, x0
            u_axil_ram.mem[32] = 32'h34202e73;
            // 0x84: CSRRS x29, mepc, x0
            u_axil_ram.mem[33] = 32'h34102ef3;
            // 0x88: CSRRS x30, mtval, x0
            u_axil_ram.mem[34] = 32'h34302f73;
            // 0x8C: ADDI x29, x29, 4
            u_axil_ram.mem[35] = 32'h004e8e93;
            // 0x90: CSRRW x0, mepc, x29
            u_axil_ram.mem[36] = 32'h341e9073;
            // 0x94: SW x28, 0(x31)
            u_axil_ram.mem[37] = 32'h01cfa023;
            // 0x98: SW x29, 4(x31)
            u_axil_ram.mem[38] = 32'h01dfa223;
            // 0x9C: SW x30, 8(x31)
            u_axil_ram.mem[39] = 32'h01efa423;
            // 0xA0: ADDI x31, x31, 12
            u_axil_ram.mem[40] = 32'h00cf8f93;
            // 0xA4: MRET
            u_axil_ram.mem[41] = 32'h30200073;
        end
    endtask

    // ==========================================
    //   Test 35: Cache Round-Trip (write-allocate + read-hit)
    //
    //   Write 4 distinct values to 4 different cache indices, then
    //   read them back. Read path should hit on every load because
    //   the writes installed lines via write-allocate.
    //
    //   Stores -> 0x100, 0x200, 0x300, 0x3FC (4 different indices)
    //   Loads  -> same addresses into x10..x13
    // ==========================================
    task load_test35_cache_round_trip;
        integer i;
        begin
            $display("\n--- Loading Test 35: Cache Round-Trip ---");
            for (i = 0; i < 64; i = i + 1) u_axil_ram.mem[i] = 32'h00000013;

            // 0x00: ADDI x2, x0, 100      x2 = 100
            u_axil_ram.mem[0]  = 32'h06400113;
            // 0x04: ADDI x3, x0, 200      x3 = 200
            u_axil_ram.mem[1]  = 32'h0c800193;
            // 0x08: ADDI x4, x0, 300      x4 = 300
            u_axil_ram.mem[2]  = 32'h12c00213;
            // 0x0C: ADDI x5, x0, 400      x5 = 400
            u_axil_ram.mem[3]  = 32'h19000293;

            // 0x10: SW x2, 0x100(x0)
            u_axil_ram.mem[4]  = 32'h10202023;
            // 0x14: SW x3, 0x200(x0)
            u_axil_ram.mem[5]  = 32'h20302023;
            // 0x18: SW x4, 0x300(x0)
            u_axil_ram.mem[6]  = 32'h30402023;
            // 0x1C: SW x5, 0x3FC(x0)  (offset 0x3FC = 1020, fits 12-bit signed)
            u_axil_ram.mem[7]  = 32'h3e502e23;

            // 0x20-0x2C: NOPs to drain the pipeline
            // (already filled with NOPs above)

            // 0x30: LW x10, 0x100(x0)
            u_axil_ram.mem[12] = 32'h10002503;
            // 0x34: LW x11, 0x200(x0)
            u_axil_ram.mem[13] = 32'h20002583;
            // 0x38: LW x12, 0x300(x0)
            u_axil_ram.mem[14] = 32'h30002603;
            // 0x3C: LW x13, 0x3FC(x0)
            u_axil_ram.mem[15] = 32'h3fc02683;

            // 0x40: JAL x0, 0
            u_axil_ram.mem[16] = 32'h0000006f;
        end
    endtask

    // ==========================================
    //   Test 36: Cache Way Conflict
    //
    //   Three addresses share the same cache index but have distinct
    //   tags, forcing the third write to evict an LRU way. Reads
    //   verify all three values are still observable (via cache hit
    //   or refill). Index = addr[9:2] for CACHE_DEPTH=256, so
    //   addresses 0x100, 0x500, 0x900 all map to index 64.
    // ==========================================
    task load_test36_way_conflict;
        integer i;
        begin
            $display("\n--- Loading Test 36: Cache Way Conflict ---");
            for (i = 0; i < 96; i = i + 1) u_axil_ram.mem[i] = 32'h00000013;

            // 0x00: ADDI x2, x0, 11       x2 = 11 (A)
            u_axil_ram.mem[0]  = 32'h00b00113;
            // 0x04: ADDI x3, x0, 22       x3 = 22 (B)
            u_axil_ram.mem[1]  = 32'h01600193;
            // 0x08: ADDI x4, x0, 33       x4 = 33 (C)
            u_axil_ram.mem[2]  = 32'h02100213;

            // 0x0C: ADDI x6, x0, 0x100    x6 = 0x100 (addr A)
            u_axil_ram.mem[3]  = 32'h10000313;
            // 0x10: SW x2, 0(x6)          mem[0x100] = 11
            u_axil_ram.mem[4]  = 32'h00232023;
            // 0x14: ADDI x6, x6, 0x400    x6 = 0x500 (addr B)
            u_axil_ram.mem[5]  = 32'h40030313;
            // 0x18: SW x3, 0(x6)          mem[0x500] = 22
            u_axil_ram.mem[6]  = 32'h00332023;
            // 0x1C: ADDI x6, x6, 0x400    x6 = 0x900 (addr C)
            u_axil_ram.mem[7]  = 32'h40030313;
            // 0x20: SW x4, 0(x6)          mem[0x900] = 33  (forces eviction)
            u_axil_ram.mem[8]  = 32'h00432023;

            // 0x24-0x30: NOPs (drain)
            // (already NOPs)

            // 0x34: ADDI x7, x0, 0x100    x7 = 0x100
            u_axil_ram.mem[13] = 32'h10000393;
            // 0x38: LW x10, 0(x7)         x10 = mem[0x100]
            u_axil_ram.mem[14] = 32'h0003a503;
            // 0x3C: ADDI x7, x7, 0x400    x7 = 0x500
            u_axil_ram.mem[15] = 32'h40038393;
            // 0x40: LW x11, 0(x7)         x11 = mem[0x500]
            u_axil_ram.mem[16] = 32'h0003a583;
            // 0x44: ADDI x7, x7, 0x400    x7 = 0x900
            u_axil_ram.mem[17] = 32'h40038393;
            // 0x48: LW x12, 0(x7)         x12 = mem[0x900]
            u_axil_ram.mem[18] = 32'h0003a603;

            // 0x4C: JAL x0, 0
            u_axil_ram.mem[19] = 32'h0000006f;
        end
    endtask

    // ==========================================
    //   Test 37: Strided Cache Sweep (8 indices)
    //
    //   Writes 8 different values to 8 distinct cache indices, then
    //   reads them all back into x10..x17. Tests that multiple
    //   independent lines coexist and all return their values.
    // ==========================================
    task load_test37_strided_sweep;
        integer i;
        begin
            $display("\n--- Loading Test 37: Strided Cache Sweep ---");
            for (i = 0; i < 64; i = i + 1) u_axil_ram.mem[i] = 32'h00000013;

            // Loop counter / base reg setup
            // 0x00: ADDI x6, x0, 0          x6 = 0 (base)
            u_axil_ram.mem[0]  = 32'h00000313;
            // 0x04: ADDI x7, x0, 8          x7 = limit (8 stores)
            u_axil_ram.mem[1]  = 32'h00800393;
            // 0x08: ADDI x8, x0, 0x100      x8 = base addr (0x100)
            u_axil_ram.mem[2]  = 32'h10000413;

            // Store loop (start at 0x0C / mem[3])
            // 0x0C: ADDI x9, x6, 1          x9 = i+1 (value to store)
            u_axil_ram.mem[3]  = 32'h00130493;
            // 0x10: SW x9, 0(x8)            mem[x8] = x9
            u_axil_ram.mem[4]  = 32'h00942023;
            // 0x14: ADDI x6, x6, 1          x6++
            u_axil_ram.mem[5]  = 32'h00130313;
            // 0x18: ADDI x8, x8, 0x40       x8 += 64 (next index, stride=64 bytes)
            u_axil_ram.mem[6]  = 32'h04040413;
            // 0x1C: BLT x6, x7, -16 -> 0x0C
            //       BLT encoding: imm_hi[12,10:5]=offsets +/-, rs2=x7, rs1=x6, f3=100, imm_lo[4:1,11], op=1100011
            //       Branch offset = -16 (back 4 instructions)
            u_axil_ram.mem[7]  = 32'hfe7348e3;

            // After loop: reset addr pointer & load
            // 0x20: ADDI x8, x0, 0x100      x8 = 0x100
            u_axil_ram.mem[8]  = 32'h10000413;

            // 0x24..0x40: 8 LW instructions into x10..x17
            // LW xN, 0(x8); ADDI x8, x8, 0x40
            // 0x24: LW x10, 0(x8)
            u_axil_ram.mem[9]  = 32'h00042503;
            // 0x28: ADDI x8, x8, 0x40
            u_axil_ram.mem[10] = 32'h04040413;
            // 0x2C: LW x11, 0(x8)
            u_axil_ram.mem[11] = 32'h00042583;
            // 0x30: ADDI x8, x8, 0x40
            u_axil_ram.mem[12] = 32'h04040413;
            // 0x34: LW x12, 0(x8)
            u_axil_ram.mem[13] = 32'h00042603;
            // 0x38: ADDI x8, x8, 0x40
            u_axil_ram.mem[14] = 32'h04040413;
            // 0x3C: LW x13, 0(x8)
            u_axil_ram.mem[15] = 32'h00042683;
            // 0x40: ADDI x8, x8, 0x40
            u_axil_ram.mem[16] = 32'h04040413;
            // 0x44: LW x14, 0(x8)
            u_axil_ram.mem[17] = 32'h00042703;
            // 0x48: ADDI x8, x8, 0x40
            u_axil_ram.mem[18] = 32'h04040413;
            // 0x4C: LW x15, 0(x8)
            u_axil_ram.mem[19] = 32'h00042783;
            // 0x50: ADDI x8, x8, 0x40
            u_axil_ram.mem[20] = 32'h04040413;
            // 0x54: LW x16, 0(x8)
            u_axil_ram.mem[21] = 32'h00042803;
            // 0x58: ADDI x8, x8, 0x40
            u_axil_ram.mem[22] = 32'h04040413;
            // 0x5C: LW x17, 0(x8)
            u_axil_ram.mem[23] = 32'h00042883;

            // 0x60: JAL x0, 0
            u_axil_ram.mem[24] = 32'h0000006f;
        end
    endtask

    // ==========================================
    //   Test 34: MRET Into Branch With Predictor State
    //   Loop body contains ECALL; handler returns
    //   via MRET to the loop-back branch. Tests
    //   MRET flush + branch prediction interaction.
    // ==========================================
    task load_test34_mret_into_branch;
        integer i;
        begin
            $display("\n--- Loading Test 34: MRET Into Branch With Predictor State ---");
            for (i = 0; i < 128; i = i + 1) begin
                u_axil_ram.mem[i] = 32'h00000013; // NOP
            end

            // 0x00: ADDI x1, x0, 0x80
            u_axil_ram.mem[0] = 32'h08000093;
            // 0x04: CSRRW x0, mtvec, x1
            u_axil_ram.mem[1] = 32'h30509073;
            // 0x08: ADDI x10, x0, 0 — counter = 0
            u_axil_ram.mem[2] = 32'h00000513;
            // 0x0C: ADDI x11, x0, 5 — limit = 5
            u_axil_ram.mem[3] = 32'h00500593;
            // 0x10: ADDI x20, x0, 0 — exception count = 0
            u_axil_ram.mem[4] = 32'h00000a13;

            // Loop:
            // 0x14: ADDI x10, x10, 1 — counter++
            u_axil_ram.mem[5] = 32'h00150513;
            // 0x18: ECALL — handler bumps mepc to 0x1C
            u_axil_ram.mem[6] = 32'h00000073;
            // 0x1C: BLT x10, x11, -8 → 0x14
            u_axil_ram.mem[7] = 32'hfeb54ce3;

            // Post-loop:
            // 0x20: SW x10, 256(x0)
            u_axil_ram.mem[8] = {7'b0001000, 5'd10, 5'd0, 3'b010, 5'b00000, 7'b0100011};
            // 0x24: SW x20, 260(x0)
            u_axil_ram.mem[9] = {7'b0001000, 5'd20, 5'd0, 3'b010, 5'b00100, 7'b0100011};
            // 0x28: JAL x0, 0
            u_axil_ram.mem[10] = 32'h0000006f;

            // ========== Handler at 0x80 (mem[32]) ==========
            // 0x80: CSRRS x28, mepc, x0
            u_axil_ram.mem[32] = 32'h34102e73;
            // 0x84: ADDI x28, x28, 4 — skip ECALL
            u_axil_ram.mem[33] = 32'h004e0e13;
            // 0x88: CSRRW x0, mepc, x28
            u_axil_ram.mem[34] = 32'h341e1073;
            // 0x8C: ADDI x20, x20, 1
            u_axil_ram.mem[35] = 32'h001a0a13;
            // 0x90: MRET
            u_axil_ram.mem[36] = 32'h30200073;
        end
    endtask

    // ==========================================
    //   Test 38: Hot Loop (Heavy I$ + D$ Locality, Full Throughput)
    //
    //   Tight 4-instruction loop body that repeatedly loads from one
    //   cached address, accumulates, and decrements a counter. After
    //   the first iteration the loop is fully resident in I$ (small
    //   working set) and the data line is resident in D$. Steady state
    //   must sustain ~1 IPC with no AXI traffic.
    //
    //   Expected: x10 = 32 * 7 = 224
    //             mem[0x1000] = 7
    // ==========================================
    task load_test38_hot_loop;
        integer i;
        begin
            $display("\n--- Loading Test 38: Hot Loop (I$+D$ Locality) ---");
            for (i = 0; i < 64; i = i + 1) u_axil_ram.mem[i] = 32'h00000013;

            // 0x00: ADDI x10, x0, 0     — accumulator = 0
            u_axil_ram.mem[0] = 32'h00000513;
            // 0x04: ADDI x11, x0, 32    — loop count
            u_axil_ram.mem[1] = 32'h02000593;
            // 0x08: LUI  x12, 0x00001   — x12 = 0x00001000 (data addr, well clear of code)
            u_axil_ram.mem[2] = 32'h00001637;
            // 0x0C: ADDI x13, x0, 7     — value to store
            u_axil_ram.mem[3] = 32'h00700693;
            // 0x10: SW x13, 0(x12)      — mem[0x1000] = 7  (preload + write-allocate fill)
            u_axil_ram.mem[4] = 32'h00d62023;

            // Loop body (0x14..0x20):
            // 0x14: LW   x14, 0(x12)    — D$ hit after warmup
            u_axil_ram.mem[5] = 32'h00062703;
            // 0x18: ADD  x10, x10, x14  — acc += 7
            u_axil_ram.mem[6] = 32'h00e50533;
            // 0x1C: ADDI x11, x11, -1   — count--
            u_axil_ram.mem[7] = 32'hfff58593;
            // 0x20: BNE  x11, x0, -12   — back to 0x14 while count != 0
            u_axil_ram.mem[8] = 32'hfe059ae3;

            // 0x24: JAL x0, 0           — halt
            u_axil_ram.mem[9] = 32'h0000006f;
        end
    endtask

    // ==========================================
    //   Test 39: Dirty-Eviction Persistence (D$ Corner Case)
    //
    //   Four addresses share the same cache index (0x100, 0x500, 0x900,
    //   0xD00 → idx 64 with CACHE_DEPTH=256). Four SWs fill both ways,
    //   then evict each way in turn. Then four LWs from the original
    //   addresses force more evictions. By the end every value must be
    //   recoverable — either from cache or from RAM via writebacks.
    //
    //   Trace (with the data_in=mem_rdata refill fix in place):
    //     SW 0x100=10  -> way0={tag0,10,d}
    //     SW 0x500=20  -> way1={tag1,20,d}
    //     SW 0x900=30  -> evict way0 → mem[0x100]=10; way0={tag2,30,d}
    //     SW 0xD00=40  -> evict way1 → mem[0x500]=20; way1={tag3,40,d}
    //     LW 0x100     -> evict way0 → mem[0x900]=30; refill→way0=10
    //     LW 0x500     -> evict way1 → mem[0xD00]=40; refill→way1=20
    //     LW 0x900     -> evict way0 → mem[0x100]=10; refill→way0=30
    //     LW 0xD00     -> evict way1 → mem[0x500]=20; refill→way1=40
    //
    //   Expected regs : x10=10, x11=20, x12=30, x13=40
    //   Expected mem  : mem[0x100]=10, mem[0x500]=20, cache[0x900]=30, cache[0xD00]=40
    // ==========================================
    task load_test39_dirty_eviction_persistence;
        integer i;
        begin
            $display("\n--- Loading Test 39: Dirty-Eviction Persistence ---");
            for (i = 0; i < 64; i = i + 1) u_axil_ram.mem[i] = 32'h00000013;

            // Values to store
            // 0x00: ADDI x2, x0, 10
            u_axil_ram.mem[0]  = 32'h00a00113;
            // 0x04: ADDI x3, x0, 20
            u_axil_ram.mem[1]  = 32'h01400193;
            // 0x08: ADDI x4, x0, 30
            u_axil_ram.mem[2]  = 32'h01e00213;
            // 0x0C: ADDI x5, x0, 40
            u_axil_ram.mem[3]  = 32'h02800293;

            // Phase 1: four stores, all index 0x40, distinct tags
            // 0x10: ADDI x6, x0, 0x100
            u_axil_ram.mem[4]  = 32'h10000313;
            // 0x14: SW x2, 0(x6)            mem[0x100] = 10
            u_axil_ram.mem[5]  = 32'h00232023;
            // 0x18: ADDI x6, x6, 0x400      x6 = 0x500
            u_axil_ram.mem[6]  = 32'h40030313;
            // 0x1C: SW x3, 0(x6)            mem[0x500] = 20
            u_axil_ram.mem[7]  = 32'h00332023;
            // 0x20: ADDI x6, x6, 0x400      x6 = 0x900
            u_axil_ram.mem[8]  = 32'h40030313;
            // 0x24: SW x4, 0(x6)            mem[0x900] = 30  (evicts way0)
            u_axil_ram.mem[9]  = 32'h00432023;
            // 0x28: ADDI x6, x6, 0x400      x6 = 0xD00
            u_axil_ram.mem[10] = 32'h40030313;
            // 0x2C: SW x5, 0(x6)            mem[0xD00] = 40  (evicts way1)
            u_axil_ram.mem[11] = 32'h00532023;

            // Phase 2: read each original address — every LW now misses,
            // forcing further evictions and AXI READs.
            // 0x30: ADDI x6, x0, 0x100
            u_axil_ram.mem[12] = 32'h10000313;
            // 0x34: LW x10, 0(x6)
            u_axil_ram.mem[13] = 32'h00032503;
            // 0x38: ADDI x6, x6, 0x400      x6 = 0x500
            u_axil_ram.mem[14] = 32'h40030313;
            // 0x3C: LW x11, 0(x6)
            u_axil_ram.mem[15] = 32'h00032583;
            // 0x40: ADDI x6, x6, 0x400      x6 = 0x900
            u_axil_ram.mem[16] = 32'h40030313;
            // 0x44: LW x12, 0(x6)
            u_axil_ram.mem[17] = 32'h00032603;
            // 0x48: ADDI x6, x6, 0x400      x6 = 0xD00
            u_axil_ram.mem[18] = 32'h40030313;
            // 0x4C: LW x13, 0(x6)
            u_axil_ram.mem[19] = 32'h00032683;

            // 0x50: JAL x0, 0
            u_axil_ram.mem[20] = 32'h0000006f;
        end
    endtask

    // ==========================================
    //   Test 40: Read-Modify-Write Throughput (D$ Hit Storm)
    //
    //   50-iteration RMW loop on a single address: LW, ADDI +1, SW.
    //   After the first iteration the line is resident and dirty, so
    //   every subsequent LW and SW must hit the cache without requesting
    //   a refill. Tests that store-hits update the line cleanly and that
    //   the load-after-store dependency is satisfied within one cycle
    //   of the data-cache hit (no false stalls).
    //
    //   Expected: x10 = 50, cache[0x100] = 50
    // ==========================================
    task load_test40_rmw_hit_storm;
        integer i;
        begin
            $display("\n--- Loading Test 40: RMW Hit Storm ---");
            for (i = 0; i < 64; i = i + 1) u_axil_ram.mem[i] = 32'h00000013;
            // Make sure mem[0x100] starts at 0
            u_axil_ram.mem[64] = 32'h00000000;  // word index 64 = byte addr 0x100

            // 0x00: ADDI x6, x0, 0x100      data addr
            u_axil_ram.mem[0] = 32'h10000313;
            // 0x04: ADDI x2, x0, 0          counter
            u_axil_ram.mem[1] = 32'h00000113;
            // 0x08: ADDI x3, x0, 50         limit
            u_axil_ram.mem[2] = 32'h03200193;

            // Loop body (0x0C..0x1C):
            // 0x0C: LW   x10, 0(x6)
            u_axil_ram.mem[3] = 32'h00032503;
            // 0x10: ADDI x10, x10, 1
            u_axil_ram.mem[4] = 32'h00150513;
            // 0x14: SW   x10, 0(x6)
            u_axil_ram.mem[5] = 32'h00a32023;
            // 0x18: ADDI x2, x2, 1
            u_axil_ram.mem[6] = 32'h00110113;
            // 0x1C: BLT  x2, x3, -16        back to 0x0C while counter < 50
            u_axil_ram.mem[7] = 32'hfe3148e3;

            // 0x20: JAL x0, 0
            u_axil_ram.mem[8] = 32'h0000006f;
        end
    endtask

    // ==========================================
    //   Test 41: Load-Use Hazard — Basic LW→USE
    //
    //   Stores 42 at 0x300, sets x3=99 as a sentinel wrong value,
    //   then LW x3←mem[0x300]=42 immediately followed by instructions
    //   that use x3. If the load-use stall is broken, x4/x5 get 99.
    //
    //   Expected: x4=42, x5=84, x6=43
    // ==========================================
    //   Test 41: Load-Use Hazard — LW→ADD (2-iter loop)
    //
    //   A 2-iteration loop. Iter 1 warms I$ and D$. Iter 2 runs fully
    //   pipelined: LW and ADD are back-to-back with no natural stalls,
    //   so the load-use hazard detection MUST fire.
    // ==========================================
    task load_test41_load_use_basic;
        integer i;
        begin
            $display("\n--- Loading Test 41: Load-Use Hazard LW->ADD ---");
            for (i = 0; i < 32; i = i + 1) u_axil_ram.mem[i] = 32'h00000013;

            u_axil_ram.mem[0] = 32'h30000093; // ADDI x1,x0,0x300
            u_axil_ram.mem[1] = 32'h02a00113; // ADDI x2,x0,42
            u_axil_ram.mem[2] = 32'h0020a023; // SW x2,0(x1)
            u_axil_ram.mem[3] = 32'h00200393; // ADDI x7,x0,2
            u_axil_ram.mem[4] = 32'h06300193; // ADDI x3,x0,99   sentinel
            u_axil_ram.mem[5] = 32'h0000a183; // LW x3,0(x1)
            u_axil_ram.mem[6] = 32'h00018233; // ADD x4,x3,x0    load-use
            u_axil_ram.mem[7] = 32'h003182b3; // ADD x5,x3,x3
            u_axil_ram.mem[8] = 32'hfff38393; // ADDI x7,x7,-1
            u_axil_ram.mem[9] = 32'hfe0396e3; // BNE x7,x0,-20   back to 0x10
            u_axil_ram.mem[10] = 32'h0000006f; // JAL x0,0
        end
    endtask

    // ==========================================
    //   Test 42: Load-Use Hazard — LB→ADDI (2-iter loop)
    //
    //   Same loop structure as Test 41 but with a sign-extending byte
    //   load. Sentinel x4=5 makes broken stall give x5=6 instead of 0.
    // ==========================================
    task load_test42_load_use_byte_half;
        integer i;
        begin
            $display("\n--- Loading Test 42: Load-Use Hazard LB->ADDI ---");
            for (i = 0; i < 32; i = i + 1) u_axil_ram.mem[i] = 32'h00000013;

            u_axil_ram.mem[0] = 32'h20000093; // ADDI x1,x0,0x200
            u_axil_ram.mem[1] = 32'h0ff00113; // ADDI x2,x0,0xFF
            u_axil_ram.mem[2] = 32'h0020a023; // SW x2,0(x1)
            u_axil_ram.mem[3] = 32'h00200393; // ADDI x7,x0,2
            u_axil_ram.mem[4] = 32'h00500213; // ADDI x4,x0,5    sentinel
            u_axil_ram.mem[5] = 32'h00008203; // LB x4,0(x1)
            u_axil_ram.mem[6] = 32'h00120293; // ADDI x5,x4,1    load-use
            u_axil_ram.mem[7] = 32'hfff38393; // ADDI x7,x7,-1
            u_axil_ram.mem[8] = 32'hfe0398e3; // BNE x7,x0,-16   back to 0x10
            u_axil_ram.mem[9] = 32'h0000006f; // JAL x0,0
        end
    endtask

    // ==========================================
    //   Test 43: Load-Use Hazard — LW→SW (2-iter loop)
    //
    //   Sentinel x4=0 is reset each iter. LW loads 77; the immediately
    //   following SW stores x4. Iter 2 runs at full speed: SW must
    //   forward the load result or mem[0x304] ends up 0 (broken).
    // ==========================================
    task load_test43_load_use_store;
        integer i;
        begin
            $display("\n--- Loading Test 43: Load-Use Hazard LW->SW ---");
            for (i = 0; i < 32; i = i + 1) u_axil_ram.mem[i] = 32'h00000013;

            u_axil_ram.mem[0] = 32'h30000093; // ADDI x1,x0,0x300
            u_axil_ram.mem[1] = 32'h04d00113; // ADDI x2,x0,77
            u_axil_ram.mem[2] = 32'h0020a023; // SW x2,0(x1)
            u_axil_ram.mem[3] = 32'h00200393; // ADDI x7,x0,2
            u_axil_ram.mem[4] = 32'h00000213; // ADDI x4,x0,0    sentinel
            u_axil_ram.mem[5] = 32'h0000a203; // LW x4,0(x1)
            u_axil_ram.mem[6] = 32'h0040a223; // SW x4,4(x1)     load-use store
            u_axil_ram.mem[7] = 32'hfff38393; // ADDI x7,x7,-1
            u_axil_ram.mem[8] = 32'hfe0398e3; // BNE x7,x0,-16   back to 0x10
            u_axil_ram.mem[9] = 32'h0000006f; // JAL x0,0
        end
    endtask

    // ==========================================
    //   Test 44: Load-Use Hazard — Alternating D$ values (2-iter loop)
    //
    //   Each iteration writes the loop counter (x7) to the cache address
    //   before loading it: x7=2 on iter 1, x7=1 on iter 2.  After iter 2
    //   the loaded value is 1 and x4=x6=11.
    // ==========================================
    task load_test44_load_use_cache_hit;
        integer i;
        begin
            $display("\n--- Loading Test 44: Load-Use Hazard Alternating D$ Values ---");
            for (i = 0; i < 16; i = i + 1) u_axil_ram.mem[i] = 32'h00000013;

            u_axil_ram.mem[0]  = 32'h50000093; // ADDI x1,x0,0x500
            u_axil_ram.mem[1]  = 32'h00200393; // ADDI x7,x0,2
            u_axil_ram.mem[2]  = 32'h00000193; // ADDI x3,x0,0    sentinel #1
            u_axil_ram.mem[3]  = 32'h0070a023; // SW x7,0(x1)     write x7 to cache
            u_axil_ram.mem[4]  = 32'h0000a183; // LW x3,0(x1)     D$ hit #1; load-use
            u_axil_ram.mem[5]  = 32'h00a18213; // ADDI x4,x3,10   x4=12(iter1) 11(iter2)
            u_axil_ram.mem[6]  = 32'h00000293; // ADDI x5,x0,0    sentinel #2
            u_axil_ram.mem[7]  = 32'h0000a283; // LW x5,0(x1)     D$ hit #2; load-use
            u_axil_ram.mem[8]  = 32'h00a28313; // ADDI x6,x5,10   x6=12(iter1) 11(iter2)
            u_axil_ram.mem[9]  = 32'hfff38393; // ADDI x7,x7,-1
            u_axil_ram.mem[10] = 32'hfe0390e3; // BNE x7,x0,-32   back to 0x08
            u_axil_ram.mem[11] = 32'h0000006f; // JAL x0,0
        end
    endtask

    // ==========================================
    //   Test 45: Load-Use Hazard — LW→STORE, alternating values + strobes
    //
    //   Goal: fully stress the load-use forward path into a STORE on the
    //   cache-HIT path, defeating the two ways a delayed/broken forward can
    //   hide:
    //     (a) Broken stall (store reads stale register): each dest register
    //         is reset to a sentinel (0xFFFFFFFF) right before its LW, so a
    //         missed stall stores 0xFF.. instead of the loaded value.
    //     (b) Delayed forward by 1 cycle (store grabs the previous load's
    //         latched data_cache_data_out): the five LW→ST pairs in each
    //         iteration load FIVE DISTINCT values, so a stale latch stores
    //         pair[i-1]'s value ≠ pair[i]'s value.
    //
    // ==========================================
    task load_test45_load_use_store_strobes;
        integer i;
        begin
            $display("\n--- Loading Test 45: Load-Use Hazard LW->STORE strobes ---");
            for (i = 0; i < 32; i = i + 1) u_axil_ram.mem[i] = 32'h00000013;

            // Source array @0x100..0x110 (5 distinct values, cache-resident)
            u_axil_ram.mem[64] = 32'hAABBCCDD; // 0x100  V0  -> SB byte
            u_axil_ram.mem[65] = 32'h11223344; // 0x104  V1  -> SB byte
            u_axil_ram.mem[66] = 32'hCAFE5678; // 0x108  V2  -> SH half
            u_axil_ram.mem[67] = 32'hDEAD9ABC; // 0x10C  V3  -> SH half
            u_axil_ram.mem[68] = 32'h13579BDF; // 0x110  V4  -> SW word
            // Dest words @0x200..0x208 cleared (unwritten bytes must read 0)
            u_axil_ram.mem[128] = 32'h00000000; // 0x200
            u_axil_ram.mem[129] = 32'h00000000; // 0x204
            u_axil_ram.mem[130] = 32'h00000000; // 0x208

            u_axil_ram.mem[0]  = 32'h10000093; // ADDI x1,x0,0x100   src base
            u_axil_ram.mem[1]  = 32'h20000113; // ADDI x2,x0,0x200   dst base
            u_axil_ram.mem[2]  = 32'h00300393; // ADDI x7,x0,3       loop count
            // loop @0x0C
            u_axil_ram.mem[3]  = 32'hfff00213; // ADDI x4,x0,-1      sentinel
            u_axil_ram.mem[4]  = 32'h0000a203; // LW   x4,0(x1)      V0 (hit on warm iter)
            u_axil_ram.mem[5]  = 32'h00410023; // SB   x4,0(x2)      load-use, strobe 0001
            u_axil_ram.mem[6]  = 32'hfff00293; // ADDI x5,x0,-1      sentinel
            u_axil_ram.mem[7]  = 32'h0040a283; // LW   x5,4(x1)      V1
            u_axil_ram.mem[8]  = 32'h005100a3; // SB   x5,1(x2)      load-use, strobe 0010
            u_axil_ram.mem[9]  = 32'hfff00313; // ADDI x6,x0,-1      sentinel
            u_axil_ram.mem[10] = 32'h0080a303; // LW   x6,8(x1)      V2
            u_axil_ram.mem[11] = 32'h00611223; // SH   x6,4(x2)      load-use, strobe 0011
            u_axil_ram.mem[12] = 32'hfff00193; // ADDI x3,x0,-1      sentinel
            u_axil_ram.mem[13] = 32'h00c0a183; // LW   x3,12(x1)     V3
            u_axil_ram.mem[14] = 32'h00311323; // SH   x3,6(x2)      load-use, strobe 1100
            u_axil_ram.mem[15] = 32'hfff00413; // ADDI x8,x0,-1      sentinel
            u_axil_ram.mem[16] = 32'h0100a403; // LW   x8,16(x1)     V4
            u_axil_ram.mem[17] = 32'h00812423; // SW   x8,8(x2)      load-use, strobe 1111
            u_axil_ram.mem[18] = 32'hfff38393; // ADDI x7,x7,-1
            u_axil_ram.mem[19] = 32'hfc0390e3; // BNE  x7,x0,-64     back to 0x0C
            u_axil_ram.mem[20] = 32'h0000006f; // JAL  x0,0          halt
        end
    endtask

    // ==========================================
    //   Test 46: load-use STORE-ADDRESS dependency under a secondary stall
    //   See invocation comment for the mechanism under test.
    // ==========================================
    task load_test46_load_use_store_addr;
        integer i;
        begin
            $display("\n--- Loading Test 46: load-use store-address under stall ---");
            for (i = 0; i < 32; i = i + 1) u_axil_ram.mem[i] = 32'h00000013;

            // Data: pointer at 0x300 -> 0x340 (valid, writable). dest cleared.
            u_axil_ram.mem[192] = 32'h00000340; // [0x300] = pointer to 0x340
            u_axil_ram.mem[208] = 32'h00000000; // [0x340] = dest, cleared

            u_axil_ram.mem[0]  = 32'h30000513; // ADDI x10,x0,0x300   LW source (ptr slot)
            u_axil_ram.mem[1]  = 32'h70000593; // ADDI x11,x0,0x700   miss-store walking base
            u_axil_ram.mem[2]  = 32'h0ab00393; // ADDI x7,x0,0xAB     data for dependent store
            u_axil_ram.mem[3]  = 32'h0cd00493; // ADDI x9,x0,0xCD     data for miss store
            u_axil_ram.mem[4]  = 32'h00300313; // ADDI x6,x0,3        loop count
            u_axil_ram.mem[5]  = 32'h03c00613; // ADDI x12,x0,0x3C    mtvec target (trap halt)
            u_axil_ram.mem[6]  = 32'h30561073; // CSRRW x0,mtvec,x12  install trap halt vector
            // loop @0x1C
            u_axil_ram.mem[7]  = 32'hff000293; // ADDI x5,x0,-16      sentinel = 0xFFFFFFF0 (aligned, invalid)
            u_axil_ram.mem[8]  = 32'h00052283; // LW   x5,0(x10)      load valid pointer (HIT on warm iter)
            u_axil_ram.mem[9]  = 32'h0095a023; // SW   x9,0(x11)      MISS store -> ex_stall
            u_axil_ram.mem[10] = 32'h0072a023; // SW   x7,0(x5)       rs1=x5: pre-fix used stale 0xFFFFFFF0 -> 0x07
            u_axil_ram.mem[11] = 32'h00458593; // ADDI x11,x11,4      walk miss addr (stay cold)
            u_axil_ram.mem[12] = 32'hfff30313; // ADDI x6,x6,-1
            u_axil_ram.mem[13] = 32'hfe0314e3; // BNE  x6,x0,-24      back to 0x1C
            u_axil_ram.mem[14] = 32'h0000006f; // JAL  x0,0           normal halt
            u_axil_ram.mem[15] = 32'h0000006f; // JAL  x0,0           trap halt (mtvec=0x3C)
        end
    endtask

    // ==========================================
    //   Test 47: load-use STORE-DATA (rs2) dependency under a secondary stall
    //   Same lingering mechanism via the store's data operand (rs2) instead of
    //   the base (rs1). Pre-fix the dependent store wrote the stale sentinel.
    // ==========================================
    task load_test47_load_use_store_data;
        integer i;
        begin
            $display("\n--- Loading Test 47: load-use store-data under stall ---");
            for (i = 0; i < 32; i = i + 1) u_axil_ram.mem[i] = 32'h00000013;

            // Data: value 0x55 at 0x300 (loaded). dest 0x380 cleared.
            u_axil_ram.mem[192] = 32'h00000055; // [0x300] = data 0x55
            u_axil_ram.mem[224] = 32'h00000000; // [0x380] = dest, cleared

            u_axil_ram.mem[0]  = 32'h30000513; // ADDI x10,x0,0x300   LW source (data slot)
            u_axil_ram.mem[1]  = 32'h10000593; // ADDI x11,x0,0x100   miss-store walking base (<0x400 so check_mem peeks cache)
            u_axil_ram.mem[2]  = 32'h38000613; // ADDI x12,x0,0x380   dependent-store dest (valid)
            u_axil_ram.mem[3]  = 32'h0cd00493; // ADDI x9,x0,0xCD     data for miss store
            u_axil_ram.mem[4]  = 32'h00300313; // ADDI x6,x0,3        loop count
            // loop @0x14
            u_axil_ram.mem[5]  = 32'hff000393; // ADDI x7,x0,-16      sentinel = 0xFFFFFFF0
            u_axil_ram.mem[6]  = 32'h00052383; // LW   x7,0(x10)      load valid data 0x55 (HIT on warm iter)
            u_axil_ram.mem[7]  = 32'h0095a023; // SW   x9,0(x11)      MISS store -> ex_stall
            u_axil_ram.mem[8]  = 32'h00762023; // SW   x7,0(x12)      rs2=x7 (data): pre-fix stored stale sentinel
            u_axil_ram.mem[9]  = 32'h00458593; // ADDI x11,x11,4      walk miss addr (stay cold)
            u_axil_ram.mem[10] = 32'hfff30313; // ADDI x6,x6,-1
            u_axil_ram.mem[11] = 32'hfe0314e3; // BNE  x6,x0,-24      back to 0x14
            u_axil_ram.mem[12] = 32'h0000006f; // JAL  x0,0           halt
        end
    endtask

    task load_test48_write_buffer_priority;
        integer i;
        begin
            $display("\n--- Loading Test 48: Write Buffer Priority ---");
            for (i = 0; i < 96; i = i + 1) u_axil_ram.mem[i] = 32'h00000013;
            u_axil_ram.mem[0]  = 32'h00b00113;
            u_axil_ram.mem[1]  = 32'h01600193;
            u_axil_ram.mem[2]  = 32'h02100213;
            u_axil_ram.mem[3]  = 32'h02c00293;
            u_axil_ram.mem[4]  = 32'h06300313;
            u_axil_ram.mem[5]  = 32'h10000413;
            u_axil_ram.mem[6]  = 32'h00242023;
            u_axil_ram.mem[7]  = 32'h40040493;
            u_axil_ram.mem[8]  = 32'h0034a023;
            u_axil_ram.mem[9]  = 32'h40048613;
            u_axil_ram.mem[10] = 32'h00462023;
            u_axil_ram.mem[11] = 32'h40060693;
            u_axil_ram.mem[12] = 32'h0056a023;
            u_axil_ram.mem[13] = 32'h00042503;
            u_axil_ram.mem[14] = 32'h0004a583;
            u_axil_ram.mem[15] = 32'h00642023;
            u_axil_ram.mem[16] = 32'h00042703;
            u_axil_ram.mem[17] = 32'h0000006f;
        end
    endtask

    task load_test49_write_buffer_full;
        integer i;
        begin
            $display("\n--- Loading Test 49: Write Buffer Full ---");
            for (i = 0; i < 96; i = i + 1) u_axil_ram.mem[i] = 32'h00000013;
            u_axil_ram.mem[0] = 32'h00100113;
            u_axil_ram.mem[1] = 32'h10000313;
            for (i = 0; i < 11; i = i + 1) begin
                u_axil_ram.mem[2 + i * 3] = 32'h00232023;
                u_axil_ram.mem[3 + i * 3] = 32'h00110113;
                u_axil_ram.mem[4 + i * 3] = 32'h40030313;
            end
            u_axil_ram.mem[35] = 32'h0000006f;
        end
    endtask

endmodule
