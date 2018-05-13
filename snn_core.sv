module snn_core(start, q_input, addr_input_unit, digit_reg, done, clk, rst_n);
	//interface inputs and outputs
	input start, q_input, clk, rst_n;
	output reg done;
	output reg [9:0] addr_input_unit;
	output logic [3:0] digit_reg;

	//MAC: 2 inputs and a output 
	logic [7:0] mac_input_1;
	logic [7:0] mac_input_2;
	logic signed [25:0] mac_output;
	logic clr_n;
	
	//PARALLEL MAC
	logic [7:0] extra_rhw_result;
	logic [7:0] extra_mac_input_1;
	logic [7:0] extra_mac_input_2;
	logic signed [25:0] extra_mac_output;
	logic extra_clr_n;
	
	//SWITCH between MACs
	logic mac_toggle, change_mac;
	
	//COUNTER
	logic en_counter32,en_counter784,en_counter_out32,en_counter_out10;
	logic [3:0] counter_out_10;
	logic [4:0] counter_out_32, counter_general_32;
	logic [4:0] counter_32, extra_counter_32;
	logic [9:0] counter_784;
	logic counter_10bit_clr;
	logic counter_5bit_clr;
	logic counter_out_4bit_clr;
	logic counter_out_5bit_clr;
	
	//RAM and ROM
	logic [7:0] act_func_result;
	logic [10:0] act_func_addr;
	logic [7:0] q_output,q_output_out;
	logic [7:0] max_value_reg;
	logic [7:0] max_value;
	logic [3:0] digit;
	logic w_enable,w_enable_out;
	logic [7:0] row_result;
	logic [7:0] rhw_result;
	logic digit_clr,digit_en;
	

	
	//FSM: 10 states	
	typedef enum reg [3:0] {IDLE, MAC_HIDDEN, MAC_HIDDEN_BP1, MAC_HIDDEN_BP2, MAC_HIDDEN_WRITE,
							MAC_OUTPUT, MAC_OUTPUT_BP1, MAC_OUTPUT_BP2, MAC_OUTPUT_WRITE, DONE} state_t;
	state_t state, next_state;
	
	
	//MAC initialization
	MAC imac(.a(mac_input_1),.b(mac_input_2),.rst_n(rst_n),.clr_n(clr_n),.acc(mac_output),.clk(clk));
	
	MAC extra_mac(.a(extra_mac_input_1),.b(extra_mac_input_2),.rst_n(rst_n),.clr_n(extra_clr_n),.acc(extra_mac_output),.clk(clk));
	
	
	//ROM & RAM initialization
	rom #(.ADDR_WIDTH(14),.DATA_WIDTH(8),.file(2)) 																			//rom_hidden_weight_contents.txt
		rom_hidden_weight(.addr({counter_32[3:0],counter_784[9:0]}),.clk(clk),.q(rhw_result));
		
	rom #(.ADDR_WIDTH(14),.DATA_WIDTH(8),.file(4)) 																			//rom2.txt   ***second part of rom_hidden_weight_contents.txt
		extra_rom_hidden_weight(.addr({extra_counter_32[3:0],counter_784[9:0]}),.clk(clk),.q(extra_rhw_result));

	rom #(.ADDR_WIDTH(9),.DATA_WIDTH(8),.file(3)) 																			//rom_output_weight_contents.txt
		rom_output_weight(.addr({counter_out_10[3:0], counter_32[4:0]}),.clk(clk),.q(row_result));

	rom #(.ADDR_WIDTH(11),.DATA_WIDTH(8),.file(1)) 																			//rom_act_func_lut_contents.txt
		rom_act_func_lut(.addr(act_func_addr),.clk(clk),.q(act_func_result));
	
	ram #(.DATA_WIDTH(8),.ADDR_WIDTH(5),.file(1))																			//ram_hidden_contents.txt
		ram_hidden_unit(.data(act_func_result), .addr(counter_general_32[4:0]), .we(w_enable), .clk(clk), .q(q_output));
	
	
	//Counter initialization: 3 counters
	counter #(.bit_length(5))																								//counter used for hidden layer operation
		counter_5bit(.cnt(counter_32),.clk(clk),.rst_n(rst_n),.en(en_counter32),.clr(counter_5bit_clr));					
	counter #(.bit_length(10))																								//counter used inside MAC
		counter_10bit(.cnt(counter_784),.clk(clk),.rst_n(rst_n),.en(en_counter784),.clr(counter_10bit_clr));				
	counter #(.bit_length(5))																								//counter used for hidden layer operation (out)
		counter_out_5bit(.cnt(counter_out_32),.clk(clk),.rst_n(rst_n),.en(en_counter_out32),.clr(counter_out_5bit_clr));
	
	assign addr_input_unit = counter_784;								
	assign extra_counter_32 = counter_32;																					//parallel counter
	
	always@ (posedge clk, negedge rst_n) begin																				//sequential logic of FSM
		if(!rst_n) begin
			state <= IDLE;																									//reset to IDLE state
		end	
		else begin
			state <= next_state;
		end
	end
	
	always @(posedge clk, negedge rst_n)	begin																			//reset counter
		if (~rst_n)
			counter_out_10 <= 4'h0;		
		else if (en_counter_out10)
			counter_out_10 <= counter_out_10 + 4'h1;		
		else if (counter_out_4bit_clr)
			counter_out_10 <= 4'h0;
	end

	always@ (posedge clk, negedge rst_n) begin																				//flip-flop of getting max value
		if(!rst_n) begin
			digit_reg <= 4'b0;
			max_value_reg <= 8'b0;
		end	
		else if (digit_en) begin
			digit_reg <= digit;
			max_value_reg <= max_value;
		end
		else if (digit_clr) begin
			digit_reg <= 4'b0;
			max_value_reg <= 8'b0;
		end
	end
	
	always @ (posedge clk, negedge rst_n) begin																				//sequential logic for MAC switch
		if(!rst_n) begin
			mac_toggle = 1;
		end
		else if (change_mac) begin
			mac_toggle = ~mac_toggle;
		end
	end
																															//default setting
	always_comb begin		
		clr_n = 1'b0;																										//clear MAC																	
		extra_clr_n = 1'b0;																									//clear extra MAC
		en_counter32=0;																										//disable counters
		en_counter784=0;
		en_counter_out32=0;
		w_enable=0;																											//disable RAM write
		w_enable_out = 0;
		done=0;																												
		counter_10bit_clr = 0;																								//clear counters
		counter_5bit_clr = 0;
		counter_out_4bit_clr = 0;
		counter_out_5bit_clr = 0;
		en_counter_out10 = 0;
		mac_input_1 = 8'h00;																								//default inputs																							
		mac_input_2 = 8'h00;
		extra_mac_input_1 = 8'h00;
		extra_mac_input_2 = 8'h00;
		next_state = IDLE;																			
		act_func_addr = 11'h000;																							//default activation function address
		digit = 4'b0;																										//default max value
		max_value = 8'b0;
		digit_en = 1'b0;
		digit_clr = 1'b0;
		change_mac = 0;
		counter_general_32 = counter_32;
	case(state)
		IDLE: begin																											//waiting for start signal
			act_func_addr = 11'h000;
			digit_clr = 1'b1;
			if(start) begin
				next_state = MAC_HIDDEN;																					//when start assert, go to MAC_HIDDEN
			end
			else
				next_state = IDLE;
		end
		
		MAC_HIDDEN : begin
			clr_n=1'b1;		
			extra_clr_n = 1'b1;
			mac_input_1 = {1'b0, {7{q_input}}};																				//setting q input
			extra_mac_input_1 = {1'b0, {7{q_input}}};																		//parallel q input
			en_counter784=1;
			if(counter_784 != 10'h30F) begin																				//loop 784 times to calculate acc			
				mac_input_2 = rhw_result;
				extra_mac_input_2 = extra_rhw_result;
				next_state = MAC_HIDDEN;
			end
			else begin																										//when finish 783 times calculation
				en_counter784=0;																							//go to MAC_HIDDEN_BP1  and clear counter
				counter_10bit_clr = 1;
				next_state = MAC_HIDDEN_BP1;
			end					
		end
		
		MAC_HIDDEN_BP1: begin																								//finish up the 784th time calculation
			counter_10bit_clr = 1;
			clr_n = 1'b1;
			extra_clr_n = 1'b1;
			mac_input_1 = {1'b0, {7{q_input}}};
			mac_input_2 = rhw_result;
			extra_mac_input_1 = {1'b0, {7{q_input}}};
			extra_mac_input_2 = extra_rhw_result;
			next_state = MAC_HIDDEN_BP2;																					//go to MAC_HIDDEN_BP2
		end	
		
		MAC_HIDDEN_BP2: begin																								//MAC result rectification
			counter_10bit_clr = 1;
			if (mac_toggle) begin																							//MAC
				if((mac_output[25] == 0) &&  |(mac_output[24:17])) begin
					act_func_addr = 11'b01111111111;
				end else if ((mac_output[25] == 1) && !(&(mac_output[24:17]))) begin
					act_func_addr = 11'b10000000000;
				end else begin
					act_func_addr = mac_output[17:7];
				end
				act_func_addr = act_func_addr + 11'h400;
				clr_n=1'b0;	
				extra_clr_n = 1'b1;
				change_mac = 1;
				next_state = MAC_HIDDEN_BP2;
			end
			else begin																										//PARALLEL MAC
				if((extra_mac_output[25] == 0) &&  |(extra_mac_output[24:17])) begin
					act_func_addr = 11'b01111111111;
				end else if ((extra_mac_output[25] == 1) && !(&(extra_mac_output[24:17]))) begin
					act_func_addr = 11'b10000000000;
				end else begin
					act_func_addr = extra_mac_output[17:7];
				end
				act_func_addr = act_func_addr + 11'h400;
				
				w_enable = 1;																								//enable write,
				clr_n=1'b0;																									//clear MAC
				extra_clr_n = 1'b0;																							
				change_mac = 1;																		
				next_state = MAC_HIDDEN_WRITE;
			end
		end
		
		MAC_HIDDEN_WRITE: begin																								//write the result to ram_hidden_contents.txt
			en_counter32=1;
			clr_n=1'b0;																										//clear both MACs
			extra_clr_n = 1'b0;
			if(counter_32 != 5'h0F) begin																					//loop 16 times (upper 16 results)
				w_enable = 1'b1;
				counter_general_32 = extra_counter_32 + 5'h10;																//ADD 16 in order to write to correct address
				counter_10bit_clr = 1;
				next_state = MAC_HIDDEN;
			end
			else begin																										//loop 16 times (lower 16 results)
				w_enable=1'b1;
				counter_general_32 = extra_counter_32 + 5'h10;
				en_counter32 = 0;
				counter_5bit_clr = 1;
				counter_out_4bit_clr = 1;
				next_state = MAC_OUTPUT;																					//go to MAC_OUTPUT

			end
		end
		MAC_OUTPUT:begin 																							
				if (counter_32 != 0)																						
					clr_n = 1;																								//calculate the first 31 results from hidden layer 
				mac_input_1=q_output;	
				en_counter32=1;
				if(counter_32 != 5'h1F) begin
				mac_input_2=row_result;
				next_state=MAC_OUTPUT;
				end
				else begin
				mac_input_2=row_result;
				next_state=MAC_OUTPUT_BP1;
				end
			end
		MAC_OUTPUT_BP1:begin																								//finish up the 32th result
				clr_n = 1;
				mac_input_1=q_output;
				mac_input_2=row_result;
				next_state=MAC_OUTPUT_BP2;
			end
		MAC_OUTPUT_BP2:begin																	//mac result rectification for mac_output
				if((mac_output[25] == 0) &&  |(mac_output[24:17])) begin
				act_func_addr = 11'b01111111111;
			end else if ((mac_output[25] == 1) && !(&(mac_output[24:17]))) begin
				act_func_addr = 11'b10000000000;
			end else begin
				act_func_addr = mac_output[17:7];
				end
				act_func_addr = act_func_addr + 11'h400;
				clr_n=1'b0;
				next_state=MAC_OUTPUT_WRITE;																				//go to MAC_OUTPUT_WRITE
			end

		MAC_OUTPUT_WRITE:begin		
		en_counter_out10 = 1;
		if(counter_out_10 != 4'h9) begin																					//compare the max result 
			if (max_value_reg < act_func_result) begin																		//assert digit
				digit_en = 1'b1;
				max_value = act_func_result;
				digit = counter_out_10;
			end
			next_state = MAC_OUTPUT;																						//loop 	10 times to get max result																					
		end
		else begin
			if (max_value_reg < act_func_result) begin
				digit_en = 1'b1;
				max_value = act_func_result;
				digit = counter_out_10;
			end
			next_state = DONE;
		end
		end 
		DONE: begin																											//DONE
			en_counter_out10=0;
			done=1;
			next_state=IDLE;
		end
		
		default: begin																										//default state: back to IDLE
			next_state = IDLE;
		end
	endcase
	end
	
endmodule
