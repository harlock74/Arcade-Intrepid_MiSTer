// Stage C platform hierarchy; deliberately no CPU, ROM storage or renderer.
module intrepid_shell(
    input wire clk, reset, download, wr,
    input wire [15:0] index,
    input wire [26:0] address,
    input wire [7:0] data,
    output wire complete, failed,
    output wire [31:0] receipt_crc,
    output wire [15:0] route_signature
);
    wire accepted;
    wire [1:0] bank;
    wire [14:0] local_address;
    wire [31:0] crc;
    reg [15:0] route = 0;
    reg previous_download = 0;
    wire start_target = download && !previous_download && index == 0;
    intrepid_download loader(.clk(clk),.reset(reset),.download(download),.wr(wr),
        .index(index),.address(address),.data(data),.accepted(accepted),.bank(bank),
        .local_address(local_address),.complete(complete),.failed(failed),.crc(crc));
    always @(posedge clk) begin
        if(reset) begin route <= 0; previous_download <= 0; end
        else begin
            previous_download <= download;
            if(start_target) route <= 0;
            if(accepted) route <= (start_target ? 16'd0 : {route[14:0],route[15]}) ^
                                 {1'b0,local_address} ^ {6'd0,bank,data};
        end
    end
    assign receipt_crc = ~crc;
    assign route_signature = route;
endmodule
