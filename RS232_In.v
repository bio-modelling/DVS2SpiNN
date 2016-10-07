module RS232_In (
// Inputs
input clk,
input reset,
input serial_data_in,
input receive_data_en,
// Outputs
output reg [(DATA_WIDTH-1):0] received_data,
output reg receiving_data,
output reg data_received,
output baud_clock
);

parameter BAUD_COUNT = 9'd434;
parameter DATA_WIDTH = 8;
parameter TOTAL_DATA_WIDTH = DATA_WIDTH + 2;

wire shift_data_reg_en;
wire all_bits_received;


assign baud_clock = shift_data_reg_en;
reg [(TOTAL_DATA_WIDTH - 1):0]	data_in_shift_reg;
//reg receiving_data;
reg prev_receiving_data;



always @(posedge clk)
begin
	if (reset == 1'b1)
		receiving_data <= 1'b0;
	else if (all_bits_received == 1'b1)
		receiving_data <= 1'b0;
	else if (serial_data_in == 1'b0)
		receiving_data <= 1'b1;
end

always @(posedge clk)
begin
	prev_receiving_data  <= receiving_data;
	if (receiving_data==1'b1)
		data_received <= 1'b0;
	else if (prev_receiving_data==1'b1)
	begin
		data_received <= 1'b1;
		received_data <= data_in_shift_reg[DATA_WIDTH:1];
	end
end

always @(posedge clk)
begin
	if (reset == 1'b1)
		data_in_shift_reg	<= {TOTAL_DATA_WIDTH{1'b0}};
	else if (shift_data_reg_en)
		data_in_shift_reg	<= 
			{serial_data_in, data_in_shift_reg[(TOTAL_DATA_WIDTH - 1):1]};
end

Baud_Counter RS232_In_Counter (
// Inputs
.clk(clk),
.reset(reset),
.reset_counters(~receiving_data),
// Outputs
.baud_clock_rising_edge(),
.baud_clock_falling_edge(shift_data_reg_en),
.all_bits_transmitted(all_bits_received)
);
defparam 
	RS232_In_Counter.BAUD_COUNT= BAUD_COUNT,
	RS232_In_Counter.DATA_WIDTH= DATA_WIDTH;
/*
Altera_UP_SYNC_FIFO RS232_In_FIFO (
	// Inputs
	.clk			(clk),
	.reset			(reset),

	.write_en		(all_bits_received & ~fifo_is_full),
	.write_data		(data_in_shift_reg[(DATA_WIDTH + 1):1]),

	.read_en		(receive_data_en & ~fifo_is_empty),
	
	// Bidirectionals

	// Outputs
	.fifo_is_empty	(fifo_is_empty),
	.fifo_is_full	(fifo_is_full),
	.words_used		(fifo_used),

	.read_data		(received_data)
);
defparam 
	RS232_In_FIFO.DATA_WIDTH	= DATA_WIDTH,
	RS232_In_FIFO.DATA_DEPTH	= 128,
	RS232_In_FIFO.ADDR_WIDTH	= 7;
*/
endmodule

