module lru_table (
    input [6:0] index,
    input clk,
    input reset,
    input update,
    input [1:0] accessed_way,
    output [1:0] evict_way
);

    reg [1:0] lru_array [0:127];

    // Combinational read of evict way for a given set
    assign evict_way = lru_array[index];

    // Sequential update of LRU based on most recently used way
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            integer i;
            for (i = 0; i < 128; i = i + 1)
                lru_array[i] <= 2'b00;
        end else if (update) begin
            lru_array[index] <= accessed_way;
        end
    end

endmodule
