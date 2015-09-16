module counter(input isHalt, input clk);

    reg [15:0] count = 0;

    always @(posedge clk) begin
        if (isHalt) begin
            $display("@%d",count);
            $finish;
        end
        if (count == 1000) begin
            $display("ran for 1000 cycles");
            $finish;
        end
        count <= count + 1;
    end

endmodule
