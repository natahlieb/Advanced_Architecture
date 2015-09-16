/* fetch queue */
`timescale 1ps/1ps

module queue(input clk, 
            //pushing
            input push_enable,
            input [15:0] push_value,
            output isFull,
            //popping
            input pop_enable,
            output [15:0] value, 
            output isEmpty);
   
    //fetch buffer    
    reg [16:0] f_buff0 = 0;
    reg [16:0] f_buff1 = 0;
    reg [16:0] f_buff2 = 0;
    reg [16:0] f_buff3 = 0;
    reg [16:0] f_buff4 = 0;
    reg [16:0] f_buff5 = 0;


    //wire telling us part of fetch buffer is busy
    wire q0 = f_buff0[16];
    wire q1 = f_buff1[16];
    wire q2 = f_buff2[16];
    wire q3 = f_buff3[16];
    wire q4 = f_buff4[16];
    wire q5 = f_buff5[16];
 
    wire isFull = head == 5;
    wire isEmpty = (head==0 && f_buff0==0);
    reg [15:0] value = 16'hxxxx;
    reg [15:0] tail = 0;
    reg [15:0] head = 0;
    
    always@(posedge clk) begin
      //popping logic
      if(pop_enable && isEmpty == 0) begin
          if(head==0) begin
             value <= f_buff0[15:0];
             f_buff0 <= 0;
          end else if(head ==1) begin
             value <= f_buff1[15:0];
             f_buff1 <= 0;
          end else if(head ==2) begin
              value <= f_buff2[15:0];
              f_buff2 <= 0;
          end else if(head == 3) begin
              value <= f_buff3[15:0];
              f_buff3 <= 0;
              head <= head -1;
          end else if(head ==4) begin
              value <= f_buff4[15:0];
              f_buff4 <= 0;
          end else if(head == 5) begin
              value <= f_buff5[15:0];
              f_buff5 <= 0;
          end
          if(head ==0) begin
              head = 0;
          end else begin
              head = head -1;
          end
      end

      //pushing logic
      else if (push_enable && isFull == 0) begin
            head <= head + 1;
            f_buff0[15:0] <= push_value;
            f_buff0[16] <= 1;
            f_buff1 <= f_buff0;
            f_buff2 <= f_buff1;
            f_buff3 <= f_buff2;
            f_buff4 <= f_buff3;
            f_buff5 <= f_buff4;  
      end
    end

endmodule

