module rs232lab(
  input CLOCK_50,	//	50 MHz clock
  input [3:0] KEY,    //	Pushbutton[3:0]
  input [17:0] SW,	//	Toggle Switch[17:0]
  output [6:0]	HEX0,HEX1,HEX2,HEX3,HEX4,HEX5,HEX6,HEX7,  // Seven Segment Digits
  output [8:0] LEDG,  //	Green LEDs
  output [17:0] LEDR,  //	Red LEDs
  inout [35:0] GPIO_0,GPIO_1,	//	GPIO Connections 
 //	UART for Rs232 communcation
  output UART_TXD, // UART Transmitter
  input  UART_RXD, // UART Receiver
//	LCD Module 16X2
  output LCD_ON,	// LCD Power ON/OFF
  output LCD_BLON,	// LCD Back Light ON/OFF
  output LCD_RW,	// LCD Read/Write Select, 0 = Write, 1 = Read
  output LCD_EN,	// LCD Enable
  output LCD_RS,	// LCD Command/Data Select, 0 = Command, 1 = Data
  inout [7:0] LCD_DATA	// LCD Data bus 8 bits
);

// Reset button
wire RST;
assign RST = KEY[0];
wire reset = ~RST;

// Start Button
wire STR;
assign STR = KEY[2];
wire start = ~STR;


 //Get dAta Button
wire RDY;
assign RDY = KEY[3];
wire is_red = ~RDY;

//assign GPIO_0[33] = is_red;

//////////////////////////////////////////////////
/*   LCD DISPLAY - USED FOR DEBUGGING PURPOSES  */
//////////////////////////////////////////////////

// reset delay gives some time for peripherals to initialize Used for LCD dispaly
wire DLY_RST;
Reset_Delay r0(	.iCLK(CLOCK_50),.oRESET(DLY_RST) );

// turn LCD ON
assign	LCD_ON		=	1'b1;
assign	LCD_BLON	=	1'b1;

wire [4:0] adx;
reg [7:0] transmit_addr = 8'h05;

romtext mem1(
.address(transmit_addr),
.clock(CLOCK_50),
.q(transmit_data)
);

parameter XMT_LIMIT = 8'h5f; // number of character in packet

assign transmit_data_en = SW[0]? recieveing: flag;

// handle transmission
always @(posedge transmit_data_en)
	if (reset)
		transmit_addr <= 8'h00;
	else if (transmit_addr<XMT_LIMIT)
		transmit_addr <= transmit_addr;// + 1'b1;
	else
		transmit_addr <= 8'h00;

wire [7:0] q;
wire [4:0] addr;

LCD_display_string d(
.clock(CLOCK_50),
.received(spinn_acq), // data_received
.q(spinn_pkt[4:0]),
.adx(adx),
.index(addr),
.out(q)
);


LCD_Display u1(
// Host Side
   .iCLK_50MHZ(CLOCK_50),
   .iRST_N(DLY_RST),
   .char_index(addr),
   .char_value(q),
// LCD Side
   .DATA_BUS(LCD_DATA),
   .LCD_RW(LCD_RW),
   .LCD_E(LCD_EN),
   .LCD_RS(LCD_RS)
);

//////////////////////////////////////////////////////
/*   RS323 MODULE - USED FOR DEBUGGING VIA MATLAB   */
//////////////////////////////////////////////////////

parameter DATA_WIDTH = 8;
wire [DATA_WIDTH-1:0] received_data;
wire [DATA_WIDTH-1:0] transmit_data;
wire transmitting_data;
wire receiving_data, data_received;
wire transmit_data_en;

wire spinn_acq;


wire flag;
oneshot trig(flag,~KEY[3],CLOCK_50);

reg [31:0] count;
reg clk;

always @(posedge CLOCK_50)
begin
	if (count < 50*1000*1000)
	begin
		count <= count + 1'b1;
		clk <= 1'b0;
	end
	else
	begin
		count <= 0;
		clk <= 1'b1;
	end
end

wire UART;

RS232_Out u2(
// Inputs
.clk(CLOCK_50),
.reset(reset),
	
.transmit_data(rx_data),
.transmit_data_en(transmit_data_en),

// Outputs
.serial_data_out(UART_TXD), // UART_TXD
.transmitting_data(transmitting_data)
);


/////////////////////////////////////
/*       SEND DATA TO EDVS         */
/////////////////////////////////////
wire [7:0] rx_byte;
wire transmitting;
wire recieveing;

assign LEDR[0] = transmitting;
assign LEDR[1] = recieveing;

// eDVS start and stop bits
localparam start_bit = "+E\n";
localparam stop_bit = "-E\n";

reg transmit;
integer byteN = 0;

