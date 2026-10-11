`timescale 1ns/1ps
// Isolated Pause Stage B controller. Production integration is deferred.
// All state is synchronous to the existing 20 MHz clk_sys domain.
module intrepid_pause_controller(
    input  wire clk,
    input  wire reset,
    input  wire enabled,
    input  wire pause_button,
    input  wire safe_to_pause,
    input  wire gameplay_controls_released,
    output reg  pause_requested = 1'b0,
    output reg  pause_active = 1'b0,
    output reg  quarantine = 1'b0,
    output wire block_game_inputs,
    output wire block_new_hiscore
);
    // Arming from an observed low prevents boot/enabling while held from
    // becoming a synthetic press. A high level clears armed until release.
    reg armed = 1'b0;
    wire fresh_press = enabled && armed && pause_button;

    assign block_new_hiscore = pause_requested || pause_active || fresh_press;
    assign block_game_inputs = pause_requested || pause_active || quarantine || fresh_press;

    always @(posedge clk) begin
        if(reset || !enabled) begin
            armed <= 1'b0;
            pause_requested <= 1'b0;
            pause_active <= 1'b0;
            quarantine <= 1'b0;
        end else begin
            if(!pause_button) armed <= 1'b1;
            else if(fresh_press) begin
                armed <= 1'b0;
                quarantine <= 1'b1;
                if(pause_active || pause_requested) begin
                    // Resume or cancel a not-yet-granted pause immediately.
                    pause_requested <= 1'b0;
                    pause_active <= 1'b0;
                end else begin
                    pause_requested <= 1'b1;
                end
            end

            // Entry alone waits for an explicit machine-safe boundary.
            if(pause_requested && safe_to_pause && !fresh_press) begin
                pause_requested <= 1'b0;
                pause_active <= 1'b1;
            end

            // Inputs held before/during Pause do not appear immediately after
            // resume. Pause itself must also be released before quarantine ends.
            if(quarantine && !pause_requested && !pause_active &&
               !pause_button && gameplay_controls_released)
                quarantine <= 1'b0;
        end
    end
endmodule
