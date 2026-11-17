// 36.864 MHz system clock. Sound Z80 averages 2.5 MHz; AY is exactly /24.
module intrepid_sound_clocks(
    input wire clk, reset,
    output wire cpu_ce, ay_ce
);
    reg [13:0] cpu_phase=0;
    reg [4:0] ay_phase=0;
    wire [13:0] next_cpu=cpu_phase+14'd625;
    assign cpu_ce=!reset && next_cpu>=14'd9216;
    assign ay_ce=!reset && ay_phase==5'd23;
    always @(posedge clk) begin
        if(reset) begin cpu_phase<=0;ay_phase<=0;end
        else begin
            cpu_phase<=cpu_ce ? next_cpu-14'd9216 : next_cpu;
            ay_phase<=ay_ce ? 5'd0 : ay_phase+1'b1;
        end
    end
endmodule
