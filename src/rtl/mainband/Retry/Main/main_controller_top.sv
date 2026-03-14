//author : fatma fawzy
//module description : main controller top
//date : 14/3/2026

import common_pkg::*;

module main_controller_top (
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    init,                        // software reset
    input  logic                    i_valid,                     // works as enable for the system
    input  logic                    i_valid_ack_nak,             // valid ack/nak flag
    input  logic [7:0]              i_received_valid_seq_num,    // sequence number of the received valid ack/nak flit
    input  logic [7:0]              i_ackd_flit_seq_num,         // ackd flit sequence number
    input  logic [7:0]              i_next_tx_flit_seq_num,      // next tx flit sequence number
    input  logic                    i_replay_in_progress,        // replay in progress flag
    input  logic [7:0]              i_replay_timeout_flit_count, // replay timeout flit count
    input  logic [7:0]              i_nak_ignore_flit_seq_num,   // nak ignore flit sequence number
    input  logic [7:0]              i_tx_replay_flit_seq_num,    // tx replay flit sequence number
    input  logic                    i_start_buffer_replay_mode,  // start buffer replay mode
    input  logic                    i_replay_scheduled,          // replay scheduled flag
    input  logic [2:0]              i_flit_replay_num,           // flit replay count
    input  data_rate_t              data_rate,                   // data rate
    input  logic [DATA_WIDTH-1:0]   i_data,                      // data to write into buffer
    input  logic [STREAM_WIDTH-1:0] i_stream,                    // stream to write into buffer
    output logic [DATA_WIDTH-1:0]   o_data,                      // replayed data from buffer
    output logic [STREAM_WIDTH-1:0] o_stream,                    // replayed stream from buffer
    output logic                    o_replayed_finished,         // replay finished flag
    output logic                    o_consecutive_reset,         // consecutive replay reset
    output logic                    o_log_cie,                   // log correctable internal error
    output logic                    o_replay_scheduled,          // replay scheduled flag
    output replay_schedule_type_t   o_replay_scheduled_type,     // type of scheduled replay
    output logic [2:0]              o_flit_replay_num,           // flit replay count
    output logic                    o_rdi_retrain_request,       // RDI retrain request
    output logic [7:0]              o_nak_ignore_flit_seq_num_vp,// nak ignore flit sequence number (from VP)
    output logic [7:0]              o_nak_ignore_flit_seq_num_rs,// nak ignore flit sequence number (from RS)
    output logic [7:0]              o_ackd_flit_seq_num,         // ackd flit sequence number
    output logic [7:0]              o_tx_replay_flit_seq_num_vp, // tx replay flit sequence number (from VP)
    output logic [7:0]              o_tx_replay_flit_seq_num_rs, // tx replay flit sequence number (from RS)
    output logic                    o_start_buffer_replay_mode   // start buffer replay mode
);

    logic w_log_cie_a, w_log_cie_b;
    logic w_start_replay;

    assign o_log_cie = w_log_cie_a | w_log_cie_b;

    valid_ack_nak_processing u_valid_ack_nak_processing (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .init                     (init),
        .i_valid                  (i_valid),
        .i_valid_ack_nak          (i_valid_ack_nak),
        .i_n                      (i_received_valid_seq_num),
        .i_ackd_flit_seq_num      (i_ackd_flit_seq_num),
        .i_tx_replay_flit_seq_num (i_tx_replay_flit_seq_num),
        .i_next_tx_flit_seq_num   (i_next_tx_flit_seq_num),
        .i_nak_ignore_flit_seq_num(i_nak_ignore_flit_seq_num),
        .o_flit_replay_num        (o_flit_replay_num),
        .o_ackd_flit_seq_num      (o_ackd_flit_seq_num),
        .o_tx_replay_flit_seq_num (o_tx_replay_flit_seq_num_vp),
        .o_nak_ignore_flit_seq_num(o_nak_ignore_flit_seq_num_vp),
        .o_start_replay           (w_start_replay)
    );

    replay_schedule u_replay_schedule (
        .clk                        (clk),
        .rst_n                      (rst_n),
        .init                       (init),
        .i_replay_in_progress       (i_replay_in_progress),
        .i_start_replay             (w_start_replay),
        .i_received_valid_seq_num   (i_received_valid_seq_num),
        .i_ackd_flit_seq_num        (i_ackd_flit_seq_num),
        .i_next_tx_flit_seq_num     (i_next_tx_flit_seq_num),
        .i_nak_ignore_flit_seq_num  (i_nak_ignore_flit_seq_num),
        .i_replay_timeout_flit_count(i_replay_timeout_flit_count),
        .o_tx_replay_flit_seq_num   (o_tx_replay_flit_seq_num_rs),
        .o_nak_ignore_flit_seq_num  (o_nak_ignore_flit_seq_num_rs),
        .o_consecutive_reset        (o_consecutive_reset),
        .o_log_cie                  (w_log_cie_a),
        .o_replay_scheduled         (o_replay_scheduled),
        .o_replay_scheduled_type    (o_replay_scheduled_type),
        .o_start_buffer_replay_mode (o_start_buffer_replay_mode)
    );

    buffer u_buffer (
        .clk                       (clk),
        .rst_n                     (rst_n),
        .init                      (init),
        .i_tx_replay_flit_seq_num  (i_tx_replay_flit_seq_num),
        .i_ackd_flit_seq_num       (i_ackd_flit_seq_num),
        .i_start_buffer_replay_mode(i_start_buffer_replay_mode),
        .i_next_tx_flit_seq_num    (i_next_tx_flit_seq_num),
        .i_data                    (i_data),
        .i_stream                  (i_stream),
        .o_data                    (o_data),
        .o_stream                  (o_stream),
        .o_replayed_finished       (o_replayed_finished)
    );

    replay_transmit_2 u_replay_transmit_2 (
        .clk                  (clk),
        .rst_n                (rst_n),
        .init                 (init),
        .i_replay_scheduled   (i_replay_scheduled),
        .i_replay_in_progress (i_replay_in_progress),
        .data_rate            (data_rate),
        .i_flit_replay_num    (i_flit_replay_num),
        .o_flit_replay_num    (o_flit_replay_num),
        .o_rdi_retrain_request(o_rdi_retrain_request),
        .o_log_cie            (w_log_cie_b)
    );

endmodule
