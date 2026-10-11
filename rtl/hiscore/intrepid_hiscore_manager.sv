// CPU port-A supervisor. Only a verified BUSAK + idle side-effect boundary
// grants ownership. Capture is read-only; restore is write + full readback.
module intrepid_hiscore_manager(
 input wire clk,reset_request,boot_event,initialized,update_busy,changed,save_event,
 input wire snapshot_valid,capture_ready,load_pending,
 input wire busak_n,rd_n,wr_n,iorq_n,read_fire,write_fire,
 input wire [7:0] ram_data,default_data,snapshot_data,
 output wire busrq_n,owns,atomic,
 output wire [12:0] ram_address,output wire [15:0] default_address,
 output wire ram_write,output wire [7:0] ram_write_data,
 output wire restore_lock,output wire [5:0] restore_offset,
 output wire capture_begin,capture_wr,capture_end,capture_stable,
 output wire [6:0] capture_offset,output wire [7:0] capture_data,
 output reg load_ack=0,captured=0,restored=0,fault=0,
 output reg [15:0] last_grant_clocks=0,last_transaction_clocks=0,
 output wire active
`ifdef INTREPID_HS_DIAG
 ,output wire [31:0] diag
`endif
);
 localparam [4:0] IDLE=0,REQUEST=1,SETTLE=2,CHECK_ADDR=3,CHECK_DATA=4,
  WRITE_ADDR=5,WRITE_BYTE=6,VERIFY_ADDR=7,VERIFY_DATA=8,
  CAP_BEGIN=9,CAP_ADDR=10,CAP_DATA=11,CAP_END=12,
  PREFILL=13,RELEASE=14,FAULT=15;
 reg [4:0] state=IDLE;
 reg restoring=0,spent=0,mismatch=0,save_pending=0;
 reg [6:0] pos=0;
 reg [2:0] idle_count=0;
 reg [15:0] grant_clocks=0,transaction_clocks=0;
