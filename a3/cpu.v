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

// decode
`define D0 3

// load
`define L1 5
`define L2 6

// write-back
`define WB 7

// regs
`define R1 9

// execute
`define EXEC 10

// halt
`define HALT 15

module main();
    integer i;

    // clock
    wire clk;
    clock c0(clk);
    reg [3:0]state = `F0;

    counter ctr((state == `HALT),clk);


    // PC
    reg [15:0]pc = 16'h0000;

    // fetch 
    wire [15:0]memOut;
    wire [15:0]memIn = (state == `F0) ? pc :
                       (state == `WB) ? pc + 1 :
                       (state == `F2 &&  memOut[15:12] ==4) ? memOut[11:4] :
                       16'hxxxx;
    mem i0(clk,memIn,memOut);

    reg [15:0]inst;

    // decode
    wire [3:0]opcode = inst[15:12];
    wire [3:0]ra = memOut[11:8];
    wire [3:0]rb = memOut[7:4];
    wire [3:0]rt = inst[3:0];
    wire [15:0]jjj = inst[11:0]; // zero-extended
    wire [15:0]ii = inst[11:4]; // zero-extended

    wire [15:0]va;
    wire [15:0]vb;

    reg [15:0]res; // what to write in the register file

    // registers
    regs rf(clk,
        (state == `F2 && memOut[15:12]==1), ra, va,
        (state == `F2 && memOut[15:12]==1), rb, vb, 
        (state == `WB), rt, res);  //write enable, write address, write data

    reg [15:0] cycle = 0;
    reg [15:0] oldest = 0;
    reg [15:0] write_to;
    reg [15:0] cache_write;
    reg [15:0] oldest_line = 0;

    //caches 
    //valid, tag, data
    reg [15:0] i_cache0 [2:0];
    reg [15:0] i_cache1 [2:0];
    reg[15:0]  cache0 [2:0];
    reg [15:0] cache1 [2:0]; 


    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(1,main);
        for(i = 0; i < 3; i  = i + 1) begin
           i_cache0[i] <= 0;
           i_cache1[i] <= 0;
           cache0[i] <= 0;
           cache1[i] <= 0;
           $dumpvars(0, i_cache0[i]);
           $dumpvars(0, i_cache1[i]);
           $dumpvars(0, cache0[i]);
           $dumpvars(0, cache1[i]);
        end
    end


    always @(posedge clk) begin
        case(state)
        `F0: begin
            state <= `F1;
        end
        `F1: begin
            //check if instruction is in cache?
            if(i_cache0[0]==1 && i_cache0[1]==pc) begin
                inst <= i_cache0[2];
                state <= `D0;
            end
            else if(i_cache1[0]==1 && i_cache1[1]==pc) begin
                inst <= i_cache1[2];
                state <= `D0;
            end
            //see if cache line is empty
            else if(i_cache0[0]==0) begin
                i_cache0[0] <= 1;
                i_cache0[1] <= pc;
                write_to <= 0;
                state <= `F2;
            end
            else if(i_cache1[0]==0) begin
                i_cache1[0] <= 1;
                i_cache1[1] <= pc;
                write_to <= 1;
                state <= `F2;
            end
            //put in oldest cache line
            else if(oldest == 0) begin
              i_cache0[1] <= pc;
              write_to <= 0;
              oldest <= 1;
              state <= `F2;
            end
            else begin
              i_cache1[1] <= pc;
              write_to <= 1;
              oldest <= 0;
              state <= `F2;
            end

        end
        `F2: begin
            //assume had a cache miss
            if(write_to==0) begin
                i_cache0[2] <= memOut;
            end
            else if(write_to == 1) begin
                i_cache1[2] <= memOut;
            end
            state <= `D0;
            inst <= memOut;
        end
        `D0: begin
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
                state <= `HALT;
            end
            4'h4 : begin // ld

                //check if item in cache
                if(cache0[0]==1 && cache0[1]==ii) begin
                  res <= cache0[2];
                  state <= `WB;
                end
                else if(cache1[0]==1 && cache1[1]==ii) begin
                  res <= cache1[2];  
                  state <= `WB;
                end

                //not in cache -> see if can place in empty location
                else if(cache0[0]==0) begin
                   cache0[0] <= 1;
                   cache0[1] <= ii;
                   cache_write <= 0;
                   state <= `L1;
                end
                else if(cache1[1]==0) begin
                   cache1[0] <= 1;
                   cache1[1] <= ii;
                   cache_write <= 1;
                   state <=`L1; 
                end
                //clear out old cache line
                else if(oldest_line ==0) begin
                   oldest_line <= 1;
                   cache0[1] <= ii;
                   cache_write <= 0;
                   state <= `L1;
                end
                else if(oldest_line == 1) begin
                   oldest_line <= 0;
                   cache1[1] <= ii;
                   cache_write <= 1;
                   state <= `L1;
                end

           
            end

            default: begin
                pc <= pc + 1;
                state <= `F1;
            end
            endcase        
        end
        `WB: begin
            pc <= pc + 1;
            state <= `F1;
        end
        `L1: begin
            //put item into cache
            if(cache_write ==0 ) begin
              cache0[2] <= memOut;
            end
            else if(cache_write == 1) begin
              cache1[2] <= memOut;
            end

            res <= memOut;
            state <= `WB;

        end
        `EXEC : begin 
            case (opcode)
                4'h1 : begin // add
                    res <= va + vb;
                    state <= `WB;
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
