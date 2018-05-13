module rst_synch(sys_rst_n, rst_n,clk);

input sys_rst_n, clk;
output logic rst_n;

logic temp;

always_ff @(negedge clk, negedge sys_rst_n) begin
	if (!sys_rst_n) begin
		temp <= 1'b0;
	end else begin
		temp <= 1'b1;
	end
end

always_ff @(negedge clk, negedge sys_rst_n) begin
	if (!sys_rst_n) begin
		rst_n <= 1'b0;
	end else begin
		rst_n <= temp;
	end
end

endmodule


