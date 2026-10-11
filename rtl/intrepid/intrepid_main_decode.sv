// Exact pinned intrepid_main_map. ROM holes and unmapped reads return zero.
module intrepid_main_decode(
    input wire [15:0] address,
    output wire rom_select, ram_select,
    output reg [12:0] ram_address,
    output wire controls_select, system_select, dip_select, latch_select, watchdog_select
);
    wire work_ram=address>=16'h8000 && address<=16'h87ff;
    wire tile_ram=address>=16'h9000 && address<=16'h93ff;
    wire colour_ram=(address>=16'h8c00 && address<=16'h8fff) || (address>=16'h9400 && address<=16'h97ff);
    wire attributes=(address & 16'hf8c0)==16'h9800;
    wire descriptors=address>=16'h9840 && address<=16'h98ff;
    assign rom_select=address<16'h5000;
    assign ram_select=work_ram || tile_ram || colour_ram || attributes || descriptors;
    always @* begin
        ram_address=0;
        if(work_ram) ram_address={2'b00,address[10:0]};
        else if(tile_ram) ram_address=13'h800+{3'b000,address[9:0]};
        else if(colour_ram) ram_address=13'hc00+{3'b000,address[9:0]};
        else if(attributes) ram_address=13'h1000+{7'd0,address[5:0]};
        else if(descriptors) ram_address=13'h1000+{5'd0,address[7:0]};
    end
    assign controls_select=address==16'ha000;
    assign system_select=address==16'ha800;
    assign dip_select=address==16'hb000;
    assign latch_select=address>=16'hb000 && address<=16'hb007;
    assign watchdog_select=address==16'hb800;
endmodule
