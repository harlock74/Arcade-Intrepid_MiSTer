`timescale 1ns/1ps
// Isolated Pause Stage B event retention. A request which arrives while Pause
// blocks new live-RAM ownership is retained and emitted once after resume.
module intrepid_pause_hiscore_arbiter(
    input wire clk, reset,
    input wire block_new_hiscore,
    input wire boot_event, save_event,
    output wire manager_boot_event,
    output wire manager_save_event,
    output reg boot_pending = 1'b0,
    output reg save_pending = 1'b0
);
    // Preserve the production event timing exactly when Pause is not blocking
    // ownership. Only events observed while blocked take the pending path.
    assign manager_boot_event = !block_new_hiscore && (boot_event || boot_pending);
    assign manager_save_event = !block_new_hiscore && (save_event || save_pending);

    always @(posedge clk) begin
        if(reset) begin
            boot_pending <= 1'b0;
            save_pending <= 1'b0;
        end else begin
            if(block_new_hiscore && boot_event) boot_pending <= 1'b1;
            else if(!block_new_hiscore && boot_pending) boot_pending <= 1'b0;
            if(block_new_hiscore && save_event) save_pending <= 1'b1;
            else if(!block_new_hiscore && save_pending) save_pending <= 1'b0;
        end
    end
endmodule
