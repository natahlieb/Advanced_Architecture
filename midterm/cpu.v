// The Silly350 architecture has 16 16 bit registers,
//     byte addressable memory and a 16-bit PC initialized to 0.
 
// It has three instructions:
 
//
//        00000000aaaabbbb     strlen aaaa,bbbb
//            (aaaa points to a zero-terminated string in memory), strlen puts the length of the string in bb
//        00000001aaaabbbb     count aaaa,bbbb
//            (aaaa points to the head of a linked list), count puts the length of the list in bb
//        00000010aaaabbbb     sum aaaa,bbbb
//            (aaaa points to an array of 16 bit integers)
//            (bbbb contains the length of the array)
//            "sum" computes the sum of the array elements and stores the result in bbbb
//
// Show as much of its implementation in Verilog as you can
// Why is this a bad architecture?


//states
//fetch
`define F0 0

//decode
`define D0 1

//read values
`define R0 2 //read bbbb values
`define R1 3 //performs strlen count
`define R2 4 //performs count of value
`define R3 5 //computes sum of array elements

//store values
`define W0 5
module cpu();
 
//using previously provided clock file, memory file, register value, state machine file. all but clock
//were modified

     //are we handling a string length instruction?
     function isstrLen;
         input [15:0] inst;
         isstrLen = (inst[15:8] == 0) ? 1:
                    0;
     endfunction

     //are we handling a count function?
     function isCount
         input [15:0] inst;
         isCount = (inst[15:8] == 1) ? 1:
                    0;
     endfunction

     //are we handling a sum function?
     function isSum
         input [15:0] inst;
         isSum = (inst[15:8] == 2) ? 1:
                    0;
     endfunction


     //clock
     wire clk;
     clock c0(clk);
 
     reg [3:0] state = `F0;

     // PC
     reg [15:0] pc = 0;

     //instruction
     reg [15:0] inst;

     //A location we're retrieving
     reg [15:0] inst_a;

     //A value
     reg [15:0] a_val;

     //B register
     reg [15:0] rb;
     
     //B returned value
     reg [15:0] vb;
     
     //read/write values
     reg[15:0] write_address;
     reg[15:0] write_value;


     //fetch 
     wire [15:0] read_location = (state == `F0) ? pc:
                         (state == `R0) ? inst_a:
                         (state == `R1) ? r1_addr:
                         (state == `R2) ? r2_addr:
                         (state == `R3) ? r3_addr:
                         16'h0000; 
                         
     //memory                    
     mem i0(clk, read_location, returned_value);
     

     //registers
     regs rf(clk, 
             (state == `R0), rb, vb,
             (state == `W0), write_address, write_value);
    

    //temp values
    reg [15:0] str_len;
    reg [15:0] count_val;
    reg [15:0] sum_val;
    reg [15:0] counter;

    always @(posedge clk) begin
       case(state)
         //fetch
         `F0 : begin
            inst <= memOut;
            state <= `D0;
            str_len <= 0;
            count_val <= 0;
            sum_val <= 0;
            counter <= 0;
         end

         //decode
         `D0 : begin
            rb <= inst[3:0];
            inst_a <= inst[7:4];
         end

         //read values/register
         `R0 : begin //read b values
             if(isstrLen(inst)) begin
               state <= `R1;
               r1_addr <= inst_a;
             end

            if(isCount(inst)) begin
                state <= `R2;
                r2_addr <= inst_a;
            end

            if(isSum(inst)) begin
                state <= `R3;
                r3_addr <= inst_a;
            end  
               
         end

         `R1 : begin //isstrLen
            if(returned_value==1) begin
              state <= `W0;
              write_value <= str_len;
            end 

            r1_addr <= r1_addr + 1;
            str_len <=  str_len + 1;
         end

         `R2 : begin //isCount
            if(returned_value == end_list)
              state <= `W0;
              write_value <= str_len;
            end

            r2_addr <= r2_addr + 1;
            count_val <= count_val +1;

         end

         `R3 : begin //isSum 
             if(counter == vb) begin
               state <= `W0;
               write_value <= sum;
             end
            sum_val <= sum_val + returned_val;
            r3_addr <= r3_addr + 1;
         end

         //store values
         `W0 : begin
            write_address <= rb;
         end

         default : begin
           $display*"unknown state %d", state);    
         end
       endcase

    end
endmodule 
