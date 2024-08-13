`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/10/25 21:02:37
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
reg     clk;
reg     rst_n;
reg [511:0] i_tdata;
wire        i_tvalid;
wire        i_tlast;
reg         i_tuser;
reg [63:0]  i_tkeep;
wire        i_tready;

wire [63:0] o_tadta;
wire [63:0] o_tadta_test;
wire        o_tvalid;
wire        o_tlast;
wire        o_tuser;
wire [3:0]  o_tkeep;
reg         o_tready;
// flag decide left or right
reg         left_ready;
reg         right_ready;


integer file_rsbrief_left,file_rsbrief_right,file_result1,file_result2;
initial begin
    clk = 0;
    rst_n = 0;
    left_ready = 0;
    #25;rst_n = 1;
    left_ready = 1;
    o_tready = 1;
    file_rsbrief_left = $fopen("/home/lqw/lqw_workspace/05_FPGA_SLAM/Cam2_acSLAM/IP/Feature_Match/Feature_Match.srcs/sim_1/new/result_left.txt","rb");
    file_rsbrief_right = $fopen("/home/lqw/lqw_workspace/05_FPGA_SLAM/Cam2_acSLAM/IP/Feature_Match/Feature_Match.srcs/sim_1/new/result_right.txt","rb");
    file_result1 = $fopen("/home/lqw/lqw_workspace/05_FPGA_SLAM/Cam2_acSLAM/IP/Feature_Match/Feature_Match.srcs/sim_1/new/result_match1.txt","w");
    file_result2 = $fopen("/home/lqw/lqw_workspace/05_FPGA_SLAM/Cam2_acSLAM/IP/Feature_Match/Feature_Match.srcs/sim_1/new/result_match2.txt","w");
end
always #5 clk = ~clk;

reg[15:0] valid_count_all;
reg compelet_flag;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        compelet_flag <= 'b0;
    else if(valid_count_all=='d1300)
        compelet_flag <= 'b1;
end

reg i_tvalid_flag;
reg i_tlast_flag;
assign i_tvalid = compelet_flag?'b0:(i_tvalid_flag?'b1:'b0);
//assign i_tvalid = i_tvalid_flag?(compelet_flag?'b0:valid_count[5]):'b0;
assign i_tlast = i_tvalid?(((valid_count_all=='d135||valid_count_all=='d450||valid_count_all=='d1000||valid_count_all=='d1300)&&i_tlast_flag=='b1)?'b1:'b0):'b0;

reg select;
always@(posedge left_ready or posedge right_ready)begin
    if(left_ready=='b1)
        select <= 'b0;
    else if(right_ready=='b1)
        select <= 'b1;
    else
        select <= select;
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        i_tdata <= 'b0;
        valid_count_all <= 'b0;
        i_tvalid_flag <= 'b0;
        i_tlast_flag <= 'b0;
    end
    else if($urandom_range(0,200)=='d1 && select=='b0 && valid_count_all<'d135 && i_tvalid=='b0 && i_tready=='b1)begin
        $fscanf(file_rsbrief_left,"%d",i_tdata);
        if(valid_count_all=='d134)
            i_tlast_flag = 'b1;
        valid_count_all <= valid_count_all+'b1;
        i_tvalid_flag <= 'b1;
        
    end
    else if(valid_count_all<='d300 && valid_count_all>='d135)begin
        valid_count_all <= valid_count_all+'b1;
        i_tvalid_flag <= 'b0;
        i_tlast_flag <= 'b0;
    end
    else if($urandom_range(0,200)=='d1 && select=='b1&& valid_count_all<'d450 && valid_count_all>'d300 && i_tvalid=='b0 && i_tready=='b1)begin
        $fscanf(file_rsbrief_right,"%d",i_tdata);
        if(valid_count_all=='d449)
            i_tlast_flag = 'b1;
        valid_count_all <= valid_count_all+'b1;
        i_tvalid_flag <= 'b1;
        
    end
    else if(valid_count_all<='d800 && valid_count_all>='d450)begin
        valid_count_all <= valid_count_all+'b1;
        i_tvalid_flag <= 'b0;
        i_tlast_flag <= 'b0;
    end
    else if($urandom_range(0,2)=='d1 && select=='b0&& valid_count_all<'d1000 && valid_count_all>'d800 && i_tvalid=='b0 && i_tready=='b1)begin
        $fscanf(file_rsbrief_left,"%d",i_tdata);
        if(valid_count_all=='d999)
            i_tlast_flag = 'b1;
        valid_count_all <= valid_count_all+'b1;
        i_tvalid_flag <= 'b1;
        
    end
    else if(valid_count_all<='d1100 && valid_count_all>='d1000)begin
        valid_count_all <= valid_count_all+'b1;
        i_tvalid_flag <= 'b0;
        i_tlast_flag <= 'b0;
    end
    else if($urandom_range(0,2)=='d1 && select=='b1&& valid_count_all<'d1300 && valid_count_all>'d1100 && i_tvalid=='b0 && i_tready=='b1)begin
        $fscanf(file_rsbrief_right,"%d",i_tdata);
        if(valid_count_all=='d1299)
            i_tlast_flag = 'b1;
        valid_count_all <= valid_count_all+'b1;
        i_tvalid_flag <= 'b1;
        
    end
    else begin
        i_tvalid_flag <= 'b0;
        i_tlast_flag = 'b0;
    end
end
always@(posedge clk)begin
    if(o_tvalid=='b1 && valid_count_all<='d802)begin
        $fdisplay(file_result1,"%d",o_tadta);
        if(o_tlast=='b1)
            $fclose(file_result1);
    end
end
always@(posedge clk)begin
    if(o_tvalid=='b1 && valid_count_all>'d802)begin
        $fdisplay(file_result2,"%d",o_tadta);
        if(o_tlast=='b1)
            $fclose(file_result2);
    end
end

always@(posedge clk)begin
    if(valid_count_all=='d1)
        left_ready <= 'b1;
    else if(valid_count_all=='d300)begin
        right_ready <= 'b1;
    end
    else if(valid_count_all=='d800)begin
        left_ready <= 'b1;
    end
    else if(valid_count_all=='d1100)begin
        right_ready <= 'b1;
    end
    else begin
        left_ready <= 'b0;
        right_ready <= 'b0;
    end
end
//reg flag;
//always@(posedge clk or negedge rst_n)begin
//    if(!rst_n)
//        flag <= 'b0;
//    else if((o_tvalid=='b1)&&(o_tadta_test!=o_tadta))begin
//        flag <= 'b1;
//        $display("Error:%d,%d,%d",valid_count_all,o_tadta_test,o_tadta); 
//    end
//    else
//        flag <= 'b0;
//end

Feature_Match inst(
    .clk(clk),
    .rst_n(rst_n),
    // input rs_brief axis 
    .I_AXIS_tdata(i_tdata),
    .I_AXIS_tvalid(i_tvalid),
    .I_AXIS_tlast(i_tlast),
    .I_AXIS_tuser(i_tuser),
    .I_AXIS_tkeep(i_tkeep),
    .I_AXIS_tready(i_tready),
    // ouput match pixels to dma axis
    .O_AXIS_tdata(o_tadta),
    .O_AXIS_tvalid(o_tvalid),
    .O_AXIS_tlast(o_tlast),
    .O_AXIS_tuser(o_tuser),
    .O_AXIS_tkeep(o_tkeep),
    .O_AXIS_tready(o_tready)
 
    );

endmodule