/* memory */

`timescale 1ps/1ps

// Protocol:
//  set readEnable = 1
//      raddr = read address
//
//  A few cycles later:
//      ready = 1
//      rdata = data
//
module mem(input clk,
    // read port
    input readEnable,
    input [15:0]raddr,
    output ready,
    output [15:0]rdata);

    reg [15:0]data[1023:0];
    reg [15:0]ptr = 16'hxxxx;

    /* Simulation -- read initial content from file */
    initial begin
        $readmemh("mem.hex",data);
    end

    reg [15:0]counter = 0;

    assign ready = (counter == 1);
    assign rdata = (counter == 1) ? data[ptr] : 16'hxxxx;

    always @(posedge clk) begin
        if (readEnable) begin
            ptr <= raddr;
            counter <= 100;
        end else begin
            if (counter > 0) begin
                counter <= counter - 1;
            end else begin
                ptr <= 16'hxxxx;
            end
        end
    end

endmodule
