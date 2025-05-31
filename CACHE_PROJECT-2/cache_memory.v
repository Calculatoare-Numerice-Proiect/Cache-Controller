`include "four_way_set.v"
module cache_memory #(
    parameter ADDRESS_WORD_SIZE = 32
)(
    input clk,
    input rst_b,
    input [ADDRESS_WORD_SIZE-1:0] addr,
    input try_read,
    input try_write,
    input cache_write,
    output [7:0] data_out,
    output hit,
    output dirty
);

    wire valid;
    wire [1:0] index;

    four_way_set set (
        .clk(clk),
        .rst_b(rst_b),
        .address_word(addr),
        .try_read(try_read),
        .try_write(try_write),
        .cache_write(cache_write),
        .write_data(8'hAA),         // hardcoded for now
        .data(data_out),
        .hit_miss(hit),
        .hit_index(index),
        .dirty_out(dirty),
        .valid_out(valid)
    );

endmodule
