// 4352 unique writable bytes: work 2048, tiles 1024, colour 1024,
// attributes/sprite/scratch 256. Aliases share cells, not duplicate arrays.
// Power-up zero matches MAME allocation; soft reset never clears RAM.
module intrepid_main_ram(
    input wire clk, write_enable,
    input wire [12:0] address,
    input wire [7:0] write_data,
    output reg [7:0] read_data,
    input wire [12:0] video_address,
    output reg [7:0] video_data
);
    (* ramstyle="M10K" *) reg [7:0] memory [0:4351];
    initial $readmemh("rtl/intrepid/ram_zero.hex",memory);
    // CPU port: write-through on writes, synchronous read otherwise. The CPU
    // bus never consumes RAM data during a write. Requesting old CPU data here
    // made Quartus 17 duplicate this array into two simple-dual-port memories.
    // Separate ports follow the documented single-clock true-dual-port pattern.
    always @(posedge clk) begin
        if(write_enable) begin
            memory[address]<=write_data;
            read_data<=write_data;
        end else read_data<=memory[address];
    end
    // Video remains synchronous OLD data on a simultaneous CPU write.
    always @(posedge clk) begin
        video_data<=memory[video_address];
    end
endmodule
