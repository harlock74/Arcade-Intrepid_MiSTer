// Stage H: one bounded pixel of a MAME sprite; no physical-ROM interleave.
module intrepid_sprite_pixel(
 input wire [31:0] descriptor,
 input wire [2:0] number,
 input wire bank,global_x,global_y,
 input wire [8:0] line_y,
 input wire [3:0] pixel_x,
 output wire [11:0] graphics_address,
 output wire [2:0] bit_number,colour,
 output wire priority_bit,visible,
 output wire [7:0] screen_x,
 output wire [3:0] source_x,source_y
);
 wire [7:0] d0=descriptor[7:0],d1=descriptor[15:8],d2=descriptor[23:16],d3=descriptor[31:24];
 wire [7:0] initial_y=8'd240-d0,initial_x=d3+8'd1;
 wire [7:0] origin_x=global_x ? 8'd242-initial_x : initial_x;
 wire [7:0] flipped_y=global_y ? 8'd240-initial_y : initial_y;
 wire [7:0] origin_y=flipped_y+(number<4 ? 8'd1 : 8'd0);
 wire [8:0] row_delta=line_y-{1'b0,origin_y};
 assign screen_x=origin_x+{4'd0,pixel_x}; // x and x-256 copies, modulo 256
 assign source_x=(d1[6]^global_x) ? 4'd15-pixel_x : pixel_x;
 assign source_y=(d1[7]^global_y) ? 4'd15-row_delta[3:0] : row_delta[3:0];
 assign graphics_address={bank,d1[5:0],source_y[3],source_x[3],source_y[2:0]};
 assign bit_number=3'd7-source_x[2:0];
 assign colour=d2[2:0];assign priority_bit=d2[3];
 assign visible=d0!=0 && d3!=0 && line_y>=9'd16 && line_y<=9'd239 &&
  line_y>={1'b0,origin_y} && row_delta<9'd16 &&
  (global_x ? screen_x<=8'd238 : screen_x>=8'd17);
endmodule
