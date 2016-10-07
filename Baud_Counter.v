module Baud_Counter (
	// Inputs
input	clk,
input	reset,
	
input	reset_counters,

	// Outputs
output reg baud_clock_rising_edge,
output reg baud_clock_falling_edge,
output reg all_bits_transmitted
);

parameter BAUD_COUNTER_WIDTH = 9;
parameter BAUD_COUNT =  5;
parameter BAUD_TICK_COUNT =  BAUD_COUNT - 1; //9'd433;
parameter HALF_BAUD_TICK_COUNT	= BAUD_COUNT / 2; //9'd216;

parameter DATA_WIDTH = 9;
parameter TOTAL_DATA_WIDTH = DATA_WIDTH + 2;

reg [(BAUD_COUNTER_WIDTH - 1):0] baud_counter;
reg [3:0] bit_counter;

// control baud_counter
always @(posedge clk)
begin
	if (reset == 1'b1)
		baud_counter <= {BAUD_COUNTER_WIDTH{1'b0}};
	else if (reset_counters)
		baud_counter <= {BAUD_COUNTER_WIDTH{1'b0}};
	else if (baud_counter == BAUD_TICK_COUNT)
		baud_counter <= {BAUD_COUNTER_WIDTH{1'b0}};
	else
		baud_counter <= baud_counter + 1'b1;
end

// control baud_clock_rising_edge signal
always @(posedge clk)
begin
	if (reset == 1'b1)
		baud_clock_rising_edge <= 1'b0;
	else if (baud_counter == BAUD_TICK_COUNT)
		baud_clock_rising_edge <= 1'b1;
	else
		baud_clock_rising_edge <= 1'b0;
end

// control baud_clock_falling_edge signal
always @(posedge clk)
begin
	if (reset == 1'b1)
		baud_clock_falling_edge <= 1'b0;
	else if (baud_counter == HALF_BAUD_TICK_COUNT)
		baud_clock_falling_edge <= 1'b1;
	else
		baud_clock_falling_edge <= 1'b0;
end

// control bit counter
always @(posedge clk)
begin
	if (reset == 1'b1)
		bit_counter <= 4'h0;
	else if (reset_counters)
		bit_counter <= 4'h0;
	else if (bit_counter == TOTAL_DATA_WIDTH)
		bit_counter <= 4'h0;
	else if (baud_counter == BAUD_TICK_COUNT)
		bit_counter <= bit_counter + 4'h1;
end

// control all_bits_transmitted signal
always @(posedge clk)
begin
	if (reset == 1'b1)
		all_bits_transmitted <= 1'b0;
	else if (bit_counter == TOTAL_DATA_WIDTH)
		all_bits_transmitted <= 1'b1;
	else
		all_bits_transmitted <= 1'b0;
end

endmodule

