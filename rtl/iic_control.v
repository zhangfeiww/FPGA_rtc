module iic_control#(
	parameter		DEVICE_ADDR		=	7'b101_0001		,//slave device address
	parameter		SYS_CLK_FREQ	=	26'd50_000_000	,//frequency of systerm
	parameter		SCL_FREQ		=	18'd250_000
)
(
	input	wire					sys_clk			,
	input	wire					sys_rstn		,								
	input	wire					wr_en			,	
	input	wire					rd_en			,
	input	wire					iic_start		,
	input	wire					addr_num		,
	input	wire		[15:0]		byte_addr		,
	input	wire		[7:0]		wr_data			,

	output	reg						iic_clk			,	
	output	reg						iic_end			,
	output	reg			[7:0]		rd_data			,
	output	reg						iic_scl			,
	inout	wire					iic_sda			

);

localparam CNT_CLK_MAX = (SYS_CLK_FREQ/SCL_FREQ) >> 2'd3 ;//divide 


			reg 	[7:0] 		cnt_clk 			; 
			reg 				cnt_iic_clk_en 		; 
			reg     [1:0]       cnt_iic_clk 		; 
			reg 	[2:0] 		cnt_bit 			;
			reg					ack					;
			reg 	[3:0] 		current_state		;
			reg 	[3:0] 		next_state			;

			wire 				sda_in 				; //sda输入数据寄存
			wire 				sda_en 				; //sda数据写入使能信号
			reg 				wr_data_buff 		; //out of sda data buff
			reg 	[7:0] 		rd_data_buff 		; //自i2c设备读出数据

