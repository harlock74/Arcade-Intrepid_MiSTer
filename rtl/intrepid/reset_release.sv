// Intrepid Stage C: asynchronous assertion, three-edge synchronous release.
module reset_release(input wire clk, input wire request, output wire reset);
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
    reg [2:0] stages = 3'b111;
    always @(posedge clk or posedge request)
        if (request) stages <= 3'b111;
        else stages <= {stages[1:0],1'b0};
    assign reset = stages[2];
endmodule
