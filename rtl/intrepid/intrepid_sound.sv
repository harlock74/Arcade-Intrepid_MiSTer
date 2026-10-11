// Stage J production sound subsystem; unchanged TV80 primitive, separate CPU.
module intrepid_sound(
    input wire clk, reset, phase_reset, stall, raster_irq, enable, pause_active,
    input wire command_write,
    input wire [7:0] command_data,
    input wire load_rom,
    input wire [11:0] load_address,
    input wire [7:0] load_data,
    output wire signed [15:0] audio,
    output wire pause_safe
);
    wire cpu_clock_ce,raw_ay_ce;
    intrepid_sound_clocks clocks(.clk(clk),.reset(phase_reset),.cpu_ce(cpu_clock_ce),.ay_ce(raw_ay_ce));
    wire gated_cpu_ce,ay_ce;
    wire signed [15:0] raw_audio;
    intrepid_pause_machine_control pause_control(.pause_active(pause_active),
        .raw_main_cpu_ce(cpu_clock_ce),.raw_sound_cpu_ce(cpu_clock_ce),.raw_ay_ce(raw_ay_ce),
        .raw_raster_event_ce(1'b0),.raw_main_nmi_set(1'b0),.raw_sound_irq_set(1'b0),.raw_audio(raw_audio),
        .main_cpu_ce(),.sound_cpu_ce(gated_cpu_ce),.ay_ce(ay_ce),.raster_event_ce(),
        .main_nmi_set(),.sound_irq_set(),.watchdog_step(),.coin_step(),.gameplay_step(),.audio(audio));
    wire cpu_ce=gated_cpu_ce && !reset && !stall;
    wire [15:0] address;
    wire [7:0] read_data,write_data,command;
    wire mreq_n,iorq_n,m1_n,rd_n,wr_n,irq;
    wire read_fire,write_fire,ack_fire,ay_pipeline_busy;
    wire signed [15:0] a,b,c,d,e,f;
    tv80e #(.Mode(0),.T2Write(1),.IOWait(1)) cpu(
        .clk(clk),.reset_n(!reset),.cen(cpu_ce),.wait_n(1'b1),.int_n(!irq),.nmi_n(1'b1),.busrq_n(1'b1),
        .di(read_data),.dout(write_data),.A(address),.m1_n(m1_n),.mreq_n(mreq_n),.iorq_n(iorq_n),
        .rd_n(rd_n),.wr_n(wr_n),.rfsh_n(),.halt_n(),.busak_n());
    intrepid_sound_bus bus(.clk(clk),.reset(reset),.ay_ce(ay_ce),.raster_irq(raster_irq),
        .command_write(command_write),.command_data(command_data),.load_rom(load_rom),.load_address(load_address),.load_data(load_data),
        .address(address),.write_data(write_data),.mreq_n(mreq_n),.iorq_n(iorq_n),.m1_n(m1_n),.rd_n(rd_n),.wr_n(wr_n),
        .read_data(read_data),.irq(irq),.command(command),.read_fire(read_fire),.write_fire(write_fire),.ack_fire(ack_fire),.ay_pipeline_busy(ay_pipeline_busy),
        .ay1_a(a),.ay1_b(b),.ay1_c(c),.ay2_a(d),.ay2_b(e),.ay2_c(f));
    intrepid_sound_mixer mixer(.reset(reset),.enable(enable),.a(a),.b(b),.c(c),.d(d),.e(e),.f(f),.audio(raw_audio));
    assign pause_safe=mreq_n && iorq_n && rd_n && wr_n && !read_fire && !write_fire && !ack_fire &&
        !command_write && !ay_pipeline_busy && !cpu_clock_ce && !raw_ay_ce;
endmodule
