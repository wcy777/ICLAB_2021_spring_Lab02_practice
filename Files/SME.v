//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   2021 ICLAB Spring Course practice
//   Lab02     : String Match Engine (SME)
//   Author    : Chun-Yi Wang (eric88728@gmail.com)
//   Date      : 2022-07-25 ~ 2022-07-27
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : SME.v
//   Module Name : SME
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module SME (
    //input ports
    clk, rst_n,
    ispattern,
    isstring,
    chardata,
    //output ports
    out_valid,
    match,
    match_index
);

input clk, rst_n;
input ispattern, isstring;
input [7:0] chardata;
output reg out_valid;
output reg match;
output reg [4:0] match_index;

integer i;

//local parameter
localparam IDLE = 3'b000;
localparam READ_STRING = 3'b001;
localparam READ_PATTERN = 3'b010;
localparam COMPUTE = 3'b011;
localparam FINISH = 3'b100;

reg [2:0] current_state, next_state;        //state

reg [7:0] str_reg [0:34];       //string register
reg [5:0] str_index;            //string index
reg [5:0] str_index_cnt;        //counter of string_index
reg [7:0] pat_reg [0:8];        //pattern register
reg [3:0] pat_index;            //pattern index
reg start_char;                 //special character ^
reg end_char;                   //special character &
reg mul_char;                   //special character *
wire mul_char_tmp;

reg [5:0] cmps_index;           //compare string index
reg [2:0] cmps_index_cnt;       //counter of cmps_index
reg [3:0] cmpp_index;           //compare pattern index
reg [3:0] cmpp_index_cnt;       //counter of cmpp_index
wire cmp_flag;                  //cpmpare flag
wire match_en;                  //on when match in COMPUTE
reg match_tmp;                  //store match_en
wire unmatch_en;                //unmatch signal

//FSM
always @(posedge clk, negedge rst_n) begin
    if(!rst_n) current_state <= IDLE;
    else current_state <= next_state;
end

