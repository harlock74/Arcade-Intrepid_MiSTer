// Native Stage E diagnostic output through unchanged production MiSTer cleaner.
// No scandoubler: accepted 20 MHz is below video_mixer's 4*6.144 MHz requirement.
module intrepid_video(
    input wire clk, reset, event_ce,
    input wire [7:0] red, green, blue,
    input wire hblank, vblank, hsync, vsync, de,
    output wire ce_pixel,
    output wire [7:0] vga_r, vga_g, vga_b,
    output wire vga_hs, vga_vs, vga_de
);
    wire [7:0] clean_r,clean_g,clean_b;
    wire clean_hs,clean_vs,clean_de;
    video_cleaner cleaner(
        .clk_vid(clk),.ce_pix(event_ce),.R(red),.G(green),.B(blue),
        .HSync(hsync),.VSync(vsync),.HBlank(hblank),.VBlank(vblank),
        .DE_in(de),.interlace(1'b0),.f1(1'b0),
        .VGA_R(clean_r),.VGA_G(clean_g),.VGA_B(clean_b),
        .VGA_HS(clean_hs),.VGA_VS(clean_vs),.VGA_DE(clean_de),
        .HBlank_out(),.VBlank_out(),.DE_out());
    reg sampled_ce=0;
    always @(posedge clk) sampled_ce<=event_ce;
    assign ce_pixel=!reset && sampled_ce;
    assign vga_r=reset ? 8'd0 : clean_r;
    assign vga_g=reset ? 8'd0 : clean_g;
    assign vga_b=reset ? 8'd0 : clean_b;
    assign vga_hs=!reset && clean_hs;
    assign vga_vs=!reset && clean_vs;
    assign vga_de=!reset && clean_de;
endmodule
