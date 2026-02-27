/*
Authour: Shahd

Module_name: SB_FDI_Packer

Description: The FDI Packer Block is responsible for handling local register access requests
originating from the Protocol Layer. Its role is to construct the appropriate
sideband packets for transmission over the sideband interface.
*/

import  SB_FDI_Packer_pkg::*;
module SB_FDI_Packer #(
     parameter int P_IN_W = 32 //8/16/32
)
(
  // Inputs
  input  logic         i_clk,             // clock
  input  logic         i_rst_n,           // async active-low reset
  input  logic [P_IN_W-1:0] i_lp_cfg,     // incoming chunk
  input  logic         i_lp_cfg_valid,    // chunk valid
  input  logic         i_full,            // FIFO full
  input  logic [4:0]   i_opcode,          // request opcode

  // Outputs
  output logic [127:0] o_data_in,          // assembled packet to FIFO
  output logic         o_wr_en,            // push enable (1-cycle pulse)
  output logic         o_is_config,        // decoded: config access
  output logic         o_read_req,         // decoded: read request
  output logic [4:0]   o_comp_opcode,      // decoded completion opcode
  output logic         o_fifo_overflow,    // overflow pulse
  output logic         o_opcode_error      // invalid opcode pulse
);

  // w_* (combinational)

  fdi_dec_t  w_dec;          // decoded opcode (combinational)
  logic [8:0] w_tgt_bits;     // target total bits = 64 + data_bits

  // r_* (registered)

  fdi_state_e r_state;       // FSM state
  fdi_dec_t   r_dec_lat;     // latched decode for current packet
  logic [127:0] r_sb_packet; // packet accumulator
  logic [8:0]   r_bit_cnt;   // how many bits collected so far
  logic [8:0]   r_target_bits; // final target bits for this packet

  logic r_wr_en;             // registered pulse
  logic r_fifo_overflow;     // registered pulse
  logic r_opcode_error;      // registered pulse

 
  // append chunk at position

  function automatic logic [127:0] append_bits(
    input logic [127:0]    i_current,
    input logic [P_IN_W-1:0] i_chunk,
    input logic [8:0]      i_position
  );
    logic [127:0] s_next;
    s_next = i_current;
    s_next[i_position +: P_IN_W] = i_chunk;
    return s_next;
  endfunction


  // combinational decode

  always_comb begin : comb_decode_init
    // init
    w_dec      = fdi_decode_opcode(i_opcode);
    w_tgt_bits = 9'(64 + w_dec.data_bits);
  end


  // outputs (combinational)

  always_comb begin : comb_outputs_init
    // init
    o_data_in        = r_sb_packet;
    o_is_config      = r_dec_lat.is_conf;
    o_read_req       = r_dec_lat.is_read;
    o_comp_opcode    = r_dec_lat.completion_opcode;

    o_wr_en          = r_wr_en;
    o_fifo_overflow  = r_fifo_overflow;
    o_opcode_error   = r_opcode_error;
  end


  // FSM (sequential)
 
  always_ff @(posedge i_clk or negedge i_rst_n) begin : seq_fsm_init // for software
    if (!i_rst_n) begin
      // init/reset
      r_state        <= S_IDLE;
      r_dec_lat      <= '0;
      r_sb_packet    <= '0;
      r_bit_cnt      <= '0;      r_target_bits  <= '0;

      r_wr_en        <= 1'b0;
      r_fifo_overflow<= 1'b0;
      r_opcode_error <= 1'b0;
    end else begin

      // init pulses every cycle
      r_wr_en         <= 1'b0;
      r_fifo_overflow <= 1'b0;
      r_opcode_error  <= 1'b0;

      unique case (r_state)

        S_IDLE: begin
          if (i_lp_cfg_valid) begin
            if (!w_dec.valid) begin
              r_opcode_error <= 1'b1;
              r_state        <= S_IDLE;
            end else begin
              r_dec_lat     <= w_dec;
              r_target_bits <= w_tgt_bits;

              r_sb_packet   <= '0;
              r_sb_packet[P_IN_W-1:0] <= i_lp_cfg;
              r_bit_cnt     <= 9'(P_IN_W);

              if (P_IN_W >= w_tgt_bits)
                r_state <= S_PUSH;
              else
                r_state <= S_COLLECT;
            end
          end
        end

        S_COLLECT: begin
          if (i_lp_cfg_valid) begin
            r_sb_packet <= append_bits(r_sb_packet, i_lp_cfg, r_bit_cnt);
            r_bit_cnt   <= r_bit_cnt + 9'(P_IN_W);

            if ((r_bit_cnt + 9'(P_IN_W)) >= r_target_bits)
              r_state <= S_PUSH;
          end
        end

        S_PUSH: begin
          if (!i_full) begin
            r_wr_en <= 1'b1;
          end else begin
            r_fifo_overflow <= 1'b1;
          end
          r_state <= S_IDLE;
        end

        default: begin
          r_state <= S_IDLE;
        end

      endcase
    end
  end

endmodule