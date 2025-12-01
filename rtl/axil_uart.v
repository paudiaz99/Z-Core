
`timescale 1ns / 1ps

module axil_uart #
(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter STRB_WIDTH = (DATA_WIDTH/8)
)
(
    input  wire                   clk,
    input  wire                   rst,

    // AXI-Lite Slave Interface
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
    input  wire                   s_axil_rready
);

    // AXI-Lite Internal Registers
    reg s_axil_awready_reg = 0;
    reg s_axil_wready_reg = 0;
    reg s_axil_bvalid_reg = 0;
    reg s_axil_arready_reg = 0;
    reg s_axil_rvalid_reg = 0;
    reg [DATA_WIDTH-1:0] s_axil_rdata_reg = 0;

    // Internal Logic Signals
    reg [ADDR_WIDTH-1:0] write_addr_reg;
    reg [DATA_WIDTH-1:0] write_data_reg;
    reg [STRB_WIDTH-1:0] write_strb_reg;
    reg write_en;
    
    reg [ADDR_WIDTH-1:0] read_addr_reg;
    reg read_en;

    // Assignments
    assign s_axil_awready = s_axil_awready_reg;
    assign s_axil_wready = s_axil_wready_reg;
    assign s_axil_bresp = 2'b00; // OKAY
    assign s_axil_bvalid = s_axil_bvalid_reg;
    assign s_axil_arready = s_axil_arready_reg;
    assign s_axil_rdata = s_axil_rdata_reg;
    assign s_axil_rresp = 2'b00; // OKAY
    assign s_axil_rvalid = s_axil_rvalid_reg;

    // Write Channel Logic
    always @(posedge clk) begin
        if (rst) begin
            s_axil_awready_reg <= 0;
            s_axil_wready_reg <= 0;
            s_axil_bvalid_reg <= 0;
            write_en <= 0;
            write_addr_reg <= 0;
            write_data_reg <= 0;
            write_strb_reg <= 0;
        end else begin
            write_en <= 0; // Default

            // Address Handshake
            if (s_axil_awvalid && !s_axil_awready_reg && (!s_axil_bvalid_reg || s_axil_bready)) begin
                s_axil_awready_reg <= 1;
                write_addr_reg <= s_axil_awaddr;
            end else begin
                s_axil_awready_reg <= 0;
            end

            // Data Handshake
            if (s_axil_wvalid && !s_axil_wready_reg && (!s_axil_bvalid_reg || s_axil_bready)) begin
                s_axil_wready_reg <= 1;
                write_data_reg <= s_axil_wdata;
                write_strb_reg <= s_axil_wstrb;
            end else begin
                s_axil_wready_reg <= 0;
            end

            // Write Response
            if (s_axil_awready_reg && s_axil_wready_reg) begin
                s_axil_bvalid_reg <= 1;
                write_en <= 1; // Trigger internal write logic
            end else if (s_axil_bready && s_axil_bvalid_reg) begin
                s_axil_bvalid_reg <= 0;
            end
        end
    end

    // Read Channel Logic
    always @(posedge clk) begin
        if (rst) begin
            s_axil_arready_reg <= 0;
            s_axil_rvalid_reg <= 0;
            s_axil_rdata_reg <= 0;
            read_en <= 0;
            read_addr_reg <= 0;
        end else begin
            read_en <= 0; // Default

            // Address Handshake
            if (s_axil_arvalid && !s_axil_arready_reg && (!s_axil_rvalid_reg || s_axil_rready)) begin
                s_axil_arready_reg <= 1;
                read_addr_reg <= s_axil_araddr;
                read_en <= 1; // Trigger internal read logic
            end else begin
                s_axil_arready_reg <= 0;
            end

            // Read Response
            if (s_axil_arready_reg) begin
                s_axil_rvalid_reg <= 1;
                // For now, just return 0. In a real UART, we'd read registers based on read_addr_reg
                s_axil_rdata_reg <= 32'h0; 
            end else if (s_axil_rready && s_axil_rvalid_reg) begin
                s_axil_rvalid_reg <= 0;
            end
        end
    end

    // UART Specific Logic (Placeholder)
    // Example:
    // reg [31:0] control_reg;
    // always @(posedge clk) begin
    //     if (rst) control_reg <= 0;
    //     else if (write_en && write_addr_reg[3:0] == 4'h0) control_reg <= write_data_reg;
    // end

endmodule
