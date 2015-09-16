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
`define L1 7
`define L2 8
`define L3 9

// write-back
`define WB 10

// regs
`define R0 11
`define R1 12

// execute
`define EXEC 13

// halt
`define HALT 15

module main();

    //Setup Cache for data
    //  0         1          2    3
    //[valid, last updated, tag, data]
    reg [15:0] cache_l0 [0:3];
    reg [15:0] cache_l1 [0:3];
    reg [15:0] cache_l2 [0:3];
    reg [15:0] cache_l3 [0:3];

    reg [15:0] cache_addr;
    reg lru = 0; 
    reg [15:0] r_from_cache = 0;
    reg [15:0] write_location = 16'h0000;
    reg [15:0] cache_hit =0;

    //cache for instructions
    reg [15:0] i_cache0 [0:2];
    reg [15:0] i_cache1 [0:2];
    reg [15:0] i_cache2 [0:2];
    reg [15:0] i_cache3 [0:2];

    reg clear = 0; 
    reg [15:0] i_write_location = 16'h0000;
    reg [15:0] i_cache_hit =0;
    reg [15:0] oldest_line = 0;


    integer lp;
    integer i; 

    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(1,main);
        $dumpvars(1,i0);
        for (lp=0; lp < 4; lp = lp+1) begin
                $dumpvars(0, cache_l0[lp]);
                $dumpvars(0, cache_l1[lp]);
                $dumpvars(0, cache_l2[lp]);
                $dumpvars(0, cache_l3[lp]);
        end

        for(lp = 0; lp < 3; lp = lp+1) begin
                $dumpvars(0, i_cache0[lp]);
                $dumpvars(0, i_cache1[lp]);
                $dumpvars(0, i_cache2[lp]);
                $dumpvars(0, i_cache3[lp]);
        end

        for( i = 0; i < 4; i = i + 1 ) begin
           cache_l0[i]<= 0;
           cache_l1[i]<=0;
           cache_l2[i]<=0;
           cache_l3[i] <=0;
        end

        i_cache0[0]<= 0;
        i_cache1[0]<=0;
        i_cache2[0]<=0;
        i_cache3[0] <=0;

    end

    // clock
    wire clk;
    clock c0(clk);
    reg [3:0]state = `F0;

    counter ctr((state == `HALT),clk,(state == `D0),cycle);


    // PC
    reg [15:0]pc = 16'h0000;

    // fetch 
    wire [15:0]memOut;
    wire memReady;
    wire [15:0]memIn = (state == `F0) ? pc :
                       (state == `L1) ? res :
                       16'hxxxx;


    mem i0(clk,
       //read port
       (state == `F0) || (state == `L1),  //read enable
       memIn, //raddr
       memReady, //ready
       memOut); //rdata

    reg [15:0]inst;

    // decode
    wire [3:0]opcode = inst[15:12];
    wire [3:0]ra = inst[11:8];
    wire [3:0]rb = inst[7:4];
    wire [3:0]rt = inst[3:0];
    wire [15:0]jjj = inst[11:0]; // zero-extended
    wire [15:0]ii = inst[11:4]; // zero-extended

    wire [15:0]va;
    wire [15:0]vb;

    reg [15:0]res; // what to write in the register file

    // registers
    regs rf(clk,
        (state == `R0), ra, va,   //read enabled, read address, read data
        (state == `R0), rb, vb,   //read enabled, read address, read data
        (state == `WB && (opcode==0 || opcode==1 || opcode==4 || opcode == 5 )), rt, res); //write enabled, write address, write data

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
        //fetch--------------------
        case(state)
        `F0: begin

        //check i_cache to see if we have the saved instruction

            //check if item is already in cache 
            //is in cache 0
            if(i_cache0[0]==1 && i_cache0[1]==pc) begin
                 inst <= i_cache0[2];
                 i_cache_hit <= i_cache_hit +1;
                 r_from_cache <= 0;
                 state <= `D0;
            end
            //is in cache 1
            else if (i_cache1[0]==1 && i_cache1[1]==pc) begin
                 inst <= i_cache1[2];
                 i_cache_hit <= i_cache_hit + 1;
                 state <= `D0;
                 r_from_cache <= 1;
            end

            //is in cache 2
            else if(i_cache2[0]==1 && i_cache2[1]==pc) begin
                 inst <= i_cache2[2];
                 i_cache_hit <= i_cache_hit + 1;
                 state <= `D0;
                   r_from_cache <= 2;
            end
            //is in cache 3
            else if(i_cache3[0]==1 && i_cache3[1]==pc) begin
                inst <= i_cache3[2];
                i_cache_hit <= i_cache_hit + 1;
                state <= `D0;
                 r_from_cache <= 3;
            end
            else begin
                state <= `F1;
                r_from_cache <= 0;
                pc <= pc;
            end       
            
         end

        //item not in our cache-> see where we can place it
        `F1: begin
          //first check if all lines of cache are full
          //if cache l0 empty load there
            if (i_cache0[0]!=1) begin
               i_cache0[0] <= 1;
               i_cache0[1] <= pc;
               i_write_location <= 0;
               state <= `F2;
            end
            //if cache l0 full, load into l1
            else if (i_cache1[0]!=1) begin
               i_cache1[0] <=1;
               i_cache1[1] <= pc;
               i_write_location <= 1;
               state <= `F2;
            end
            //if cache l1 full load into l2
            else if (i_cache2[0]!=1) begin
                i_cache2[0] <= 1;
                i_cache2[1] <= pc;
                i_write_location <= 2;
                state <= `F2;
            end
            //if cache l2 full, load into l3
            else if(i_cache3[0]!=1) begin 
                i_cache3[0] <= 1;
                i_cache3[1] <= pc;
                i_write_location <= 3;
                state <=`F2; 
           end

           //assuming all lines aren't full. check to see which line to replace
           //if line 0 oldest/iLRU
           else if(oldest_line==0) begin
                   i_cache0[1] <= pc;
                   i_write_location <= 0;
                   oldest_line <= 1;
                   state <= `F2;
               end
               //if line 1 oldest/LRU
           else if(oldest_line == 1) begin
                   i_cache1[1] <= pc;
                   i_write_location <= 1;
                   oldest_line <= 2;
                   state <= `F2;
               end
           //if line 2 oldest/LRU
           else if(oldest_line == 2) begin
                   i_cache2[1] <= pc;
                   i_write_location <= 2;
                   oldest_line <= 3;
                   state <= `F2;
           end
           //else clear line 3
           else begin
                   i_cache3[1] <= pc;
                   i_write_location <= 3;
                   oldest_line <= 0;
                   state <= `F2;
           end
        end


        `F2: begin
            if (memReady) begin
                inst <= memOut;

                if(i_write_location==0) begin
                    i_cache0[2] <= memOut;
                end
                else if(i_write_location==1) begin
                    i_cache1[2] <= memOut;
                end
                else if(i_write_location==2) begin
                    i_cache2[2] <= memOut;
                end
                else begin
                    i_cache3[2]<= memOut;
                end
                state <= `F3;
           end
              
         end

         `F3: begin
            state <= `F4;
         end

         `F4: begin
            state <= `D0;
         end



        //decode-------------------
        `D0: begin
            case(opcode)
            4'h0 : begin // mov
                res <= ii;
                state <= `WB;
            end
            4'h1 : begin // add
                state <= `R0;
            end
            4'h2 : begin // jmp
                pc <= jjj;
                state <= `F0;
            end
            4'h3 : begin // halt
                state <= `HALT;
            end
            4'h4 : begin // ld
                res <= ii;
                cache_addr <= ii;
                state <= `L1;
            end
            4'h5 : begin // ldr
                state <= `R0;
            end
            4'h6 : begin // jeq
                state <= `R0;
            end
            default: begin
                $display("unknown inst %x @ %x",inst,pc);
                pc <= pc + 1;
                state <= `F0;
            end
            endcase        
        end
        
        //load --------------------
        `L0: begin
            state <= `L1;
        end

        `L1: begin
            //check if item is already in cache 
            //is in cache 0
            if(cache_l0[0]==1 && cache_l0[2]==cache_addr) begin
                 cache_l0[2] <= pc;
                 res <= cache_l0[3];
                 cache_hit <= cache_hit +1;
                 state <= `WB;
            end
            //is in cache 1
            else if (cache_l1[0]==1 && cache_l1[2]==cache_addr) begin
                 cache_l1[2] <= pc;
                 res <= cache_l1[3];
                 cache_hit <= cache_hit + 1;
                 state <= `WB;
            end
            //is in cache 2
            else if(cache_l2[0]==1 && cache_l2[2]==cache_addr) begin
                 cache_l2[2] <= pc;
                 res <= cache_l2[3];
                 cache_hit <= cache_hit + 1;
                 state <= `WB;
            end
            //is in cache 3
            else if(cache_l3[0]==1 && cache_l3[2]==cache_addr) begin
                 cache_l3[2] <= pc;
                 res <= cache_l3[3];
                 cache_hit <= cache_hit + 1;
                 state <= `WB;
            end
            else begin
                 state <= `L2;
            end

        end

        //item not in our cache-> see where we can place it
        `L2: begin
          //first check if all lines of cache are full
          //if cache l0 empty load there
            if (!cache_l0[0]) begin
               cache_l0[0] <= 1;
               cache_l0[1] <= pc;
               cache_l0[2] <= cache_addr;
               write_location <= 0;
               state <= `L3;
            end
            //if cache l0 full, load into l1
            else if (!cache_l1[0]) begin
               cache_l1[0] <=1;
               cache_l1[1] <= pc;
               cache_l1[2] <= cache_addr;
               write_location <= 1;
               state <= `L3;
            end
            //if cache l1 full load into l2
            else if (!cache_l2[0]) begin
                cache_l2[0] <= 1;
                cache_l2[1] <= pc;
                cache_l2[2] <= cache_addr;
                write_location <= 2;
                state <= `L3;
            end
            //if cache l2 full, load into l3
            else if(!cache_l3[0]) begin 
                cache_l3[0] <= 1;
                cache_l3[1] <= pc;
                cache_l3[2] <= cache_addr;
                write_location <= 2;
                state <=`L3; 
           end

           //assuming all lines aren't full. check to see which line to replace
           //if line 0 oldest/LRU
           else  if(oldest(cache_l0[1], cache_l1[1], cache_l2[1], cache_l3[1])==0) begin
                   cache_l0[1] <= pc;
                   cache_l0[2] <= cache_addr;
                   write_location <= 0;
                   state <= `L3;
               end
               //if line 1 oldest/LRU
           else if(oldest(cache_l0[1], cache_l1[1], cache_l2[1], cache_l3[1])==1) begin
                   cache_l1[1] <= pc;
                   cache_l1[2] <= cache_addr;
                   write_location <= 1;
                   state <= `L3;
     // cache_l1[3] <= memOut;
               end
               //if line 2 oldest/LRU
           else if(oldest(cache_l0[1], cache_l1[1], cache_l2[1], cache_l3[1])==2) begin
                   cache_l2[1] <= pc;
                   cache_l2[2] <= cache_addr;
                   write_location <= 2;
                   state <= `L3;
  //   cache_l2[3] <= memOut;
               end
               //else clear line 3
           else if(oldest(cache_l0[1], cache_l1[1], cache_l2[1], cache_l3[1])==3) begin
                   cache_l3[1] <= pc;
                   cache_l3[2] <= cache_addr;
                   write_location <= 3;
                   state <= `L3;
//     cache_l3[3] <= memOut;
               end
        end


        `L3: begin
            if (memReady) begin
                res <= memOut;
                state <= `WB;

                if(write_location==0) begin
                    cache_l0[3] <= memOut;
                end
                else if(write_location==1) begin
                    cache_l1[3] <= memOut;
                end
                else if(write_location==2) begin
                    cache_l2[3] <= memOut;
                end
                else begin
                    cache_l3[3] <= memOut;
                end
                state <= `WB;
           end
                //state <= `WB;

         end
         
        
        //write back----------------
        `WB: begin
            pc <= pc + 1;
            state <= `F0;
        end
                //register read------------
        `R0: begin
            state <= `R1;
        end
        `R1: begin
            state <= `EXEC;
        end

        //execute instruction-----
        `EXEC : begin
            case (opcode)
                4'h1 : begin // add
                    res <= va + vb;
                    state <= `WB;
                end
                4'h5 : begin // ldr
                    res <= va + vb;
                    cache_addr <= va + vb;
                    state <= `L1;
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

        //halt ----------
        `HALT: begin
        end
        default: begin
            $display("unknown state %d",state);
            $finish;
        end
        endcase
    end

endmodule
