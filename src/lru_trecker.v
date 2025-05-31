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
