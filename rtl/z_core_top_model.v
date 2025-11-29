// **************************************************
//                    TODO LIST
// 1. Instance Control Unit, Memory, and IO Modules [DONE]
// 2. Implement Testbench (Once All Modules are Done and Tested) [IN PROGRESS]
// 3. Verify correctness of the CPU using Simulation
// 4. Synthesize and Test on FPGA
//
// **************************************************

module top_model # (

    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    parameter PIPELINE_OUTPUT = 0
)
(
    input clk,
    input resetn
);

// **************************************************
//              Wires and Assignments
// **************************************************


wire [ADDR_WIDTH-1:0] aw_addr;
wire [2:0] aw_prot;
wire aw_valid;
wire aw_ready;

wire [DATA_WIDTH-1:0] w_data;
wire [STRB_WIDTH-1:0] w_strb;
wire w_valid;
wire w_ready;

wire [1:0] b_resp;
wire b_ready;
wire b_valid;


wire [ADDR_WIDTH-1:0] ar_addr;
wire ar_valid;
wire [2:0] ar_prot;
wire ar_ready;

wire [DATA_WIDTH-1:0] r_data;
wire [2:0] r_resp;
wire r_valid;
wire r_ready;


// **************************************************
//                Control Unit
// **************************************************

z_core_control_u control_unit (
    .clk(clk)
    ,.rstn(resetn)
    ,.aw_addr(aw_addr)
    ,.aw_prot(aw_prot)
    ,.aw_valid(aw_valid)
    ,.aw_ready(aw_ready)
    ,.w_data(w_data)
    ,.w_strb(w_strb)
    ,.w_valid(w_valid)
    ,.w_ready(w_ready)
    ,.b_resp(b_resp)
    ,.b_ready(b_ready)
    ,.b_valid(b_valid)
    ,.ar_addr(ar_addr)
    ,.ar_prot(ar_prot)
    ,.ar_valid(ar_valid)
    ,.ar_ready(ar_ready)
    ,.r_data(r_data)
    ,.r_resp(r_resp)
    ,.r_valid(r_valid)
    ,.r_ready(r_ready)
)


// **************************************************
//                Memory
// **************************************************

z_axi_mem_if memory (
    .clk(clk)
    ,.rstn(resetn)
    ,.aw_addr(aw_addr)
    ,.aw_prot(aw_prot)
    ,.aw_valid(aw_valid)
    ,.aw_ready(aw_ready)
    ,.w_data(w_data)
    ,.w_strb(w_strb)
    ,.w_valid(w_valid)
    ,.w_ready(w_ready)
    ,.b_resp(b_resp)
    ,.b_ready(b_ready)
    ,.b_valid(b_valid)
    ,.ar_addr(ar_addr)
    ,.ar_prot(ar_prot)
    ,.ar_valid(ar_valid)
    ,.ar_ready(ar_ready)
    ,.r_data(r_data)
    ,.r_resp(r_resp)
    ,.r_valid(r_valid)
    ,.r_ready(r_ready)
)


endmodule