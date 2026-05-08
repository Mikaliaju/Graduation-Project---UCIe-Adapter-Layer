//author : fatma fawzy
//module description : schedules the replay of the flits that are stored in the tx retry buffer
//date : 10/3/2026
import UC_MB_retry_pkg::*;
module UC_MB_retry_replay_schedule (
    input  logic                        clk,
    input  logic                        rst_n,
    input  logic                        init,
    input  phase_t                      i_tx_phase,
    input  logic                        i_replay_in_progress,
    input  logic                        i_start_replay,
    input  logic                  [7:0] i_rx_seq_num,
    input  logic                  [7:0] i_ackd_flit_seq_num,
    input  logic                  [7:0] i_nak_ignore_flit_seq_num,
    input  logic                  [8:0] i_replay_timeout_flit_count,
    input  logic                  [7:0] i_tx_replay_flit_seq_num,
    output logic                  [7:0] o_tx_replay_flit_seq_num,
    output logic                  [7:0] o_nak_ignore_flit_seq_num,
    output logic                        o_consecutive_reset,
    output logic                        o_log_cie,
    output logic                        o_replay_scheduled,
    output replay_schedule_type_t       o_replay_scheduled_type,
    output logic                        o_start_buffer_replay_mode
);


  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      o_replay_scheduled <= 1'b0;
      o_replay_scheduled_type <= standard_replay;
      o_tx_replay_flit_seq_num <= '0;
      o_nak_ignore_flit_seq_num <= '0;
      o_consecutive_reset <= 1'b0;
      o_log_cie <= 1'b0;
      o_start_buffer_replay_mode <= 1'b0;
    end else if (!init || i_tx_phase == R_IDLE) begin
      o_replay_scheduled <= 1'b0;
      o_replay_scheduled_type <= standard_replay;
      o_tx_replay_flit_seq_num <= '0;
      o_nak_ignore_flit_seq_num <= '0;
      o_consecutive_reset <= 1'b0;
      o_log_cie <= 1'b0;
      o_start_buffer_replay_mode <= 1'b0;
    end else begin
      o_log_cie <= 1'b0;
      o_consecutive_reset <= 1'b0;

      if (i_replay_timeout_flit_count >= 375) begin
        if (!o_replay_scheduled && !i_replay_in_progress) begin
          replay_schedule_0();
        end
      end else if (i_start_replay) begin
        if(!i_replay_in_progress && !o_replay_scheduled) begin //a payload flit with flit sequence number n + 1 is stored in the tx retry buffer.
          if (i_nak_ignore_flit_seq_num != i_rx_seq_num || i_nak_ignore_flit_seq_num == 0)
            replay_schedule_1();
        end
      end else begin
        if (i_replay_in_progress) begin
          o_replay_scheduled         <= 1'b0;
          o_start_buffer_replay_mode <= 1'b0;
        end
        o_nak_ignore_flit_seq_num <= i_nak_ignore_flit_seq_num;
        o_tx_replay_flit_seq_num  <= i_tx_replay_flit_seq_num;
      end
    end
  end

  task replay_schedule_0();
    o_replay_scheduled <= 1'b1;
    o_replay_scheduled_type <= standard_replay;
    o_tx_replay_flit_seq_num <= i_ackd_flit_seq_num + 1;
    o_consecutive_reset <= 1'b1;
    o_log_cie <= 1'b1;
  endtask

  task replay_schedule_1();
    o_replay_scheduled <= 1'b1;
    o_replay_scheduled_type <= standard_replay;
    o_tx_replay_flit_seq_num <= i_rx_seq_num + 1;
    o_nak_ignore_flit_seq_num <= i_rx_seq_num;
  endtask


endmodule
