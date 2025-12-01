// **************************************************
//                    Z-Core Top Model
// 
// A complete RISC-V RV32I processor with AXI-Lite
// memory interface.
//
// TODO LIST
// 1. Instance Control Unit, Memory, and IO Modules [DONE]
// 2. Implement Testbench [DONE]
// 3. Verify correctness of the CPU using Simulation [DONE]
// 4. Synthesize and Test on FPGA
//
// **************************************************

`include "rtl/z_core_control_u.v"
`include "rtl/axi_mem.v"
`include "rtl/axil_interconnect.v"
`include "rtl/axil_uart.v"
`include "rtl/axil_gpio.v"

module z_core_top #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    parameter MEM_ADDR_WIDTH = 16,      // 64KB memory
    parameter PIPELINE_OUTPUT = 0
)(
    input wire clk,
    input wire rstn
);

// **************************************************
//              AXI-Lite Interconnect Wires
// **************************************************



// **************************************************
//              AXI-Lite Interconnect
// **************************************************

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
    
    // Slave Interfaces (Connect to Masters)
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

// **************************************************
//                Control Unit (Master 0)
// **************************************************

z_core_control_u #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH)
) u_control_unit (
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
    .m_axil_rready(s_axil_rready)
);


// **************************************************
//              Memory (Slave 0)
// **************************************************

axil_ram #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(26), // 64MB
    .STRB_WIDTH(STRB_WIDTH),
    .PIPELINE_OUTPUT(PIPELINE_OUTPUT)
) u_memory (
    .clk(clk),
    .rstn(rstn),
    
    // AXI-Lite Slave Interface <- Interconnect Master 0
    .s_axil_awaddr(m_axil_awaddr[0*ADDR_WIDTH +: 26]), // Truncate to local size
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
    .s_axil_araddr(m_axil_araddr[0*ADDR_WIDTH +: 26]), // Truncate to local size
    .s_axil_arprot(m_axil_arprot[0*3 +: 3]),
    .s_axil_arvalid(m_axil_arvalid[0]),
    .s_axil_arready(m_axil_arready[0]),
    .s_axil_rdata(m_axil_rdata[0*DATA_WIDTH +: DATA_WIDTH]),
    .s_axil_rresp(m_axil_rresp[0*2 +: 2]),
    .s_axil_rvalid(m_axil_rvalid[0]),
    .s_axil_rready(m_axil_rready[0])
);

// **************************************************
//              UART (Slave 1)
// **************************************************

axil_uart #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(12), // 4KB
    .STRB_WIDTH(STRB_WIDTH)
) u_uart (
    .clk(clk),
    .rst(~rstn), // Active high reset
    
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

// **************************************************
//              GPIO (Slave 2)
// **************************************************

axil_gpio #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(12), // 4KB
    .STRB_WIDTH(STRB_WIDTH)
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
    .s_axil_rready(m_axil_rready[2])
);

endmodule
