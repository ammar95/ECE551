module snn_tb();

logic clk, sys_rst_n,uart_rx,uart_tx;
logic [7:0] led;
logic tx;
logic tx_rdy,tx_start;
logic [7:0] tx_data;
logic [7:0] rx_data;
integer index;

reg [0:0] mem[0:900]; // 16-bit wide 256 entry ROM



// initial begin	
	// clk = 0;
	// index = 0;
	// sys_rst_n = 0;
	// tx_start = 0;
	// # 1 sys_rst_n = 1;
	
	
	// $readmemh("ram_input_contents_sample_8.txt",mem);

// for (index = 0; index < 784; index = index + 8) begin
	// tx_data = {mem[index],mem[index+1],mem[index+2],mem[index+3],mem[index+4],mem[index+5],mem[index+6],mem[index+7]};
	// tx_start = 1;
	// @(posedge clk);
		// tx_start = 0;
	// @(posedge tx_rdy);
// end



// end

// always #5 clk = ~clk;

initial
$readmemh("ram_input_contents_sample_8.txt",mem);



snn iDUT(clk, sys_rst_n, led, uart_tx, tx);

initial begin
	clk = 0;
	index = 0;
	sys_rst_n = 0;
	# 1 sys_rst_n = 1;
	tx_data = {mem[7],mem[6],mem[5],mem[4],mem[3],mem[2],mem[1],mem[0]};
	tx_start = 1;
end

always #5 clk = ~clk;

uart_tx sender(tx,tx_start,tx_data,tx_rdy,clk,sys_rst_n);
uart_rx receiver(rx,rx_rdy,rx_data,clk,sys_rst_n);

always @ (posedge clk) begin
	if (tx_rdy == 1) begin
		tx_data = {mem[index+7],mem[index+6],mem[index+5],mem[index+4],mem[index+3],mem[index+2],mem[index+1],mem[index]};
		tx_start = 1;
	end
	else 
		tx_start = 0;
end


always @ (posedge tx_start) index = index + 8;

endmodule


// logic curr;
// parameter EOF = -1;
// integer file_handle,error,indx;
// reg signed [15:0] wide_char;
// reg [7:0] mem[0:900];
// reg [639:0] err_str;
// initial begin
	// indx=0;
	// file_handle = $fopen("ram_input_contents_sample_0.txt","r");
	// error = $ferror(file_handle,err_str);
	// if (error==0) begin
		// wide_char = 16'h0000;
		// while (wide_char!=EOF) begin
			// wide_char = $fgetc(file_handle);
			// mem[indx] = wide_char[7:0];
			// $write("%c",mem[indx]);
			// if (wide_char != 8'h0a)
			// curr = wide_char[0:0];
			// #5 indx = indx + 1;
		// end
	// end
	// else $display("Can't open file");
	// $fclose(file_handle);
// end
