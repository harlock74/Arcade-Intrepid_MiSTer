// Intrepid sound-side map, command latch, raster IRQ and two owned AY8910s.
// MAME provenance and collision choices: validation/stage_j/ARCHITECTURE.md.
module intrepid_sound_bus(
    input wire clk, reset, ay_ce, raster_irq,
    input wire command_write,
    input wire [7:0] command_data,
    input wire load_rom,
    input wire [11:0] load_address,
    input wire [7:0] load_data,
    input wire [15:0] address,
    input wire [7:0] write_data,
    input wire mreq_n,iorq_n,m1_n,rd_n,wr_n,
    output wire [7:0] read_data,
    output reg irq=0,
    output reg [7:0] command=0,
    output wire read_fire,write_fire,ack_fire,
    output wire ay_pipeline_busy,
    output wire signed [15:0] ay1_a,ay1_b,ay1_c,ay2_a,ay2_b,ay2_c
);
    (* ramstyle="M10K" *) reg [7:0] rom[0:4095];
    (* ramstyle="M10K" *) reg [7:0] ram[0:1023];
    initial $readmemh("rtl/intrepid/sound_ram_zero.hex",ram);
    reg [7:0] rom_q,ram_q;
    wire ram_select=address>=16'h3800 && address<=16'h3bff;
    wire rd_cycle=!rd_n && (!mreq_n || !iorq_n);
    wire wr_cycle=!wr_n && (!mreq_n || !iorq_n);
    wire ack_cycle=!iorq_n && !m1_n;
    reg read_seen=0,write_seen=0,ack_seen=0;
    assign read_fire=rd_cycle && !read_seen && !reset;
    assign write_fire=wr_cycle && !write_seen && !reset;
    assign ack_fire=ack_cycle && !ack_seen && !reset;
    wire io_write=write_fire && !iorq_n;
    wire io_read=read_fire && !iorq_n;
    wire clear_command=io_write && address[7:0]==8'h00;
    always @(posedge clk) begin
        if(load_rom) rom[load_address]<=load_data;
        rom_q<=rom[address[11:0]];
    end
    always @(posedge clk) begin
        if(write_fire && !mreq_n && ram_select) begin
            ram[address[9:0]]<=write_data;ram_q<=write_data;
        end else ram_q<=ram[address[9:0]];
    end
    always @(posedge clk) begin
        if(reset) begin read_seen<=0;write_seen<=0;ack_seen<=0;irq<=0;end
        else begin
            read_seen<=rd_cycle;write_seen<=wr_cycle;ack_seen<=ack_cycle;
            if(ack_fire) irq<=0;
            // Simultaneous new raster event wins over acknowledge; no event lost.
            if(raster_irq) irq<=1;
            if(clear_command) command<=0;
            // Main write wins if both clock-edge events coincide (implementation choice).
            if(command_write) command<=command_data;
        end
    end
    wire [7:0] ay1_read,ay2_read;wire ay1_busy,ay2_busy;
    intrepid_ay8910 #(.EXTERNAL_A(1)) ay1(.clk(clk),.reset(reset),.ay_ce(ay_ce),
        .address_write(io_write && address[7:0]==8'h8e),.data_write(io_write && address[7:0]==8'h8f),
        .data_read(io_read && address[7:0]==8'h8f),.write_data(write_data),.port_a(command),.read_data(ay1_read),
        .channel_a(ay1_a),.channel_b(ay1_b),.channel_c(ay1_c),.sample(),.selected_register(),.selected_active(),.pipeline_busy(ay1_busy));
    intrepid_ay8910 ay2(.clk(clk),.reset(reset),.ay_ce(ay_ce),
        .address_write(io_write && address[7:0]==8'h8c),.data_write(io_write && address[7:0]==8'h8d),
        .data_read(io_read && address[7:0]==8'h8d),.write_data(write_data),.port_a(8'hff),.read_data(ay2_read),
        .channel_a(ay2_a),.channel_b(ay2_b),.channel_c(ay2_c),.sample(),.selected_register(),.selected_active(),.pipeline_busy(ay2_busy));
    assign ay_pipeline_busy=ay1_busy || ay2_busy;
    // MAME default unmapped value is zero for these address maps; IRQ vector ff.
    assign read_data=ack_cycle ? 8'hff : !mreq_n ?
        (address<16'h1000 ? rom_q : address<16'h2000 ? 8'd0 : ram_select ? ram_q : 8'd0) :
        !iorq_n ? (address[7:0]==8'h8f ? ay1_read : address[7:0]==8'h8d ? ay2_read : 8'd0) : 8'd0;
endmodule
