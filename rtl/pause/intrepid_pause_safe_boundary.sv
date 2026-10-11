`timescale 1ns/1ps
// Exact isolated Stage B entry predicate. A user pause may only become active
// with both TV80 buses externally idle and no live-RAM hiscore ownership.
module intrepid_pause_safe_boundary(
    input wire main_mreq_n, main_iorq_n, main_rd_n, main_wr_n,
    input wire main_read_fire, main_write_fire,
    input wire sound_mreq_n, sound_iorq_n, sound_rd_n, sound_wr_n,
    input wire sound_read_fire, sound_write_fire, sound_ack_fire,
    input wire sound_command_commit, sound_pipeline_busy,
    input wire hiscore_active, hiscore_atomic, hiscore_owns,
    input wire hiscore_busrq_n, main_busak_n, hiscore_ram_write,
    output wire main_idle, sound_idle, hiscore_idle, safe_to_pause
);
    assign main_idle = main_mreq_n && main_iorq_n && main_rd_n && main_wr_n &&
                       !main_read_fire && !main_write_fire;
    assign sound_idle = sound_mreq_n && sound_iorq_n && sound_rd_n && sound_wr_n &&
                        !sound_read_fire && !sound_write_fire && !sound_ack_fire &&
                        !sound_command_commit && !sound_pipeline_busy;
    assign hiscore_idle = !hiscore_active && !hiscore_atomic && !hiscore_owns &&
                          hiscore_busrq_n && main_busak_n && !hiscore_ram_write;
    assign safe_to_pause = main_idle && sound_idle && hiscore_idle;
endmodule