/*******************output iic_clk(1MHz)*******************/
always@(posedge sys_clk or negedge sys_rstn)begin
	if(!sys_rstn)
		cnt_clk <= 8'd0;
	else if(cnt_clk == CNT_CLK_MAX - 1'b1)
		cnt_clk <= 8'd0;
	else
		cnt_clk <= cnt_clk + 1'b1;
end

always@(posedge sys_clk or negedge sys_rstn)begin
	if(sys_rstn == 1'b0)
		iic_clk <= 1'b1;
	else if(cnt_clk == CNT_CLK_MAX - 1'b1)
		iic_clk <= ~iic_clk;
end
/*******************state machine *******************/
localparam			IDLE				=	4'd0		,
					START_1				=	4'd1		,
					SEND_DW_ADDR		=	4'd2		,
					SLAVE_ACK_1			=	4'd3		,
					SEND_BIT_ADDR_H		=	4'd4		,
					SLAVE_ACK_2			=	4'd5		,
					SEND_BIT_ADDR_L		=	4'd6		,
					SLAVE_ACK_3			=	4'd7		,
					WR_DATA				=	4'd8		,
					SLAVE_ACK_4			=	4'd9		,
					START_2				=	4'd10		,
					SEND_DR_ADDR		=	4'd11		,
					SLAVE_ACK_5			=	4'd12		,
					RD_DATA				=	4'd13		,
					MASTER_NACK			=	4'd14		,
					STOP				=	4'd15		;

//-----------------------fist------------------------//
always @(posedge iic_clk or negedge sys_rstn) begin
        if (!sys_rstn)
            current_state <= IDLE;
        else
            current_state <= next_state;
end
//-----------------------second----------------------//
always @(*) begin
        case (current_state)
            IDLE			:		begin
                						if(iic_start == 1'b1)
                    					next_state = START_1;
										else
											next_state = IDLE;
            	  					end
            START_1			: 		begin
                						if(cnt_iic_clk == 3)
                    						next_state = SEND_DW_ADDR;
										else
											next_state = START_1;
            						end
			SEND_DW_ADDR	: 		begin
                						if((cnt_bit == 3'd7) &&(cnt_iic_clk == 3))
                    						next_state = SLAVE_ACK_1;
										else
											next_state = SEND_DW_ADDR;
            						end
			SLAVE_ACK_1		: 		begin
                						if((cnt_iic_clk == 3) && (ack == 1'b0))
											begin
												if(addr_num == 1'b1)
                    								next_state = SEND_BIT_ADDR_H;
												else
													next_state = SEND_BIT_ADDR_L;
											end
										else
											next_state = SLAVE_ACK_1;
            						end
			SEND_BIT_ADDR_H	: 		begin
                						if((cnt_bit == 3'd7) &&(cnt_iic_clk == 3))
                    						next_state = SLAVE_ACK_2;
										else
											next_state = SEND_BIT_ADDR_H;
            						end
			SLAVE_ACK_2		: 		begin
                						if((cnt_iic_clk == 3) && (ack == 1'b0))
                    						next_state = SEND_BIT_ADDR_L;
										else
											next_state = SLAVE_ACK_2;
            						end
			SEND_BIT_ADDR_L	: 		begin
                						if((cnt_bit == 3'd7) &&(cnt_iic_clk == 3))
                    						next_state = SLAVE_ACK_3;
										else
											next_state = SEND_BIT_ADDR_L;
            						end
			SLAVE_ACK_3		: 		begin
                						if((wr_en == 1'b1) && (cnt_bit == 3'd0) &&(cnt_iic_clk == 3))
                    						next_state = WR_DATA;
										else if((rd_en == 1'b1) && (cnt_bit == 3'd0) &&(cnt_iic_clk == 3))
											next_state = START_2;
										else
											next_state = SLAVE_ACK_3;
            						end

			WR_DATA			:	 	begin
                						if((cnt_bit == 3'd7) &&(cnt_iic_clk == 3))
                    						next_state = SLAVE_ACK_4;
										else
											next_state = WR_DATA;
            						end
			SLAVE_ACK_4		: 		begin
                						if((cnt_iic_clk == 3) && (ack == 1'b0))
                    						next_state = STOP;
										else
											next_state = SLAVE_ACK_4;
            						end

 			START_2			: 		begin
                						if(cnt_iic_clk == 3)
                    						next_state = SEND_DR_ADDR;
										else
											next_state = START_2;
            						end
			SEND_DR_ADDR	: 		begin
                						if((cnt_bit == 3'd7) &&(cnt_iic_clk == 3))
                    						next_state = SLAVE_ACK_5;
										else
											next_state = SEND_DR_ADDR;
            						end

			SLAVE_ACK_5		: 		begin
                						if((cnt_iic_clk == 3) && (ack == 1'b0))
                    						next_state = RD_DATA;
										else
											next_state = SLAVE_ACK_5;
            						end
		
			RD_DATA			:	 	begin
                						if((cnt_bit == 3'd7) &&(cnt_iic_clk == 3))
                    						next_state = MASTER_NACK;
										else
											next_state = RD_DATA;
            						end
			MASTER_NACK		:	    begin
                						if(cnt_iic_clk == 3)
                    						next_state = STOP;
										else
											next_state = MASTER_NACK;
            						end
			STOP			:		begin
                						if((cnt_bit == 3'd3) &&(cnt_iic_clk == 3))
                    						next_state = IDLE;
										else
											next_state = STOP;
            						end
			default			:		next_state = IDLE;
		endcase
end
//-----------------------third-----------------------//
always @(*) begin
	case (current_state)
            IDLE			:		begin
                						wr_data_buff = 1'b1;
										rd_data_buff = 8'd0;
            	  					end
            START_1			: 		begin
                						if(cnt_iic_clk <= 2'd1)
                    						wr_data_buff = 1'b1;			// scl is high ,then sda is negedge ,start;
										else
											wr_data_buff = 1'b0; 
            						end
			SEND_DW_ADDR	: 		begin
                						if(cnt_bit != 3'd7)
                    						wr_data_buff = DEVICE_ADDR[6 - cnt_bit];
										else
											wr_data_buff = 1'b0; //0 is write
            						end
			SLAVE_ACK_1		: 		begin
                							wr_data_buff = 1'b1;
            						end
			SEND_BIT_ADDR_H	: 		begin
                						wr_data_buff = byte_addr[15 - cnt_bit];
            						end
			SLAVE_ACK_2		: 		begin
                						wr_data_buff = 1'b1;
            						end
			SEND_BIT_ADDR_L	: 		begin
                						wr_data_buff = byte_addr[7 - cnt_bit];
            						end
			SLAVE_ACK_3		: 		begin
                						wr_data_buff = 1'b1;
            						end
			WR_DATA			:	 	begin
                						wr_data_buff = wr_data[7 - cnt_bit];
            						end
			SLAVE_ACK_4		: 		begin
                						wr_data_buff = 1'b1;
            						end

 			START_2			: 		begin
                					if(cnt_iic_clk <= 2'd1)
                    						wr_data_buff = 1'b1;
										else
											wr_data_buff = 1'b0;
            						end
			SEND_DR_ADDR	: 		begin
                						if(cnt_bit != 3'd7)
                    						wr_data_buff = DEVICE_ADDR[6 - cnt_bit];
										else
											wr_data_buff = 1'b1;//1 is read
            						end

			SLAVE_ACK_5		: 		begin
                						wr_data_buff = 1'b1;
            						end
		
			RD_DATA			:	 	begin
                						if(cnt_iic_clk == 2'd0)
                    						rd_data_buff[7 - cnt_bit] = sda_in;
										else
											rd_data_buff = rd_data_buff;
            						end
			MASTER_NACK		:	    begin
                						wr_data_buff = 1'b1;
            						end
			STOP			:		begin
                						if((cnt_bit == 3'd0) &&(cnt_iic_clk < 3))
                    						wr_data_buff = 1'b0;					// scl is high ,then sda is posedge ,stop;
										else
											wr_data_buff = 1'b1;
            						end
			default			:		begin
										wr_data_buff = 1'b1;
										rd_data_buff = rd_data_buff;
									end
	endcase
end


/*******************generate cnt_bit*******************/
always@(posedge iic_clk or negedge sys_rstn)begin
	if(!sys_rstn )
		cnt_iic_clk_en <= 1'b0;
	else if((current_state == STOP) && (cnt_bit == 3'd3) &&(cnt_iic_clk == 3))
		cnt_iic_clk_en <= 1'b0;
	else if(iic_start == 1'b1)
		cnt_iic_clk_en <= 1'b1;
end

always@(posedge iic_clk or negedge sys_rstn)begin
	if(!sys_rstn )
		cnt_iic_clk <= 2'd0;
	else if(cnt_iic_clk_en == 1'b1)
		cnt_iic_clk <= cnt_iic_clk + 1'b1;
end

always@(posedge iic_clk or negedge sys_rstn)begin
 	if(!sys_rstn)
 		cnt_bit <= 3'd0;
 	else if((current_state == IDLE) || (current_state == START_1) || (current_state == START_2) 
 				|| (current_state == SLAVE_ACK_1) || (current_state == SLAVE_ACK_2) || (current_state == SLAVE_ACK_3) 
 				|| (current_state == SLAVE_ACK_4) || (current_state == SLAVE_ACK_5) || (current_state == MASTER_NACK))
 		cnt_bit <= 3'd0;
 	else if((cnt_bit == 3'd7) && (cnt_iic_clk == 2'd3))
 		cnt_bit <= 3'd0;
 	else if((cnt_iic_clk == 2'd3) && (current_state != IDLE))
 		cnt_bit <= cnt_bit + 1'b1;
end
/*******************ack*******************/
always@(*)begin
 	case (current_state)
 		IDLE,START_1,SEND_DW_ADDR,SEND_BIT_ADDR_H,SEND_BIT_ADDR_L,
 		WR_DATA,START_2,SEND_DR_ADDR,RD_DATA,MASTER_NACK				:		ack = 1'b1;
 		SLAVE_ACK_1,SLAVE_ACK_2,SLAVE_ACK_3,SLAVE_ACK_4,SLAVE_ACK_5		:	begin
																				if(cnt_iic_clk == 2'd0)
 																					ack = sda_in;
 																				else
 																					ack = ack;
																			end
 		default	: 		ack = 1'b1;
 	endcase
 end
 /*******************scl*******************/
always@(*)begin
 	case (current_state)
 		IDLE															: 		iic_scl <= 1'b1;
 		START_1															:	begin
 																				if(cnt_iic_clk == 2'd3)
 																					iic_scl = 1'b0;
 																				else
 																					iic_scl = 1'b1;
																			end
 		SEND_DW_ADDR,SLAVE_ACK_1,SEND_BIT_ADDR_H,SLAVE_ACK_2,SEND_BIT_ADDR_L,SLAVE_ACK_3,WR_DATA,
 		SLAVE_ACK_4,START_2,SEND_DR_ADDR,SLAVE_ACK_5,RD_DATA,MASTER_NACK:	begin
																				if((cnt_iic_clk == 2'd1) || (cnt_iic_clk == 2'd2))
 																					iic_scl = 1'b1;
 																				else
 																					iic_scl = 1'b0;
																			end
 	
 		STOP															:	begin
																		
 																				if((cnt_bit == 3'd0) &&(cnt_iic_clk == 2'd0))
 																				iic_scl = 1'b0;
 																				else
 																				iic_scl = 1'b1;
																			end
 		default															: 		iic_scl = 1'b1;
 	endcase
end
/*******************rd_data*******************/
always@(posedge iic_clk or negedge sys_rstn)begin
	if(!sys_rstn)
		rd_data <= 8'd0;
 	else if((current_state == RD_DATA)&&(cnt_bit == 3'd7)&&(cnt_iic_clk == 2'd3))
 		rd_data <= rd_data_buff;
 end
/*******************iic_end*******************/
always@(posedge iic_clk or negedge sys_rstn)begin
 	if(!sys_rstn)
 		iic_end <= 1'b0;
 	else if((current_state == STOP) && (cnt_bit == 3'd3) &&(cnt_iic_clk == 3))
 		iic_end <= 1'b1;
 	else
 		iic_end <= 1'b0;
end

/*******************iic_sda*******************/
assign sda_in = iic_sda;
assign sda_en = ((current_state == RD_DATA)||(current_state == SLAVE_ACK_1)||(current_state == SLAVE_ACK_2)
|| (current_state == SLAVE_ACK_3)||(current_state == SLAVE_ACK_4)||(current_state == SLAVE_ACK_5))? 1'b0 : 1'b1;//0 is open
 assign iic_sda = (sda_en == 1'b1) ? wr_data_buff : 1'bz;

endmodule

