// Pure isolated mapping contract. No connection to live RAM in Stage B.
module intrepid_hiscore_map(input wire [6:0] offset,
 output wire valid,output wire [15:0] cpu_address,output wire [12:0] ram_address);
 assign valid=offset<63;
 assign cpu_address=!valid ? 16'd0 : offset<60 ? 16'h803d+{9'd0,offset} : 16'h8035+({9'd0,offset}-16'd60);
 assign ram_address=valid ? {2'd0,cpu_address[10:0]} : 13'd0;
endmodule
