module BPSK #(parameter SG_SIZE = 10, N = 8)
//SG_SIZE - разрядность сигнала
//N - параметр модуля (Ts = N*Tclk)
//ВАЖНО!!! Если хотим работать на минимальной частоте несущего сигнала,
//			  то 	N = 2*4*PHAS_INC(MAX=255), при действительной PHAS_INC = 1

(
    input clk,      //тактовый сигнал
    input tx_enb,   //сигнал разрешения передачи (формирования сигнала
    input CE,       //сигнал разрешения передачи тактового сигнала
    input reset,    //сигнал сброса

    output [SG_SIZE-1:0] sin_out, //выход гармонического сигнала на промежуточной частоте.
    output [SG_SIZE-1:0] tx_out	 //выход промодулированного сигнала на промежуточной частоте.	
	 
//	  temp
//	  ,output clkdivn,
//	  ,output sg_mod
);

wire 	 					sg_mod;	  		//мудулирующий сигнал 
wire [SG_SIZE-1:0]	tx_sg;			//внутренний модулированный сигнал
wire [SG_SIZE-1:0] 	derect_sg; 		//phase = 0
wire [SG_SIZE-1:0] 	shift_sg;  		//phase = pi


assign clk_act = clk & CE;
assign tx_sg   = (sg_mod) ?  derect_sg:shift_sg; 
assign tx_out  = (tx_enb) ?  tx_sg : 10'hZ;		//Модулированный сигнал
assign sin_out = derect_sg;


mod_sg_generator #(
	.N(N)) SG_GEN(
	.clk	 			(clk_act),
	.tx_enb  		(tx_enb),
	.reset			(reset),
	.sg_mod			(sg_mod)
	);
	
mod_sine_generator #(
	.SG_SIZE(SG_SIZE), 
	.PHAS_INC(255)) SINE_GEN(
		//PHAS_INC - параметр инкрементирования фазового аккумулятоора (задает частоту сигнала)
		//при PHAS_INC = 255 - работает правильно	(удовлетворяет условию задачи) - максимальная частота
		//при PHAS_INC =   1 - работает правильно - минимальная частота
		//при иных PHAS_INC	- ведет непредсказуемо 
	.clk	 			(clk_act),
	.reset			(reset),
	.derect_sg		(derect_sg),
	.shift_sg 		(shift_sg)
	);	


endmodule

/*Генерация модулирующего сигнала*/
module mod_sg_generator #(parameter N)(
    input 	clk,      
    input 	tx_enb,        
    input 	reset,
	 output	sg_mod
	 );
	 
reg [10:0]  clkdiv_cnt;
reg 		 	clkdiv_pulse;
reg [ 6:0] 	sg_mod_sreg = 7'b1010110;


assign clkdivN = clkdiv_pulse;

//делитель чстоты
	always @(posedge clk)
		begin 
			if (reset) begin
					clkdiv_cnt 	 <= 0;
					clkdiv_pulse <= 0;
					end
			else begin clkdiv_cnt[ 10:0]  <= clkdiv_cnt + 1;
			
			if (clkdiv_cnt == N-2) begin
					clkdiv_pulse <= 1;
					clkdiv_cnt 	 <= 0;
					end
			
			if (clkdiv_pulse == 1) begin
					clkdiv_pulse <= 0;
					clkdiv_cnt 	 <= 0;
					end
			end
		end

//сдвиговой регистр	
	always @(posedge clkdivN) 
		begin 
			if (reset) 
					sg_mod_sreg <= 7'b1010110; //перевернутая исходная последовательность
			else if (tx_enb) 
					sg_mod_sreg <=  {sg_mod_sreg[0], sg_mod_sreg[6:1]};
		end		
	assign sg_mod  = sg_mod_sreg[6];
	
endmodule
  
  
/*Генерация модулируемого сигнала*/	 
module mod_sine_generator #(parameter SG_SIZE, PHAS_INC)(
		input 						 clk,
		input 						 reset,
		output 	  [		  7:0] pha_accum_sg,
		output reg [SG_SIZE-1:0] derect_sg,
		output reg [SG_SIZE-1:0] shift_sg
);

reg [7:0] delta_phase = PHAS_INC;
reg [7:0] count_phase = 0;
reg [1:0] state;

wire [8:0] pre_signal;

assign pha_accum_sg = count_phase;

localparam [1:0] I_QURTER   = 0;
localparam [1:0] II_QURTER  = 1;
localparam [1:0] III_QURTER = 2;
localparam [1:0] IV_QURTER  = 3;

always @(posedge clk) begin
	if (reset) begin
		state 		<= 0;
		count_phase <= 0;
		end
	
	else begin 
	case (state)
		I_QURTER: 
			begin if (count_phase < 255) begin
					derect_sg 	<= {1'b1,  pre_signal};
					shift_sg  	<= {1'b0, ~pre_signal};
					state 	 	<= I_QURTER;
					count_phase <= count_phase +delta_phase;
				end
				else begin
					//delta_phase <= (~delta_phase)+1;
					derect_sg 	<= {1'b1,  pre_signal};
					shift_sg  	<= {1'b0, ~pre_signal};
					count_phase <= count_phase -delta_phase;
					state 	 	<= II_QURTER;
				end
			end
			
		II_QURTER: 
			begin if (count_phase > 0) begin
					derect_sg 	<= {1'b1,  pre_signal};
					shift_sg  	<= {1'b0, ~pre_signal};
					state 	 	<= II_QURTER;
					count_phase <= count_phase -delta_phase;
				end
				else begin
					derect_sg 	<= {1'b0, ~pre_signal};
					shift_sg  	<= {1'b1,  pre_signal};
					state 	 	<= III_QURTER;
					count_phase <= count_phase + delta_phase;
				end
			end
		III_QURTER: 
			begin if (count_phase < 255) begin
					derect_sg 	<= {1'b0, ~pre_signal};
					shift_sg  	<= {1'b1,  pre_signal};
					state 	 	<= III_QURTER;
					count_phase <= count_phase +delta_phase;			
				end
				else begin
					derect_sg 	<= {1'b0, ~pre_signal};
					shift_sg  	<= {1'b1,  pre_signal};
					state 	 	<= IV_QURTER;
					count_phase <= count_phase -delta_phase;	
				end
			end
			
		IV_QURTER: 
			begin if(count_phase > 0) begin
					derect_sg 	<= {1'b0, ~pre_signal};
					shift_sg  	<= {1'b1,  pre_signal};
					state 	 	<= IV_QURTER;
					count_phase <= count_phase -delta_phase;			
				end
				else begin
					derect_sg 	<= {1'b0, ~pre_signal};
					shift_sg  	<= {1'b1,  pre_signal};
					state 	 	<= I_QURTER;
					count_phase <= count_phase +delta_phase;	
				end		
			end
	endcase
	end
	
end		

pha2amp_ROM AMP_ROM(
	.ADDR1			(pha_accum_sg),
	.RDATA1			(pre_signal)
	);
endmodule

/*ПЗУ со значениями амплитуды синуса*/
module pha2amp_ROM #(parameter ROM_SIZE = 256, WORD_SIZE = 9)(
		input  [WORD_SIZE-2:0] ADDR1,
		output [WORD_SIZE-1:0] RDATA1
);

reg 	 [WORD_SIZE-1:0] reg_mem[ROM_SIZE-1:0];
assign RDATA1  = reg_mem[ADDR1[WORD_SIZE-2:0]];

initial begin
       $readmemh ("../source/phase2amp.hex", reg_mem); //указать правильный адрес 
   end


endmodule

    