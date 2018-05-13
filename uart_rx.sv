module uart_rx(rx,rx_rdy,rx_data,clk,rst_n);
input rx,clk,rst_n;
output reg rx_rdy;
output [7:0] rx_data;
logic [9:0] data;
logic [11:0] baud;
logic baud_clear, data_ctl, data_clr;
logic [3:0] bit_count;


typedef enum logic [1:0] {IDLE, FRONT_PORCH, RX, BACK_PORCH} state_t;
state_t state,next_state;

assign rx_data = data[8:1];

// State FF: reset to IDLE
always_ff @ (posedge clk, negedge rst_n) begin
	if (~rst_n) begin
		state <= IDLE;
	end
	else begin
		state <= next_state;
	end
end

// Bit_count FF: reset to 0, when baud reach a full baud cycle, increment to read the next bit
always_ff @ (posedge clk, negedge rst_n) begin
	if (~rst_n) begin
		bit_count <= 0;
	end
	else begin
		if (baud_clear == 1) 
			bit_count <= 0;
		else begin
			if (baud == 12'hA2B)
				bit_count <= bit_count + 4'h1;
			else 
				bit_count <= bit_count;
		end
	end
end

// Baud FF: reset to 0, cleared by setting baud_clear before use, used as a timer for bit operation
always_ff @ (posedge clk, negedge rst_n) begin
	if (~rst_n)
		baud <= 0;
	else begin
		if (baud != 12'hA2C && baud_clear == 0) begin
			baud <= baud + 12'h001;
		end
		else begin
			baud <= 12'h000;
		end
	end
end

// Data FF: shift and store data as appropriate
always_ff @ (posedge clk, negedge rst_n) begin
	if (~rst_n)
		data <= 10'h000;
	else begin
		if (data_ctl) begin
			//data[9] <= rx;
			data <= {data[0], rx, data[8:1]};
		end
		if (data_clr) begin
			data <= 10'h000;
		end
	end
end
always_comb begin
	// Default 
	rx_rdy = 0;
	baud_clear = 0;
	data_ctl = 0;
	data_clr = 0;
	case(state)
		IDLE: begin
			// Move to FRONT_PORCH and clear the baud counter when a bit string arrives
			if (rx == 0) begin
				next_state = FRONT_PORCH;
				baud_clear = 1;
			end
			else begin
				next_state = IDLE;
				data_clr = 1;
			end
		end
		FRONT_PORCH: begin
			// After half baud cycle, clear the baud counter and register the start bit of the bit string
			// Then move on to the RX state to read the remaining data
			if (baud == 12'h516) begin
				baud_clear = 1;
				data_ctl = 1;
				next_state = RX;
			end
			else
				next_state = FRONT_PORCH;
		end
		RX: begin
			next_state = RX;
			// Operation is performed every full baud cycle
			if (baud == 12'hA2C)begin
				// Read in the next data when there is data remaining
				if (bit_count != 4'h9) begin
					data_ctl = 1;
					next_state = RX;
				end
				// Clear the baud counter for the BACK_PROCH and signal ready
				else begin
					baud_clear = 1;
					rx_rdy = 1;
					next_state = BACK_PORCH;
				end
			end
		end
		BACK_PORCH: begin
			// Spin half baud cycle
			if (baud == 12'h516) begin
				next_state = IDLE;
			end
			else begin
				next_state = BACK_PORCH;
			end
		end
	endcase
end

endmodule
