module counter(cnt,clk,rst_n,en,clr);

	parameter bit_length = 5;
	input clk,rst_n,en,clr;		//input clk, active low rst, enable, sync clear
	output reg[(bit_length-1):0] cnt;		//output counter
	
always @(posedge clk, negedge rst_n)			// positive edge triggered async counter

	if (~rst_n)
		cnt <= {bit_length{1'b0}};		//reset counter on active low reset signal
	else if (en)
		cnt <= cnt + 1;		// Move to next state
	else if (clr)
		cnt <= {bit_length{1'b0}};

endmodule

