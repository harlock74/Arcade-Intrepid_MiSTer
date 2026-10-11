// Presentation settings only. Never change native game coordinates or input mux.
module intrepid_presentation(
    input wire [127:0] status,
    input wire direct_video,
    output wire no_rotate, vga_scaler,
    output wire [12:0] arx, ary,
    output wire [15:0] menu_mask
);
    assign no_rotate=status[1] | direct_video;
    assign vga_scaler=!direct_video && (!no_rotate || status[4]);
    wire [1:0] aspect=status[3:2];
    assign arx=aspect==0 ? (no_rotate ? 13'd4 : 13'd3) : {11'd0,aspect-2'd1};
    assign ary=aspect==0 ? (no_rotate ? 13'd3 : 13'd4) : 13'd0;
    assign menu_mask={14'd0,(!no_rotate || direct_video),direct_video};
endmodule
