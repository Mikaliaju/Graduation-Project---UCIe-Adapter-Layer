//author : fatma fawzy
//module description : controls the buffer operations (write, replay, purge)
//date : 10/3/2026

import UC_MB_retry_pkg::*;
module UC_MB_retry_buffer (
    input  logic                             clk,
    input  logic                             rst_n,
    input  logic                             init,
    input  phase_t                           i_tx_phase,
    input  logic          [             7:0] i_tx_replay_flit_seq_num,
    input  logic          [             7:0] i_ackd_flit_seq_num,
    input  logic                             i_replay_scheduled,
    input  logic                             i_replay_in_progress,
    input  logic                             i_transmitter_write, //from outside the retry
    input  logic                             i_flush, //from outside
    input  logic                             i_drain, //from outside
    input  logic                             i_pl_trdy_control,
    input  logic          [             7:0] i_next_tx_flit_seq_num,
    input  logic          [  DATA_WIDTH-1:0] i_data,
    input  logic          [STREAM_WIDTH-1:0] i_stream,
    output logic          [  DATA_WIDTH-1:0] o_data,
    output logic          [STREAM_WIDTH-1:0] o_stream,
    output buffer_state_t                    o_buffer_state
);

  logic [1:0] chunk_counter, w_chunk_counter;

  logic [ADDR_DATA_WIDTH-1:0] write_data_ptr, replay_data_ptr, acked_data_ptr;
  logic [ADDR_DATA_WIDTH-1:0] w_write_data_ptr, w_replay_data_ptr, w_acked_data_ptr;

  logic [ADDR_STREAM_WIDTH-1:0] write_stream_ptr, replay_stream_ptr, acked_stream_ptr;
  logic [ADDR_STREAM_WIDTH-1:0] w_write_stream_ptr, w_replay_stream_ptr, w_acked_stream_ptr;

  // Address mux outputs — driven only by always_comb
  logic [  ADDR_DATA_WIDTH-1:0] addr_data;
  logic [ADDR_STREAM_WIDTH-1:0] addr_stream;

  logic [       DATA_WIDTH-1:0] r_data      [  0:DATA_DEPTH-1];
  logic [     STREAM_WIDTH-1:0] r_stream    [0:STREAM_DEPTH-1];

  //operation purge
  //a acked_flits_ptr determine which address has been acked.

  //operation write
  // write_addr_ptr moves with each chunks added to the 
  //buffer by the transmitter while pl_trdy_control is 0

  //operation replay 
  //a replay_ptr moves with each chunk starting from 
  //tx_replay_flit_seq_num until the end of the data in buffer 
  //(write_ptr == replay_ptr) handled by the transmitting_rules Module

  // address for data = 4 (flit seq num - 1)
  // address for stream = 1 (flit seq num - 1)

  assign w_acked_data_ptr   = 4 * (i_ackd_flit_seq_num - 1);
  assign w_acked_stream_ptr = i_ackd_flit_seq_num - 1;

  always_comb begin
    if (acked_data_ptr == write_data_ptr - 2) o_buffer_state <= empty;
    else o_buffer_state <= counting;
  end

  always_comb begin
    if (i_replay_scheduled || i_replay_in_progress || i_drain || i_flush) begin
      addr_data   = replay_data_ptr;
      addr_stream = replay_stream_ptr;
    end else begin
      addr_data   = w_write_data_ptr;
      addr_stream = w_write_stream_ptr;
    end
  end

  // buffer controller logic 

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      write_data_ptr    <= '0;
      write_stream_ptr  <= '0;
      chunk_counter     <= '0;
      replay_data_ptr   <= '0;
      replay_stream_ptr <= '0;
      acked_data_ptr    <= '0;
      acked_stream_ptr  <= '0;
    end else if (!init || i_tx_phase == R_IDLE) begin
      write_data_ptr    <= '0;
      write_stream_ptr  <= '0;
      chunk_counter     <= '0;
      replay_data_ptr   <= '0;
      replay_stream_ptr <= '0;
      acked_data_ptr    <= '0;
      acked_stream_ptr  <= '0;
    end else begin
      replay_data_ptr   <= w_replay_data_ptr;
      replay_stream_ptr <= w_replay_stream_ptr;
      write_data_ptr   <= w_write_data_ptr;
      chunk_counter    <= w_chunk_counter;
      write_stream_ptr <= w_write_stream_ptr;
      acked_data_ptr   <= w_acked_data_ptr;
      acked_stream_ptr <= w_acked_stream_ptr;
    end
  end


  always_comb begin
    w_write_data_ptr   = write_data_ptr;
    w_write_stream_ptr = write_stream_ptr;
    w_chunk_counter    = chunk_counter;
    w_replay_data_ptr  = replay_data_ptr;
    w_replay_stream_ptr = replay_stream_ptr;
    if (i_replay_scheduled) begin
      w_replay_data_ptr   = 4 * (i_tx_replay_flit_seq_num - 1);
      w_replay_stream_ptr = i_tx_replay_flit_seq_num - 1;
    end else if (i_replay_in_progress && !i_replay_scheduled) begin
      w_replay_data_ptr = replay_data_ptr + 1;
    end else if (!i_replay_in_progress && !i_replay_scheduled && i_transmitter_write) begin
      w_write_data_ptr   =  4 * (i_next_tx_flit_seq_num - 1) + chunk_counter;
      w_write_stream_ptr = i_next_tx_flit_seq_num - 1;
      w_chunk_counter    = chunk_counter + 1;
    end
  end

  //Memory default logic

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < DATA_DEPTH; i = i + 1) begin
        r_data[i] <= 'b0;
      end
      for (int i = 0; i < STREAM_DEPTH; i = i + 1) begin
        r_stream[i] <= 'b0;
      end
      o_data   <= '0;
      o_stream <= '0;
    end else if (!init || i_tx_phase == R_IDLE) begin
      for (int i = 0; i < DATA_DEPTH; i = i + 1) begin
        r_data[i] <= 'b0;
      end
      for (int i = 0; i < STREAM_DEPTH; i = i + 1) begin
        r_stream[i] <= 'b0;
      end
      o_data   <= '0;
      o_stream <= '0;
    end else if (i_replay_scheduled || i_replay_in_progress || i_drain || i_flush) begin
      o_data   <= r_data[addr_data];
      o_stream <= r_stream[addr_stream];
    end else if (i_transmitter_write) begin
      r_data[addr_data] <= i_data;
      r_stream[addr_stream] <= i_stream;
    end
  end

endmodule
