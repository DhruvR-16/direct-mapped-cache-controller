`timescale 1ns/1ps

module tb_direct_mapped_cache;
    localparam int MEMORY_LATENCY = 3;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic rst_n = 1'b0;
    logic req_valid = 1'b0;
    logic req_ready;
    logic [31:0] req_addr = '0;
    logic resp_valid;
    logic [31:0] resp_data;
    logic resp_hit;
    logic mem_req_valid;
    logic mem_req_ready;
    logic [31:0] mem_req_addr;
    logic mem_resp_valid;
    logic [127:0] mem_resp_block;
    logic [31:0] hit_count;
    logic [31:0] miss_count;

    integer clock_count = 0;
    integer trace_cycles = 0;
    integer trace_accesses = 0;
    integer memory_requests = 0;
    integer i;
    always @(posedge clk) clock_count <= clock_count + 1;
    always @(posedge clk) begin
        if (!rst_n)
            memory_requests <= 0;
        else if (mem_req_valid && mem_req_ready)
            memory_requests <= memory_requests + 1;
    end

    direct_mapped_cache dut (
        .clk(clk), .rst_n(rst_n),
        .req_valid(req_valid), .req_ready(req_ready), .req_addr(req_addr),
        .resp_valid(resp_valid), .resp_data(resp_data), .resp_hit(resp_hit),
        .mem_req_valid(mem_req_valid), .mem_req_ready(mem_req_ready),
        .mem_req_addr(mem_req_addr), .mem_resp_valid(mem_resp_valid),
        .mem_resp_block(mem_resp_block),
        .hit_count(hit_count), .miss_count(miss_count)
    );

    main_memory_model #(.LATENCY(MEMORY_LATENCY)) memory (
        .clk(clk), .rst_n(rst_n),
        .req_valid(mem_req_valid), .req_ready(mem_req_ready),
        .req_addr(mem_req_addr), .resp_valid(mem_resp_valid),
        .resp_block(mem_resp_block)
    );

    task automatic reset_trace;
        begin
            @(negedge clk);
            rst_n = 1'b0;
            req_valid = 1'b0;
            repeat (3) @(posedge clk);
            @(negedge clk);
            rst_n = 1'b1;
            trace_cycles = 0;
            trace_accesses = 0;
        end
    endtask

    task automatic read_and_check(input logic [31:0] address,
                                  input logic expected_hit);
        logic [31:0] expected_data;
        integer start_cycle;
        begin
            expected_data = 32'hA500_0000 + (address / 4);
            @(negedge clk);
            while (!req_ready) @(negedge clk);
            req_addr = address;
            req_valid = 1'b1;
            start_cycle = clock_count;
            @(posedge clk);
            @(negedge clk);
            req_valid = 1'b0;
            wait (resp_valid === 1'b1);
            if (resp_data !== expected_data || resp_hit !== expected_hit)
                $fatal(1, "FAIL addr=%08h data=%08h expected=%08h hit=%b expected_hit=%b",
                       address, resp_data, expected_data, resp_hit, expected_hit);
            trace_cycles = trace_cycles + (clock_count - start_cycle);
            trace_accesses = trace_accesses + 1;
            $display("PASS addr=%08h %s data=%08h", address,
                     resp_hit ? "HIT " : "MISS", resp_data);
        end
    endtask

    task automatic check_summary(input string label,
                                 input integer expected_hits,
                                 input integer expected_misses);
        real hit_rate;
        real average_cycles;
        begin
            if (hit_count !== expected_hits || miss_count !== expected_misses)
                $fatal(1, "FAIL %s: hits=%0d misses=%0d; expected %0d/%0d",
                       label, hit_count, miss_count,
                       expected_hits, expected_misses);
            if (memory_requests !== expected_misses)
                $fatal(1, "FAIL %s: memory reads=%0d expected=%0d",
                       label, memory_requests, expected_misses);
            hit_rate = 100.0 * hit_count / trace_accesses;
            average_cycles = 1.0 * trace_cycles / trace_accesses;
            $display("SUMMARY %-12s accesses=%0d hits=%0d misses=%0d hit_rate=%0.2f%% average_cycles=%0.2f",
                     label, trace_accesses, hit_count, miss_count,
                     hit_rate, average_cycles);
        end
    endtask

    initial begin
        $dumpfile("results/cache.vcd");
        $dumpvars(0, tb_direct_mapped_cache);

        // Directed correctness cases, including conflict replacement.
        reset_trace();
        read_and_check(32'h0000_0000, 1'b0);
        read_and_check(32'h0000_0004, 1'b1);
        read_and_check(32'h0000_0008, 1'b1);
        read_and_check(32'h0000_000C, 1'b1);
        read_and_check(32'h0000_0400, 1'b0); // Same index, different tag.
        read_and_check(32'h0000_0000, 1'b0); // Previous line was evicted.
        read_and_check(32'h0000_0000, 1'b1);
        check_summary("directed", 4, 3);

        // Four 16-byte blocks, four words from each block.
        reset_trace();
        for (i = 0; i < 16; i = i + 1)
            read_and_check(i * 4, (i % 4) != 0);
        check_summary("sequential", 12, 4);

        // First access is cold; the remaining 15 use temporal locality.
        reset_trace();
        for (i = 0; i < 16; i = i + 1)
            read_and_check(32'h0000_0080, i != 0);
        check_summary("repeated", 15, 1);

        // Both addresses map to line zero; every access replaces the other.
        reset_trace();
        for (i = 0; i < 16; i = i + 1)
            read_and_check((i % 2) ? 32'h0000_0400 : 32'h0000_0000, 1'b0);
        check_summary("conflict", 0, 16);

        $display("ALL TESTS PASSED");
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Simulation timeout");
    end
endmodule

