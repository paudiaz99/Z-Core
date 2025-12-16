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
//    Comprehensive test suite for RV32I instructions
// **************************************************

`timescale 1ns / 1ns
`include "rtl/z_core_control_u.v"
`include "rtl/axi_mem.v"
`include "rtl/axil_interconnect.v"
`include "rtl/axil_uart.v"
`include "rtl/axil_gpio.v"
`include "rtl/arbiter.v"
`include "rtl/priority_encoder.v"

module z_core_control_u_tb;

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;
    parameter STRB_WIDTH = (DATA_WIDTH/8);
    parameter N_GPIO     = 64;

    // Clock and Reset
    reg clk = 0;
    reg rstn;

    // Test tracking
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;
    reg [4:0] current_state = 0;
    real instruction_count = 0;

    // Interconnect Parameters
    localparam S_COUNT = 1;
    localparam M_COUNT = 3;
    localparam M_REGIONS = 1;

    // Address Map
    // M0: Memory (0x0000_0000 - 0x03FF_FFFF) 64MB
    // M1: UART   (0x0400_0000 - 0x0400_0FFF) 4KB
    // M2: GPIO   (0x0400_1000 - 0x0400_1FFF) 4KB

    localparam [M_COUNT*ADDR_WIDTH-1:0] M_BASE_ADDR = {
        32'h0400_1000, // M2: GPIO
        32'h0400_0000, // M1: UART
        32'h0000_0000  // M0: Memory
    };

    localparam [M_COUNT*32-1:0] M_ADDR_WIDTH_CONF = {
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

    // Instantiate Control Unit (AXI-Lite Master)
    wire cpu_halt;  // Halt signal from CPU (ECALL/EBREAK detected)
    
    z_core_control_u #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .STRB_WIDTH(STRB_WIDTH)
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
        
        // Halt signal for RISCOF
        .halt(cpu_halt)
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

    // Clock generation (100MHz)
    always #5 clk = ~clk;

    always @(posedge clk) begin
        current_state <= uut.state[5:0];
        if (current_state == 1) begin
            instruction_count <= instruction_count + 1;
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
                default: actual = 32'hDEADBEEF;
            endcase
            
            if (actual == expected) begin
                pass_count = pass_count + 1;
                $display("  [PASS] %0s: x%0d = %0d", test_name, reg_num, actual);
            end else begin
                fail_count = fail_count + 1;
                $display("  [FAIL] %0s: x%0d = %0d (expected %0d)", 
                         test_name, reg_num, actual, expected);
            end
        end
    endtask

    task check_mem;
        input [31:0] addr;
        input [31:0] expected;
        input [255:0] test_name;
        reg [31:0] actual;
        begin
            test_count = test_count + 1;
            actual = u_axil_ram.mem[addr >> 2];
            
            if (actual == expected) begin
                pass_count = pass_count + 1;
                $display("  [PASS] %0s: mem[0x%04h] = %0d", test_name, addr, actual);
            end else begin
                fail_count = fail_count + 1;
                $display("  [FAIL] %0s: mem[0x%04h] = %0d (expected %0d)", 
                         test_name, addr, actual, expected);
            end
        end
    endtask

    task wait_cycles;
        input integer n;
        begin
            repeat(n) @(posedge clk);
        end
    endtask

    task reset_cpu;
        begin
            rstn = 0;
            wait_cycles(10);  // Increased from 4 to allow pipeline flush
            rstn = 1;
            wait_cycles(5);   // Increased from 2 to allow pipeline fill
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
        $display("╔═══════════════════════════════════════════════════════════╗");
        $display("║           Z-Core RISC-V Processor Test Suite              ║");
        $display("║                   RV32I Instruction Set                    ║");
        $display("╚═══════════════════════════════════════════════════════════╝");

        // ==========================================
        // Test 1: Arithmetic Operations
        // ==========================================
        load_test1_arithmetic();
        reset_cpu();
        #1500;
        
        $display("\n=== Test 1 Results: Arithmetic ===");
        check_reg(2, 10, "ADDI x2, x0, 10");
        check_reg(3, 7,  "ADDI x3, x0, 7");
        check_reg(4, 17, "ADD x4, x2, x3");
        check_reg(5, 3,  "SUB x5, x2, x3");
        check_reg(6, -5, "ADDI x6, x0, -5");
        check_reg(7, 12, "ADD x7, x4, x6");

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

        // ==========================================
        // Test 12: GPIO Bidirectional Verification
        // ==========================================
        load_test12_gpio_bidirectional();
        gpio_test_en = 0;    // TB not driving initially
        gpio_test_drive = 0;
        reset_cpu();
        
        // Wait for GPIO to be configured as output and data written
        // CPU writes DIR=0xFFFFFFFF then DATA=0x000000FF
        wait(gpio_wiring[31:0] === 32'h000000FF);
        $display("\n=== Test 12 Results: GPIO Bidirectional ===");
        test_count = test_count + 1;
        pass_count = pass_count + 1;
        $display("  [PASS] GPIO Output Drive: gpio[31:0] = 0x%08h", gpio_wiring[31:0]);
        
        // Wait for CPU to switch GPIO to input mode (DIR=0)
        wait(u_gpio.gpio_dir[31:0] === 32'h00000000);
        
        // Now TB drives the GPIO pins with test pattern
        gpio_test_en[31:0] = 32'hFFFFFFFF;
        gpio_test_drive[31:0] = 32'hCAFEBABE;
        
        // Wait for CPU to read the value
        #500;
        check_reg(6, 32'hCAFEBABE, "GPIO Input Read");

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

        // ==========================================
        // Test 17: Nested Loops
        // ==========================================
        load_test17_nested_loops();
        reset_cpu();
        #15000;  // Nested loops need more time
        
        $display("\n=== Test 17 Results: Nested Loops ===");
        // sum = (0+0)+(0+1)+(0+2) + (1+0)+(1+1)+(1+2) + (2+0)+(2+1)+(2+2)
        //     = 0+1+2 + 1+2+3 + 2+3+4 = 3 + 6 + 9 = 18
        check_reg(1, 3,   "Outer counter final i=3");
        check_reg(2, 3,   "Inner counter final j=3");
        check_reg(10, 18, "Sum = 18");
        check_mem(768, 18, "SW mem[768] = 18");

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

        // ==========================================
        // Final Summary
        // ==========================================
        $display("");
        $display("╔═══════════════════════════════════════════════════════════╗");
        $display("║                    TEST SUMMARY                           ║");
        $display("╠═══════════════════════════════════════════════════════════╣");
        $display("║  Total Tests: %3d                                         ║", test_count);
        $display("║  Passed:      %3d                                         ║", pass_count);
        $display("║  Failed:      %3d                                         ║", fail_count);
        $display("╠═══════════════════════════════════════════════════════════╣");
        
        if (fail_count == 0) begin
            $display("║         ✓ ALL TESTS PASSED SUCCESSFULLY ✓                 ║");
        end else begin
            $display("║              ✗ SOME TESTS FAILED ✗                        ║");
        end

        $display("║  Test Duration: %0d ns                                 ║", $time);
        $display("║  Clock Cycles:  %0d                                     ║", $time / 10);
        $display("║  Instructions:  %0d                                      ║", instruction_count);
        $display("╚═══════════════════════════════════════════════════════════╝");
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

endmodule
