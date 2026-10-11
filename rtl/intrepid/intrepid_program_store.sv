// Stage B's entire 0x8020-byte packed stream, one write and one synchronous
// read port. No ROM initialization payload or array reset. The post-load scan
// retains and verifies every destination, including future sound/gfx/PROM data.
module intrepid_program_store(
    input wire clk, write_enable,
    input wire [15:0] write_address, read_address,
    input wire [7:0] write_data,
    output reg [7:0] read_data
);
    (* ramstyle="M10K" *) reg [7:0] memory [0:32799];
    always @(posedge clk) begin
        if(write_enable) memory[write_address]<=write_data;
        read_data<=memory[read_address];
    end
endmodule
