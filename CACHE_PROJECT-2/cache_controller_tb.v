`include "cache_controller.v"
// Testbench for cache_controller with FSM and four_way_set
// Testbench for cache_controller with FSM and four_way_set

module cache_controller_tb;

    reg clk;
    reg rst_b;
    reg opcode; // 0 = read, 1 = write
    wire [7:0] data_out;
    wire ready;

    // Instantiate cache_controller
    cache_controller uut (
        .clk(clk),
        .rst_b(rst_b),
        .opcode(opcode),
        .data_out(data_out),
        .ready(ready)
    );

    // Clock generator
    always #5 clk = ~clk;

    initial begin
        $display("Start simulation");
        $dumpfile("waveform.vcd");
        $dumpvars(0, cache_controller_tb);

        clk = 0;
        rst_b = 0;
        opcode = 0;

        #10;
        rst_b = 1;

        // === READ MISS ===
        opcode = 0;
        #20;
        $display("[READ MISS] data_out = %h, ready = %b", data_out, ready);

        // === WRITE MISS ===
        opcode = 1;
        #20;
        $display("[WRITE MISS] data_out = %h, ready = %b", data_out, ready);

        // === READ HIT ===
        opcode = 0;
        #20;
        $display("[READ HIT] data_out = %h, ready = %b", data_out, ready);

        // === WRITE HIT ===
        opcode = 1;
        #20;
        $display("[WRITE HIT] data_out = %h, ready = %b", data_out, ready);

        // === READ after eviction ===
        opcode = 0;
        #20;
        $display("[READ after eviction] data_out = %h, ready = %b", data_out, ready);

        $display("End simulation");
        $finish;
    end

endmodule
