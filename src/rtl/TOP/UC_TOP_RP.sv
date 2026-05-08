// ============================================================
// File: UC_top.sv
// Description: Top-level module connecting all UCIe subsystems
//              Instantiates SB, MB, ALSM, and RegFile
// ============================================================

import UC_ALSM_package::*;
import UC_sb_rx_pkg::*;
import UC_MB_Mainband_pkg::*;
import UC_regfile_package::*;

`include "../common/UC_all_defs.svh"

module UC_TOP_RP #(
)(
    //==========================================================
    // Global Signals
    //==========================================================
    input  logic                i_clk,
    input  logic                i_rst_n,        // Active-low HW reset
    input  logic                i_init,         // Active-high SW reset (MB/ALSM)

    //==========================================================
    // RDI Interface — Sideband (to/from PHY)
    //==========================================================
    input  logic [`P_NC-1:0]    i_rdi_pl_cfg,
    input  logic                i_rdi_pl_cfg_vld,
    input  logic                i_rdi_pl_cfg_crd,

    output logic [`P_NC-1:0]     o_rdi_lp_cfg,
    output logic                o_rdi_lp_cfg_vld,
    output logic                o_rdi_lp_cfg_crd,

    //==========================================================
    // RDI Interface — Mainband (to/from PHY)
    //==========================================================
    input  logic                 i_rdi_pl_trdy,              // PHY ready to accept flit
    output logic [DATA_PATH-1:0] o_rdi_lp_data,            // TX flit to PHY
    output logic                 o_rdi_lp_valid,             // TX flit valid
    output logic                 o_rdi_lp_irdy,              // Packer ready

    input  logic [DATA_PATH-1:0] i_rdi_pl_data,            // RX flit from PHY
    input  logic                 i_rdi_pl_valid,             // RX flit valid
    //==========================================================
    // RDI Interface — ALSM (to/from PHY)
    //==========================================================
    input  logic                i_rdi_pl_inband_pres,
    input  logic                i_rdi_pl_phyinrecenter,
    input  logic [2:0]          i_rdi_pl_speedmode,
    input  logic [2:0]          i_rdi_pl_lnk_cfg,
    input  ll_state             i_rdi_pl_state_sts,
    input  logic                i_rdi_pl_clk_req,
    input  logic                i_rdi_pl_wake_ack,
    input  logic                i_rdi_pl_stall_req,
    input  logic                i_rdi_pl_error,
    input  logic                i_rdi_pl_trdy_alsm,

    output logic                o_rdi_lp_clk_ack,
    output logic                o_rdi_lp_wake_req,
    output logic                o_rdi_lp_linkerror,
    output state_req            o_rdi_lp_state_req,
    output logic                o_rdi_lp_stall_ack,

    //==========================================================
    // RDI Interface — RegFile (from PHY, logging only)
    //==========================================================
    input  logic                i_rdi_pl_trainerror,
    input  logic                i_rdi_pl_cerror,
    input  logic                i_rdi_pl_nferror,

    //==========================================================
    // FDI Interface — Sideband (to/from Protocol Layer)
    //==========================================================
    input  logic [`P_NC-1:0]     i_fdi_lp_cfg,
    input  logic                 i_fdi_lp_cfg_vld,
    input  logic                 i_fdi_lp_cfg_crd,

    output logic [`P_NC-1:0]    o_fdi_pl_cfg,
    output logic                o_fdi_pl_cfg_vld,
    output logic                o_fdi_pl_cfg_crd,
    output logic [3:0]          o_fdi_pl_protocol,
    output logic [3:0]          o_fdi_pl_flit_fmt,
    output logic                o_fdi_pl_valid,
    output logic                o_fdi_pl_protocol_valid,

    //==========================================================
    // FDI Interface — Mainband TX (from Protocol Layer)
    //==========================================================
    input  logic                 i_fdi_lp_irdy,
    input  logic                 i_fdi_lp_valid,
    input  logic [DATA_PATH-1:0] i_fdi_lp_data,
    input  logic [DLLP-1:0]      i_fdi_lp_dllp,
    input  logic                 i_fdi_lp_dllp_valid,
    input  logic                 i_fdi_lp_dllp_ofc,
    input  logic [7:0]           i_fdi_lp_stream,

    output logic                o_fdi_pl_trdy,

    //==========================================================
    // FDI Interface — Mainband RX (to Protocol Layer)
    //==========================================================
    output logic [DATA_PATH-1:0] o_fdi_pl_data,
    output logic [7:0]          o_fdi_pl_stream,
    output logic [DLLP-1:0]     o_fdi_pl_dllp,
    output logic                o_fdi_pl_dllp_valid,
    output logic                o_fdi_pl_dllp_ofc,
    output logic                o_fdi_flit_cancel,

    //==========================================================
    // FDI Interface — ALSM (to/from Protocol Layer)
    //==========================================================
    input  state_req            i_fdi_lp_state_req,
    input  logic                i_fdi_lp_linkerror,
    input  logic                i_fdi_lp_rx_active_sts,
    input  logic                i_fdi_lp_stall_ack,
    input  logic                i_fdi_lp_clk_ack,
    input  logic                i_fdi_lp_wake_req,

    output logic                o_fdi_pl_stallreq,
    output logic                o_fdi_pl_phyinrecenter,
    output logic                o_fdi_pl_phyinl1,
    output logic                o_fdi_pl_phyinl2,
    output logic [2:0]          o_fdi_pl_speedmode,
    output logic                o_fdi_pl_max_speedmode,
    output logic [2:0]          o_fdi_pl_lnk_cfg,
    output ll_state             o_fdi_pl_state_sts,
    output logic                o_fdi_pl_inband_pres,
    output logic                o_fdi_pl_rx_active_req,
    output logic                o_fdi_pl_clk_req,
    output logic                o_fdi_pl_wake_ack,

    //==========================================================
    // FDI Interface — RegFile
    //==========================================================
    output o_fdi_pl_cerror,
    output o_fdi_pl_nferror,
    output o_fdi_pl_trainerror,

    //==========================================================
    // IRQ Outputs
    //==========================================================
    output logic                o_uncorrectable_error_IRQ,
    output logic                o_correctable_error_IRQ

    //==========================================================
    // MB LSM Interface (from ALSM to MB)
    // Exposed at top for debug/visibility (optional)
    //==========================================================
    // These are internally connected but exposed for observability
    // output logic                o_mb_tx_enable,
    // output logic                o_mb_rx_enable
);

// MB
logic w_mb_drain, w_mb_drain_done, w_mb_flit_boundary, w_mb_flit_boundary_done,
      w_mb_flush, w_mb_flush_done, w_mb_tx_enable, w_mb_rx_enable, w_mb_receiver_overflow,
      w_mb_correctable_internal_error, w_mb_crc_error_detected;
// ALSM
logic w_link_status, w_ce_adapter_transition_retrain, w_linkerror, w_start_retrain;
Adapter_Response w_adpater_lsm_response_type;


// SB to RegFile
logic [31:0] w_i_sb_mailbox_data_low;
logic [31:0] w_i_sb_mailbox_data_high;
logic [1:0]  w_i_sb_mailbox_status;
logic [63:0] w_sb_Header_log1;
logic [63:0] w_i_sb_adapter_advcap;
logic [63:0] w_i_sb_cxl_advcap;
logic [63:0] w_sb_adapter_fincap;
logic [63:0] w_sb_cxl_fincap;
logic [4:0]  w_sb_flit_format_status;
logic [63:0] w_sb_write_data;
logic  [7:0] w_sb_BE;
logic [23:0] w_sb_address;

logic w_sb_config_req           , w_sb_32_B                 , w_sb_invalid_param_exch , w_sb_local_timeout,
      w_sb_parity_error         , w_sb_param_exch_timeout   , w_sb_invalid_opcode_id  , w_sb_param_exch_done,
      w_sb_adapter_fincap_valid , w_sb_cxl_fincap_valid     , w_sb_flitfmt_valid      , w_sb_write_en,
      w_sb_remote_timeout       , w_sb_fdi_overflow         , w_sb_rdi_overflow       , w_i_sb_mailbox_trigger_en,
      w_sb_Header_log1_valid    , w_sb_adapter_advcap_valid , w_sb_cxl_advcap_valid   ;

sb_error_msg_encoding w_sb_in_error_msg_encoding;

// regfile to SB
logic        w_o_sb_mailbox_trigger;
logic [31:0] w_o_sb_mailbox_index_low;
logic [4:0]  w_o_sb_mailbox_index_high;
logic [31:0] w_o_sb_mailbox_data_low;
logic [31:0] w_o_sb_mailbox_data_high;
logic [3:0]  w_sb_remote_threshold;
logic [63:0] w_o_sb_adapter_advcap;
logic [63:0] w_o_sb_cxl_advcap;
logic [4:0]  w_sb_flit_fmt_status;
logic [2:0]  w_sb_status;
logic [63:0] w_sb_read_data;
logic        w_sb_format4_enabled;
logic        w_sb_format6_enabled;
sb_error_msg_encoding w_sb_out_error_msg_encoding;

// SB to ALSM
logic w_sb_start_param_exch;
sb_state_msg_encoding w_sb_state_tx,  w_sb_state_rx;

// Mainband
UC_MB_Mainband  UC_MB_Mainband_inst (
    .i_clk                (i_clk                  ),
    .i_rst_n              (i_rst_n                ),
    .i_init               (i_init                 ),
    // FDI
    .i_lp_irdy_fdi        (i_fdi_lp_irdy          ),
    .i_lp_valid_fdi       (i_fdi_lp_valid         ),
    .i_lp_data_fdi        (i_fdi_lp_data          ),
    .i_lp_dllp            (i_fdi_lp_dllp          ),
    .i_lp_dllp_valid      (i_fdi_lp_dllp_valid    ),
    .i_lp_dllp_ofc        (i_fdi_lp_dllp_ofc      ),
    .i_lp_stream          (i_fdi_lp_stream        ),
    .o_pl_trdy_fdi        (o_fdi_pl_trdy          ),
    .o_pl_data_fdi        (o_fdi_pl_data          ),
    .o_pl_valid_fdi       (o_fdi_pl_valid         ),
    .o_pl_stream          (o_fdi_pl_stream        ),
    .o_pl_dllp            (o_fdi_pl_dllp          ),
    .o_pl_dllp_valid      (o_fdi_pl_dllp_valid    ),
    .o_pl_dllp_ofc        (o_fdi_pl_dllp_ofc      ),
    .o_flit_cancel        (o_fdi_flit_cancel      ),
    // RDI
    .i_pl_trdy            (i_rdi_pl_trdy          ),
    .o_lp_data_rdi        (o_rdi_lp_data          ),
    .o_lp_valid_rdi       (o_rdi_lp_valid         ),
    .o_lp_irdy_rdi        (o_rdi_lp_irdy          ),
    .i_pl_data_rdi        (i_rdi_pl_data          ),
    .i_pl_valid_rdi       (i_rdi_pl_valid         ),
    // ALSM
    .i_packer_en          (w_mb_tx_enable         ),
    .i_flit_boundary      (w_mb_flit_boundary     ),
    .i_flush              (w_mb_flush             ),
    .i_drain              (w_mb_drain             ),
    .o_flit_boundary_done (w_mb_flit_boundary_done),
    .o_flush_done         (w_mb_flush_done        ),
    .o_drain_done         (w_mb_drain_done        ),
    .i_unpacker_en        (w_mb_rx_enable         ),
    .i_stop_stream        ('0                     )
  );

// RegFile
UC_regfile  UC_regfile_inst (
    .i_init                          (i_init                          ),
    .i_clk                           (i_clk                           ),
    .i_rst_n                         (i_rst_n                         ),
    // FDI
    .i_fdi_lp_linkerror              (i_fdi_lp_linkerror              ),
    .o_fdi_pl_cerror                 (o_fdi_pl_cerror                 ),
    .o_fdi_pl_nferror                (o_fdi_pl_nferror                ),
    .o_fdi_pl_trainerror             (o_fdi_pl_trainerror             ),
    // RDI
    .i_rdi_pl_trainerror             (i_rdi_pl_trainerror             ),
    .i_rdi_pl_error                  (i_rdi_pl_error                  ),
    .i_rdi_pl_cerror                 (i_rdi_pl_cerror                 ),
    .i_rdi_pl_nferror                (i_rdi_pl_nferror                ),
    .i_rdi_pl_phyinrecenter          (i_rdi_pl_phyinrecenter          ),
    .i_rdi_pl_speedmode              (i_rdi_pl_speedmode              ),
    .i_rdi_pl_lnk_cfg                (i_rdi_pl_lnk_cfg                ),
    // ALSM
    .i_adpater_lsm_response_type     (w_adpater_lsm_response_type     ),
    .i_link_status                   (w_link_status                   ),
    .i_ce_adapter_transition_retrain (w_ce_adapter_transition_retrain ),
    .i_ALSM_start_param_exch         (w_sb_start_param_exch           ),
    .o_linkerror                     (w_linkerror                     ),
    .o_start_retrain                 (w_start_retrain                 ),
    // MB
    .i_MB_Receiver_Overflow          ('0                              ),
    .i_MB_CRC_Error_Detected         ('0                              ),
    .i_MB_Correctable_Internal_Error ('0                              ),
    // .i_MB_Receiver_Overflow          (w_mb_receiver_overflow          ),
    // .i_MB_CRC_Error_Detected         (w_mb_crc_error_detected         ),
    // .i_MB_Correctable_Internal_Error (w_mb_correctable_internal_error ),
    // SB
    .i_sb_mailbox_data_low           (w_i_sb_mailbox_data_low         ),
    .i_sb_mailbox_data_high          (w_i_sb_mailbox_data_high        ),
    .i_sb_mailbox_status             (w_i_sb_mailbox_status           ),
    .i_sb_mailbox_trigger_en         (w_i_sb_mailbox_trigger_en       ),
    .i_sb_Header_log1                (w_sb_Header_log1                ),
    .i_sb_Header_log1_valid          (w_sb_Header_log1_valid          ),
    .i_sb_adapter_advcap             (w_i_sb_adapter_advcap           ),
    .i_sb_adapter_advcap_valid       (w_sb_adapter_advcap_valid       ),
    .i_sb_cxl_advcap                 (w_i_sb_cxl_advcap               ),
    .i_sb_cxl_advcap_valid           (w_sb_cxl_advcap_valid           ),
    .i_sb_adapter_fincap             (w_sb_adapter_fincap             ),
    .i_sb_adapter_fincap_valid       (w_sb_adapter_fincap_valid       ),
    .i_sb_cxl_fincap                 (w_sb_cxl_fincap                 ),
    .i_sb_cxl_fincap_valid           (w_sb_cxl_fincap_valid           ),
    .i_sb_flit_format_status         (w_sb_flit_format_status         ),
    .i_sb_flitfmt_valid              (w_sb_flitfmt_valid              ),
    .i_sb_write_data                 (w_sb_write_data                 ),
    .i_sb_write_en                   (w_sb_write_en                   ),
    .i_sb_BE                         (w_sb_BE                         ),
    .i_sb_address                    (w_sb_address                    ),
    .i_sb_config_req                 (w_sb_config_req                 ),
    .i_sb_32_B                       (w_sb_32_B                       ),
    .i_sb_invalid_param_exch         (w_sb_invalid_param_exch         ),
    .i_sb_local_timeout              ('0                              ), //
    .i_sb_remote_timeout             (w_sb_remote_timeout             ),
    .i_sb_fdi_overflow               (w_sb_fdi_overflow               ),
    .i_sb_rdi_overflow               (w_sb_rdi_overflow               ),
    .i_sb_parity_error               ('0                              ), //
    .i_sb_param_exch_timeout         (w_sb_param_exch_timeout         ),
    .i_sb_invalid_opcode_id          (w_sb_invalid_opcode_id          ),
    .i_sb_param_exch_done            (w_sb_param_exch_done            ),
    .i_sb_in_error_msg_encoding      (w_sb_in_error_msg_encoding      ),
    .o_sb_mailbox_trigger            (w_o_sb_mailbox_trigger          ),
    .o_sb_mailbox_index_low          (w_o_sb_mailbox_index_low        ),
    .o_sb_mailbox_index_high         (w_o_sb_mailbox_index_high       ),
    .o_sb_mailbox_data_low           (w_o_sb_mailbox_data_low         ),
    .o_sb_mailbox_data_high          (w_o_sb_mailbox_data_high        ),
    .o_sb_remote_threshold           (w_sb_remote_threshold           ),
    .o_sb_adapter_advcap             (w_o_sb_adapter_advcap           ),
    .o_sb_cxl_advcap                 (w_o_sb_cxl_advcap               ),
    .o_sb_flit_fmt_status            (w_sb_flit_fmt_status            ),
    .o_sb_status                     (w_sb_status                     ),
    .o_sb_read_data                  (w_sb_read_data                  ),
    .o_sb_out_error_msg_encoding     (w_sb_out_error_msg_encoding     ),
    .o_sb_format4_enabled            (w_sb_format4_enabled            ),
    .o_sb_format6_enabled            (w_sb_format6_enabled            ),
    // IRQ
    .o_uncorrectable_error_IRQ       (o_uncorrectable_error_IRQ       ),
    .o_correctable_error_IRQ         (o_correctable_error_IRQ         )
  );

// ALSM
UC_ALSM  UC_ALSM_inst (
    .i_clk                            (i_clk                            ),
    .i_rst_n                          (i_rst_n                          ),
    .i_init                           (i_init                           ),
    // RDI
    .i_rdi_pl_inband_pres             (i_rdi_pl_inband_pres             ),
    .i_rdi_pl_phyinrecenter           (i_rdi_pl_phyinrecenter           ),
    .i_rdi_pl_speedmode               (i_rdi_pl_speedmode               ),
    .i_rdi_pl_lnk_cfg                 (i_rdi_pl_lnk_cfg                 ),
    .i_rdi_pl_state_sts               (i_rdi_pl_state_sts               ),
    .i_rdi_pl_clk_req                 (i_rdi_pl_clk_req                 ),
    .i_rdi_pl_wake_ack                (i_rdi_pl_wake_ack                ),
    .i_rdi_pl_stall_req               (i_rdi_pl_stall_req               ),
    .i_rdi_pl_error                   (i_rdi_pl_error                   ),
    .i_rdi_pl_trdy                    (i_rdi_pl_trdy                    ),
    .o_rdi_lp_clk_ack                 (o_rdi_lp_clk_ack                 ),
    .o_rdi_lp_wake_req                (o_rdi_lp_wake_req                ),
    .o_rdi_lp_linkerror               (o_rdi_lp_linkerror               ),
    .o_rdi_lp_state_req               (o_rdi_lp_state_req               ),
    .o_rdi_lp_stall_ack               (o_rdi_lp_stall_ack               ),
    // FDI
    .i_fdi_lp_state_req               (i_fdi_lp_state_req               ),
    .i_fdi_lp_linkerror               (i_fdi_lp_linkerror               ),
    .i_fdi_lp_rx_active_sts           (i_fdi_lp_rx_active_sts           ),
    .i_fdi_lp_stall_ack               (i_fdi_lp_stall_ack               ),
    .i_fdi_lp_clk_ack                 (i_fdi_lp_clk_ack                 ),
    .i_fdi_lp_wake_req                (i_fdi_lp_wake_req                ),
    .o_fdi_pl_stallreq                (o_fdi_pl_stallreq                ),
    .o_fdi_pl_phyinrecenter           (o_fdi_pl_phyinrecenter           ),
    .o_fdi_pl_phyinl1                 (o_fdi_pl_phyinl1                 ),
    .o_fdi_pl_phyinl2                 (o_fdi_pl_phyinl2                 ),
    .o_fdi_pl_speedmode               (o_fdi_pl_speedmode               ),
    .o_fdi_pl_max_speedmode           (o_fdi_pl_max_speedmode           ),
    .o_fdi_pl_lnk_cfg                 (o_fdi_pl_lnk_cfg                 ),
    .o_fdi_pl_state_sts               (o_fdi_pl_state_sts               ),
    .o_fdi_pl_inband_pres             (o_fdi_pl_inband_pres             ),
    .o_fdi_pl_rx_active_req           (o_fdi_pl_rx_active_req           ),
    .o_fdi_pl_clk_req                 (o_fdi_pl_clk_req                 ),
    .o_fdi_pl_wake_ack                (o_fdi_pl_wake_ack                ),
    // SB
    .i_sb_state_rx                    (w_sb_state_rx                    ),
    .i_sb_param_exch_done             (w_sb_param_exch_done             ),
    .o_sb_start_param_exch            (w_sb_start_param_exch            ),
    .o_sb_state_tx                    (w_sb_state_tx                    ),
    // MB
    .i_mb_retry_clean_boundary_done   (w_mb_flit_boundary_done          ),
    .i_mb_flush_done                  (w_mb_flush_done                  ),
    .i_mb_retrain_trigger             ('0                               ),
    .i_mb_drain_done                  (w_mb_drain_done                  ),
    .o_mb_flush                       (w_mb_flush                       ),
    .o_mb_retry_clean_boundary        (w_mb_flit_boundary               ),
    .o_mb_tx_enable                   (w_mb_tx_enable                   ),
    .o_mb_rx_enable                   (w_mb_rx_enable                   ),
    .o_mb_drain                       (w_mb_drain                       ),
    // RegFile
    .i_regfile_linkerror              (w_linkerror                      ),
    .i_regfile_start_retrain          (w_start_retrain                  ),
    .i_regfile_start_link_train       ('0                               ), //
    .o_adpater_lsm_response_type      (w_adpater_lsm_response_type      ),
    .o_uce_adapter_timeout_non_active (w_uce_adapter_timeout_non_active ), //
    .o_uce_adapter_timeout_active     (w_uce_adapter_timeout_active     ), //
    .o_error_valid                    (w_alsm_error_valid               ), //
    .o_link_status                    (w_link_status                    ),
    .o_ce_adapter_transition_retrain  (w_ce_adapter_transition_retrain  ),
    .o_regfile_start_link_train_clear (w_regfile_start_link_train_clear )  //
  );

  // SB
UC_sb_top_RP # (
  .P_NC(`P_NC),
  .P_RX_NUM_OF_COMP_PKTS     (`P_RX_NUM_OF_COMP_PKTS     ),
  .P_RX_NUM_OF_MSG_PKTS      (`P_RX_NUM_OF_MSG_PKTS      ),
  .P_TX_FDI_FIFO_DEPTH       (`P_TX_FDI_FIFO_DEPTH       ),
  .P_TX_FIFO_WIDTH           (`P_TX_FIFO_WIDTH           ),
  .P_TX_DATA_W               (`P_TX_DATA_W               ),
  .P_CL_MAX_CREDITS          (`P_CL_MAX_CREDITS          )
)
UC_sb_top_RP_inst (
  .i_clk                     (i_clk                      ),
  .i_rst_n                   (i_rst_n                    ),
  .i_init_n                  (i_init                     ),
  // RDI
  .i_rdi_pl_cfg              (i_rdi_pl_cfg               ),
  .i_rdi_pl_cfg_vld          (i_rdi_pl_cfg_vld           ),
  .i_rdi_pl_cfg_crd          (i_rdi_pl_cfg_crd           ),
  .o_rdi_lp_cfg              (o_rdi_lp_cfg               ),
  .o_rdi_lp_cfg_vld          (o_rdi_lp_cfg_vld           ),
  .o_rdi_lp_cfg_crd          (o_rdi_lp_cfg_crd           ),
  // FDI
  .i_fdi_lp_cfg              (i_fdi_lp_cfg               ),
  .i_fdi_lp_cfg_vld          (i_fdi_lp_cfg_vld           ),
  .i_fdi_lp_cfg_crd          (i_fdi_lp_cfg_crd           ),
  .o_fdi_pl_cfg              (o_fdi_pl_cfg               ),
  .o_fdi_pl_cfg_vld          (o_fdi_pl_cfg_vld           ),
  .o_fdi_pl_cfg_crd          (o_fdi_pl_cfg_crd           ),
  .o_fdi_pl_protocol         (o_fdi_pl_protocol          ),
  .o_fdi_pl_flit_fmt         (o_fdi_pl_flit_fmt          ),
  .o_fdi_pl_valid            (o_fdi_pl_protocol_valid    ), //
  // ALSM
  .o_sb_state_msg_rx         (w_sb_state_rx              ),
  .i_sb_state_msg_tx         (w_sb_state_tx              ),
  .i_sb_start_param_exch     (w_sb_start_param_exch      ),
  .o_sb_param_exch_done      (w_sb_param_exch_done       ),

  .o_sb_err_msg_rx           (w_sb_in_error_msg_encoding ),
  .o_sb_remote_timeout       (w_sb_remote_timeout        ),
  .o_sb_rdi_overflow         (w_sb_rdi_overflow          ),
  .o_sb_fdi_overflow         (w_sb_fdi_overflow          ),
  .o_sb_parity_error         (w_sb_parity_error          ),
  .o_sb_opid_err             (w_sb_invalid_opcode_id     ),
  .o_sb_fdi_packer_error     (o_sb_fdi_packer_error      ), //
  .o_sb_invalid_param_exch   (w_sb_invalid_param_exch    ),
  .o_sb_param_exch_timeout   (w_sb_param_exch_timeout    ),
  .o_sb_retry_negotiated     (o_sb_retry_negotiated      ), //
  .o_msg_timer_enable        (o_msg_timer_enable         ), //
  .i_reg_read_data           (w_sb_read_data             ),
  .i_reg_status              (w_sb_status                ),
  .o_reg_write_data          (w_sb_write_data            ),
  .o_reg_write_en            (w_sb_write_en              ),
  .o_reg_address             (w_sb_address               ),
  .o_reg_be                  (w_sb_BE                    ),
  .o_reg_config_req          (w_sb_config_req            ),
  .o_reg_32_B                (w_sb_32_B                  ),
  .o_reg_valid               (o_reg_valid                ), // 

  .i_mailbox_index_low       (w_o_sb_mailbox_index_low   ),
  .i_mailbox_index_high      (w_o_sb_mailbox_index_high  ),
  .i_mailbox_data_low        (w_o_sb_mailbox_data_low    ),
  .i_mailbox_data_high       (w_o_sb_mailbox_data_high   ),
  .i_mailbox_trigger         (w_o_sb_mailbox_trigger     ),
  .o_mailbox_data_low        (w_i_sb_mailbox_data_low    ),
  .o_mailbox_data_high       (w_i_sb_mailbox_data_high   ),
  .o_mailbox_data_en         (w_i_sb_mailbox_data_en     ),
  .o_mailbox_trigger_en      (w_i_sb_mailbox_trigger_en  ),
  .o_mailbox_status          (w_i_sb_mailbox_status      ),

  .o_header_log_1            (w_sb_Header_log1           ),
  .o_header_log_en           (w_sb_Header_log1_valid     ),
  .i_remote_access_threshold (w_sb_remote_threshold      ),
  .i_adapter_advcap          (w_o_sb_adapter_advcap      ),
  .i_cxl_advcap              (64'b1                      ),
  .i_format4_enabled         (w_sb_format4_enabled       ),
  .i_format6_enabled         (w_sb_format6_enabled       ),
  .i_retry_needed            (1'b1                       ), //
  .i_retry_negotiated        (i_retry_negotiated         ), //
  .i_flit_fmt_status         (w_sb_flit_fmt_status       ),
  .o_adapter_advcap          (w_i_sb_adapter_advcap      ),
  .o_adapter_fincap          (w_sb_adapter_fincap        ),
  .o_cxl_advcap              (w_i_sb_cxl_advcap          ),
  .o_cxl_fincap              (w_sb_cxl_fincap            ),
  .o_adapter_advcap_valid    (w_sb_adapter_advcap_valid  ),
  .o_adapter_fincap_valid    (w_sb_adapter_fincap_valid  ),
  .o_cxl_advcap_valid        (w_sb_cxl_advcap_valid      ),
  .o_cxl_fincap_valid        (w_sb_cxl_fincap_valid      ),
  .o_flit_format_status      (w_sb_flit_format_status    ),
  .o_flitfmt_valid           (w_sb_flitfmt_valid         )
);
endmodule
