`timescale 1ns/1ps
// Testbench-only main memory: deterministic word contents and fixed latency.
// This is deliberately separate from the synthesizable cache controller.
module main_memory_model #(
    parameter int ADDR_WIDTH   = 32,
    parameter int DATA_WIDTH   = 32,
    parameter int BLOCK_BYTES  = 16,
    parameter int MEMORY_BYTES = 4096,
    parameter int LATENCY      = 3
) (
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic                         req_valid,
    output logic                         req_ready,
    input  logic [ADDR_WIDTH-1:0]        req_addr,
    output logic                         resp_valid,
    output logic [BLOCK_BYTES*8-1:0]     resp_block
);
    localparam int WORD_BYTES = DATA_WIDTH / 8;
    localparam int WORD_COUNT = MEMORY_BYTES / WORD_BYTES;
    localparam int WORDS_PER_BLOCK = BLOCK_BYTES / WORD_BYTES;

    logic [DATA_WIDTH-1:0] words [0:WORD_COUNT-1];
    logic [BLOCK_BYTES*8-1:0] pending_block;
    logic busy;
    integer cycles_left;
    integer i;
    integer w;

    initial begin
        for (i = 0; i < WORD_COUNT; i = i + 1)
            words[i] = 32'hA500_0000 + i;
    end

    assign req_ready = !busy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 1'b0;
            cycles_left <= 0;
            pending_block <= '0;
            resp_block <= '0;
            resp_valid <= 1'b0;
        end else begin
            resp_valid <= 1'b0;
            if (req_valid && req_ready) begin
                if (req_addr % BLOCK_BYTES != 0 || req_addr >= MEMORY_BYTES)
                    $fatal(1, "Invalid main-memory block request: %08h", req_addr);
                busy <= 1'b1;
                cycles_left <= LATENCY;
                for (w = 0; w < WORDS_PER_BLOCK; w = w + 1)
                    pending_block[w*DATA_WIDTH +: DATA_WIDTH] <=
                        words[(req_addr / WORD_BYTES) + w];
            end else if (busy) begin
                cycles_left <= cycles_left - 1;
                if (cycles_left == 1) begin
                    resp_block <= pending_block;
                    resp_valid <= 1'b1;
                    busy <= 1'b0;
                end
            end
        end
    end
endmodule

