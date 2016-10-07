module receiver(input wire rx,
		output reg rdy,
		input wire rdy_clr,
		input clk_50,
		input reset,
		input wire clken,
		output reg [7:0] data,
		output is_receiving,
		output reg [39:0] spinn_pkt,
		output reg ipkt_vld,
		input wire ipkt_rdy,
		output reg dump
		);
		
localparam spinn_chip_addr = 16'h0005;

initial begin
	rdy = 0;
	data = 8'b0;
	spinn_pkt = 40'd0;
end



parameter RX_STATE_START	= 2'b00;
parameter RX_STATE_DATA		= 2'b01;
parameter RX_STATE_STOP		= 2'b10;

reg [1:0] state = RX_STATE_START;
reg [3:0] sample = 0;
reg [3:0] bitpos = 0;
reg [7:0] scratch = 8'b0;

assign is_receiving = state == RX_STATE_DATA;

always @(posedge clk_50) begin
	if (rdy_clr)
		rdy <= 0;

	if (clken) begin
		case (state)
		RX_STATE_START: begin
			/*
			* Start counting from the first low sample, once we've
			* sampled a full bit, start collecting data bits.
			*/
			if (!rx || sample != 0)
				sample <= sample + 4'b1;

			if (sample == 15) begin
				state <= RX_STATE_DATA;
				bitpos <= 0;
				sample <= 0;
				scratch <= 0;
			end
		end
		RX_STATE_DATA: begin
			sample <= sample + 4'b1;
			if (sample == 4'h8) begin
				scratch[bitpos[2:0]] <= rx;
				bitpos <= bitpos + 4'b1;
			end
			if (bitpos == 8 && sample == 15)
				state <= RX_STATE_STOP;
		end
		RX_STATE_STOP: begin
			/*
			 * Our baud clock may not be running at exactly the
			 * same rate as the transmitter.  If we thing that
			 * we're at least half way into the stop bit, allow
			 * transition into handling the next start bit.
			 */
			if (sample == 15 || (sample >= 8 && !rx)) begin
				state <= RX_STATE_START;
				data <= scratch;
				rdy <= 1'b1;
				sample <= 0;
			end else begin
				sample <= sample + 4'b1;
			end
		end
		default: begin
			state <= RX_STATE_START;
		end
		endcase
	end
end

//localparam IDLE = 3'b110;
//localparam GET_BYTE = 3'b0;
//localparam SPIN_PKT =  3'b001;
//localparam WAIT = 3'b010;
//localparam DUMP = 3'b100;
//reg [2:0] spinn_state;


  localparam STATE_BITS = 2;
  localparam IDLE_ST    = 0;
  localparam WTRQ_ST    = IDLE_ST + 1;
  localparam DUMP_ST    = WTRQ_ST + 1;
  reg [STATE_BITS - 1:0] spinn_state;
  
 reg busy;
  
  
wire [38:0] pkt;
wire parity;
reg [7:0] dump_pkt;
reg [8:0] mapped_addr = 16'b0;
reg [1:0] count = 1'b0;
reg [3:0] y_dat = 4'b0;

always @(posedge clk_50) begin
	if(!count && data[7]) begin
		y_dat <= data[6:3];
		count <= 1;
	end else if (count) begin
		mapped_addr <= {data[7], y_dat, data[6:3]};
		count <=0;
	end
end



//assign pkt = {spinn_chip_addr, 1'b1, mapped_addr, 7'd0};

assign pkt = {spinn_chip_addr, 1'b1, 6'b000000, mapped_addr, 7'b0000000};
assign parity   = ~(^pkt);

reg nxt_vld;

reg [7:0] dump_ctr; 

always @(posedge clk_50 or posedge reset)
	if (reset)
		spinn_pkt <= 40'd0;  // not really necessary!
   else
      case (spinn_state)
      IDLE_ST:
			if (count && !busy)
				spinn_pkt <= {pkt, parity};  // no payload!
         else
            spinn_pkt <= spinn_pkt;  // no change!

	default:  
            spinn_pkt <= spinn_pkt;  // no change!
endcase

always @(posedge clk_50 or posedge reset)
    if (reset)
      ipkt_vld <= 1'b0;
    else
      if (nxt_vld || busy)
        ipkt_vld <= 1'b1;
      else
        ipkt_vld <= 1'b0;

always @(*)
    case (spinn_state)
    	IDLE_ST: 
			if (count && !busy)
				nxt_vld <= 1'b1;
         else
            nxt_vld <= 1'b0;

    default:   nxt_vld <= 1'b0;
endcase 

always @(*)
	busy = ipkt_vld && !ipkt_rdy;

always @(posedge clk_50 or posedge reset)
    if (reset)
      dump_ctr <= 8'd128;
    else
      if (ipkt_rdy)
        dump_ctr <= 8'd128;  // spinn_driver ready resets counter
      else if (dump_ctr != 5'd0)
        dump_ctr <= dump_ctr - 1;
      else
        dump_ctr <= dump_ctr;  // no change!
 
  always @(posedge clk_50 or posedge reset)
    if (reset)
      dump <= 1'b0;
    else
      if (spinn_state == DUMP_ST)
        dump <= 1'b1;
      else
        dump <= 1'b0;
  //---------------------------------------------------------------

  //---------------------------------------------------------------
  // in_mapper state machine
  //---------------------------------------------------------------
  always @(posedge clk_50 or posedge reset)
    if (reset)
      spinn_state <= IDLE_ST;
    else
      case (spinn_state)
        IDLE_ST:
          casex ({(dump == 0), rdy_clr, busy})
            3'b1xx:  spinn_state <= DUMP_ST;
            3'b000:  spinn_state <= WTRQ_ST;
            default: spinn_state <= IDLE_ST;  // no change!
	  endcase

	WTRQ_ST:
          if (!count)
            spinn_state <= IDLE_ST;
          else
            spinn_state <= WTRQ_ST;  // no change!

	DUMP_ST:
          case ({ipkt_rdy, rdy_clr})
            2'b10:   spinn_state <= WTRQ_ST;
            2'b11:   spinn_state <= IDLE_ST;
            default: spinn_state <= DUMP_ST;  // no change!
	  endcase
	
	default:  
            spinn_state <= spinn_state;  // no change!
endcase

//assign parity = ~(^pkt);
//
//always @(posedge clk_50m ) begin
//	if (reset) begin
//		spinn_state = IDLE;
//	end else
//		case(spinn_state)
//		IDLE: begin
//			//count <= 0;
//			ready <= 0;
//			dump <= 1'b1;
//			if(dump_pkt != 0)
//				spinn_state <= GET_BYTE;
//		end
//		GET_BYTE: begin
//			dump <= 1'b0;
//			
//		end
//		SPIN_PKT: begin
//			spinn_pkt <= { pkt, parity};
//			ready = 1;
//			spinn_state <= IDLE;
//		end
//		endcase
//end
//
//always @(posedge clk_50m or posedge reset) begin
//	if (reset) 
//		dump_pkt = 8'd200;
//	else begin
//		if(spinn_rdy)
//			dump_pkt <= 8'd200;
//		else if(dump_pkt != 8'd0)
//			dump_pkt <= dump_pkt -1;
//		else 
//			dump_pkt <= dump_pkt;
//	end		
//end

endmodule