module snn(clk, sys_rst_n, led, uart_tx, uart_rx);

	//interface inputs and outputs	
	input clk;			      	// 50MHz clock
	input sys_rst_n;			// Unsynched reset from push button. Needs to be synchronized.
	output logic [7:0] led;		// Drives LEDs of DE0 nano board
	input uart_rx;
	output uart_tx;
	
	logic [3:0] digit;
	logic rst_n;				 	// Synchronized active low reset	
	logic uart_rx_ff, uart_rx_synch;	
	logic tx_rdy, rx_rdy;
	
	//RECEIVING 
	logic [7:0] rx_data;
	logic [7:0] rx_copy;
	logic rx_copy_clr, rx_copy_en, rx_copy_read;
	
	//COUNTERS
	logic counter_snn_7bit_clr, en_snn_counter98, counter_snn_4bit_clr, en_snn_counter8, en_snn_counter784, counter_snn_10bit_clr;
	logic [6:0] counter_snn_98;
	logic [3:0] counter_snn_8;
	logic [9:0] counter_snn_784;
	logic [3:0] digit_copy;
	logic done;
	
	//FSM: 5 states
	typedef enum reg [2:0] {IDLE, UART_RX_STATE, UART_RX_STATE_2, SNN_CORE_STATE, DONE} state_t;
	state_t state, next_state;
	/******************************************************
	Reset synchronizer
	******************************************************/
	rst_synch i_rst_synch(.clk(clk), .sys_rst_n(sys_rst_n), .rst_n(rst_n));
	
	/******************************************************
	UART
	******************************************************/
	
	// Declare wires below
	wire [7:0] uart_data;
	logic ram_input_unit_we,ram_input_unit_data,ram_input_unit_out;
	logic [9:0] ram_input_unit_addr;
	logic [9:0] ram_addr;
	logic start;
	logic tx_start;

	// Double flop RX for meta-stability reasons
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n) begin
		uart_rx_ff <= 1'b1;
		uart_rx_synch <= 1'b1;
	end else begin
		uart_rx_ff <= uart_rx;
		uart_rx_synch <= uart_rx_ff;
	end
	
	always@ (posedge clk, negedge rst_n) begin			//sequential logic of FSM
		if(!rst_n) begin								//reset to IDLE state
			state <= IDLE;
		end	
		else begin
			state <= next_state;
		end
	end
	
	always @(posedge clk, negedge rst_n)	begin		// positive edge triggered async counter

		if (~rst_n)
			counter_snn_8 <= 4'h0;						//reset counter on active low reset signal
		else if (en_snn_counter8)
			counter_snn_8 <= counter_snn_8 + 4'h1;		// Move to next state
		else if (counter_snn_4bit_clr)
			counter_snn_8 <= 4'h0;	
	end
	
	always @(posedge clk, negedge rst_n)	begin		// positive edge triggered async counter

		if (~rst_n)
			counter_snn_98 <= 7'h00;					//reset counter on active low reset signal
		else if (en_snn_counter98)
			counter_snn_98 <= counter_snn_98 + 7'h01;		// Move to next state
		else if (counter_snn_7bit_clr)
			counter_snn_98 <= 7'h00;	
	end
	
	always @ (posedge clk, negedge rst_n) begin				//store the rx data to a shift register in correct sequence
		if (~rst_n)
			rx_copy <= 8'h00;
		else if (rx_copy_en)
			rx_copy <= {rx_copy[0], rx_copy[7:1]};
		else if (rx_copy_read)
			rx_copy <= rx_data;
		else if (rx_copy_clr)
			rx_copy <= 8'h00;
	end
	
	always @ (posedge clk, negedge rst_n) begin							
		if(!rst_n) begin
			digit_copy <= 4'h0;
		end	
		else if (done) begin								//setup digit_copy
			digit_copy <= digit;
		end
	end
			
	
	//UART SETTING
	uart_tx my_uart_tx(uart_tx,tx_start,{4'b0000,digit[3:0]},tx_rdy,clk,rst_n);		
	uart_rx my_uart_rx(uart_rx_synch,rx_rdy,rx_data[7:0],clk,rst_n);


	logic ram[2**10-1:0];
	logic [9:0] addr_reg;

	initial begin
		$readmemh("ram_input_contents.txt", ram);
	end

	always @ (posedge clk) begin
		if (ram_input_unit_we) 															// Write
		ram[ram_addr[9:0]] <= ram_input_unit_data;
		addr_reg <= ram_addr[9:0];
	end
	 
	assign ram_input_unit_out = ram[addr_reg];
	
	
	snn_core my_snn_core(start, ram_input_unit_out, ram_input_unit_addr, digit, done, clk, rst_n);
	

	always_comb begin
		en_snn_counter8 = 0;															//disable counters									
		en_snn_counter98 = 0;
		counter_snn_4bit_clr = 0;														//clear counters
		counter_snn_7bit_clr = 0;
		ram_input_unit_we = 0;															//disable write
		ram_addr = 0;
		start = 0;
		next_state=IDLE;																//initializion of state
		ram_input_unit_data = 0;
		rx_copy_read = 0;
		rx_copy_en  = 0;
		rx_copy_clr = 0;
		tx_start = 0;
		case(state)																		
			IDLE: begin
				en_snn_counter8 = 0;													
				en_snn_counter98 = 0;
				counter_snn_4bit_clr = 1;
				counter_snn_7bit_clr = 1;
				rx_copy_clr = 1;
				if(rx_rdy) begin														//wait until data transferred from PC
					rx_copy_read = 1;
					next_state = UART_RX_STATE_2;
				end
				else begin
					next_state = IDLE;
				end
			end
			UART_RX_STATE: begin														
				if (!rx_rdy) begin
					next_state=UART_RX_STATE;
				end
				else begin
					if(counter_snn_98 != 7'h62) begin									//loop 98 times to get all 784 bits of data from PC			
						rx_copy_read = 1;												// in each loop, deal with 8 bit data
						next_state = UART_RX_STATE_2;
					end else begin
						counter_snn_7bit_clr = 1;										//clear and disable counter before entering SNN_CORE_STATE
						counter_snn_4bit_clr = 1;
						en_snn_counter8 = 0;
						en_snn_counter98 = 0;
						ram_addr = 10'h0;
						ram_input_unit_we = 0;	
						start = 1;
						next_state = SNN_CORE_STATE;
					end
				end
			end
			
			UART_RX_STATE_2: begin
				en_snn_counter8 = 1;													//enable the 8 bit counter and disable the 98 bit counter when entering this state
				en_snn_counter98 = 0;													
				rx_copy_en = 1;
				if(counter_snn_8 != 4'h8) begin											//inner loop that write the 8 bits data to ram_input_contents
					ram_input_unit_data = rx_copy[0];
					ram_addr = {counter_snn_98[6:0],counter_snn_8[2:0]};				//set up the ram address
					ram_input_unit_we = 1'b1;
					next_state = UART_RX_STATE_2;										
				end	else begin
					en_snn_counter8 = 0;
					counter_snn_4bit_clr = 1;
					if (counter_snn_98 == 7'h61) begin
						start = 1;														//after receiving all data, go to SNN_CORE_STATE
						next_state=SNN_CORE_STATE;
					end
					else begin
						en_snn_counter98 = 1;											//re-enable 98 bit counter
						next_state = UART_RX_STATE;
					end
				end	
			end
			
			SNN_CORE_STATE: begin														//module of SNN_CORE
				ram_addr = ram_input_unit_addr;
				if(!done) begin
					next_state = SNN_CORE_STATE;
				end else begin
					tx_start = 1;														//start transmit data back to PC
					next_state = DONE;
				end
				
			end
			
		    DONE: begin
				if(tx_rdy) begin														//Back to IDLE after finish the transmitting
				next_state = IDLE;
				end else begin
				next_state = DONE;
				end	
			end
			
			
			default: begin																//default: go to IDLE
				next_state = IDLE;
			end
		endcase	
	end
	
		
	/******************************************************
	LED
	******************************************************/
	// TODO: edit
	assign	led = {4'b0,digit_copy[3:0]};

endmodule