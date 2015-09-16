/* instruction memory */

`timescale 1ps/1ps
module mem(input [15:0]raddr, output [15:0]rdata);
    reg [15:0]mem[1023:0];

    /* Simulation -- read initial content from file */
    initial begin
        $readmemh("mem.hex",mem,0,8);
    end

    reg [15:0]out = 16'hxxxx;
    assign rdata = out;

    always @(raddr) begin
        out = 16'hxxxx;
        #800;
        out = mem[raddr];
    end

endmodule
