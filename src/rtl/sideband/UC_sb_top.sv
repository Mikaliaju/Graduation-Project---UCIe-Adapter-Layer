/*
===========================================================================
 File Name   : UC_sb_top.sv
 Project     : UCIe 3.0 Adapter Layer - Sideband Unit
 Authors     : Shahd Mohamed, Ashraf Sherif
===========================================================================
 Module      : UC_sb_top
 Description : Top-level wrapper for the UCIe 3.0 Sideband Unit.
               Integrates Tx, Rx, Credit Loop, Parameter Exchange,
               and LSM Message Controller.
=========================================================================== 
*/ 
import UC_sb_rx_pkg::*;



module UC_sb_top #(
    /*---------------------------------------------
      Sideband Parameters
    ---------------------------------------------*/
    // Common Parameters
    parameter int P_NC = 32,                  // Config bits per phase (Tx/Rx)

    // RX Parameters
    parameter int P_RX_NUM_OF_COMP_PKTS = 4,  // Max completion packets in Rx FIFO
    parameter int P_RX_NUM_OF_MSG_PKTS  = 2,  // Max message packets in Rx FIFO

    // TX Parameters
    parameter int P_TX_FDI_FIFO_DEPTH = 32,   // Tx FDI FIFO depth
    parameter int P_TX_FIFO_WIDTH     = 128,  // Tx FIFO data width
    parameter int P_TX_DATA_W         = 64,   // Tx data width

    // Credit Loop Parameters
    parameter int P_CL_MAX_CREDITS = 32       // Physical layer credits
)(
    /*---------------------------------------------
      Global Signals
    ---------------------------------------------*/
    input  logic                        i_clk,
    input  logic                        i_rst_n,       // Active-low HW reset
    input  logic                        i_init_n,      // Active-low SW reset

    /*---------------------------------------------
      RDI Interface (Raw D2D Interface)
    ---------------------------------------------*/
    // Inputs
    input  logic [P_NC-1:0]             i_rdi_pl_cfg,       // RDI packet chunks from PHY
    input  logic                        i_rdi_pl_cfg_vld,   // Valid indicator for RDI data
    input  logic                        i_rdi_pl_cfg_crd,   // RDI Credit return from PHY

    // Outputs
    output logic [P_NC-1:0]             o_rdi_lp_cfg,       // RDI packet chunks sent to PHY
    output logic                        o_rdi_lp_cfg_vld,   // Valid indicator for RDI packet sent
    output logic                        o_rdi_lp_cfg_crd,   // RDI Credit return from Adapter to PHY

    /*---------------------------------------------
      FDI Interface (Flit aware D2D Interface)
    ---------------------------------------------*/
    // Inputs
    input  logic [P_NC-1:0]             i_fdi_lp_cfg,       // FDI packet chunks from Protocol Layer
    input  logic                        i_fdi_lp_cfg_vld,   // Valid indicator for FDI data
    input  logic                        i_fdi_lp_cfg_crd,   // FDI Credit return from Protocol Layer

    // Outputs
    output logic [P_NC-1:0]             o_fdi_pl_cfg,       // FDI packet chunks to Protocol Layer
    output logic                        o_fdi_pl_cfg_vld,   // Valid indicator for FDI packet sent
    output logic                        o_fdi_pl_cfg_crd,   // FDI Credit return from Adapter to Protocol Layer
    output logic [3:0]                  o_fdi_pl_protocol,  // Negotiated protocol
    output logic [3:0]                  o_fdi_pl_flit_fmt,  // Negotiated flit format
    output logic                        o_fdi_pl_valid,

    /*---------------------------------------------
      LSM & Error Handling Interface
    ---------------------------------------------*/
    `ifndef END_POINT
    output sb_error_msg_encoding        o_sb_err_msg_rx,          // Error messages received (RP only)
    output logic                        o_sb_remote_timeout,      // Remote timeout (RP only)
    `else
    output logic                        o_sb_local_timeout,       // Local timeout (EP only)
    `endif
    output sb_state_msg_encoding        o_sb_state_msg_rx,        // State messages
    output logic                        o_sb_rdi_overflow,        // RDI FIFO overflow
    output logic                        o_sb_fdi_overflow,        // FDI FIFO overflow
    output logic                        o_sb_parity_error,        // Combined parity error
    output logic                        o_sb_opid_err,            // opcode OR id error
    output logic                        o_sb_fdi_packer_error,    // FDI packer error

    // LSM Control
    input  logic                        i_sb_start_param_exch,    // Start parameter exchange
    output logic                        o_sb_param_exch_done,     // Parameter exchange done
    output logic                        o_sb_invalid_param_exch,  // Invalid parameter exchange
    output logic                        o_sb_param_exch_timeout,  // Parameter exchange timeout
    output logic                        o_sb_retry_negotiated,    // Retry negotiated
    input  sb_state_msg_encoding        i_sb_state_msg_tx,        // State message to transmit
    `ifdef END_POINT
    input  sb_error_msg_encoding        i_sb_err_msg_tx,          // Error message to transmit (EP only)
    `endif
    output logic                        o_msg_timer_enable,       // to enable msgs timer 

    /*---------------------------------------------
      Register File Interface
    ---------------------------------------------*/
    // Read Interface
    input  logic [63:0]                 i_reg_read_data,
    input  logic [2:0]                  i_reg_status,

    // Write Interface
    output logic [63:0]                 o_reg_write_data,
    output logic                        o_reg_write_en,
    output logic [23:0]                 o_reg_address,
    output logic [7:0]                  o_reg_be,
    output logic                        o_reg_config_req,
    output logic                        o_reg_32_B,
    output logic                        o_reg_valid,

    // Mailbox Interface (RP only)
    `ifndef END_POINT
    input  logic [31:0]                 i_mailbox_index_low,
    input  logic [4:0]                  i_mailbox_index_high,
    input  logic [31:0]                 i_mailbox_data_low,
    input  logic [31:0]                 i_mailbox_data_high,
    input  logic                        i_mailbox_trigger,
    input  logic [3:0]                  i_remote_access_threshold,

    output logic [31:0]                 o_mailbox_data_low,
    output logic [31:0]                 o_mailbox_data_high,
    output logic                        o_mailbox_data_en,
    output logic                        o_mailbox_trigger_en,
    output logic [1:0]                  o_mailbox_status,
    output logic [63:0]                 o_header_log_1,
    output logic                        o_header_log_en,
    `endif

    /*---------------------------------------------
      Parameter Exchange Interface
    ---------------------------------------------*/
    input  logic [63:0]                 i_adapter_advcap,
    input  logic [63:0]                 i_cxl_advcap,
    input  logic                        i_format4_enabled,
    input  logic                        i_format6_enabled,
    input  logic                        i_retry_needed,
    input  logic                        i_retry_negotiated,
    input  logic [4:0]                  i_flit_fmt_status,

    output logic [63:0]                 o_adapter_advcap,
    output logic [63:0]                 o_adapter_fincap,
    output logic [63:0]                 o_cxl_advcap,
    output logic [63:0]                 o_cxl_fincap,
    output logic                        o_adapter_advcap_valid,
    output logic                        o_adapter_fincap_valid,
    output logic                        o_cxl_advcap_valid,
    output logic                        o_cxl_fincap_valid,
    output logic [4:0]                  o_flit_format_status,
    output logic                        o_flitfmt_valid
);

// ===========================================================================
//                    Internal Signals
// ===========================================================================

// --- Tx ↔ Rx Tag Manager Interface ---
logic              s_tag_mgr_check_tag_request;
logic [4:0]        s_tag_mgr_current_tag;
logic [4:0]        s_tag_mgr_original_tag;
logic              s_tag_mgr_tag_not_found;

// --- Tx ↔ Rx Completion Interface ---
logic [127:0]      s_tx_rx_completion_packet;
logic              s_tx_rx_completion_valid;
logic              s_tx_rx_completion_done;

// --- Tx ↔ Rx Remote Request/Completion Interface ---
`ifdef END_POINT
logic [127:0]      s_rx_tx_remote_request_packet;
logic              s_rx_tx_remote_request_valid;
`else
logic              s_rx_tx_e2e_credit_return;
`endif

// Unconditional: UC_sb_rx_top always drives o_rx_remote_comp_length
logic              s_rx_tx_remote_comp_length;

logic [127:0]      s_rx_tx_remote_completion_pkt;
logic              s_rx_tx_remote_completion_valid;

// --- Parameter Exchange ↔ LSM Message Controller ---
logic [127:0]      s_param_exch_tx_message;
logic              s_param_exch_tx_message_valid;
logic [127:0]      s_param_exch_rx_message;
logic              s_param_exch_rx_message_valid;

// --- LSM Message Controller ↔ Tx ---
logic [127:0]      s_msg_ctrl_tx_message;
logic              s_msg_ctrl_tx_message_valid;
logic              s_msg_ctrl_tx_message_type;
logic              s_tx_msg_fifo_full_flag;
logic              s_tx_msg_handling_done_flag;

// --- Credit Loop Signals ---
logic              s_rx_rdi_credit_release;
logic              s_tx_fdi_credit_release;
logic              s_tx_decrease_phy_buffer;
logic              s_credit_loop_stall_signal;

// --- Error Signals ---
logic              s_rx_parity_error_flag;
logic              s_tx_parity_error_flag;
logic              s_rx__opid_err;

// ===========================================================================
//                    1. UC_sb_rx_top
// ===========================================================================

UC_sb_rx_top #(
    .NC                 (P_NC),
    .NUM_OF_COMP_PKTS   (P_RX_NUM_OF_COMP_PKTS),
    .NUM_OF_MSG_PKTS    (P_RX_NUM_OF_MSG_PKTS)
) U_RX_TOP (
    .i_clk                   (i_clk),
    .i_rst_n                 (i_rst_n),
    .i_init_n                (i_init_n),

    // RDI
    .i_rdi_pl_cfg            (i_rdi_pl_cfg),
    .i_rdi_pl_cfg_vld        (i_rdi_pl_cfg_vld),

    // FDI
    .o_fdi_pl_cfg            (o_fdi_pl_cfg),
    .o_fdi_pl_cfg_vld        (o_fdi_pl_cfg_vld),

    // LSM
    `ifndef END_POINT
    .o_sb_err_msg_rx         (o_sb_err_msg_rx),
    `endif
    .o_sb_state_msg_rx       (o_sb_state_msg_rx),

    // Error Handling
    .o_sb_rdi_overflow       (o_sb_rdi_overflow),
    .o_sb_rx_parity_error    (s_rx_parity_error_flag),
    .o_sb_rx_opid_err        (s_rx__opid_err),

    // Credit
    .o_rdi_crd_release       (s_rx_rdi_credit_release),

    // Tag Manager
    .o_rx_chk_tag            (s_tag_mgr_check_tag_request),
    .o_rx_current_tag        (s_tag_mgr_current_tag),
    .i_rx_orig_tag           (s_tag_mgr_original_tag),
    .i_rx_tag_notfound       (s_tag_mgr_tag_not_found),

    // Tx Interface
    .i_tx_comp_pkt           (s_tx_rx_completion_packet),
    .i_tx_comp_pkt_vld       (s_tx_rx_completion_valid),
    .o_tx_comp_pkt_done      (s_tx_rx_completion_done),

    // Remote
    `ifdef END_POINT
    .o_remote_req_pkt        (s_rx_tx_remote_request_packet),
    .o_remote_req_vld        (s_rx_tx_remote_request_valid),
    `else
    .o_e2e_crds_return_vld   (s_rx_tx_e2e_credit_return),
    `endif
    .o_rx_remote_comp_pkt    (s_rx_tx_remote_completion_pkt),
    .o_rx_remote_comp_vld    (s_rx_tx_remote_completion_valid),
    .o_rx_remote_comp_length (s_rx_tx_remote_comp_length),

    // Parameter Exchange
    .o_rx_msg                (s_param_exch_rx_message),
    .o_rx_msg_vld            (s_param_exch_rx_message_valid)
);

// ===========================================================================
//                    2. UC_sb_tx_top
// ===========================================================================

UC_sb_tx_top #(
    .P_NC               (P_NC),
    .P_FDI_FIFO_DEPTH   (P_TX_FDI_FIFO_DEPTH),
    .P_FIFO_WIDTH       (P_TX_FIFO_WIDTH),
    .P_DATA_W           (P_TX_DATA_W)
) U_TX_TOP (
    .i_clk                   (i_clk),
    .i_rst_n                 (i_rst_n),
    .i_init_n                (i_init_n),

    // FDI
    .i_fdi_lp_cfg            (i_fdi_lp_cfg),
    .i_fdi_lp_cfg_vld        (i_fdi_lp_cfg_vld),

    // RDI
    .o_rdi_lp_cfg            (o_rdi_lp_cfg),
    .o_rdi_lp_cfg_vld        (o_rdi_lp_cfg_vld),

    // LSM / Error
    `ifdef END_POINT
    .o_tx_lsm_local_time_out  (o_sb_local_timeout),
    `else
    .o_tx_lsm_remote_time_out (o_sb_remote_timeout),
    `endif
    .o_tx_lsm_parity_error   (s_tx_parity_error_flag),
    .o_tx_fdi_overflow        (o_sb_fdi_overflow),
    .o_fdi_packer_error       (o_sb_fdi_packer_error),

    // Register File
    .i_reg_read_data         (i_reg_read_data),
    .i_reg_status            (i_reg_status),
    .o_reg_write_data        (o_reg_write_data),
    .o_reg_write_en          (o_reg_write_en),
    .o_reg_address           (o_reg_address),
    .o_reg_be                (o_reg_be),
    .o_reg_config_req        (o_reg_config_req),
    .o_reg_32_B              (o_reg_32_B),
    .o_reg_valid             (o_reg_valid),

    // Mailbox (RP only)
    `ifndef END_POINT
    .i_mailbox_index_low     (i_mailbox_index_low),
    .i_mailbox_index_high    (i_mailbox_index_high),
    .i_mailbox_data_low      (i_mailbox_data_low),
    .i_mailbox_data_high     (i_mailbox_data_high),
    .i_mailbox_trigger       (i_mailbox_trigger),
    .i_remote_access_threshold(i_remote_access_threshold),
    .i_e2e_crd_return        (s_rx_tx_e2e_credit_return),
    .o_mailbox_data_low      (o_mailbox_data_low),
    .o_mailbox_data_high     (o_mailbox_data_high),
    .o_mailbox_data_en       (o_mailbox_data_en),
    .o_mailbox_trigger_en    (o_mailbox_trigger_en),
    .o_mailbox_status        (o_mailbox_status),
    .o_header_log_1          (o_header_log_1),
    .o_header_log_en         (o_header_log_en),
    `endif

    // Rx Controller Interface — Tag Manager
    .i_rx_tx_chk_tag         (s_tag_mgr_check_tag_request),
    .i_rx_tx_current_tag     (s_tag_mgr_current_tag),
    .o_rx_tx_orig_tag        (s_tag_mgr_original_tag),
    .o_rx_tx_tag_notfound    (s_tag_mgr_tag_not_found),

    // Rx Controller Interface — Remote
    `ifdef END_POINT
    .i_rx_tx_remote_req_pkt  (s_rx_tx_remote_request_packet),
    .i_rx_tx_remote_req_vld  (s_rx_tx_remote_request_valid),
    .i_rx_tx_remote_comp_type(s_rx_tx_remote_comp_length),
    `endif

    .i_rx_tx_remote_comp_pkt (s_rx_tx_remote_completion_pkt),
    .i_rx_tx_remote_comp_vld (s_rx_tx_remote_completion_valid),
    .o_tx_rx_comp_pkt        (s_tx_rx_completion_packet),
    .o_tx_rx_comp_pkt_vld    (s_tx_rx_completion_valid),
    .i_tx_rx_comp_pkt_done   (s_tx_rx_completion_done),

    // Credit
    .i_tx_stall_signal       (s_credit_loop_stall_signal),
    .o_tx_fdi_crd_release    (s_tx_fdi_credit_release),
    .o_tx_dec_phy_buffer     (s_tx_decrease_phy_buffer),

    // Messages
    .i_tx_msg                (s_msg_ctrl_tx_message),
    .i_tx_msg_vld            (s_msg_ctrl_tx_message_valid),
    .i_tx_msg_type           (s_msg_ctrl_tx_message_type),
    .o_tx_msgs_fifo_full     (s_tx_msg_fifo_full_flag),
    .o_tx_msg_handling_done  (s_tx_msg_handling_done_flag)
);

