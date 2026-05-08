//author : fatma fawzy
//module description : process the received ack/nak flits to get valid ones
//date : 28/2/2026
import UC_MB_retry_pkg::*;

module UC_MB_retry_ack_nak_processing (
    input logic            clk,
    input logic            rst_n,
    input phase_t          i_rx_phase,
    input logic            init,  // software reset
    input replay_command_t i_rx_replay_command,  // ack or nak or explicit
    input logic [7:0]      i_rx_seq_num,  // sequence number of the received flit
    input logic            i_rx_crc_error,  // crc error in the received flit from mainband receiver
    input logic [7:0]      i_next_tx_flit_seq_num,  //from transmitting_rules module
    input logic [7:0]      i_tx_replay_flit_seq_num,
    output logic [2:0]     o_flit_replay_num,
    output logic [7:0]     o_ackd_flit_seq_num,
    output logic [7:0]     o_tx_replay_flit_seq_num,
    output logic [7:0]     o_nak_ignore_flit_seq_num,
    output logic           o_start_replay,  //start replaying data in case of NAK recieved
    output logic           o_log_uie  // log uncorrectable internal error in register file
);

  logic [7:0] ackd_flit_seq_num;
  logic [7:0] nak_ignore_flit_seq_num;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      o_log_uie                <= 1'b0;
      o_flit_replay_num        <= 3'b0;
      ackd_flit_seq_num        <= 8'b0;
      o_tx_replay_flit_seq_num <= 8'b0;
      nak_ignore_flit_seq_num  <= 8'b0;
      o_start_replay           <= 1'b0;
    end else if (!init || i_rx_phase == R_IDLE) begin
      o_log_uie                <= 1'b0;
      o_flit_replay_num        <= 3'b0;
      ackd_flit_seq_num        <= 8'b0;
      o_tx_replay_flit_seq_num <= 8'b0;
      nak_ignore_flit_seq_num  <= 8'b0;
      o_start_replay           <= 1'b0;
    end else begin
      o_start_replay <= 1'b0;
      o_log_uie      <= 1'b0;
      if (!i_rx_crc_error) begin
        if ((i_rx_replay_command == ack || i_rx_replay_command == nak)) begin
          if (i_rx_seq_num == 8'b0) begin
            // ignore ack/nak
          end else if (!valid_sequence_number(i_rx_seq_num)) begin
            o_log_uie <= 1'b1;
            // ignore ack/nak
          end else begin  // valid ack/nak
            if ((i_rx_seq_num - ackd_flit_seq_num) % 255 > 0) begin
              o_flit_replay_num <= 3'b0;
              ackd_flit_seq_num <= i_rx_seq_num;
            end
            // pruge retry buffer 
          end
          if (i_rx_replay_command == ack) begin  // valid ack
            nak_ignore_flit_seq_num <= 0;
            if (((i_rx_seq_num - i_tx_replay_flit_seq_num) % 255) < MAX_UNACKNOWLEDGED_FLITS)
              o_tx_replay_flit_seq_num <= 0;
          end else begin  // valid nak
            if (i_rx_seq_num == (i_next_tx_flit_seq_num - 1)) begin
              nak_ignore_flit_seq_num <= i_rx_seq_num;
            end else if (i_rx_seq_num != nak_ignore_flit_seq_num) begin
              nak_ignore_flit_seq_num <= 0;
            end
            o_start_replay <= 1'b1;  // schedule a replay as neccessary
          end
        end
      end
    end
  end

  function automatic valid_sequence_number(input [7:0] seq_num);
    return ((i_next_tx_flit_seq_num - 1) - seq_num) % 255 <= MAX_UNACKNOWLEDGED_FLITS &&
           (seq_num - ackd_flit_seq_num) % 255 <= MAX_UNACKNOWLEDGED_FLITS;
  endfunction

  assign o_ackd_flit_seq_num = ackd_flit_seq_num;
  assign o_nak_ignore_flit_seq_num = nak_ignore_flit_seq_num;
endmodule
