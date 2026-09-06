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
    input wire pipeline_enable,
    input wire write_buffer_forward,
    input wire write_buffer_full,

    input wire [ADDR_WIDTH-1:0] addr,
    input wire [DATA_WIDTH-1:0] data_in,
    
    output reg [DATA_WIDTH-1:0] data_out,
    output wire cache_hit_comb,
    output reg dirty_writeback_enabled,
    output reg [ADDR_WIDTH-1:0] dirty_writeback_addr,
    output reg [DATA_WIDTH-1:0] dirty_writeback_data,
    output reg [3:0] dirty_writeback_strb,
    output reg request_refill
);

reg [DATA_WIDTH-1:0] data_0 [CACHE_DEPTH-1:0];
reg [DATA_WIDTH-1:0] data_1 [CACHE_DEPTH-1:0];
reg [CACHE_TAG_WIDTH-1:0] tags_0 [CACHE_DEPTH-1:0];
reg [CACHE_TAG_WIDTH-1:0] tags_1 [CACHE_DEPTH-1:0];
reg valid_bits_0 [CACHE_DEPTH-1:0];
reg valid_bits_1 [CACHE_DEPTH-1:0];
reg dirty_bits_0 [CACHE_DEPTH-1:0];
reg dirty_bits_1 [CACHE_DEPTH-1:0];
reg lru_bits_0 [CACHE_DEPTH-1:0];
reg lru_bits_1 [CACHE_DEPTH-1:0];

reg [DATA_WIDTH-1:0] refill_buffer_data;
reg refill_buffer_set;
reg refill_wen;
reg [CACHE_ADDR_WIDTH-1:0] refill_index_q;
reg [CACHE_TAG_WIDTH-1:0]  refill_tag_q;

// Pipeline Registers
reg [CACHE_TAG_WIDTH-1:0] tag_0_q;
reg [CACHE_TAG_WIDTH-1:0] tag_1_q;
reg valid_0_q;
reg valid_1_q;
reg dirty_0_q;
reg dirty_1_q;
reg lru_0_q;
reg lru_1_q;
reg [ADDR_WIDTH-1:0] data_addr_q;

wire [CACHE_TAG_WIDTH-1:0] tag_addr = addr[ADDR_WIDTH-1:CACHE_ADDR_WIDTH+2];
wire [CACHE_ADDR_WIDTH-1:0] index_addr = addr[CACHE_ADDR_WIDTH+1:2];

wire [CACHE_TAG_WIDTH-1:0] tag_addr_q = data_addr_q[ADDR_WIDTH-1:CACHE_ADDR_WIDTH+2];
wire [CACHE_ADDR_WIDTH-1:0] index_addr_q = data_addr_q[CACHE_ADDR_WIDTH+1:2];
    
// 2-Set Associative Cache - Set One and Set Two Hits
wire set_one_hit = tag_0_q == tag_addr_q && valid_0_q;
wire set_two_hit = tag_1_q == tag_addr_q && valid_1_q;

wire valid_bit_set_one = valid_0_q;
wire valid_bit_set_two = valid_1_q;

assign cache_hit_comb = ((set_one_hit && valid_bit_set_one) || (set_two_hit && valid_bit_set_two)) && cs;
wire set_to_write_on_hit = (set_one_hit && valid_bit_set_one) ? 1'b0 : 1'b1;

// Dirty Bit Checks
wire dirty_bit_set_one = dirty_0_q;
wire dirty_bit_set_two = dirty_1_q;


// LRU Bit Checks
wire lru_bit_set_one = lru_0_q;
wire lru_bit_set_two = lru_1_q;

wire lru_bit_set_to_write = lru_bit_set_one ? 0 : 1;

// Empty Slot Checks
wire empty_slot = !valid_bit_set_one || !valid_bit_set_two;
wire empty_slot_set_one = !valid_0_q;
wire empty_slot_to_write = empty_slot_set_one ? 0 : 1;

// Final set to write on miss
wire set_to_write_on_miss = empty_slot ? empty_slot_to_write : lru_bit_set_to_write;

wire [DATA_WIDTH-1:0] mask = {8{strb[0]}} << 0 | {8{strb[1]}} << 8 | {8{strb[2]}} << 16 | {8{strb[3]}} << 24;

