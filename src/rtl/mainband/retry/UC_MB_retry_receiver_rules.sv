//author : fatma fawzy
//module description : validate the received flits and schedule ack/nak flits
//date : 28/2/2026
import UC_MB_retry_pkg::*;

module UC_MB_retry_receiver_rules (
    input logic                clk,
    input logic                rst_n,
    input logic                init,  // software reset
    input logic                i_rx_crc_error,  // crc error in the received flit from mainband receiver
    input flit_type_t          i_rx_flit_type,  // 1 : payload, 0 : nop
    input replay_command_t     i_rx_replay_command,  // ack or nak or explicit
    input logic [7:0]          i_rx_seq_num,  // sequence number of the received flit
    input  logic [7:0]         i_implicit_rx_flit_seq_num,   // implicit sequence number from implicit seq number module (new)
    input logic                i_snh_done,
    input logic                i_snh_timeout,
    input logic                i_fdi_active,
    input logic                i_rx_en,
    output phase_t             o_rx_phase,
    output logic               o_log_uie,  // log uncorrectable internal error in register file
    output logic               o_discard_flit,  // discard flit
    output logic               o_discard_payload,  // discard payload
    output logic               o_nak_scheduled,  // nak scheduled
    output nak_schedule_type_t o_nak_schedule_type,  // nak schedule type
    output logic [7:0]         o_tx_acknak_flit_seq_num  // tx acknak flit to counter tracker
);

  logic                  r_rx_crc_error_d;
  logic                  r_rx_flit_type_d;
  logic            [7:0] r_rx_seq_num_d;
  replay_command_t       r_rx_replay_command_d;

  logic            [7:0] next_expect_rx_flit_seq_num;
  logic            [7:0] tx_acknak_flit_seq_num;

  phase_t                rx_phase;
  assign o_rx_phase    = rx_phase;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_phase <= R_IDLE;
    end else if (!init || !i_rx_en) begin
      rx_phase <= R_IDLE;
    end else begin
      case (rx_phase) 
        R_IDLE : if (i_rx_en) rx_phase <= SNH;
        SNH : begin
          if (i_fdi_active) rx_phase <= SNH_FDI_ACTIVE;
        end
        SNH_FDI_ACTIVE: begin
          if (i_snh_done) rx_phase <= NORMAL_EXCHANGE;
          else if (i_snh_timeout) rx_phase <= R_IDLE;
        end
        NORMAL_EXCHANGE: begin
        end
      endcase
    end
  end

  // delay by 1 cycle to wait for implicit rx seq num to be updated
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r_rx_crc_error_d      <= 0;
      r_rx_flit_type_d      <= NOP;
      r_rx_seq_num_d        <= 0;
      r_rx_replay_command_d <= explicit;
    end else if (!init || rx_phase == R_IDLE) begin
      r_rx_crc_error_d      <= 0;
      r_rx_flit_type_d      <= NOP;
      r_rx_seq_num_d        <= 0;
      r_rx_replay_command_d <= explicit;
    end else begin
      r_rx_crc_error_d      <= i_rx_crc_error;
      r_rx_flit_type_d      <= i_rx_flit_type;
      r_rx_seq_num_d        <= i_rx_seq_num;
      r_rx_replay_command_d <= i_rx_replay_command;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      o_log_uie                   <= 1'b0;
      o_discard_flit              <= 1'b0;
      o_discard_payload           <= 1'b0;
      o_nak_scheduled             <= 1'b0;
      o_nak_schedule_type         <= standard_nak;
      tx_acknak_flit_seq_num      <= 8'b0;
      next_expect_rx_flit_seq_num <= 8'b0;
    end else if (!init || rx_phase == R_IDLE) begin
      o_log_uie                   <= 1'b0;
      o_discard_flit              <= 1'b0;
      o_discard_payload           <= 1'b0;
      o_nak_scheduled             <= 1'b0;
      o_nak_schedule_type         <= standard_nak;
      tx_acknak_flit_seq_num      <= 8'b0;
      next_expect_rx_flit_seq_num <= 8'b0;
    end else begin
      o_discard_flit    <= 1'b0;
      o_discard_payload <= 1'b0;
      o_log_uie         <= 1'b0;
      if (r_rx_crc_error_d) begin
        if (o_nak_scheduled) begin
          flit_discard_1();
        end else begin
          nak_schedule_0();
        end
      end
        else if (r_rx_replay_command_d == explicit && rx_phase == NORMAL_EXCHANGE
                 && r_rx_seq_num_d == 8'b0) begin
        flit_discard_2();
      end else begin
        if (r_rx_flit_type_d == NOP) begin
          if (bad_nop_sequence_number()) begin
            nak_schedule_2();
          end else begin
            flit_discard_0();
          end
        end else begin
          if (o_nak_scheduled) begin
            standard_nak_procedure();
          end else begin
            if (duplicate_sequence_number()) flit_discard_0();
            else if (bad_sequence_number()) nak_schedule_2();
            else ack_schedule_0();
          end
        end
      end
    end
  end

  function bad_sequence_number();
    return (next_expect_rx_flit_seq_num - i_implicit_rx_flit_seq_num) % 255 > 127;
  endfunction

  function bad_nop_sequence_number();
    return bad_sequence_number() || (i_implicit_rx_flit_seq_num == next_expect_rx_flit_seq_num);
  endfunction

  function duplicate_sequence_number();
    return ((tx_acknak_flit_seq_num - i_implicit_rx_flit_seq_num) % 255 < 127);
  endfunction

  task standard_nak_procedure();
    if (duplicate_sequence_number()) begin
      if (o_nak_scheduled) begin
        flit_discard_0();
      end else begin
        nak_schedule_2();
      end
    end
    else if ((r_rx_replay_command_d == explicit) &&
             (i_implicit_rx_flit_seq_num == next_expect_rx_flit_seq_num)) begin
      ack_schedule_1();
    end else begin
      if (o_nak_scheduled) begin
        flit_discard_0();
      end else begin
        nak_schedule_2();
      end
    end
  endtask

  task automatic ack_schedule_0();
    tx_acknak_flit_seq_num      <= next_expect_rx_flit_seq_num;
    next_expect_rx_flit_seq_num <= next_expect_rx_flit_seq_num + 1;
    o_nak_scheduled             <= 1'b0;
    o_nak_schedule_type         <= standard_nak;
  endtask

  task automatic ack_schedule_1();
    tx_acknak_flit_seq_num      <= i_implicit_rx_flit_seq_num;
    next_expect_rx_flit_seq_num <= i_implicit_rx_flit_seq_num + 1;
    o_nak_scheduled             <= 1'b0;
    o_nak_schedule_type         <= standard_nak;
  endtask

  task automatic nak_schedule_0();
    o_discard_flit              <= 1'b1;
    o_nak_scheduled             <= 1'b1;
    next_expect_rx_flit_seq_num <= next_expect_rx_flit_seq_num;
  endtask

  task automatic nak_schedule_2();
    o_discard_payload           <= 1'b1;
    tx_acknak_flit_seq_num      <= next_expect_rx_flit_seq_num - 1;
    o_nak_scheduled             <= 1'b1;
    o_nak_schedule_type         <= standard_nak;
    next_expect_rx_flit_seq_num <= next_expect_rx_flit_seq_num;
  endtask

  task automatic flit_discard_0();
    o_discard_payload           <= 1'b1;
    next_expect_rx_flit_seq_num <= next_expect_rx_flit_seq_num;
  endtask

  task automatic flit_discard_1();
    o_discard_flit              <= 1'b1;
    next_expect_rx_flit_seq_num <= next_expect_rx_flit_seq_num;
  endtask

  task automatic flit_discard_2();
    o_discard_flit              <= 1'b1;
    next_expect_rx_flit_seq_num <= next_expect_rx_flit_seq_num;
    o_log_uie                   <= 1'b1;
  endtask

  assign o_tx_acknak_flit_seq_num = tx_acknak_flit_seq_num;
endmodule
