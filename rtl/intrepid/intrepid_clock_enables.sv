// 20 MHz PLL domain. Rational enables, not clocks: 18.432 MHz master,
// 6.144 MHz event/pixel cadence, 3.072 MHz main Z80 T-state cadence.
module intrepid_clock_enables(
    input wire clk, reset,
    output wire master_ce, event_ce, cpu_ce
);
    reg [9:0] accumulator=0;
    reg [2:0] divider=0;
    wire [10:0] sum={1'b0,accumulator}+11'd576;
    wire [10:0] next_sum=sum>=11'd625 ? sum-11'd625 : sum;
    assign master_ce=!reset && sum>=11'd625;
    assign event_ce=master_ce && (divider==0 || divider==3);
    assign cpu_ce=master_ce && divider==0;
    always @(posedge clk) begin
        if(reset) begin accumulator<=0;divider<=0;end
        else begin
            accumulator<=next_sum[9:0];
            if(master_ce) divider<=divider==5 ? 0 : divider+1'b1;
        end
    end
endmodule
