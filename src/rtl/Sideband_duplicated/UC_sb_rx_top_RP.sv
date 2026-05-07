// ================================================================================================================================
//  FILENAME    : UC_sb_rx_top_RP.sv
//  MODULE      : UC_sb_rx_top_RP
//  PROJECT     : UCIe 3.0 Adapter Layer
//  AUTHOR      : Ashraf Sherif, Shahd Mohamed
// ================================================================================================================================
//  Description : Top-level wrapper for the SB Receiver Unit.                                                      
//                Instantiates the RX Decoder, Completions FIFO, Messages FIFO,
//                Completions Controller, and Messages Controller.
//                Requests are forwarded directly from the Decoder to the remote die
//                (EP only) — no Request FIFO.
// ================================================================================================================================ 
   import UC_sb_rx_pkg::*;

   import UC_sb_rx_pkg_RP::*; 
    module UC_sb_rx_top_RP #(
    parameter int NC                  = 32,  // Number of config bits per phase/chunk
    parameter int NUM_OF_COMP_PKTS    = 4,   // Max completion packets the completions FIFO can store
    parameter int NUM_OF_MSG_PKTS     = 2    // Max message packets the messages FIFO can store
)(
    /*------------------------------------------
      Global Signals
    ------------------------------------------*/
    input  logic              i_clk,         // Main clock (lclk)
    input  logic              i_rst_n,       // Active-low HW reset (Power-on Reset)
    input  logic              i_init_n,      // Active-low SW reset (Initialization)

    /*------------------------------------------
      RDI Interface
    ------------------------------------------*/
    input  logic [NC-1:0]     i_rdi_pl_cfg,      // RDI packet chunks from PHY
    input  logic              i_rdi_pl_cfg_vld,  // Valid indicator for RDI data

    /*------------------------------------------
      FDI Interface
    ------------------------------------------*/
    output logic [NC-1:0]     o_fdi_pl_cfg,      // FDI packet chunks to protocol layer
    output logic              o_fdi_pl_cfg_vld,  // Valid indicator for FDI data

    /*------------------------------------------
      LSM Interface
    ------------------------------------------*/
    output sb_error_msg_encoding   o_sb_err_msg_rx,      // Error messages received from the EP device (RP only)
    output sb_state_msg_encoding   o_sb_state_msg_rx,    // State messages for LSM

    /*------------------------------------------
      LSM Error Handling Interface
    ------------------------------------------*/
    output logic              o_sb_rdi_overflow,    // Combined FIFO overflow status
    output logic              o_sb_rx_parity_error, // Combined parity error status
    output logic              o_sb_rx_opid_err,     // Fatal invalid id or opcode error in sideband Rx

    /*------------------------------------------
      Credit Loop Interface
    ------------------------------------------*/
    output logic              o_rdi_crd_release,    // Credit release signal to PHY

    /*------------------------------------------
      Tag Controller Interface
    ------------------------------------------*/
    output logic              o_rx_chk_tag,         // Tag mapping request
    output logic [4:0]        o_rx_current_tag,     // Current packet tag
    input  logic [4:0]        i_rx_orig_tag,        // Original tag from protocol layer
    input  logic              i_rx_tag_notfound,    // Tag lookup failure indication

    /*------------------------------------------
      Tx Register Controller Interface
    ------------------------------------------*/
    input  logic [127:0]      i_tx_comp_pkt,        // Completion packet from Tx Register Controller
    input  logic              i_tx_comp_pkt_vld,    // Valid indicator for completion from Tx
    output logic              o_tx_comp_pkt_done,   // Completion transmission acknowledgment

    /*------------------------------------------
      Mailbox / Remote Requests Controller Interface
    ------------------------------------------*/
    output logic              o_e2e_crds_return_vld, // E2E credit return valid (RP only)
    output logic [127:0]      o_rx_remote_comp_pkt, // Remote completion packet
    output logic              o_rx_remote_comp_vld, // Valid indicator for remote completion
    output logic              o_rx_remote_comp_length, // Completion length: 1=128b, 0=64b

    /*------------------------------------------
      Parameter Exchange Controller Interface
    ------------------------------------------*/
    output logic [127:0]      o_rx_msg,             // Received parameter exchange message
    output logic              o_rx_msg_vld          // Valid indicator for parameter exchange message
);

