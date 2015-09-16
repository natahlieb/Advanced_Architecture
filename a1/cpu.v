`timescale 1ps/1ps
module main();

    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(1,main);
    end

    // clock
    wire clk;
    clock c0(clk);

    // PC
    reg [15:0]pc = 16'h0000;

    // registers
    reg [15:0]regs[15:0];

    wire [15:0]inst;

    //define our opcodes
    reg [3:0] opcode ;//= inst[15:12];
   
//    reg [7:0] j; 
    imem i0(pc,inst);

    reg [15:0] cycle = 0;

    
    always @(posedge clk) begin
        
        //grab the opcode 
        opcode = inst[15:12];
 
        /* stop after 20 cycles */
        if (cycle == 20) $finish;
  

        /* if jump instruction given */
        if (opcode == 2) begin
             //$display("jump");
             pc <=inst[12:0];
             //pc <= j;
        end

        /* if add instruction given */
        if (opcode == 1) begin
             //$display("add");
             regs[inst[3:0]] <= regs[inst[11:8]] + regs[inst[7:4]];
        end
        /* if move instruction given */
        if(opcode == 0) begin
             //$display("move");
            regs[inst[3:0]] <= inst[11:4];
        end
        
        
        $display("cycle=%d, pc=%x, inst=%x, regs=%x:%x:%x:%x:%x:%x:%x:%x:%x:%x:%x:%x:%x:%x:%x:%x",cycle,pc,inst,
            regs[0], regs[1], regs[2], regs[3], regs[4], regs[5], regs[6], regs[7],
            regs[8], regs[9], regs[10], regs[11], regs[12], regs[13], regs[14], regs[15]);
        cycle <= cycle + 1;
        
        
        if (opcode !=2)  pc <= pc + 1;
    end

endmodule

/* clock */
module clock(output clk);
    reg theClock = 1;

    assign clk = theClock;
    
    always begin
        #5;
        theClock = !theClock;
    end
endmodule

/* instruction memory */
module imem(input [15:0]raddr, output [15:0]data);
    reg [15:0]mem[15:0];

    /* Simulation -- read initial content from file */
    initial begin
        $readmemh("imem.hex",mem,0,6);
    end

    assign data = mem[raddr];
endmodule


