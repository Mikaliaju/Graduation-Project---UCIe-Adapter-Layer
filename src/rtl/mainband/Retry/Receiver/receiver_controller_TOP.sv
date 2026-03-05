//author : fatma fawzy
//module description : receiver controller top
//date : 28/2/2026

import common_pkg::*;
module receiver_controller_top (
    input  logic [7:0] i_seq_num, // sequence number of the received flit
    input  logic       i_crc_error, // crc error in the received flit from mainband receiver
    input  replay_command_t i_replay_command, // ack or nak or explicit
    input  logic       i_nop_payload_flit, // 1 : nop, 0 : payload
    input  phase_t     i_phase, // phase of the link
    input  logic       i_enable, //enable
    input  logic       init, //software reset
    input  logic [7:0] i_ackd_flit_seq_num, // ackd flit from counter tracker (old)
    input  logic [7:0] i_tx_acknak_flit_seq_num, // tx acknak flit from counter tracker (old)
    input  logic [7:0] i_next_expect_rx_flit_seq_num, //next expect rx flit to counter tracker
    input  logic       clk, rst_n,
    output logic [7:0] o_implicit_rx_flit_seq_num, //implicit sequence number (new)
    output logic       o_log_uie, //log uncorrectable internal error in register file
    output logic       o_discard_flit, //discard flit
    output logic       o_discard_payload, //discard payload
    output logic       o_nak_scheduled, //nak scheduled
    output logic       o_nak_schedule_type, //nak schedule type
    output logic [7:0] o_tx_acknak_flit_seq_num, //tx acknak flit to counter tracker
    output logic [7:0] o_next_expect_rx_flit_seq_num, //next expect rx flit to counter tracker
    output logic       o_valid_ack_nak, //valid ack/nak
    output logic [7:0] o_n //sequence number of the received valid ack/nak flit  
);

    logic w_log_uie_a, w_log_uie_b;
    assign o_log_uie = w_log_uie_a | w_log_uie_b;

    implicit_rx_rules u_implicit_rx_rules (
        .i_seq_num(i_seq_num),
        .i_crc_error(i_crc_error),
        .i_replay_command(i_replay_command),
        .i_nop_payload_flit(i_nop_payload_flit),
        .i_enable(i_enable),
        .clk(clk),
        .rst_n(rst_n),
        .o_implicit_rx_flit_seq_num(o_implicit_rx_flit_seq_num)
    );

    ack_nak_proccessing u_ack_nak_proccessing (
        .i_replay_command(i_replay_command),
        .i_seq_num(i_seq_num),
        .i_tx_acknak_flit_seq_num(i_tx_acknak_flit_seq_num),
        .i_ackd_flit_seq_num(i_ackd_flit_seq_num),
        .i_enable(i_enable),
        .clk(clk),
        .rst_n(rst_n),
        .o_valid_ack_nak(o_valid_ack_nak),
        .o_log_uie(w_log_uie_a),
        .o_n(o_n)
    );

    ack_nak_discard_rules u_ack_nak_discard_rules (
        .i_crc_error(i_crc_error),
        .i_phase(i_phase),
        .i_nop_payload_flit(i_nop_payload_flit),
        .i_replay_command(i_replay_command),
        .i_seq_num(i_seq_num),
        .i_implicit_rx_flit_seq_num(o_implicit_rx_flit_seq_num),
        .i_next_expect_rx_flit_seq_num(i_next_expect_rx_flit_seq_num),
        .i_tx_acknak_flit_seq_num(i_tx_acknak_flit_seq_num),
        .i_enable(i_enable),
        .clk(clk),
        .rst_n(rst_n),
        .o_log_uie(w_log_uie_b),
        .o_discard_flit(o_discard_flit),
        .o_discard_payload(o_discard_payload),
        .o_nak_scheduled(o_nak_scheduled),
        .o_nak_schedule_type(o_nak_schedule_type),
        .o_tx_acknak_flit_seq_num(o_tx_acknak_flit_seq_num),
        .o_next_expect_rx_flit_seq_num(o_next_expect_rx_flit_seq_num)
    );

endmodule