// ======================================================================= //
//  Internal Signals — Completions FIFO
// ======================================================================= //

    logic [NC-1:0]  s_comp_fifo_write_data;      // Data written into completions FIFO (from Decoder)
    logic [NC-1:0]  s_comp_fifo_read_data;       // Data read from completions FIFO (to Comp Controller)
    logic           s_comp_fifo_write_enable;    // Write enable for completions FIFO
    logic           s_comp_fifo_read_enable;     // Read enable for completions FIFO
    logic           s_comp_fifo_full_flag;       // Completions FIFO full flag
    logic           s_comp_fifo_empty_flag;      // Completions FIFO empty flag
    logic           s_comp_fifo_overflow_flag;   // Completions FIFO overflow flag

// ======================================================================= //
//  Internal Signals — Messages FIFO
// ======================================================================= //

    logic [NC-1:0]  s_msg_fifo_write_data;       // Data written into messages FIFO (from Decoder)
    logic [NC-1:0]  s_msg_fifo_read_data;        // Data read from messages FIFO (to Msgs Controller)
    logic           s_msg_fifo_write_enable;     // Write enable for messages FIFO
    logic           s_msg_fifo_read_enable;      // Read enable for messages FIFO
    logic           s_msg_fifo_full_flag;        // Messages FIFO full flag
    logic           s_msg_fifo_empty_flag;       // Messages FIFO empty flag
    logic           s_msg_fifo_overflow_flag;    // Messages FIFO overflow flag

// ======================================================================= //
//  Internal Signals — Error Aggregation
// ======================================================================= //

    logic           s_comp_ctrl_parity_error;      // Completion parity error (from Comp Controller)
    logic           s_msg_ctrl_parity_error;       // Message parity error    (from Msgs Controller)
    logic           s_msg_ctrl_invalid_id_error;   // Invalid Src/Dst ID error (from Msgs Controller)
    logic           s_decoder_reserved_opcode_err; // Reserved opcode error   (from Decoder)

// ======================================================================= //
//  Completions FIFO Instantiation
//  Depth = NUM_OF_COMP_PKTS × PKT_CHUNKS_NUM  (e.g. 4×4=16 entries at NC=32)
// ======================================================================= //

    UC_rx_sync_fifo #(
        .FIFO_DEPTH (NUM_OF_COMP_PKTS * PKT_CHUNKS_NUM),
        .DATA_WIDTH (NC)
    ) u_comp_fifo (
        .clk               (i_clk),
        .rst_n             (i_rst_n),
        .init_n            (i_init_n),
        .fifo_data_in      (s_comp_fifo_write_data),
        .fifo_write_enable (s_comp_fifo_write_enable),
        .fifo_read_enable  (s_comp_fifo_read_enable),
        .fifo_data_out     (s_comp_fifo_read_data),
        .fifo_full         (s_comp_fifo_full_flag),
        .fifo_empty        (s_comp_fifo_empty_flag),
        .fifo_overflow     (s_comp_fifo_overflow_flag)
    );

// ======================================================================= //
//  Messages FIFO Instantiation
//  Depth = NUM_OF_MSG_PKTS × PKT_CHUNKS_NUM  (e.g. 2×4=8 entries at NC=32)
// ======================================================================= //

    UC_rx_sync_fifo #(
        .FIFO_DEPTH (NUM_OF_MSG_PKTS * PKT_CHUNKS_NUM),
        .DATA_WIDTH (NC)
    ) u_msg_fifo (
        .clk               (i_clk),
        .rst_n             (i_rst_n),
        .init_n            (i_init_n),
        .fifo_data_in      (s_msg_fifo_write_data),
        .fifo_write_enable (s_msg_fifo_write_enable),
        .fifo_read_enable  (s_msg_fifo_read_enable),
        .fifo_data_out     (s_msg_fifo_read_data),
        .fifo_full         (s_msg_fifo_full_flag),
        .fifo_empty        (s_msg_fifo_empty_flag),
        .fifo_overflow     (s_msg_fifo_overflow_flag)
    );

// ======================================================================= //
//  RX Decoder Instantiation
//  Decodes the opcode of each arriving packet and routes:
//    - Completions → Completions FIFO (phase by phase)
//    - Messages    → Messages FIFO    (phase by phase)
//    - Requests    → directly to Remote Die Request Controller (EP only, full packet)
// ======================================================================= //

    UC_rx_controller_decoder_RP #(.NC(NC)) u_decoder (
        .i_clk              (i_clk),
        .i_rstn             (i_rst_n),
        .i_init_n           (i_init_n),
        // RDI Interface
        .i_pl_cfg           (i_rdi_pl_cfg),
        .i_pl_cfg_vld       (i_rdi_pl_cfg_vld),
        // Completions FIFO write port
        .o_comp_phase       (s_comp_fifo_write_data),
        .o_write_comp_fifo  (s_comp_fifo_write_enable),
        // Messages FIFO write port
        .o_msg_phase        (s_msg_fifo_write_data),
        .o_write_msg_fifo   (s_msg_fifo_write_enable),
        // Error Handler
        .o_rsvd_opcode_err  (s_decoder_reserved_opcode_err)
    );

