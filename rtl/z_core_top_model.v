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

// Write Address Channel
wire [ADDR_WIDTH-1:0]  axil_awaddr;
wire [2:0]             axil_awprot;
wire                   axil_awvalid;
wire                   axil_awready;

// Write Data Channel
wire [DATA_WIDTH-1:0]  axil_wdata;
wire [STRB_WIDTH-1:0]  axil_wstrb;
wire                   axil_wvalid;
wire                   axil_wready;

// Write Response Channel
wire [1:0]             axil_bresp;
wire                   axil_bvalid;
wire                   axil_bready;

// Read Address Channel
wire [ADDR_WIDTH-1:0]  axil_araddr;
wire [2:0]             axil_arprot;
wire                   axil_arvalid;
wire                   axil_arready;

// Read Data Channel
wire [DATA_WIDTH-1:0]  axil_rdata;
wire [1:0]             axil_rresp;
wire                   axil_rvalid;
wire                   axil_rready;


// **************************************************
//                Control Unit (CPU Core)
// **************************************************

z_core_control_u #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH)
) u_control_unit (
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


// **************************************************
//              Memory (AXI-Lite RAM)
// **************************************************

axil_ram #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(MEM_ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
    .PIPELINE_OUTPUT(PIPELINE_OUTPUT)
) u_memory (
    .clk(clk),
    .rstn(rstn),
    
    // AXI-Lite Slave Interface
    .s_axil_awaddr(axil_awaddr[MEM_ADDR_WIDTH-1:0]),
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
    .s_axil_araddr(axil_araddr[MEM_ADDR_WIDTH-1:0]),
    .s_axil_arprot(axil_arprot),
    .s_axil_arvalid(axil_arvalid),
    .s_axil_arready(axil_arready),
    .s_axil_rdata(axil_rdata),
    .s_axil_rresp(axil_rresp),
    .s_axil_rvalid(axil_rvalid),
    .s_axil_rready(axil_rready)
);

endmodule
