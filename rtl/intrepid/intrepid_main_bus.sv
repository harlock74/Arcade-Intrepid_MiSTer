module intrepid_main_bus #(
    parameter WATCHDOG_CYCLES=60000000, parameter HISCORE=0
)(
    input wire clk, reset, phase_reset, event_ce, pause_active, watchdog_step,
    input wire [15:0] address,
    input wire [7:0] write_data, rom_data,
    input wire mreq_n, rd_n, wr_n,
    input wire [7:0] player1, player2, system_inputs, dips,
    output wire [7:0] read_data,
    output reg [7:0] control=0,
    output reg [7:0] sound_command=0,
    output reg nmi=0,
    output reg watchdog_reset=0,
    output wire read_fire, write_fire, vblank_event,
    input wire [12:0] video_address,
    output wire [7:0] video_data,
    input wire hs_owns,hs_busak_n,hs_write,
    input wire [12:0] hs_address,input wire [7:0] hs_data,
    output wire [7:0] hs_read_data
);
    wire rom_sel,ram_sel,controls_sel,system_sel,dip_sel,latch_sel,watchdog_sel;
    wire [12:0] ram_addr;
    intrepid_main_decode decode(address,rom_sel,ram_sel,ram_addr,controls_sel,system_sel,dip_sel,latch_sel,watchdog_sel);
    wire manager_owner=HISCORE && hs_owns;
    wire memory_read=!manager_owner && !mreq_n && !rd_n;
    wire memory_write=!manager_owner && !mreq_n && !wr_n;
    reg read_seen=0,write_seen=0;
    assign read_fire=!reset && memory_read && !read_seen;
    assign write_fire=!reset && memory_write && !write_seen;
    wire [7:0] ram_data;
    // Independent physical allowlist immediately before the actual RAM port.
    wire hs_allowed=(hs_address>=13'h03d && hs_address<=13'h078) || (hs_address>=13'h035 && hs_address<=13'h037);
    wire take=manager_owner && !hs_busak_n && hs_allowed;
    assign hs_read_data=ram_data;
    intrepid_main_ram ram(.clk(clk),.write_enable(take ? hs_write : write_fire && ram_sel),.address(take ? hs_address : ram_addr),.write_data(take ? hs_data : write_data),.read_data(ram_data),.video_address(video_address),.video_data(video_data));
    assign read_data=!memory_read ? 8'd0 : rom_sel ? rom_data : ram_sel ? ram_data :
        controls_sel ? (control[6] ? player2 : player1) : system_sel ? system_inputs : dip_sel ? dips : 8'd0;
    // Only the phase needed by main NMI: 384*264 events/frame, VBLANK at 240*384.
    // No pixel coordinates or raster/video outputs are implemented.
    reg [16:0] frame_phase=0;
    assign vblank_event=!reset && event_ce && frame_phase==17'd92159;
    // Soft CPU/watchdog reset must not restart the free-running frame phase.
    always @(posedge clk) begin
        if(phase_reset) frame_phase<=0;
        else if(event_ce) frame_phase<=frame_phase==17'd101375 ? 17'd0 : frame_phase+1'b1;
    end
    reg watchdog_armed=0;
    reg [25:0] watchdog_count=0;
    always @(posedge clk) begin
        watchdog_reset<=0;
        if(reset) begin
            control<=0;nmi<=0;read_seen<=0;write_seen<=0;
            watchdog_armed<=0;watchdog_count<=0;
            // MAME sound latch reset preserves its stored value.
        end else begin
            read_seen<=memory_read;write_seen<=memory_write;
            if(vblank_event && control[0] && !pause_active) nmi<=1;
            if(write_fire && latch_sel) begin
                control[address[2:0]]<=write_data[0];
                if(address[2:0]==0 && !write_data[0]) nmi<=0;
            end
            if(write_fire && watchdog_sel) sound_command<=write_data;
            if(read_fire && watchdog_sel) begin watchdog_armed<=1;watchdog_count<=0;end
            else if(watchdog_armed && watchdog_step) begin
                if(watchdog_count==WATCHDOG_CYCLES-1) begin
                    watchdog_reset<=1;watchdog_armed<=0;watchdog_count<=0;
                end else watchdog_count<=watchdog_count+1'b1;
            end
        end
    end
endmodule
