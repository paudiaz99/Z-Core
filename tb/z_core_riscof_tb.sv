// **************************************************
//        Z-Core RISCOF Compliance Testbench
//    Runs RISCOF architectural tests with signature dump
// **************************************************

`timescale 1ns / 1ns
`include "rtl/z_core_control_u.v"
`include "rtl/axi_mem.v"
`include "rtl/axil_interconnect.v"
`include "rtl/axil_uart.v"
`include "rtl/axil_gpio.v"
`include "rtl/arbiter.v"
`include "rtl/priority_encoder.v"

module z_core_riscof_tb;

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;
    parameter STRB_WIDTH = (DATA_WIDTH/8);
    parameter N_GPIO     = 64;

    // Plusargs for RISCOF
    reg [512*8-1:0] hex_file;
    reg [512*8-1:0] sig_file;
    integer sig_begin;
    integer sig_end;

    // Clock and Reset
    reg clk = 0;
    reg rstn;

    // Timeout counter
    integer timeout_cycles = 50000000;  // 50M cycles max for large tests
    integer cycle_count = 0;

    // Interconnect Parameters
    localparam S_COUNT = 1;
    localparam M_COUNT = 3;
    localparam M_REGIONS = 1;

    // Address Map
    localparam [M_COUNT*ADDR_WIDTH-1:0] M_BASE_ADDR = {
        32'h0400_1000, // M2: GPIO
        32'h0400_0000, // M1: UART
        32'h0000_0000  // M0: Memory
    };

    localparam [M_COUNT*32-1:0] M_ADDR_WIDTH_CONF = {
        32'd12, // M2: GPIO (4KB)
        32'd12, // M1: UART (4KB)
        32'd26  // M0: Memory (64MB)
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

    // GPIO Signals
    wire [N_GPIO-1:0] gpio_wiring;
    assign gpio_wiring = {N_GPIO{1'bz}};



    // CPU Halt signal
    wire cpu_halt;

    // Instantiate Interconnect
    axil_interconnect #(
        .S_COUNT(S_COUNT),
        .M_COUNT(M_COUNT),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(32),
        .STRB_WIDTH(STRB_WIDTH),
        .M_REGIONS(M_REGIONS),
        .M_BASE_ADDR(M_BASE_ADDR),
        .M_ADDR_WIDTH(M_ADDR_WIDTH_CONF)
    ) u_interconnect (
        .clk(clk),
        .rst(~rstn),
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

    // Instantiate Control Unit (CPU)
    z_core_control_u #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .STRB_WIDTH(STRB_WIDTH)
    ) uut (
        .clk(clk),
        .rstn(rstn),
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
        .halt(cpu_halt)
    );

    // Instantiate AXI-Lite RAM (2MB for large RISCOF tests)
    axil_ram #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(26),  // 2^26 = 64MB
        .STRB_WIDTH(STRB_WIDTH),
        .PIPELINE_OUTPUT(0)
    ) u_axil_ram (
        .clk(clk),
        .rstn(rstn),
        .s_axil_awaddr(m_axil_awaddr[0*ADDR_WIDTH +: 26]),
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
        .s_axil_araddr(m_axil_araddr[0*ADDR_WIDTH +: 26]),
        .s_axil_arprot(m_axil_arprot[0*3 +: 3]),
        .s_axil_arvalid(m_axil_arvalid[0]),
        .s_axil_arready(m_axil_arready[0]),
        .s_axil_rdata(m_axil_rdata[0*DATA_WIDTH +: DATA_WIDTH]),
        .s_axil_rresp(m_axil_rresp[0*2 +: 2]),
        .s_axil_rvalid(m_axil_rvalid[0]),
        .s_axil_rready(m_axil_rready[0])
    );

    // Instantiate AXI-Lite UART
    axil_uart #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(12), // 4KB
        .STRB_WIDTH(STRB_WIDTH)
    ) u_axil_uart (
        .clk(clk),
        .rst(~rstn),
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

    // Instantiate AXI-Lite GPIO
    axil_gpio #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(12), // 4KB
        .STRB_WIDTH(STRB_WIDTH),
        .N_GPIO(N_GPIO)
    ) u_axil_gpio (
        .clk(clk),
        .rst(~rstn),
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
        .gpio(gpio_wiring)
    );

    initial begin
        #1;
        $display("DEBUG: ADDR_WIDTH=%d", ADDR_WIDTH);
        $display("DEBUG: m_axil_awaddr width=%d", $bits(m_axil_awaddr));
        $display("DEBUG: u_interconnect.m_axil_awaddr width=%d", $bits(u_interconnect.m_axil_awaddr));
    end

    // Clock generation (100MHz)
    always #5 clk = ~clk;

    // Main test sequence
    initial begin
        // Get plusargs
        if (!$value$plusargs("hex_file=%s", hex_file)) begin
            $display("ERROR: No hex_file specified");
            $finish;
        end
        if (!$value$plusargs("sig_file=%s", sig_file)) begin
            $display("ERROR: No sig_file specified");
            $finish;
        end
        if (!$value$plusargs("sig_begin=%d", sig_begin)) begin
            $display("ERROR: No sig_begin specified");
            $finish;
        end
        if (!$value$plusargs("sig_end=%d", sig_end)) begin
            $display("ERROR: No sig_end specified");
            $finish;
        end

        $display("RISCOF Test Starting");
        $display("  Hex file: %s", hex_file);
        $display("  Sig file: %s", sig_file);
        $display("  Sig range: 0x%08x - 0x%08x", sig_begin, sig_end);

        // Load program
        $readmemh(hex_file, u_axil_ram.mem);

        // Reset
        rstn = 0;
        repeat(10) @(posedge clk);
        rstn = 1;

        // Wait for halt or timeout
        while (!cpu_halt && cycle_count < timeout_cycles) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end

        if (cycle_count >= timeout_cycles) begin
            $display("ERROR: Test timeout after %0d cycles", cycle_count);
        end else begin
            $display("Test halted after %0d cycles", cycle_count);
        end

        // Dump signature
        dump_signature();

        $display("RISCOF Test Complete");
        $finish;
    end

    // Task to dump signature region to file
    task dump_signature;
        integer fd;
        integer addr;
        reg [31:0] data;
        begin
            fd = $fopen(sig_file, "w");
            if (fd == 0) begin
                $display("ERROR: Could not open signature file");
                disable dump_signature;
            end

            for (addr = sig_begin; addr < sig_end; addr = addr + 4) begin
                data = u_axil_ram.mem[addr >> 2];
                $fwrite(fd, "%08x\n", data);
            end

            $fclose(fd);
            $display("Signature dumped: %0d words", (sig_end - sig_begin) / 4);
        end
    endtask

endmodule
