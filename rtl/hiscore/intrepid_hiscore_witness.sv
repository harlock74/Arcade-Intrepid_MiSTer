// Parent-ROM-bound events. No time delay or static sentinel can open an epoch.
module intrepid_hiscore_witness(
 input wire clk, reset, parent_ok, read_fire, write_fire, m1_n,
 input wire [15:0] address,input wire [7:0] read_data,write_data,
 output wire boot_event,update_busy,output reg initialized=0,
 output reg changed=0,input wire captured,capture_rejected
`ifdef INTREPID_HS_DIAG
 ,output wire [31:0] diag
`endif
);
 reg update_active=0;
 reg armed=0;reg [6:0] copied=0;reg [15:0] opcode=0;
 wire fetch=read_fire && !m1_n;
 wire update_start=initialized && fetch && (address==16'h174e || address==16'h1207);
 // Close the boundary in the same cycle as the entry fetch. Otherwise an OSD
 // event coincident with that fetch can be consumed as an unchanged snapshot.
 assign update_busy=update_active || update_start;
 wire table_address=address>=16'h803d && address<=16'h8078;
 wire persist_address=table_address || (address>=16'h8035 && address<=16'h8037);
`ifdef INTREPID_HS_DIAG
 assign diag={opcode,copied,armed,4'd0,boot_event,update_busy,changed,initialized};
`endif
 assign boot_event=!reset && parent_ok && !initialized && armed && copied==60 && fetch && address==16'h1398 && read_data==8'hc9;
 always @(posedge clk) begin
  if(reset || !parent_ok)begin armed<=0;copied<=0;opcode<=0;initialized<=0;update_active<=0;changed<=0;end
  else begin
   if(captured)changed<=0;
   if(capture_rejected)changed<=1;
   if(fetch)begin
    opcode<=address;
    if(!initialized && address==16'h1511 && read_data==8'hcd)begin armed<=1;copied<=0;end
    // Entire game-over score/name transaction, including both players. A
    // conditional RET opcode by itself does not prove that the RET was taken.
    if(initialized && (address==16'h174e || address==16'h1207))update_active<=1;
    if(initialized && address==16'h179d)update_active<=0;
   end
   if(armed && write_fire && table_address)begin
    if(copied<60 && address==16'h803d+{9'd0,copied} && opcode==16'h1397)copied<=copied+1'b1;
    else begin armed<=0;copied<=0;end
   end
   if(boot_event)begin initialized<=1;armed<=0;end
   if(initialized && write_fire && persist_address)changed<=1;
  end
 end
endmodule
