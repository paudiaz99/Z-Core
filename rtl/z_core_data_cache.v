module z_core_data_cache #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter CACHE_ENTRIES = 1024,
    parameter ASSOCIATIVITY = 2,
    parameter CACHE_LINE_SIZE = 4,
    parameter CACHE_DEPTH = CACHE_ENTRIES / ASSOCIATIVITY,
    parameter CACHE_ADDR_WIDTH = $clog2(CACHE_DEPTH),
    parameter CACHE_TAG_WIDTH = ADDR_WIDTH - 2 - CACHE_ADDR_WIDTH
)(
    input wire clk,
    input wire rstn,
    input wire wen,

    input wire [ADDR_WIDTH-1:0] addr,
    input wire [DATA_WIDTH-1:0] data_in,
    input wire eviction_complete,
    
    output reg [DATA_WIDTH-1:0] data_out,
    output reg cache_hit,
    output reg wait_for_eviction_complete
);

reg [DATA_WIDTH-1:0] data [ASSOCIATIVITY-1:0] [CACHE_DEPTH-1:0];
reg [CACHE_TAG_WIDTH-1:0] tags [ASSOCIATIVITY-1:0] [CACHE_DEPTH-1:0];
reg valid_bits [ASSOCIATIVITY-1:0] [CACHE_DEPTH-1:0];
reg dirty_bits [ASSOCIATIVITY-1:0] [CACHE_DEPTH-1:0];
reg lru_bits [ASSOCIATIVITY-1:0] [CACHE_DEPTH-1:0];

wire [CACHE_TAG_WIDTH-1:0] tag_addr = addr[ADDR_WIDTH-1:CACHE_ADDR_WIDTH+2];
wire [CACHE_ADDR_WIDTH-1:0] index_addr = addr[CACHE_ADDR_WIDTH+1:2];

reg [DATA_WIDTH-1:0] data_to_write_on_eviction;
reg [CACHE_TAG_WIDTH-1:0] tag_to_write_on_eviction;
reg [CACHE_ADDR_WIDTH-1:0] index_to_write_on_eviction;
reg [ASSOCIATIVITY-1:0] set_index_to_write_on_eviction;

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
        data_to_write_on_eviction <= 32'b0;
        tag_to_write_on_eviction <= 32'b0;
        index_to_write_on_eviction <= 32'b0;
        set_index_to_write_on_eviction <= 2'b0;
        wait_for_eviction_complete <= 1'b0;
        cache_hit <= 1'b0;
        data_out <= 32'b0;
    end else if(wait_for_eviction_complete) begin
        if(eviction_complete) begin
            data[set_index_to_write_on_eviction][index_to_write_on_eviction] <= data_to_write_on_eviction;
            tags[set_index_to_write_on_eviction][index_to_write_on_eviction] <= tag_to_write_on_eviction;
            valid_bits[set_index_to_write_on_eviction][index_to_write_on_eviction] <= 1'b1;
            dirty_bits[set_index_to_write_on_eviction][index_to_write_on_eviction] <= 1'b1;
            lru_bits[set_index_to_write_on_eviction][index_to_write_on_eviction] <= 1'b0;
            lru_bits[!set_index_to_write_on_eviction][index_to_write_on_eviction] <= 1'b1;
            wait_for_eviction_complete <= 1'b0;
        end   
    end else if(wen) begin
        if(cache_hit_comb) begin
            data[set_to_write_on_hit][index_addr] <= data_in;
            tags[set_to_write_on_hit][index_addr] <= tag_addr;
            valid_bits[set_to_write_on_hit][index_addr] <= 1'b1;
            dirty_bits[set_to_write_on_hit][index_addr] <= 1'b1;
            lru_bits[set_to_write_on_hit][index_addr] <= 1'b0;
            lru_bits[!set_to_write_on_hit][index_addr] <= 1'b1;
        end else begin
            if(dirty_bits[set_to_write_on_miss][index_addr]) begin
                wait_for_eviction_complete <= 1'b1;
            end else begin
                data[set_to_write_on_miss][index_addr] <= data_in;
                tags[set_to_write_on_miss][index_addr] <= tag_addr;
                valid_bits[set_to_write_on_miss][index_addr] <= 1'b1;
                dirty_bits[set_to_write_on_miss][index_addr] <= 1'b1;
                lru_bits[set_to_write_on_miss][index_addr] <= 1'b0;
                lru_bits[!set_to_write_on_miss][index_addr] <= 1'b1;
            end
        end
    end else begin
        if(cache_hit_comb) begin
            data_out <= data[set_to_write_on_hit][index_addr];
            cache_hit <= 1'b1;
        end else begin
            // TODO: Handle cache miss
            data_out <= 32'b0;
            cache_hit <= 1'b0;
        end
    end
end


endmodule