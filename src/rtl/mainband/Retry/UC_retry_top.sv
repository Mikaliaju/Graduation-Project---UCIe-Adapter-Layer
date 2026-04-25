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



import common_pkg::*;

module retry_top (
    // -------------------------------------------------------------------------
    // Global
    // -------------------------------------------------------------------------
    input logic clk,
    input logic rstn,
    input logic init,  // software reset / FDI active

    // -------------------------------------------------------------------------
    // RX inputs — from mainband receiver
    // -------------------------------------------------------------------------
    input logic                rx_crc_error,
    input logic          [7:0] rx_seq_num,
    input replaycommandt       rx_replay_command,
    input flittypet            rx_flit_type,
    input logic                rx_nop_payload_flit,

    // -------------------------------------------------------------------------
    // TX inputs — from transmitter (signals internal to transmittingorder
    //             that must be exposed as output ports of that module)
    // -------------------------------------------------------------------------
    input logic [  DATAWIDTH-1:0] tx_idata,
    input logic [STREAMWIDTH-1:0] tx_istream,
    input logic [            7:0] tx_nexttxflitseqnum,
    input logic                   tx_replay_inprogress,
    input logic [            8:0] tx_replay_timeout_count,
    input logic [            1:0] tx_consec_explicit_seqnum,

    // -------------------------------------------------------------------------
    // Outputs to transmitter
    // -------------------------------------------------------------------------
    output replaycommandt                   tx_replay_command_out,
    output logic                            pl_trdy_control,
    output logic                            tx_nop_payload_flit,
    output logic          [            7:0] tx_seq_num,
    output logic          [  DATAWIDTH-1:0] tx_odata,
    output logic          [STREAMWIDTH-1:0] tx_ostream,
    output logic                            tx_replay_finished,

    // -------------------------------------------------------------------------
    // Outputs to error/status handling
    // -------------------------------------------------------------------------
    output logic discard_flit,
    output logic discard_payload,
    output logic log_uie,
    output logic log_ce,
    output logic rdi_retrain
);

  // =========================================================================
  // Internal wires — named exactly as the driving module's output port
  // =========================================================================

  // implicit_rx_rules outputs
  logic               [7:0] oimplicitrxflitseqnum;

  // ack_nak_discard_rules outputs
  logic                     discard_ologuie;
  logic                     discard_odiscardflit;
  logic                     discard_odiscardpayload;
  logic                     discard_onakscheduled;
  logic                     discard_onakscheduletype;
  logic               [7:0] discard_otxacknakflitseqnum;
  logic               [7:0] discard_onextexpectrxflitseqnum;

  // ack_nak_processing outputs
  logic               [2:0] proc_oflitreplaynum;
  logic               [7:0] proc_oackdflitseqnum;
  logic               [7:0] proc_otxreplayflitseqnum;
  logic               [7:0] proc_onakignoreflitseqnum;
  logic                     proc_ostartreplay;
  logic                     proc_ologuie;

  // replay_schedule outputs
  logic               [7:0] rs_otxreplayflitseqnum;
  logic               [7:0] rs_onakignoreflitseqnum;
  logic                     rs_oconsecutivereset;
  logic                     rs_ologcie;
  logic                     rs_oreplayscheduled;
  replayscheduletypet       rs_oreplayscheduledtype;
  logic                     rs_ostartbufferreplaymode;

  // =========================================================================
  // 1. implicit_rx_rules
  //    → oimplicitrxflitseqnum feeds ack_nak_discard_rules
  // =========================================================================
  implicitrxrules u_implicit_rx_rules (
      .clk                  (clk),
      .rstn                 (rstn),
      .init                 (init),
      .iseqnum              (rx_seq_num),
      .icrcerror            (rx_crc_error),
      .ireplaycommand       (rx_replay_command),
      .inoppayloadflit      (rx_nop_payload_flit),
      .oimplicitrxflitseqnum(oimplicitrxflitseqnum)
  );

  // =========================================================================
  // 2. ack_nak_discard_rules
  //    ← oimplicitrxflitseqnum from block 1
  //    ← inextexpectrxflitseqnum / itxacknakflitseqnum fed back (self-owned)
  //    → discard_onakscheduled / discard_otxacknakflitseqnum → transmitter
  //    → discard_odiscardflit / discard_odiscardpayload → top outputs
  // =========================================================================
  acknakdiscardrules u_ack_nak_discard_rules (
      .clk                    (clk),
      .rstn                   (rstn),
      .init                   (init),
      .icrcerror              (rx_crc_error),
      .iphase                 (phase),
      .iflittype              (rx_flit_type),
      .ireplaycommand         (rx_replay_command),
      .iseqnum                (rx_seq_num),
      .iimplicitrxflitseqnum  (oimplicitrxflitseqnum),
      .inextexpectrxflitseqnum(discard_onextexpectrxflitseqnum),
      .itxacknakflitseqnum    (discard_otxacknakflitseqnum),
      .ologuie                (discard_ologuie),
      .odiscardflit           (discard_odiscardflit),
      .odiscardpayload        (discard_odiscardpayload),
      .onakscheduled          (discard_onakscheduled),
      .onakscheduletype       (discard_onakscheduletype),
      .otxacknakflitseqnum    (discard_otxacknakflitseqnum),
      .onextexpectrxflitseqnum(discard_onextexpectrxflitseqnum)
  );

  // =========================================================================
  // 3. ack_nak_processing
  //    ← discard_otxacknakflitseqnum from block 2
  //    ← tx_nexttxflitseqnum from transmitter
  //    ← iackdflitseqnum / itxreplayflitseqnum / inakignoreflitseqnum (self-owned)
  //    → proc_ostartreplay pulse → replay_schedule
  //    → proc_oackdflitseqnum   → replay_schedule + buffer (purge floor)
  //    → proc_onakignoreflitseqnum → replay_schedule
  // =========================================================================
  acknakprocessing u_ack_nak_processing (
      .clk                 (clk),
      .rstn                (rstn),
      .init                (init),
      .ireplaycommand      (rx_replay_command),
      .iseqnum             (rx_seq_num),
      .icrcerror           (rx_crc_error),
      .itxacknakflitseqnum (discard_otxacknakflitseqnum),
      .inexttxflitseqnum   (tx_nexttxflitseqnum),
      .iackdflitseqnum     (proc_oackdflitseqnum),
      .itxreplayflitseqnum (proc_otxreplayflitseqnum),
      .inakignoreflitseqnum(proc_onakignoreflitseqnum),
      .oflitreplaynum      (proc_oflitreplaynum),
      .oackdflitseqnum     (proc_oackdflitseqnum),
      .otxreplayflitseqnum (proc_otxreplayflitseqnum),
      .onakignoreflitseqnum(proc_onakignoreflitseqnum),
      .ostartreplay        (proc_ostartreplay),
      .ologuie             (proc_ologuie)
  );

  // =========================================================================
  // 4. replay_schedule
  //    ← proc_ostartreplay          — NAK-triggered replay pulse from block 3
  //    ← proc_oackdflitseqnum       — ACKDFLITSEQNUM (Rule 0 ptr + Rule 1 N)
  //    ← proc_onakignoreflitseqnum  — NAK ignore window from block 3
  //    ← tx_nexttxflitseqnum        — from transmitter
  //    ← tx_replay_inprogress       — REPLAYINPROGRESS from transmitter
  //    ← tx_replay_timeout_count    — REPLAYTIMEOUTFLITCOUNT from transmitter
  //    → rs_oreplayscheduled         → transmitter
  //    → rs_otxreplayflitseqnum      → buffer (replay start address)
  //    → rs_ostartbufferreplaymode   → buffer (begin replay read-out)
  //    → rs_oconsecutivereset        → transmitter (clears consecutive counters)
  //    → rs_ologcie                  → log_ce
  // =========================================================================
  replayschedule u_replay_schedule (
      .clk                    (clk),
      .rstn                   (rstn),
      .init                   (init),
      .ireplayinprogress      (tx_replay_inprogress),
      .istartreplay           (proc_ostartreplay),
      .ireceivedvalidseqnum   (proc_oackdflitseqnum),
      .iackdflitseqnum        (proc_oackdflitseqnum),
      .inexttxflitseqnum      (tx_nexttxflitseqnum),
      .inakignoreflitseqnum   (proc_onakignoreflitseqnum),
      .ireplaytimeoutflitcount(tx_replay_timeout_count),
      .otxreplayflitseqnum    (rs_otxreplayflitseqnum),
      .onakignoreflitseqnum   (rs_onakignoreflitseqnum),
      .oconsecutivereset      (rs_oconsecutivereset),
      .ologcie                (rs_ologcie),
      .oreplayscheduled       (rs_oreplayscheduled),
      .oreplayscheduledtype   (rs_oreplayscheduledtype),
      .ostartbufferreplaymode (rs_ostartbufferreplaymode)
  );

  // =========================================================================
  // 5. buffer
  //    ← tx_idata / tx_istream       — new flit chunks from transmitter
  //    ← tx_nexttxflitseqnum         — write address (which flit slot to write)
  //    ← proc_oackdflitseqnum        — ACKDFLITSEQNUM (purge floor)
  //    ← rs_otxreplayflitseqnum      — replay start address from block 4
  //    ← rs_ostartbufferreplaymode   — begin replay pulse from block 4
  //    → tx_odata / tx_ostream       — replayed flit data to transmitter
  //    → tx_replay_finished          — all replay flits sent
  // =========================================================================
  buffer u_buffer (
      .clk                   (clk),
      .rstn                  (rstn),
      .init                  (init),
      .itxreplayflitseqnum   (rs_otxreplayflitseqnum),
      .iackdflitseqnum       (proc_oackdflitseqnum),
      .istartbufferreplaymode(rs_ostartbufferreplaymode),
      .inexttxflitseqnum     (tx_nexttxflitseqnum),
      .idata                 (tx_idata),
      .istream               (tx_istream),
      .odata                 (tx_odata),
      .ostream               (tx_ostream),
      .oreplayedfinished     (tx_replay_finished)
  );

  // =========================================================================
  // 6. transmittingorder
  //    ← rs_oreplayscheduled         — REPLAYSCHEDULED from block 4
  //    ← tx_consec_explicit_seqnum   — CONSECUTIVETXEXPLICITSEQNUMFLITS
  //    ← discard_onakscheduled       — NAKSCHEDULED from block 2
  //    ← discard_onakscheduletype    — NAKSCHEDULEDTYPE from block 2
  //    ← discard_otxacknakflitseqnum — TXACKNAKFLITSEQNUM from block 2
  //    → tx_replay_command_out / tx_seq_num / pl_trdy_control / tx_nop_payload_flit
  //
  //    NOTE: the following signals are currently internal to transmittingorder
  //    and must be added as output ports before full integration:
  //      - NEXTTXFLITSEQNUM       → tx_nexttxflitseqnum (top input today)
  //      - REPLAYINPROGRESS       → tx_replay_inprogress
  //      - REPLAYTIMEOUTFLITCOUNT → tx_replay_timeout_count
  //      - CONSECUTIVETXEXPLICITSEQNUMFLITS → tx_consec_explicit_seqnum
  //      - ordiretrainrequest     → rdi_retrain
  // =========================================================================
  transmittingorder u_transmitting_rules (
      .clk                        (clk),
      .rstn                       (rstn),
      .phase                      (phase),
      .init                       (init),
      .ireplayscheduled           (rs_oreplayscheduled),
      .consecutivetxexplicitseqnum(tx_consec_explicit_seqnum),
      .inakscheduled              (discard_onakscheduled),
      .inakscheduletype           (nakscheduletypet'(discard_onakscheduletype)),
      .itxacknakflitseqnum        (discard_otxacknakflitseqnum),
      .oreplaycommand             (tx_replay_command_out),
      .opltrdycontrol             (pl_trdy_control),
      .onoppayloadflit            (tx_nop_payload_flit),
      .oflitseqnum                (tx_seq_num)
  );

  // =========================================================================
  // Top-level output assignments
  // =========================================================================
  assign discard_flit    = discard_odiscardflit;
  assign discard_payload = discard_odiscardpayload;
  assign log_uie         = discard_ologuie | proc_ologuie;
  assign log_ce          = rs_ologcie;
  // rdi_retrain to be connected once ordiretrainrequest added to transmittingorder
  assign rdi_retrain     = 1'b0;

endmodule
