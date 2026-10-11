// CONFIRMED-MAME: roundup.cpp set_raw(6144000,384,0,256,264,16,240).
// DOCUMENTED-APPROXIMATION: positive HS [288,320), VS lines [248,252).
// Original PCB sync width/position/polarity remains UNRESOLVED.
module intrepid_raster(
    input wire clk, reset, event_ce,
    output reg [8:0] h=0, v=0,
    output wire hblank, vblank, hsync, vsync, de,
    output wire [7:0] red, green, blue,
    output wire frame_event, nmi_opportunity
);
    always @(posedge clk) begin
        if(reset) begin h<=0;v<=0;end
        else if(event_ce) begin
            if(h==9'd383) begin
                h<=0;v<=v==9'd263 ? 9'd0 : v+9'd1;
            end else h<=h+9'd1;
        end
    end
    assign hblank=reset || h>=9'd256;
    assign vblank=reset || v<9'd16 || v>=9'd240;
    assign de=!(hblank || vblank);
    assign hsync=!reset && h>=9'd288 && h<9'd320;
    assign vsync=!reset && v>=9'd248 && v<9'd252;
    // Procedural diagnostic only: no VRAM/graphics ROM/palette data consumed.
    assign red=de ? {h[7:5],5'b11111} : 8'd0;
    assign green=de ? {v[7:5],5'b11111} : 8'd0;
    assign blue=de ? 8'h80 : 8'd0;
    // Events describe the incoming coordinate, sampled on the advancing edge.
    assign frame_event=!reset && event_ce && h==9'd383 && v==9'd263;
    assign nmi_opportunity=!reset && event_ce && h==9'd383 && v==9'd239;
endmodule
