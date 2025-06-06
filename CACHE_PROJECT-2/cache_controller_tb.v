`timescale 1ns / 1ps
module cache_controller_tb;

    // Inputs
    reg clk;
    reg rst_b;
    reg opcode;
    reg [7:0] data_in;    // Data input for write operations
    reg [31:0] address;   // Address input for cache operations

    // Outputs
    wire [7:0] data_out;
    wire hit;
    wire ready;

    // Counters for hit/miss statistics
    integer total_accesses = 0;
    integer hit_count = 0;
    real    hit_rate;

    // Instantiate DUT
    cache_controller uut (
        .clk(clk),
        .rst_b(rst_b),
        .opcode(opcode),
        .data_in(data_in),
        .address(address),
        .data_out(data_out),
        .hit(hit),
        .ready(ready)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Task to send operation to cache controller
    task send_op(input reg rw, input [7:0] val, input [31:0] addr);
        begin
            @(posedge clk);
            opcode  <= rw;
            data_in <= val;
            address <= addr;
            $display("Opcode = %0s | Addr = 0x%08h | data_in = 0x%0h @ %0t",
                     rw ? "WRITE" : "READ", addr, val, $time);
            #20;
        end
    endtask

    // Task to wait for ready signal and update counters
    task wait_ready;
        begin
            while (!ready)
                @(posedge clk);

            // Once ready is asserted, record result
            total_accesses = total_accesses + 1;
            if (hit)
                hit_count = hit_count + 1;

            $display("READY: data_out = 0x%0h | RESULT = %s @ %0t",
                     data_out, hit ? "HIT " : "MISS", $time);
        end
    endtask

    initial begin
        // Initialize signals
        clk = 0;
        rst_b = 0;
        opcode = 0;  // default to read

        // Release reset
        #12 rst_b = 1;

        // Sequence of operations
        send_op(0, 8'h00, 32'h00000010); wait_ready(); // MISS
        send_op(0, 8'h00, 32'h00000010); wait_ready(); // HIT

        send_op(1, 8'hA5, 32'h00000080); wait_ready(); // MISS

        send_op(1, 8'hB6, 32'h00000100); wait_ready(); // HIT
        send_op(0, 8'h00, 32'h00000100); wait_ready(); // HIT

        send_op(0, 8'h00, 32'h00000200); wait_ready(); // MISS
        send_op(1, 8'hC7, 32'h00000200); wait_ready(); // HIT
        send_op(0, 8'h00, 32'h00000200); wait_ready(); // HIT

        send_op(0, 8'h00, 32'h00000400); wait_ready(); // MISS
        send_op(1, 8'hD8, 32'h00000400); wait_ready(); // HIT
        send_op(0, 8'h00, 32'h00000400); wait_ready(); // HIT

        // Compute and display hit rate
        hit_rate = (hit_count * 100.0) / total_accesses;
        $display("");
        $display("===== Simulation Statistics =====");
        $display(" Total Accesses = %0d", total_accesses);
        $display("     Hit Count  = %0d", hit_count);
        $display("     Miss Count = %0d", total_accesses - hit_count);
        $display("     Hit Rate   = %0.2f%%", hit_rate);
        $display("=================================");

        $display("Simulation done.");
        $finish;
    end

endmodule
