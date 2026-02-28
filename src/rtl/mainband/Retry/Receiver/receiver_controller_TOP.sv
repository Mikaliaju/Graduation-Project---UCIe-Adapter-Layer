//Author : Fatma Fawzy
//Module Description : receiver controller TOP
//Date : 28/2/2026
import common_pkg::*;
module receiver_controller_TOP (
    input  logic [7:0] i_SEQ_NUM, // Sequence number of the received flit
    input  logic       i_CRC_ERROR, // CRC error in the received flit from Mainband Receiver
    input  replay_command_t i_REPLAY_COMMAND, // ACK OR NAK OR EXPLICIT
    input  logic       i_NOP_PAYLOAD_FLIT, // 1 : NOP, 0 : Payload
    input  phase_t     i_phase, // Phase of the link
    input  logic       i_enable, //enable
    input  logic       init, //software reset
    input  logic [7:0] i_ACKD_FLIT_SEQ_NUM, // ACKD flit from counter tracker (old)
    input  logic [7:0] i_TX_ACKNAK_FLIT_SEQ_NUM, // TX ACKNAK flit from counter tracker (old)
    input  logic [7:0] i_NEXT_EXPECT_RX_FLIT_SEQ_NUM, //next expect RX flit to counter tracker
    input  logic       clk, rst_n,
    output logic [7:0] o_IMPLICIT_RX_FLIT_SEQ_NUM, //implicit sequence number (new)
    output logic       o_log_UIE, //log Uncorrectable Internal Error in Register file
    output logic       o_discard_flit, //discard flit
    output logic       o_discard_payload, //discard payload
    output logic       o_NAK_SCHEDULED, //NAK scheduled
    output logic       o_NAK_SCHEDULE_TYPE, //NAK schedule type
    output logic [7:0] o_TX_ACKNAK_FLIT_SEQ_NUM, //TX ACKNAK flit to counter tracker
    output logic [7:0] o_NEXT_EXPECT_RX_FLIT_SEQ_NUM, //next expect RX flit to counter tracker
    output logic       o_valid_ack_nak, //valid ack/nak
    output logic [7:0] o_N //sequence number of the received valid ack/nak flit  
);

    logic w_log_UIE_a, w_log_UIE_b;
    assign o_log_UIE = w_log_UIE_a | w_log_UIE_b;

    implicit_rx_rules u_implicit_rx_rules (
        .i_SEQ_NUM(i_SEQ_NUM),
        .i_CRC_ERROR(i_CRC_ERROR),
        .i_REPLAY_COMMAND(i_REPLAY_COMMAND),
        .i_NOP_PAYLOAD_FLIT(i_NOP_PAYLOAD_FLIT),
        .i_enable(i_enable),
        .clk(clk),
        .rst_n(rst_n),
        .o_IMPLICIT_RX_FLIT_SEQ_NUM(o_IMPLICIT_RX_FLIT_SEQ_NUM)
    );

    ack_nak_proccessing u_ack_nak_proccessing (
        .i_REPLAY_COMMAND(i_REPLAY_COMMAND),
        .i_SEQ_NUM(i_SEQ_NUM),
        .i_TX_ACKNAK_FLIT_SEQ_NUM(i_TX_ACKNAK_FLIT_SEQ_NUM),
        .i_ACKD_FLIT_SEQ_NUM(i_ACKD_FLIT_SEQ_NUM),
        .i_enable(i_enable),
        .clk(clk),
        .rst_n(rst_n),
        .o_valid_ack_nak(o_valid_ack_nak),
        .o_log_UIE(w_log_UIE_a),
        .o_N(o_N)
    );

    ack_nak_discard_rules u_ack_nak_discard_rules (
        .i_CRC_ERROR(i_CRC_ERROR),
        .i_phase(i_phase),
        .i_NOP_PAYLOAD_FLIT(i_NOP_PAYLOAD_FLIT),
        .i_REPLAY_COMMAND(i_REPLAY_COMMAND),
        .i_SEQ_NUM(i_SEQ_NUM),
        .i_IMPLICIT_RX_FLIT_SEQ_NUM(o_IMPLICIT_RX_FLIT_SEQ_NUM),
        .i_NEXT_EXPECT_RX_FLIT_SEQ_NUM(i_NEXT_EXPECT_RX_FLIT_SEQ_NUM),
        .i_TX_ACKNAK_FLIT_SEQ_NUM(i_TX_ACKNAK_FLIT_SEQ_NUM),
        .i_enable(i_enable),
        .clk(clk),
        .rst_n(rst_n),
        .o_log_UIE(w_log_UIE_b),
        .o_discard_flit(o_discard_flit),
        .o_discard_payload(o_discard_payload),
        .o_NAK_SCHEDULED(o_NAK_SCHEDULED),
        .o_NAK_SCHEDULE_TYPE(o_NAK_SCHEDULE_TYPE),
        .o_TX_ACKNAK_FLIT_SEQ_NUM(o_TX_ACKNAK_FLIT_SEQ_NUM),
        .o_NEXT_EXPECT_RX_FLIT_SEQ_NUM(o_NEXT_EXPECT_RX_FLIT_SEQ_NUM)
    );

endmodule