
`timescale 1ns / 1ps

module axil_slave #
(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter STRB_WIDTH = (DATA_WIDTH/8)
)
(
    input  wire                   clk,
    input  wire                   rst,

    // AXI-Lite Interface
    input  wire [ADDR_WIDTH-1:0]  s_axil_awaddr,
    input  wire [2:0]             s_axil_awprot,
    input  wire                   s_axil_awvalid,
    output wire                   s_axil_awready,
    input  wire [DATA_WIDTH-1:0]  s_axil_wdata,
    input  wire [STRB_WIDTH-1:0]  s_axil_wstrb,
    input  wire                   s_axil_wvalid,
    output wire                   s_axil_wready,
    output wire [1:0]             s_axil_bresp,
    output wire                   s_axil_bvalid,
    input  wire                   s_axil_bready,
    input  wire [ADDR_WIDTH-1:0]  s_axil_araddr,
    input  wire [2:0]             s_axil_arprot,
    input  wire                   s_axil_arvalid,
    output wire                   s_axil_arready,
    output wire [DATA_WIDTH-1:0]  s_axil_rdata,
    output wire [1:0]             s_axil_rresp,
    output wire                   s_axil_rvalid,
    input  wire                   s_axil_rready,

    // User Interface
    output wire [ADDR_WIDTH-1:0]  usr_addr,
    output wire [DATA_WIDTH-1:0]  usr_wdata,
    output wire [STRB_WIDTH-1:0]  usr_wstrb,
    output wire                   usr_wen,
    output wire                   usr_ren,
    input  wire [DATA_WIDTH-1:0]  usr_rdata
);

    // Write Channel
    reg s_axil_awready_reg = 0;
    reg s_axil_wready_reg = 0;
    reg s_axil_bvalid_reg = 0;
    reg [ADDR_WIDTH-1:0] usr_addr_reg;
    reg [DATA_WIDTH-1:0] usr_wdata_reg;
    reg [STRB_WIDTH-1:0] usr_wstrb_reg;
    reg usr_wen_reg;

    assign s_axil_awready = s_axil_awready_reg;
    assign s_axil_wready = s_axil_wready_reg;
    assign s_axil_bresp = 2'b00; // OKAY
    assign s_axil_bvalid = s_axil_bvalid_reg;

    // Read Channel
    reg s_axil_arready_reg = 0;
    reg s_axil_rvalid_reg = 0;
    reg [DATA_WIDTH-1:0] s_axil_rdata_reg = 0;
    reg usr_ren_reg;

    assign s_axil_arready = s_axil_arready_reg;
    assign s_axil_rdata = s_axil_rdata_reg;
    assign s_axil_rresp = 2'b00; // OKAY
    assign s_axil_rvalid = s_axil_rvalid_reg;

    // User Interface Assignments
    // We share usr_addr for both read and write. 
    // Priority could be given to one, but AXI-Lite usually separates them.
    // Here, if both happen, we might need arbitration or just separate signals.
    // For simplicity, let's drive usr_addr from whichever channel is active.
    // Since this is a simple slave, we can assume we process one at a time or just mux it.
    // However, to be safe, let's use the registered address.
    
    assign usr_addr = usr_wen_reg ? usr_addr_reg : (usr_ren_reg ? usr_addr_reg : {ADDR_WIDTH{1'b0}});
    assign usr_wdata = usr_wdata_reg;
    assign usr_wstrb = usr_wstrb_reg;
    assign usr_wen = usr_wen_reg;
    assign usr_ren = usr_ren_reg;

    always @(posedge clk) begin
        if (rst) begin
            s_axil_awready_reg <= 0;
            s_axil_wready_reg <= 0;
            s_axil_bvalid_reg <= 0;
            usr_wen_reg <= 0;
            usr_addr_reg <= 0;
            usr_wdata_reg <= 0;
            usr_wstrb_reg <= 0;
        end else begin
            usr_wen_reg <= 0; // Default to 0

            if (s_axil_awvalid && !s_axil_awready_reg && (!s_axil_bvalid_reg || s_axil_bready)) begin
                s_axil_awready_reg <= 1;
                usr_addr_reg <= s_axil_awaddr;
            end else begin
                s_axil_awready_reg <= 0;
            end

            if (s_axil_wvalid && !s_axil_wready_reg && (!s_axil_bvalid_reg || s_axil_bready)) begin
                s_axil_wready_reg <= 1;
                usr_wdata_reg <= s_axil_wdata;
                usr_wstrb_reg <= s_axil_wstrb;
            end else begin
                s_axil_wready_reg <= 0;
            end

            if (s_axil_awready_reg && s_axil_wready_reg) begin
                s_axil_bvalid_reg <= 1;
                usr_wen_reg <= 1; // Trigger write enable to user logic
            end else if (s_axil_bready && s_axil_bvalid_reg) begin
                s_axil_bvalid_reg <= 0;
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            s_axil_arready_reg <= 0;
            s_axil_rvalid_reg <= 0;
            s_axil_rdata_reg <= 0;
            usr_ren_reg <= 0;
        end else begin
            usr_ren_reg <= 0; // Default to 0

            if (s_axil_arvalid && !s_axil_arready_reg && (!s_axil_rvalid_reg || s_axil_rready)) begin
                s_axil_arready_reg <= 1;
                usr_addr_reg <= s_axil_araddr; // Capture read address
                usr_ren_reg <= 1; // Trigger read enable to user logic
            end else begin
                s_axil_arready_reg <= 0;
            end

            if (s_axil_arready_reg) begin
                s_axil_rvalid_reg <= 1;
                // We assume user logic provides data immediately (combinational read) or we latch it.
                // For this simple wrapper, we assume combinational read or 1-cycle latency if we wait.
                // But here we are asserting rvalid next cycle.
                // If usr_ren is high this cycle, usr_rdata should be valid next cycle?
                // Or usr_rdata is valid combinatorially based on usr_addr?
                // Let's assume usr_rdata is valid when usr_ren is asserted (combinational read from register).
                s_axil_rdata_reg <= usr_rdata; 
            end else if (s_axil_rready && s_axil_rvalid_reg) begin
                s_axil_rvalid_reg <= 0;
            end
        end
    end

endmodule
