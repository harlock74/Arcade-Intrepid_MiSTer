// Accepted Stage I video path plus Stage J board-specific audio.
module intrepid_machine #(parameter ENABLE_HISCORE=0)(
    input wire clk, reset, soft_reset, stall,
    input wire pause_active, block_new_hiscore,
    input wire download, wr,
    input wire [15:0] index,
    input wire [26:0] address,
    input wire [7:0] data,
    input wire [7:0] player1, player2, system_inputs, dips,
    output wire rom_ready, download_failed, cpu_reset,
    output wire [15:0] cpu_address,
    output wire [7:0] cpu_data_in, cpu_data_out,
    output wire cpu_m1_n, cpu_mreq_n, cpu_rd_n, cpu_wr_n, cpu_halt_n,
    output wire cpu_ce, nmi,
    output wire [7:0] control, sound_command,
    output wire video_reset, video_ce,
    output wire [7:0] video_red, video_green, video_blue,
    output wire video_hblank,video_vblank,video_hsync,video_vsync,video_de,
    output wire signed [15:0] audio,
    output wire pause_safe,
    input wire hs_autosave,hs_save_event,hs_upload,hs_read,
    output wire [7:0] hs_upload_data,hs_upload_index,
    output wire hs_upload_request
`ifdef INTREPID_HS_DIAG
    ,input wire diag_freeze
    ,input wire [25:0] diag_hps
    ,output wire [7:0] diag_data
`endif
);
    wire accepted,complete;
    wire [1:0] bank;
    wire [14:0] local_address;
    wire [31:0] received_crc;
    intrepid_download loader(.clk(clk),.reset(reset),.download(download),.wr(wr),.index(index),.address(address),.data(data),
        .accepted(accepted),.bank(bank),.local_address(local_address),.complete(complete),.failed(download_failed),.crc(received_crc));
    reg previous_download=0,previous_complete=0;
    wire target_start=download && !previous_download && index==0;
    reg ready=0,verifying=0,scan_valid=0;
    reg [15:0] scan_address=0;
    reg [31:0] scan_crc=32'hffffffff;
    reg verify_failed=0;
    wire [7:0] stored_data;
    wire [15:0] mapped_write_address=bank==0 ? {1'b0,local_address} : bank==1 ? 16'h5000+local_address :
        bank==2 ? 16'h6000+local_address : 16'h8000+local_address;
    wire hs_owns,hs_atomic,hs_fault,hs_busrq_n,hs_write;
    wire [12:0] hs_address;wire [7:0] hs_data,hs_ram_data;
    wire [15:0] hs_default_address;
    wire [15:0] read_address=verifying ? scan_address : hs_owns ? hs_default_address : cpu_address<16'h5000 ? cpu_address : 16'd0;
    intrepid_program_store program_rom(.clk(clk),.write_enable(accepted),.write_address(mapped_write_address),
        .write_data(data),.read_address(read_address),.read_data(stored_data));
    function automatic [31:0] crc_byte(input [31:0] prior,input [7:0] value);
        reg [31:0] c;integer i;
        begin c=prior^{24'd0,value};for(i=0;i<8;i=i+1)c=(c>>1)^(c[0]?32'hedb88320:32'd0);crc_byte=c;end
    endfunction
    // Two clocks/byte: select synchronous address, then consume its returned byte.
    always @(posedge clk) begin
        previous_download<=download;previous_complete<=complete;
        if(reset) begin
            previous_download<=0;previous_complete<=0;ready<=0;verifying<=0;scan_valid<=0;scan_address<=0;scan_crc<=32'hffffffff;verify_failed<=0;
        end else if(target_start) begin ready<=0;verifying<=0;scan_valid<=0;verify_failed<=0;end
        else if(complete && !previous_complete) begin
            verifying<=1;scan_valid<=0;scan_address<=0;scan_crc<=32'hffffffff;
        end else if(verifying) begin
            scan_valid<=!scan_valid;
            if(scan_valid) begin
                scan_crc<=crc_byte(scan_crc,stored_data);
                if(scan_address==16'h801f) begin
                    verifying<=0;ready<=crc_byte(scan_crc,stored_data)==received_crc;
                    verify_failed<=crc_byte(scan_crc,stored_data)!=received_crc;
                end else scan_address<=scan_address+1'b1;
            end
        end
    end
    assign rom_ready=ready && !verify_failed;
    wire watchdog_reset,raw_cpu_ce,event_ce,master_ce;
    wire phase_reset=reset || !rom_ready || target_start;
    wire reset_request=reset || soft_reset || !rom_ready || target_start || watchdog_reset;
    reg reset_pending=0;
    always @(posedge clk)begin
        if(reset_request && hs_atomic)reset_pending<=1;
        else if(cpu_reset)reset_pending<=0;
    end
    wire managed_reset=ENABLE_HISCORE ? ((reset_request || reset_pending) && !hs_atomic) : reset_request;
    reset_release cpu_reset_sync(.clk(clk),.request(managed_reset || (hs_fault && !hs_atomic)),.reset(cpu_reset));
    intrepid_clock_enables enables(.clk(clk),.reset(phase_reset),.master_ce(master_ce),.event_ce(event_ce),.cpu_ce(raw_cpu_ce));
    assign video_reset=phase_reset;
    wire raw_hblank,raw_vblank,raw_hsync,raw_vsync,raw_de;
    wire [12:0] video_address;
    wire [7:0] video_data;
    wire [8:0] raster_h,raster_v;
    wire raster_frame,raster_nmi;
    intrepid_raster raster(.clk(clk),.reset(phase_reset),.event_ce(event_ce),
        .h(raster_h),.v(raster_v),.hblank(raw_hblank),.vblank(raw_vblank),
        .hsync(raw_hsync),.vsync(raw_vsync),.de(raw_de),
        .red(),.green(),.blue(),
        .frame_event(raster_frame),.nmi_opportunity(raster_nmi));
    wire [12:0] tile_address;
    wire [8:0] source_h,source_v;
    wire tile_ce,tile_bank,tile_hblank,tile_vblank,tile_hsync,tile_vsync,tile_de;
    intrepid_scroll scroll(.clk(clk),.reset(phase_reset),.event_ce(event_ce),.h(raster_h),.v(raster_v),
        .flip_x(control[6]),.flip_y(control[7]),.graphics_bank(control[5]),
        .hblank(raw_hblank),.vblank(raw_vblank),.hsync(raw_hsync),.vsync(raw_vsync),.de(raw_de),
        .tile_address(tile_address),.video_data(video_data),.video_address(video_address),
        .source_h(source_h),.source_v(source_v),.out_ce(tile_ce),.out_bank(tile_bank),
        .out_hblank(tile_hblank),.out_vblank(tile_vblank),.out_hsync(tile_hsync),.out_vsync(tile_vsync),.out_de(tile_de));
    wire [7:0] background_red,background_green,background_blue;
    wire [25:0] sprite_pixel;
    wire tile_opaque;
    wire [7:0] tile_attribute;
    wire read_fire,write_fire,vblank_event;
    // Exact 0x9840..0x985f descriptor window: no attribute-RAM aliases here.
    intrepid_sprites #(.PIXEL_WIDTH(26)) sprites(.clk(clk),.reset(phase_reset),.event_ce(event_ce),.h(raster_h),.v(raster_v),
        .bank(control[5]),.global_x(control[6]),.global_y(control[7]),
        .descriptor_write(write_fire && cpu_address>=16'h9840 && cpu_address<=16'h985f),
        .descriptor_address(cpu_address[4:0]),.descriptor_data(cpu_data_out),
        .load_graphics(accepted && bank==2),.load_palette(accepted && bank==3),
        .load_address(local_address[12:0]),.load_data(data),.pixel(sprite_pixel),.busy(),.overrun());
    intrepid_composition composition(.tile_rgb({background_red,background_green,background_blue}),
        .tile_opaque(tile_opaque),.attribute(tile_attribute),.sprite_pixel(sprite_pixel),
        .de(video_de),.reset(phase_reset),.rgb({video_red,video_green,video_blue}),.preblank_rgb(),.owner());
    intrepid_background background(.clk(clk),.reset(phase_reset),.event_ce(tile_ce),.h(source_h),.v(source_v),
        .hblank(tile_hblank),.vblank(tile_vblank),.hsync(tile_hsync),.vsync(tile_vsync),.de(tile_de),.graphics_bank(tile_bank),
        .video_address(tile_address),.video_data(video_data),.load_graphics(accepted && bank==2),.load_palette(accepted && bank==3),
        .load_address(local_address[12:0]),.load_data(data),.out_ce(video_ce),.out_hblank(video_hblank),.out_vblank(video_vblank),
        .out_hsync(video_hsync),.out_vsync(video_vsync),.out_de(video_de),.red(background_red),.green(background_green),.blue(background_blue),.tile_opaque(tile_opaque),.tile_attribute(tile_attribute));
    // Stage J audio IRQ at entry to raster line 256; independent of command writes.
    wire sound_pause_safe;
    intrepid_sound sound(.clk(clk),.reset(cpu_reset),.phase_reset(phase_reset),.stall(stall),.pause_active(pause_active),
        .raster_irq(event_ce && raster_h==383 && raster_v==255 && !pause_active),.enable(control[3]),
        .command_write(write_fire && cpu_address==16'hb800),.command_data(cpu_data_out),
        .load_rom(accepted && bank==1),.load_address(local_address[11:0]),.load_data(data),.audio(audio),.pause_safe(sound_pause_safe));
    wire pause_main_cpu_ce,pause_watchdog_step;
    intrepid_pause_machine_control pause_main_control(.pause_active(pause_active),
        .raw_main_cpu_ce(raw_cpu_ce),.raw_sound_cpu_ce(1'b0),.raw_ay_ce(1'b0),.raw_raster_event_ce(event_ce),
        .raw_main_nmi_set(1'b0),.raw_sound_irq_set(1'b0),.raw_audio(16'sd0),
        .main_cpu_ce(pause_main_cpu_ce),.sound_cpu_ce(),.ay_ce(),.raster_event_ce(),.main_nmi_set(),.sound_irq_set(),
        .watchdog_step(pause_watchdog_step),.coin_step(),.gameplay_step(),.audio());
    assign cpu_ce=pause_main_cpu_ce && !stall && !cpu_reset;
    wire iorq_n,rfsh_n,busak_n;
    tv80e #(.Mode(0),.T2Write(1),.IOWait(1)) maincpu(
        .clk(clk),.reset_n(!cpu_reset),.cen(cpu_ce),.wait_n(1'b1),.int_n(1'b1),.nmi_n(!nmi),.busrq_n(hs_busrq_n),
        .di(cpu_data_in),.dout(cpu_data_out),.A(cpu_address),.m1_n(cpu_m1_n),.mreq_n(cpu_mreq_n),.iorq_n(iorq_n),
        .rd_n(cpu_rd_n),.wr_n(cpu_wr_n),.rfsh_n(rfsh_n),.halt_n(cpu_halt_n),.busak_n(busak_n));
    intrepid_main_bus #(.HISCORE(ENABLE_HISCORE)) bus(.clk(clk),.reset(cpu_reset),.phase_reset(phase_reset),.event_ce(event_ce),.pause_active(pause_active),.watchdog_step(pause_watchdog_step),.address(cpu_address),.write_data(cpu_data_out),.rom_data(stored_data),
        .mreq_n(cpu_mreq_n),.rd_n(cpu_rd_n),.wr_n(cpu_wr_n),.player1(player1),.player2(player2),.system_inputs(system_inputs),.dips(dips),
        .read_data(cpu_data_in),.control(control),.sound_command(sound_command),.nmi(nmi),.watchdog_reset(watchdog_reset),
        .read_fire(read_fire),.write_fire(write_fire),.vblank_event(vblank_event),.video_address(video_address),.video_data(video_data),
        .hs_owns(hs_owns),.hs_busak_n(busak_n),.hs_write(hs_write),.hs_address(hs_address),.hs_data(hs_data),.hs_read_data(hs_ram_data));
    wire manager_active_for_pause;
    wire main_pause_idle,sound_pause_idle,hiscore_pause_idle,boundary_safe;
    intrepid_pause_safe_boundary pause_boundary(
        .main_mreq_n(cpu_mreq_n),.main_iorq_n(iorq_n),.main_rd_n(cpu_rd_n),.main_wr_n(cpu_wr_n),
        .main_read_fire(read_fire),.main_write_fire(write_fire),
        .sound_mreq_n(sound_pause_safe),.sound_iorq_n(1'b1),.sound_rd_n(1'b1),.sound_wr_n(1'b1),
        .sound_read_fire(1'b0),.sound_write_fire(1'b0),.sound_ack_fire(1'b0),
        .sound_command_commit(1'b0),.sound_pipeline_busy(1'b0),
        .hiscore_active(manager_active_for_pause),.hiscore_atomic(hs_atomic),.hiscore_owns(hs_owns),
        .hiscore_busrq_n(hs_busrq_n),.main_busak_n(busak_n),.hiscore_ram_write(hs_write),
        .main_idle(main_pause_idle),.sound_idle(sound_pause_idle),.hiscore_idle(hiscore_pause_idle),.safe_to_pause(boundary_safe));
    assign pause_safe=boundary_safe && !raw_cpu_ce;
    generate if(ENABLE_HISCORE)begin: hiscores
        wire initialized,update_busy,changed,boot_event,captured,capture_rejected;
        wire valid,dirty,load_pending,load_ack,capture_ready,manager_active;
        wire manager_boot_event,manager_save_event,boot_pending,save_pending;
        intrepid_pause_hiscore_arbiter pause_hiscore_events(.clk(clk),.reset(managed_reset || cpu_reset),
            .block_new_hiscore(block_new_hiscore),.boot_event(boot_event),.save_event(hs_save_event),
            .manager_boot_event(manager_boot_event),.manager_save_event(manager_save_event),
            .boot_pending(boot_pending),.save_pending(save_pending));
        assign manager_active_for_pause=manager_active;
        wire capture_begin,capture_wr,capture_end,capture_stable,restore_lock;
        wire [6:0] capture_offset;wire [5:0] restore_offset;
        wire [7:0] capture_data,restore_data;
`ifdef INTREPID_HS_DIAG
        wire [31:0] diag_witness,diag_manager,diag_transport;
        wire [71:0] diag_validation;
        intrepid_hiscore_diagnostic diagnostic(.clk(clk),.freeze(diag_freeze),
            .rom_crc(received_crc),.rom_ready(rom_ready),.cpu_reset(cpu_reset),
            .witness(diag_witness),.manager(diag_manager),.transport(diag_transport),.validation(diag_validation),
            .read_fire(read_fire),.write_fire(write_fire),.cpu_address(cpu_address),.cpu_in(cpu_data_in),.cpu_out(cpu_data_out),
            .save_event(hs_save_event),.autosave(hs_autosave),.busrq_n(hs_busrq_n),.busak_n(busak_n),.fault(hs_fault),
            .capture_begin(capture_begin),.capture_wr(capture_wr),.capture_end(capture_end),.capture_stable(capture_stable),
            .capture_offset(capture_offset),.capture_data(capture_data),
            .upload(hs_upload),.download(download),.ioctl_index(index),.ioctl_addr(address),.ioctl_rd(hs_read),
            .upload_request(hs_upload_request),.hps(diag_hps),.data(diag_data));
`endif
        intrepid_hiscore_witness witness(.clk(clk),.reset(managed_reset || cpu_reset),
`ifdef INTREPID_HS_DIAG
            .diag(diag_witness),
`endif
            .parent_ok(rom_ready && received_crc==32'h19047566),
            .read_fire(read_fire),.write_fire(write_fire),.m1_n(cpu_m1_n),
            .address(cpu_address),.read_data(cpu_data_in),.write_data(cpu_data_out),
            .boot_event(boot_event),.initialized(initialized),.update_busy(update_busy),.changed(changed),.captured(captured),.capture_rejected(capture_rejected));
        // Host reception and game reset are separate lifecycles. Main's normal
        // NVRAM load is physically delivered while launch soft reset is high,
        // so soft reset holds validation/publication but must not discard a
        // complete index-4 transaction. True core/ROM/watchdog boundaries still
        // abort unfinished staging. FPGA reconfiguration clears valid by its
        // explicit LOW power-up assignment.
        wire transport_reset=(reset || watchdog_reset || target_start || reset_pending) && !hs_atomic;
        wire transport_validation_hold=soft_reset || !rom_ready;
        intrepid_hiscore_transport transport(.clk(clk),.reset(transport_reset),.validation_hold(transport_validation_hold),.autosave(hs_autosave),.save_event(hs_save_event && initialized && !update_busy && !changed && !manager_active),
`ifdef INTREPID_HS_DIAG
            .diag(diag_transport),.diag_validation(diag_validation),
`endif
            .ioctl_download(download),.ioctl_upload(hs_upload),.ioctl_wr(wr),.ioctl_rd(hs_read),.ioctl_index(index),.ioctl_addr(address),.ioctl_dout(data),
            .ioctl_din(hs_upload_data),.ioctl_upload_req(hs_upload_request),.ioctl_upload_index(hs_upload_index),
            .capture_begin(capture_begin),.capture_wr(capture_wr),.capture_end(capture_end),.capture_stable(capture_stable),
            .capture_offset(capture_offset),.capture_data(capture_data),.capture_ready(capture_ready),
            .restore_lock(restore_lock),.load_ack(load_ack),.restore_offset(restore_offset),.restore_data(restore_data),
            .load_pending(load_pending),.valid(valid),.dirty(dirty),.load_accepted(),.load_rejected(),.capture_accepted(),.capture_rejected(capture_rejected),.upload_complete(),.busy());
        intrepid_hiscore_manager manager(.clk(clk),.reset_request(reset_request || reset_pending),
`ifdef INTREPID_HS_DIAG
            .diag(diag_manager),
`endif
            .boot_event(manager_boot_event),.initialized(initialized),.update_busy(update_busy),.changed(changed),.save_event(manager_save_event),
            .snapshot_valid(valid),.capture_ready(capture_ready),.load_pending(load_pending),
            .busak_n(busak_n),.rd_n(cpu_rd_n),.wr_n(cpu_wr_n),.iorq_n(iorq_n),.read_fire(read_fire),.write_fire(write_fire),
            .ram_data(hs_ram_data),.default_data(stored_data),.snapshot_data(restore_data),
            .busrq_n(hs_busrq_n),.owns(hs_owns),.atomic(hs_atomic),.ram_address(hs_address),.default_address(hs_default_address),
            .ram_write(hs_write),.ram_write_data(hs_data),.restore_lock(restore_lock),.restore_offset(restore_offset),
            .capture_begin(capture_begin),.capture_wr(capture_wr),.capture_end(capture_end),.capture_stable(capture_stable),
            .capture_offset(capture_offset),.capture_data(capture_data),.load_ack(load_ack),.captured(captured),.restored(),.fault(hs_fault),
            .last_grant_clocks(),.last_transaction_clocks(),.active(manager_active));
    end else begin: no_hiscores
`ifdef INTREPID_HS_DIAG
        assign diag_data=0;
`endif
        assign hs_owns=0;assign hs_atomic=0;assign hs_fault=0;assign hs_busrq_n=1;assign hs_write=0;assign manager_active_for_pause=0;
        assign hs_address=0;assign hs_data=0;assign hs_default_address=0;
        assign hs_upload_data=0;assign hs_upload_index=0;assign hs_upload_request=0;
    end endgenerate
endmodule
