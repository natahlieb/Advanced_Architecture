`timescale 1ps/1ps

module main();

    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(1,main);
    end

    //clock
    wire clk;
    clock c0(clk);
    
    //next instruction
    wire [15:0]next_pc =  d_flush ? d_target :
                          storing ? f_pc:
                          d_stall ? f_pc:
                          f_valid ? (f_pc + 1) :
                          0;

     //functions

    //grab ra
    function [3:0] RA;
        input [15:0]inst;
        RA = inst[11:8];
    endfunction
    
    //grab rb
    function [3:0] RB;
      input [15:0]inst;
      RB = inst[7:4];
    endfunction
    
    //grab rt
    function [3:0] RT;
     input [15:0]inst;
      RT = inst[3:0];
    endfunction

    //grab S for store
    function [7:0] RS;
      input[15:0]inst;
      RS = inst[7:0];
    endfunction
 
    function isMov;
       input valid;
       input [15:0]inst;
       isMov = valid & (inst[15:12] == 0);
    endfunction
    
    function isAdd;
        input valid;
        input [15:0]inst;
        isAdd = valid & (inst[15:12] == 1);
    endfunction
    
    function isJmp;
        input valid;
        input [15:0]inst;
        isJmp = valid & (inst[15:12] == 2);
    endfunction
    
    function isHalt;
        input valid;
        input [15:0]inst;
        isHalt = valid & (inst[15:12] == 3);
    endfunction
    
    function isLd;
        input valid;
        input [15:0]inst;
        isLd = valid & (inst[15:12] == 4);
    endfunction
    
    function isLdr;
        input valid;
        input [15:0]inst;
        isLdr = valid & (inst[15:12] == 5);
    endfunction
    
    function isJeq;
        input valid;
        input [15:0]inst;
        isJeq = valid & (inst[15:12] == 6);
    endfunction
   
    function isStore;
        input valid;
        input [15:0] inst;
        isStore = valid & (inst[15:12]==7);
    endfunction
     
    function usesRA;
        input valid;
        input [15:0]inst;
        usesRA = isAdd(valid,inst) | isLdr(valid,inst) | isJeq(valid,inst) | isStore(valid, inst);
    endfunction
    
    function usesRB;
        input valid;
        input [15:0]inst;
        usesRB = isAdd(valid,inst) | isLdr(valid,inst) | isJeq(valid,inst) | isStore(valid, inst);
    endfunction
    
    function usesRT;
        input valid;
        input [15:0]inst;
        usesRT = isAdd(valid,inst) | isLd(valid,inst) | isLdr(valid,inst) | isMov(valid,inst) | isStore(valid, inst);
    endfunction
   
   function storeStall;
       input valid;
       input [15:0] inst;
       input d_pc;
       storeStall = /*isStore(valid, inst);// &  */((RS(inst)-d_pc));
   endfunction 

    function [3:0] count;
       input [3:0] index;
       count = ((~d_stall) & ~(d_flush) & usesRT(d_valid, d_inst) & (RT(d_inst) == index)) ? 4 :
                (counters[index] == 0) ? 0 :
                (counters[index] -1);
    endfunction

    //fowarding register
    //6 item array, each index holding 2 16bit values. first value register, second is value
  //  reg [15:0] fowarding [6:0][[2:0];
     reg [15:0] fowarding [0:15];
     reg [15:0] fowarding_bitmask = 0;


    //variables-----------------------------

    //counters
    //array of per register counters, each representing the number of cycles
    //remaming until the register is ready
    reg [3:0] counters[0:15];
   
    reg [3:0] stores;
 
 
    //fetch variables------------------------
    reg f_valid= 0;
    reg [15:0] f_pc;
  
    
    //decode variables-----------------------
    reg d_valid =0;
    reg [15:0] d_pc;

    wire [7:0] d_RS = RS(d_inst);

    reg [15:0] d_savedInst; //saved instruction
    reg d_useSaved = 0; //set to 1 if using stalled instruction

    wire [15:0] d_inst = d_useSaved ? d_savedInst : memOut;
    //do we have a jump?
    wire d_isJmp = isJmp(d_valid, d_inst);

    //are we flushing?
    wire d_flush = r_flush | d_isJmp;
    wire [15:0] d_target  = r_flush ? r_target:
                            d_isJmp ? d_inst[11:0]:
                            16'hxxxx;

   //are we stalling due to register dependencies?
    wire  d_stall = (usesRA(d_valid, d_inst) & (counters[RA(d_inst)] != 0)) |
                   (usesRB(d_valid, d_inst) & (counters[RB(d_inst)] != 0 ));
    wire  d_value  = fowarding_bitmask[RA(d_inst)]==1 | fowarding_bitmask[RB(d_inst)] ==1;
  //are we stalling due to storing dependencies?
 // wire [15:0] store_stall = //isStore(d_valid, d_inst);
    reg[15:0] store_counter = 0;


    //register variables -------------------------
    reg [15:0] r_inst;
    reg r_valid = 0;
    reg [15:0] r_pc;

    wire r_flush = x_flush;
    wire [15:0] r_target = x_target;

    //execute variables -------------------------
    reg [15:0] x_inst;
    reg x_valid = 0;
    reg [15:0] x_pc;

    wire [15:0] x_va;
    wire [15:0] x_vb;
    wire [15:0] x_result = (isAdd(x_valid, x_inst) | isLdr(x_valid, x_inst)) ? x_va + x_vb:
                           (isMov(x_valid, x_inst) | isLd(x_valid, x_inst)) ? x_inst[11:4]:
                           16'hxxxx;
    


    wire x_flush = l_flush | (isJeq(x_valid, x_inst) & (x_va == x_vb));
    wire [15:0] x_target = l_flush ? l_target:
                           (x_pc + x_inst[3:0]);

   
    //load variables-----------------------------
    reg [15:0] l_inst;
    reg l_valid = 0;
    reg [15:0] l_pc;

    reg [15:0] l_result;
    wire l_flush = w_flush;
    wire [15:0] l_target = w_target;

    reg [15:0] l_va;
    reg [15:0] l_vb;


    //writeback variables-----------------------
    reg [15:0] w_inst;
    reg w_valid = 0;
    reg [15:0] w_pc;
    wire [15:0] w_memOut;

    reg [15:0] w_va;
    reg[15:0] w_vb;
    reg [15:0] w_result;
    wire [15:0] w_output = (isLd(w_valid, w_inst) | isLdr(w_valid, w_inst)) ? w_memOut :
                           w_result;
    
    wire w_halt = isHalt(w_valid, w_inst);//&& counter_delay2!=1;
    //flush if we have a halt
    wire [15:0] w_target = w_pc;
    wire w_flush = w_halt;

    //enabled writing if moving, adding, ld, ldr if w is valid
    wire write_enabled = mem_writeEnable ? 0:
                         isMov(w_valid, w_inst) ? 1:
                         isAdd(w_valid, w_inst)  ? 1:
                         isLd(w_valid, w_inst) ? 1:
                         isLdr(w_valid, w_inst) ? 1:
                         0;


    //storing
    wire mem_writeEnable = write_enabled ? 0:
                           isStore(w_valid, w_inst) ? 1 :
                           0;                           
    wire[15:0] mem_writeAddress = isStore(w_valid, w_inst) ? RS(w_inst):
                                  16'hxxxx;
    wire[15:0] mem_writeData = isStore(w_valid, w_inst) ? w_va:
                                  16'hxxxx;

  
    
    //enable ra & rb value fetch if adding, ldr, or jeq 
    wire ren0 = (isAdd(d_valid, d_inst) | isLdr(d_valid, d_inst) | isJeq(d_valid, d_inst) | isStore(d_valid, d_inst)) ? 1:
                0;
    wire ren1 =  (isAdd(d_valid, d_inst) | isLdr(d_valid, d_inst) | isJeq(d_valid, d_inst)) ? 1:
                0;

   reg[15:0] tail_end;  
   
   //memory output
    wire [15:0] memOut;
    wire [3:0] target = RT(w_inst); 
    wire [3:0] ra_val = RA(d_inst);
    wire [3:0] rb_val = RB(d_inst);
    mem i0(clk, next_pc, memOut, x_result, w_memOut, mem_writeEnable, mem_writeAddress, mem_writeData);

  // registers
  regs rf(clk, ren0, RA(d_inst), x_va, ren1, RB(d_inst), x_vb, write_enabled, RT(w_inst), w_output);

  //counter  
  counter ctr(w_halt, clk, write_valid | d_isJmp | r_flush,);

  wire begin_store = isStore(d_valid, d_inst) && store_counter!=1 && d_stall==0 && d_flush==0;

  wire storing = store_counter|  begin_store;
  reg counter_delay = 0;
  reg counter_delay2 = 0;

  always @(posedge clk) begin

             f_valid <= 1;
             f_pc <= next_pc;

             d_valid <= d_flush ? 0 : 
                        storing ? 0:
                        (f_valid | d_stall);

             d_pc <= d_stall | storing? d_pc :
                     f_pc;

             d_useSaved <= d_stall | storing;
             d_savedInst <= d_inst;

             if(d_flush) begin
                store_counter <=0;
                counter_delay <= 0;
                counter_delay2 <= 0;
             end

             //store instruction
             tail_end <= d_pc + 6;
             if(isStore(d_valid, d_inst) && store_counter!=1 && d_stall==0 && d_flush==0) begin // && ~(RS(d_inst) > d_pc+5)) begin
                store_counter <= 1;
             //   counter_delay <= 1;
            //    counter_delay2 <= 1;
             end

             if(isStore(w_valid, w_inst) && store_counter==1) begin
                 store_counter <= 0;
             end
/*
             if(store_counter==0 && counter_delay==1) begin
                 counter_delay <=0;
             end

             if(counter_delay==0 && counter_delay2==1) begin
                 counter_delay2 <=0;
             end
  
             
  */
             r_valid <= d_valid & (~d_flush) & (~d_stall);// & (~storing);
             r_pc <= d_pc;
             r_inst <= d_inst;

             x_valid <= r_valid & (~r_flush);
             x_pc <= r_pc;
             x_inst <= r_inst;

             l_valid <= x_valid & (~x_flush);
             l_pc <= x_pc;
             l_inst <= x_inst;
             l_result <= x_result;
             l_va <= x_va;
             l_vb <= x_vb;

             w_valid <= l_valid & (~l_flush);
             w_pc <= l_pc;
             w_inst <= l_inst;
             w_result <= l_result;
             w_va <= l_va;
             w_vb <= l_vb;
               
             
             //fowarding implementation
             //get stored value from the move
             if(isMov(d_valid, d_inst)) begin
                fowarding[RT(d_inst)] <= d_inst[11:8];
                fowarding_bitmask[RT(d_inst)]<=1;
             end
/*
             if(isLd(w_valid, w_inst) || isLdr(w_valid, w_inst)) begin
                fowarding[RT(w_inst)] <= w_memOut;
                fowarding_bitmask[RT(w_inst)]<=1;
             end


             //create added cookie
             if(isAdd(x_valid, x_inst)) begin

                 //fowarding[3][0] <= RT(x_inst);
                 fowarding[RT(x_inst)] <= x_va + x_vb;
                 fowarding_bitmask[RT(x_inst)]<=1;
             end
*/

             if(w_valid) begin
                fowarding_bitmask[RT(w_inst)]<=0;
             end
 
            
             // counters
             if (f_valid) begin
               counters[0] <= count(0);
               counters[1] <= count(1);
               counters[2] <= count(2);
               counters[3] <= count(3);
               counters[4] <= count(4);
               counters[5] <= count(5);
               counters[6] <= count(6);
               counters[7] <= count(7);
               counters[8] <= count(8);
               counters[9] <= count(9);
               counters[10] <= count(10);
               counters[11] <= count(11);
               counters[12] <= count(12);
               counters[13] <= count(13);
               counters[14] <= count(14);
               counters[15] <= count(15);
             end 
             else begin
               counters[0] <= 0;
               counters[1] <= 0;
               counters[2] <= 0;
               counters[3] <= 0;
               counters[4] <= 0;
               counters[5] <= 0;
               counters[6] <= 0;
               counters[7] <= 0;
               counters[8] <= 0;
               counters[9] <= 0;
               counters[10] <= 0;
               counters[11] <= 0;
               counters[12] <= 0;
               counters[13] <= 0;
               counters[14] <= 0;
               counters[15] <= 0;
             end

                
      end

endmodule
