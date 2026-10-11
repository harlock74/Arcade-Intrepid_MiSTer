// Stage K host input/DIP adapter. Pinned MAME reference: contracts/stage_k_integration.json.
// Host joystick bits R,L,D,U,Action,Start1,Coin,Start2. Game A000 is active high
// after MAME's input-port inversion. The accepted main bus owns the Q6 player mux.
module intrepid_inputs #(parameter COIN_CYCLES=990000)(
    input wire clk, reset,
    input wire [31:0] joystick_0, joystick_1,
    input wire [10:0] ps2_key,
    input wire [127:0] status,
    input wire block_game_inputs,
    input wire coin_step,
    output wire pause_button,
    output wire gameplay_controls_released,
    output wire [7:0] player1, player2, system_inputs, dips
);
    reg [7:0] keys=0;
    reg key_toggle=0;
    always @(posedge clk) begin
        key_toggle<=ps2_key[10];
        if(reset) keys<=0;
        else if(key_toggle!=ps2_key[10]) begin
            case(ps2_key[7:0])
                8'h74: if(ps2_key[8]) keys[0]<=ps2_key[9]; // Right
                8'h6b: if(ps2_key[8]) keys[1]<=ps2_key[9]; // Left
                8'h72: if(ps2_key[8]) keys[2]<=ps2_key[9]; // Down
                8'h75: if(ps2_key[8]) keys[3]<=ps2_key[9]; // Up
                8'h14: keys[4]<=ps2_key[9]; // Ctrl / Action
                8'h16: if(!ps2_key[8]) keys[5]<=ps2_key[9]; // 1 / Start 1
                8'h2e: if(!ps2_key[8]) keys[6]<=ps2_key[9]; // 5 / Coin
                8'h1e: if(!ps2_key[8]) keys[7]<=ps2_key[9]; // 2 / Start 2
                default: ;
            endcase
        end
    end
    wire [7:0] p1=joystick_0[7:0]|keys;
    wire [7:0] shared=p1|joystick_1[7:0];
    assign pause_button=joystick_0[8] | joystick_1[8];
    assign gameplay_controls_released=!(|shared);
    assign player1=reset || block_game_inputs ? 8'd0 : {3'd0,p1[4:2],p1[0],p1[1]};
    assign player2=reset || block_game_inputs ? 8'd0 : {3'd0,joystick_1[4:2],joystick_1[0],joystick_1[1]};
    // Parent ROM 0138..0154 accepts a coin held 2..15 frame polls, on release.
    // Three nominal frames = 990000 clocks: bounded press, rearm only on release.
    // A new edge while the pulse is active is ignored, never queued or repeated.
    reg [19:0] coin_count=0;
    reg coin_armed=0;
    wire coin_active=coin_count!=0;
    always @(posedge clk) begin
        if(reset) begin coin_count<=0;coin_armed<=0;end
        else if(coin_step) begin
            if(coin_count!=0) coin_count<=coin_count-1'b1;
            if(!shared[6]) coin_armed<=1;
            else if(coin_armed) begin
                coin_armed<=0;
                if(coin_count==0) coin_count<=COIN_CYCLES;
            end
        end
    end
    assign system_inputs=reset || block_game_inputs ? 8'd0 : {4'd0,shared[7],shared[5],1'b0,coin_active};
    wire [1:0] coinage=status[15:14]==0 ? 2'b01 : status[15:14]==1 ? 2'b10 : status[15:14]==2 ? 2'b11 : 2'b00;
    assign dips={coinage,status[13],status[12],~status[11],~status[10],~status[9],~status[8]};
endmodule
