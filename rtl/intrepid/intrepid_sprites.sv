// Stage H line renderer. CPU descriptor read copy; private graphics/PROM read
// copies; one 512xPIXEL_WIDTH ping-pong RAM. Stage I selects 26 bits,
// retaining priority at bit 25 alongside H valid/RGB. Default 25 retains H tests.
// No reset loops or extra clocks.
module intrepid_sprites #(parameter PIXEL_WIDTH=25)(
 input wire clk,reset,event_ce,
 input wire [8:0] h,v,
 input wire bank,global_x,global_y,
 input wire descriptor_write,
 input wire [4:0] descriptor_address,
 input wire [7:0] descriptor_data,
 input wire load_graphics,load_palette,
 input wire [12:0] load_address,
 input wire [7:0] load_data,
 output wire [PIXEL_WIDTH-1:0] pixel,
 output wire busy,
 output reg overrun=0
);
 (* ramstyle="M10K" *) reg [7:0] descriptors[0:31];
 initial $readmemh("rtl/intrepid/sprite_zero.hex",descriptors);
 (* ramstyle="M10K" *) reg [7:0] gfx_low[0:4095],gfx_high[0:4095];
 (* ramstyle="M10K" *) reg [7:0] palette[0:31];
 (* ramstyle="M10K" *) reg [PIXEL_WIDTH-1:0] lines[0:511];
 localparam IDLE=0,CLEAR=1,REQUEST=2,CAPTURE=3,EVALUATE=4,FETCH=5,LOOKUP=6,WRITE=7,NEXT=8,FINISH=9;
 reg [3:0] state=IDLE;
 reg [7:0] clear_x=0;
 reg [8:0] target_y=0;
 reg target_bank=0,fx=0,fy=0,pass=0;
 reg [2:0] number=7;
 reg [1:0] byte_index=0;
 reg [3:0] px=0;
 reg [31:0] descriptor=0;
 reg [7:0] descriptor_q,low_q,high_q,prom_q;
 wire [11:0] ga;wire [2:0] bitno,colour;wire pri,visible;
 wire [7:0] sx;wire [3:0] source_x,source_y;
 intrepid_sprite_pixel mapping(.descriptor(descriptor),.number(number),.bank(target_bank),.global_x(fx),.global_y(fy),
  .line_y(target_y),.pixel_x(px),.graphics_address(ga),.bit_number(bitno),.colour(colour),.priority_bit(pri),.visible(visible),.screen_x(sx),.source_x(source_x),.source_y(source_y));
 wire [1:0] pen={high_q[bitno],low_q[bitno]};
 wire [4:0] pa={colour,pen};
 function automatic [7:0] rg(input [2:0] b);
  begin rg=(b[0]?8'd33:8'd0)+(b[1]?8'd71:8'd0)+(b[2]?8'd151:8'd0);end
 endfunction
 wire [23:0] rgb={rg(prom_q[2:0]),rg(prom_q[5:3]),((prom_q[6]?8'd71:8'd0)+(prom_q[7]?8'd151:8'd0))};
 wire line_write=!reset && (state==CLEAR || (state==WRITE && visible && pen!=0));
 wire [8:0] write_address={target_y[0],state==CLEAR ? clear_x : sx};
 wire [PIXEL_WIDTH-1:0] write_pixel=state==CLEAR ? 25'd0 : (({{(PIXEL_WIDTH-1){1'b0}},pass} << 25) | {1'b1,rgb});
 reg [PIXEL_WIDTH-1:0] line_q;
 reg [8:0] ready_y0=0,ready_y1=0;
 reg ready0=0,ready1=0,read_valid=0;
 reg [PIXEL_WIDTH-1:0] pipe1=0,pipe2=0,pipe3=0,pipe4=0,pipe5=0;
 // Canonical simple dual-port memories. CPU writes persist across soft resets.
 always @(posedge clk) begin
  if(descriptor_write)descriptors[descriptor_address]<=descriptor_data;
  descriptor_q<=descriptors[{number,byte_index}];
  if(load_graphics && !load_address[12])gfx_low[load_address[11:0]]<=load_data;
  if(load_graphics && load_address[12])gfx_high[load_address[11:0]]<=load_data;
  if(load_palette)palette[load_address[4:0]]<=load_data;
  low_q<=gfx_low[ga];high_q<=gfx_high[ga];prom_q<=palette[pa];
  if(line_write)lines[write_address]<=write_pixel;
  line_q<=lines[{v[0],h[7:0]}];
 end
 // A line is displayed only when its completed tag matches the current raster.
 // 1 RAM latency + 5 registers = raw event t to output t+5, aligned with G.
 always @(posedge clk) begin
  if(reset)begin read_valid<=0;pipe1<=0;pipe2<=0;pipe3<=0;pipe4<=0;pipe5<=0;end
  else begin
   read_valid<=h<256 && (v[0] ? ready1 && ready_y1==v : ready0 && ready_y0==v);
   pipe1<=read_valid ? line_q : 25'd0;pipe2<=pipe1;pipe3<=pipe2;pipe4<=pipe3;pipe5<=pipe4;
  end
 end
 assign pixel=reset ? 25'd0 : pipe5;
 assign busy=state!=IDLE;
 always @(posedge clk) begin
  if(reset)begin
   state<=IDLE;clear_x<=0;target_y<=0;target_bank<=0;fx<=0;fy<=0;pass<=0;number<=7;byte_index<=0;px<=0;descriptor<=0;
   ready0<=0;ready1<=0;ready_y0<=0;ready_y1<=0;overrun<=0;
  end else if(event_ce && h==0)begin
   if(state!=IDLE)overrun<=1;
   target_y<=v==263 ? 9'd0 : v+9'd1;target_bank<=bank;fx<=global_x;fy<=global_y;
   clear_x<=0;pass<=0;number<=7;byte_index<=0;px<=0;state<=CLEAR;
   if(v==263 || v[0])ready0<=0;else ready1<=0;
  end else case(state)
   CLEAR: if(clear_x==255)begin state<=REQUEST;byte_index<=0;end else clear_x<=clear_x+8'd1;
   REQUEST:state<=CAPTURE;
   CAPTURE:begin
    descriptor[8*byte_index+:8]<=descriptor_q;
    if(byte_index==3)begin state<=EVALUATE;px<=0;end
    else begin byte_index<=byte_index+2'd1;state<=REQUEST;end
   end
   EVALUATE:begin
    // X clipping can reject pixel 0 while later pixels are visible: only Y/raw
    // descriptor/priority decide whether to visit all sixteen pixels here.
    if(pri==pass && descriptor[7:0]!=0 && descriptor[31:24]!=0)state<=FETCH;else state<=NEXT;
   end
   FETCH:state<=LOOKUP;
   LOOKUP:state<=WRITE;
   WRITE:if(px==15)state<=NEXT;else begin px<=px+4'd1;state<=FETCH;end
   NEXT:begin
    byte_index<=0;
    if(number!=0)begin number<=number-3'd1;state<=REQUEST;end
    else if(!pass)begin pass<=1;number<=7;state<=REQUEST;end
    else state<=FINISH;
   end
   FINISH:begin
    if(target_y[0])begin ready_y1<=target_y;ready1<=1;end else begin ready_y0<=target_y;ready0<=1;end
    state<=IDLE;
   end
   default:state<=IDLE;
  endcase
 end
endmodule
