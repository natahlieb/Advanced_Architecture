`timescale 1ps/1ps

//
// This is an inefficient implementation.
//   make it run correctly in less cycles, fastest implementation wins
//

//
// States:
//

// Fetch
`define F0 0
`define F1 1
`define F2 2
`define F3 3
`define F4 4

// decode
`define D0 5

// load
`define L0 6
`define L2 7

// write-back
`define WB 8

// execute
`define EXEC 10

// halt
`define HALT 15

module main();


    //create something to hold register values
    reg[15:0] reg_values[0:15][0:2];
    integer i;
    integer j;
    integer k;
    //reservation stations
    //busy? operand? v0 source? v0 ready? v0 value? v1 source? v1 ready? v1 value?
    //add 
    reg[15:0] add_rs [0:4][0:7];
    //mov
    reg[15:0] mov_rs [0:4][0:7];
    //halt
    reg[15:0] halt_rs [0:4][0:7];
    //load
    reg [15:0] load_rs [0:4][0:7];
    //ldr
    reg [15:0] ldr_rs [0:4][0:7];
    //jeq
    reg[15:0] jeq_rs [0:4][0:7];

    //8 entries
    //each consisting of pc/memory read location of instruction, instruction itself
    //load buffer
    reg [15:0] load_buff [0:7][0:1];

    //instruction cache
    //4 entries in instruction cache
    //valid, last updated, tag, data
    reg [15:0] inst_cache [0:3][0:3];
    reg [15:0] cache_addr;
    reg clear = 0;
    reg [15:0] i_write_location = 16'h0000;
    reg [15:0] inst_cache_hit = 0;
    integer l;
    initial begin
        
        $dumpfile("cpu.vcd");
        $dumpvars(1,main);
        $dumpvars(1,i0);
        for(i=0; i < 16; i = i +1) begin
            reg_values[i][0] <= 0;
         //  $dumpvars(0, reg_values[i][0]);
          /* $dumpvars(0, reg_values[i][1]);
           $dumpvars(0, reg_values[i][2]);
           $dumpvars(0, reg_values[i][3]);
*/
        end
        for(l=0; l<4; l= l+ 1) begin
            inst_cache[l][0] <=0;
            inst_cache[l][1] <= 0;
            inst_cache[l][2] <= 0;
            inst_cache[l][3] <= 0;
        end
        
    end

    // clock
    wire clk;
    clock c0(clk);
    reg [3:0]state = `F0;

    counter ctr((state == `HALT),clk,(state == `D0),cycle);

  
    // regs
    reg [15:0]regs[0:15];

    // PC
    reg [15:0]pc = 16'h0000;

    // fetch 
    wire [15:0]memOut;
    wire memReady;
    wire [15:0]memIn = (state == `F0) ? pc :
                       (state == `L0) ? res :
                       16'hxxxx;


    mem i0(clk,
       (state == `F0) || (state == `L0), //read enable
       memIn, //raddr
       memReady, //ready
       memOut);  //rdata

    reg [15:0]inst;

    // decode
    wire [3:0]opcode = inst[15:12];
    wire [3:0]ra = inst[11:8];
    wire [3:0]rb = inst[7:4];
    wire [3:0]rt = inst[3:0];
    wire [15:0]jjj = inst[11:0]; // zero-extended
    wire [15:0]ii = inst[11:4]; // zero-extended

    reg [15:0]va;
    reg [15:0]vb;

    reg [15:0]res; // what to write in the register file


    //find the LRU 
    function [15:0] oldest; 
        input [15:0] l0;
        input [15:0] l1;
        input [15:0] l2;
        input [15:0] l3;
        //case where l0 is oldest
        if(l0 <= l1 && l0<=l2 && l0<=l3) begin
             oldest = 0;
        end
        //case where l1 is oldest
        else if(l1 <= l0 && l1 <= l2 && l1 <= l3) begin
            oldest = 1;
        end
        //case where l2 is oldest
        else if(l2 <= l0 && l2<=l1 && l2 <= l3) begin
            oldest = 2;
        end
        //case where l3 is oldest
        else begin
            oldest = 3;
        end
    endfunction


    always @(posedge clk) begin
        case(state)
        `F0: begin
        //check to see if the instruction we want is already in our instruction inst_cache
            for(k = 0; k < 4; k++) begin
               if(inst_cache[k][0]==1 && inst_cache[k][2]==pc) begin
                  //set instruction to what's in the cache
                  inst <= inst_cache[k][3];
                  //record we touched the cache
                  inst_cache[k][1] <= pc;
                  //increase our hit number
                  inst_cache_hit <= inst_cache_hit + 1;
                  state <= `D0;           
               end
            end
            cache_addr <= pc;
            state <= `F1;
        end

        //item not yet in inst_cache, see where it can be placed
        //check to see if any inst_cache lines are empty- place on the first empty line
        `F1: begin
           for(j=0; j< 3; j++) begin
               if(inst_cache[j][0]!=1) begin
                   //set to valid
                   inst_cache[j][0] <= 1;
                   //set updated as current pc
                   inst_cache[j][1] <= pc;
                   //set tag to requested address
                   inst_cache[j][2] <= cache_addr;
                   //set this to be the line we write to
                   i_write_location <= j;
                   state <= `F2;
               end    
           end
       

           //assume all inst_cache lines are full -> find the LRU cache line then
          if(oldest(inst_cache[0][1], inst_cache[1][1], inst_cache[2][1], inst_cache[3][1])==0) begin
             //change last updated time
             inst_cache[0][1]<= pc;
             //change the tag
             inst_cache[0][2] <= cache_addr;
             //set tag line to write to
             i_write_location <=0;
             state <= `F2;
           end
           /*
           else if(oldest(inst_cache[0][1], inst_cache[1][1], inst_cache[2][1], inst_cache[3][1])==1) begin
             inst_cache[1][1]<= pc;
             inst_cache[1][2] <= cache_addr;
             i_write_location <=1;
             state <= `F2;
           end
           else if(oldest(inst_cache[0][1], inst_cache[1][1], inst_cache[2][1], inst_cache[3][1])==2) begin
             inst_cache[2][1]<= pc;
             inst_cache[2][2] <= cache_addr;
             i_write_location <=2;
             state <= `F2;
           end
           else
             inst_cache[3][1]<= pc;
             inst_cache[3][2] <= cache_addr;
             i_write_location <=3;
             state <= `F2;
           end
           */
        end        
        
        
        `F2: begin
            if (memReady) begin
                //set data in line to be retrieved value
                inst_cache[i_write_location][3] <= memOut;
                state <= `D0;
                inst <= memOut;
            end
        end

        `F3: begin
            state <= `F4;
        end

        `F4: begin
          state <= `D0;
        end
        `D0: begin
            va <= regs[ra];
            vb <= regs[rb];
            case(opcode)
            4'h0 : begin // mov
                res <= ii;
                state <= `WB;
            end
            4'h1 : begin // add
                state <= `EXEC;
            end
            4'h2 : begin // jmp
                pc <= jjj;
                state <= `F0;
            end
            4'h3 : begin // halt
                $display("#0:%x",regs[0]);
                $display("#1:%x",regs[1]);
                $display("#2:%x",regs[2]);
                $display("#3:%x",regs[3]);
                $display("#4:%x",regs[4]);
                $display("#5:%x",regs[5]);
                $display("#6:%x",regs[6]);
                $display("#7:%x",regs[7]);
                $display("#8:%x",regs[8]);
                $display("#9:%x",regs[9]);
                $display("#10:%x",regs[10]);
                $display("#11:%x",regs[11]);
                $display("#12:%x",regs[12]);
                $display("#13:%x",regs[13]);
                $display("#14:%x",regs[14]);
                $display("#15:%x",regs[15]);
                state <= `HALT;
            end
            4'h4 : begin // ld
                res <= ii;
                state <= `L0;
            end
            4'h5 : begin // ldr
                state <= `EXEC;
            end
            4'h6 : begin // jeq
                state <= `EXEC;
            end
            default: begin
                $display("unknown inst %x @ %x",inst,pc);
                pc <= pc + 1;
                state <= `F0;
            end
            endcase        
        end
        `WB: begin
            //$display("#reg[%d] <= 0x%x",rt,res);
            regs[rt] <= res;
            pc <= pc + 1;
            state <= `F0;
        end
        `L0: begin
            state <= `L2;
        end
        `L2: begin
            if (memReady) begin
                res <= memOut;
                state <= `WB;
            end
        end
        `EXEC : begin
            case (opcode)
                4'h1 : begin // add
                    res <= va + vb;
                    state <= `WB;
                end
                4'h5 : begin // ldr
                    res <= va + vb;
                    state <= `L0;
                end
                4'h6 : begin // jeq
                    pc <= pc + ((va == vb) ? inst[3:0] : 1);
                    state <= `F0;
                end
               
                default: begin
                    $display("invalid opcode in exec %d",opcode);
                    $finish;
                end
            endcase
        end
        `HALT: begin
        end
        default: begin
            $display("unknown state %d",state);
            $finish;
        end
        endcase
    end

endmodule
