// -------------------------------------------------------------------------
//  SpiNNaker link transmitter module
//
// -------------------------------------------------------------------------
// AUTHOR
//  lap - luis.plana@manchester.ac.uk
//  Based on work by J Pepper (Date 08/08/2012)
//
// -------------------------------------------------------------------------
// Taken from:
// https://solem.cs.man.ac.uk/svn/spiNNlink/testing/src/packet_sender.v
// Revision 2517 (Last-modified date: 2013-08-19 10:33:30 +0100)
//
// -------------------------------------------------------------------------
// COPYRIGHT
//  Copyright (c) The University of Manchester, 2012. All rights reserved.
//  SpiNNaker Project
//  Advanced Processor Technologies Group
//  School of Computer Science
// -------------------------------------------------------------------------
// TODO
//  * decide what to do with "default" cases: non-valid states.
//  * could save one clock cycle by adding RDY_ST (not straightforward!).
// -------------------------------------------------------------------------

`define PKT_BITS         40

// ----------------------------------------------------------------
// include spiNNlink global constants and parameters
//
// ----------------------------------------------------------------



`timescale 1ns / 1ps

module spinn_driver
(
  input                        CLK_IN,
  input                        RESET_IN,

  // synchronous packet interface
  input      [`PKT_BITS - 1:0] PKT_DATA_IN,
  input                        PKT_VLD_IN,
  output reg                   PKT_RDY_OUT,

  // SpiNNaker link asynchronous interface
  output reg             [6:0] SL_DATA_2OF7_OUT,
  input                        SL_ACK_IN
);

  //---------------------------------------------------------------
  // constants
  //---------------------------------------------------------------
  //# Xilinx recommends one-hot state encoding
  localparam STATE_BITS = 2;
  localparam IDLE_ST    = 0;
  localparam TRAN_ST    = IDLE_ST + 1;
  localparam EOP_ST     = TRAN_ST + 1;
  localparam PARK_ST    = EOP_ST + 1;


  //---------------------------------------------------------------
  // internal signals
  //---------------------------------------------------------------
  reg  [STATE_BITS - 1:0] state;
  reg                     eop;

  reg                     old_ack;
  reg                     acked;

  reg   [`PKT_BITS - 1:0] pkt_buf;
  reg                     long_pkt;
  reg               [4:0] symbol_cnt;


  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //--------------------------- functions -------------------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //---------------------------------------------------------------
  // NRZ 2-of-7 encoder
  //---------------------------------------------------------------
  function [6:0] encode_2of7 ;
    input [4:0] din;
    input [6:0] code_2of7;

    casex (din)
      5'b00000 : encode_2of7 = code_2of7 ^ 7'b0010001; // 0
      5'b00001 : encode_2of7 = code_2of7 ^ 7'b0010010; // 1
      5'b00010 : encode_2of7 = code_2of7 ^ 7'b0010100; // 2
      5'b00011 : encode_2of7 = code_2of7 ^ 7'b0011000; // 3
      5'b00100 : encode_2of7 = code_2of7 ^ 7'b0100001; // 4
      5'b00101 : encode_2of7 = code_2of7 ^ 7'b0100010; // 5
      5'b00110 : encode_2of7 = code_2of7 ^ 7'b0100100; // 6
      5'b00111 : encode_2of7 = code_2of7 ^ 7'b0101000; // 7
      5'b01000 : encode_2of7 = code_2of7 ^ 7'b1000001; // 8
      5'b01001 : encode_2of7 = code_2of7 ^ 7'b1000010; // 9
      5'b01010 : encode_2of7 = code_2of7 ^ 7'b1000100; // 10
      5'b01011 : encode_2of7 = code_2of7 ^ 7'b1001000; // 11
      5'b01100 : encode_2of7 = code_2of7 ^ 7'b0000011; // 12
      5'b01101 : encode_2of7 = code_2of7 ^ 7'b0000110; // 13
      5'b01110 : encode_2of7 = code_2of7 ^ 7'b0001100; // 14
      5'b01111 : encode_2of7 = code_2of7 ^ 7'b0001001; // 15
      5'b1xxxx : encode_2of7 = code_2of7 ^ 7'b1100000; // EOP
      default  : encode_2of7 = 7'bxxxxxxx;
    endcase
  endfunction
  //---------------------------------------------------------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //--------------------------- datapath --------------------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //---------------------------------------------------------------
  // SpiNNaker link interface
  //---------------------------------------------------------------
  always @(posedge CLK_IN or posedge RESET_IN)
    if (RESET_IN)
      SL_DATA_2OF7_OUT <= 7'd0;
    else
      case (state)
        IDLE_ST: if (PKT_VLD_IN)
                   SL_DATA_2OF7_OUT <= encode_2of7 ({1'b0, PKT_DATA_IN[3:0]},
                                                     SL_DATA_2OF7_OUT
                                                   );     // first nibble
                 else
                   SL_DATA_2OF7_OUT <= SL_DATA_2OF7_OUT;  // no change!

        TRAN_ST: if (acked)
                     SL_DATA_2OF7_OUT <= encode_2of7 ({eop, pkt_buf[3:0]},
                                                       SL_DATA_2OF7_OUT
                                                     );   // next nibble or eop
                 else
                   SL_DATA_2OF7_OUT <= SL_DATA_2OF7_OUT;  // no change!

        EOP_ST:  if (acked && PKT_VLD_IN)
                   SL_DATA_2OF7_OUT <= encode_2of7 ({1'b0, PKT_DATA_IN[3:0]},
                                                     SL_DATA_2OF7_OUT
                                                   );     // first nibble
                 else
                   SL_DATA_2OF7_OUT <= SL_DATA_2OF7_OUT;  // no change!

        PARK_ST: if (acked)
                   SL_DATA_2OF7_OUT <= encode_2of7 ({1'b0, pkt_buf[3:0]},
                                                     SL_DATA_2OF7_OUT
                                                   );     // first nibble
                 else
                   SL_DATA_2OF7_OUT <= SL_DATA_2OF7_OUT;  // no change!

        default:   SL_DATA_2OF7_OUT <= SL_DATA_2OF7_OUT;  // no change!
      endcase 

  always @(posedge CLK_IN or posedge RESET_IN)
    if (RESET_IN)
      old_ack   <= 1'b0;  // not really necessary!
    else
      case (state)
        IDLE_ST: if (PKT_VLD_IN)
                   old_ack <= SL_ACK_IN;  // remember SL_ACK_IN value
                 else
                   old_ack <= old_ack;    // no change!

        TRAN_ST,
        PARK_ST: if (acked)
                   old_ack <= SL_ACK_IN;  // remember SL_ACK_IN value
                 else
                   old_ack <= old_ack;    // no change!

        EOP_ST:  if (acked && PKT_VLD_IN)
                   old_ack <= SL_ACK_IN;  // remember SL_ACK_IN value
                 else
                   old_ack <= old_ack;    // no change!

        default:   old_ack <= old_ack;    // no change!
      endcase 
  //---------------------------------------------------------------

  //---------------------------------------------------------------
  // packet interface
  //---------------------------------------------------------------
  always @(posedge CLK_IN or posedge RESET_IN)
    if (RESET_IN)
      PKT_RDY_OUT <= 1'b1;
    else
      case (state)
        IDLE_ST: if (PKT_VLD_IN)
                   PKT_RDY_OUT <= 1'b0;
                 else
                   PKT_RDY_OUT <= 1'b1;

        TRAN_ST: if (acked && eop)
                   PKT_RDY_OUT <= 1'b1;         // ready for next packet
                 else
                   PKT_RDY_OUT <= 1'b0;

        EOP_ST:  if (PKT_VLD_IN)
                   PKT_RDY_OUT <= 1'b0;
                 else
                   PKT_RDY_OUT <= 1'b1;

        default:   PKT_RDY_OUT <= PKT_RDY_OUT;  // no change!
      endcase 

  always @(posedge CLK_IN or posedge RESET_IN)
    if (RESET_IN)
      pkt_buf <= {(`PKT_BITS) {1'b0}};  // not really necessary!
    else
      case (state)
        IDLE_ST: if (PKT_VLD_IN)
                   pkt_buf <= PKT_DATA_IN >> 4;    // first nibble gone
                 else
                   pkt_buf <= pkt_buf;             // no change!

        TRAN_ST: if (acked)
                   pkt_buf <= pkt_buf >> 4;        // prepare for next nibble
                 else
                   pkt_buf <= pkt_buf;             // no change!

        EOP_ST: 
          case ({acked, PKT_VLD_IN})
	    2'b01:   pkt_buf <= PKT_DATA_IN;       // park new packet
	    2'b11:   pkt_buf <= PKT_DATA_IN >> 4;  // first nibble gone
            default: pkt_buf <= pkt_buf;           // no change!
	  endcase
	
        PARK_ST: if (acked)
                   pkt_buf <= pkt_buf >> 4;  // prepare for next nibble
                 else
                   pkt_buf <= pkt_buf;       // no change!

        default:   pkt_buf <= pkt_buf;       // no change!
      endcase 

  always @(posedge CLK_IN or posedge RESET_IN)
    if (RESET_IN)
      symbol_cnt <= 5'd0;  // not really necessary!
    else
      case (state)
        IDLE_ST: if (PKT_VLD_IN)
                   symbol_cnt <= 5'd1;  // start counting symbols (nibbles)
                 else
                   symbol_cnt <= 5'd0;

        TRAN_ST: if (acked)
                   symbol_cnt <= symbol_cnt + 1;
                 else
                   symbol_cnt <= symbol_cnt;  // no change!

        EOP_ST:  if (acked && PKT_VLD_IN)
                   symbol_cnt <= 5'd1;  // start counting symbols (nibbles)
                 else
                   symbol_cnt <= 5'd0;

        PARK_ST: if (acked)
                   symbol_cnt <= 5'd1;  // start counting symbols (nibbles)
                 else
                   symbol_cnt <= 5'd0;

        default:   symbol_cnt <= symbol_cnt;  // no change!
      endcase 

  always @(posedge CLK_IN or posedge RESET_IN)
    if (RESET_IN)
      long_pkt <= 1'b0;  // not really necessary!
    else
      case (state)
        IDLE_ST: if (PKT_VLD_IN)
                   long_pkt <= PKT_DATA_IN[1];  // remember packet size
                 else
                   long_pkt <= long_pkt;        // no change!

        EOP_ST:  if (acked && PKT_VLD_IN)
                   long_pkt <= PKT_DATA_IN[1];  // remember packet size
                 else
                   long_pkt <= long_pkt;        // no change!

        PARK_ST: if (acked)
                   long_pkt <= pkt_buf[1];      // remember packet size
                 else
                   long_pkt <= long_pkt;        // no change!

        default:   long_pkt <= long_pkt;        // no change!
      endcase 
  //---------------------------------------------------------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //---------------------------- control --------------------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //---------------------------------------------------------------
  // send end-of-packet (combinatorial)
  //---------------------------------------------------------------
  always @ (*)
    eop = (!long_pkt && (symbol_cnt == 10)) || (symbol_cnt == 18);
  //---------------------------------------------------------------

  //---------------------------------------------------------------
  // output data has been acked (combinatorial)
  //---------------------------------------------------------------
  always @ (*)
    acked = (old_ack != SL_ACK_IN);
  //---------------------------------------------------------------

  //---------------------------------------------------------------
  // state
  //---------------------------------------------------------------
  always @(posedge CLK_IN or posedge RESET_IN)
    if (RESET_IN)
      state <= IDLE_ST;
    else
      case (state)
        IDLE_ST: if (PKT_VLD_IN)
                   state <= TRAN_ST;    // start new packet
                 else
                   state <= IDLE_ST;    // no change!

        TRAN_ST: if (acked && eop)
                   state <= EOP_ST;     // done with packet
                 else
                   state <= TRAN_ST;    // no change!

        EOP_ST:  
          case({acked, PKT_VLD_IN})
	    2'b01:   state <= PARK_ST;  // park new packet
            2'b10:   state <= IDLE_ST;  // wait for new packet
	    2'b11:   state <= TRAN_ST;  // start new packet
            default: state <= EOP_ST;   // no change!
          endcase
                   
        PARK_ST: if (acked)
                   state <= TRAN_ST;
                 else
                   state <= PARK_ST;    // no change!

        default:   state <= state;    // no change!
      endcase 
  //---------------------------------------------------------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
endmodule