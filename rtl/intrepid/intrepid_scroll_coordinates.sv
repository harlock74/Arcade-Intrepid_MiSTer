// Stage G inverse coordinates, derived from pinned MAME tilemap draw placement.
// Screen rotation is deliberately absent. Coordinates wrap on the 256x256 map.
module intrepid_scroll_coordinates(
    input wire [7:0] x,y,scroll,
    input wire flip_x,flip_y,
    output wire [4:0] column,
    output wire [7:0] source_x,source_y
);
    assign source_x=flip_x ? 8'd255-x : x;
    assign column=source_x[7:3];
    wire [7:0] base_y=flip_y ? 8'd255-y : y;
    assign source_y=base_y+scroll;
endmodule