// Write
always @(posedge clk) begin
    dirty_writeback_enabled <= 1'b0;
    if (!rstn) begin
        // Reset logic
        for(int j = 0; j < CACHE_DEPTH; j++) begin
            valid_bits_0[j] <= 1'b0;
            valid_bits_1[j] <= 1'b0;
            dirty_bits_0[j] <= 1'b0;
            dirty_bits_1[j] <= 1'b0;
            lru_bits_0[j] <= 1'b0;
            lru_bits_1[j] <= 1'b0;
            data_0[j] <= 32'b0;
            data_1[j] <= 32'b0;
            tags_0[j] <= {CACHE_TAG_WIDTH{1'b0}};
            tags_1[j] <= {CACHE_TAG_WIDTH{1'b0}};
        end
        dirty_writeback_enabled <= 1'b0;
        data_out <= 32'b0;
        request_refill <= 1'b0;
        refill_index_q <= {CACHE_ADDR_WIDTH{1'b0}};
        refill_tag_q   <= {CACHE_TAG_WIDTH{1'b0}};
    end else if(refill_complete) begin
        dirty_writeback_enabled <= 1'b0;
        request_refill <= 1'b0;
        if(!refill_buffer_set) begin
            data_0[refill_index_q] <= (refill_wen ? data_in & ~mask | refill_buffer_data & mask : data_in & mask);
            tags_0[refill_index_q] <= refill_tag_q;
            valid_bits_0[refill_index_q] <= 1'b1;
            dirty_bits_0[refill_index_q] <= refill_wen;
            lru_bits_0[refill_index_q] <= 1'b0;
            lru_bits_1[refill_index_q] <= 1'b1;
        end else begin
            data_1[refill_index_q] <= (refill_wen ? data_in & ~mask | refill_buffer_data & mask : data_in & mask);
            tags_1[refill_index_q] <= refill_tag_q;
            valid_bits_1[refill_index_q] <= 1'b1;
            dirty_bits_1[refill_index_q] <= refill_wen;
            lru_bits_1[refill_index_q] <= 1'b0;
            lru_bits_0[refill_index_q] <= 1'b1;
        end
    end else if (!cs) begin
        dirty_writeback_enabled <= dirty_writeback_enabled ? 1'b0 : dirty_writeback_enabled;
    end else if(cs && wen) begin
        if(cache_hit_comb) begin
            dirty_writeback_enabled <= 1'b0;
            if(!set_to_write_on_hit) begin
                data_0[index_addr_q] <= data_0[index_addr_q] & ~mask | data_in & mask;
                tags_0[index_addr_q] <= tag_addr_q;
                valid_bits_0[index_addr_q] <= 1'b1;
                dirty_bits_0[index_addr_q] <= 1'b1;
                lru_bits_0[index_addr_q] <= 1'b0;
                lru_bits_1[index_addr_q] <= 1'b1;
            end else begin
                data_1[index_addr_q] <= data_1[index_addr_q] & ~mask | data_in & mask;
                tags_1[index_addr_q] <= tag_addr_q;
                valid_bits_1[index_addr_q] <= 1'b1;
                dirty_bits_1[index_addr_q] <= 1'b1;
                lru_bits_1[index_addr_q] <= 1'b0;
                lru_bits_0[index_addr_q] <= 1'b1;
            end
        end else if(!request_refill && !write_buffer_full) begin
            dirty_writeback_enabled <= set_to_write_on_miss ? (dirty_bits_1[index_addr_q]) : (dirty_bits_0[index_addr_q]);
            dirty_writeback_addr <= {set_to_write_on_miss ? (tags_1[index_addr_q]) : (tags_0[index_addr_q]), index_addr_q, 2'b00};
            dirty_writeback_data <= set_to_write_on_miss ? (data_1[index_addr_q]) : (data_0[index_addr_q]);
            dirty_writeback_strb <= 4'b1111;
            if(write_buffer_forward) begin
                if(!set_to_write_on_miss) begin
                    data_0[index_addr_q] <= (data_0[index_addr_q] & ~mask) | (data_in & mask);
                    tags_0[index_addr_q] <= tag_addr_q;
                    valid_bits_0[index_addr_q] <= 1'b1;
                    dirty_bits_0[index_addr_q] <= 1'b1;
                    lru_bits_0[index_addr_q] <= 1'b0;
                    lru_bits_1[index_addr_q] <= 1'b1;
                end else begin
                    data_1[index_addr_q] <= (data_1[index_addr_q] & ~mask) | (data_in & mask);
                    tags_1[index_addr_q] <= tag_addr_q;
                    valid_bits_1[index_addr_q] <= 1'b1;
                    dirty_bits_1[index_addr_q] <= 1'b1;
                    lru_bits_1[index_addr_q] <= 1'b0;
                    lru_bits_0[index_addr_q] <= 1'b1;
                end
            end else begin
                refill_index_q <= index_addr_q;
                refill_tag_q   <= tag_addr_q;
                refill_buffer_data <= data_in & mask;
                refill_buffer_set <= set_to_write_on_miss;
                refill_wen <= 1'b1;
                request_refill <= 1'b1;
            end
        end else begin
            dirty_writeback_enabled <= 1'b0;
        end
    end else if(cs && !wen) begin
        if(cache_hit_comb) begin
            dirty_writeback_enabled <= 1'b0;
            data_out <= set_to_write_on_hit ? (data_1[index_addr_q] & mask) : (data_0[index_addr_q] & mask);
        end else if(!request_refill && !write_buffer_full) begin
            dirty_writeback_enabled <= set_to_write_on_miss ? (dirty_bits_1[index_addr_q]) : (dirty_bits_0[index_addr_q]);
            dirty_writeback_addr <= {set_to_write_on_miss ? (tags_1[index_addr_q]) : (tags_0[index_addr_q]), index_addr_q, 2'b00};
            dirty_writeback_data <= set_to_write_on_miss ? (data_1[index_addr_q]) : (data_0[index_addr_q]);
            dirty_writeback_strb <= 4'b1111;
            if(write_buffer_forward) begin
                if(!set_to_write_on_miss) begin
                    data_0[index_addr_q] <= (data_0[index_addr_q] & ~mask) | (data_in & mask);
                    tags_0[index_addr_q] <= tag_addr_q;
                    valid_bits_0[index_addr_q] <= 1'b1;
                    dirty_bits_0[index_addr_q] <= 1'b1;
                    lru_bits_0[index_addr_q] <= 1'b0;
                    lru_bits_1[index_addr_q] <= 1'b1;
                end else begin
                    data_1[index_addr_q] <= (data_1[index_addr_q] & ~mask) | (data_in & mask);
                    tags_1[index_addr_q] <= tag_addr_q;
                    valid_bits_1[index_addr_q] <= 1'b1;
                    dirty_bits_1[index_addr_q] <= 1'b1;
                    lru_bits_1[index_addr_q] <= 1'b0;
                    lru_bits_0[index_addr_q] <= 1'b1;
                end
            end else begin
                refill_index_q <= index_addr_q;
                refill_tag_q   <= tag_addr_q;
                request_refill <= 1'b1;
                refill_buffer_set <= set_to_write_on_miss;
                refill_wen <= 1'b0;
                data_out <= 32'b0;
            end
        end else begin
            dirty_writeback_enabled <= 1'b0;
        end
    end
end

// Update Pipeline Registers
always @(posedge clk) begin
    if (!rstn) begin
        tag_0_q <= 32'b0;
        tag_1_q <= 32'b0;
        valid_0_q <= 1'b0;
        valid_1_q <= 1'b0;
        dirty_0_q <= 1'b0;
        dirty_1_q <= 1'b0;
        lru_0_q <= 1'b0;
        lru_1_q <= 1'b0;
        data_addr_q <= 32'b0;
    end else if (pipeline_enable) begin
        tag_0_q <= tags_0[index_addr];
        tag_1_q <= tags_1[index_addr];
        valid_0_q <= valid_bits_0[index_addr];
        valid_1_q <= valid_bits_1[index_addr];
        dirty_0_q <= dirty_bits_0[index_addr];
        dirty_1_q <= dirty_bits_1[index_addr];
        lru_0_q <= lru_bits_0[index_addr];
        lru_1_q <= lru_bits_1[index_addr];
        data_addr_q <= addr;
    end
end


endmodule