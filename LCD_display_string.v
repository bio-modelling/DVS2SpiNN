/*
------------------------------------------------------------------- 
--                        ASCII HEX TABLE
--  Hex						Low Hex Digit
-- Value  0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
------\----------------------------------------------------------------
--H  2 |  SP  !   "   #   $   %   &   '   (   )   *   +   ,   -   .   /
--i  3 |  0   1   2   3   4   5   6   7   8   9   :   ;   <   =   >   ?
--g  4 |  @   A   B   C   D   E   F   G   H   I   J   K   L   M   N   O
--h  5 |  P   Q   R   S   T   U   V   W   X   Y   Z   [   \   ]   ^   _
--   6 |  `   a   b   c   d   e   f   g   h   i   j   k   l   m   n   o
--   7 |  p   q   r   s   t   u   v   w   x   y   z   {   |   }   ~ DEL
-----------------------------------------------------------------------
-- Example "A" is row 4 column 1, so hex value is 8'h41"
-- *see LCD Controller's Datasheet for other graphics characters available
*/

module LCD_display_string(
input received,
input [7:0] q,
output reg swap,
output reg [4:0] adx,
input clock,
input [4:0] index,
output reg [7:0] out
);

reg [7:0] mem[0:31];

//reg [3:0] adx;


integer k;
initial
	for (k=0; k<32; k=k+1)
		mem[k] = 8'h20;
	

always @(posedge received)
begin
	if (adx==5'h1F) 
	begin
		adx <= 5'h00;
	end
	else adx <= adx + 1'b1;
end

always @(posedge received)
	mem[adx] <= q;


always @(posedge clock)
	out <= mem[index]; 

endmodule