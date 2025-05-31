// Testbench for cache_controller (structural with FSM)

module tb_cache_controller;
    reg clk;
    reg reset;
    reg read_req;
    reg write_req;
    reg [31:0] addr;
    reg [31:0] cpu_write_data;
    wire [31:0] cpu_read_data;
    wire ready;
    wire mem_read;
    wire hit;
    wire mem_write;
    wire cache_write;
    wire update_lru;
    wire [2:0] state_out;
    wire [31:0] mem_addr;
    wire [31:0] mem_write_data;
    reg [31:0] mem_read_data;

    // Instantiate the DUT
    cache_controller uut (
        .clk(clk),
        .reset(reset),
        .read_req(read_req),
        .write_req(write_req),
        .addr(addr),
        .cpu_write_data(cpu_write_data),
        .cpu_read_data(cpu_read_data),
        .ready(ready),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .hit_cc(hit),
        .cache_write(cache_write),
        .update_lru(update_lru),
        .state_out(state_out),
        .mem_addr(mem_addr),
        .mem_write_data(mem_write_data),
        .mem_read_data(mem_read_data)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk; // 10 time units period

    initial begin
        $monitor("[%0t] state=%b ready=%b read_req=%b write_req=%b addr=%h read_data=%h write_data=%h mem_read=%b mem_write=%b cache_write=%b update_lru=%b", 
                 $time, state_out, ready, read_req, write_req, addr, cpu_read_data, cpu_write_data, mem_read, mem_write, cache_write, update_lru);
    end

    integer total_accesses = 0;
    integer total_hits = 0;
    integer total_misses = 0;

    always @(posedge clk) begin
        if (read_req || write_req) begin
            total_accesses = total_accesses + 1;
        if (hit) total_hits = total_hits + 1;
        else total_misses = total_misses + 1;
        end
    end

    initial begin
        #300;
        $display("Total accesses: %0d", total_accesses);
        $display("Total hits: %0d", total_hits);
        $display("Total misses: %0d", total_misses);
        $display("Hit rate: %0f%%", total_accesses ? 100.0 * total_hits / total_accesses : 0);
    end

    // Stimulus
    initial begin
        // Initial values
        reset = 1;
        read_req = 0;
        write_req = 0;
        addr = 32'h00000000;
        cpu_write_data = 32'h00000000;
        mem_read_data = 32'hDEADBEEF;

        #15;
        reset = 0;

        // Write miss → allocate

        #10
        addr = 32'h0000_0040; // maps to set 1
        cpu_write_data = 32'h12345678;
        write_req = 1;

        #10
        write_req = 0;

        // Read hit (should be cached)
        #20;

        #20
        addr = 32'h0000_0040;
        read_req = 1;

        #20
        read_req = 0;

        // Read miss (new address)
        #30;
        #20;
        addr = 32'h0000_1000; // different set
        read_req = 1;

        #50
        read_req = 0;

        // Let it run a bit
        #1000;

        $finish;
    end
endmodule
