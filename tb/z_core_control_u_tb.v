// **************************************************
//        Z-Core Control Unit Testbench
//    Comprehensive test suite for RV32I instructions
// **************************************************

`timescale 1ns / 1ps
`include "rtl/z_core_control_u.v"
`include "rtl/axi_mem.v"

module z_core_control_u_tb;

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;
    parameter STRB_WIDTH = (DATA_WIDTH/8);

    // Clock and Reset
    reg clk = 0;
    reg rstn;

    // Test tracking
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // AXI-Lite signals between Control Unit (Master) and Memory (Slave)
    wire [ADDR_WIDTH-1:0]  axil_awaddr;
    wire [2:0]             axil_awprot;
    wire                   axil_awvalid;
    wire                   axil_awready;
    wire [DATA_WIDTH-1:0]  axil_wdata;
    wire [STRB_WIDTH-1:0]  axil_wstrb;
    wire                   axil_wvalid;
    wire                   axil_wready;
    wire [1:0]             axil_bresp;
    wire                   axil_bvalid;
    wire                   axil_bready;
    wire [ADDR_WIDTH-1:0]  axil_araddr;
    wire [2:0]             axil_arprot;
    wire                   axil_arvalid;
    wire                   axil_arready;
    wire [DATA_WIDTH-1:0]  axil_rdata;
    wire [1:0]             axil_rresp;
    wire                   axil_rvalid;
    wire                   axil_rready;

    // Instantiate Control Unit (AXI-Lite Master)
    z_core_control_u #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .STRB_WIDTH(STRB_WIDTH)
    ) uut (
        .clk(clk),
        .rstn(rstn),
        
        // AXI-Lite Master Interface
        .m_axil_awaddr(axil_awaddr),
        .m_axil_awprot(axil_awprot),
        .m_axil_awvalid(axil_awvalid),
        .m_axil_awready(axil_awready),
        .m_axil_wdata(axil_wdata),
        .m_axil_wstrb(axil_wstrb),
        .m_axil_wvalid(axil_wvalid),
        .m_axil_wready(axil_wready),
        .m_axil_bresp(axil_bresp),
        .m_axil_bvalid(axil_bvalid),
        .m_axil_bready(axil_bready),
        .m_axil_araddr(axil_araddr),
        .m_axil_arprot(axil_arprot),
        .m_axil_arvalid(axil_arvalid),
        .m_axil_arready(axil_arready),
        .m_axil_rdata(axil_rdata),
        .m_axil_rresp(axil_rresp),
        .m_axil_rvalid(axil_rvalid),
        .m_axil_rready(axil_rready)
    );

    // Instantiate AXI-Lite RAM (Slave)
    axil_ram #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(16),  // 64KB memory space
        .STRB_WIDTH(STRB_WIDTH),
        .PIPELINE_OUTPUT(0)
    ) u_axil_ram (
        .clk(clk),
        .rstn(rstn),
        
        // AXI-Lite Slave Interface
        .s_axil_awaddr(axil_awaddr[15:0]),
        .s_axil_awprot(axil_awprot),
        .s_axil_awvalid(axil_awvalid),
        .s_axil_awready(axil_awready),
        .s_axil_wdata(axil_wdata),
        .s_axil_wstrb(axil_wstrb),
        .s_axil_wvalid(axil_wvalid),
        .s_axil_wready(axil_wready),
        .s_axil_bresp(axil_bresp),
        .s_axil_bvalid(axil_bvalid),
        .s_axil_bready(axil_bready),
        .s_axil_araddr(axil_araddr[15:0]),
        .s_axil_arprot(axil_arprot),
        .s_axil_arvalid(axil_arvalid),
        .s_axil_arready(axil_arready),
        .s_axil_rdata(axil_rdata),
        .s_axil_rresp(axil_rresp),
        .s_axil_rvalid(axil_rvalid),
        .s_axil_rready(axil_rready)
    );

    // Clock generation (100MHz)
    always #5 clk = ~clk;

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
            wait_cycles(4);
            rstn = 1;
            wait_cycles(2);
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
            u_axil_ram.mem[7] = 32'h00811493;
            // NOPs
            u_axil_ram.mem[8] = 32'h00000013;
            u_axil_ram.mem[9] = 32'h00000013;
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
            // ADDI x8, x0, -1      - x8 = -1
            u_axil_ram.mem[6] = 32'hfff00413;
            // SLTU x9, x8, x2      - x9 = (0xFFFFFFFF < 10) = 0 (unsigned)
            u_axil_ram.mem[7] = 32'h00243493;
            // NOPs
            u_axil_ram.mem[8] = 32'h00000013;
            u_axil_ram.mem[9] = 32'h00000013;
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

    // ==========================================
    //           Main Test Sequence
    // ==========================================
    
    initial begin
        $dumpfile("z_core_control_u_tb.vcd");
        $dumpvars(0, z_core_control_u_tb);

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
        check_reg(9, 0, "SLTU x9 (unsigned)");

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
        // Final Summary
        // ==========================================
        $display("");
        $display("╔═══════════════════════════════════════════════════════════╗");
        $display("║                    TEST SUMMARY                            ║");
        $display("╠═══════════════════════════════════════════════════════════╣");
        $display("║  Total Tests: %3d                                          ║", test_count);
        $display("║  Passed:      %3d                                          ║", pass_count);
        $display("║  Failed:      %3d                                          ║", fail_count);
        $display("╠═══════════════════════════════════════════════════════════╣");
        
        if (fail_count == 0) begin
            $display("║         ✓ ALL TESTS PASSED SUCCESSFULLY ✓                ║");
        end else begin
            $display("║              ✗ SOME TESTS FAILED ✗                        ║");
        end
        
        $display("╚═══════════════════════════════════════════════════════════╝");
        $display("");
        
        $finish;
    end

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
