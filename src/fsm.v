module fsm(
    input clk,
    input rst_b,
    input read_req,
    input write_req,
    input hit,
    input dirty,
    input need_evict,
    output reg ready,
    output reg mem_read,
    output reg mem_write,
    output reg cache_write,
    output reg update_lru,
    output [2:0] state_out

);


localparam  IDLE = 3'b000;
localparam  CHECK = 3'b001;
localparam  READ_HIT = 3'b010;
localparam  READ_MISS = 3'b011;
localparam  WRITE_HIT = 3'b100;
localparam  WRITE_MISS = 3'b101;
localparam  EVICT = 3'b110;
localparam  ALLOC_DATA = 3'b111;

reg[2:0] state, next_state;

always @(posedge clk or negedge rst_b) begin
    if (!rst_b) state <= IDLE;

    else state <= next_state;
end

always @(*) begin
    next_state = state; // Default next state is the current state
    case(state)
        IDLE: 
            if (read_req || write_req) next_state = CHECK;
        CHECK: 
            if (hit) begin
                if (read_req) next_state = READ_HIT;
                else if (write_req) next_state = WRITE_HIT;
            end else begin
                if (read_req) next_state = READ_MISS;
                else if (write_req) next_state = WRITE_MISS;
            end
        READ_HIT:
            next_state = IDLE; // After a hit, go back to idle
        WRITE_HIT:
            next_state = IDLE; 
        READ_MISS:
            if (need_evict && dirty) next_state = EVICT;
            else next_state = ALLOC_DATA; // If no eviction needed, allocate data
        WRITE_MISS:
            if (need_evict && dirty) next_state = EVICT;
            else next_state = ALLOC_DATA; // If no eviction needed, allocate data
        EVICT:
            next_state = ALLOC_DATA; // After eviction, allocate data
        ALLOC_DATA:
            next_state = IDLE; // After allocating data, go back to idle   
    endcase
end

always @(*) begin
    // Default outputs
    ready = 1'b0;
    mem_read = 1'b0;
    mem_write = 1'b0;
    cache_write = 1'b0;
    update_lru = 1'b0;
    
    case(state)
        IDLE: 
            ready = 1'b1; // Ready to accept new requests
        CHECK:
            if (hit && read_req)
                update_lru = 1;
            else if (hit && write_req) begin
                update_lru = 1;
                cache_write = 1;
            end 
        
        READ_HIT:
            ready = 1'b1; // Ready after hit
        WRITE_HIT: begin
            cache_write = 1'b1; // Write to cache on hit
            ready = 1'b1; // Ready after hit
        end
        READ_MISS:
            if (~need_evict || ~dirty)
                mem_read = 1;
        WRITE_MISS:
             if (~need_evict || ~dirty) begin
                mem_read = 1;
                cache_write = 1;
            end
        EVICT:
            mem_write = 1'b1; // Write dirty block back to memory during eviction
        
        ALLOC_DATA: begin
            mem_read = 1;
            if (write_req)
                cache_write = 1;
            update_lru = 1; // Update LRU on allocation
            ready = 1'b1; // Ready after allocation or eviction is done 
        end 
    endcase
end
    assign state_out = state;
endmodule


// Top-level structural module for a 4-way set-associative cache controller
// with FSM module, tag compare, data array, and LRU integration (simplified example)

// 4-way LRU Tracker for a single set
module lru_tracker (
    input clk,
    input rst_b,
    input update,
    input [1:0] accessed_way,
    output [1:0] lru_way
);
    reg [1:0] lru_stack [0:3];
    integer i;

    always @(posedge clk or negedge rst_b) begin
        if (!rst_b) begin
            lru_stack[0] <= 2'd0;
            lru_stack[1] <= 2'd1;
            lru_stack[2] <= 2'd2;
            lru_stack[3] <= 2'd3;
        end else if (update) begin
            for (i = 3; i > 0; i = i - 1)
                lru_stack[i] <= (lru_stack[i-1] == accessed_way) ? lru_stack[i-1] : lru_stack[i];
            lru_stack[0] <= accessed_way;
        end
    end

    assign lru_way = lru_stack[3];
endmodule



