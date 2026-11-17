// 36.864 MHz PLL domain. Enables for the 18.432 MHz master, 6.144 MHz
// raster and 3.072 MHz main Z80; the CPU enable coincides with alternate pixels.
module intrepid_clock_enables(
    input wire clk, reset,
    output wire master_ce, event_ce, cpu_ce
);
    reg [3:0] phase=0;
    assign master_ce=!reset && phase[0];
    assign event_ce=master_ce && (phase==4'd1 || phase==4'd7);
    assign cpu_ce=master_ce && phase==4'd1;
    always @(posedge clk) begin
        if(reset || phase==4'd11) phase<=0;
        else phase<=phase+1'b1;
    end
endmodule
