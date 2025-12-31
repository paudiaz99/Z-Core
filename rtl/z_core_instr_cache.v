module z_core_instr_cache #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter CACHE_DEPTH = 256
) (
    input wire clk,
    input wire rstn,
    input wire wen,
    input wire [ADDR_WIDTH-1:0] address,
    input wire [DATA_WIDTH-1:0] data_in,
    output wire [DATA_WIDTH-1:0] data_out,

    output wire valid,
    output wire cache_hit,
    output wire cache_miss
);

// **************************************************
//      Direct Mapped Instruction Cache (256x32)
//      Asynchronous Read - Combinational output
//      Synchronous Write
// **************************************************

localparam CACHE_ADDR_WIDTH = $clog2(CACHE_DEPTH);
localparam CACHE_TAG_WIDTH = ADDR_WIDTH - 2 - CACHE_ADDR_WIDTH;

reg [DATA_WIDTH-1:0] instr_cache [CACHE_DEPTH-1:0];
reg [CACHE_TAG_WIDTH-1:0] instr_cache_tag [CACHE_DEPTH-1:0];
reg [CACHE_DEPTH-1:0] instr_cache_valid;

wire [CACHE_TAG_WIDTH-1:0] tag = address[ADDR_WIDTH-1:ADDR_WIDTH-CACHE_TAG_WIDTH];
wire [CACHE_ADDR_WIDTH-1:0] addr = address[CACHE_ADDR_WIDTH+1:2];

// Asynchronous (combinational) read outputs
assign data_out = instr_cache[addr];
assign cache_hit = (instr_cache_tag[addr] == tag) && instr_cache_valid[addr];
assign cache_miss = !((instr_cache_tag[addr] == tag) && instr_cache_valid[addr]);
assign valid = (instr_cache_tag[addr] == tag) && instr_cache_valid[addr];

// Synchronous write and reset
always @(posedge clk) begin
    if (!rstn) begin
        instr_cache_valid <= {CACHE_DEPTH{1'b0}};
    end else if (wen) begin
        instr_cache[addr] <= data_in;
        instr_cache_tag[addr] <= tag;
        instr_cache_valid[addr] <= 1'b1;
    end
end

endmodule
