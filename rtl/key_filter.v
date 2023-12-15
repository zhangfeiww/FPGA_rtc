module key_filter
#(
parameter CNT_MAX = 20'd999_999 
)
(
	input 	wire 				sys_clk 	, 
	input 	wire 				sys_rstn 	, 
	input 	wire 				key_in 		, 

	output 	reg 				key_flag 
);

			reg 	[19:0] 		cnt_20ms 	; 


always@(posedge sys_clk or negedge sys_rstn)begin
	if(!sys_rstn)
		cnt_20ms <= 20'b0;
	else if(key_in == 1'b1)
		cnt_20ms <= 20'b0;
	else if(cnt_20ms == CNT_MAX && key_in == 1'b0)
		cnt_20ms <= cnt_20ms;
	else
		cnt_20ms <= cnt_20ms + 1'b1;
end

always@(posedge sys_clk or negedge sys_rstn)begin
	if(!sys_rstn)
		key_flag <= 1'b0;
	else if(cnt_20ms == CNT_MAX - 1'b1)
		key_flag <= 1'b1;
	else
		key_flag <= 1'b0;
end
endmodule