// ======================================================================= //
//  Completions Controller Instantiation
//  Reads from Completions FIFO, checks parity, restores tags, and forwards:
//    - Local  completions → FDI (protocol layer)
//    - Remote completions → Mailbox Controller
// ======================================================================= //

    UC_rx_completions_controller #(.NC(NC)) u_comp_ctrl (
        .i_clk                   (i_clk),
        .i_rst_n                 (i_rst_n),
        .i_init_n                (i_init_n),
        // Completions FIFO read port
        .i_comp_fifo_empty       (s_comp_fifo_empty_flag),
        .i_comp_phase            (s_comp_fifo_read_data),
        .o_read_comp_fifo        (s_comp_fifo_read_enable),
        // Tx Register Controller Interface
        .i_tx_Comp_pkt           (i_tx_comp_pkt),
        .i_tx_Comp_pkt_vld       (i_tx_comp_pkt_vld),
        .o_tx_Comp_pkt_done      (o_tx_comp_pkt_done),
        // Mailbox Controller Interface (remote completions)
        .o_rx_remote_comp_pkt    (o_rx_remote_comp_pkt),
        .o_rx_remote_comp_vld    (o_rx_remote_comp_vld),
        .o_rx_remote_comp_length (o_rx_remote_comp_length),
        // Tag Manager Interface
        .o_rx_chk_tag            (o_rx_chk_tag),
        .o_rx_current_tag        (o_rx_current_tag),
        .i_rx_orig_tag           (i_rx_orig_tag),
        .i_rx_tag_notfound       (i_rx_tag_notfound),
        // Error Handler Interface
        .o_comp_parity_err       (s_comp_ctrl_parity_error),
        // FDI Interface (local completions → protocol layer)
        .o_pl_cfg                (o_fdi_pl_cfg),
        .o_pl_cfg_vld            (o_fdi_pl_cfg_vld)
    );

// ======================================================================= //
//  Messages Controller Instantiation
//  Reads from Messages FIFO, checks parity, validates IDs, and forwards:
//    - State/Error messages → LSM
//    - Parameter exchange messages → Parameter Exchange Controller
//    - E2E credit returns → Remote Requests Controller (RP only)
// ======================================================================= //

    UC_rx_msgs_ctrl_RP #(.NC(NC)) u_msgs_ctrl (
        .i_clk                (i_clk),
        .i_rstn               (i_rst_n),
        .i_init_n             (i_init_n),
        // Messages FIFO read port
        .i_msgs_fifo_empty    (s_msg_fifo_empty_flag),
        .i_msg_phase          (s_msg_fifo_read_data),
        .o_read_msg_fifo      (s_msg_fifo_read_enable),
        // Parameter Exchange Controller Interface
        .o_rx_msg             (o_rx_msg),
        .o_rx_msg_vld         (o_rx_msg_vld),
        // Credit Loop Interface
        .o_rdi_crd_release    (o_rdi_crd_release),
        // LSM Interface
        .o_sb_err_msg_rx      (o_sb_err_msg_rx),
        .o_e2e_crds_return_vld(o_e2e_crds_return_vld),
        .o_sb_state_msg_rx    (o_sb_state_msg_rx),
        // Error Handler Interface
        .o_msg_parity_err     (s_msg_ctrl_parity_error),
        .o_msg_invld_id_err   (s_msg_ctrl_invalid_id_error)
    );

// ======================================================================= //
//  Error Signals Aggregation
// ======================================================================= //

    // FIFO Overflow — flagged only when the FIFO is actually full 
    assign o_sb_rdi_overflow =
        (s_comp_fifo_overflow_flag & s_comp_fifo_full_flag) |
        (s_msg_fifo_overflow_flag  & s_msg_fifo_full_flag );

    // Combined Parity Error — from Completions Controller + Messages Controller
    // EP also includes request parity errors from the Decoder
    assign o_sb_rx_parity_error = s_comp_ctrl_parity_error | s_msg_ctrl_parity_error ;

    // Fatal  — reserved opcode or invalid message IDs
    assign o_sb_rx_opid_err= s_decoder_reserved_opcode_err | s_msg_ctrl_invalid_id_error;

endmodule