always @(*) begin
    case (current_state)
        IDLE:begin
            if(isstring)    next_state = READ_STRING;
            else if(ispattern) next_state = READ_PATTERN;
            else            next_state = IDLE;
        end
        READ_STRING:begin
            if(ispattern) next_state = READ_PATTERN;
            else next_state = READ_STRING;
        end        
        READ_PATTERN:begin
            if(!ispattern) next_state = COMPUTE;
            else next_state = READ_PATTERN;
        end
        COMPUTE:begin
            if(match_en | unmatch_en == 1'b1) next_state = FINISH;
            else next_state = COMPUTE;
        end
        FINISH:begin
            next_state = IDLE;
        end
        default:
            next_state = IDLE;
    endcase
end

/****************************************COMPUTE***********************************************/

assign cmp_flag = (current_state == COMPUTE)? ((str_reg[cmps_index] == pat_reg[cmpp_index]) || (pat_reg[cmpp_index] == 8'h2E))? 1'b1: 1'b0: 1'b0;
assign match_en = (cmpp_index == pat_index)? 1'b1: 1'b0;
assign unmatch_en = (end_char)? ((cmps_index == str_index_cnt + 2'b10)? 1'b1: 1'b0): (cmps_index == (str_index_cnt + 1'b1))? 1'b1: 1'b0;

//cmps_index
always @(posedge clk, negedge rst_n) begin
    if(!rst_n) cmps_index <= 6'b0;
    else if(current_state == COMPUTE) 
        if(cmp_flag) cmps_index <= cmps_index + 1'b1;
        else if(cmp_flag == 1'b0 && cmps_index != 1'b0)begin                        
            if(pat_reg[cmpp_index] == 8'h2A) cmps_index <= cmps_index;                     //handle sprcial chardata *
            else cmps_index <= cmps_index - cmps_index_cnt + 1'b1;
        end 
        else cmps_index <= cmps_index + 1'b1;
    else begin
        if(start_char) cmps_index <= 6'b0;
        else cmps_index <= 6'b1;
    end 
end
//cmpp_index
always @(posedge clk, negedge rst_n) begin
    if(!rst_n) cmpp_index <= 4'b0;
    else if(current_state == COMPUTE)begin
        if(cmp_flag == 1'b1 || pat_reg[cmpp_index] == 8'h2A) cmpp_index <= cmpp_index + 1'b1;       //handle sprcial chardata *
        else begin
            if(mul_char) cmpp_index <= cmpp_index_cnt;
            else cmpp_index <= 4'b0;
        end
    end
    else cmpp_index <= 4'b0;
end
//match_tmp
always @(posedge clk, negedge rst_n) begin
    if(!rst_n) match_tmp <= 1'b0;
    else if(current_state == COMPUTE)begin
        if(match_en) match_tmp <= 1'b1;
        else match_tmp <= 1'b0;
    end
    else if(current_state == IDLE) match_tmp <= 1'b0;
    else match_tmp <= match_tmp;
end
//cmps_index_cnt
always @(posedge clk, negedge rst_n) begin
    if(!rst_n) cmps_index_cnt <= 3'b0;
    else if(current_state == COMPUTE)begin
        if(cmp_flag == 1'b1) cmps_index_cnt <= cmps_index_cnt + 1'b1;
        else cmps_index_cnt <= 3'b0;
    end
    else if(current_state == IDLE) cmps_index_cnt <= 3'b0;
    else cmps_index_cnt <= cmps_index_cnt;
end
//cmpp_index_cnt
always @(posedge clk, negedge rst_n) begin
    if(!rst_n) cmpp_index_cnt <= 4'b0;
    else if(current_state == COMPUTE)begin
        if(mul_char) cmpp_index_cnt <= cmpp_index_cnt;
        else cmpp_index_cnt <= cmpp_index + 1'b1;
    end
    else if(current_state == IDLE) cmpp_index_cnt <= 4'b0;
    else cmpp_index_cnt <= cmpp_index_cnt;
end

/****************************************READ***********************************************/

//read string
always @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        for (i = 0; i < 35; i = i + 1) begin
            str_reg[i] <= 8'h20;
        end
    end
    else if(isstring == 1'b1) begin
        if(str_index == 6'b1)begin
            str_reg[str_index] <= chardata;
            str_reg[0] <= 8'h21;
            for (i = 2; i < 35; i = i + 1) begin
                str_reg[i] <= 8'h21;
            end 
        end
        else str_reg[str_index] <= chardata;
    end
    else if(current_state == READ_PATTERN)begin
        if(end_char) str_reg[str_index_cnt+1] <= 8'h20;
        else if(start_char) str_reg[0] <= 8'h20;
        else begin
            str_reg[0] <= 8'h21;
            str_reg[str_index_cnt+1] <= 8'h21;
        end
    end
    else begin
        for (i = 0; i < 35; i = i + 1) begin
            str_reg[i] <= str_reg[i];
        end
    end
end
//string index
always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        str_index <= 6'b1;
    else if(isstring)  
        str_index <= str_index + 1'b1;
    else if(current_state == IDLE)
        str_index <= 6'b1;
    else 
        str_index <= str_index;
end
//str_index_cnt
always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        str_index_cnt <= 6'b1;
    else if(isstring)  
        str_index_cnt <= str_index;
    else 
        str_index_cnt <= str_index_cnt;
end
//read pattern
always @(posedge clk, negedge rst_n) begin
    if(!rst_n) 
        for (i = 0; i < 10; i = i + 1) begin
            pat_reg[i] <= 8'b0;
        end
    else if(ispattern) begin
        pat_reg[pat_index] <= (chardata == 8'h5E || chardata == 8'h24)? 8'h20: chardata;
    end
    else if(current_state == IDLE)
        for (i = 0; i < 10; i = i + 1) begin
            pat_reg[i] <= 8'b0;
        end
    else 
        for (i = 0; i < 10; i = i + 1) begin
            pat_reg[i] <= pat_reg[i];
        end
end
//pattern index
always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        pat_index <= 4'b0;
    else if(ispattern)  
        pat_index <= pat_index + 1'b1;
    else if(current_state == IDLE)
        pat_index <= 4'b0;
    else 
        pat_index <= pat_index;
end
//start_char
always @(posedge clk, negedge rst_n) begin
    if(!rst_n) start_char <= 1'b0;
    else if(ispattern)begin
        if(chardata == 8'h5E) start_char <= 1'b1;
        else start_char <= start_char;
    end
    else if(current_state == IDLE) start_char <= 1'b0;
    else start_char <= start_char;
end
//end_char
always @(posedge clk, negedge rst_n) begin
    if(!rst_n) end_char <= 1'b0;
    else if(ispattern)begin
        if(chardata == 8'h24) end_char <= 1'b1;
        else end_char <= end_char;
    end
    else if(current_state == IDLE) end_char <= 1'b0;
    else end_char <= end_char;
end
//mul_char
always @(posedge clk, negedge rst_n) begin
    if(!rst_n) mul_char <= 1'b0;
    else if(current_state == COMPUTE) mul_char <= mul_char_tmp;
    else if(current_state == IDLE) mul_char <= 1'b0;
    else mul_char <= mul_char;
end
assign mul_char_tmp = (pat_reg[cmpp_index] == 8'h2A)? 1'b1: mul_char;

/****************************************FINISH***********************************************/

//output_valid
always @(posedge clk, negedge rst_n) begin
    if(!rst_n) out_valid <= 1'b0;
    else if(current_state == FINISH) out_valid <= 1'b1;
    else out_valid <= 1'b0;
end
//match
always @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        match <= 1'b0;
    end
    else if(current_state == FINISH)begin
        if(match_tmp) match <= 1'b1;
        else match <= 1'b0;
    end
    else match <= 1'b0;  
end
//match_index
always @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        match_index <= 5'b0;
    end
    else if(current_state == COMPUTE) begin
        if((cmp_flag | match_en | mul_char_tmp) == 1'b0) match_index <= match_index + 1'b1;
        else match_index <= match_index;
    end
    else if(current_state == FINISH)begin
        if(match_tmp) begin
            if(start_char) match_index <= match_index;
            else match_index <= match_index;
        end
        else match_index <= 5'b0;
    end
    else match_index <= 5'b0;
end
    
endmodule