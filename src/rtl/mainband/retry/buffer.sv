//author : fatma fawzy
//module description : controls the buffer operations (write, replay, purge)
//date : 10/3/2026

import UC_retry_pkg::*;
module UC_MB_retry_buffer (
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    init,
    input  logic [             7:0] i_tx_replay_flit_seq_num,
    input  logic [             7:0] i_ackd_flit_seq_num,
    input  logic                    i_start_buffer_replay_mode,
    input  logic [             7:0] i_next_tx_flit_seq_num,
    input  logic [  DATA_WIDTH-1:0] i_data,
    input  logic [STREAM_WIDTH-1:0] i_stream,
    output logic [  DATA_WIDTH-1:0] o_data,
    output logic [STREAM_WIDTH-1:0] o_stream,
    output logic                    o_replayed_finished
);

  logic [1:0] chunk_counter;
  logic stop_writing, replay_write, replay_write_d;

  logic [ADDR_DATA_WIDTH-1:0] write_data_ptr, replay_data_ptr, acked_data_ptr;
  logic [ADDR_STREAM_WIDTH-1:0] write_stream_ptr, replay_stream_ptr, acked_stream_ptr;

  // Address mux outputs — driven only by always_comb
  logic [  ADDR_DATA_WIDTH-1:0] addr_data;
  logic [ADDR_STREAM_WIDTH-1:0] addr_stream;

  //assign replay_write = i_start_buffer_replay_mode ? 1'b1 : 1'b0;
  //assign stop_writing = (write_data_ptr == acked_data_ptr - 1) ? 1'b1 : 1'b0;
  assign stop_writing = (((i_next_tx_flit_seq_num - i_ackd_flit_seq_num) & 8'hFF) >= MAX_UNACKNOWLEDGED_FLITS);
  assign o_replayed_finished = (replay_data_ptr == write_data_ptr - 1) ? 1'b1 : 1'b0;

  reg [  DATA_WIDTH-1:0] r_data  [  DATA_DEPTH-1:0];
  reg [STREAM_WIDTH-1:0] r_stream[STREAM_DEPTH-1:0];

  //operation purge
  //a acked_flits_ptr determine which address has been acked.

  //operation write
  // write_addr_ptr moves with each chunks added to the 
  //buffer by the transmitter while write_replay is 1 

  //operation replay 
  //a replay_ptr moves with each chunk starting from 
  //tx_replay_flit_seq_num until the end of the data in buffer 
  //(write_ptr == replay_ptr)

  // address for data = 4 (flit seq num - 1)
  // address for stream = 1 (flit seq num - 1)

  assign acked_data_ptr = 4 * (i_ackd_flit_seq_num - 1);
  assign acked_stream_ptr = i_ackd_flit_seq_num - 1;

  //assign replay_data_ptr = 4 * (i_tx_replay_flit_seq_num - 1) - 1;
  //assign replay_stream_ptr = (i_tx_replay_flit_seq_num - 1) - 1;

  always_comb begin
    if (!replay_write) begin
      addr_data   = write_data_ptr;
      addr_stream = write_stream_ptr;
    end else begin
      addr_data   = replay_data_ptr;
      addr_stream = replay_stream_ptr;
    end
  end

  // buffer controller logic 

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      write_data_ptr <= '0;
      chunk_counter  <= 2'b0;
      replay_write_d <= 1'b0;
    end else if (!init) begin
      write_data_ptr <= '0;
      chunk_counter  <= 2'b0;
      replay_write_d <= 1'b0;
    end else begin 
      replay_write_d <= replay_write;
      if(replay_write && !replay_write_d) begin 
        replay_data_ptr   <= 4 * (i_tx_replay_flit_seq_num - 1);
        replay_stream_ptr <= (i_tx_replay_flit_seq_num - 1);
      end
      else if (replay_write && replay_write_d && !o_replayed_finished) begin
        replay_data_ptr   <= replay_data_ptr + 1;
        replay_stream_ptr <= replay_stream_ptr + 1;
      end
      else if (!replay_write && !stop_writing) begin
        write_data_ptr   <= 4 * (i_next_tx_flit_seq_num - 1) + chunk_counter;
        chunk_counter    <= chunk_counter + 1;
        write_stream_ptr <= i_next_tx_flit_seq_num - 1;
      end
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
    end else if (!init) begin
      for (int i = 0; i < DATA_DEPTH; i = i + 1) begin
        r_data[i] <= 'b0;
      end
      for (int i = 0; i < STREAM_DEPTH; i = i + 1) begin
        r_stream[i] <= 'b0;
      end
    end else if (replay_write && !o_replayed_finished) begin
      o_data   <= r_data[addr_data];
      o_stream <= r_stream[addr_stream];
    end else if (!replay_write && !stop_writing) begin
      r_data[addr_data]     <= i_data;
      r_stream[addr_stream] <= i_stream;
    end
  end

endmodule
