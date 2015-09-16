/* instruction memory */

`timescale 1ps/1ps

module mem(input clk,
    input [15:0]raddr, output [15:0]rdata);

    reg [15:0]mem[1023:0];

    /* Simulation -- read initial content from file */
    initial begin
        $readmemh("mem.hex",mem,0,12);
    end

    /* memory address register */
    reg [15:0]in = 16'hxxxx;

    /* memory data register */
    reg [15:0]out = 16'hxxxx;

    assign rdata = out;

    always @(posedge clk) begin
        in <= raddr;
        out <= mem[in];        
    end

endmodule
