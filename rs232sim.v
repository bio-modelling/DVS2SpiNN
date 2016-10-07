module rs232lab(
// Inputs
input clk,
input reset,
	
input [DATA_WIDTH:1] transmit_data,
input transmit_data_en,

// Outputs
output serial_data_out,
output transmitting_data,

output [DATA_WIDTH:1] received_data,
output [(DATA_WIDTH+1):0] input_shift_reg,
output receiving_data,
output data_received,
output clock_in, clock_out
);

parameter DATA_WIDTH = 9;

RS232_Out u1(
// Inputs
.clk(clk),
.reset(reset),
	
.transmit_data(transmit_data),
.transmit_data_en(transmit_data_en),

// Outputs
.serial_data_out(serial_data_out),
.transmitting_data(transmitting_data),
.baud_clock(clock_out)
);

RS232_In (
// Inputs
.clk(clk),
.reset(reset),
.serial_data_in(serial_data_out),
.receive_data_en(1'b1),
// Outputs
.received_data(received_data),
.data_received(data_received),
.data_in_shift_reg(input_shift_reg),
.receiving_data(receiving_data),
.baud_clock(clock_in)
);

endmodule