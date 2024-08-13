`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/11/12 18:45:40
// Design Name: 
// Module Name: tb
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


module tb();
reg clk;
reg rst_n;
reg [9:0] width0,width1,width7;
reg [8:0] height0,height1,height7;
reg [31:0] cfg_tdata;
reg cfg_tvalid;
reg cfg_tlast;
reg [7:0] fast_tdata;
reg fast_tlast0,fast_tlast1,fast_tlast7;
reg [7:0] pixel_tdata;
wire fast_tvalid;
wire pixel_tvalid; 
wire fast_tready,pixel_tready;
reg fastout_tready,pixelout_tready;
reg [3:0]fast_tlast_count;

integer file_fast_data0,file_result_fast0,file_pixel_data0,file_result_pixel0;
integer file_fast_data1,file_result_fast1,file_pixel_data1,file_result_pixel1;
integer file_fast_data7,file_result_fast7,file_pixel_data7,file_result_pixel7;
initial begin
    clk = 'b0;
    rst_n = 'b0;
    width0 = 'b0;
    height0 = 'b0;
    width1 = 'b0;
    height1 = 'b0;
    width7 = 'b0;
    height7 = 'b0;
    fast_tlast_count = 'b0;
    fastout_tready = 'b0;
    pixelout_tready = 'b0;
    #25;rst_n = 'b1;
    width0 = 'd640;
    height0 = 'd400;
    width1 = 'd533;
    height1 = 'd333;
    width7 = 'd182;
    height7 = 'd114;
    file_fast_data0 = $fopen("/home/lqw/lqw_workspace/05_FPGA_SLAM/Quad_tree/Feature_Even/Feature_Even.srcs/sim_1/new/fast_data0.txt","rb");
    file_pixel_data0 = $fopen("/home/lqw/lqw_workspace/05_FPGA_SLAM/Quad_tree/Feature_Even/Feature_Even.srcs/sim_1/new/pixel_data0.txt","rb");
    file_result_fast0 = $fopen("/home/lqw/lqw_workspace/05_FPGA_SLAM/Quad_tree/Feature_Even/Feature_Even.srcs/sim_1/new/result_fast0.txt","rb");
    file_result_pixel0 = $fopen("/home/lqw/lqw_workspace/05_FPGA_SLAM/Quad_tree/Feature_Even/Feature_Even.srcs/sim_1/new/result_pixel0.txt","rb");
    
    file_fast_data1 = $fopen("/home/lqw/lqw_workspace/05_FPGA_SLAM/Quad_tree/Feature_Even/Feature_Even.srcs/sim_1/new/fast_data1.txt","rb");
    file_pixel_data1 = $fopen("/home/lqw/lqw_workspace/05_FPGA_SLAM/Quad_tree/Feature_Even/Feature_Even.srcs/sim_1/new/pixel_data1.txt","rb");
    file_result_fast1 = $fopen("/home/lqw/lqw_workspace/05_FPGA_SLAM/Quad_tree/Feature_Even/Feature_Even.srcs/sim_1/new/result_fast1.txt","rb");
    file_result_pixel1 = $fopen("/home/lqw/lqw_workspace/05_FPGA_SLAM/Quad_tree/Feature_Even/Feature_Even.srcs/sim_1/new/result_pixel1.txt","rb");
    
    file_fast_data7 = $fopen("/home/lqw/lqw_workspace/05_FPGA_SLAM/Quad_tree/Feature_Even/Feature_Even.srcs/sim_1/new/fast_data7.txt","rb");
    file_pixel_data7 = $fopen("/home/lqw/lqw_workspace/05_FPGA_SLAM/Quad_tree/Feature_Even/Feature_Even.srcs/sim_1/new/pixel_data7.txt","rb");
    file_result_fast7 = $fopen("/home/lqw/lqw_workspace/05_FPGA_SLAM/Quad_tree/Feature_Even/Feature_Even.srcs/sim_1/new/result_fast7.txt","rb");
    file_result_pixel7 = $fopen("/home/lqw/lqw_workspace/05_FPGA_SLAM/Quad_tree/Feature_Even/Feature_Even.srcs/sim_1/new/result_pixel7.txt","rb");
//    if(file_fast_data==0 || file_pixel_data==0) $stop;
end 
always #5 clk = ~clk;
reg [19:0] count;
reg [18:0] count_valid;
reg fast_tlast_last0,fast_tlast_last1,fast_tlast_last7;
reg axis_flag;
reg [7:0] axis_time;

assign fast_tvalid=fastout_tready&&(count>='d6);
assign pixel_tvalid=pixelout_tready&&(count>='d6);

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        axis_flag <= 'b0;
    else if(axis_time[7]=='b1)
        axis_flag <= 'b0;
    else if($urandom_range(0,8)=='d8 && axis_flag=='b0)
        axis_flag <= 'b1;    
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        axis_time <= 'b0;
    else if(axis_flag=='b1 && axis_time=='b0)
        axis_time <= 'b1;    
    else
        axis_time <= {axis_time[6:0],1'b0};
end


always@(posedge clk or negedge rst_n)begin
    if(axis_flag=='b1)begin
        fastout_tready = 'b1;
        pixelout_tready = 'b1;
    end
    else begin
        fastout_tready = 'b0;
        pixelout_tready = 'b0;
    end
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        fast_tdata <= 'b0;
        pixel_tdata <= 'b0;
        cfg_tdata <= 'b0;
        cfg_tvalid <= 'b0;
        cfg_tlast <= 'b0;
        count_valid <= 'b0;
    end
    else if(count == 'd2 && fast_tlast_count=='b0)begin
        cfg_tdata <= width0;
        cfg_tvalid <= 'b1;
    end
    else if(count == 'd3 && fast_tlast_count=='b0)begin
        cfg_tdata <= height0;
        cfg_tvalid <= 'b1;
        cfg_tlast <= 'b1;
    end
    else if(count == 'd2 && fast_tlast_count=='b1)begin
        cfg_tdata <= width1;
        cfg_tvalid <= 'b1;
    end
    else if(count == 'd3 && fast_tlast_count=='b1)begin
        cfg_tdata <= height1;
        cfg_tvalid <= 'b1;
        cfg_tlast <= 'b1;
    end

    else if(count == 'd2 && fast_tlast_count=='d2)begin
        cfg_tdata <= width7;
        cfg_tvalid <= 'b1;
    end
    else if(count == 'd3 && fast_tlast_count=='d2)begin
        cfg_tdata <= height7;
        cfg_tvalid <= 'b1;
        cfg_tlast <= 'b1;
    end

    else if(count>='d6 && fast_tready=='b1 && fast_tlast_last0=='b0 && fast_tlast_count=='b0) begin
        $fscanf(file_fast_data0,"%d",fast_tdata);
        $fscanf(file_pixel_data0,"%d",pixel_tdata);
        count_valid <= count_valid+'b1;
    end
    else if(count>='d6 && fast_tready=='b1 && fast_tlast_last1=='b0 && fast_tlast_count=='b1) begin
        $fscanf(file_fast_data1,"%d",fast_tdata);
        $fscanf(file_pixel_data1,"%d",pixel_tdata);
        count_valid <= count_valid+'b1;
    end
    else if(count>='d6 && fast_tready=='b1 && fast_tlast_last7=='b0 && fast_tlast_count=='d2) begin
        $fscanf(file_fast_data7,"%d",fast_tdata);
        $fscanf(file_pixel_data7,"%d",pixel_tdata);
        count_valid <= count_valid+'b1;
    end
    else if(fast_tlast0 == 'b1)
        count_valid <= 'b0;
    else begin
        cfg_tvalid <= 'b0;
        cfg_tlast <= 'b0;
    end
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        fast_tlast0 <= 'b0;
    else if(count_valid/width0==height0-'b1 && count_valid%width0==width0-'b1)
        fast_tlast0 <= 'b1;
    else 
        fast_tlast0 <= 'b0;
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        fast_tlast_last0 <= 'b0;
    else if(count_valid/width0==height0-'b1 && count_valid%width0==width0-'b1)
        fast_tlast_last0 <= 'b1;
end


always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        fast_tlast1 <= 'b0;
    else if(count_valid/width1==height1-'b1 && count_valid%width1==width1-'b1 && fast_tlast_count=='d1)
        fast_tlast1 <= 'b1;
    else 
        fast_tlast1 <= 'b0;
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        fast_tlast_last1 <= 'b0;
    else if(count_valid/width1==height1-'b1 && count_valid%width1==width1-'b1 && fast_tlast_count=='d1)
        fast_tlast_last1 <= 'b1;
end


always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        fast_tlast7 <= 'b0;
    else if(count_valid/width7==height7-'b1 && count_valid%width7==width7-'b1 && fast_tlast_count=='d2)
        fast_tlast7 <= 'b1;
    else 
        fast_tlast7 <= 'b0;
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        fast_tlast_last7 <= 'b0;
    else if(count_valid/width7==height7-'b1 && count_valid%width7==width7-'b1 && fast_tlast_count=='d2)
        fast_tlast_last7 <= 'b1;
end

reg pixelout_tvalid;
reg [31:0] pixelout_tdata;
reg [31:0] pixelout_tdata_result;
reg fastout_tvalid;
reg fastout_tlast;
wire [31:0] fastout_tdata;
reg [31:0] fastout_tdata_result;
reg [31:0] pixelout_tdata_result;

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        fastout_tdata_result <= 'b0;
        pixelout_tdata_result <= 'b0;
    end
    else if(fastout_tvalid&&fast_tlast_count=='d0)begin
        $fscanf(file_result_fast0,"%d",fastout_tdata_result);
        $fscanf(file_result_pixel0,"%d",pixelout_tdata_result);
        if(fastout_tdata!=fastout_tdata_result)
            $display("Error fast:%d,%d,%d",count,fastout_tdata,fastout_tdata_result); 
        else if(pixelout_tdata!=pixelout_tdata_result)    
            $display("Error pixel:%d,%d,%d",count,pixelout_tdata,pixelout_tdata_result); 
    end
    else if(fastout_tvalid&&fast_tlast_count=='d1)begin
        $fscanf(file_result_fast1,"%d",fastout_tdata_result);
        $fscanf(file_result_pixel1,"%d",pixelout_tdata_result);
        if(fastout_tdata!=fastout_tdata_result)
            $display("Error fast:%d,%d,%d",count,fastout_tdata,fastout_tdata_result); 
        else if(pixelout_tdata!=pixelout_tdata_result)    
            $display("Error pixel:%d,%d,%d",count,pixelout_tdata,pixelout_tdata_result); 
    end

    else if(fastout_tvalid&&fast_tlast_count=='d2)begin
        $fscanf(file_result_fast7,"%d",fastout_tdata_result);
        $fscanf(file_result_pixel7,"%d",pixelout_tdata_result);
        if(fastout_tdata!=fastout_tdata_result)
            $display("Error fast:%d,%d,%d",count,fastout_tdata,fastout_tdata_result); 
        else if(pixelout_tdata!=pixelout_tdata_result)    
            $display("Error pixel11:%d,%d,%d",count,pixelout_tdata,pixelout_tdata_result); 
    end
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        count <= 'b0;
    else if(fastout_tlast == 'd1)
        count <= 'b0;
    else 
        count <= count+'b1;
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        fast_tlast_count <= 'b0;
    else if(fastout_tlast == 'd1)
        fast_tlast_count <= fast_tlast_count+'b1;
end
wire fast_tlast;
assign fast_tlast = fast_tlast0 || fast_tlast1 || fast_tlast7;

Feature_Even inst(
    .clk(clk),
    .rst_n(rst_n),
    
    .cfg_tdata(cfg_tdata),
    .cfg_tvalid(cfg_tvalid),
    .cfg_tlast(cfg_tlast),
    .fast_tdata(fast_tdata),
    .fast_tvalid(fast_tvalid),
    .fast_tlast(fast_tlast),
    .fast_tready(fast_tready),
    .pixel_tdata(pixel_tdata),
    .pixel_tvalid(pixel_tvalid),
    .pixel_tready(pixel_tready),
    
    .pixelout_tdata(pixelout_tdata),
    .pixelout_tvalid(pixelout_tvalid),
    .pixelout_tready(pixelout_tready),
    
    .fastout_tdata(fastout_tdata),
    .fastout_tvalid(fastout_tvalid),
    .fastout_tlast(fastout_tlast),
    .fastout_tready(fastout_tready)
   

);
endmodule
