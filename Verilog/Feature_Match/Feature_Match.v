`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/10/24 22:07:42
// Design Name: 
// Module Name: Feature_Match
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
`define MATCH_NUM 200
`define BACK_NUM 100
`define FORWARD_NUM 100

module Feature_Match(
    input clk,
    input rst_n,
    // input rs_brief axis 
    input [511:0] I_AXIS_tdata,
    input         I_AXIS_tvalid,
    input         I_AXIS_tlast,
    input         I_AXIS_tuser,
    input [63:0]  I_AXIS_tkeep,
    output        I_AXIS_tready,
    // ouput match pixels to dma axis
    output [63:0] O_AXIS_tdata,
//    output [63:0] O_AXIS_tdata_test,
    output        O_AXIS_tvalid,
    output        O_AXIS_tlast,
    output        O_AXIS_tuser,
    output [7:0]  O_AXIS_tkeep,
    input         O_AXIS_tready,
//    output reg[511:0] left_data_vec_temp  
    output reg[9:0]   ram_addra_left,
    output reg[9:0]   ram_addra_right,
    output reg[9:0]   ram_addrb_left,
    output reg[9:0]   ram_addrb_right,
    output reg[5:0]   min_dist_valid,
    output reg        right_last_flag

    );
wire  rd_en_left,rd_en_right; 
wire  wea_left,wea_right;
wire  [511:0] dina_left;
wire  [511:0] dina_right; 
// depth = 1000     
//reg  [9:0]   ram_addra_left;
//reg  [9:0]   ram_addra_right;
//reg  [9:0]   ram_addrb_left;
//reg  [9:0]   ram_addrb_right;

wire o_valid_left,o_valid_right;
wire [511:0] doutb_left;
wire [511:0] doutb_right;
 
integer i,j;
  
reg select;  //0---left,1---right
// to save fpga resource,devide left_data_vec into 2 data
reg [255:0] left_data_vec_rsbrief[`MATCH_NUM-1:0];
reg [34:0]  left_data_vec_data[`MATCH_NUM-1:0];
reg [3:0]   i_tlast_count;

