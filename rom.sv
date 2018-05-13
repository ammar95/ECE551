module rom (addr,clk,q);
	parameter ADDR_WIDTH = 3;
	parameter DATA_WIDTH = 3;
	parameter file = 1;
	
	input [(ADDR_WIDTH-1):0] addr;
	input clk;
	output reg [(DATA_WIDTH-1):0] q;
	// Declare the ROM variable
	reg [DATA_WIDTH-1:0] rom[2**ADDR_WIDTH-1:0];
	
	initial begin
		if (file == 1)
		$readmemh("rom_act_func_lut_contents.txt", rom);				//split rom_hidden_weight_contents.txt to two parts in order to read parallel
		if (file == 2)
		$readmemh("rom_hidden_weight_contents.txt", rom);
		if (file == 3)
		$readmemh("rom_output_weight_contents.txt", rom);
		if (file == 4)
		$readmemh("rom2.txt", rom);
	end
	
	always @ (posedge clk) begin
		q <= rom[addr];
	end
	
endmodule 
