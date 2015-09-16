/* instruction memory */

`timescale 1ps/1ps

module mem(input clk,
    input [15:0]raddr0, output [15:0]rdata0,
    input [15:0]raddr1, output [15:0]rdata1);

    reg [15:0]mem[1023:0];

    /* Simulation -- read initial content from file */
    initial begin
        $readmemh("mem.hex",mem,0,27);
    end

    /* memory address register */
    reg [15:0]in0 = 16'hxxxx;
    reg [15:0]in1 = 16'hxxxx;

    /* memory data register */
    reg [15:0]out0 = 16'hxxxx;
    reg [15:0]out1 = 16'hxxxx;

    assign rdata0 = out0;
    assign rdata1 = out1;

    always @(posedge clk) begin
        in0 <= raddr0;
        out0 <= mem[in0];        
        in1 <= raddr1;
        out1 <= mem[in1];
    end

endmodule
