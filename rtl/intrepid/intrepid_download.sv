// Stage B v1 transaction controller. No ROM arrays or CPU implemented here.
module intrepid_download(
    input wire clk, reset, download, wr,
    input wire [15:0] index,
    input wire [26:0] address,
    input wire [7:0] data,
    output wire accepted,
    output wire [1:0] bank,
    output wire [14:0] local_address,
    output reg complete = 0,
    output reg failed = 0,
    output reg [31:0] crc = 32'hffffffff
);
    reg previous_download = 0;
    reg target = 0;
    reg [15:0] expected = 0;
    wire start = download && !previous_download;
    wire current_target = start ? (index == 16'd0) : target;
    wire current_failed = start ? 1'b0 : failed;
    wire [15:0] current_expected = start ? 16'd0 : expected;
    wire valid_address = address < 27'h0008020;
    assign accepted = !reset && download && current_target && !current_failed &&
                      index == 16'd0 && wr && valid_address && address == {11'd0,current_expected};
    assign bank = address < 27'h5000 ? 2'd0 : address < 27'h6000 ? 2'd1 :
                  address < 27'h8000 ? 2'd2 : 2'd3;
    wire [26:0] offset = bank == 0 ? address : bank == 1 ? address - 27'h5000 :
                        bank == 2 ? address - 27'h6000 : address - 27'h8000;
    assign local_address = offset[14:0]; // Only meaningful when accepted=1.
    function automatic [31:0] crc_byte(input [31:0] prior, input [7:0] value);
        reg [31:0] next_crc;
        integer i;
        begin
            next_crc = prior ^ {24'd0,value};
            for (i=0;i<8;i=i+1)
                next_crc = (next_crc >> 1) ^ (next_crc[0] ? 32'hedb88320 : 32'd0);
            crc_byte = next_crc;
        end
    endfunction
    always @(posedge clk) begin
        if (reset) begin
            previous_download <= 0; target <= 0; expected <= 0;
            complete <= 0; failed <= 0; crc <= 32'hffffffff;
        end else begin
            previous_download <= download;
            if (start) begin
                target <= index == 0; failed <= 0; expected <= 0;
                if (index == 0) begin complete <= 0; crc <= 32'hffffffff; end
            end
            if (download && current_target) begin
                if (index != 0 || (wr && (!valid_address || address != {11'd0,current_expected})))
                    failed <= 1;
                if (accepted) begin
                    expected <= current_expected + 16'd1;
                    crc <= crc_byte(start ? 32'hffffffff : crc,data);
                end
            end
            if (!download && previous_download) begin
                if (target) complete <= !failed && expected == 16'h8020;
                target <= 0;
            end
        end
    end
endmodule
