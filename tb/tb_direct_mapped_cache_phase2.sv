`timescale 1ns/1ps

module tb_direct_mapped_cache_phase2;
    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic rst_n = 1'b0;
    logic req_valid = 1'b0;
    logic req_ready;
    logic [31:0] req_addr = '0;
    logic req_write = 1'b0;
    logic [31:0] req_wdata = '0;
    logic resp_valid;
    logic [31:0] resp_data;
    logic resp_hit;
    logic mem_req_valid;
    logic mem_req_ready;
    logic [31:0] mem_req_addr;
    logic mem_resp_valid;
    logic [127:0] mem_resp_block;
    logic mem_write_valid;
    logic mem_write_ready;
    logic memory_write_ready;
    logic permit_write = 1'b1;
    logic [31:0] mem_write_addr;
    logic [31:0] mem_write_data;
    wire accepted_write = mem_write_valid && mem_write_ready;

    assign mem_write_ready = memory_write_ready && permit_write;
    logic [31:0] hit_count;
    logic [31:0] miss_count;

    integer clock_count = 0;
    integer block_reads = 0;
    integer word_writes = 0;
    integer expected_hits = 0;
    integer expected_misses = 0;
    integer expected_block_reads = 0;
    integer expected_word_writes = 0;
    integer accesses = 0;
    integer total_cycles = 0;
    integer read_hits = 0;
    integer read_misses = 0;
    integer write_hits = 0;
    integer write_misses = 0;

    always @(posedge clk) begin
        clock_count <= clock_count + 1;
        if (!rst_n) begin
            block_reads <= 0;
            word_writes <= 0;
        end else begin
            if (mem_req_valid && mem_req_ready)
                block_reads <= block_reads + 1;
            if (accepted_write)
                word_writes <= word_writes + 1;
            if (mem_req_valid && mem_write_valid)
                $fatal(1, "Cache issued simultaneous memory requests");
        end
    end

    direct_mapped_cache dut (
        .clk(clk), .rst_n(rst_n),
        .req_valid(req_valid), .req_ready(req_ready), .req_addr(req_addr),
        .req_write(req_write), .req_wdata(req_wdata),
        .resp_valid(resp_valid), .resp_data(resp_data), .resp_hit(resp_hit),
        .mem_req_valid(mem_req_valid), .mem_req_ready(mem_req_ready),
        .mem_req_addr(mem_req_addr), .mem_resp_valid(mem_resp_valid),
        .mem_resp_block(mem_resp_block),
        .mem_write_valid(mem_write_valid), .mem_write_ready(mem_write_ready),
        .mem_write_addr(mem_write_addr), .mem_write_data(mem_write_data),
        .hit_count(hit_count), .miss_count(miss_count)
    );

    main_memory_model #(.LATENCY(3)) memory (
        .clk(clk), .rst_n(rst_n),
        .req_valid(mem_req_valid), .req_ready(mem_req_ready),
        .req_addr(mem_req_addr), .resp_valid(mem_resp_valid),
        .resp_block(mem_resp_block),
        .write_valid(mem_write_valid && permit_write), .write_ready(memory_write_ready),
        .write_addr(mem_write_addr), .write_data(mem_write_data)
    );

    task automatic reset_cache;
        begin
            @(negedge clk);
            rst_n = 1'b0;
            req_valid = 1'b0;
            repeat (3) @(posedge clk);
            @(negedge clk);
            rst_n = 1'b1;
            expected_hits = 0;
            expected_misses = 0;
            expected_block_reads = 0;
            expected_word_writes = 0;
            accesses = 0;
            total_cycles = 0;
            read_hits = 0;
            read_misses = 0;
            write_hits = 0;
            write_misses = 0;
        end
    endtask

    task automatic request_and_check(
        input integer is_write,
        input logic [31:0] address,
        input logic [31:0] write_data,
        input integer expected_hit,
        input logic [31:0] expected_data
    );
        integer start_cycle;
        integer latency;
        begin
            @(negedge clk);
            while (!req_ready) @(negedge clk);
            req_addr = address;
            req_write = is_write != 0;
            req_wdata = write_data;
            req_valid = 1'b1;
            start_cycle = clock_count;
            @(posedge clk);
            @(negedge clk);
            req_valid = 1'b0;
            wait (resp_valid === 1'b1);

            if (resp_hit !== (expected_hit != 0) || resp_data !== expected_data)
                $fatal(1, "FAIL op=%0d addr=%08h data=%08h expected=%08h hit=%b expected_hit=%0d",
                       is_write, address, resp_data, expected_data, resp_hit, expected_hit);
            accesses = accesses + 1;
            if (expected_hit != 0)
                expected_hits = expected_hits + 1;
            else begin
                expected_misses = expected_misses + 1;
                expected_block_reads = expected_block_reads + 1;
            end
            if (is_write != 0)
                expected_word_writes = expected_word_writes + 1;
            if (hit_count !== expected_hits || miss_count !== expected_misses ||
                block_reads !== expected_block_reads || word_writes !== expected_word_writes)
                $fatal(1, "FAIL counters op=%0d addr=%08h hits=%0d/%0d misses=%0d/%0d block_reads=%0d/%0d word_writes=%0d/%0d",
                       is_write, address, hit_count, expected_hits, miss_count, expected_misses,
                       block_reads, expected_block_reads, word_writes, expected_word_writes);

            latency = clock_count - start_cycle;
            total_cycles = total_cycles + latency;
            if (is_write != 0) begin
                if (expected_hit != 0) write_hits = write_hits + 1;
                else write_misses = write_misses + 1;
            end else begin
                if (expected_hit != 0) read_hits = read_hits + 1;
                else read_misses = read_misses + 1;
            end
            $display("PASS2 op=%s addr=%08h %s data=%08h cycles=%0d",
                     is_write ? "WRITE" : "READ ", address,
                     expected_hit ? "HIT " : "MISS", resp_data, latency);
        end
    endtask

    task automatic show_summary(input string label);
        real hit_rate;
        real miss_rate;
        real average_cycles;
        begin
            hit_rate = accesses ? 100.0 * expected_hits / accesses : 0.0;
            miss_rate = accesses ? 100.0 * expected_misses / accesses : 0.0;
            average_cycles = accesses ? 1.0 * total_cycles / accesses : 0.0;
            $display("PHASE2 SUMMARY %s accesses=%0d hits=%0d misses=%0d hit_rate=%0.2f%% miss_rate=%0.2f%% read_hits=%0d read_misses=%0d write_hits=%0d write_misses=%0d block_reads=%0d word_writes=%0d memory_bytes=%0d average_cycles=%0.2f",
                     label, accesses, expected_hits, expected_misses, hit_rate, miss_rate,
                     read_hits, read_misses, write_hits, write_misses,
                     block_reads, word_writes, block_reads*16 + word_writes*4,
                     average_cycles);
        end
    endtask

    string vector_path;
    string vcd_path;
    integer fd;
    integer fields;
    integer is_write;
    integer expected_hit;
    logic [31:0] address;
    logic [31:0] write_data;
    logic [31:0] expected_data;

    initial begin
        if (!$value$plusargs("VCD=%s", vcd_path))
            vcd_path = "results/phase2.vcd";
        $dumpfile(vcd_path);
        $dumpvars(0, tb_direct_mapped_cache_phase2);
        if (!$value$plusargs("VECTORS=%s", vector_path))
            vector_path = "results/phase2_vectors.txt";
        fd = $fopen(vector_path, "r");
        if (!fd)
            $fatal(1, "Cannot open vector file: %s", vector_path);

        reset_cache();
        while (!$feof(fd)) begin
            fields = $fscanf(fd, "%d %h %h %d %h\n",
                             is_write, address, write_data, expected_hit, expected_data);
            if (fields == 5)
                request_and_check(is_write, address, write_data, expected_hit, expected_data);
            else if (fields != -1)
                $fatal(1, "Malformed vector file: %s", vector_path);
        end
        $fclose(fd);
        show_summary("trace");

        if ($test$plusargs("SMOKE")) begin
            // Cache reset must retain writes already accepted by main memory.
            reset_cache();
            request_and_check(0, 32'h0000_0400, 0, 0, 32'hDEAD_BEEF);
            request_and_check(0, 32'h0000_0008, 0, 0, 32'h1234_5678);
            request_and_check(0, 32'h0000_000C, 0, 1, 32'hA500_0003);
            // Stall the word-write channel; the CPU response must wait.
            permit_write = 1'b0;
            fork
                request_and_check(1, 32'h0000_0008, 32'hCAFE_1234, 1, 0);
                begin
                    wait (mem_write_valid === 1'b1);
                    repeat (3) begin
                        @(posedge clk);
                        if (resp_valid || mem_write_addr !== 32'h0000_0008 ||
                            mem_write_data !== 32'hCAFE_1234)
                            $fatal(1, "Write changed or responded during backpressure");
                    end
                    @(negedge clk);
                    permit_write = 1'b1;
                end
            join
            request_and_check(0, 32'h0000_0008, 0, 1, 32'hCAFE_1234);
            show_summary("after_reset");
            reset_cache();
            request_and_check(0, 32'h0000_0008, 0, 0, 32'hCAFE_1234);
            show_summary("write_persisted");
        end
        $display("PHASE2 ALL TESTS PASSED");
        $finish;
    end

    initial begin
        #5000000;
        $fatal(1, "Phase II simulation timeout");
    end
endmodule
