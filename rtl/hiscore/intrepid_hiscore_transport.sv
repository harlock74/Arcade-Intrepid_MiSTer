// Production high-score transport; included by files.qip and instantiated when ENABLE_HISCORE is enabled.
// Two 64-byte banks: receive/capture inactive bank, validate, then atomic swap.
// reset cancels unfinished staging; retains a published bank and in-flight upload.
module intrepid_hiscore_transport(
 input wire clk, reset, validation_hold, autosave, save_event,
 input wire ioctl_download, ioctl_upload, ioctl_wr, ioctl_rd,
 input wire [15:0] ioctl_index,
 input wire [26:0] ioctl_addr,
 input wire [7:0] ioctl_dout,
 output wire [7:0] ioctl_din,
 output reg ioctl_upload_req=0,
 output wire [7:0] ioctl_upload_index,
 input wire capture_begin, capture_wr, capture_end, capture_stable,
 input wire [6:0] capture_offset,
 input wire [7:0] capture_data,
 output wire capture_ready,
 input wire restore_lock, load_ack,
 input wire [5:0] restore_offset,
 output wire [7:0] restore_data,
 output reg load_pending=0,
 // Quartus 17 with ALLOW_POWER_UP_DONT_CARE may otherwise fold this set-only
 // published-state flag to VCC. Keep the override local: soft reset must retain
 // a published bank, so adding a reset assignment would change the contract.
 (* altera_attribute = "-name POWER_UP_LEVEL LOW" *) output reg valid=0,
 output reg dirty=0,
 output reg load_accepted=0, load_rejected=0, capture_accepted=0, capture_rejected=0,
 output reg upload_complete=0,
 output wire busy
`ifdef INTREPID_HS_DIAG
 ,output wire [31:0] diag
 ,output wire [71:0] diag_validation
`endif
);
 localparam [3:0] IDLE=0, LOAD=1, CAPTURE=2, VADDR=3, VCHECK=4, PUBLISH=5, DRAIN=6, COMPLETE=7;
 localparam [6:0] PAYLOAD=7'd63;
 reg [3:0] state=IDLE;
 reg active_bank=0, from_load=0, bad=0, changed=0;
 reg [6:0] count=0, pos=0;
 reg [2:0] field=0;
 reg [23:0] score=0, previous_score=24'hffffff;
 reg prev_download=0, prev_upload=0, upload_session=0, upload_bad=0;
 reg [6:0] upload_count=0;
 reg request_pending=0, upload_prefetch_seen=0;
 wire target=ioctl_index==16'd4;
 wire start_load=ioctl_download && !prev_download && target;
 wire uploading=ioctl_upload && target;
 assign ioctl_upload_index=8'd4;
 assign busy=state!=IDLE;
 assign capture_ready=state==IDLE && !reset && !validation_hold && !ioctl_download && !ioctl_upload && !restore_lock && !load_pending;
 // Port A: inactive staging writes/validation, or locked active restore reads.
 // Port B: active immutable HPS upload, otherwise comparison during validation.
 (* ramstyle="M10K" *) reg [7:0] banks[0:127];
 reg [7:0] aq=0,bq=0;
 wire validate_read=(state==VADDR || state==VCHECK) && !restore_lock;
 wire [6:0] aa=validate_read ? {~active_bank,pos[5:0]} : {active_bank,restore_offset};
 wire [6:0] ba={active_bank,uploading ? ioctl_addr[5:0] : pos[5:0]};
 wire load_write=state==LOAD && ioctl_download && target && ioctl_wr && !bad && count<PAYLOAD && ioctl_addr=={20'd0,count};
 wire cap_write=state==CAPTURE && capture_wr && !bad && count<PAYLOAD && capture_offset==count;
 wire stage_write=!reset && !restore_lock && (load_write || cap_write);
 wire [6:0] wa={~active_bank,count[5:0]};
 // One explicit address per physical port permits Quartus TDP inference.
 wire [6:0] port_a_address=stage_write ? wa : aa;
 always @(posedge clk) begin
  if(stage_write) begin banks[port_a_address]<=load_write ? ioctl_dout : capture_data; aq<=load_write ? ioctl_dout : capture_data;end
  else aq<=banks[port_a_address];
 end
 always @(posedge clk) bq<=banks[ba];
 assign ioctl_din=valid && uploading && ioctl_addr<{20'd0,PAYLOAD} ? bq : 8'd0;
 assign restore_data=valid && {1'b0,restore_offset}<PAYLOAD ? aq : 8'd0;
 wire bcd_ok=aq[7:4]<=9 && aq[3:0]<=9;
 wire name_ok=aq<=8'h24 || aq==8'hfd;
 wire [23:0] full_score={aq,score[15:0]};
`ifdef INTREPID_HS_DIAG
 // Observation only: these outputs do not participate in any decision.
 assign diag={upload_count,upload_bad,upload_prefetch_seen,request_pending,
  from_load,changed,bad,active_bank,load_pending,dirty,valid,
  capture_accepted,capture_rejected,load_accepted,load_rejected,upload_complete,
  capture_ready,restore_lock,4'd0,state};
 assign diag_validation={4'd0,previous_score,full_score,field,pos,aq,2'd0};
`endif
 always @(posedge clk) begin
  prev_download<=ioctl_download;prev_upload<=ioctl_upload;
  ioctl_upload_req<=0;load_accepted<=0;load_rejected<=0;
  capture_accepted<=0;capture_rejected<=0;upload_complete<=0;
  if(load_ack) load_pending<=0;
  // hps_io emits an initial rd at address 0 to prefetch, then delivered-byte
  // strobes at addresses 1..63. Neither the prefetch nor a partial upload is ack.
  if(uploading && !prev_upload) begin upload_session<=1;upload_count<=0;upload_bad<=!valid;upload_prefetch_seen<=0;request_pending<=0;end
  if(upload_session && ioctl_upload && !target) upload_bad<=1;
  if(upload_session && uploading && ioctl_rd) begin
   if(ioctl_addr==0 && upload_count==0 && !upload_prefetch_seen) upload_prefetch_seen<=1;
   else if(ioctl_addr=={20'd0,upload_count}+27'd1 && upload_count<PAYLOAD) upload_count<=upload_count+1'b1;
   else upload_bad<=1;
  end
  if(upload_session && !ioctl_upload) begin
   upload_session<=0;
   if(!upload_bad && upload_count==PAYLOAD) begin upload_complete<=1;dirty<=0;end
  end
  // reset deliberately does not mutate the published bank or erase a host
  // request already latched in hps_io. Ongoing uploads can drain coherently.
  if(reset) begin
   state<=ioctl_download ? DRAIN : IDLE;count<=0;pos<=0;bad<=0;load_pending<=0;
  end else begin
   if(capture_begin && !capture_ready) capture_rejected<=1;
   // No queue/overwrite of the staging bank while another operation owns it.
   if(start_load && state!=IDLE && state!=COMPLETE) load_rejected<=1;
   case(state)
    IDLE: begin
     if(start_load) begin state<=LOAD;from_load<=1;bad<=0;count<=0;load_pending<=0;end
     else if(capture_begin && capture_ready) begin state<=CAPTURE;from_load<=0;bad<=!capture_stable;count<=0;end
     else if(save_event && autosave && dirty && valid && !request_pending && !ioctl_upload && !ioctl_download) begin ioctl_upload_req<=1;request_pending<=1;end
    end
    LOAD: begin
     if(ioctl_download && !target) bad<=1;
     if(ioctl_download && ioctl_wr) begin
      if(restore_lock || !target || count>=PAYLOAD || ioctl_addr!={20'd0,count}) bad<=1;
      else count<=count+1'b1;
     end
     if(!ioctl_download) begin
      if(bad || count!=PAYLOAD) begin load_rejected<=1;state<=IDLE;end
      else begin
       // Main may finish the ordinary filesystem load while game soft reset
       // still holds the machine. Preserve the complete inactive bank, but do
       // not validate or publish it until ROM identity and launch reset are
       // released. A hard transport reset above still discards this state.
       state<=validation_hold ? COMPLETE : VADDR;
       pos<=0;field<=0;score<=0;previous_score<=24'hffffff;changed<=!valid;
      end
     end
    end
    COMPLETE: begin
     // A later index-4 load supersedes the waiting image. Other indices remain
     // isolated; a true ROM/reconfiguration boundary is handled by reset.
     if(start_load)begin state<=LOAD;from_load<=1;bad<=0;count<=0;load_pending<=0;end
     else if(!validation_hold)begin
      state<=VADDR;pos<=0;field<=0;score<=0;previous_score<=24'hffffff;changed<=!valid;
     end
    end
    CAPTURE: begin
     if(!capture_stable) bad<=1;
     if(capture_wr) begin
      if(restore_lock || count>=PAYLOAD || capture_offset!=count) bad<=1;else count<=count+1'b1;
     end
     if(capture_end) begin
      // end must be a separate cycle following the final write.
      if(bad || count!=PAYLOAD || !capture_stable || capture_wr) begin capture_rejected<=1;state<=IDLE;end
      else begin state<=VADDR;pos<=0;field<=0;score<=0;previous_score<=24'hffffff;changed<=!valid;end
     end
    end
    VADDR: if(validation_hold)begin state<=COMPLETE;pos<=0;field<=0;score<=0;previous_score<=24'hffffff;end
     else if(!ioctl_upload && !restore_lock) state<=VCHECK;
    VCHECK: begin
     if(validation_hold)begin state<=COMPLETE;pos<=0;field<=0;score<=0;previous_score<=24'hffffff;end
     else if(ioctl_upload || restore_lock) state<=VADDR;
     else begin
      if(aq!=bq) changed<=1;
      if((pos>=60 ? bcd_ok : field<3 ? bcd_ok : name_ok) !== 1'b1) bad<=1;
      if(pos<60) begin
       if(field==0) score[7:0]<=aq;
       if(field==1) score[15:8]<=aq;
       if(field==2) begin
        if(full_score==0 || full_score>previous_score) bad<=1;
        previous_score<=full_score;
       end
       field<=field==5 ? 0 : field+1'b1;
      end
      if(pos==PAYLOAD-7'd1) state<=PUBLISH;else begin pos<=pos+1'b1;state<=VADDR;end
     end
    end
    PUBLISH: begin
     if(validation_hold)begin state<=COMPLETE;pos<=0;field<=0;score<=0;previous_score<=24'hffffff;end
     else if(bad) begin if(from_load)load_rejected<=1;else capture_rejected<=1;state<=IDLE;end
     else if(!ioctl_upload && !restore_lock) begin
      active_bank<=~active_bank;valid<=1;state<=IDLE;
      if(from_load) begin load_pending<=1;load_accepted<=1;dirty<=0;end
      else begin
       capture_accepted<=1;dirty<=dirty || changed;
       if(autosave && (dirty || changed) && !request_pending && !ioctl_download) begin ioctl_upload_req<=1;request_pending<=1;end
      end
     end
    end
    DRAIN: if(!ioctl_download) state<=IDLE;
    default: state<=IDLE;
   endcase
  end
 end
endmodule