`ifdef INTREPID_HS_DIAG
 assign diag={grant_clocks,pos,restoring,spent,mismatch,save_pending,state};
`endif
 wire mapped;wire [15:0] cpu_map;
 intrepid_hiscore_map mapping(.offset(pos),.valid(mapped),.cpu_address(cpu_map),.ram_address(ram_address));
 // Independent guard at the point of each access, not just mapper.valid.
 wire allowed=mapped && ((ram_address>=13'h03d && ram_address<=13'h078) || (ram_address>=13'h035 && ram_address<=13'h037));
 assign default_address=16'h1399+{9'd0,pos};
 assign atomic=state==WRITE_ADDR || state==WRITE_BYTE || state==VERIFY_ADDR || state==VERIFY_DATA;
 assign owns=state>=CHECK_ADDR && state<=CAP_END;
 assign busrq_n=!(state!=IDLE && state!=RELEASE && state!=FAULT);
 assign active=state!=IDLE;
 assign ram_write=state==WRITE_BYTE && allowed && !busak_n;
 assign ram_write_data=snapshot_data;
 assign restore_lock=restoring && state!=IDLE;
 assign restore_offset=pos[5:0];
 assign capture_begin=state==CAP_BEGIN && capture_ready && capture_stable;
 assign capture_wr=state==CAP_DATA && !reset_request && allowed && !busak_n;
 assign capture_end=state==CAP_END && !reset_request;
 assign capture_stable=!update_busy && initialized && !reset_request;
 assign capture_offset=pos;
 assign capture_data=ram_data;
 wire quiet=!busak_n && rd_n && wr_n && iorq_n && !read_fire && !write_fire;
 always @(posedge clk)begin
  load_ack<=0;captured<=0;restored<=0;
  if(reset_request && !atomic)begin
   state<=IDLE;restoring<=0;spent<=0;pos<=0;idle_count<=0;mismatch<=0;fault<=0;save_pending<=0;
  end else begin
   if(save_event && initialized)save_pending<=1;
   if(state==REQUEST || state==SETTLE)grant_clocks<=grant_clocks+1'b1;
   if(owns)transaction_clocks<=transaction_clocks+1'b1;
   case(state)
    IDLE:begin
     idle_count<=0;pos<=0;transaction_clocks<=0;grant_clocks<=0;mismatch<=0;
     if(boot_event && !spent)begin
      spent<=1;
      if(snapshot_valid)begin restoring<=1;state<=REQUEST;end
      else load_ack<=load_pending;
     end else if(initialized)begin
      // A late receipt is acknowledged without a live restore. Published
      // bytes remain available for the next reset epoch.
      if(load_pending)load_ack<=1;
      if((save_event || save_pending) && !update_busy && capture_ready)begin
       if(changed)begin restoring<=0;state<=REQUEST;end
       else save_pending<=0;
      end
     end
    end
    REQUEST:begin
     if(quiet)begin state<=SETTLE;idle_count<=0;end
     else if(grant_clocks==16'd4095)begin fault<=1;state<=FAULT;end
    end
    SETTLE:begin
     if(!quiet)begin state<=REQUEST;idle_count<=0;end
     else if(idle_count==2)begin
      last_grant_clocks<=grant_clocks+1'b1;
      state<=restoring ? CHECK_ADDR : CAP_BEGIN;
     end else idle_count<=idle_count+1'b1;
    end
    CHECK_ADDR:begin
     if(!allowed || !quiet || !snapshot_valid)begin fault<=1;state<=PREFILL;idle_count<=0;end
     else state<=CHECK_DATA;
    end
    CHECK_DATA:begin
     if((pos<60 && ram_data!==default_data) || (pos>=60 && ram_data!==8'd0))begin fault<=1;state<=PREFILL;idle_count<=0;end
     else if(pos==62)begin pos<=0;state<=WRITE_ADDR;end
     else begin pos<=pos+1'b1;state<=CHECK_ADDR;end
    end
    WRITE_ADDR:state<=WRITE_BYTE;
    WRITE_BYTE:begin
     if(!allowed || busak_n)begin mismatch<=1;fault<=1;end
     if(pos==62)begin pos<=0;state<=VERIFY_ADDR;end
     else begin pos<=pos+1'b1;state<=WRITE_ADDR;end
    end
    VERIFY_ADDR:state<=VERIFY_DATA;
    VERIFY_DATA:begin
     if(!allowed || busak_n || ram_data!==snapshot_data)begin mismatch<=1;fault<=1;end
     if(pos==62)begin
      restored<=!mismatch && allowed && !busak_n && ram_data===snapshot_data;
      load_ack<=1;state<=PREFILL;idle_count<=0;
     end else begin pos<=pos+1'b1;state<=VERIFY_ADDR;end
    end
    CAP_BEGIN:begin
     pos<=0;
     // A host transfer or score routine may start while BUSRQ is pending.
     // Reserve transport only after the CPU is quiet and recheck readiness.
     if(capture_ready && capture_stable)begin state<=CAP_ADDR;save_pending<=0;end
     else begin state<=PREFILL;idle_count<=0;end
    end
    CAP_ADDR:begin
     if(!allowed || !quiet || update_busy)begin fault<=1;state<=PREFILL;idle_count<=0;end
     else state<=CAP_DATA;
    end
    CAP_DATA:begin
     if(pos==62)state<=CAP_END;
     else begin pos<=pos+1'b1;state<=CAP_ADDR;end
    end
    CAP_END:begin captured<=1;state<=PREFILL;idle_count<=0;end
    PREFILL:begin
     last_transaction_clocks<=transaction_clocks;
     // Port A and ROM read selection return to CPU while BUSRQ stays held.
     if(idle_count==2)state<=RELEASE;else idle_count<=idle_count+1'b1;
    end
    RELEASE:if(busak_n)begin state<=fault ? FAULT : IDLE;restoring<=0;end
    FAULT:begin end // Fail closed until a real reset request, never force a save.
    default:begin fault<=1;state<=FAULT;end
   endcase
  end
 end
endmodule
