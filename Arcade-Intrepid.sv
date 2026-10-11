//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

// Adapted from pinned Template_MiSTer; see contracts/stage_c_imports.json.
module emu (
    `include "sys/emu_ports.vh"
);
assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
// Standard pinned framebuffer rotator owns DDR writes below.

assign VGA_SL = 0;
assign VGA_F1 = 0;
wire direct_video, no_rotate, video_rotated;
wire [15:0] menu_mask;
wire [31:0] joystick_0,joystick_1;
wire [10:0] ps2_key;
wire [7:0] player1,player2,system_inputs,dips;
wire pause_button,gameplay_controls_released,pause_safe,pause_requested,pause_active,pause_quarantine;
wire block_game_inputs,block_new_hiscore;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

assign AUDIO_S = 1;
wire signed [15:0] game_audio;
assign AUDIO_L = game_audio;
assign AUDIO_R = game_audio;
assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;


wire clk_sys, pll_locked;
wire [35:0] unused_extension;
wire [21:0] unused_gamma;
assign unused_extension[32] = 1'b0;
assign unused_extension[15:0] = 16'd0;
assign unused_gamma[21] = 1'b0;
wire [127:0] status;
wire [1:0] buttons;
wire download, download_wr;
wire [15:0] download_index;
wire [26:0] download_address;
wire [7:0] download_data;
wire core_reset;
wire hs_upload,hs_read,hs_upload_request;wire [7:0] hs_upload_data,hs_upload_index;
`ifdef INTREPID_HS_DIAG
wire [7:0] diag_data;
wire [25:0] diag_hps;
wire [7:0] upload_mux=download_index==16'd5 ? diag_data : hs_upload_data;
`else
wire [7:0] upload_mux=hs_upload_data;
`endif
reg hs_osd_last=0;always @(posedge clk_sys)hs_osd_last<=OSD_STATUS;
wire [31:0] unused_sd_lba [1];
wire [5:0] unused_sd_count [1];
wire [7:0] unused_sd_data [1];
assign unused_sd_lba[0] = 32'd0;
assign unused_sd_count[0] = 6'd0;
assign unused_sd_data[0] = 8'd0;
wire rom_ready, download_failed, cpu_reset;
wire [15:0] cpu_address;
wire [7:0] cpu_data_in,cpu_data_out,control,sound_command;
wire video_reset,video_ce,video_hblank,video_vblank,video_hsync,video_vsync,video_de;
wire [7:0] video_red,video_green,video_blue;
wire cpu_m1_n,cpu_mreq_n,cpu_rd_n,cpu_wr_n,cpu_halt_n,cpu_ce,nmi;
`include "build_id.v"
`include "rtl/intrepid/intrepid_menu.vh"
hps_io #(.CONF_STR(CONF_STR),.WIDE(0)) hps_io (
    .clk_sys(clk_sys),.HPS_BUS(HPS_BUS),.EXT_BUS(unused_extension),.gamma_bus(unused_gamma),
    .status(status),.buttons(buttons),.status_menumask(menu_mask),
    .joystick_0(joystick_0),.joystick_1(joystick_1),.ps2_key(ps2_key),.direct_video(direct_video),
    .ioctl_download(download),.ioctl_wr(download_wr),.ioctl_index(download_index),
    .ioctl_addr(download_address),.ioctl_dout(download_data),
    .ioctl_wait(1'b0),.ioctl_din(upload_mux),.ioctl_upload_req(hs_upload_request),.ioctl_upload_index(hs_upload_index),
`ifdef INTREPID_HS_DIAG
    .diag_hps(diag_hps),
`endif
    .ioctl_upload(hs_upload),.ioctl_rd(hs_read),
    .status_in(128'd0),.status_set(1'b0),.info_req(1'b0),.info(8'd0),
    .video_rotated(video_rotated),.new_vmode(1'b0),
    .sd_lba(unused_sd_lba),.sd_blk_cnt(unused_sd_count),.sd_buff_din(unused_sd_data),
    .sd_rd(1'b0),.sd_wr(1'b0),
    .joystick_0_rumble(16'd0),.joystick_1_rumble(16'd0),.joystick_2_rumble(16'd0),
    .joystick_3_rumble(16'd0),.joystick_4_rumble(16'd0),.joystick_5_rumble(16'd0),
    .ps2_kbd_clk_in(1'b1),.ps2_kbd_data_in(1'b1),.ps2_mouse_clk_in(1'b1),.ps2_mouse_data_in(1'b1),
    .ps2_kbd_led_status(3'd0),.ps2_kbd_led_use(3'd0)
);
pll pll(.refclk(CLK_50M),.rst(1'b0),.outclk_0(clk_sys),.locked(pll_locked));
reset_release reset_sync(.clk(clk_sys),.request(RESET | !pll_locked),.reset(core_reset));
intrepid_machine #(.ENABLE_HISCORE(1)) game(.clk(clk_sys),.reset(core_reset),.soft_reset(status[0] | buttons[1]),.stall(1'b0),
    .pause_active(pause_active),.block_new_hiscore(block_new_hiscore),.pause_safe(pause_safe),
    .download(download),.wr(download_wr),.index(download_index),.address(download_address),.data(download_data),
    .player1(player1),.player2(player2),.system_inputs(system_inputs),.dips(dips),
    .hs_autosave(status[16]),.hs_save_event(OSD_STATUS && !hs_osd_last),.hs_upload(hs_upload),.hs_read(hs_read),
`ifdef INTREPID_HS_DIAG
    .diag_freeze(status[17]),.diag_hps(diag_hps),.diag_data(diag_data),
`endif
    .hs_upload_data(hs_upload_data),.hs_upload_index(hs_upload_index),.hs_upload_request(hs_upload_request),
    .rom_ready(rom_ready),.download_failed(download_failed),.cpu_reset(cpu_reset),
    .cpu_address(cpu_address),.cpu_data_in(cpu_data_in),.cpu_data_out(cpu_data_out),
    .cpu_m1_n(cpu_m1_n),.cpu_mreq_n(cpu_mreq_n),.cpu_rd_n(cpu_rd_n),.cpu_wr_n(cpu_wr_n),.cpu_halt_n(cpu_halt_n),
    .cpu_ce(cpu_ce),.nmi(nmi),.control(control),.sound_command(sound_command),
    .video_reset(video_reset),.video_ce(video_ce),.video_red(video_red),.video_green(video_green),.video_blue(video_blue),
    .video_hblank(video_hblank),.video_vblank(video_vblank),.video_hsync(video_hsync),.video_vsync(video_vsync),.video_de(video_de),.audio(game_audio));
intrepid_pause_controller pause_controller(.clk(clk_sys),.reset(core_reset || cpu_reset),.enabled(status[18]),
    .pause_button(pause_button),.safe_to_pause(pause_safe),.gameplay_controls_released(gameplay_controls_released),
    .pause_requested(pause_requested),.pause_active(pause_active),.quarantine(pause_quarantine),
    .block_game_inputs(block_game_inputs),.block_new_hiscore(block_new_hiscore));
// Platform/ROM readiness only, not a game-running or hardware-validation claim.
assign LED_USER = download_failed | (rom_ready && !cpu_reset);
assign CLK_VIDEO = clk_sys;
intrepid_video native_video(.clk(clk_sys),.reset(video_reset),.event_ce(video_ce),
    .red(video_red),.green(video_green),.blue(video_blue),
    .hblank(video_hblank),.vblank(video_vblank),.hsync(video_hsync),.vsync(video_vsync),.de(video_de),
    .ce_pixel(CE_PIXEL),.vga_r(VGA_R),.vga_g(VGA_G),.vga_b(VGA_B),.vga_hs(VGA_HS),.vga_vs(VGA_VS),.vga_de(VGA_DE));
intrepid_inputs inputs(.clk(clk_sys),.reset(core_reset),.joystick_0(joystick_0),.joystick_1(joystick_1),
    .ps2_key(ps2_key),.status(status),.block_game_inputs(block_game_inputs),.coin_step(!block_game_inputs),
    .pause_button(pause_button),.gameplay_controls_released(gameplay_controls_released),
    .player1(player1),.player2(player2),.system_inputs(system_inputs),.dips(dips));
intrepid_presentation presentation(.status(status),.direct_video(direct_video),.no_rotate(no_rotate),
    .vga_scaler(VGA_SCALER),.arx(VIDEO_ARX),.ary(VIDEO_ARY),.menu_mask(menu_mask));
// ROT90 = clockwise: output (x,y)=(native_height-1-native_y,native_x).
// Input comes from the accepted native cleaner, not a replacement game renderer.
assign FB_FORCE_BLANK=1'b0;
screen_rotate rotation(.CLK_VIDEO(CLK_VIDEO),.CE_PIXEL(CE_PIXEL),
    .VGA_R(VGA_R),.VGA_G(VGA_G),.VGA_B(VGA_B),.VGA_HS(VGA_HS),.VGA_VS(VGA_VS),.VGA_DE(VGA_DE),
    .rotate_ccw(1'b0),.no_rotate(no_rotate),.flip(1'b0),.video_rotated(video_rotated),
    .FB_EN(FB_EN),.FB_FORMAT(FB_FORMAT),.FB_WIDTH(FB_WIDTH),.FB_HEIGHT(FB_HEIGHT),
    .FB_BASE(FB_BASE),.FB_STRIDE(FB_STRIDE),.FB_VBL(FB_VBL),.FB_LL(FB_LL),
    .DDRAM_CLK(DDRAM_CLK),.DDRAM_BUSY(DDRAM_BUSY),.DDRAM_BURSTCNT(DDRAM_BURSTCNT),
    .DDRAM_ADDR(DDRAM_ADDR),.DDRAM_DIN(DDRAM_DIN),.DDRAM_BE(DDRAM_BE),.DDRAM_WE(DDRAM_WE),.DDRAM_RD(DDRAM_RD));
endmodule
