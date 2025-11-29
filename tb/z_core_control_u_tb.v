// **************************************************
//        Z-Core Control Unit Testbench
//    Tests AXI-Lite interface with memory
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

    // Clock generation
    always #5 clk = ~clk;

    // Initialize memory with test program
    initial begin
        // Wait for reset to complete before initializing memory
        @(posedge rstn);
        @(posedge clk);
        
        // Load program into memory (word-aligned addresses)
        // Address 0x00: ADDI x2, x0, 3   - Load 3 into x2
        u_axil_ram.mem[0] = 32'b00000000001100000000000100010011;
        
        // Address 0x04: ADDI x3, x0, 5   - Load 5 into x3
        u_axil_ram.mem[1] = 32'b00000000010100000000000110010011;
        
        // Address 0x08: ADD x4, x2, x3   - x4 = x2 + x3 = 8
        u_axil_ram.mem[2] = 32'b00000000001100010000001000110011;
        
        // Address 0x0C: SW x4, 256(x0)   - Store x4 to address 256
        u_axil_ram.mem[3] = 32'b00010000010000000010000000100011;
        
        // Address 0x10: LW x5, 256(x0)   - Load from address 256 into x5
        u_axil_ram.mem[4] = 32'b00010000000000000010001010000011;
        
        // Address 0x14: SUB x6, x5, x2   - x6 = x5 - x2 = 8 - 3 = 5
        u_axil_ram.mem[5] = 32'b01000000001000101000001100110011;
        
        // Address 0x18: NOP (ADDI x0, x0, 0)
        u_axil_ram.mem[6] = 32'b00000000000000000000000000010011;
        u_axil_ram.mem[7] = 32'b00000000000000000000000000010011;
        
        $display("Program loaded into memory");
    end

    // Test sequence
    initial begin
        $dumpfile("z_core_control_u_tb.vcd");
        $dumpvars(0, z_core_control_u_tb);

        // Initialize
        rstn = 0;
        
        // Hold reset for a few cycles
        #20;
        rstn = 1;
        
        $display("===========================================");
        $display("Z-Core Control Unit AXI Interface Test");
        $display("===========================================");
        
        // Run simulation for enough cycles to execute program
        // Each instruction takes multiple cycles due to FSM and AXI latency
        #2000;
        
        // Check results
        $display("");
        $display("=== Simulation Results ===");
        $display("PC = %d", uut.PC);
        $display("");
        $display("Register x2 = %d (expected: 3)", uut.reg_file.reg_r2_q);
        $display("Register x3 = %d (expected: 5)", uut.reg_file.reg_r3_q);
        $display("Register x4 = %d (expected: 8)", uut.reg_file.reg_r4_q);
        $display("Register x5 = %d (expected: 8)", uut.reg_file.reg_r5_q);
        $display("Register x6 = %d (expected: 5)", uut.reg_file.reg_r6_q);
        $display("");
        $display("Memory[256/4] = %d (expected: 8)", u_axil_ram.mem[64]);
        $display("");
        
        // Verify results
        if (uut.reg_file.reg_r2_q == 3 &&
            uut.reg_file.reg_r3_q == 5 &&
            uut.reg_file.reg_r4_q == 8 &&
            uut.reg_file.reg_r5_q == 8 &&
            uut.reg_file.reg_r6_q == 5) begin
            $display("*** TEST PASSED ***");
        end else begin
            $display("*** TEST FAILED ***");
        end
        
        $display("===========================================");
        $display("Test Finished");
        $finish;
    end

    // Monitor AXI transactions
    always @(posedge clk) begin
        if (rstn) begin
            // Monitor read transactions
            if (axil_arvalid && axil_arready) begin
                $display("[%0t] AXI Read Request: addr=0x%08h", $time, axil_araddr);
            end
            if (axil_rvalid && axil_rready) begin
                $display("[%0t] AXI Read Response: data=0x%08h", $time, axil_rdata);
            end
            
            // Monitor write transactions
            if (axil_awvalid && axil_awready) begin
                $display("[%0t] AXI Write Request: addr=0x%08h, data=0x%08h", 
                         $time, axil_awaddr, axil_wdata);
            end
            if (axil_bvalid && axil_bready) begin
                $display("[%0t] AXI Write Response: complete", $time);
            end
        end
    end

    // Debug FSM state transitions
    reg [5:0] prev_state;
    always @(posedge clk) begin
        if (rstn) begin
            prev_state <= uut.state;
            if (uut.state != prev_state) begin
                $display("[%0t] FSM State: %b -> %b, PC=0x%08h, IR=0x%08h", 
                         $time, prev_state, uut.state, uut.PC, uut.IR);
            end
        end
    end

endmodule
