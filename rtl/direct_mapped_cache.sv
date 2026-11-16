`timescale 1ns/1ps
// Phase I: read-only, direct-mapped cache with a block-refill memory interface.
// Requests must be aligned to DATA_WIDTH/8 bytes. One request is outstanding.
module direct_mapped_cache #(
    parameter int ADDR_WIDTH  = 32,
    parameter int DATA_WIDTH  = 32,
    parameter int CACHE_BYTES = 1024,
    parameter int BLOCK_BYTES = 16
) (
    input  logic                          clk,
    input  logic                          rst_n,

    input  logic                          req_valid,
    output logic                          req_ready,
    input  logic [ADDR_WIDTH-1:0]         req_addr,
    output logic                          resp_valid,
    output logic [DATA_WIDTH-1:0]         resp_data,
    output logic                          resp_hit,

    output logic                          mem_req_valid,
    input  logic                          mem_req_ready,
    output logic [ADDR_WIDTH-1:0]         mem_req_addr,
    input  logic                          mem_resp_valid,
    input  logic [BLOCK_BYTES*8-1:0]      mem_resp_block,

    output logic [31:0]                   hit_count,
    output logic [31:0]                   miss_count
);
    localparam int LINE_COUNT  = CACHE_BYTES / BLOCK_BYTES;
    localparam int INDEX_BITS  = $clog2(LINE_COUNT);
    localparam int OFFSET_BITS = $clog2(BLOCK_BYTES);
    localparam int TAG_BITS    = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS;
    localparam int WORD_BYTES  = DATA_WIDTH / 8;

    typedef enum logic [1:0] {
        IDLE, LOOKUP, MISS_REQUEST, MISS_WAIT
    } state_t;

    state_t state;
    logic [ADDR_WIDTH-1:0] pending_addr;
    logic [BLOCK_BYTES*8-1:0] selected_block;
    logic [TAG_BITS-1:0] selected_tag;
    logic selected_valid;

    wire [INDEX_BITS-1:0] pending_index =
        pending_addr[OFFSET_BITS +: INDEX_BITS];
    wire [TAG_BITS-1:0] pending_tag =
        pending_addr[ADDR_WIDTH-1 -: TAG_BITS];
    wire [OFFSET_BITS-1:0] pending_offset =
        pending_addr[OFFSET_BITS-1:0];

    assign req_ready = (state == IDLE);
    assign mem_req_valid = (state == MISS_REQUEST);
    assign mem_req_addr = {
        pending_addr[ADDR_WIDTH-1:OFFSET_BITS], {OFFSET_BITS{1'b0}}
    };

    cache_line_store #(
        .BLOCK_BITS(BLOCK_BYTES*8), .LINE_COUNT(LINE_COUNT),
        .INDEX_BITS(INDEX_BITS), .TAG_BITS(TAG_BITS)
    ) lines (
        .clk(clk), .rst_n(rst_n),
        .read_index(pending_index), .read_block(selected_block),
        .read_tag(selected_tag), .read_valid(selected_valid),
        .refill_en(state == MISS_WAIT && mem_resp_valid),
        .refill_index(pending_index), .refill_block(mem_resp_block),
        .refill_tag(pending_tag)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pending_addr <= '0;
            resp_valid <= 1'b0;
            resp_data <= '0;
            resp_hit <= 1'b0;
            hit_count <= '0;
            miss_count <= '0;
        end else begin
            // A response is a one-cycle pulse. The requester may issue its
            // next request when req_ready rises in the following cycle.
            resp_valid <= 1'b0;
            case (state)
                IDLE: begin
                    if (req_valid) begin
                        pending_addr <= req_addr;
                        state <= LOOKUP;
                    end
                end

                LOOKUP: begin
                    if (selected_valid && selected_tag == pending_tag) begin
                        resp_data <= selected_block
                            [pending_offset / WORD_BYTES * DATA_WIDTH +: DATA_WIDTH];
                        resp_hit <= 1'b1;
                        resp_valid <= 1'b1;
                        hit_count <= hit_count + 1'b1;
                        state <= IDLE;
                    end else begin
                        miss_count <= miss_count + 1'b1;
                        state <= MISS_REQUEST;
                    end
                end

                MISS_REQUEST: begin
                    if (mem_req_ready)
                        state <= MISS_WAIT;
                end

                MISS_WAIT: begin
                    if (mem_resp_valid) begin
                        resp_data <= mem_resp_block
                            [pending_offset / WORD_BYTES * DATA_WIDTH +: DATA_WIDTH];
                        resp_hit <= 1'b0;
                        resp_valid <= 1'b1;
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule

