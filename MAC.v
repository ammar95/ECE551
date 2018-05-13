module MAC(a,b,clr_n,acc,clk,rst_n);
 
input signed [7:0] a,b;
input clr_n;
input clk, rst_n;
//output reg of,uf;
output  reg signed[25:0] acc;

wire signed[15:0] mult;
wire  signed [25:0] mult_ext,add, acc_nxt;
wire flow;
//wire flow,off,uff;

assign mult = a * b;
assign mult_ext={{10{mult[15]}},mult};
assign add=acc+mult_ext;
//assign {flow,add} = {acc[15],acc} + {mult[15],mult};
//assign off = flow ? 0 : (add[15] ? 1 : 0);
//assign uff = flow ? (add[15] ? 0 : 1) : 0;
assign acc_nxt = clr_n ? add : 0;

always@(posedge clk, negedge rst_n) begin
if(!rst_n) begin
//of <= 1'b0;
//uf <= 1'b0;
acc <= 16'b0;
end else begin
acc <= acc_nxt;
//of <= off;
//uf <= uff;
end
end

endmodule



