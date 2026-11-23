`timescale 1ns/1ps
// Direct-mapped cache with write-through, write-allocate writes.
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
    input  logic                          req_write,
    input  logic [DATA_WIDTH-1:0]         req_wdata,
    output logic                          resp_valid,
    output logic [DATA_WIDTH-1:0]         resp_data,
    output logic                          resp_hit,

    output logic                          mem_req_valid,
    input  logic                          mem_req_ready,
    output logic [ADDR_WIDTH-1:0]         mem_req_addr,
    input  logic                          mem_resp_valid,
    input  logic [BLOCK_BYTES*8-1:0]      mem_resp_block,

    output logic                          mem_write_valid,
    input  logic                          mem_write_ready,
    output logic [ADDR_WIDTH-1:0]         mem_write_addr,
    output logic [DATA_WIDTH-1:0]         mem_write_data,

    output logic [31:0]                   hit_count,
    output logic [31:0]                   miss_count
);
    localparam int LINE_COUNT  = CACHE_BYTES / BLOCK_BYTES;
    localparam int INDEX_BITS  = $clog2(LINE_COUNT);
    localparam int OFFSET_BITS = $clog2(BLOCK_BYTES);
    localparam int TAG_BITS    = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS;
    localparam int WORD_BYTES  = DATA_WIDTH / 8;

    typedef enum logic [2:0] {
        IDLE, LOOKUP, MISS_REQUEST, MISS_WAIT, WRITE_REQUEST
    } state_t;

    state_t state;
    logic [ADDR_WIDTH-1:0] pending_addr;
    logic pending_write;
    logic [DATA_WIDTH-1:0] pending_wdata;
    logic pending_hit;
    logic [BLOCK_BYTES*8-1:0] selected_block;
    logic [BLOCK_BYTES*8-1:0] refill_block;
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
    assign mem_write_valid = (state == WRITE_REQUEST);
    assign mem_write_addr = pending_addr;
    assign mem_write_data = pending_wdata;

    always_comb begin
        refill_block = mem_resp_block;
        if (pending_write)
            refill_block[(pending_offset / WORD_BYTES)*DATA_WIDTH +: DATA_WIDTH]
                = pending_wdata;
    end

    cache_line_store #(
        .BLOCK_BITS(BLOCK_BYTES*8), .LINE_COUNT(LINE_COUNT),
        .INDEX_BITS(INDEX_BITS), .TAG_BITS(TAG_BITS),
        .WORD_BITS(DATA_WIDTH), .WORD_SELECT_BITS($clog2(BLOCK_BYTES/WORD_BYTES))
    ) lines (
        .clk(clk), .rst_n(rst_n),
        .read_index(pending_index), .read_block(selected_block),
        .read_tag(selected_tag), .read_valid(selected_valid),
        .refill_en(state == MISS_WAIT && mem_resp_valid),
        .refill_index(pending_index), .refill_block(refill_block),
        .refill_tag(pending_tag),
        .word_write_en(state == WRITE_REQUEST && mem_write_ready && pending_hit),
        .word_write_index(pending_index),
        .word_write_select(pending_offset[OFFSET_BITS-1:$clog2(WORD_BYTES)]),
        .word_write_data(pending_wdata)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pending_addr <= '0;
            pending_write <= 1'b0;
            pending_wdata <= '0;
            pending_hit <= 1'b0;
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
                        pending_write <= req_write;
                        pending_wdata <= req_wdata;
                        state <= LOOKUP;
                    end
                end

                LOOKUP: begin
                    if (selected_valid && selected_tag == pending_tag) begin
                        hit_count <= hit_count + 1'b1;
                        if (pending_write) begin
                            pending_hit <= 1'b1;
                            state <= WRITE_REQUEST;
                        end else begin
                            resp_data <= selected_block
                                [(pending_offset / WORD_BYTES)*DATA_WIDTH +: DATA_WIDTH];
                            resp_hit <= 1'b1;
                            resp_valid <= 1'b1;
                            state <= IDLE;
                        end
                    end else begin
                        miss_count <= miss_count + 1'b1;
                        pending_hit <= 1'b0;
                        state <= MISS_REQUEST;
                    end
                end

                MISS_REQUEST: begin
                    if (mem_req_ready)
                        state <= MISS_WAIT;
                end

                MISS_WAIT: begin
                    if (mem_resp_valid) begin
                        if (pending_write) begin
                            state <= WRITE_REQUEST;
                        end else begin
                            resp_data <= mem_resp_block
                                [(pending_offset / WORD_BYTES)*DATA_WIDTH +: DATA_WIDTH];
                            resp_hit <= 1'b0;
                            resp_valid <= 1'b1;
                            state <= IDLE;
                        end
                    end
                end

                WRITE_REQUEST: begin
                    if (mem_write_ready) begin
                        resp_data <= '0;
                        resp_hit <= pending_hit;
                        resp_valid <= 1'b1;
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule

