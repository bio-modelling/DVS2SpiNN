module RS232_Out(
// Inputs
input clk,
input reset,
	
input [DATA_WIDTH:1] transmit_data,
input transmit_data_en,

// Outputs
output reg serial_data_out,
output reg transmitting_data
);

parameter DATA_WIDTH = 8;
parameter BAUD_COUNT = 9'd434;

wire shift_data_reg_en, read_input_en;
//wire baud_clock;
wire all_bits_transmitted;

// debug outputs
//assign baud_clock = shift_data_reg_en;
//assign next_bit = data_out_shift_reg[0];

reg [DATA_WIDTH:0] data_out_shift_reg;

initial
begin
	serial_data_out <= 1'b1;
	data_out_shift_reg	<= {(DATA_WIDTH + 1){1'b1}}; // all ones
end

always @(posedge clk)
begin
	if (reset == 1'b1)
		serial_data_out <= 1'b1; 
	else
		serial_data_out <= data_out_shift_reg[0]; //next bit
end

always @(posedge clk)
begin
	if (reset == 1'b1)
		transmitting_data <= 1'b0;
	else if (all_bits_transmitted == 1'b1)
		transmitting_data <= 1'b0;
	else if (transmit_data_en)
		transmitting_data <= 1'b1;
end

always @(posedge clk)
begin
	if (reset == 1'b1)
		data_out_shift_reg	<= {(DATA_WIDTH + 1){1'b1}}; // all ones
	else if (read_input_en)
		data_out_shift_reg	<=  {transmit_data,1'b0};
	else if (shift_data_reg_en)
		data_out_shift_reg	<= 
			{1'b1, data_out_shift_reg[DATA_WIDTH:1]};
end


assign read_input_en = ~transmitting_data & ~all_bits_transmitted & transmit_data_en;

Baud_Counter Out_Counter (
// Inputs
.clk(clk), .reset(reset), .reset_counters(~transmitting_data),
// Outputs
.baud_clock_rising_edge(shift_data_reg_en),
.baud_clock_falling_edge(),
.all_bits_transmitted(all_bits_transmitted)
);
defparam
	Out_Counter.BAUD_COUNT = BAUD_COUNT,
	Out_Counter.DATA_WIDTH = DATA_WIDTH;

/*
Altera_UP_SYNC_FIFO RS232_Out_FIFO (
	// Inputs
	.clk			(clk),
	.reset			(reset),

	.write_en		(transmit_data_en & ~fifo_is_full),
	.write_data		(transmit_data),

	.read_en		(read_fifo_en),
	
	// Bidirectionals

	// Outputs
	.fifo_is_empty	(fifo_is_empty),
	.fifo_is_full	(fifo_is_full),
	.words_used		(fifo_used),

	.read_data		(data_from_fifo)
);
defparam 
	RS232_Out_FIFO.DATA_WIDTH	= DATA_WIDTH,
	RS232_Out_FIFO.DATA_DEPTH	= 128,
	RS232_Out_FIFO.ADDR_WIDTH	= 7;
*/
endmodule

