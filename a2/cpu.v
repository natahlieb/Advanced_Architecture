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
    reg [15:0] reg_memIn = 16'h0000;

    // fetch 
    wire [15:0]memOut;
    wire [15:0]memIn;
    mem m0(memIn,memOut);
 
    assign memIn = reg_memIn; 
   
    //define opcode
    reg [15:0] opcode; // = memIn[15:12];
    reg [15:0] inst_info;

    wire [3:0] ra; // = 4'hx;
    wire [15:0] va;

    wire [3:0] rb; // = 4'hx;
    wire [15:0] vb;

    wire writeReg; //= 1'bx;
    wire [3:0] rt; // = 4'hx;
    wire [15:0] res; // = 16'hxxxx;

    // registers
    regs rf(clk,
        ra, va,
        rb, vb, 
        writeReg, rt, res);

    
   //-----------------------------
   reg [3:0] reg1; //= 4'hx;
   assign ra = reg1;

   reg [3:0] reg2;// = 4'hx;
   assign rb = reg2;

    reg write_enabled;// = 1'bx;
    assign writeReg = write_enabled;

    reg [3:0] write_location;// = 4'hx;
    assign rt= write_location;

    reg [15:0] write_data =0;// = 16'hxxxx;
    assign res = write_data;

    reg instruction_complete;
    //-------------------------------------



   reg[15:0] out1;
   reg[15:0] out2;
   reg [15:0] instruction;
   reg stateMachineIndex =0;



    always @(clk) begin
     
      if(pc == 9) $finish;

      if(stateMachineIndex  ==0) begin
          reg_memIn = pc;
          #1000;
          instruction = memOut;
          //$display("instruction: %x", instruction);
          opcode = instruction[15:12];
          write_enabled <= 0;
       end     

      case (opcode) 
            0: begin
                  if(stateMachineIndex ==0) begin
            //         $display("\nmove");
                     write_location = instruction[3:0];
                     write_data = instruction[11:4];
                     write_enabled = 1;
                     stateMachineIndex =1;
                     end
                  else begin
                     // $display("foo1");
                      stateMachineIndex = 0;
                      pc = pc +1;
                 end
               end
           
            1: begin
                  if(stateMachineIndex == 0) begin
                      //  $display("\nadd");
                        stateMachineIndex = 1;
                        write_location <= instruction[3:0];
                        reg1 <= instruction[11:8];
                        reg2 <= instruction[7:4];
                      //                          write_enabled <= 1 ;
                    //    write_data = va + vb;
                        #1000;
                       end
                  else begin
                    //  $display("foo2");
                    //  $display("reg 1 %x, reg 2 %x", reg1, reg2);
                      write_enabled =1;
                      write_data = va + vb;
                      stateMachineIndex =0;
                      pc = pc+1;
                  end
               end
           
             2: begin
                  if(stateMachineIndex == 0) begin
                       // $display("\njump");
                        write_enabled = 0;
                        stateMachineIndex = 1;
                       end
                  else begin
                     // $display("foo3");
                      stateMachineIndex =0;
                      pc = instruction[12:0]; 
                  end
               end

             3: begin
                  if(stateMachineIndex == 0) begin
                       // $display("\nhalt");
                        $finish;
                       end
                  else begin
                     // $display("foo4");
                      stateMachineIndex =0;
                      pc = pc+1;
                  end
               end
           
             4: begin
                  if(stateMachineIndex == 0) begin
                       // $display("\nload");
                        stateMachineIndex = 1;
                        write_location <= instruction[3:0];
                        //write_enabled <= 1;
                        reg_memIn <= instruction[11:4];
                       // $display("new instruction %x", instruction[11:4]);
                        #1000;
                  end
                  else begin
                     // $display("foo5");
                        write_enabled <=1;
                        write_data <= memOut[15:0];
                        stateMachineIndex =0;
                      //write_data = memOut[15:0];
                     // $display("memOut %x", memOut);
                      pc = pc+1;
                  end
               end

            default: begin
        //       $display("opcode %d", opcode);
               stateMachineIndex = 0;
               pc = pc+1;
          //     reg_memIn = pc;
           end
      endcase
    end

/*        
    always @(posedge clk) begin
        
        opcode = memOut[15:12];

        #1000; 
        //halt
        if(opcode == 3) $finish;

        //move
        if(opcode==0) begin
            write_location <= memOut[3:0];
            write_data <= memOut[11:4];
        //    $display("\nmove\nmemOut %x, memIn %x, writeEnabled %x,  ra %x, va %x, rb %x, vb %x,  write_location %x, write_data %x, pc %x", memOut, memIn, writeReg, ra, va ,rb, vb, rt, res, pc);
        #1000;
            write_enabled = 1;
        end



        //load
        
        if(opcode == 4) begin
          write_location <= memOut[3:0];
          write_data <= memOut[11:4];
          //$display("\nload\nmemOut %x, memIn %x, writeEnabled %x,  ra %x, va %x, rb %x, vb %x, write_location %x, write_data %x, pc %x", memOut, memIn, writeReg, ra, va ,rb, vb, rt, res, pc);
            #1000;
            write_enabled =1;
        end
       


       
       //jump
       if(opcode == 2) begin 
            write_enabled <=0;
            pc <= memOut[12:0];
            //$display("\njump\nmemOut %x, memIn %x, writeEnabled %x,  ra %x, va %x, rb %x, vb %x, write_location %x, write_data %x, pc %x", memOut, memIn, writeReg, ra, va ,rb, vb, rt, res, pc);
       end
      

       //add 
       if(opcode == 1) begin
           reg1 <= memOut[11:8];
            reg2 <= memOut[7:4];
            write_location <= memOut[3:0];
           write_data = va + vb;
            //$display("\nadd\nmemOut %x, memIn %x, writeEnabled %x,  ra %x, va %x, rb %x, vb %x, write_location %x, write_data %x, pc %x", memOut, memIn, writeReg, ra, va ,rb, vb, rt, res, pc);
            #1000;
            write_enabled = 1;
       end
         
            
       #200;
       write_enabled =0;
       if(opcode != 2) begin
          pc <= pc+1;
       end
       
    end
*/
endmodule
