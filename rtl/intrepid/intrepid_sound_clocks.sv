// Accepted 20 MHz system clock; MAME-configured 2.5 MHz CPU and 1.536 MHz AY.
module intrepid_sound_clocks(
    input wire clk, reset,
    output wire cpu_ce, ay_ce
);
    reg [2:0] cpu_phase=0;
    reg [11:0] ay_phase=0;
    wire [12:0] next_ay={1'b0,ay_phase}+13'd192;
    assign cpu_ce=!reset && cpu_phase==7;
    assign ay_ce=!reset && next_ay>=13'd2500;
    always @(posedge clk) begin
        if(reset) begin cpu_phase<=0;ay_phase<=0;end
        else begin
            cpu_phase<=cpu_phase+1'b1;
            ay_phase<=next_ay>=13'd2500 ? next_ay-13'd2500 : next_ay;
        end
    end
endmodule
