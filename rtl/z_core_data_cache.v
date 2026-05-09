module z_core_data_cache #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter CACHE_ENTRIES = 8192,
    parameter ASSOCIATIVITY = 2,
    parameter CACHE_LINE_SIZE = 4,
    parameter CACHE_DEPTH = CACHE_ENTRIES / ASSOCIATIVITY,
    parameter CACHE_ADDR_WIDTH = $clog2(CACHE_DEPTH),
    parameter CACHE_TAG_WIDTH = ADDR_WIDTH - 2 - CACHE_ADDR_WIDTH
)(
    input wire clk,
    input wire rstn,
    input wire wen,
    input wire cs,
    input wire [3:0] strb,
    input wire refill_complete,

    input wire [ADDR_WIDTH-1:0] addr,
    input wire [DATA_WIDTH-1:0] data_in,
    
    output reg [DATA_WIDTH-1:0] data_out,
    output reg cache_hit,
    output reg dirty_writeback_enabled,
    output reg [ADDR_WIDTH-1:0] dirty_writeback_addr,
    output reg [DATA_WIDTH-1:0] dirty_writeback_data,
    output reg [3:0] dirty_writeback_strb,
    output reg request_refill
);

reg [DATA_WIDTH-1:0] data [ASSOCIATIVITY-1:0] [CACHE_DEPTH-1:0];
reg [CACHE_TAG_WIDTH-1:0] tags [ASSOCIATIVITY-1:0] [CACHE_DEPTH-1:0];
reg valid_bits [ASSOCIATIVITY-1:0] [CACHE_DEPTH-1:0];
reg dirty_bits [ASSOCIATIVITY-1:0] [CACHE_DEPTH-1:0];
reg lru_bits [ASSOCIATIVITY-1:0] [CACHE_DEPTH-1:0];

reg [DATA_WIDTH-1:0] refill_buffer_data;
reg refill_buffer_set;
reg refill_wen;

wire [CACHE_TAG_WIDTH-1:0] tag_addr = addr[ADDR_WIDTH-1:CACHE_ADDR_WIDTH+2];
wire [CACHE_ADDR_WIDTH-1:0] index_addr = addr[CACHE_ADDR_WIDTH+1:2];

// 2-Set Associative Cache - Set One and Set Two Hits
wire set_one_hit = tags[0][index_addr] == tag_addr && valid_bits[0][index_addr];
wire set_two_hit = tags[1][index_addr] == tag_addr && valid_bits[1][index_addr];

wire valid_bit_set_one = valid_bits[0][index_addr];
wire valid_bit_set_two = valid_bits[1][index_addr];

wire cache_hit_comb = (set_one_hit && valid_bit_set_one) || (set_two_hit && valid_bit_set_two);
wire set_to_write_on_hit = (set_one_hit && valid_bit_set_one) ? 1'b0 : 1'b1;

// Dirty Bit Checks
wire dirty_bit_set_one = dirty_bits[0][index_addr];
wire dirty_bit_set_two = dirty_bits[1][index_addr];


// LRU Bit Checks
wire lru_bit_set_one = lru_bits[0][index_addr];
wire lru_bit_set_two = lru_bits[1][index_addr];

wire lru_bit_set_to_write = lru_bit_set_one ? 0 : 1;

// Empty Slot Checks
wire empty_slot = !valid_bit_set_one || !valid_bit_set_two;
wire empty_slot_set_one = !valid_bits[0][index_addr];
wire empty_slot_to_write = empty_slot_set_one ? 0 : 1;

// Final set to write on miss
wire set_to_write_on_miss = empty_slot ? empty_slot_to_write : lru_bit_set_to_write;

wire [DATA_WIDTH-1:0] mask = {8{strb[0]}} << 0 | {8{strb[1]}} << 8 | {8{strb[2]}} << 16 | {8{strb[3]}} << 24;

// Write
always @(posedge clk) begin
    if (!rstn) begin
        // Reset logic
        for(int i = 0; i < ASSOCIATIVITY; i++) begin
            for(int j = 0; j < CACHE_DEPTH; j++) begin
                valid_bits[i][j] <= 1'b0;
                dirty_bits[i][j] <= 1'b0;
                lru_bits[i][j] <= 1'b0;
                data[i][j] <= 32'b0;
                tags[i][j] <= 32'b0;
            end
        end
        dirty_writeback_enabled <= 1'b0;
        cache_hit <= 1'b0;
        data_out <= 32'b0;
        request_refill <= 1'b0;
    end else if(refill_complete) begin
        request_refill <= 1'b0;
        data[refill_buffer_set][index_addr] <= (refill_wen ? data_in & ~mask | refill_buffer_data & mask : data_in);
        tags[refill_buffer_set][index_addr] <= tag_addr;
        valid_bits[refill_buffer_set][index_addr] <= 1'b1;
        dirty_bits[refill_buffer_set][index_addr] <= 1'b1;
        lru_bits[refill_buffer_set][index_addr] <= 1'b0;
        lru_bits[!refill_buffer_set][index_addr] <= 1'b1;
    end else if (!cs) begin
        cache_hit <= cache_hit ? 1'b0 : cache_hit;
        dirty_writeback_enabled <= dirty_writeback_enabled ? 1'b0 : dirty_writeback_enabled;
    end else if(cs && wen) begin
        if(cache_hit_comb) begin
            data[set_to_write_on_hit][index_addr] <= data_in & mask;
            tags[set_to_write_on_hit][index_addr] <= tag_addr;
            valid_bits[set_to_write_on_hit][index_addr] <= 1'b1;
            dirty_bits[set_to_write_on_hit][index_addr] <= 1'b1;
            lru_bits[set_to_write_on_hit][index_addr] <= 1'b0;
            lru_bits[!set_to_write_on_hit][index_addr] <= 1'b1;
            cache_hit <= 1'b1;
        end else begin
            dirty_writeback_enabled <= dirty_bits[set_to_write_on_miss][index_addr];
            dirty_writeback_addr <= {tags[set_to_write_on_miss][index_addr], index_addr, 2'b00};
            dirty_writeback_data <= data[set_to_write_on_miss][index_addr];
            dirty_writeback_strb <= 4'b1111;
            refill_buffer_data <= data_in & mask;
            refill_buffer_set <= set_to_write_on_miss;
            refill_wen <= 1'b1;
            request_refill <= 1'b1;
            cache_hit <= 1'b0;
        end
    end else if(cs && !wen) begin
        if(cache_hit_comb) begin
            data_out <= data[set_to_write_on_hit][index_addr];
            cache_hit <= 1'b1;
        end else begin
            dirty_writeback_enabled <= dirty_bits[set_to_write_on_miss][index_addr];
            dirty_writeback_addr <= {tags[set_to_write_on_miss][index_addr], index_addr, 2'b00};
            dirty_writeback_data <= data[set_to_write_on_miss][index_addr];
            dirty_writeback_strb <= 4'b1111;
            request_refill <= 1'b1;
            refill_buffer_set <= set_to_write_on_miss;
            refill_wen <= 1'b0;
            data_out <= 32'b0;
            cache_hit <= 1'b0;
        end
    end
end


endmodule