module cache_controller (
    input clk,
    input reset,
    input read_req,
    input write_req,
    input [31:0] addr,
    input [31:0] cpu_write_data,
    output [31:0] cpu_read_data,
    output wire ready,
    output wire mem_read,
    output wire mem_write,
    output wire hit_cc,
    output wire cache_write,
    output wire update_lru,
    output wire [2:0] state_out,
    output [31:0] mem_addr,
    output [31:0] mem_write_data,
    input [31:0] mem_read_data
);

    // Address decode
    wire [6:0] index = addr[12:6];
    wire [5:0] offset = addr[5:0];
    wire [18:0] tag = addr[31:13];

    // Simplified cache arrays (structural version would use separate RAM modules)
    reg [18:0] tag_array [0:127][0:3];
    reg valid_array [0:127][0:3];
    reg dirty_array [0:127][0:3];
    reg [31:0] data_array [0:127][0:3][0:15];
    reg [1:0] lru [0:127];

    // Hit and match logic

    wire hit_comb = (valid_array[index][0] && tag_array[index][0] == tag) ||
                    (valid_array[index][1] && tag_array[index][1] == tag) ||
                    (valid_array[index][2] && tag_array[index][2] == tag) ||
                    (valid_array[index][3] && tag_array[index][3] == tag);

    wire [1:0] hit_way = (valid_array[index][0] && tag_array[index][0] == tag) ? 2'd0 :
                         (valid_array[index][1] && tag_array[index][1] == tag) ? 2'd1 :
                         (valid_array[index][2] && tag_array[index][2] == tag) ? 2'd2 :
                         (valid_array[index][3] && tag_array[index][3] == tag) ? 2'd3 : 2'd0;


    // Registered outputs for hit and hit_way
    wire hit;
    wire [1:0] hit_way_reg;

    dff_async_reset dff_hit     (.clk(clk), .rst_b(~reset), .d(hit_comb),        .q(hit));
    dff_async_reset dff_way0    (.clk(clk), .rst_b(~reset), .d(hit_way[0]),      .q(hit_way_reg[0]));
    dff_async_reset dff_way1    (.clk(clk), .rst_b(~reset), .d(hit_way[1]),      .q(hit_way_reg[1]));

    wire [1:0] evict_way = lru[index];
    wire dirty = valid_array[index][evict_way] && dirty_array[index][evict_way];
    wire need_evict = valid_array[index][evict_way];

    wire [1:0] lru_way0, lru_way1, lru_way2, lru_way3;
    lru_tracker lru0 (.clk(clk), .rst_b(~reset), .update(update_lru && index[1:0] == 2'd0), .accessed_way(hit ? hit_way_reg : evict_way), .lru_way(lru_way0));
    lru_tracker lru1 (.clk(clk), .rst_b(~reset), .update(update_lru && index[1:0] == 2'd1), .accessed_way(hit ? hit_way_reg : evict_way), .lru_way(lru_way1));
    lru_tracker lru2 (.clk(clk), .rst_b(~reset), .update(update_lru && index[1:0] == 2'd2), .accessed_way(hit ? hit_way_reg : evict_way), .lru_way(lru_way2));
    lru_tracker lru3 (.clk(clk), .rst_b(~reset), .update(update_lru && index[1:0] == 2'd3), .accessed_way(hit ? hit_way_reg : evict_way), .lru_way(lru_way3));

reg [1:0] evict_way_mux;
always @(*) begin
    case (index[1:0])
        2'd0: evict_way_mux = lru_way0;
        2'd1: evict_way_mux = lru_way1;
        2'd2: evict_way_mux = lru_way2;
        2'd3: evict_way_mux = lru_way3;
        default: evict_way_mux = 2'd0;
    endcase
end

    always @(posedge clk) begin
    if (reset) begin
        // optional: clear arrays if you want full reset logic
    end else begin
        // WRITE HIT
        if (cache_write && hit) begin
            data_array[index][hit_way_reg][offset[5:2]] <= cpu_write_data;
            dirty_array[index][hit_way_reg] <= 1;
        end

        // WRITE MISS or READ MISS → WRITE-ALLOCATE (via evict_way)
        if (cache_write && !hit) begin
            tag_array[index][evict_way][18:0] <= tag;
            valid_array[index][evict_way] <= 1;
            dirty_array[index][evict_way] <= write_req; // set dirty only if it's a write
            data_array[index][evict_way][offset[5:2]] <= cpu_write_data;
        end

        // MEMORY REFILL (used during ALLOC_DATA state, typically after mem_read=1)
        if (mem_read && !hit) begin
            // On real memory systems, you'd refill the full block; simplified here
            data_array[index][evict_way][offset[5:2]] <= mem_read_data;
            tag_array[index][evict_way] <= tag;
            valid_array[index][evict_way] <= 1;
            if (!write_req)
                dirty_array[index][evict_way] <= 0;
        end

        // LRU update is done separately via `update_lru` and lru_tracker
    end
end


assign evict_way = evict_way_mux;

    // Instantiate FSM
    fsm controller_fsm (
        .clk(clk),
        .rst_b(~reset),
        .read_req(read_req),
        .write_req(write_req),
        .hit(hit),
        .dirty(dirty),
        .need_evict(need_evict),
        .ready(ready),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .cache_write(cache_write),
        .update_lru(update_lru),
        .state_out(state_out)
    );

    // Read output purely combinational
    assign cpu_read_data = (hit && read_req) ? data_array[index][hit_way_reg][offset[5:2]] : 32'b0;
    assign hit_cc = hit;
    // Memory write-back address and data
    assign mem_addr = {tag_array[index][evict_way], index, 6'b0};
    assign mem_write_data = data_array[index][evict_way][offset[5:2]];

endmodule

// D flip-flop with asynchronous active-low reset
module dff_async_reset (
    input clk,
    input rst_b,
    input d,
    output reg q
);
    always @(posedge clk or negedge rst_b) begin
        if (!rst_b)
            q <= 1'b0;
        else
            q <= d;
    end
endmodule


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

        @(posedge clk);
        addr = 32'h0000_0040; // maps to set 1
        cpu_write_data = 32'h12345678;
        write_req = 1;

        @(posedge clk);
        write_req = 0;

        // Read hit (should be cached)
        #20;

        @(posedge clk);
        addr = 32'h0000_0040;
        read_req = 1;

        @(posedge clk);
        read_req = 0;

        // Read miss (new address)
        #30;
        @(posedge clk);
        addr = 32'h0000_1000; // different set
        read_req = 1;

        @(posedge clk);
        read_req = 0;

        // Let it run a bit
        #1000;

        $finish;
    end
endmodule
