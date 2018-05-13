module uart_tx(tx,tx_start,tx_data,tx_rdy,clk,rst_n);
input tx_start,clk,rst_n;
input [7:0] tx_data;
output logic tx,tx_rdy;

logic baud_clear,data_save,data_rotate;	// data_save asserted: tx_data is valid, save!
logic [3:0] bit_count;
logic [9:0] data;
logic [11:0] baud;

typedef enum logic { IDLE, TRANSMIT } state_t;
state_t state,next_state;

// State FF: reset to IDLE
always_ff @ (posedge clk, negedge rst_n) begin
	if (~rst_n) begin
		state <= IDLE;
	end
	else begin
		state <= next_state;
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

// Data FF: shift and store data as appropriate
always_ff @ (posedge clk, negedge rst_n) begin
	if (~rst_n)
		data <= 10'h000;
	else begin
		if (data_save) begin
			data <= {1'b1,tx_data,1'b0};
		end
		if (data_rotate) begin
			data <= {data[0],data[9:1]};
		end
	end
end

// 
assign tx = (state == IDLE) ? 1'b1 : data[0];

always_comb begin
	// Default
	tx_rdy = 1;
	baud_clear = 0;
	data_save = 0;
	data_rotate = 0;
	next_state = IDLE;
	case(state)
		IDLE: begin
			if (tx_start) begin
				data_save = 1;
				baud_clear = 1;
				next_state = TRANSMIT;
			end
			else begin
				next_state = IDLE;
			end
		end
		TRANSMIT: begin
			if (bit_count != 4'b1010) begin
				if (baud == 12'hA2C) begin
					data_rotate = 1;
					tx_rdy = 0;
					next_state = TRANSMIT;
				end
				else begin
					tx_rdy = 0;
					next_state = TRANSMIT;
				end
			end
			else begin
				next_state = IDLE;
			end
		end
	endcase
end

endmodule
