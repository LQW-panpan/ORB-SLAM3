`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/11/11 10:30:33
// Design Name: 
// Module Name: Feature_Even
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

`define win_size 11

module Feature_Even(
    input clk,
    input rst_n,
    
    // input cfg config axis 
    input [31:0] cfg_tdata,
    input        cfg_tvalid,
    input        cfg_tlast,
    input        cfg_tuser,
    input [3:0]  cfg_tkeep,
    output       cfg_tready,
    // input fast data axis 
    input [7:0]  fast_tdata,
    input        fast_tvalid,
    input        fast_tlast,
    input        fast_tuser,
    input [0:0]  fast_tkeep,
    output       fast_tready,
    // input pixel data axis 
    input [7:0]  pixel_tdata,
    input        pixel_tvalid,
    input        pixel_tlast,
    input        pixel_tuser,
    input [0:0]  pixel_tkeep,
    output       pixel_tready,
    
    // output cfg config axis 
    output [31:0]cfgout_tdata,
    output       cfgout_tvalid,
    output       cfgout_tlast,
    output       cfgout_tuser,
    output [3:0] cfgout_tkeep,
    input        cfgout_tready,
    // output fast data axis 
    output [31:0]fastout_tdata,
    output       fastout_tvalid,
    output       fastout_tlast,
    output       fastout_tuser,
    output [3:0] fastout_tkeep,
    input        fastout_tready,
    // output pixel data axis 
    output [31:0]pixelout_tdata,
    output       pixelout_tvalid,
    output       pixelout_tlast,
    output       pixelout_tuser,
    output [3:0] pixelout_tkeep,
    input        pixelout_tready,
    
    output reg [9:0] new_width,
    output reg [8:0] new_height,
    output reg [9:0] pos_x,
    output reg [8:0] pos_y,
    output           ready,
    output reg fastout_valid_temp,
    output reg [1:0] temp_count
    );
 
assign cfgout_tdata = cfg_tdata;
assign cfgout_tvalid = cfg_tvalid;
assign cfgout_tlast = cfg_tlast;
assign cfgout_tkeep = cfg_tkeep;
assign cfgout_tuser = cfg_tuser;
assign cfg_tready = cfgout_tready;

assign fastout_tkeep = 'b1111;
assign fastout_tuser = 'b0;

assign pixelout_tkeep = 'b1111;
assign pixelout_tuser = 'b0;

