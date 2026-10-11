`timescale 1ns/1ps
// Isolated Stage B machine-control contract. These are ordinary enables and
// event qualifiers in clk_sys; no clock is generated or gated as a clock net.
module intrepid_pause_machine_control(
    input  wire pause_active,
    input  wire raw_main_cpu_ce,
    input  wire raw_sound_cpu_ce,
    input  wire raw_ay_ce,
    input  wire raw_raster_event_ce,
    input  wire raw_main_nmi_set,
    input  wire raw_sound_irq_set,
    input  wire signed [15:0] raw_audio,
    output wire main_cpu_ce,
    output wire sound_cpu_ce,
    output wire ay_ce,
    output wire raster_event_ce,
    output wire main_nmi_set,
    output wire sound_irq_set,
    output wire watchdog_step,
    output wire coin_step,
    output wire gameplay_step,
    output wire signed [15:0] audio
);
    assign main_cpu_ce = raw_main_cpu_ce && !pause_active;
    assign sound_cpu_ce = raw_sound_cpu_ce && !pause_active;
    assign ay_ce = raw_ay_ce && !pause_active;
    assign raster_event_ce = raw_raster_event_ce;
    assign main_nmi_set = raw_main_nmi_set && !pause_active;
    assign sound_irq_set = raw_sound_irq_set && !pause_active;
    assign watchdog_step = !pause_active;
    assign coin_step = !pause_active;
    assign gameplay_step = !pause_active;
    assign audio = pause_active ? 16'sd0 : raw_audio;
endmodule
