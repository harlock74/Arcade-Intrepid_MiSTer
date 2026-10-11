// Accepted F RGB fetch backend, driven by G coordinates. Stage I additionally
// exports pen opacity and attribute aligned with RGB; addressing/RGB unchanged.
// MAME layout plane 0 (gfx +0x1000) has weight 2, plane 1 (+0) weight 1.
module intrepid_background(
    input wire clk, reset, event_ce,
    input wire [8:0] h,v,
    input wire hblank,vblank,hsync,vsync,de,
    input wire graphics_bank,
    output wire [12:0] video_address,
    input wire [7:0] video_data,
    input wire load_graphics,load_palette,
    input wire [12:0] load_address,
    input wire [7:0] load_data,
    output wire out_ce,out_hblank,out_vblank,out_hsync,out_vsync,out_de,
    output reg [7:0] red=0,green=0,blue=0,
    output reg tile_opaque=0,
    output reg [7:0] tile_attribute=0
);
    // Intentional video read copies of verified download: 8192+32 bytes.
    // Stage D archival store remains unchanged for CPU and stored-stream CRC.
    // One write + one synchronous read per array; no reset/init of ROM arrays.
    (* ramstyle="M10K" *) reg [7:0] gfx_low [0:4095];
    (* ramstyle="M10K" *) reg [7:0] gfx_high [0:4095];
    (* ramstyle="M10K" *) reg [7:0] palette [0:31];
    reg [7:0] low_byte,high_byte,prom_byte;
    reg [9:0] tile_index=0;
    reg [7:0] code=0,attribute=0;
    reg [4:0] ce_pipe=0,hb_pipe=5'b11111,vb_pipe=5'b11111,hs_pipe=0,vs_pipe=0,de_pipe=0;
    reg [2:0] x0=0,x1=0,x2=0,row0=0,row1=0;
    reg bank0=0,bank1=0;
    reg pen_nonzero=0;
    reg [7:0] attribute_meta=0;
    // Two descriptor reads per event. Minimum CE spacing is three clocks.
    // t: code request; t+1: code capture / attribute request;
    // t+2: attribute capture / two plane reads; t+3: PROM read;
    // t+4: RGB and matching CE/blank/sync become valid.
    assign video_address=event_ce ? {3'b010,v[7:3],h[7:3]} : {3'b011,tile_index};
    wire [11:0] graphics_address={bank1,code,row1}; // bank*0x800 + code*8 + row
    wire [1:0] pen={high_byte[3'd7-x2],low_byte[3'd7-x2]};
    wire [4:0] prom_address={attribute[2:0],pen};
    always @(posedge clk) begin
        if(load_graphics && !load_address[12]) gfx_low[load_address[11:0]]<=load_data;
        if(load_graphics &&  load_address[12]) gfx_high[load_address[11:0]]<=load_data;
        if(load_palette) palette[load_address[4:0]]<=load_data;
        low_byte<=gfx_low[graphics_address];
        high_byte<=gfx_high[graphics_address];
        prom_byte<=palette[prom_address];
    end
    function automatic [7:0] rg_value(input [2:0] bits_in);
        begin rg_value=(bits_in[0]?8'h21:8'd0)+(bits_in[1]?8'h47:8'd0)+(bits_in[2]?8'h97:8'd0);end
    endfunction
    always @(posedge clk) begin
        if(reset) begin
            ce_pipe<=0;hb_pipe<=5'b11111;vb_pipe<=5'b11111;hs_pipe<=0;vs_pipe<=0;de_pipe<=0;
            tile_index<=0;code<=0;attribute<=0;x0<=0;x1<=0;x2<=0;row0<=0;row1<=0;bank0<=0;bank1<=0;
            red<=0;green<=0;blue<=0;tile_opaque<=0;tile_attribute<=0;pen_nonzero<=0;attribute_meta<=0;
        end else begin
            ce_pipe<={ce_pipe[3:0],event_ce};
            hb_pipe<={hb_pipe[3:0],hblank};vb_pipe<={vb_pipe[3:0],vblank};
            hs_pipe<={hs_pipe[3:0],hsync};vs_pipe<={vs_pipe[3:0],vsync};de_pipe<={de_pipe[3:0],de};
            if(event_ce) begin tile_index<={v[7:3],h[7:3]};x0<=h[2:0];row0<=v[2:0];bank0<=graphics_bank;end
            if(ce_pipe[0]) begin code<=video_data;x1<=x0;row1<=row0;bank1<=bank0;end
            if(ce_pipe[1]) begin attribute<=video_data;x2<=x1;end
            if(ce_pipe[2]) begin pen_nonzero<=pen!=0;attribute_meta<=attribute;end
            if(ce_pipe[3]) begin
                tile_opaque<=pen_nonzero;tile_attribute<=attribute_meta;
                red<=de_pipe[3] ? rg_value(prom_byte[2:0]) : 8'd0;
                green<=de_pipe[3] ? rg_value(prom_byte[5:3]) : 8'd0;
                blue<=de_pipe[3] ? ((prom_byte[6]?8'h47:8'd0)+(prom_byte[7]?8'h97:8'd0)) : 8'd0;
            end
        end
    end
    assign out_ce=!reset && ce_pipe[4];
    assign out_hblank=reset || hb_pipe[4];assign out_vblank=reset || vb_pipe[4];
    assign out_hsync=!reset && hs_pipe[4];assign out_vsync=!reset && vs_pipe[4];
    assign out_de=!reset && de_pipe[4];
endmodule