//reg [9:0] new_width;
//reg [8:0] new_height;
wire image_valid;
//wire ready;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        new_width <= 'b0;
        new_height <= 'b0;
    end
    else if(cfg_tvalid=='b1 && cfg_tlast=='b1)
        new_height <= cfg_tdata[8:0];
    else if(cfg_tvalid=='b1)
        new_width <= cfg_tdata[9:0];
    else begin
        new_width <= new_width;
        new_height <= new_height;
    end
end
//reg [9:0] pos_x;
//reg [8:0] pos_y;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        pos_x <= 'b0;
    else if(pos_x == new_width-'b1 && ready == 'b1)
        pos_x <= 'b0;
    else if(ready == 'b1)
        pos_x <= pos_x+'b1;    
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        pos_y <= 'b0;
    else if(pos_y == new_height+`win_size)
        pos_y <= 'b0; 
    else if(pos_x == new_width-'b1 && ready == 'b1)
        pos_y <= pos_y+'b1;  
end

assign image_valid = (new_width!='b0)&&(new_height!='b0);

reg [9 : 0] addra,addrb;
// add 2 becase bram read delay 2 cycles
wire [9:0] addra_plus2 = addra + 3;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        addra <= 'b0;
        addrb <= 'b0;
    end
    else if(fastout_tlast=='b1)begin
        addra <= 0;
        addrb <= 0;
    end
    else if(ready == 'b1)begin
        //=====a=====
        if(addra==new_width-1)
            addra <= 0;
        else
            addra <= addra + 1'd1;     
        //====b=====
        if(addra_plus2 > new_width-1)
            addrb <= addra_plus2 - new_width;
        else
            addrb <= addra_plus2;
    end
end
/**************************************Padding y**********************************************/
reg [5:0] window_valid_county;
reg window_valid_county_first_flag;
reg [3:0] padding_county;
reg padding_y_flag;

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        window_valid_county <= 'b0;
    else if(pos_y%'d11=='b0 && pos_x=='b1)
        window_valid_county <= window_valid_county+'b1;
    else if(fastout_tlast=='b1)
        window_valid_county <= 'b0;
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        padding_county <= 'b0;
    else if(window_valid_county*'d11>new_height && pos_x==new_width-'b1 && pos_y==new_height-'b1)
        padding_county <= window_valid_county*'d11-new_height-'b1;
    else if(fastout_tlast=='b1)
        padding_county <= 'b0;
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
       padding_y_flag <= 'b0;
    else if(pos_x==new_width-'b1 && pos_y==padding_county+new_height)
       padding_y_flag <= 'b0;  
    else if(fast_tlast=='b1)
       padding_y_flag <= 'b1;
    else
       padding_y_flag <= padding_y_flag;     
end 

/**************************************Padding y Output****************************************/
reg [3:0] padding_y_output;
reg  padding_y_output_lasting;
reg padding_y_output_flag;
reg [12:0] padding_y_output_count;
reg fastout_tlast_temp;
assign fastout_tlast = fastout_tlast_temp&fastout_tvalid;
assign pixelout_tlast = fastout_tlast;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        fastout_tlast_temp <= 'b0;
    //output last data,set fastout_tlast_temp to 1,in case new_width cannot be divided by 4
    else if(pos_x==new_width-'b1 && pos_y==new_height+`win_size-'b1) 
        fastout_tlast_temp <= 'b1;
    else 
        fastout_tlast_temp <= 'b0;
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
       padding_y_output_lasting <= 'b0;
    else if(pos_x==new_width-'b1 && pos_y==new_height+`win_size-'b1)
       padding_y_output_lasting <= 'b0;
    else if(pos_x==new_width-'b1 && pos_y==padding_county+new_height)
       padding_y_output_lasting <= 'b1;    
end
wire fast_tready_for_padding;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        padding_y_output_flag <= 'b0;
    else if(pos_x==new_width-'b1 && pos_y==new_height+`win_size-'b1)
        padding_y_output_flag <= 'b0;
    else if(padding_y_output_lasting && fast_tready_for_padding)
        padding_y_output_flag <= 'b1;
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
       padding_y_output <= 'b0;
    else if(pos_x==new_width-'b1 && pos_y==padding_county+new_height)
       padding_y_output <= `win_size-padding_county-'b1;  
    else if(pos_x==new_width-'b1 && pos_y==new_height+`win_size-'b1)
       padding_y_output <= 'b0;     
end 
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
       padding_y_output_count <= 'b0;
    else if(padding_y_output_flag=='b1)
       padding_y_output_count <= padding_y_output_count+'b1; 
    else if(fastout_tlast=='b1)
       padding_y_output_count <= 'b0;      
end

assign ready = (fast_tready && fast_tvalid && pixel_tvalid && image_valid) || padding_y_flag || padding_y_output_flag; 

wire [7:0] linebuffer_fast_in[0:`win_size-1];
wire [7:0] linebuffer_fast_out[0:`win_size-1];
wire [7:0] linebuffer_pixel_in[0:`win_size-1];
wire [7:0] linebuffer_pixel_out[0:`win_size-1];
  
assign linebuffer_fast_in[0] = (fast_tdata[0]=='b1)?fast_tdata:'b0;
assign linebuffer_pixel_in[0] = pixel_tdata;
genvar k;
generate
    for (k=1;k<`win_size;k=k+1) begin
        assign linebuffer_fast_in[k] = linebuffer_fast_out[k-1];
        assign linebuffer_pixel_in[k] = linebuffer_pixel_out[k-1];
    end
endgenerate

generate
    for (k=0;k<`win_size;k=k+1) begin
      line_buffer inst_fast (
      .clka(clk),    // input wire clka
      .ena(ready),      // input wire ena
      .wea(ready),      // input wire [0 : 0] wea
      .addra(addra),  // input wire [9 : 0] addra
      .dina(linebuffer_fast_in[k]),    // input wire [7 : 0] dina
      
      .clkb(clk),    // input wire clkb
      .enb(ready),      // input wire enb
      .addrb(addrb),  // input wire [9 : 0] addrb
      .doutb(linebuffer_fast_out[k])  // output wire [7 : 0] doutb
    );
      line_buffer inst_pixel (
      .clka(clk),    // input wire clka
      .ena(ready),      // input wire ena
      .wea(ready),      // input wire [0 : 0] wea
      .addra(addra),  // input wire [9 : 0] addra
      .dina(linebuffer_pixel_in[k]),    // input wire [7 : 0] dina
      
      .clkb(clk),    // input wire clkb
      .enb(ready),      // input wire enb
      .addrb(addrb),  // input wire [9 : 0] addrb
      .doutb(linebuffer_pixel_out[k])  // output wire [7 : 0] doutb
    );
    end
endgenerate

/**************************************Padding x**********************************************/
reg [7:0] window_valid_countx;
reg window_valid_countx_first_flag_random;
reg [3:0] padding_countx;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        window_valid_countx_first_flag_random <= 'b0;      
    else if(fast_tvalid=='b1)
        window_valid_countx_first_flag_random <= 'b0;
    else if((pos_y+'b1)%'d11=='b0 && pos_x%'d11=='b0&& fast_tready=='b1)
        window_valid_countx_first_flag_random <= 'b1;
end
// for simple y
wire window_valid_countx_flag1_random;
assign window_valid_countx_flag1_random = fast_tready=='b1 && window_valid_countx_first_flag_random=='b0;
// for padding y
wire window_valid_countx_flag2_random;
assign window_valid_countx_flag2_random = new_height!='b0 && pos_y>=new_height;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        window_valid_countx <= 'b0;
    else if(fastout_tlast=='b1)
        window_valid_countx <= 'b0;
    else if(pos_y%'d11=='b0 && padding_countx == window_valid_countx*'d11-new_width)
        window_valid_countx <= 'b0;
    else if((pos_y+'b1)%'d11=='b0 && pos_x%'d11=='b0 && (window_valid_countx_flag1_random||window_valid_countx_flag2_random))
        window_valid_countx <= window_valid_countx+'b1;
    
end
reg [7:0] window[`win_size-1:0][`win_size-1:0];
reg posx_flag_random;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        posx_flag_random <= 'b0;
    else if(pos_x==new_width-'b1 && new_width!='b0)
        posx_flag_random <= 'b1;
    else if(pos_x=='d16)
        posx_flag_random <= 'b0;
end

integer i,j;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        for(i=0;i<`win_size;i=i+1)begin
            for(j=0;j<`win_size;j=j+1)begin
                window[i][j] <= 'b0;
            end
        end
        padding_countx <= 'b0;
    end
    else if(padding_countx == window_valid_countx*'d11-new_width)
        padding_countx <= 'b0;
    else if(ready == 'b1 || (window_valid_countx*'d11>new_width)&&(posx_flag_random=='b1))begin
        for(i=0;i<`win_size;i=i+1)begin
            if(ready == 'b1) begin
                window[i][`win_size-1] <= linebuffer_fast_in[`win_size-'b1-i];
                for(j=`win_size-1;j>0;j=j-1)begin
                    window[i][j-1] <=  window[i][j];
                end
            end            
            else if(window_valid_countx*'d11>new_width)begin
                window[i][`win_size-1] <= 'b0;
                for(j=`win_size-1;j>0;j=j-1)begin
                    window[i][j-1] <=  window[i][j];
                end
                padding_countx <= padding_countx+'b1;
            end             
        end
    end
end

//fast_tready is used to control x padding
wire fast_out_last;
assign fast_out_last = new_height!='b0 && pos_y>=new_height;
//assign fast_tready = ((window_valid_countx*'d11>=new_width)&&(pos_x=='b0))||fast_out_last?'b0:'b1;
assign fast_tready = fastout_tready?(((window_valid_countx*'d11>=new_width)&&(pos_x=='b0))||fast_out_last?'b0:'b1):'b0;
//assign fast_tready = fastout_tready;
assign fast_tready_for_padding = ((window_valid_countx*'d11>=new_width)&&(pos_x==new_width-'b1||pos_x=='b0))?'b0:'b1;
assign pixel_tready = fast_tready&&pixelout_tready;
//assign pixel_tready = pixelout_tready;

integer m,n;
reg [7:0] max0_col[`win_size-1:0][5:0];
reg [3:0] max0_col_index[`win_size-1:0][5:0];
reg [7:0] max1_col[`win_size-1:0][2:0];
reg [3:0] max1_col_index[`win_size-1:0][2:0];
reg [7:0] max_col[`win_size-1:0];
reg [3:0] max_col_index[`win_size-1:0];

reg [7:0] max0_row[5:0];
reg [3:0] max0_row_col_index[5:0];
reg [3:0] max0_row_index[5:0];
reg [7:0] max1_row[2:0];
reg [3:0] max1_row_col_index[2:0];
reg [3:0] max1_row_index[2:0];
reg [7:0] max_row;
reg [3:0] max_row_col_index;
reg [3:0] max_row_index;
/**************************************Level 6 Comparison Tree**********************************************/
always@(posedge clk)begin
    //===========max0_col===========//
    for(m=0;m<`win_size;m=m+1)begin
        for(n=0;n<5;n=n+1)begin
            if(window[m][2*n]>=window[m][2*n+1])begin
                max0_col[m][n] <= window[m][2*n];
                max0_col_index[m][n] <= 2*n; 
            end
            else begin
                max0_col[m][n] <= window[m][2*n+1];
                max0_col_index[m][n] <= 2*n+1; 
            end     
        end
        max0_col[m][5] <= window[m][10];
        max0_col_index[m][5] <= 'd10;    
    end
    //===========max1_col===========//
    for(m=0;m<`win_size;m=m+1)begin
        for(n=0;n<3;n=n+1)begin
            if(max0_col[m][2*n]>=max0_col[m][2*n+1])begin
                max1_col[m][n] <= max0_col[m][2*n];
                max1_col_index[m][n] <= max0_col_index[m][2*n]; 
            end
            else begin
                max1_col[m][n] <= max0_col[m][2*n+1];
                max1_col_index[m][n] <= max0_col_index[m][2*n+1]; 
            end     
        end  
    end
    //===========max_col===========//
    for(m=0;m<`win_size;m=m+1)begin
        if(max1_col[m][0]>=max1_col[m][1] && max1_col[m][0]>=max1_col[m][2])begin
            max_col[m] <= max1_col[m][0];
            max_col_index[m] <= max1_col_index[m][0]; 
        end
        else if(max1_col[m][1]>=max1_col[m][0] && max1_col[m][1]>=max1_col[m][2])begin
            max_col[m] <= max1_col[m][1];
            max_col_index[m] <= max1_col_index[m][1]; 
        end
        else if(max1_col[m][2]>=max1_col[m][0] && max1_col[m][2]>=max1_col[m][1])begin
            max_col[m] <= max1_col[m][2];
            max_col_index[m] <= max1_col_index[m][2];
        end          
    end
    //===========max0_row===========//
    for(n=0;n<5;n=n+1)begin
        if(max_col[2*n]>=max_col[2*n+1])begin
            max0_row[n] <= max_col[2*n];
            max0_row_col_index[n] <= max_col_index[2*n];
            max0_row_index[n] <= 2*n; 
        end
        else begin
            max0_row[n] <= max_col[2*n+1];
            max0_row_col_index[n] <= max_col_index[2*n+1];
            max0_row_index[n] <= 2*n+1;  
        end     
    end
    max0_row[5] <= max_col[10];
    max0_row_col_index[5] <= max_col_index[10];
    max0_row_index[5] <= 'd10; 
    //===========max1_row===========//
    for(n=0;n<3;n=n+1)begin
        if(max0_row[2*n]>=max0_row[2*n+1])begin
            max1_row[n] <= max0_row[2*n];
            max1_row_col_index[n] <= max0_row_col_index[2*n];
            max1_row_index[n] <= max0_row_index[2*n]; 
        end
        else begin
            max1_row[n] <= max0_row[2*n+1];
            max1_row_col_index[n] <= max0_row_col_index[2*n+1];
            max1_row_index[n] <= max0_row_index[2*n+1];  
        end     
    end
    //===========max_row===========//
    if(max1_row[0]>=max1_row[1] && max1_row[0]>=max1_row[2])begin
        max_row <= max1_row[0];
        max_row_col_index <= max1_row_col_index[0];
        max_row_index <= max1_row_index[0];
    end
    else if(max1_row[1]>=max1_row[0] && max1_row[1]>=max1_row[2])begin
        max_row <= max1_row[1];
        max_row_col_index <= max1_row_col_index[1];
        max_row_index <= max1_row_index[1];
    end
    else if(max1_row[2]>=max1_row[0] && max1_row[2]>=max1_row[1])begin
        max_row <= max1_row[2];
        max_row_col_index <= max1_row_col_index[2];
        max_row_index <= max1_row_index[2];
    end
end

reg [6:0] max_row_valid;
reg [8:0] padding_max_row_valid;
reg [0:0] padding_max_row_valid_last;
//fast_max_valid_count is different from window_valid_countx
//fast_max_valid_count is used to indicate assigning fast_valid,always smaller than window_valid_countx
reg [7:0] fast_max_valid_count;
reg fast_valid[`win_size-1:0][639:0];
//when clear fast_valid for next 11row homogenize,last 11row surplus the last row to output
//so need one temp data to store the last row fast_valid data
reg fast_valid_lastrow[639:0];
integer p,q;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        max_row_valid <= 'b0;
    else if((pos_y+'b1)%'d11=='b0 && (pos_x+'b1)%'d11=='b0)
        max_row_valid <= 'b1;
    else 
        max_row_valid <= {max_row_valid[5:0],1'b0}; 
end  
//every 11 rows last window may less than 11,so padding with 0
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        padding_max_row_valid <= 'b0;
        padding_max_row_valid_last <= 'b0;
    end
    else if(padding_countx == window_valid_countx*'d11-new_width-'b1)
        padding_max_row_valid <= 'b1;
    else begin
        padding_max_row_valid <= {padding_max_row_valid[7:0],1'b0}; 
        padding_max_row_valid_last <= padding_max_row_valid[8];
    end
end 
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        fast_max_valid_count <= 'b0;
    else if(padding_max_row_valid_last=='b1 && padding_max_row_valid[8]=='b0)
        fast_max_valid_count <= 'b0;
    else if(max_row_valid[5]=='b1 || padding_max_row_valid[7]=='b1)
        fast_max_valid_count <= fast_max_valid_count+'b1;
    else if(fastout_tlast=='b1)
        fast_max_valid_count <= 'b0; 
    else 
        fast_max_valid_count <= fast_max_valid_count; 
end  
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        for(q=0;q<`win_size;q=q+1)begin
            for(p=0;p<640;p=p+1)begin
                fast_valid[q][p] <= 'b0;
            end
        end
    end
    else if(max_row_valid[6]=='b1 || padding_max_row_valid[8]=='b1)begin
        if(max_row!='b0)
            fast_valid[max_row_index][max_row_col_index+'d11*(fast_max_valid_count-'b1)] <= 'b1;
    end
    else if((pos_y+'b1)%'d11=='b0 && pos_x=='b0)begin
        for(q=0;q<`win_size;q=q+1)begin
            for(p=0;p<640;p=p+1)begin
                fast_valid[q][p] <= 'b0;
            end
        end
    end
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        for(p=0;p<640;p=p+1)begin
            fast_valid_lastrow[p] <= 'b0;
        end
    end
    else if(pos_y%'d11=='b0 && pos_x=='d11)begin
        for(p=0;p<640;p=p+1)begin
            fast_valid_lastrow[p] <= fast_valid['d10][p];
        end
    end
    else if(pos_y%'d11=='b0 && pos_x=='d10)begin
        for(p=0;p<640;p=p+1)begin
            fast_valid_lastrow[p] <= 'b0;
        end
    end
end
reg [31:0] fastout_tdata_temp;
reg [31:0] pixelout_tdata_temp;
//reg [1:0] temp_count;
reg temp_valid;
reg [12:0] fast_valid_count;
//reg fastout_valid_temp;
reg [3:0] fast_valid_row;
reg [9:0] fast_valid_col;
wire row_add,row_add0,row_add1,row_add2,row_add3,row_add4,row_add5,row_add6,row_add7;
assign row_add0 = fast_valid_col=='d639 && new_width=='d640;
assign row_add1 = fast_valid_col=='d532 && new_width=='d533;
assign row_add2 = fast_valid_col=='d456 && new_width=='d457;
assign row_add3 = fast_valid_col=='d375 && new_width=='d376;
assign row_add4 = fast_valid_col=='d319 && new_width=='d320;
assign row_add5 = fast_valid_col=='d265 && new_width=='d266;
assign row_add6 = fast_valid_col=='d219 && new_width=='d220;
assign row_add7 = fast_valid_col=='d181 && new_width=='d182;
assign row_add = row_add0||row_add1||row_add2||row_add3||row_add4||row_add5||row_add6||row_add7;

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        fast_valid_col <= 'b0;
    else if(fastout_tlast=='b1)
        fast_valid_col <= 'b0;
    else if(new_width=='d640 && fast_valid_col=='d639 && fastout_valid_temp=='b1 && ready=='b1)
        fast_valid_col <= 'b0;
    else if(new_width=='d533 && fast_valid_col=='d532 && fastout_valid_temp=='b1 && ready=='b1)
        fast_valid_col <= 'b0;
    else if(new_width=='d457 && fast_valid_col=='d456 && fastout_valid_temp=='b1 && ready=='b1)
        fast_valid_col <= 'b0;
    else if(new_width=='d376 && fast_valid_col=='d375 && fastout_valid_temp=='b1 && ready=='b1)
        fast_valid_col <= 'b0;
    else if(new_width=='d320 && fast_valid_col=='d319 && fastout_valid_temp=='b1 && ready=='b1)
        fast_valid_col <= 'b0;
    else if(new_width=='d266 && fast_valid_col=='d265 && fastout_valid_temp=='b1 && ready=='b1)
        fast_valid_col <= 'b0;
    else if(new_width=='d220 && fast_valid_col=='d219 && fastout_valid_temp=='b1 && ready=='b1)
        fast_valid_col <= 'b0;
    else if(new_width=='d182 && fast_valid_col=='d181 && fastout_valid_temp=='b1 && ready=='b1)
        fast_valid_col <= 'b0;
    else if(fastout_valid_temp=='b1 && ready=='b1)
        fast_valid_col <= fast_valid_col+'b1;
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        fast_valid_row <= 'b0;
    else if(fastout_tlast=='b1)
        fast_valid_row <= 'b0;
    else if(new_width=='d640 && fast_valid_col=='d639 && fast_valid_row=='d10 && fastout_valid_temp=='b1 && ready=='b1)
        fast_valid_row <= 'b0;
    else if(new_width=='d533 && fast_valid_col=='d532 && fast_valid_row=='d10 && fastout_valid_temp=='b1 && ready=='b1)
        fast_valid_row <= 'b0;
    else if(new_width=='d457 && fast_valid_col=='d456 && fast_valid_row=='d10 && fastout_valid_temp=='b1 && ready=='b1)
        fast_valid_row <= 'b0;
    else if(new_width=='d376 && fast_valid_col=='d375 && fast_valid_row=='d10 && fastout_valid_temp=='b1 && ready=='b1)
        fast_valid_row <= 'b0;
    else if(new_width=='d320 && fast_valid_col=='d319 && fast_valid_row=='d10 && fastout_valid_temp=='b1 && ready=='b1)
        fast_valid_row <= 'b0;
    else if(new_width=='d266 && fast_valid_col=='d265 && fast_valid_row=='d10 && fastout_valid_temp=='b1 && ready=='b1)
        fast_valid_row <= 'b0;
    else if(new_width=='d220 && fast_valid_col=='d219 && fast_valid_row=='d10 && fastout_valid_temp=='b1 && ready=='b1)
        fast_valid_row <= 'b0;
    else if(new_width=='d182 && fast_valid_col=='d181 && fast_valid_row=='d10 && fastout_valid_temp=='b1 && ready=='b1)
        fast_valid_row <= 'b0;
    else if(fastout_valid_temp=='b1 && ready=='b1 && row_add=='b1)
        fast_valid_row <= fast_valid_row+'b1;
end

reg fastout_valid_temp_last,fastout_valid_temp_now;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        fastout_valid_temp_last <= 'b0;
    else if(fastout_tlast=='b1)
        fastout_valid_temp_last <= 'b0;
    else if(fastout_valid_temp_now=='b1)
        fastout_valid_temp_last <= 'b1;
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        fastout_valid_temp_now <= 'b0;
    else if(fastout_tlast=='b1)
        fastout_valid_temp_now <= 'b0;
    else if(pos_y%'d11=='b0 && pos_x=='b0 && pos_y!='b0)
        fastout_valid_temp_now <= 'b1;
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        fastout_valid_temp <= 'b0;
    else if(fastout_tlast=='b1)
        fastout_valid_temp <= 'b0;
    else if(fastout_valid_temp_now=='b1 && fastout_valid_temp_last=='b0)
        fastout_valid_temp <= 'b1;
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        fastout_tdata_temp <= 'b0;
        pixelout_tdata_temp <= 'b0;
        temp_count <= 'b0;
    end
    //all data that exceeds one line but is less than 32 bits must be filled with zeros
    else if(fastout_valid_temp=='b1 && ready=='b1 && pos_x==new_width-'b1)begin
        if(temp_count == 'd0)begin
            if(fast_valid_row=='d10)
                fastout_tdata_temp[31:0] <= (fast_valid_lastrow[fast_valid_col]=='b1)?{24'b0,linebuffer_fast_out[10]}:'b0;
            else 
                fastout_tdata_temp[31:0] <= (fast_valid[fast_valid_row][fast_valid_col]=='b1)?{24'b0,linebuffer_fast_out[10]}:'b0;
            pixelout_tdata_temp[31:0] <= {24'b0,linebuffer_pixel_out[10]};
            temp_count <= 'd0;
        end
        else if(temp_count == 'd1)begin
            if(fast_valid_row=='d10)
                fastout_tdata_temp[31:8] <= (fast_valid_lastrow[fast_valid_col]=='b1)?{16'b0,linebuffer_fast_out[10]}:'b0;
            else 
                fastout_tdata_temp[31:8] <= (fast_valid[fast_valid_row][fast_valid_col]=='b1)?{16'b0,linebuffer_fast_out[10]}:'b0;
            pixelout_tdata_temp[31:8] <= {16'b0,linebuffer_pixel_out[10]};
            temp_count <= 'd0;
        end
        else if(temp_count == 'd2)begin
            if(fast_valid_row=='d10)
                fastout_tdata_temp[31:16] <= (fast_valid_lastrow[fast_valid_col]=='b1)?{8'b0,linebuffer_fast_out[10]}:'b0;
            else 
                fastout_tdata_temp[31:16] <= (fast_valid[fast_valid_row][fast_valid_col]=='b1)?{8'b0,linebuffer_fast_out[10]}:'b0;
            pixelout_tdata_temp[31:16] <= {8'b0,linebuffer_pixel_out[10]};
            temp_count <= 'd0;
        end
        else if(temp_count == 'd3)begin
            if(fast_valid_row=='d10)
                fastout_tdata_temp[31:24] <= (fast_valid_lastrow[fast_valid_col]=='b1)?linebuffer_fast_out[10]:'b0;
            else 
                fastout_tdata_temp[31:24] <= (fast_valid[fast_valid_row][fast_valid_col]=='b1)?linebuffer_fast_out[10]:'b0;
            pixelout_tdata_temp[31:24] <= linebuffer_pixel_out[10];
            temp_count <= 'd0;
        end
    end
    else if(fastout_valid_temp=='b1 && ready=='b1)begin
        if(temp_count == 'd0)begin
            if(fast_valid_row=='d10)
                fastout_tdata_temp[7:0] <= (fast_valid_lastrow[fast_valid_col]=='b1)?linebuffer_fast_out[10]:'b0;
            else 
                fastout_tdata_temp[7:0] <= (fast_valid[fast_valid_row][fast_valid_col]=='b1)?linebuffer_fast_out[10]:'b0;
            pixelout_tdata_temp[7:0] <= linebuffer_pixel_out[10];
            temp_count <= 'd1;
        end
        else if(temp_count == 'd1)begin
            if(fast_valid_row=='d10)
                fastout_tdata_temp[15:8] <= (fast_valid_lastrow[fast_valid_col]=='b1)?linebuffer_fast_out[10]:'b0;
            else 
                fastout_tdata_temp[15:8] <= (fast_valid[fast_valid_row][fast_valid_col]=='b1)?linebuffer_fast_out[10]:'b0;
            pixelout_tdata_temp[15:8] <= linebuffer_pixel_out[10];
            temp_count <= 'd2;
        end
        else if(temp_count == 'd2)begin
            if(fast_valid_row=='d10)
                fastout_tdata_temp[23:16] <= (fast_valid_lastrow[fast_valid_col]=='b1)?linebuffer_fast_out[10]:'b0;
            else 
                fastout_tdata_temp[23:16] <= (fast_valid[fast_valid_row][fast_valid_col]=='b1)?linebuffer_fast_out[10]:'b0;
            pixelout_tdata_temp[23:16] <= linebuffer_pixel_out[10];
            temp_count <= 'd3;
        end
        else if(temp_count == 'd3)begin
            if(fast_valid_row=='d10)
                fastout_tdata_temp[31:24] <= (fast_valid_lastrow[fast_valid_col]=='b1)?linebuffer_fast_out[10]:'b0;
            else 
                fastout_tdata_temp[31:24] <= (fast_valid[fast_valid_row][fast_valid_col]=='b1)?linebuffer_fast_out[10]:'b0;
            pixelout_tdata_temp[31:24] <= linebuffer_pixel_out[10];
            temp_count <= 'd0;
        end
    end
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        fast_valid_count <= 'b0; 
    else if(fastout_valid_temp=='b1 && ready=='b1)
        fast_valid_count <= fast_valid_count+'b1;
    else if(fast_valid_count==new_width*`win_size || fastout_tlast=='b1)
        fast_valid_count <= 'b0;
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        temp_valid <= 'b0;
    else if(fastout_valid_temp=='b1 && ready=='b1 && (temp_count=='d3 || pos_x==new_width-'b1))
        temp_valid <= 'b1;
    else
        temp_valid <= 'b0; 
end

assign fastout_tvalid = temp_valid;
assign fastout_tdata = (temp_valid=='b1)?fastout_tdata_temp:'b0;

assign pixelout_tvalid = temp_valid; 
assign pixelout_tdata = (temp_valid=='b1)?pixelout_tdata_temp:'b0;

endmodule
