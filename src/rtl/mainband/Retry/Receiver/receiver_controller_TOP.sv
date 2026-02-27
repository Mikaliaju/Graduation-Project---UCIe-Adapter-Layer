import common_pkg::*;
module receiver_controller_TOP (
    input  logic [7:0] i_SEQ_NUM,
    input  logic       i_CRC_ERROR,
    input  replay_command_t i_REPLAY_COMMAND,
    input  logic       i_NOP_PAYLOAD_FLIT,
    input  phase_t     i_phase,
    input  logic       i_enable,
    input  logic       init,
    input  logic [7:0] i_ACKD_FLIT_SEQ_NUM,
    input  logic [7:0] i_TX_ACKNAK_FLIT_SEQ_NUM,
    input  logic [7:0] i_NEXT_EXPECT_RX_FLIT_SEQ_NUM,
    input  logic       clk, rst,
    output logic [7:0] o_IMPLICIT_RX_FLIT_SEQ_NUM,
    output logic       o_log_UIE,
    output logic       o_discard_flit, 
    output logic       o_discard_payload,
    output logic       o_NAK_SCHEDULED,
    output logic       o_NAK_SCHEDULE_TYPE,
    output logic [7:0] o_TX_ACKNAK_FLIT_SEQ_NUM,
    output logic [7:0] o_NEXT_EXPECT_RX_FLIT_SEQ_NUM,
    output logic       o_valid_ack_nak,
    output logic [7:0] o_N  
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
        .rst(rst),
        .o_IMPLICIT_RX_FLIT_SEQ_NUM(o_IMPLICIT_RX_FLIT_SEQ_NUM)
    );

    ack_nak_proccessing u_ack_nak_proccessing (
        .i_REPLAY_COMMAND(i_REPLAY_COMMAND),
        .i_SEQ_NUM(i_SEQ_NUM),
        .i_TX_ACKNAK_FLIT_SEQ_NUM(i_TX_ACKNAK_FLIT_SEQ_NUM),
        .i_ACKD_FLIT_SEQ_NUM(i_ACKD_FLIT_SEQ_NUM),
        .i_enable(i_enable),
        .clk(clk),
        .rst(rst),
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
        .rst(rst),
        .o_log_UIE(w_log_UIE_b),
        .o_discard_flit(o_discard_flit),
        .o_discard_payload(o_discard_payload),
        .o_NAK_SCHEDULED(o_NAK_SCHEDULED),
        .o_NAK_SCHEDULE_TYPE(o_NAK_SCHEDULE_TYPE),
        .o_TX_ACKNAK_FLIT_SEQ_NUM(o_TX_ACKNAK_FLIT_SEQ_NUM),
        .o_NEXT_EXPECT_RX_FLIT_SEQ_NUM(o_NEXT_EXPECT_RX_FLIT_SEQ_NUM)
    );

endmodule