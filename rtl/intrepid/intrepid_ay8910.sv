// See LICENSES/MAME-AY8910-notice.txt for reference attribution.
// Intrepid-specific AY8910 functional model. Reference/provenance and limitations:
// validation/stage_j/ARCHITECTURE.md. Not a generic pin-level AY replacement.
// All state uses clk; ay_ce average 1.536 MHz on 20 MHz clk. At least 14 clk
// cycles between stream events are required for the bounded tone pipeline.
module intrepid_ay8910 #(
    parameter EXTERNAL_A = 0
)(
    input wire clk, reset, ay_ce,
    input wire address_write, data_write, data_read,
    input wire [7:0] write_data, port_a,
    output wire [7:0] read_data,
    output reg signed [15:0] channel_a, channel_b, channel_c,
    output reg sample,
    output wire [3:0] selected_register,
    output wire selected_active,
    output wire pipeline_busy
);
    reg [7:0] registers [0:15];
    reg [3:0] address=0;
    reg active=0;
    reg [2:0] divider=0;
    wire tick=ay_ce && divider==7;
    assign selected_register=address;
    assign selected_active=active;
    function automatic [7:0] mask(input [3:0] r);
        begin case(r)
            1,3,5,13: mask=8'h0f;
            6,8,9,10: mask=8'h1f;
            default: mask=8'hff;
        endcase end
    endfunction
    assign read_data=!active ? 8'hff : (address==14 && EXTERNAL_A) ? port_a : registers[address]&mask(address);
    integer i;
    initial begin
        for(i=0;i<16;i=i+1) registers[i]=0;
        channel_a=0;channel_b=0;channel_c=0;sample=0;
    end
    always @(posedge clk) begin
        if(reset) begin
            active<=0;address<=0;divider<=0;
            // MAME device reset preserves port registers 14 and 15.
            for(integer r=0;r<14;r=r+1) registers[r]<=0;
        end else begin
            if(ay_ce) divider<=divider+1'b1;
            if(address_write) begin
                active<=write_data[7:4]==0;
                if(write_data[7:4]==0) address<=write_data[3:0];
            end
            if(data_write && active) registers[address]<=write_data;
            if(data_read && active && address==14 && EXTERNAL_A) registers[14]<=port_a;
        end
    end

    reg [11:0] tone_count[0:2];
    reg [2:0] tone_output=0;
    reg [11:0] remainder[0:2];
    reg [22:0] divisor[0:2];
    reg [3:0] iteration=0;
    reg busy=0,finish=0;
    assign pipeline_busy=busy || finish;
    reg [4:0] noise_count=0;
    reg noise_prescale=0;
    reg [16:0] rng=17'd1;
    wire noise_step={1'b0,noise_count}+6'd1 >= {1'b0,registers[6][4:0]};
    wire [16:0] next_rng=noise_step && noise_prescale ? {rng[0]^rng[3],rng[16:1]} : rng;
    reg [16:0] envelope_count=0;
    reg [3:0] envelope_step=15,attack=0;
    reg hold=1,alternate=0,holding=0;
    wire envelope_step_due=!holding && ({1'b0,envelope_count}+18'd1 >= {1'b0,registers[12],registers[11],1'b0});
    wire [3:0] next_step=envelope_step_due ? (envelope_step!=0 ? envelope_step-1'b1 : hold ? 4'd0 : 4'd15) : envelope_step;
    wire [3:0] next_attack=envelope_step_due && envelope_step==0 && alternate ? ~attack : attack;
    wire [3:0] next_envelope=next_step^next_attack;
    reg [3:0] sampled_level[0:2];
    reg [2:0] sampled_envelope=0,sampled_tone_disable=0,sampled_noise_gate=0;
    function automatic signed [15:0] dac(input envelope,input [3:0] level);
        begin
            // MAME 1000-ohm legacy-normalized per-channel DAC, round-to-nearest Q15.
            // Fixed and envelope level zero have distinct resistance models.
            if(envelope) case(level)
                0:dac=-4096;1:dac=-3948;2:dac=-3881;3:dac=-3792;
                4:dac=-3654;5:dac=-3454;6:dac=-3209;7:dac=-2605;
                8:dac=-2239;9:dac=-1005;10:dac=212;11:dac=1650;
                12:dac=3606;13:dac=5682;14:dac=8872;15:dac=12288;
            endcase else case(level)
                0:dac=-4096;1:dac=-3874;2:dac=-3806;3:dac=-3718;
                4:dac=-3581;5:dac=-3382;6:dac=-3138;7:dac=-2537;
                8:dac=-2172;9:dac=-944;10:dac=267;11:dac=1698;
                12:dac=3646;13:dac=5712;14:dac=8888;15:dac=12288;
            endcase
        end
    endfunction
    wire signed [15:0] result[0:2];
    genvar c;
    generate for(c=0;c<3;c=c+1) begin: outputs
        assign result[c]=dac(sampled_envelope[c],((tone_output[c]|sampled_tone_disable[c]) && sampled_noise_gate[c]) ? sampled_level[c] : 4'd0);
    end endgenerate
    always @(posedge clk) begin
        sample<=0;finish<=0;
        if(reset) begin
            busy<=0;finish<=0;iteration<=0;tone_output<=0;
            noise_count<=0;noise_prescale<=0;rng<=17'd1;
            envelope_count<=0;envelope_step<=15;attack<=0;hold<=1;alternate<=0;holding<=0;
            sampled_envelope<=0;sampled_tone_disable<=0;sampled_noise_gate<=0;
            channel_a<=0;channel_b<=0;channel_c<=0;
            for(integer c=0;c<3;c=c+1) begin
                tone_count[c]<=0;remainder[c]<=0;divisor[c]<=0;sampled_level[c]<=0;
            end
        end else begin
            if(tick) begin
                busy<=1;iteration<=11;
                for(integer c=0;c<3;c=c+1) begin
                    remainder[c]<=tone_count[c]+12'd1;
                    divisor[c]<={((registers[2*c+1][3:0]==0 && registers[2*c]==0) ? 12'd1 : {registers[2*c+1][3:0],registers[2*c]}),11'b0};
                    sampled_level[c]<=registers[8+c][4] ? next_envelope : registers[8+c][3:0];
                    sampled_envelope[c]<=registers[8+c][4];
                    sampled_tone_disable[c]<=registers[7][c];
                    sampled_noise_gate[c]<=next_rng[0]|registers[7][c+3];
                end
                if(noise_step) begin noise_count<=0;noise_prescale<=!noise_prescale;end
                else noise_count<=noise_count+1'b1;
                rng<=next_rng;
                if(!holding) envelope_count<=envelope_step_due ? 17'd0 : envelope_count+1'b1;
                envelope_step<=next_step;attack<=next_attack;
                if(envelope_step_due && envelope_step==0 && hold) holding<=1;
            end
            if(busy) begin
                for(integer c=0;c<3;c=c+1) begin
                    if({11'd0,remainder[c]}>=divisor[c]) remainder[c]<=remainder[c]-divisor[c][11:0];
                    divisor[c]<=divisor[c]>>1;
                    if(iteration==0) begin
                        tone_count[c]<={11'd0,remainder[c]}>=divisor[c] ? remainder[c]-divisor[c][11:0] : remainder[c];
                        if({11'd0,remainder[c]}>=divisor[c]) tone_output[c]<=!tone_output[c];
                    end
                end
                if(iteration==0) begin busy<=0;finish<=1;end
                else iteration<=iteration-1'b1;
            end
            if(finish) begin
                channel_a<=result[0];channel_b<=result[1];channel_c<=result[2];sample<=1;
            end
            // Shape writes restart even when unchanged. MAME preserves count.
            if(data_write && active && address==13) begin
                attack<=write_data[2] ? 4'd15 : 4'd0;
                hold<=!write_data[3] || write_data[0];
                alternate<=write_data[3] ? write_data[1] : write_data[2];
                envelope_step<=15;holding<=0;
            end
        end
    end
endmodule
