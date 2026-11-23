`timescale 1ns/1ps
// Direct-mapped data, tag, and valid-bit arrays. Only valid bits need reset.
module cache_line_store #(
    parameter int BLOCK_BITS = 128,
    parameter int LINE_COUNT = 64,
    parameter int INDEX_BITS = 6,
    parameter int TAG_BITS = 22,
    parameter int WORD_BITS = 32,
    parameter int WORD_SELECT_BITS = 2
) (
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic [INDEX_BITS-1:0]   read_index,
    output logic [BLOCK_BITS-1:0]   read_block,
    output logic [TAG_BITS-1:0]     read_tag,
    output logic                    read_valid,
    input  logic                    refill_en,
    input  logic [INDEX_BITS-1:0]   refill_index,
    input  logic [BLOCK_BITS-1:0]   refill_block,
    input  logic [TAG_BITS-1:0]     refill_tag,
    input  logic                    word_write_en,
    input  logic [INDEX_BITS-1:0]   word_write_index,
    input  logic [WORD_SELECT_BITS-1:0] word_write_select,
    input  logic [WORD_BITS-1:0]    word_write_data
);
    logic [BLOCK_BITS-1:0] data_lines [0:LINE_COUNT-1];
    logic [TAG_BITS-1:0] tag_lines [0:LINE_COUNT-1];
    logic valid_lines [0:LINE_COUNT-1];

    assign read_block = data_lines[read_index];
    assign read_tag = tag_lines[read_index];
    assign read_valid = valid_lines[read_index];

    integer line;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (line = 0; line < LINE_COUNT; line = line + 1)
                valid_lines[line] <= 1'b0;
        end else begin
            if (refill_en) begin
                data_lines[refill_index] <= refill_block;
                tag_lines[refill_index] <= refill_tag;
                valid_lines[refill_index] <= 1'b1;
            end else if (word_write_en) begin
                data_lines[word_write_index]
                    [word_write_select*WORD_BITS +: WORD_BITS] <= word_write_data;
            end
        end
    end
endmodule

