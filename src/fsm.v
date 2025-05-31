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


// This is a simple FSM for a cache controller 