// Pinned roundup.cpp screen_update: solid category 0, transparent tile,
// low sprite, solid category 1, high sprite. Synthetic RGB is MAME-derived,
// DOCUMENTED-APPROXIMATION / UNRESOLVED for original hardware fidelity.
module intrepid_composition(
 input wire [23:0] tile_rgb,
 input wire tile_opaque,
 input wire [7:0] attribute,
 input wire [25:0] sprite_pixel,
 input wire de,reset,
 output wire [23:0] rgb,
 output reg [23:0] preblank_rgb,
 output reg [2:0] owner
);
 wire [2:0] solid=attribute[6:4];
 wire high_solid=(solid!=0) && !attribute[7];
 wire [23:0] solid_rgb={{8{solid[2]}},{8{solid[1]}},{8{solid[0]}}};
 // A high sprite always supersedes low sprites; otherwise the last opaque
 // low sprite remains. One winner+priority tag suffices across both passes.
 always @* begin
  preblank_rgb=solid_rgb;owner=0;
  if(tile_opaque)begin preblank_rgb=tile_rgb;owner=1;end
  if(sprite_pixel[24] && !sprite_pixel[25])begin preblank_rgb=sprite_pixel[23:0];owner=2;end
  if(high_solid)begin preblank_rgb=solid_rgb;owner=3;end
  if(sprite_pixel[24] && sprite_pixel[25])begin preblank_rgb=sprite_pixel[23:0];owner=4;end
 end
 assign rgb=de && !reset ? preblank_rgb : 24'd0;
endmodule
