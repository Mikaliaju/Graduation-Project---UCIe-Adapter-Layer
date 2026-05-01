// Author      : Fatma Fawzy
// Module      : retry_top
// Description : Top-level retry mechanism - UCIe 256B flit format
//               Instantiates and connects:
//                 1. implicit_rx_rules
//                 2. ack_nak_discard_rules
//                 3. ack_nak_processing
//                 4. replay_schedule
//                 5. buffer
//                 6. transmitting_rules (transmittingorder)
//                 7. snh_condition_checker

import common_pkg::*;

module retry_top (
    // -------------------------------------------------------------------------
    // Global
    // -------------------------------------------------------------------------
    input logic clk,
    input logic rst_n,
    input logic init,  // software reset
    // -------------------------------------------------------------------------
    // System Ports
    // -------------------------------------------------------------------------
    input logic fdi_active,
    input logic tx_en,
    input logic rx_en,
    // -------------------------------------------------------------------------
    // RX ports from mainband receiver
    // -------------------------------------------------------------------------
    input logic                 rx_crc_error,
    input logic          [7:0]  rx_seq_num,
    input replay_command_t      rx_replay_command,
    input flit_type_t           rx_flit_type,
    // -------------------------------------------------------------------------
    // TX buffer ports 
    // -------------------------------------------------------------------------
    input logic [DATAWIDTH-1:0] tx_i_data,
    input logic [STREAMWIDTH-1:0] tx_i_stream,
    output logic [DATAWIDTH-1:0] tx_o_data,
    output logic [STREAMWIDTH-1:0] tx_o_stream,
    // -------------------------------------------------------------------------
    // Outputs to transmitter
    // -------------------------------------------------------------------------
    output logic                              pl_trdy_control,
    output replay_command_t                   tx_replay_command,
    output flit_type_t                        tx_flit_type,
    output logic          [            7:0]   tx_seq_num,
    // -------------------------------------------------------------------------
    // Outputs to error/status handling
    // -------------------------------------------------------------------------
    output logic discard_flit,
    output logic discard_payload,
    output logic log_uie,
    output logic log_cie,
    output logic rdi_retrain
);

  // =========================================================================
  // Internal wires
  // =========================================================================
  logic [7:0] o_implicit_rx_flit_seq_num;
  logic log_cie_a, log_cie_b, log_cie_c;
  logic log_uie_a, log_uie_b;

  logic nak_scheduled;
  logic nak_scheduled_type;
  logic start_replay;
  logic replay_in_progress;
  logic consecutive_reset;
  logic replay_scheduled;
  logic replay_scheduled_type;
  logic start_buffer_replay_mode;
  logic snh_done;
  logic snh_timeout;
  
  //  counters signals 
  logic [7:0] tx_acknak_flit_seq_num; 
  logic [7:0] next_expect_rx_flit_seq_num; 
  logic [7:0] ackd_flit_seq_num; 
  logic 

  // =========================================================================
  // 1. implicit_rx_rules
  // =========================================================================
  implicit_rx_rules u_implicit_rx_rules (
      .clk                   (clk),
      .rst_n                 (rst_n),
      .init                  (init),
      .i_rx_seq_num          (rx_seq_num),
      .i_rx_crc_error        (rx_crc_error),
      .i_rx_replay_command   (rx_replay_command),
      .i_flit_type           (rx_flit_type),
      .o_implicit_rx_flit_seq_num(o_implicit_rx_flit_seq_num)
  );

  // =========================================================================
  // 2. ack_nak_discard_rules
  // =========================================================================
  ack_nak_discard_rules u_ack_nak_discard_rules (
      .clk                    (clk),
      .rst_n                  (rst_n),
      .init                   (init),
      .i_rx_crc_error         (rx_crc_error),
      .i_rx_flit_type         (rx_flit_type),
      .i_rx_replay_command    (rx_replay_command),
      .i_rx_seq_num           (rx_seq_num),
      .i_snh_done             (snh_done),
      .i_snh_timeout          (snh_timeout),
      .i_implicit_rx_flit_seq_num (o_implicit_rx_flit_seq_num),
      .i_next_expect_rx_flit_seq_num (),
      .i_tx_acknak_flit_seq_num (),
      .o_log_uie              (log_uie_a),
      .o_discard_flit         (discard_flit),
      .o_discard_payload        (discard_payload),
      .o_nak_scheduled          (nak_scheduled),
      .o_nak_schedule_type       (nak_scheduled_type),
      .o_tx_acknak_flit_seq_num     (),
      .o_next_expect_rx_flit_seq_num()
  );

  // =========================================================================
  // 3. ack_nak_processing
  // =========================================================================
  ack_nak_processing u_ack_nak_processing (
      .clk                    (clk),
      .rst_n                  (rst_n),
      .init                   (init),
      .i_rx_replay_command      (rx_replay_command),
      .i_rx_seq_num             (rx_seq_num),
      .i_rx_crc_error           (rx_crc_error),
      .i_tx_acknak_flit_seq_num (),
      .i_next_tx_flit_seq_num   (),
      .i_ackd_flit_seq_num      (),
      .i_tx_replay_flit_seq_num (),
      .o_flit_replay_num        (),
      .o_ackd_flit_seq_num      (),
      .o_tx_replay_flit_seq_num (),
      .o_nak_ignore_flit_seq_num(),
      .o_start_replay           (start_replay),
      .o_log_uie                (log_uie_b)
  );

  // =========================================================================
  // 4. replay_schedule
  // =========================================================================
  replay_schedule u_replay_schedule (
      .clk                    (clk),
      .rst_n                  (rst_n),
      .init                   (init),
      .i_replay_in_progress   (replay_in_progress),
      .i_start_replay         (start_replay),
      .i_received_valid_seq_num(),
      .i_ackd_flit_seq_num    (),
      .i_next_tx_flit_seq_num (),
      .i_nak_ignore_flit_seq_num (),
      .i_replay_timeout_flit_count(),
      .o_tx_replay_flit_seq_num (),
      .o_nak_ignore_flit_seq_num (),
      .o_consecutive_reset    (consecutive_reset),
      .o_log_cie              (log_cie_a),
      .o_replay_scheduled     (replay_scheduled),
      .o_replay_scheduled_type(replay_scheduled_type),
      .o_start_buffer_replay_mode(start_buffer_replay_mode)
  );

  // =========================================================================
  // 5. buffer
  // =========================================================================
  buffer u_buffer (
      .clk                   (clk),
      .rstn                  (rst_n),
      .init                  (init),
      .i_tx_replay_flit_seq_num(),
      .i_ackd_flit_seq_num       (),
      .i_start_buffer_replay_mode(start_buffer_replay_mode),
      .i_next_tx_flit_seq_num     (),
      .i_data                 (tx_i_data),
      .i_stream               (tx_i_stream),
      .o_data                 (tx_o_data),
      .o_stream               (tx_o_stream),
      .o_replay_finished      ()
  );

  // =========================================================================
  // 6. transmittingorder
  // =========================================================================
  transmittingorder u_transmitting_rules (
      .clk                        (clk),
      .rstn                       (rst_n),
      .init                       (init),
      .i_replay_scheduled           (replay_scheduled),
      .i_replay_scheduled_type      (replay_scheduled_type),
      .i_consecutive_tx_explicit_seq_num(),
      .i_nak_scheduled              (nak_scheduled),
      .i_nak_schedule_type           (nak_scheduled_type),
      .i_consecutive_reset              (consecutive_reset),
      .i_tx_acknak_flit_seq_num        (),
      .i_snh_done                     (snh_done),
      .i_snh_timeout                  (snh_timeout),
      .o_tx_replay_command             (tx_replay_command),
      .o_pl_trdy_control               (pl_trdy_control),
      .o_tx_flit_type             (tx_flit_type),
      .o_tx_seq_num                 (tx_seq_num),
      .o_rdi_retrain               (rdi_retrain),
      .o_replay_in_progress        (replay_in_progress),
      .o_log_cie                  (log_cie_c)
  );

  // =========================================================================
  // 7. snh_condition_checker
  // =========================================================================
  snh_condition_checker u_snh_condition_checker (
      .clk                     (clk),
      .rstn                    (rst_n),
      .init                    (init),
      .o_snh_done             (snh_done),
      .o_snh_timeout            (snh_timeout),
      .i_flit_sent              (i_flit_sent),
      .i_replay_command         (replay_command),
      .i_flit_seq_num           (flit_seq_num),
      .i_tx_acknak_flit_seq_num ()
  );

  // =========================================================================
  // Top-level output assignments
  // =========================================================================
assign log_cie = log_cie_a | log_cie_b | log_cie_c;
assign log_uie = log_uie_a | log_uie_b;`

endmodule
