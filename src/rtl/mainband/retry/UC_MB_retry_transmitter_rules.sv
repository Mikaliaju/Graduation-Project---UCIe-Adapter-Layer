import UC_MB_retry_pkg::*;

module UC_MB_retry_transmitter_rules (
    input  logic                        clk,
    input  logic                        rst_n,
    input  logic                        init,
    input  logic                        i_snh_done,
    input  logic                        i_snh_timeout,
    input  logic                        i_replay_scheduled,
    input  replay_schedule_type_t       i_replay_scheduled_type,
    input  logic                        i_nak_scheduled,
    input  nak_schedule_type_t          i_nak_schedule_type,
    input  logic                        i_consecutive_reset,
    input  logic                  [7:0] i_tx_acknak_flit_seq_num,
    input  logic                        i_tx_en,
    input  buffer_state_t               i_buffer_state,
    input  logic                        i_fdi_active,
    input  logic                        i_flit_valid,                 // from transmitter 
    input  data_rate_t                  i_data_rate,
    input  logic                  [2:0] i_flit_replay_num,
    input  logic                  [7:0] i_tx_replay_flit_seq_num,
    input  logic                  [7:0] i_nak_ignore_flit_seq_num,
    input  logic                  [7:0] i_ackd_flit_seq_num,
    output logic                  [7:0] o_next_tx_flit_seq_num,
    output logic                  [8:0] o_replay_timeout_flit_count,
    output replay_command_t             o_tx_replay_command,
    output logic                        o_pl_trdy_control,
    output logic                  [7:0] o_tx_seq_num,
    output logic                        o_rdi_retrain,
    output logic                        o_replay_in_progress,
    output logic                        o_log_cie,
    output phase_t                      o_tx_phase
);

  logic [2:0] flit_replay_num;

  flit_type_t tx_flit_type;
  assign tx_flit_type = (o_pl_trdy_control) ? NOP : PAYLOAD;

  phase_t tx_phase;
  assign o_tx_phase = tx_phase;

  logic [2:0] consecutive_tx_nak_flits;
  logic       consecutive_tx_explicit_seq_num;

  logic [7:0] next_tx_flit_seq_num;
  logic [8:0] replay_timeout_flit_count;

  assign o_next_tx_flit_seq_num = next_tx_flit_seq_num;
  assign o_replay_timeout_flit_count = replay_timeout_flit_count;

  // Phase controller 

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx_phase <= R_IDLE;
    end else if (!init || !i_tx_en) begin
      tx_phase <= R_IDLE;
    end else begin
      case (tx_phase)
        R_IDLE: if (i_tx_en) tx_phase <= SNH;
        SNH: begin
          if (i_fdi_active) tx_phase <= SNH_FDI_ACTIVE;
        end
        SNH_FDI_ACTIVE: begin
          if (i_snh_done) tx_phase <= NORMAL_EXCHANGE;
          else if (i_snh_timeout) tx_phase <= R_IDLE;
        end
        NORMAL_EXCHANGE: begin
        end
      endcase
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      next_tx_flit_seq_num <= 'b1;
      replay_timeout_flit_count <= 'b0;
      consecutive_tx_nak_flits <= 'b0;
      consecutive_tx_explicit_seq_num <= 'b0;

      o_tx_replay_command <= explicit;
      o_tx_seq_num <= 'b0;
      o_pl_trdy_control <= 1'b0;
      o_replay_in_progress <= 1'b0;
      o_log_cie <= 1'b0;
      o_rdi_retrain <= 1'b0;
    end else if (!init || !i_tx_en) begin
      next_tx_flit_seq_num <= 8'b1;
      replay_timeout_flit_count <= 9'b0;
      consecutive_tx_nak_flits <= 'b0;
      consecutive_tx_explicit_seq_num <= 'b0;

      o_tx_replay_command <= explicit;
      o_tx_seq_num <= 'b0;
      o_pl_trdy_control <= 1'b0;
      o_replay_in_progress <= 1'b0;
      o_log_cie <= 1'b0;
      o_rdi_retrain <= 1'b0;
    end else if (i_flit_valid) begin
      flit_replay_num <= i_flit_replay_num;
      if (next_tx_flit_seq_num == 8'hff) next_tx_flit_seq_num <= 8'b1;
      case (tx_phase)
        R_IDLE: begin
          IDLE_CASE();
          if (i_tx_en) SNH_CASE();

        end
        SNH: begin
          SNH_CASE();
          if (i_fdi_active) begin
            SNH_FDI_ACTIVE_CASE();
          end
        end
        SNH_FDI_ACTIVE: begin
          SNH_FDI_ACTIVE_CASE();
          if (i_snh_done) NORMAL_EXCHANGE_CASE();
          else if (i_snh_timeout) IDLE_CASE();
        end
        NORMAL_EXCHANGE: begin
          NORMAL_EXCHANGE_CASE();
        end
      endcase
    end
  end

  task IDLE_CASE();
    next_tx_flit_seq_num <= 8'b1;
    replay_timeout_flit_count <= 9'b0;
    consecutive_tx_nak_flits <= 'b0;
    consecutive_tx_explicit_seq_num <= 'b0;
    o_tx_replay_command <= explicit;
    o_tx_seq_num <= 'b0;
    o_pl_trdy_control <= 1'b1;
    o_replay_in_progress <= 1'b0;
    o_log_cie <= 1'b0;
    o_rdi_retrain <= 1'b0;
  endtask

  task SNH_CASE();
    o_tx_replay_command <= explicit;
    o_tx_seq_num <= 8'hFF;
    o_pl_trdy_control <= 1'b1;
    consecutive_tx_explicit_seq_num <= consecutive_tx_explicit_seq_num + 1;
  endtask

  task SNH_FDI_ACTIVE_CASE();
    o_pl_trdy_control <= 1'b0;
    if (((next_tx_flit_seq_num - i_ackd_flit_seq_num) % 8'hFF) > MAX_UNACKNOWLEDGED_FLITS)
      o_pl_trdy_control <= 1'b1;

    if (!i_replay_scheduled) begin
      if (consecutive_tx_explicit_seq_num < 1) begin
        o_tx_replay_command <= explicit;
        consecutive_tx_explicit_seq_num <= consecutive_tx_explicit_seq_num + 1;
        if (i_buffer_state != empty) replay_timeout_flit_count <= replay_timeout_flit_count + 1;
        if (tx_flit_type == NOP) begin
          o_tx_seq_num <= next_tx_flit_seq_num;
        end else begin
          o_tx_seq_num <= next_tx_flit_seq_num;
          next_tx_flit_seq_num <= next_tx_flit_seq_num + 1;
        end
      end else if (i_nak_scheduled && i_nak_schedule_type == standard_nak) begin
        o_tx_replay_command <= nak;
        o_tx_seq_num <= i_tx_acknak_flit_seq_num;
        consecutive_tx_explicit_seq_num <= 'b0;
        if (tx_flit_type != NOP) begin
          next_tx_flit_seq_num <= next_tx_flit_seq_num + 1;
        end
      end else begin
        o_tx_replay_command <= ack;
        o_tx_seq_num <= i_tx_acknak_flit_seq_num;
        consecutive_tx_explicit_seq_num <= 'b0;
        if (tx_flit_type != NOP) begin
          next_tx_flit_seq_num <= next_tx_flit_seq_num + 1;
        end
      end
    end else begin  // -- REPLAY PATH -- 
      if (consecutive_tx_explicit_seq_num < 1) begin
        flit_replay_transmit_0();
      end else if (o_replay_in_progress) begin
        o_tx_seq_num <= o_tx_seq_num + 1;
        if (o_tx_seq_num == next_tx_flit_seq_num - 1) begin
          o_replay_in_progress <= 1'b0;
          o_pl_trdy_control <= 1'b0;
        end
      end
    end
    flit_replay_transmit_2();
  endtask

  task NORMAL_EXCHANGE_CASE();
    if (normal_exchange_explicit_condition()) begin
      o_tx_replay_command <= explicit;
      consecutive_tx_nak_flits <= 'b0;
      // -- REPLAY PATH -- 
      if (i_replay_scheduled && i_replay_scheduled_type == standard_replay) begin
        flit_replay_transmit_0();
      end else if (o_replay_in_progress) begin
        o_tx_seq_num <= o_tx_seq_num + 1;
        if (o_tx_seq_num == next_tx_flit_seq_num - 1) begin
          o_replay_in_progress <= 1'b0;
          o_pl_trdy_control <= 1'b0;
        end
      end else begin
        // -- NORMAL PATH -- 
        consecutive_tx_explicit_seq_num <= consecutive_tx_explicit_seq_num + 1;
        if (i_buffer_state != empty) replay_timeout_flit_count <= replay_timeout_flit_count + 1;
        if (((next_tx_flit_seq_num - i_ackd_flit_seq_num) % 8'hFF) > MAX_UNACKNOWLEDGED_FLITS)
          o_pl_trdy_control <= 1'b1;
        else o_pl_trdy_control <= 1'b0;

        if (tx_flit_type == NOP) begin
          o_tx_seq_num <= next_tx_flit_seq_num;
        end else begin
          o_tx_seq_num <= next_tx_flit_seq_num;
          next_tx_flit_seq_num <= next_tx_flit_seq_num + 1;
        end
      end
    end else if ((i_nak_scheduled && i_nak_schedule_type == standard_nak)) begin
      o_tx_replay_command <= nak;
      o_tx_seq_num <= i_tx_acknak_flit_seq_num;
      consecutive_tx_nak_flits <= consecutive_tx_nak_flits + 1;
      consecutive_tx_explicit_seq_num <= 0;
      if (tx_flit_type != NOP) begin
        next_tx_flit_seq_num <= next_tx_flit_seq_num + 1;
      end
    end else begin
      o_tx_replay_command <= ack;
      o_tx_seq_num <= i_tx_acknak_flit_seq_num;
      consecutive_tx_nak_flits <= 'b0;
      consecutive_tx_explicit_seq_num <= 0;
      if (tx_flit_type != NOP) begin
        next_tx_flit_seq_num <= next_tx_flit_seq_num + 1;
      end
    end
    // Check for excessive replays -- triggers retrain
    flit_replay_transmit_2();
  endtask

  function automatic logic normal_exchange_explicit_condition();
    logic cond_A, cond_B, cond_C, cond_D;
    cond_A = (!i_replay_scheduled)       &&   
             (!o_replay_in_progress)     &&   
             (i_nak_ignore_flit_seq_num != 8'h00);
    cond_B = i_replay_scheduled || o_replay_in_progress || cond_A;
    cond_C = (consecutive_tx_explicit_seq_num < 1);
    cond_D = ((consecutive_tx_nak_flits == 0) || (consecutive_tx_nak_flits > 2));

    return (cond_B && cond_C && cond_D);
  endfunction

  task automatic flit_replay_transmit_0();
    if (flit_replay_num < 3'b110) begin
      if(i_replay_scheduled && !o_replay_in_progress 
            && i_replay_scheduled_type == standard_replay) begin
        if((consecutive_tx_nak_flits >= 2 || consecutive_tx_nak_flits == 0) 
                && i_data_rate == GTs_32) begin
          o_pl_trdy_control <= 1'b1;  //deassert pl_trdy
          o_replay_in_progress <= 1'b1;
          o_tx_seq_num <= i_tx_replay_flit_seq_num;
          flit_replay_num <= flit_replay_num + 2;
          if (i_consecutive_reset) begin
            consecutive_tx_explicit_seq_num <= 3'b0;
            consecutive_tx_nak_flits <= 3'b0;
            replay_timeout_flit_count <= 9'b0;
          end
        end
      end
    end
  endtask

  task automatic flit_replay_transmit_2();
    if (i_replay_scheduled && !o_replay_in_progress) begin
      if (i_data_rate <= GTs_32 && flit_replay_num >= 3'b110) begin
        flit_replay_num <= flit_replay_num + 2;
        o_rdi_retrain <= 1'b1;
        o_log_cie <= 1'b1;
      end
    end
  endtask

endmodule
