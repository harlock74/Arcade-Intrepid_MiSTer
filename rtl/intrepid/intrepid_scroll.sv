// One extra synchronous RAM read ahead of the unchanged Stage F renderer.
// Accepted event CE gaps are >=3 clk_sys cycles: scroll, code, colour.
// No shadow RAM, additional memory port, clock, or display rotation.
module intrepid_scroll(
    input wire clk,reset,event_ce,
    input wire [8:0] h,v,
    input wire flip_x,flip_y,graphics_bank,
    input wire hblank,vblank,hsync,vsync,de,
    input wire [12:0] tile_address,
    input wire [7:0] video_data,
    output wire [12:0] video_address,
    output wire [8:0] source_h,source_v,
    output reg out_ce=0,out_bank=0,
    output reg out_hblank=1,out_vblank=1,out_hsync=0,out_vsync=0,out_de=0
);
    wire [4:0] lookup_column=flip_x ? 5'd31-h[7:3] : h[7:3];
    // Packed main RAM 0x1000 + 2*column = CPU 0x9800 + 2*column.
    assign video_address=event_ce ? {7'b1000000,lookup_column,1'b0} : tile_address;
    reg [7:0] sample_x=0,sample_y=0;
    reg sample_fx=0,sample_fy=0;
    wire [7:0] source_x,source_y;
    intrepid_scroll_coordinates coordinates(.x(sample_x),.y(sample_y),.scroll(video_data),
        .flip_x(sample_fx),.flip_y(sample_fy),.column(),.source_x(source_x),.source_y(source_y));
    assign source_h={1'b0,source_x};
    assign source_v={1'b0,source_y};
    always @(posedge clk) begin
        if(reset) begin
            out_ce<=0;out_bank<=0;out_hblank<=1;out_vblank<=1;out_hsync<=0;out_vsync<=0;out_de<=0;
            sample_x<=0;sample_y<=0;sample_fx<=0;sample_fy<=0;
        end else begin
            out_ce<=event_ce;
            out_hblank<=hblank;out_vblank<=vblank;out_hsync<=hsync;out_vsync<=vsync;out_de<=de;
            if(event_ce) begin
                sample_x<=h[7:0];sample_y<=v[7:0];sample_fx<=flip_x;sample_fy<=flip_y;out_bank<=graphics_bank;
            end
        end
    end
endmodule
