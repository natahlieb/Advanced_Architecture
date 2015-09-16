`timescale 1ps/1ps

//
// States:
//

// Fetch States
`define F0 0
`define F1 1
`define F2 2  //normal place in fetch buffer
`define F3 3  //buffer is full, stop fetching until no longer full
`define F7 18

// decode
`define D0 4
`define D1 5
`define D2 6
`define D3 7
`define D7 77
`define D8 19  //stalling -> not enough room in one of or RS

//add 
`define A0 16
`define A1 17


//move 
`define M0 13
`define M1 14

//jump
`define J0 18
`define J1 20
// load
`define L0 8
`define L1 9
`define L2 10
`define L3 11
// write-back
`define WB 16

// execute
`define EXEC 17

// halt
`define HALT 15

module main();

    // clock
    wire clk;
    clock c0(clk);

    reg [5:0]fetch_state = `F0;
    reg [5:0]decode_state = `D0;
    reg [5:0] move_state = `M0;
    reg [5:0] add_state = `A0;
    reg [5:0] load_state = `L0;
    reg [15:0] jump_state;
    counter ctr((fetch_state == `HALT),clk,(fetch_state == `D0),cycle);
  
    // regs
    reg [15:0]regs[0:15];
    reg [15:0] regs_src [0:15];
    reg regs_busy [0:15];

    // PC
    reg [15:0]pc = 16'h0000;

    // fetch 
    wire [15:0]fetchOut;
    wire fetchReady;
    // load 
    wire [15:0]loadOut;
    wire loadReady;
    reg [15:0]res; // what to write in the register file

    //queue stuff
    wire push_enable = (fetch_state==`F1 && !queue_full && fetchReady) ? 1 :
                       0;
    wire queue_full;
    wire pop_enable = (decode_state == `D0 && !queue_empty) || (jump_state == `J1 && queue_empty==0) ? 1: 0;
    wire [15:0] popped_value;
    wire queue_empty;
    reg push_ok;

    queue fetch_queue(clk, 
                     push_enable,
                     fetchOut,
                     queue_full, 
                     pop_enable,
                     popped_value, 
                     queue_empty);
   
    mem i0(clk,
       /* fetch port */
       (fetch_state == `F0 && jump_state != `J0), //fetch enable
       pc,  //fetch address
       fetchReady,  //fetch information ready
       fetchOut, //fetch data

       /* load port */
       (load_state == `L1),
       res, //load address
       loadReady, 
       loadOut
       );

    //functional unit variables
    reg [15:0] move_target;
 
    //reservation stations - 4 stations per instruction
    //mov reservation_station
    reg [15:0] r_mov0 [8:0];
    reg [15:0] r_mov1 [8:0];
    reg [15:0] r_mov2 [8:0];
    reg [15:0] r_mov3 [8:0];

    //add reservation station
    reg [15:0] r_add0 [8:0];
    reg [15:0] r_add1 [8:0];
    reg [15:0] r_add2 [8:0];
    reg [15:0] r_add3 [8:0];

    //ld reservation stations
    reg [15:0] r_ld0 [8:0];
    reg [15:0] r_ld1 [8:0];
    reg [15:0] r_ld2 [8:0];
    reg [15:0] r_ld3 [8:0];

    //ldr reservation stations
    reg [15:0] r_ldr0 [8:0];
    reg [15:0] r_ldr1 [8:0];
    reg [15:0] r_ldr2 [8:0];
    reg [15:0] r_ldr3 [8:0];

    //jeq reservation stations
    reg [15:0] r_jeq0 [8:0];
    reg [15:0] r_jeq1 [8:0];
    reg [15:0] r_jeq2 [8:0];
    reg [15:0] r_jeq3 [8:0];

    integer i;
    initial begin
       $dumpfile("cpu.vcd");
       $dumpvars(1,main);
       $dumpvars(1,i0);
       $dumpvars(1, fetch_queue);

       for(i=0; i <16; i = i+ 1) begin
          $dumpvars(0, regs[i]);

          $dumpvars(0, regs_src[i]);
          $dumpvars(0, regs_busy[i]);
          regs_busy[i] <= 0;
       end

       for(i=0; i < 9; i = i +1) begin
          $dumpvars(0, r_mov0[i]); $dumpvars(0, r_mov1[i]);
          $dumpvars(0, r_mov2[i]); $dumpvars(0, r_mov3[i]);
          $dumpvars(0, r_add0[i]); $dumpvars(0, r_add1[i]);
          $dumpvars(0, r_add2[i]); $dumpvars(0, r_add3[i]);
          $dumpvars(0, r_ld0[i]); $dumpvars(0, r_ld1[i]);
          $dumpvars(0, r_ld2[i]); $dumpvars(0, r_ld3[i]);
          $dumpvars(0, r_ldr0[i]); $dumpvars(0, r_ldr1[i]);
          $dumpvars(0, r_ldr2[i]); $dumpvars(0, r_ldr3[i]);
          r_mov0[0]<=0;
          r_mov1[0]<=0;
          r_mov2[0]<=0;
          r_mov3[0]<=0;
          r_add0[0]<=0;
          r_add1[0]<=0;
          r_add2[0]<=0;
          r_add3[0]<=0;
          r_ld0[0]<=0;
          r_ld1[0]<=0;
          r_ld2[0]<=0;
          r_ld3[0]<=0;
          r_ldr0[0]<=0;
          r_ldr1[0]<=0;
          r_ldr2[0]<=0;
          r_ldr3[0]<=0;
      end
    end

    reg [15:0] inst;

    // decode
    wire [3:0]ra = popped_value[11:8];
    wire [3:0]rb = popped_value[7:4];
    wire [3:0]rt = popped_value[3:0];
    wire [15:0]jjj = popped_value[11:0]; // zero-extended
    wire [15:0]ii = popped_value[11:4]; // zero-extended

    reg [15:0]va;
    reg [15:0]vb;
    wire [15:0] d_inst = popped_value;
    wire [3:0] opcode = (popped_value[15:12]);
    reg [15:0] load_out;
    reg [15:0] load_reg;
    reg [15:0] jump_value;
    always @(posedge clk) begin

        //fetch machine
        case(fetch_state)
        `F0: begin
            fetch_state <= `F1;
            pc <= pc + 1;
        end

        `F1: begin
        
          //temporary halting mechanism
          if(queue_full) begin
              fetch_state <= `F3;
          end
          else begin
            fetch_state <= `F2;
          end

        end

       `F2: begin
           fetch_state <= `F0;
       end

       `F3: begin  //our fetch buffer is full. wait until not completely full
            if(queue_full==0) begin
               fetch_state <= `F0;
            end
            else begin
                fetch_state <= `F3;
            end
        end

       `F7: begin
           //do nothing
        end
      endcase 
            
      case(jump_state_ 
        `J0: begin
            //clear out entirity of fetch buffer
            if(queue_empty==1) begin
                pc <= jmp_value -1;
                jump_state <= `J1;
                fetch_state <= `F0;
                decode_state <= `D0;
            end
         end
         `J1: begin

         end
      endcase
 
      //move fetch unit
      //cycle through, see if any move has two values which are ready to be computed
      case(move_state)
       `M0: begin


           //check if both dependencies met, reservation station in use
           if(r_mov0[0]==1 && r_mov0[2]==1 && r_mov0[5]==1) begin
               //see if reservation station for register matches current reservation station
               if(regs_src[r_mov0[8]] == 0) begin
                   regs[r_mov0[8]] <= r_mov0[4];
                   r_mov0[0] <= 0;
                   move_state <= `M1;
               end
           end
           else if(r_mov1[0]==1 && r_mov1[2]==1 && r_mov1[5]==1) begin
               //see if register source matches target of move
               if(regs_src[r_mov1[8]] == 1) begin
                   regs[r_mov1[8]] <= r_mov1[4];
                   r_mov1[0] <= 0;
                   move_state <= `M1;
               end
           end
           else if(r_mov2[0]==1 && r_mov2[2]==1 && r_mov2[5]==1) begin
               //see if register source matches target of move
               if(regs_src[r_mov2[8]] == 2) begin
                   regs[r_mov2[8]] <= r_mov2[4];
                   r_mov2[0] <= 0;
                   move_state <= `M1;
               end
           end
           else if(r_mov3[0]==1 && r_mov3[2]==1 && r_mov3[5]==1) begin
               //see if register source matches target of move
               if(regs_src[r_mov3[8]] == 3) begin
                   regs[r_mov3[8]] <= r_mov3[4];
                   r_mov3[0] <= 0;
                   move_state <= `M1;
               end
           end
          move_state <= `M1;
      end
      `M1: begin
          move_state <= `M0;
      end

      endcase      

      case(add_state) 
      `A0: begin
           //check if both dependencies met, reservation station in use
           if(r_add0[0]==1 && r_add0[2]==1 && r_add0[5]==1) begin
               //see if reservation station for register matches current reservation station
               if(regs_src[r_add0[8]] == 10) begin
                   regs[r_add0[8]] <= r_add0[4] + r_add0[7];
                   r_add0[0] <= 0;
                   add_state <= `A1;
               end
           end
           else if(r_add1[0]==1 && r_add1[2]==1 && r_add1[5]==1) begin
               //see if register source matches target of adde
               if(regs_src[r_add1[8]] == 11) begin
                   regs[r_add1[8]] <= r_add1[4] + r_add1[7];
                   r_add1[0] <= 0;
                   add_state <= `A1;
               end
           end
           else if(r_add2[0]==1 && r_add2[2]==1 && r_add2[5]==1) begin
               //see if register source matches target of adde
               if(regs_src[r_add2[8]] == 12) begin
                   regs[r_add2[8]] <= r_add2[4] + r_add2[7];
                   r_add2[0] <= 0;
                   add_state <= `A1;
               end
           end
           else if(r_add3[0]==1 && r_add3[2]==1 && r_add3[5]==1) begin
               //see if register source matches target of adde
               if(regs_src[r_add3[8]] == 13) begin
                   regs[r_add3[8]] <= r_add3[4] + r_add3[7];
                   r_add3[0] <= 0;
                   add_state <= `A1;
               end
           end
          add_state <= `A0;
      end

      `A1: begin
          add_state <= `A0;
      end
      endcase      


      //load machine
      case(load_state) 
         `L0: begin
            if(r_ld0[0]==1 && r_ld0[2]==1 && r_ld0[5]==1) begin
               //get value from memory
               res <= r_ld0[8];
               load_reg <= 0;
               load_state <= `L1;
            end
            else if(r_ld2[0]==1 && r_ld2[2]==1 && r_ld2[5]==1) begin
               //get value from memory
               res <= r_ld2[8];
               load_reg <= 1;
               load_state <= `L1;
            end
             else if(r_ld2[0]==1 && r_ld2[2]==1 && r_ld2[5]==1) begin
               //get value from memory
               res <= r_ld2[8];
               load_reg <= 2;
               load_state <= `L1;
            end                      
            else if(r_ld3[0]==1 && r_ld3[2]==1 && r_ld3[5]==1) begin
               //get value from memory
               res <= r_ld1[8];
               load_reg <= 3;
               load_state <= `L1;
            end       
            else begin
                load_state  <= `L0;
            end 
         end

         `L1: begin
            load_state <= `L2;
         end
         
         `L2: begin
           if(loadReady==1) begin
               load_state <= `L3;
           end
           else begin
               load_state <= `L2;
               load_out <= loadOut;
           end
         end
         
         `L3: begin
            if(load_reg ==0) begin
               if(regs_src[r_ld0[8]]==40) begin
                   regs[r_ld0[8]] <= load_out;
                   r_ld0[0] <= 0;
               end
            end
            else if(load_reg ==1) begin
               if(regs_src[r_ld1[8]]==40) begin
                   regs[r_ld1[8]] <= load_out;
                   r_ld1[0] <= 0;
               end
            end
           else if(load_reg ==2) begin
               if(regs_src[r_ld2[8]]==40) begin
                   regs[r_ld2[8]] <= load_out;
                   r_ld0[2] <= 0;
               end
            end
            else  if(load_reg ==3) begin
               if(regs_src[r_ld0[8]]==40) begin
                   regs[r_ld3[8]] <= load_out;
                   r_ld3[0] <= 0;
               end
            end
            load_state <= `L0;
         end
      endcase


      //decode machine
      case(decode_state) 
       `D0: begin
          decode_state <= `D1;
        end
        `D1: begin
          if(opcode == 3) begin
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
             fetch_state <= `HALT;
          end

          else if(opcode==0) begin  //move-------------------------------------
              //see which reservation station is open for move
              //r0 empty
               if(r_mov0[0]==0) begin
                  r_mov0[0] <= 1;
                  r_mov0[1] <= d_inst;
                  r_mov0[8] <= rt;
                  r_mov0[4] <= ii;
                  r_mov0[7] <= ii;     
                  r_mov0[2]<=1;
                  r_mov0[3] <= regs_src[rt];
                  r_mov0[5] <= 1;
                  r_mov0[6] <= regs_src[rt];
                  
                  if(regs_busy[rt] == 0) begin //put in values of instruction to register
                     regs_busy[rt] <= 1;
                     regs_src[rt] <= 0; //reservation station no;
                  end
             end
             //r1 empty
             else if(r_mov1[0]==0) begin
                  r_mov1[0] <= 1;
                  r_mov1[1] <= d_inst;
                  r_mov1[8] <= rt;
                  r_mov1[4] <= ii;
                  r_mov1[5] <= ii;
                  r_mov1[2]<=1;
                  r_mov1[3] <= regs_src[rt];
                  r_mov1[5] <= 1;
                  r_mov1[6] <= regs_src[rt];
                  r_mov1[8] <= rt;
                 
                  if(regs_busy[rt]==0) begin //put in values of instruction to register
                     regs_busy[rt] <= 1;
                     regs_src[rt] <= 1;//reservation station no;
                  end
             end
             //r2 empty
             else if(r_mov2[0]==0) begin
                  r_mov2[0] <= 1;
                  r_mov2[1] <= d_inst;
                  r_mov2[8] <= rt;
                  r_mov2[4] <= ii;
                  r_mov2[7] <= ii;
                  r_mov2[2]<=1;
                  r_mov2[3] <= regs_src[rt];
                  r_mov2[5] <= 1;
                  r_mov2[6] <= regs_src[rt];
                 
                  if(regs_busy[rt]==0) begin //put in values of instruction to register
                     regs_busy[rt] <= 1;
                     regs_src[rt] <= 2; //reservation station no;
                  end
             
             end
             //r3 empty
             else if(r_mov3[0]==0) begin
                  r_mov3[0] <= 1;
                  r_mov3[1] <= d_inst;
                  r_mov3[8] <= rt;
                  r_mov3[4] <= ii;
                  r_mov3[7] <= ii;
                  r_mov3[2]<=1;
                  r_mov3[3] <= regs_src[rt];
                  r_mov3[5] <= 1;
                  r_mov3[6] <= regs_src[rt];

                  if(regs_busy[rt]==0) begin //put in values of instruction to register
                     regs_busy[rt] <= 1;
                     regs_src[rt] <= 3; //reservation station no;
                    //regs[rt] <= ii;
                  end
             end
             else begin
                 decode_state <= `D7;
             end
          end
          
          
          //add-------------------------------------------------
          else if(opcode==1) begin 
              //add0 open?
              if(r_add0[0]==0) begin
                  r_add0[0] <= 1;
                  r_add0[1] <= d_inst;
                  r_add0[2]<=0;
                  r_add0[3] <= ra;
                  r_add0[5] <= 0; 
                  r_add0[6] <= rb;
                  r_add0[8] <=rt;

                if(regs_busy[ra]==0) begin
                      regs_busy[rb] <= 1;
                      regs_src[rb] <= 10;//reservation station no
                 end 
                  
                 if(regs_busy[rb] == 0) begin
                     regs_busy[rb] <= 1;
                     regs_src[rb] <= 10;//reservation station no
                 end
              end

              //add1 open?
              else if(r_add1[0]==0) begin
                  r_add1[0] <= 1;
                  r_add1[1] <= d_inst;
                  r_add1[2]<=0;
                  r_add1[3] <= ra;
                  r_add1[5] <= 0; 
                  r_add1[6] <= rb;
                  r_add1[8] <=rt;

                if(regs_busy[ra]==0) begin
                      regs_busy[rb] <= 1;
                      regs_src[rb] <= 10;//reservation station no
                 end 
                  
                 if(regs_busy[rb] == 0) begin
                     regs_busy[rb] <= 1;
                     regs_src[rb] <= 10;//reservation station no
                 end
              end

              //add1 open?
              else if(r_add2[0]==0) begin
                  r_add2[0] <= 1;
                  r_add2[1] <= d_inst;
                  r_add2[2]<=0;
                  r_add2[3] <= ra;
                  r_add2[5] <= 0; 
                  r_add2[6] <= rb;
                  r_add2[8] <=rt;

                if(regs_busy[ra]==0) begin
                      regs_busy[rb] <= 1;
                      regs_src[rb] <= 10;//reservation station no
                 end 
                  
                 if(regs_busy[rb] == 0) begin
                     regs_busy[rb] <= 1;
                     regs_src[rb] <= 10;//reservation station no
                 end
              end

              //add3 open?
              else if(r_add3[0]==0) begin
                  r_add3[0] <= 1;
                  r_add3[1] <= d_inst;
                  r_add3[2]<=0;
                  r_add3[3] <= ra;
                  r_add3[5] <= 0; 
                  r_add3[6] <= rb;
                  r_add3[8] <=rt;

                if(regs_busy[ra]==0) begin
                      regs_busy[rb] <= 1;
                      regs_src[rb] <= 10;//reservation station no
                 end 
                  
                 if(regs_busy[rb] == 0) begin
                     regs_busy[rb] <= 1;
                     regs_src[rb] <= 10;//reservation station no
                 end
              end

             else begin
                 decode_state <= `D7;
             end   
          end

          //jump---------------------------------------
          else if(opcode==2) begin
              jump_value <= d_inst[11:0];
              jump_state <= `J0;
              fetch_state <= `F7;
              decode_state <= `D8;
             //logic to invalidate all items currently in queue
             // advance pc by specified value

          end 


         //ld----------------------------------------
          else if(opcode==4) begin 
               if(r_ld0[0]==0) begin
                  r_ld0[0] <= 1;
                  r_ld0[1] <= 1;
                  r_ld0[2] <= 1;
                  r_ld0[3] <= ii;
                  r_ld0[5] <= 1;
                  r_ld0[6] <= ii;
                  r_ld0[8] <= rt;
                  //see if register being operated upon
                  if(regs_busy[rt]==0) begin //see if register a busy
                      regs_busy[rt] <= 1;
                      regs_src[rt] <= 40; //reservation station no
                  end
              end
          
              else if(r_ld1[0]==0) begin
                  r_ld1[0] <= 1;
                  r_ld1[1] <= 1;
                  r_ld1[2] <= 1;
                  r_ld1[3] <= ii;
                  r_ld1[5] <= 1;
                  r_ld1[6] <= ii;
                  r_ld1[8] <= rt;
                  //see if register being operated upon
                  if(regs_busy[rt]==0) begin //see if register a busy
                      regs_busy[rt] <= 1;
                      regs_src[rt] <= 41; //reservation station no
                  end
              end

              else if(r_ld2[0]==0) begin
                  r_ld2[0] <= 1;
                  r_ld2[1] <= 1;
                  r_ld2[2] <= 1;
                  r_ld2[3] <= ii;
                  r_ld2[5] <= 1;
                  r_ld2[6] <= ii;
                  r_ld2[8] <= rt;
                  //see if register being operated upon
                  if(regs_busy[rt]==0) begin //see if register a busy
                      regs_busy[rt] <= 1;
                      regs_src[rt] <= 42; //reservation station no
                  end
              end

              else if(r_ld3[0]==0) begin
                  r_ld3[0] <= 1;
                  r_ld3[1] <= 1;
                  r_ld3[2] <= 1;
                  r_ld3[3] <= ii;
                  r_ld3[5] <= 1;
                  r_ld3[6] <= ii;
                  r_ld3[8] <= rt;
                  //see if register being operated upon
                  if(regs_busy[rt]==0) begin //see if register a busy
                      regs_busy[rt] <= 1;
                      regs_src[rt] <= 43; //reservation station no
                  end
              end
                else begin
                  decode_state <= `D7;
              end
          end


          //ldr----------------------------------------
          else if(opcode==5) begin 
               if(r_ldr0[0]==0) begin
                  r_ldr0[0] <= 1;
                  r_ldr0[1] <= d_inst;
                  r_ldr0[2] <= 0;
                  r_ldr0[3] <= ra;
                  r_ldr0[5] <=0;
                  r_ldr0[6] <= rb;
                  r_ldr0[8] <= rt;
                   //see if register being operated upon
                  if(regs_busy[ra]==0) begin //see if register a busy
                     regs_busy[ra] <= 1;
                     regs_src[ra] <= 50;//reservation station no
                  end

                  if(regs_busy[rb]==0) begin //see if rb busy 
                    regs_busy[rb] <= 1;
                    regs_src[rb] <= 50; //reservation station no
                 end
              end
             
              else if(r_ldr1[0]==0) begin
                  r_ldr1[0] <= 1;
                  r_ldr1[1] <= d_inst;
                  r_ldr1[2] <= 0;
                  r_ldr1[3] <= ra;
                  r_ldr1[5] <=0;
                  r_ldr1[6] <= rb;
                  r_ldr1[8] <= rt;
                   //see if register being operated upon
                  if(regs_busy[ra]==0) begin //see if register a busy
                     regs_busy[ra] <= 1;
                     regs_src[ra] <= 51;//reservation station no
                  end

                  if(regs_busy[rb]==0) begin //see if rb busy 
                    regs_busy[rb] <= 1;
                    regs_src[rb] <= 51; //reservation station no
                 end
              end

              else if(r_ldr2[0]==0) begin
                  r_ldr2[0] <= 1;
                  r_ldr2[1] <= d_inst;
                  r_ldr2[2] <= 0;
                  r_ldr2[3] <= ra;
                  r_ldr2[5] <=0;
                  r_ldr2[6] <= rb;
                  r_ldr2[8] <= rt;
                   //see if register being operated upon
                  if(regs_busy[ra]==0) begin //see if register a busy
                     regs_busy[ra] <= 1;
                     regs_src[ra] <= 52;//reservation station no
                  end

                  if(regs_busy[rb]==0) begin //see if rb busy 
                    regs_busy[rb] <= 1;
                    regs_src[rb] <= 52; //reservation station no
                 end
              end

              else if(r_ldr3[0]==0) begin
                  r_ldr3[0] <= 1;
                  r_ldr3[1] <= d_inst;
                  r_ldr3[2] <= 0;
                  r_ldr3[3] <= ra;
                  r_ldr3[5] <=0;
                  r_ldr3[6] <= rb;
                  r_ldr3[8] <= rt;
                   //see if register being operated upon
                  if(regs_busy[ra]==0) begin //see if register a busy
                     regs_busy[ra] <= 1;
                     regs_src[ra] <= 53;//reservation station no
                  end

                  if(regs_busy[rb]==0) begin //see if rb busy 
                    regs_busy[rb] <= 1;
                    regs_src[rb] <= 53; //reservation station no
                 end
              end

             else begin
                  decode_state <= `D7;
              end
          end

          //jeq
          else if(opcode==6) begin 
             //logic to pause fetch, clear out current buffer     
          end

          decode_state <= `D2;

        end


        `D2: begin
          decode_state <= `D0;
        end
       


        `D8: begin
           //do nothing
        end
        //stall state  - if any of the reservation stations are full, don't take any more instructions
        `D7: begin
           //check move rs
           if(r_mov0[0]==1 && r_mov1[0]==1 && r_mov2[0]==1 && r_mov3[0]==1) begin
              decode_state <= `D7;
           end
           //check add rs
           else if(r_add0[0]==1 && r_add1[0]==1 && r_add2[0]==1 && r_add3[0]==1) begin
              decode_state <= `D7;
           end  
           //check jmp rs
                  /* 
           else if(r_jmp0[0]==1 && r_jmp1[0]==1 && r_jmp2[0]==1 && r_jmp3[0]==1) begin
              decode_state <= `D7;
           end    */
           //check ld rs
           else if(r_ld0[0]==1 && r_ld1[0]==1 && r_ld2[0]==1 && r_ld3[0]==1) begin
              decode_state <= `D7;
           end
           //check ldr rs
           else if(r_ldr0[0]==1 && r_ldr1[0]==1 && r_ldr2[0]==1 && r_ldr3[0]==1) begin
              decode_state <= `D7;
           end          
           //check jeq rs
           else if(r_jeq0[0]==1 && r_jeq1[0]==1 && r_jeq2[0]==1 && r_jeq3[0]==1) begin
              decode_state <= `D7;
           end    
           else begin
               decode_state <= `D0;
           end
        end
      endcase

     

   end


        /*
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
            if (loadReady) begin
                res <= loadOut;
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

 */
endmodule