/******************************* write to uram *******************************/

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        select <= 'b0;
    else if(I_AXIS_tlast=='b1 && select=='b0)
        select <= 'b1;
    else if(O_AXIS_tlast=='b1 && select=='b1)
        select <= 'b0;
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        i_tlast_count <= 'b0;
    else if(I_AXIS_tlast=='b1)
        i_tlast_count <= i_tlast_count+'b1;
    else if(O_AXIS_tlast=='b1)
        i_tlast_count <= 'b0;
    else
        i_tlast_count <= i_tlast_count;
end

assign wea_left = I_AXIS_tvalid?((select==1'b0)?(1'b1):(1'b0)):(1'b0);
assign wea_right = I_AXIS_tvalid?((select==1'b1)?(1'b1):(1'b0)):(1'b0); 
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        ram_addra_left <= 'b0;
    else if(O_AXIS_tlast==1'b1)
        ram_addra_left <= 'b0;
    else if(wea_left==1'b1)
        ram_addra_left <= ram_addra_left+1'b1;
    else
        ram_addra_left <= ram_addra_left;
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        ram_addra_right <= 'b0;
    else if(O_AXIS_tlast==1'b1)
        ram_addra_right <= 'b0;
    else if(wea_right==1'b1)
        ram_addra_right <= ram_addra_right+1'b1;
    else
        ram_addra_right <= ram_addra_right;
end

assign dina_left = wea_left?I_AXIS_tdata:512'b0; 
assign dina_right = wea_right?I_AXIS_tdata:512'b0;

//when left feature starts to transmit,also start to cache feature points
reg [7:0] count_left;
reg [9:0] count_right;
reg [511:0] left_data_vec_temp;
reg [511:0] I_AXIS_tdata_reg;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        I_AXIS_tdata_reg <= 'b0;
    else if(I_AXIS_tvalid==1'b1)
        I_AXIS_tdata_reg <= I_AXIS_tdata;
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        count_left <= 'b0;
    else if(O_AXIS_tlast==1'b1)
        count_left <= 'b0;
    else if(wea_left==1'b1 && count_left<`MATCH_NUM)
        count_left <= count_left+1'b1;
    else
        count_left <= count_left;
end
reg O_AXIS_tlast_dalay;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        O_AXIS_tlast_dalay <= 'b0;
    else if(O_AXIS_tlast==1'b1)
        O_AXIS_tlast_dalay <= 'b1;
    else
        O_AXIS_tlast_dalay <= 'b0;
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        for(i=0;i<`MATCH_NUM;i=i+1)begin
            left_data_vec_rsbrief[i] <= 'b0;
            left_data_vec_data[i] <= 'b0;
        end
        left_data_vec_temp <= 512'b0;
    end
    else if(O_AXIS_tlast_dalay=='b1)begin
        for(i=0;i<`MATCH_NUM;i=i+1)begin
            left_data_vec_rsbrief[i] <= 'b0;
            left_data_vec_data[i] <= 'b0;
        end
        left_data_vec_temp <= 512'b0;
    end
    else if(wea_left==1'b1 && count_left<`MATCH_NUM)begin
        left_data_vec_data[count_left] <= I_AXIS_tdata[34:0];
        left_data_vec_rsbrief[count_left] <= I_AXIS_tdata[290:35];
        left_data_vec_temp <= I_AXIS_tdata;
    end
    else if(o_valid_left==1'b1 && count_right>=`BACK_NUM )begin
        left_data_vec_data[count_right-`BACK_NUM] <= doutb_left[34:0];
        left_data_vec_rsbrief[count_right-`BACK_NUM] <= doutb_left[290:35]; 
        left_data_vec_temp <= doutb_left;
    end   
end

/******************************* read from uram *******************************/
// when left feature successfully transfered and right image ready to transfer begin feature matching

wire     add2_valid_flip;
reg [3:0]first_wea_right_flag;
reg reset_count_right;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        reset_count_right <= 'b0;
    else if(O_AXIS_tlast==1'b1 && select=='b1)
        reset_count_right <= 'b1;
    else if(select=='b0)
        reset_count_right <= 'b0;
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        count_right <= 'b0;
    else if(reset_count_right==1'b1)
        count_right <= 'b0;
    else if(count_right==`BACK_NUM+`MATCH_NUM)
        count_right <= `BACK_NUM;
    else if(wea_right==1'b1&&count_right=='b0)
        count_right <= count_right+1'b1;
    else if(o_valid_left==1'b1)
        count_right <= count_right+1'b1;
end
reg [10:0] delay_11;
reg        add2_valid_flip_flag;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        first_wea_right_flag <= 'b0;
//    else if(wea_right==1'b1&&count_right=='b0)
//        first_wea_right_flag <= 1'b1;
    else if(I_AXIS_tvalid==1'b1 && select=='b1 && add2_valid_flip_flag=='b0 && first_wea_right_flag=='b0)
        first_wea_right_flag <= 1'b1;
    else if(I_AXIS_tlast==1'b1)
        first_wea_right_flag <= 'b0;
    else
        first_wea_right_flag <= {first_wea_right_flag[2:0],1'b0};   
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        delay_11 <= 'b0;
//    else if(add2_valid_flip=='b1 && ram_addrb_right<ram_addra_right && delay_18=='b0)
    else if(o_valid_right=='b1 && ram_addrb_right<=ram_addra_right && delay_11=='b0)
        delay_11 <= 'b1;
    else
        delay_11 <= {delay_11[10:0],1'b0};    
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        add2_valid_flip_flag <= 'b0;
    else if(delay_11[10]=='b1)
        add2_valid_flip_flag <= 'b0;
    else if(rd_en_right=='b1 && ram_addrb_right<=ram_addra_right)
        add2_valid_flip_flag <= 'b1;   
end

//reg right_last_flag;
// after compute hanming distance
assign rd_en_left = (add2_valid_flip=='b1)?1'b1:1'b0;
//condition1.void situation that read faster than write 
//condition2.uram is read first,so read after write one cycle 
//continuous data;separated data;last data
wire continuous_data_flag,separated_data_flag,last_data_flag;
assign continuous_data_flag = add2_valid_flip=='b1 && ram_addrb_right<ram_addra_right;
assign separated_data_flag = first_wea_right_flag[3]=='b1 && add2_valid_flip_flag=='b0 && ram_addrb_right<=ram_addra_right && delay_11=='b0;
assign last_data_flag = i_tlast_count=='d200 && ram_addrb_right<ram_addra_right;

assign rd_en_right = (continuous_data_flag)?1'b1:((separated_data_flag)?1'b1:(last_data_flag)?1'b1:1'b0);

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        ram_addrb_left <= `BACK_NUM;
    else if(rd_en_left==1'b1 && ram_addrb_left<ram_addra_left-'b1)
        ram_addrb_left <= ram_addrb_left+1'b1;
    else if(O_AXIS_tlast==1'b1)
        ram_addrb_left <= 'b0;
    else
        ram_addrb_left <= ram_addrb_left;
end 
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        ram_addrb_right <= 'b0;
    else if(rd_en_right==1'b1)
        ram_addrb_right <= ram_addrb_right+1'b1;
    else if(O_AXIS_tlast==1'b1)
        ram_addrb_right <= 'b0;
    else
        ram_addrb_right <= ram_addrb_right;
end


reg [8:0]   pixel_left_x,pixel_right_x;
reg [9:0]   pixel_left_y,pixel_right_y;

/******************************* compute hanming distance *******************************/ 
wire [255:0] right_temp;
reg         hanming_dist_vec_flag;
reg [255:0] hanming_dist_vec[`MATCH_NUM-1:0];
reg         o_valid_right_delayed;
reg [3:0]   right_temp_last_time;

assign right_temp = (o_valid_right=='b1||right_temp_last_time!='b0)?doutb_right[290:35]:'b0;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        o_valid_right_delayed <= 'b0;
    else if(o_valid_right=='b1)
        o_valid_right_delayed <= 'b1;
    else
        o_valid_right_delayed <= 'b0;
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        right_temp_last_time <= 'b0;
    else if(o_valid_right=='b1)
        right_temp_last_time <= 'b1;
    else if(right_temp_last_time=='b1)
        right_temp_last_time <= 'd2;
    else if(right_temp_last_time=='d2)
        right_temp_last_time <= 'd3;
    else if(right_temp_last_time=='d3)
        right_temp_last_time <= 'd4;
    else
        right_temp_last_time <= 'b0;
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        hanming_dist_vec_flag <= 'b0;
        pixel_right_x <= 'b0;
        pixel_right_y <= 'b0;
    end
    else if(O_AXIS_tlast==1'b1)begin
        hanming_dist_vec_flag <= 'b0;
        pixel_right_x <= 'b0;
        pixel_right_y <= 'b0;
        for(i=0;i<`MATCH_NUM;i=i+1)begin
              hanming_dist_vec[i] <= 'b0;       
        end
    end
    else if(o_valid_right_delayed=='b1)begin
        hanming_dist_vec_flag <= 'b1;
        pixel_right_x <= doutb_right[24:16];
        pixel_right_y <= doutb_right[34:25];
        for(i=0;i<`MATCH_NUM;i=i+1)begin
              hanming_dist_vec[i] <= right_temp ^ left_data_vec_rsbrief[i];       
        end
    end
    else
        hanming_dist_vec_flag <= 'b0;    
end
//wire [3:0]hanming_dist_add0[`MATCH_NUM-1:0][31:0];
//genvar r,q;
//generate
//    for(q=0;q<`MATCH_NUM;q=q+1)begin
//        for(r=0;r<32;r=r+1)begin
//            assign hanming_dist_add0[q][r]=hanming_dist_vec[q][8*r+0]+hanming_dist_vec[q][8*r+1]+hanming_dist_vec[q][8*r+2]+hanming_dist_vec[q][8*r+3]+hanming_dist_vec[q][8*r+4]+hanming_dist_vec[q][8*r+5]+hanming_dist_vec[q][8*r+6]+hanming_dist_vec[q][8*r+7];
//        end 
//    end
//endgenerate
reg [3:0]hanming_dist_add0[`MATCH_NUM-1:0][31:0];
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        for(j=0;j<`MATCH_NUM;j=j+1)begin
            for(i=0;i<32;i=i+1)begin
               hanming_dist_add0[j][i] <= 'b0; 
            end
        end
    end
    else begin
        for(j=0;j<`MATCH_NUM;j=j+1)begin
            for(i=0;i<32;i=i+1)begin
                hanming_dist_add0[j][i] <= hanming_dist_vec[j][8*i+0]+hanming_dist_vec[j][8*i+1]+hanming_dist_vec[j][8*i+2]+hanming_dist_vec[j][8*i+3]+hanming_dist_vec[j][8*i+4]+hanming_dist_vec[j][8*i+5]+hanming_dist_vec[j][8*i+6]+hanming_dist_vec[j][8*i+7];
            end 
        end
    end
end

// pipeline add to save resource
reg [5:0]add0[`MATCH_NUM-1:0][7:0];//8*4=32
reg [7:0]add1[`MATCH_NUM-1:0][1:0];//8*4*4=128
reg [8:0]add2[`MATCH_NUM-1:0];//8*4*4*2=256
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        for(j=0;j<`MATCH_NUM;j=j+1)begin
            for(i=0;i<8;i=i+1)begin
               add0[j][i] <= 'b0; 
            end
        end
        for(j=0;j<`MATCH_NUM;j=j+1)begin
               add1[j][0] <= 'b0; 
               add1[j][1] <= 'b0;
               add2[j]    <= 'b0;
        end
    end
    else begin
        for(j=0;j<`MATCH_NUM;j=j+1)begin
            for(i=0;i<8;i=i+1)begin
                add0[j][i] <= hanming_dist_add0[j][4*i+0]+hanming_dist_add0[j][4*i+1]+hanming_dist_add0[j][4*i+2]+hanming_dist_add0[j][4*i+3];
            end
        end
        for(j=0;j<`MATCH_NUM;j=j+1)begin
            for(i=0;i<2;i=i+1)begin
                add1[j][i] <= add0[j][2*i+0]+add0[j][2*i+1]+add0[j][2*i+2]+add0[j][2*i+3];
            end
        end
        for(j=0;j<`MATCH_NUM;j=j+1)begin
            add2[j] <= add1[j][0]+add1[j][1];
        end
    end
end
//reg [3:0]add2_valid;
genvar q;
wire [8:0] hanming_distance[`MATCH_NUM-1:0];
generate
    for(q=0;q<`MATCH_NUM;q=q+1)begin
        assign hanming_distance[q] = add2_valid_flip ? add2[q] : 'b0;
    end
endgenerate
// delay 3 cycles
reg [4:0]add2_valid;
reg [4:0]add2_valid_last;
assign add2_valid_flip = add2_valid_last[4]=='b0 && add2_valid[3]=='b1;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        add2_valid_last <= 'b0;
    else if(add2_valid==1'b1)
        add2_valid_last <= 1'b1;
    else if(add2_valid_last==5'b10000)
        add2_valid_last <= add2_valid_last;
    else 
        add2_valid_last <= {add2_valid_last[3:0],1'b0};
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        add2_valid <= 'b0;
    else if(hanming_dist_vec_flag==1'b1)
        add2_valid <= 1'b1;
    else if(add2_valid==5'b10000)
        add2_valid <= add2_valid;
    else 
        add2_valid <= {add2_valid[3:0],1'b0};
end
/******************************* level 3 comparison tree min_dist and sub_min_dist*******************************/
reg [7:0] min_dis_0[39:0];
reg [7:0] min_dis_0_index[39:0];
reg [7:0] min_dis_1[7:0];
reg [7:0] min_dis_1_index[7:0];
reg [7:0] min_dis[1:0];
reg [7:0] min_dis_index[1:0];

reg [7:0] sub_min_dis_0[39:0];
reg [7:0] sub_min_dis_1[7:0];
reg [7:0] sub_min_dis_2[7:0];
reg [7:0] sub_min_dis_min[1:0];
reg [7:0] sub_min_dis_sub1[1:0];
reg [7:0] sub_min_dis_sub2[1:0];
reg [7:0] sub_min_dis[1:0];

wire [8:0] min_dist_new,min_dist_sub;

integer m;
always@(posedge clk)begin
    //===========min0_distance and sub_min0_distance===========//
    for(m=0;m<40;m=m+1)begin
        if(hanming_distance[5*m+0]<=hanming_distance[5*m+1] && hanming_distance[5*m+0]<=hanming_distance[5*m+2] && hanming_distance[5*m+0]<=hanming_distance[5*m+3] && hanming_distance[5*m+0]<=hanming_distance[5*m+4])begin
            min_dis_0[m] <= hanming_distance[5*m+0];
            min_dis_0_index[m] <= 5*m;
            //sub_min0 1,2,3,4
            if(hanming_distance[5*m+1]!=hanming_distance[5*m] && (hanming_distance[5*m+1]<=hanming_distance[5*m+2]||hanming_distance[5*m+2]==hanming_distance[5*m]) && (hanming_distance[5*m+1]<=hanming_distance[5*m+3]||hanming_distance[5*m+3]==hanming_distance[5*m]) && (hanming_distance[5*m+1]<=hanming_distance[5*m+4]||hanming_distance[5*m+4]==hanming_distance[5*m]))
                sub_min_dis_0[m] <= hanming_distance[5*m+1];
            else if(hanming_distance[5*m+2]!=hanming_distance[5*m] && (hanming_distance[5*m+2]<=hanming_distance[5*m+1]||hanming_distance[5*m+1]==hanming_distance[5*m]) && (hanming_distance[5*m+2]<=hanming_distance[5*m+3]||hanming_distance[5*m+3]==hanming_distance[5*m]) && (hanming_distance[5*m+2]<=hanming_distance[5*m+4]||hanming_distance[5*m+4]==hanming_distance[5*m]))
                sub_min_dis_0[m] <= hanming_distance[5*m+2];
            else if(hanming_distance[5*m+3]!=hanming_distance[5*m] && (hanming_distance[5*m+3]<=hanming_distance[5*m+1]||hanming_distance[5*m+1]==hanming_distance[5*m]) && (hanming_distance[5*m+3]<=hanming_distance[5*m+2]||hanming_distance[5*m+2]==hanming_distance[5*m]) && (hanming_distance[5*m+3]<=hanming_distance[5*m+4]||hanming_distance[5*m+4]==hanming_distance[5*m]))
                sub_min_dis_0[m] <= hanming_distance[5*m+3];
            else if(hanming_distance[5*m+4]!=hanming_distance[5*m] && (hanming_distance[5*m+4]<=hanming_distance[5*m+1]||hanming_distance[5*m+1]==hanming_distance[5*m]) && (hanming_distance[5*m+4]<=hanming_distance[5*m+2]||hanming_distance[5*m+2]==hanming_distance[5*m]) && (hanming_distance[5*m+4]<=hanming_distance[5*m+3]||hanming_distance[5*m+3]==hanming_distance[5*m]))
                sub_min_dis_0[m] <= hanming_distance[5*m+4];
            else
                sub_min_dis_0[m] <= 'b11111111;
        end
        else if(hanming_distance[5*m+1]<=hanming_distance[5*m+0] && hanming_distance[5*m+1]<=hanming_distance[5*m+2] && hanming_distance[5*m+1]<=hanming_distance[5*m+3] && hanming_distance[5*m+1]<=hanming_distance[5*m+4])begin
            min_dis_0[m] <= hanming_distance[5*m+1];
            min_dis_0_index[m] <= 5*m+1;
            //sub_min0 0,2,3,4
            if(hanming_distance[5*m+0]!=hanming_distance[5*m+1] && (hanming_distance[5*m+0]<=hanming_distance[5*m+2]||hanming_distance[5*m+2]==hanming_distance[5*m+1]) && (hanming_distance[5*m+0]<=hanming_distance[5*m+3]||hanming_distance[5*m+3]==hanming_distance[5*m+1]) && (hanming_distance[5*m+0]<=hanming_distance[5*m+4]||hanming_distance[5*m+4]==hanming_distance[5*m+1]))
                sub_min_dis_0[m] <= hanming_distance[5*m];
            else if(hanming_distance[5*m+2]!=hanming_distance[5*m+1] && (hanming_distance[5*m+2]<=hanming_distance[5*m+0]||hanming_distance[5*m+0]==hanming_distance[5*m+1]) && (hanming_distance[5*m+2]<=hanming_distance[5*m+3]||hanming_distance[5*m+3]==hanming_distance[5*m+1]) && (hanming_distance[5*m+2]<=hanming_distance[5*m+4]||hanming_distance[5*m+4]==hanming_distance[5*m+1]))
                sub_min_dis_0[m] <= hanming_distance[5*m+2];
            else if(hanming_distance[5*m+3]!=hanming_distance[5*m+1] && (hanming_distance[5*m+3]<=hanming_distance[5*m+0]||hanming_distance[5*m+0]==hanming_distance[5*m+1]) && (hanming_distance[5*m+3]<=hanming_distance[5*m+2]||hanming_distance[5*m+2]==hanming_distance[5*m+1]) && (hanming_distance[5*m+3]<=hanming_distance[5*m+4]||hanming_distance[5*m+4]==hanming_distance[5*m+1]))
                sub_min_dis_0[m] <= hanming_distance[5*m+3];
            else if(hanming_distance[5*m+4]!=hanming_distance[5*m+1] && (hanming_distance[5*m+4]<=hanming_distance[5*m+0]||hanming_distance[5*m+0]==hanming_distance[5*m+1]) && (hanming_distance[5*m+4]<=hanming_distance[5*m+2]||hanming_distance[5*m+2]==hanming_distance[5*m+1]) && (hanming_distance[5*m+4]<=hanming_distance[5*m+3]||hanming_distance[5*m+3]==hanming_distance[5*m+1]))
                sub_min_dis_0[m] <= hanming_distance[5*m+4];
            else
                sub_min_dis_0[m] <= 'b11111111;
        end
        else if(hanming_distance[5*m+2]<=hanming_distance[5*m+0] && hanming_distance[5*m+2]<=hanming_distance[5*m+1] && hanming_distance[5*m+2]<=hanming_distance[5*m+3] && hanming_distance[5*m+2]<=hanming_distance[5*m+4])begin
            min_dis_0[m] <= hanming_distance[5*m+2];
            min_dis_0_index[m] <= 5*m+2;
            //sub_min0 0,1,3,4
            if(hanming_distance[5*m+0]!=hanming_distance[5*m+2] && (hanming_distance[5*m+0]<=hanming_distance[5*m+1]||hanming_distance[5*m+1]==hanming_distance[5*m+2]) && (hanming_distance[5*m+0]<=hanming_distance[5*m+3]||hanming_distance[5*m+3]==hanming_distance[5*m+2]) && (hanming_distance[5*m+0]<=hanming_distance[5*m+4]||hanming_distance[5*m+4]==hanming_distance[5*m+2]))
                sub_min_dis_0[m] <= hanming_distance[5*m];
            else if(hanming_distance[5*m+1]!=hanming_distance[5*m+2] && (hanming_distance[5*m+1]<=hanming_distance[5*m+0]||hanming_distance[5*m+0]==hanming_distance[5*m+2]) && (hanming_distance[5*m+1]<=hanming_distance[5*m+3]||hanming_distance[5*m+3]==hanming_distance[5*m+2]) && (hanming_distance[5*m+1]<=hanming_distance[5*m+4]||hanming_distance[5*m+4]==hanming_distance[5*m+2]))
                sub_min_dis_0[m] <= hanming_distance[5*m+1];
            else if(hanming_distance[5*m+3]!=hanming_distance[5*m+2] && (hanming_distance[5*m+3]<=hanming_distance[5*m+0]||hanming_distance[5*m+0]==hanming_distance[5*m+2]) && (hanming_distance[5*m+3]<=hanming_distance[5*m+1]||hanming_distance[5*m+1]==hanming_distance[5*m+2]) && (hanming_distance[5*m+3]<=hanming_distance[5*m+4]||hanming_distance[5*m+4]==hanming_distance[5*m+2]))
                sub_min_dis_0[m] <= hanming_distance[5*m+3];
            else if(hanming_distance[5*m+4]!=hanming_distance[5*m+2] && (hanming_distance[5*m+4]<=hanming_distance[5*m+0]||hanming_distance[5*m+0]==hanming_distance[5*m+2]) && (hanming_distance[5*m+4]<=hanming_distance[5*m+1]||hanming_distance[5*m+1]==hanming_distance[5*m+2]) && (hanming_distance[5*m+4]<=hanming_distance[5*m+3]||hanming_distance[5*m+3]==hanming_distance[5*m+2]))
                sub_min_dis_0[m] <= hanming_distance[5*m+4];
            else
                sub_min_dis_0[m] <= 'b11111111;
        end
        else if(hanming_distance[5*m+3]<=hanming_distance[5*m+0] && hanming_distance[5*m+3]<=hanming_distance[5*m+1] && hanming_distance[5*m+3]<=hanming_distance[5*m+2] && hanming_distance[5*m+3]<=hanming_distance[5*m+4])begin
            min_dis_0[m] <= hanming_distance[5*m+3];
            min_dis_0_index[m] <= 5*m+3;
            //sub_min0 0,1,2,4
            if(hanming_distance[5*m+0]!=hanming_distance[5*m+3] && (hanming_distance[5*m+0]<=hanming_distance[5*m+2]||hanming_distance[5*m+2]==hanming_distance[5*m+3]) && (hanming_distance[5*m+0]<=hanming_distance[5*m+1]||hanming_distance[5*m+1]==hanming_distance[5*m+3]) && (hanming_distance[5*m+0]<=hanming_distance[5*m+4]||hanming_distance[5*m+4]==hanming_distance[5*m+3]))
                sub_min_dis_0[m] <= hanming_distance[5*m];
            else if(hanming_distance[5*m+1]!=hanming_distance[5*m+3] && (hanming_distance[5*m+1]<=hanming_distance[5*m+0]||hanming_distance[5*m+0]==hanming_distance[5*m+3]) && (hanming_distance[5*m+1]<=hanming_distance[5*m+2]||hanming_distance[5*m+2]==hanming_distance[5*m+3]) && (hanming_distance[5*m+1]<=hanming_distance[5*m+4]||hanming_distance[5*m+4]==hanming_distance[5*m+3]))
                sub_min_dis_0[m] <= hanming_distance[5*m+1];
            else if(hanming_distance[5*m+2]!=hanming_distance[5*m+3] && (hanming_distance[5*m+2]<=hanming_distance[5*m+0]||hanming_distance[5*m+0]==hanming_distance[5*m+3]) && (hanming_distance[5*m+2]<=hanming_distance[5*m+1]||hanming_distance[5*m+1]==hanming_distance[5*m+3]) && (hanming_distance[5*m+2]<=hanming_distance[5*m+4]||hanming_distance[5*m+4]==hanming_distance[5*m+3]))
                sub_min_dis_0[m] <= hanming_distance[5*m+2];
            else if(hanming_distance[5*m+4]!=hanming_distance[5*m+3] && (hanming_distance[5*m+4]<=hanming_distance[5*m+0]||hanming_distance[5*m+0]==hanming_distance[5*m+3]) && (hanming_distance[5*m+4]<=hanming_distance[5*m+1]||hanming_distance[5*m+1]==hanming_distance[5*m+3]) && (hanming_distance[5*m+4]<=hanming_distance[5*m+2]||hanming_distance[5*m+2]==hanming_distance[5*m+3]))
                sub_min_dis_0[m] <= hanming_distance[5*m+4];
            else
                sub_min_dis_0[m] <= 'b11111111;
        end
        else if(hanming_distance[5*m+4]<=hanming_distance[5*m+0] && hanming_distance[5*m+4]<=hanming_distance[5*m+1] && hanming_distance[5*m+4]<=hanming_distance[5*m+2] && hanming_distance[5*m+4]<=hanming_distance[5*m+3])begin
            min_dis_0[m] <= hanming_distance[5*m+4];  
            min_dis_0_index[m] <= 5*m+4; 
            //sub_min0 0,1,2,3
            if(hanming_distance[5*m+0]!=hanming_distance[5*m+4] && (hanming_distance[5*m+0]<=hanming_distance[5*m+1]||hanming_distance[5*m+1]==hanming_distance[5*m+4]) && (hanming_distance[5*m+0]<=hanming_distance[5*m+2]||hanming_distance[5*m+2]==hanming_distance[5*m+4]) && (hanming_distance[5*m+0]<=hanming_distance[5*m+3]||hanming_distance[5*m+3]==hanming_distance[5*m+4]))
                sub_min_dis_0[m] <= hanming_distance[5*m];
            else if(hanming_distance[5*m+1]!=hanming_distance[5*m+4] && (hanming_distance[5*m+1]<=hanming_distance[5*m+0]||hanming_distance[5*m+0]==hanming_distance[5*m+4]) && (hanming_distance[5*m+1]<=hanming_distance[5*m+2]||hanming_distance[5*m+2]==hanming_distance[5*m+4]) && (hanming_distance[5*m+1]<=hanming_distance[5*m+3]||hanming_distance[5*m+3]==hanming_distance[5*m+4]))
                sub_min_dis_0[m] <= hanming_distance[5*m+1];
            else if(hanming_distance[5*m+2]!=hanming_distance[5*m+4] && (hanming_distance[5*m+2]<=hanming_distance[5*m+0]||hanming_distance[5*m+0]==hanming_distance[5*m+4]) && (hanming_distance[5*m+2]<=hanming_distance[5*m+1]||hanming_distance[5*m+1]==hanming_distance[5*m+4]) && (hanming_distance[5*m+2]<=hanming_distance[5*m+3]||hanming_distance[5*m+3]==hanming_distance[5*m+4]))
                sub_min_dis_0[m] <= hanming_distance[5*m+2];
            else if(hanming_distance[5*m+3]!=hanming_distance[5*m+4] && (hanming_distance[5*m+3]<=hanming_distance[5*m+0]||hanming_distance[5*m+0]==hanming_distance[5*m+4]) && (hanming_distance[5*m+3]<=hanming_distance[5*m+1]||hanming_distance[5*m+1]==hanming_distance[5*m+4]) && (hanming_distance[5*m+3]<=hanming_distance[5*m+2]||hanming_distance[5*m+2]==hanming_distance[5*m+4]))
                sub_min_dis_0[m] <= hanming_distance[5*m+3];            
            else
                sub_min_dis_0[m] <= 'b11111111;
        end
    end
    //===========min1_distance and sub_min1_distance===========//
    for(m=0;m<8;m=m+1)begin
        if(min_dis_0[5*m+0]<=min_dis_0[5*m+1] && min_dis_0[5*m+0]<=min_dis_0[5*m+2] && min_dis_0[5*m+0]<=min_dis_0[5*m+3] && min_dis_0[5*m+0]<=min_dis_0[5*m+4])begin
            min_dis_1[m] <= min_dis_0[5*m+0];
            min_dis_1_index[m] <= min_dis_0_index[5*m+0];
            //sub_min1 1,2,3,4
            if(min_dis_0[5*m+1]!=min_dis_0[5*m] && (min_dis_0[5*m+1]<=min_dis_0[5*m+2]||min_dis_0[5*m+2]==min_dis_0[5*m]) && (min_dis_0[5*m+1]<=min_dis_0[5*m+3]||min_dis_0[5*m+3]==min_dis_0[5*m]) && (min_dis_0[5*m+1]<=min_dis_0[5*m+4]||min_dis_0[5*m+4]==min_dis_0[5*m]))
                sub_min_dis_1[m] <= min_dis_0[5*m+1];
            else if(min_dis_0[5*m+2]!=min_dis_0[5*m] && (min_dis_0[5*m+2]<=min_dis_0[5*m+1]||min_dis_0[5*m+1]==min_dis_0[5*m]) && (min_dis_0[5*m+2]<=min_dis_0[5*m+3]||min_dis_0[5*m+3]==min_dis_0[5*m]) && (min_dis_0[5*m+2]<=min_dis_0[5*m+4]||min_dis_0[5*m+4]==min_dis_0[5*m]))
                sub_min_dis_1[m] <= min_dis_0[5*m+2];
            else if(min_dis_0[5*m+3]!=min_dis_0[5*m] && (min_dis_0[5*m+3]<=min_dis_0[5*m+1]||min_dis_0[5*m+1]==min_dis_0[5*m]) && (min_dis_0[5*m+3]<=min_dis_0[5*m+2]||min_dis_0[5*m+2]==min_dis_0[5*m]) && (min_dis_0[5*m+3]<=min_dis_0[5*m+4]||min_dis_0[5*m+4]==min_dis_0[5*m]))
                sub_min_dis_1[m] <= min_dis_0[5*m+3];
            else if(min_dis_0[5*m+4]!=min_dis_0[5*m] && (min_dis_0[5*m+4]<=min_dis_0[5*m+1]||min_dis_0[5*m+1]==min_dis_0[5*m]) && (min_dis_0[5*m+4]<=min_dis_0[5*m+2]||min_dis_0[5*m+2]==min_dis_0[5*m]) && (min_dis_0[5*m+4]<=min_dis_0[5*m+3]||min_dis_0[5*m+3]==min_dis_0[5*m]))
                sub_min_dis_1[m] <= min_dis_0[5*m+4];
            else
                sub_min_dis_1[m] <= 'b11111111;
        end
        else if(min_dis_0[5*m+1]<=min_dis_0[5*m+0] && min_dis_0[5*m+1]<=min_dis_0[5*m+2] && min_dis_0[5*m+1]<=min_dis_0[5*m+3] && min_dis_0[5*m+1]<=min_dis_0[5*m+4])begin
            min_dis_1[m] <= min_dis_0[5*m+1];
            min_dis_1_index[m] <= min_dis_0_index[5*m+1];
            //sub_min1 0,2,3,4
            if(min_dis_0[5*m+0]!=min_dis_0[5*m+1] && (min_dis_0[5*m+0]<=min_dis_0[5*m+2]||min_dis_0[5*m+2]==min_dis_0[5*m+1]) && (min_dis_0[5*m+0]<=min_dis_0[5*m+3]||min_dis_0[5*m+3]==min_dis_0[5*m+1]) && (min_dis_0[5*m+0]<=min_dis_0[5*m+4]||min_dis_0[5*m+4]==min_dis_0[5*m+1]))
                sub_min_dis_1[m] <= min_dis_0[5*m];
            else if(min_dis_0[5*m+2]!=min_dis_0[5*m+1] && (min_dis_0[5*m+2]<=min_dis_0[5*m+0]||min_dis_0[5*m+0]==min_dis_0[5*m+1]) && (min_dis_0[5*m+2]<=min_dis_0[5*m+3]||min_dis_0[5*m+3]==min_dis_0[5*m+1]) && (min_dis_0[5*m+2]<=min_dis_0[5*m+4]||min_dis_0[5*m+4]==min_dis_0[5*m+1]))
                sub_min_dis_1[m] <= min_dis_0[5*m+2];
            else if(min_dis_0[5*m+3]!=min_dis_0[5*m+1] && (min_dis_0[5*m+3]<=min_dis_0[5*m+0]||min_dis_0[5*m+0]==min_dis_0[5*m+1]) && (min_dis_0[5*m+3]<=min_dis_0[5*m+2]||min_dis_0[5*m+2]==min_dis_0[5*m+1]) && (min_dis_0[5*m+3]<=min_dis_0[5*m+4]||min_dis_0[5*m+4]==min_dis_0[5*m+1]))
                sub_min_dis_1[m] <= min_dis_0[5*m+3];
            else if(min_dis_0[5*m+4]!=min_dis_0[5*m+1] && (min_dis_0[5*m+4]<=min_dis_0[5*m+0]||min_dis_0[5*m+0]==min_dis_0[5*m+1]) && (min_dis_0[5*m+4]<=min_dis_0[5*m+2]||min_dis_0[5*m+2]==min_dis_0[5*m+1]) && (min_dis_0[5*m+4]<=min_dis_0[5*m+3]||min_dis_0[5*m+3]==min_dis_0[5*m+1]))
                sub_min_dis_1[m] <= min_dis_0[5*m+4];
            else
                sub_min_dis_1[m] <= 'b11111111;
        end
        else if(min_dis_0[5*m+2]<=min_dis_0[5*m+0] && min_dis_0[5*m+2]<=min_dis_0[5*m+1] && min_dis_0[5*m+2]<=min_dis_0[5*m+3] && min_dis_0[5*m+2]<=min_dis_0[5*m+4])begin
            min_dis_1[m] <= min_dis_0[5*m+2];
            min_dis_1_index[m] <= min_dis_0_index[5*m+2];
            //sub_min1 0,1,3,4
            if(min_dis_0[5*m+0]!=min_dis_0[5*m+2] && (min_dis_0[5*m+0]<=min_dis_0[5*m+1]||min_dis_0[5*m+1]==min_dis_0[5*m+2]) && (min_dis_0[5*m+0]<=min_dis_0[5*m+3]||min_dis_0[5*m+3]==min_dis_0[5*m+2]) && (min_dis_0[5*m+0]<=min_dis_0[5*m+4]||min_dis_0[5*m+4]==min_dis_0[5*m+2]))
                sub_min_dis_1[m] <= min_dis_0[5*m];
            else if(min_dis_0[5*m+1]!=min_dis_0[5*m+2] && (min_dis_0[5*m+1]<=min_dis_0[5*m+0]||min_dis_0[5*m+0]==min_dis_0[5*m+2]) && (min_dis_0[5*m+1]<=min_dis_0[5*m+3]||min_dis_0[5*m+3]==min_dis_0[5*m+2]) && (min_dis_0[5*m+1]<=min_dis_0[5*m+4]||min_dis_0[5*m+4]==min_dis_0[5*m+2]))
                sub_min_dis_1[m] <= min_dis_0[5*m+1];
            else if(min_dis_0[5*m+3]!=min_dis_0[5*m+2] && (min_dis_0[5*m+3]<=min_dis_0[5*m+0]||min_dis_0[5*m+0]==min_dis_0[5*m+2]) && (min_dis_0[5*m+3]<=min_dis_0[5*m+1]||min_dis_0[5*m+1]==min_dis_0[5*m+2]) && (min_dis_0[5*m+3]<=min_dis_0[5*m+4]||min_dis_0[5*m+4]==min_dis_0[5*m+2]))
                sub_min_dis_1[m] <= min_dis_0[5*m+3];
            else if(min_dis_0[5*m+4]!=min_dis_0[5*m+2] && (min_dis_0[5*m+4]<=min_dis_0[5*m+0]||min_dis_0[5*m+0]==min_dis_0[5*m+2]) && (min_dis_0[5*m+4]<=min_dis_0[5*m+1]||min_dis_0[5*m+1]==min_dis_0[5*m+2]) && (min_dis_0[5*m+4]<=min_dis_0[5*m+3]||min_dis_0[5*m+3]==min_dis_0[5*m+2]))
                sub_min_dis_1[m] <= min_dis_0[5*m+4];
            else
                sub_min_dis_1[m] <= 'b11111111;
        end
        else if(min_dis_0[5*m+3]<=min_dis_0[5*m+0] && min_dis_0[5*m+3]<=min_dis_0[5*m+1] && min_dis_0[5*m+3]<=min_dis_0[5*m+2] && min_dis_0[5*m+3]<=min_dis_0[5*m+4])begin
            min_dis_1[m] <= min_dis_0[5*m+3];
            min_dis_1_index[m] <= min_dis_0_index[5*m+3];
            //sub_min1 0,1,2,4
            if(min_dis_0[5*m+0]!=min_dis_0[5*m+3] && (min_dis_0[5*m+0]<=min_dis_0[5*m+2]||min_dis_0[5*m+2]==min_dis_0[5*m+3]) && (min_dis_0[5*m+0]<=min_dis_0[5*m+1]||min_dis_0[5*m+1]==min_dis_0[5*m+3]) && (min_dis_0[5*m+0]<=min_dis_0[5*m+4]||min_dis_0[5*m+4]==min_dis_0[5*m+3]))
                sub_min_dis_1[m] <= min_dis_0[5*m];
            else if(min_dis_0[5*m+1]!=min_dis_0[5*m+3] && (min_dis_0[5*m+1]<=min_dis_0[5*m+0]||min_dis_0[5*m+0]==min_dis_0[5*m+3]) && (min_dis_0[5*m+1]<=min_dis_0[5*m+2]||min_dis_0[5*m+2]==min_dis_0[5*m+3]) && (min_dis_0[5*m+1]<=min_dis_0[5*m+4]||min_dis_0[5*m+4]==min_dis_0[5*m+3]))
                sub_min_dis_1[m] <= min_dis_0[5*m+1];
            else if(min_dis_0[5*m+2]!=min_dis_0[5*m+3] && (min_dis_0[5*m+2]<=min_dis_0[5*m+0]||min_dis_0[5*m+0]==min_dis_0[5*m+3]) && (min_dis_0[5*m+2]<=min_dis_0[5*m+1]||min_dis_0[5*m+1]==min_dis_0[5*m+3]) && (min_dis_0[5*m+2]<=min_dis_0[5*m+4]||min_dis_0[5*m+4]==min_dis_0[5*m+3]))
                sub_min_dis_1[m] <= min_dis_0[5*m+2];
            else if(min_dis_0[5*m+4]!=min_dis_0[5*m+3] && (min_dis_0[5*m+4]<=min_dis_0[5*m+0]||min_dis_0[5*m+0]==min_dis_0[5*m+3]) && (min_dis_0[5*m+4]<=min_dis_0[5*m+1]||min_dis_0[5*m+1]==min_dis_0[5*m+3]) && (min_dis_0[5*m+4]<=min_dis_0[5*m+2]||min_dis_0[5*m+2]==min_dis_0[5*m+3]))
                sub_min_dis_1[m] <= min_dis_0[5*m+4];
            else
                sub_min_dis_1[m] <= 'b11111111;
        end
        else if(min_dis_0[5*m+4]<=min_dis_0[5*m+0] && min_dis_0[5*m+4]<=min_dis_0[5*m+1] && min_dis_0[5*m+4]<=min_dis_0[5*m+2] && min_dis_0[5*m+4]<=min_dis_0[5*m+3])begin
            min_dis_1[m] <= min_dis_0[5*m+4]; 
            min_dis_1_index[m] <= min_dis_0_index[5*m+4];  
            //sub_min1 0,1,2,3
            if(min_dis_0[5*m+0]!=min_dis_0[5*m+4] && (min_dis_0[5*m+0]<=min_dis_0[5*m+1]||min_dis_0[5*m+1]==min_dis_0[5*m+4]) && (min_dis_0[5*m+0]<=min_dis_0[5*m+2]||min_dis_0[5*m+2]==min_dis_0[5*m+4]) && (min_dis_0[5*m+0]<=min_dis_0[5*m+3]||min_dis_0[5*m+3]==min_dis_0[5*m+4]))
                sub_min_dis_1[m] <= min_dis_0[5*m];
            else if(min_dis_0[5*m+1]!=min_dis_0[5*m+4] && (min_dis_0[5*m+1]<=min_dis_0[5*m+0]||min_dis_0[5*m+0]==min_dis_0[5*m+4]) && (min_dis_0[5*m+1]<=min_dis_0[5*m+2]||min_dis_0[5*m+2]==min_dis_0[5*m+4]) && (min_dis_0[5*m+1]<=min_dis_0[5*m+3]||min_dis_0[5*m+3]==min_dis_0[5*m+4]))
                sub_min_dis_1[m] <= min_dis_0[5*m+1];
            else if(min_dis_0[5*m+2]!=min_dis_0[5*m+4] && (min_dis_0[5*m+2]<=min_dis_0[5*m+0]||min_dis_0[5*m+0]==min_dis_0[5*m+4]) && (min_dis_0[5*m+2]<=min_dis_0[5*m+1]||min_dis_0[5*m+1]==min_dis_0[5*m+4]) && (min_dis_0[5*m+2]<=min_dis_0[5*m+3]||min_dis_0[5*m+3]==min_dis_0[5*m+4]))
                sub_min_dis_1[m] <= min_dis_0[5*m+2];
            else if(min_dis_0[5*m+3]!=min_dis_0[5*m+4] && (min_dis_0[5*m+3]<=min_dis_0[5*m+0]||min_dis_0[5*m+0]==min_dis_0[5*m+4]) && (min_dis_0[5*m+3]<=min_dis_0[5*m+1]||min_dis_0[5*m+1]==min_dis_0[5*m+4]) && (min_dis_0[5*m+3]<=min_dis_0[5*m+2]||min_dis_0[5*m+2]==min_dis_0[5*m+4]))
                sub_min_dis_1[m] <= min_dis_0[5*m+3];            
            else
                sub_min_dis_1[m] <= 'b11111111;
        end
    end
    //===========sub_min2_distance===========//
    for(m=0;m<8;m=m+1)begin
        if(sub_min_dis_0[5*m+0]<=sub_min_dis_0[5*m+1] && sub_min_dis_0[5*m+0]<=sub_min_dis_0[5*m+2] && sub_min_dis_0[5*m+0]<=sub_min_dis_0[5*m+3] && sub_min_dis_0[5*m+0]<=sub_min_dis_0[5*m+4])
            sub_min_dis_2[m] <= sub_min_dis_0[5*m+0];
        else if(sub_min_dis_0[5*m+1]<=sub_min_dis_0[5*m+0] && sub_min_dis_0[5*m+1]<=sub_min_dis_0[5*m+2] && sub_min_dis_0[5*m+1]<=sub_min_dis_0[5*m+3] && sub_min_dis_0[5*m+1]<=sub_min_dis_0[5*m+4])
            sub_min_dis_2[m] <= sub_min_dis_0[5*m+1];
        else if(sub_min_dis_0[5*m+2]<=sub_min_dis_0[5*m+0] && sub_min_dis_0[5*m+2]<=sub_min_dis_0[5*m+1] && sub_min_dis_0[5*m+2]<=sub_min_dis_0[5*m+3] && sub_min_dis_0[5*m+2]<=sub_min_dis_0[5*m+4])
            sub_min_dis_2[m] <= sub_min_dis_0[5*m+2];
        else if(sub_min_dis_0[5*m+3]<=sub_min_dis_0[5*m+0] && sub_min_dis_0[5*m+3]<=sub_min_dis_0[5*m+1] && sub_min_dis_0[5*m+3]<=sub_min_dis_0[5*m+2] && sub_min_dis_0[5*m+3]<=sub_min_dis_0[5*m+4])
            sub_min_dis_2[m] <= sub_min_dis_0[5*m+3];
        else if(sub_min_dis_0[5*m+4]<=sub_min_dis_0[5*m+0] && sub_min_dis_0[5*m+4]<=sub_min_dis_0[5*m+1] && sub_min_dis_0[5*m+4]<=sub_min_dis_0[5*m+2] && sub_min_dis_0[5*m+4]<=sub_min_dis_0[5*m+3])
            sub_min_dis_2[m] <= sub_min_dis_0[5*m+4]; 
    end
    //===========min_distance and sub_min_distance===========//
    for(m=0;m<2;m=m+1)begin
        if(min_dis_1[4*m+0]<=min_dis_1[4*m+1] && min_dis_1[4*m+0]<=min_dis_1[4*m+2] && min_dis_1[4*m+0]<=min_dis_1[4*m+3])begin
            min_dis[m] <= min_dis_1[4*m+0];
            min_dis_index[m] <= min_dis_1_index[4*m+0];
            //sub_min 1,2,3
            if(min_dis_1[4*m+1]!=min_dis_1[4*m] && (min_dis_1[4*m+1]<=min_dis_1[4*m+2]||min_dis_1[4*m+2]==min_dis_1[4*m]) && (min_dis_1[4*m+1]<=min_dis_1[4*m+3]||min_dis_1[4*m+3]==min_dis_1[4*m]))
                sub_min_dis_min[m] <= min_dis_1[4*m+1];
            else if(min_dis_1[4*m+2]!=min_dis_1[4*m] && (min_dis_1[4*m+2]<=min_dis_1[4*m+1]||min_dis_1[4*m+1]==min_dis_1[4*m]) && (min_dis_1[4*m+2]<=min_dis_1[4*m+3]||min_dis_1[4*m+3]==min_dis_1[4*m]))
                sub_min_dis_min[m] <= min_dis_1[4*m+2];
            else if(min_dis_1[4*m+3]!=min_dis_1[4*m] && (min_dis_1[4*m+3]<=min_dis_1[4*m+1]||min_dis_1[4*m+1]==min_dis_1[4*m]) && (min_dis_1[4*m+3]<=min_dis_1[4*m+2]||min_dis_1[4*m+2]==min_dis_1[4*m]))
                sub_min_dis_min[m] <= min_dis_1[4*m+3];
            else
                sub_min_dis_min[m] <= 'b11111111;
        end
        else if(min_dis_1[4*m+1]<=min_dis_1[4*m+0] && min_dis_1[4*m+1]<=min_dis_1[4*m+2] && min_dis_1[4*m+1]<=min_dis_1[4*m+3])begin
            min_dis[m] <= min_dis_1[4*m+1];
            min_dis_index[m] <= min_dis_1_index[4*m+1];
            //sub_min 0,2,3
            if(min_dis_1[4*m+0]!=min_dis_1[4*m+1] && (min_dis_1[4*m+0]<=min_dis_1[4*m+2]||min_dis_1[4*m+2]==min_dis_1[4*m+1]) && (min_dis_1[4*m+0]<=min_dis_1[4*m+3]||min_dis_1[4*m+3]==min_dis_1[4*m+1]))
                sub_min_dis_min[m] <= min_dis_1[4*m+0];
            else if(min_dis_1[4*m+2]!=min_dis_1[4*m+1] && (min_dis_1[4*m+2]<=min_dis_1[4*m+0]||min_dis_1[4*m+0]==min_dis_1[4*m+1]) && (min_dis_1[4*m+2]<=min_dis_1[4*m+3]||min_dis_1[4*m+3]==min_dis_1[4*m+1]))
                sub_min_dis_min[m] <= min_dis_1[4*m+2];
            else if(min_dis_1[4*m+3]!=min_dis_1[4*m+1] && (min_dis_1[4*m+3]<=min_dis_1[4*m+0]||min_dis_1[4*m+0]==min_dis_1[4*m+1]) && (min_dis_1[4*m+3]<=min_dis_1[4*m+2]||min_dis_1[4*m+2]==min_dis_1[4*m+1]))
                sub_min_dis_min[m] <= min_dis_1[4*m+3];
            else
                sub_min_dis_min[m] <= 'b11111111;
        end
        else if(min_dis_1[4*m+2]<=min_dis_1[4*m+0] && min_dis_1[4*m+2]<=min_dis_1[4*m+1] && min_dis_1[4*m+2]<=min_dis_1[4*m+3])begin
            min_dis[m] <= min_dis_1[4*m+2];
            min_dis_index[m] <= min_dis_1_index[4*m+2];
            //sub_min 0,1,3
            if(min_dis_1[4*m+0]!=min_dis_1[4*m+2] && (min_dis_1[4*m+0]<=min_dis_1[4*m+1]||min_dis_1[4*m+1]==min_dis_1[4*m+2]) && (min_dis_1[4*m+0]<=min_dis_1[4*m+3]||min_dis_1[4*m+3]==min_dis_1[4*m+2]))
                sub_min_dis_min[m] <= min_dis_1[4*m+0];
            else if(min_dis_1[4*m+1]!=min_dis_1[4*m+2] && (min_dis_1[4*m+1]<=min_dis_1[4*m+0]||min_dis_1[4*m+0]==min_dis_1[4*m+2]) && (min_dis_1[4*m+1]<=min_dis_1[4*m+3]||min_dis_1[4*m+3]==min_dis_1[4*m+2]))
                sub_min_dis_min[m] <= min_dis_1[4*m+1];
            else if(min_dis_1[4*m+3]!=min_dis_1[4*m+2] && (min_dis_1[4*m+3]<=min_dis_1[4*m+0]||min_dis_1[4*m+0]==min_dis_1[4*m+2]) && (min_dis_1[4*m+3]<=min_dis_1[4*m+1]||min_dis_1[4*m+1]==min_dis_1[4*m+2]))
                sub_min_dis_min[m] <= min_dis_1[4*m+3];
            else
                sub_min_dis_min[m] <= 'b11111111;
        end
        else if(min_dis_1[4*m+3]<=min_dis_1[4*m+0] && min_dis_1[4*m+3]<=min_dis_1[4*m+1] && min_dis_1[4*m+3]<=min_dis_1[4*m+2])begin
            min_dis[m] <= min_dis_1[4*m+3];
            min_dis_index[m] <= min_dis_1_index[4*m+3];
            //sub_min 0,1,2
            if(min_dis_1[4*m+0]!=min_dis_1[4*m+3] && (min_dis_1[4*m+0]<=min_dis_1[4*m+1]||min_dis_1[4*m+1]==min_dis_1[4*m+3]) && (min_dis_1[4*m+0]<=min_dis_1[4*m+2]||min_dis_1[4*m+2]==min_dis_1[4*m+3]))
                sub_min_dis_min[m] <= min_dis_1[4*m+0];
            else if(min_dis_1[4*m+1]!=min_dis_1[4*m+3] && (min_dis_1[4*m+1]<=min_dis_1[4*m+0]||min_dis_1[4*m+0]==min_dis_1[4*m+3]) && (min_dis_1[4*m+1]<=min_dis_1[4*m+2]||min_dis_1[4*m+2]==min_dis_1[4*m+3]))
                sub_min_dis_min[m] <= min_dis_1[4*m+1];
            else if(min_dis_1[4*m+2]!=min_dis_1[4*m+3] && (min_dis_1[4*m+2]<=min_dis_1[4*m+0]||min_dis_1[4*m+0]==min_dis_1[4*m+3]) && (min_dis_1[4*m+2]<=min_dis_1[4*m+1]||min_dis_1[4*m+1]==min_dis_1[4*m+3]))
                sub_min_dis_min[m] <= min_dis_1[4*m+2];
            else
                sub_min_dis_min[m] <= 'b11111111;
        end
    end
    //===========sub_min_distance1===========//
    for(m=0;m<2;m=m+1)begin
        if(sub_min_dis_1[4*m+0]<=sub_min_dis_1[4*m+1] && sub_min_dis_1[4*m+0]<=sub_min_dis_1[4*m+2] && sub_min_dis_1[4*m+0]<=sub_min_dis_1[4*m+3])
            sub_min_dis_sub1[m] <= sub_min_dis_1[4*m+0];
        else if(sub_min_dis_1[4*m+1]<=sub_min_dis_1[4*m+0] && sub_min_dis_1[4*m+1]<=sub_min_dis_1[4*m+2] && sub_min_dis_1[4*m+1]<=sub_min_dis_1[4*m+3])
            sub_min_dis_sub1[m] <= sub_min_dis_1[4*m+1];
        else if(sub_min_dis_1[4*m+2]<=sub_min_dis_1[4*m+0] && sub_min_dis_1[4*m+2]<=sub_min_dis_1[4*m+1] && sub_min_dis_1[4*m+2]<=sub_min_dis_1[4*m+3])
            sub_min_dis_sub1[m] <= sub_min_dis_1[4*m+2];
        else if(sub_min_dis_1[4*m+3]<=sub_min_dis_1[4*m+0] && sub_min_dis_1[4*m+3]<=sub_min_dis_1[4*m+1] && sub_min_dis_1[4*m+3]<=sub_min_dis_1[4*m+2])
            sub_min_dis_sub1[m] <= sub_min_dis_1[4*m+3];
    end
    //===========sub_min_distance2===========//
    for(m=0;m<2;m=m+1)begin
        if(sub_min_dis_2[4*m+0]<=sub_min_dis_2[4*m+1] && sub_min_dis_2[4*m+0]<=sub_min_dis_2[4*m+2] && sub_min_dis_2[4*m+0]<=sub_min_dis_2[4*m+3])
            sub_min_dis_sub2[m] <= sub_min_dis_2[4*m+0];
        else if(sub_min_dis_2[4*m+1]<=sub_min_dis_2[4*m+0] && sub_min_dis_2[4*m+1]<=sub_min_dis_2[4*m+2] && sub_min_dis_2[4*m+1]<=sub_min_dis_2[4*m+3])
            sub_min_dis_sub2[m] <= sub_min_dis_2[4*m+1];
        else if(sub_min_dis_2[4*m+2]<=sub_min_dis_2[4*m+0] && sub_min_dis_2[4*m+2]<=sub_min_dis_2[4*m+1] && sub_min_dis_2[4*m+2]<=sub_min_dis_2[4*m+3])
            sub_min_dis_sub2[m] <= sub_min_dis_2[4*m+2];
        else if(sub_min_dis_2[4*m+3]<=sub_min_dis_2[4*m+0] && sub_min_dis_2[4*m+3]<=sub_min_dis_2[4*m+1] && sub_min_dis_2[4*m+3]<=sub_min_dis_2[4*m+2])
            sub_min_dis_sub2[m] <= sub_min_dis_2[4*m+3];
    end
    //===========sub_min_distance===========//
    for(m=0;m<2;m=m+1)begin
    //sub_min_dis_sub1,sub_min_dis_sub2,sub_min_dis_min,min_dist_sub
        if(sub_min_dis_sub1[m]<=sub_min_dis_sub2[m] && sub_min_dis_sub1[m]<=sub_min_dis_min[m] && (sub_min_dis_sub1[m]<=min_dist_sub||min_dist_sub==min_dist_new))
            sub_min_dis[m] <= sub_min_dis_sub1[m];
        else if(sub_min_dis_sub2[m]<=sub_min_dis_sub1[m] && sub_min_dis_sub2[m]<=sub_min_dis_min[m] && (sub_min_dis_sub2[m]<=min_dist_sub||min_dist_sub==min_dist_new))
            sub_min_dis[m] <= sub_min_dis_sub2[m];
        else if(sub_min_dis_min[m]<=sub_min_dis_sub1[m] && sub_min_dis_min[m]<=sub_min_dis_sub2[m] && (sub_min_dis_min[m]<=min_dist_sub||min_dist_sub==min_dist_new))
            sub_min_dis[m] <= sub_min_dis_min[m];
        else if(min_dist_sub<=sub_min_dis_sub1[m] && min_dist_sub<=sub_min_dis_sub2[m] && min_dist_sub<=sub_min_dis_min[m])
            sub_min_dis[m] <= min_dist_sub;
    end
end
wire [8:0] sub_min_dist_new;
wire [8:0] min_dist_index_new;
assign min_dist_new = (min_dis[0]<=min_dis[1])?min_dis[0]:min_dis[1];
assign min_dist_index_new = (min_dis[0]<=min_dis[1])?min_dis_index[0]:min_dis_index[1];
assign min_dist_sub = (min_dis[0]<=min_dis[1])?min_dis[1]:min_dis[0];
assign sub_min_dist_new = (sub_min_dis[0]<=sub_min_dis[1])?sub_min_dis[0]:sub_min_dis[1];
//reg [5:0]min_dist_valid;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        min_dist_valid <= 'b0;
    else if(add2_valid_flip=='b1)
        min_dist_valid <= 'b1;
    else
        min_dist_valid <= {min_dist_valid[4:0],1'b0}; 
end
reg [8:0]min_dist_reg,min_dist_index_reg,sub_min_dist_reg;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        min_dist_reg <= 'b0;
        min_dist_index_reg <= 'b0;
    end
    else if(min_dist_valid[2]=='b1 && min_dist_valid[3]=='b0)begin
        min_dist_reg <= min_dist_new;
        min_dist_index_reg <= min_dist_index_new;
    end
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        sub_min_dist_reg <= 'b0;
    else if(min_dist_valid[3]=='b1)
        sub_min_dist_reg <= sub_min_dist_new;
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        right_last_flag <= 'b0;
    else if(O_AXIS_tlast=='b1)
        right_last_flag <= 'b0;
    else if(i_tlast_count=='d2 && ram_addrb_right==ram_addra_right)
        right_last_flag <= 'b1;
end

// knnmatch check
assign O_AXIS_tvalid = (min_dist_valid[5]=='b1)?(((min_dist_reg<=((sub_min_dist_reg*7)>>3) && sub_min_dist_reg!='b11111111 && min_dist_reg<='d40)||(right_last_flag=='b1))?'b1:'b0):'b0;
//assign O_AXIS_tvalid = (min_dist_valid[5]=='b1)?(((sub_min_dist_reg!='b11111111)||(right_last_flag=='b1))?'b1:'b0):'b0;
assign O_AXIS_tdata = (O_AXIS_tvalid)?({26'b0,left_data_vec_data[min_dist_index_reg][24:16],left_data_vec_data[min_dist_index_reg][34:25],pixel_right_x,pixel_right_y}):('b0);

assign O_AXIS_tlast = (min_dist_valid[5]&&right_last_flag)?1'b1:1'b0;
assign O_AXIS_tuser = I_AXIS_tuser;
assign O_AXIS_tkeep = 'b11111111;
assign I_AXIS_tready = O_AXIS_tready;  
    
 ultraram_simple_dual_port uram_left(
 .clk(clk),   
 .rstb(!rst_n),   
 .wea(wea_left),    
 .regceb(rd_en_left), 
 .mem_en(1'b1),
 .dina(dina_left), 
 .addra(ram_addra_left),
 .addrb(ram_addrb_left),
 .o_valid(o_valid_left),
 .doutb(doutb_left)
);   
 ultraram_simple_dual_port uram_right(
 .clk(clk),   
 .rstb(!rst_n),   
 .wea(wea_right),    
 .regceb(rd_en_right), 
 .mem_en(1'b1),
 .dina(dina_right), 
 .addra(ram_addra_right),
 .addrb(ram_addrb_right),
 .o_valid(o_valid_right),
 .doutb(doutb_right)
); 
      
endmodule