// ===========================================================================
//                    3. UC_sb_credit_loop
// ===========================================================================

UC_sb_credit_loop #(
    .MAX_CREDITS(P_CL_MAX_CREDITS)
) U_CREDIT_LOOP (
    .i_clk                  (i_clk),
    .i_rst_n                (i_rst_n),
    .i_init                 (i_init_n),

    .i_rdi_credit_release   (s_rx_rdi_credit_release),
    .i_fdi_credit_release   (s_tx_fdi_credit_release),

    .i_lp_cfg_crd           (i_fdi_lp_cfg_crd),
    .i_pl_cfg_crd           (i_rdi_pl_cfg_crd),

    .i_decrease_counter     (s_tx_decrease_phy_buffer),

    .o_stall                (s_credit_loop_stall_signal),
    .o_pl_cfg_crd           (o_fdi_pl_cfg_crd),
    .o_lp_cfg_crd           (o_rdi_lp_cfg_crd)
);

// ===========================================================================
//                    4. UC_parameterexchange
// ===========================================================================

UC_parameterexchange U_PARAM_EXCH (
    .i_clk                      (i_clk),
    .i_rstn                     (i_rst_n),
    .i_init_n                   (i_init_n),

    // Local Capabilities
    .i_adapter_advcap           (i_adapter_advcap),
    .i_cxl_advcap               (i_cxl_advcap),
    .i_format4_enabled          (i_format4_enabled),
    .i_format6_enabled          (i_format6_enabled),
    .i_retry_needed             (i_retry_needed),

    // RX/TX Message Interface
    .i_rx_msg_with_data         (s_param_exch_rx_message),
    .i_rx_msg_valid             (s_param_exch_rx_message_valid),
    .o_tx_msg_with_data         (s_param_exch_tx_message),
    .o_tx_msg_valid             (s_param_exch_tx_message_valid),

    // Capability Logging
    .o_adapter_advcap           (o_adapter_advcap),
    .o_adapter_fincap           (o_adapter_fincap),
    .o_cxl_advcap               (o_cxl_advcap),
    .o_cxl_fincap               (o_cxl_fincap),
    .o_adapter_advcap_valid     (o_adapter_advcap_valid),
    .o_adapter_fincap_valid     (o_adapter_fincap_valid),
    .o_cxl_advcap_valid         (o_cxl_advcap_valid),
    .o_cxl_fincap_valid         (o_cxl_fincap_valid),

    // Flit Format
    .i_flit_fmt_status          (i_flit_fmt_status),
    .o_flit_fromat_status       (o_flit_format_status),
    .o_flitfmt_valid            (o_flitfmt_valid),

    // Control
    .i_start_PE                 (i_sb_start_param_exch),
    .o_PE_done                  (o_sb_param_exch_done),
    .o_invalid_param_exch       (o_sb_invalid_param_exch),
    .o_param_exchange_timeout   (o_sb_param_exch_timeout),
    .o_retry_negotiated         (o_sb_retry_negotiated),
    .i_retry_negotiated         (i_retry_negotiated),

    // Protocol Layer
    .o_pl_protocol              (o_fdi_pl_protocol),
    .o_pl_flit_fmt              (o_fdi_pl_flit_fmt),
    .o_pl_valid                 (o_fdi_pl_valid)
);

