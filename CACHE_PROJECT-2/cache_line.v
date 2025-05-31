// Simple cache line module with tag, valid, dirty, and data

module cache_line #(
    parameter ADDRESS_WORD_SIZE = 32,
    parameter TAG_SIZE = 19,
    parameter WORD_SIZE = 8
) (
    input clk,
    input rst_b,
    input [ADDRESS_WORD_SIZE-1:0] addr,
    input try_read,
    input try_write,
    input cache_write,
    input [WORD_SIZE-1:0] write_data,
    output reg [WORD_SIZE-1:0] data_out,
    output hit,
    output reg valid,
    output reg dirty
);

    reg [TAG_SIZE-1:0] tag;
    reg [WORD_SIZE-1:0] data;

    wire [TAG_SIZE-1:0] addr_tag = addr[ADDRESS_WORD_SIZE-1 -: TAG_SIZE];

    assign hit = (valid && (tag == addr_tag));

    always @(posedge clk or negedge rst_b) begin
        if (!rst_b) begin
            tag <= 0;
            data <= 0;
            valid <= 0;
            dirty <= 0;
            data_out <= 0;
        end else begin
            if (try_read && hit)
                data_out <= data;

            if (try_write && hit) begin
                data <= write_data;
                dirty <= 1;
            end

            if (cache_write && !hit) begin
                data <= write_data;
                tag <= addr_tag;
                valid <= 1;
                dirty <= 0;
            end
        end
    end

endmodule
