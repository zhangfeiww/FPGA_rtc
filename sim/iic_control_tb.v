`timescale 1ns/1ps
module iic_control_tb();

			reg						clk			;
			reg						rstn		;	
			reg						wr_en		;									
			reg						rd_en		;									
			reg						iic_start	;									
			reg						addr_num	;									
			reg			[15:0]		byte_addr	;									
			reg			[7:0]		wr_data		;								
									
			
			wire					iic_clk		;							
			wire					iic_end		;							
			wire		[7:0]		rd_data		;										
			wire					iic_scl		;							
			wire						sda			;
			reg						sda_in		;
			wire					sda_en		;
										
									
iic_control#(
	.DEVICE_ADDR		(7'b101_0110	)		,
	.DEVSYS_CLK_FREQ	(26'd50_000_000	)		,
	.DEVSCL_FREQ		(18'd250_000)		
)
u0_iic_control(
			.sys_clk		(clk)				,
			.sys_rstn		(rstn)				,								
			.wr_en			(wr_en)				,	
			.rd_en			(rd_en)				,
			.iic_start		(iic_start)			,
			.addr_num		(addr_num)			,
			.byte_addr		(byte_addr)			,
			.wr_data		(wr_data)			,
				
			.iic_clk		(iic_clk)			,	
			.iic_end		(iic_end)			,
			.rd_data		(rd_data)			,
			.iic_scl		(iic_scl)			,
			.iic_sda		(sda)				,
			.sda_en			(sda_en)
);

assign sda = sda_en ? 1'bz:sda_in;
pullup(sda);

always #10 clk = ~clk;

initial begin
	clk  = 1'b1;
	rstn = 1'b0;
	sda_in = 1'b0;
	iic_start =1'b0;
	#300
	rstn = 1'b1;
	iic_start =1'b1;
	wr_en = 1'b0;
	rd_en = 1'b1;
	addr_num =1 ;
	byte_addr = 16'hFA6A;
	wr_data = 8'hAB;
	#6000
	sda_in = 1'b0;		//forced assigment
	#35000
	read;
	#600000

	$finish;
end


task write;
	begin
    sda_in = 1'b1;
	delay_8bit;
	sda_in = 1'b0;
	delay_1bit;
	sda_in = 1'b1;
	delay_8bit;
	sda_in = 1'b0;
	delay_1bit;
	sda_in = 1'b1;
	delay_8bit;
	sda_in = 1'b0;
	delay_1bit;
	sda_in = 1'b1; 
	end
endtask

task read;
	begin
 /*   sda_in = 1'b1;
	delay_8bit;
	sda_in = 1'b0;
	delay_1bit;
	sda_in = 1'b1;
	delay_8bit;
	sda_in = 1'b0;
	delay_1bit;
	sda_in = 1'b1;
	delay_8bit;
	sda_in = 1'b0;
	delay_1bit;
	sda_in = 1'b1; 
	delay_1bit;
	delay_8bit;*/
force	sda_in = 1'b0;
 
	end
endtask


task delay_8bit;
	begin
    	#31980; 
	end
endtask

task delay_1bit;
	begin
    	#4020; 
	end
endtask








initial begin
	$fsdbDumpfile("iic_control.fsdb");
	$fsdbDumpvars(0,iic_control_tb);
end


endmodule