// ===========================================================================
//                    5. msg_controller_tx
// ===========================================================================

msg_controller_tx U_MSG_CTRL_TX (
    .i_clk                      (i_clk),
    .i_rstn                     (i_rst_n),
    .i_init_n                   (i_init_n),

    // Parameter Exchange
    .i_tx_msg_with_data         (s_param_exch_tx_message),
    .i_tx_msg_with_data_valid   (s_param_exch_tx_message_valid),
    .i_PE_done                  (o_sb_param_exch_done),

    // RDI Controller
    .i_msg_is_req               (s_tx_msg_handling_done_flag),
    .i_msgs_fifo_full           (s_tx_msg_fifo_full_flag),
    .o_tx_msg                   (s_msg_ctrl_tx_message),
    .o_tx_msg_valid             (s_msg_ctrl_tx_message_valid),
    .o_tx_msg_length            (s_msg_ctrl_tx_message_type),

    // Error Handler
    `ifdef END_POINT
    .i_err_msg                  (i_sb_err_msg_tx),
    `endif

    // LSM
    .i_lsm_msg                  (i_sb_state_msg_tx),
    .o_msg_timer_enable         (o_msg_timer_enable)
);

// ===========================================================================
//                    Error Signals Aggregation
// ===========================================================================

assign o_sb_parity_error = s_rx_parity_error_flag | s_tx_parity_error_flag;
assign o_sb_opid_err     = s_rx__opid_err;

endmodule