// STATE MACHINE
localparam START = 0; 
localparam TXD_START = START + 1; // transmitt start bit 
localparam IDLE = TXD_START +1; // recieve data
localparam STOP = IDLE + 1; // transmitt data and stop recieveing data
localparam TXD_STOP = STOP + 1;
localparam ERROR = TXD_STOP + 1;

reg [2:0] state = 3'b0;
reg [31:0] tbyte;

always @(posedge CLOCK_50 or posedge reset)
begin
	if(reset) begin
		state <= STOP;
		byteN <= 0;
		transmit <= 1'b0;
	end else if (start)
		state <= START;
	else begin
		case (state)
			IDLE: begin
				transmit = 1'b0;	
			end
			START: begin
			// if the key is pressed then transmit the start bit and move to txd_state
			// In this step we set up for the start transmission 
			// We want to send the bits E+/n	
					tbyte = start_bit[7:0];
					transmit = 1'b1;
					byteN = 1;
					state = TXD_START;
			end
			TXD_START: begin
			//send the start bit and move to rxd_state
				if (!transmitting && !transmit) begin
						tbyte = start_bit[8*byteN +: 8];
						transmit = 1'b1;
						byteN = byteN +1;
						if (byteN ==4)
							state = IDLE;
				end else begin 
						transmit = 1'b0;
				end					
			end
			STOP: begin
				if (!transmitting && !transmit) begin
					tbyte = stop_bit[8*byteN +: 8];
					transmit = 1'b1;
					byteN = byteN +1;
					if (byteN ==4)
						state = IDLE;
				end else begin 
					transmit = 1'b0;
				end							
			end				
					
		endcase
	end
end
	

//
//eDVSinput first(
//.clk(CLOCK_50),
//.reset(reset),
//.transmitting(transmitting),
//.tx(GPIO_0[3]),
//.clken(txclk_en)
////.recieveing(recieveing)
//);

//////////////////////////////////////////////////////
/*           UART TRASMITTER / RECIEVER             */
//////////////////////////////////////////////////////

wire rxclk_en, txclk_en;
//reg add = {16'h0005, 1'b1, 15'h7E3E, 7'd0};
//assign parity = ~(^add);
wire [39:0] spinn_pkt; //= { add, parity};

wire spinn_rdy;
wire dump;
wire ready; //= 1'b1;

assign LEDG[0] = ready;
assign LEDG[1] = dump;
assign LEDG[2] = spinn_rdy;
assign LEDR[17] = rx_byte[7];
assign LEDR[16] = GPIO_0[34];
//assign LEDR[14] = GPIO_0[33];

baud_rate_gen uart_baud(.clk_50m(CLOCK_50),
			.rxclk_en(rxclk_en),
			.txclk_en(txclk_en));
transmitter uart_tx(.din(tbyte),
		    .wr_en(transmit),
		    .clk_50m(CLOCK_50),
		    .clken(txclk_en),
		    .tx(GPIO_0[3]),
		    .tx_busy(transmitting));
receiver uart_rx(.rx(GPIO_0[2]),
		 .rdy(GPIO_0[1]),
		 .rdy_clr(GPIO_0[0]),
		 .clk_50(CLOCK_50),
		 .reset(reset),
		 .clken(rxclk_en),
		 .data(rx_byte),
		 .is_receiving(recieveing),
		 .spinn_pkt(spinn_pkt),
		 .ipkt_rdy(spinn_rdy),
		 .dump(dump),
		 .ipkt_vld(ready)
		 );

hex_7seg seg0(spinn_pkt[39:32],HEX0);
hex_7seg seg1(spinn_pkt[31:24],HEX1);
hex_7seg seg2(spinn_pkt[23:16],HEX2);
hex_7seg seg3(spinn_pkt[15:8],HEX3);
hex_7seg seg4(spinn_pkt[7:0],HEX4);
//hex_7seg seg2(qx[16:13],HEX5);
//hex_7seg seg2(qx[12:9],HEX6);
//hex_7seg seg2(qx[8],HEX7)[7:0]
//////////////////////////////////////////////////////
/*           SPINN DRIVER                           */
//////////////////////////////////////////////////////

//
//
 spinn_driver driv(
.CLK_IN(CLOCK_50),
.RESET_IN(reset),

  // synchronous packet interface
.PKT_DATA_IN(spinn_pkt),
.PKT_VLD_IN(ready),
.PKT_RDY_OUT(spinn_rdy),

  // SpiNNaker link asynchronous interface
.SL_DATA_2OF7_OUT(GPIO_1[6:0]),
.SL_ACK_IN(spinn_acq)
);


spio_spinnaker_link_sync 
#(.SIZE(1)
)
sync
(
  .CLK_IN (CLOCK_50),
  .IN     (GPIO_1[7]),
  .OUT    (spinn_acq)
);


endmodule