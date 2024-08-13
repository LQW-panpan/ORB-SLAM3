`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/10/21 21:23:21
// Design Name: 
// Module Name: ultraram_simple_dual_port
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


//  Xilinx UltraRAM Simple Dual Port.  This code implements 
//  a parameterizable UltraRAM block 1 Read and 1 write. 
//  when addra == addrb, old data will show at doutb 
module ultraram_simple_dual_port #(
  parameter DEPTH = 1000,
  parameter DWIDTH = 512,  // Data Width
  parameter NBPIPE = 4   // Number of pipeline Registers
 ) ( 
    input clk,                    // Clock 
    input rstb,                   // Reset
    input wea,                    // Write Enable
    input regceb,                 // Output Register Enable
    input mem_en,                 // Memory Enable
    input [DWIDTH-1:0] dina,      // Data Input  
    input [$clog2(DEPTH)-1:0] addra,     // Write Address
    input [$clog2(DEPTH)-1:0] addrb,     // Read  Address
    output reg o_valid,
    output reg [DWIDTH-1:0] doutb // Data Output
   );

(* ram_style = "ultra" *)
reg [DWIDTH-1:0] mem[DEPTH-1:0];        // Memory Declaration
reg [DWIDTH-1:0] memreg;              
reg [DWIDTH-1:0] mem_pipe_reg[NBPIPE-1:0];    // Pipelines for memory
reg mem_en_pipe_reg[NBPIPE:0];                // Pipelines for memory enable  

integer          i;

// RAM : Both READ and WRITE have a latency of one
always @ (posedge clk)
begin
 if(mem_en) 
  begin
   if(wea)
     mem[addra] <= dina;

   memreg <= mem[addrb];
  end
end

// The enable of the RAM goes through a pipeline to produce a
// series of pipelined enable signals required to control the data
// pipeline.
always @ (posedge clk)
begin
 mem_en_pipe_reg[0] <= mem_en;
 for (i=0; i<NBPIPE; i=i+1)
   mem_en_pipe_reg[i+1] <= mem_en_pipe_reg[i];
end

// RAM output data goes through a pipeline.
always @ (posedge clk)
begin
 if (mem_en_pipe_reg[0])
  mem_pipe_reg[0] <= memreg;
end    

always @ (posedge clk)
begin
 for (i = 0; i < NBPIPE-1; i = i+1)
  if (mem_en_pipe_reg[i+1])
   mem_pipe_reg[i+1] <= mem_pipe_reg[i];
end      

// Final output register gives user the option to add a reset and
// an additional enable signal just for the data ouptut
reg [4:0] rden;
always @ (posedge clk)begin
  rden <= {rden[3:0],regceb}; 
end
always @ (posedge clk)
begin
 if (rstb)
   doutb <= 0;
 else if (mem_en_pipe_reg[NBPIPE] && rden[4])
   doutb <= mem_pipe_reg[NBPIPE-1];
end
always @ (posedge clk)
begin
 if (rstb)
   o_valid <= 0;
 else if (mem_en_pipe_reg[NBPIPE] && rden[4])
   o_valid <= 1;
 else
  o_valid <= 0;
end
endmodule
/* 
// The following is an instantation template for
// xilinx_ultraram_simple_dual_port

   xilinx_ultraram_simple_dual_port # (
                                             .AWIDTH(AWIDTH),
                                             .DWIDTH(DWIDTH),
                                             .NBPIPE(NBPIPE)
                                            )
                      your_instance_name    (
                                             clk(clk),   
                                             rstb(rstb),   
                                             wea(wea),    
                                             regceb(regceb), 
                                             mem_en(mem_en),
                                             dina(dina), 
                                             addra(addra),
                                             addrb(addrb),
                                             doutb(doutb)
                                            );
*/                        