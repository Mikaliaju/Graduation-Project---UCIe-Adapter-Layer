// ============================================================
// File: UC_top.sv
// Description: Top-level module connecting all UCIe subsystems
//              Instantiates SB, MB, ALSM, and RegFile through
//              their interface wrappers
// ============================================================

import UC_ALSM_package::*;
import UC_sb_pkg::*;
import UC_MB_Mainband_pkg::*;
import UC_regfile_package::*;

// `include "UC_rdi_if.sv"
// `include "UC_fdi_if.sv"
// `include "UC_regfile_if.sv"

module UC_TOP #(
    //----------------------------------------------------------
    // Sideband Parameters
    //----------------------------------------------------------
    parameter int P_NC                  = 32,
    parameter int P_RX_NUM_OF_COMP_PKTS = 4,
    parameter int P_RX_NUM_OF_MSG_PKTS  = 2,
    parameter int P_TX_FDI_FIFO_DEPTH   = 32,
    parameter int P_TX_FIFO_WIDTH       = 128,
    parameter int P_TX_DATA_W           = 64,
    parameter int P_CL_MAX_CREDITS      = 32,

    //----------------------------------------------------------
    // Mainband Parameters
    //----------------------------------------------------------
    parameter int DATA_PATH             = 512,
    parameter int DLLP                  = 32
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
    input  logic [P_NC-1:0]     i_rdi_pl_cfg,
    input  logic                i_rdi_pl_cfg_vld,
    input  logic                i_rdi_pl_cfg_crd,

    output logic [P_NC-1:0]     o_rdi_lp_cfg,
    output logic                o_rdi_lp_cfg_vld,
    output logic                o_rdi_lp_cfg_crd,

    //==========================================================
    // RDI Interface — Mainband (to/from PHY)
    //==========================================================
    input  logic                i_rdi_pl_trdy,              // PHY ready to accept flit
    output logic [DATA_PATH-1:0] o_rdi_lp_data,            // TX flit to PHY
    output logic                o_rdi_lp_valid,             // TX flit valid
    output logic                o_rdi_lp_irdy,              // Packer ready

    input  logic [DATA_PATH-1:0] i_rdi_pl_data,            // RX flit from PHY
    input  logic                i_rdi_pl_valid,             // RX flit valid

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
    input  logic                i_rdi_pl_error_rf,
    input  logic                i_rdi_pl_cerror,
    input  logic                i_rdi_pl_nferror,

    //==========================================================
    // FDI Interface — Sideband (to/from Protocol Layer)
    //==========================================================
    input  logic [P_NC-1:0]     i_fdi_lp_cfg,
    input  logic                i_fdi_lp_cfg_vld,
    input  logic                i_fdi_lp_cfg_crd,

    output logic [P_NC-1:0]     o_fdi_pl_cfg,
    output logic                o_fdi_pl_cfg_vld,
    output logic                o_fdi_pl_cfg_crd,
    output logic [3:0]          o_fdi_pl_protocol,
    output logic [3:0]          o_fdi_pl_flit_fmt,
    output logic                o_fdi_pl_valid,

    //==========================================================
    // FDI Interface — Mainband TX (from Protocol Layer)
    //==========================================================
    input  logic                i_fdi_lp_irdy,
    input  logic                i_fdi_lp_valid,
    input  logic [DATA_PATH-1:0] i_fdi_lp_data,
    input  logic [DLLP-1:0]     i_fdi_lp_dllp,
    input  logic                i_fdi_lp_dllp_valid,
    input  logic                i_fdi_lp_dllp_ofc,
    input  logic [7:0]          i_fdi_lp_stream,

    output logic                o_fdi_pl_trdy,

    //==========================================================
    // FDI Interface — Mainband RX (to Protocol Layer)
    //==========================================================
    output logic [DATA_PATH-1:0] o_fdi_pl_data,
    output logic                o_fdi_pl_valid_mb,
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
    // RegFile drives these to protocol layer
    output logic                o_fdi_pl_cerror,
    output logic                o_fdi_pl_nferror,
    output logic                o_fdi_pl_trainerror,

    //==========================================================
    // LSM / Error Outputs
    //==========================================================
    `ifndef END_POINT
    output sb_error_msg_encoding    o_sb_err_msg_rx,
    output logic                    o_sb_remote_timeout,
    `else
    output logic                    o_sb_local_timeout,
    `endif
    output sb_state_msg_encoding    o_sb_state_msg_rx,
    output logic                    o_sb_rdi_overflow,
    output logic                    o_sb_fdi_overflow,
    output logic                    o_sb_parity_error,
    output logic                    o_sb_opid_err,
    output logic                    o_sb_fdi_packer_error,
    output logic                    o_msg_timer_enable,
    output logic                    o_sb_param_exch_done,
    output logic                    o_sb_invalid_param_exch,
    output logic                    o_sb_param_exch_timeout,
    output logic                    o_sb_retry_negotiated,

    //==========================================================
    // SW Mailbox Interface
    //==========================================================
    input  logic [31:0]         i_sw_mailbox_data_low,
    input  logic [31:0]         i_sw_mailbox_data_high,
    input  logic [1:0]          i_sw_mailbox_status,
    input  logic                i_sw_mailbox_trigger_en,

    output logic                o_sw_mailbox_trigger,
    output logic [31:0]         o_sw_mailbox_index_low,
    output logic [4:0]          o_sw_mailbox_index_high,
    output logic [31:0]         o_sw_mailbox_data_low,
    output logic [31:0]         o_sw_mailbox_data_high,

    //==========================================================
    // IRQ Outputs
    //==========================================================
    output logic                o_uncorrectable_error_IRQ,
    output logic                o_correctable_error_IRQ,

    //==========================================================
    // MB LSM Interface (from ALSM to MB)
    // Exposed at top for debug/visibility (optional)
    //==========================================================
    // These are internally connected but exposed for observability
    output logic                o_mb_tx_enable,
    output logic                o_mb_rx_enable
);

//==============================================================
// Interface Instantiations
//==============================================================

    fdi_if #(
        .P_NC       ( P_NC ),
        .DATA_PATH  ( DATA_PATH ),
        .DLLP       ( DLLP )
    ) fdi_bus (
        .i_clk      ( i_clk )
    );

    rdi_if #(
        .P_NC       ( P_NC ),
        .DATA_PATH  ( DATA_PATH )
    ) rdi_bus (
        .i_clk      ( i_clk )
    );

    regfile_if rf_bus (
        .i_clk      ( i_clk )
    );

//==============================================================
// Internal Signals (Cross-module, not in interfaces)
//==============================================================

    //----------------------------------------------------------
    // ALSM ↔ SB
    //----------------------------------------------------------
    logic                       w_sb_start_param_exch;     // ALSM → SB
    logic                       w_sb_param_exch_done;      // SB  → ALSM
    sb_state_msg_encoding       w_sb_state_msg_tx;         // ALSM → SB
    sb_state_msg_encoding       w_sb_state_msg_rx;         // SB  → ALSM

    `ifdef END_POINT
    sb_error_msg_encoding       w_sb_err_msg_tx;           // RegFile → SB (EP only)
    `endif

    //----------------------------------------------------------
    // ALSM ↔ MB
    //----------------------------------------------------------
    logic                       w_mb_flush;
    logic                       w_mb_retry_clean_boundary;
    logic                       w_mb_tx_enable;
    logic                       w_mb_rx_enable;
    logic                       w_mb_drain;

    logic                       w_mb_flush_done;
    logic                       w_mb_retry_clean_boundary_done;
    logic                       w_mb_retrain_trigger;
    logic                       w_mb_rx_path_empty;
    logic                       w_mb_drain_done;

    //----------------------------------------------------------
    // MB LSM Control (ALSM → MB wrapper)
    //----------------------------------------------------------
    logic                       w_packer_en;
    logic                       w_flit_boundary;
    logic                       w_unpacker_en;
    logic                       w_stop_stream;
    logic                       w_flit_boundary_done;
    logic                       w_flush_done;
    logic                       w_drain_done;

    //----------------------------------------------------------
    // SB Parameter Exchange
    //----------------------------------------------------------
    logic [63:0]                w_sb_adapter_advcap_out;
    logic [63:0]                w_sb_adapter_fincap_out;
    logic [63:0]                w_sb_cxl_advcap_out;
    logic [63:0]                w_sb_cxl_fincap_out;
    logic                       w_sb_adapter_advcap_valid;
    logic                       w_sb_adapter_fincap_valid;
    logic                       w_sb_cxl_advcap_valid;
    logic                       w_sb_cxl_fincap_valid;
    logic [4:0]                 w_sb_flit_format_status;
    logic                       w_sb_flitfmt_valid;
    logic                       w_sb_retry_negotiated;

    // RegFile → SB
    logic [63:0]                w_rf_adapter_advcap;
    logic [63:0]                w_rf_cxl_advcap;
    logic [4:0]                 w_rf_flit_fmt_status;
    logic                       w_rf_format4_enabled;
    logic                       w_rf_format6_enabled;

    // SB misc outputs
    logic                       w_sb_invalid_param_exch;
    logic                       w_sb_param_exch_timeout;
    logic                       w_sb_rdi_overflow;
    logic                       w_sb_fdi_overflow;
    logic                       w_sb_parity_error;
    logic                       w_sb_opid_err;
    logic                       w_sb_fdi_packer_error;
    logic                       w_sb_retry_negotiated_internal;

    //----------------------------------------------------------
    // RegFile Error/Status
    //----------------------------------------------------------
    logic                       w_rf_linkerror;
    logic                       w_rf_start_retrain;
    logic                       w_rf_start_link_train;
    logic                       w_rf_start_link_train_clear;

    // ALSM → RegFile
    Adapter_Response            w_alsm_response_type;
    logic                       w_alsm_link_status;
    logic                       w_alsm_ce_retrain;
    logic                       w_alsm_start_param_exch_rf;

    // MB → RegFile
    logic                       w_mb_receiver_overflow;
    logic                       w_mb_crc_error;
    logic                       w_mb_correctable_error;

//==============================================================
// Top-level Port → Interface Signal Assignments
//==============================================================

    //----------------------------------------------------------
    // RDI — Sideband
    //----------------------------------------------------------
    assign rdi_bus.pl_cfg               = i_rdi_pl_cfg;
    assign rdi_bus.pl_cfg_vld           = i_rdi_pl_cfg_vld;
    assign rdi_bus.pl_cfg_crd           = i_rdi_pl_cfg_crd;
    assign o_rdi_lp_cfg                 = rdi_bus.lp_cfg;
    assign o_rdi_lp_cfg_vld             = rdi_bus.lp_cfg_vld;
    assign o_rdi_lp_cfg_crd             = rdi_bus.lp_cfg_crd;

    //----------------------------------------------------------
    // RDI — Mainband
    //----------------------------------------------------------
    assign rdi_bus.pl_trdy              = i_rdi_pl_trdy;
    assign o_rdi_lp_data                = rdi_bus.lp_data;
    assign o_rdi_lp_valid               = rdi_bus.lp_valid;
    assign o_rdi_lp_irdy                = rdi_bus.lp_irdy;
    assign rdi_bus.pl_data              = i_rdi_pl_data;
    assign rdi_bus.pl_valid             = i_rdi_pl_valid;

    //----------------------------------------------------------
    // RDI — ALSM
    //----------------------------------------------------------
    assign rdi_bus.pl_inband_pres       = i_rdi_pl_inband_pres;
    assign rdi_bus.pl_phyinrecenter     = i_rdi_pl_phyinrecenter;
    assign rdi_bus.pl_speedmode         = i_rdi_pl_speedmode;
    assign rdi_bus.pl_lnk_cfg           = i_rdi_pl_lnk_cfg;
    assign rdi_bus.pl_state_sts         = i_rdi_pl_state_sts;
    assign rdi_bus.pl_clk_req           = i_rdi_pl_clk_req;
    assign rdi_bus.pl_wake_ack          = i_rdi_pl_wake_ack;
    assign rdi_bus.pl_stall_req         = i_rdi_pl_stall_req;
    assign rdi_bus.pl_error             = i_rdi_pl_error;
    assign rdi_bus.pl_trdy_alsm         = i_rdi_pl_trdy_alsm;

    assign o_rdi_lp_clk_ack             = rdi_bus.lp_clk_ack;
    assign o_rdi_lp_wake_req            = rdi_bus.lp_wake_req;
    assign o_rdi_lp_linkerror           = rdi_bus.lp_linkerror;
    assign o_rdi_lp_state_req           = rdi_bus.lp_state_req;
    assign o_rdi_lp_stall_ack           = rdi_bus.lp_stall_ack;

    //----------------------------------------------------------
    // RDI — RegFile
    //----------------------------------------------------------
    assign rdi_bus.pl_trainerror        = i_rdi_pl_trainerror;
    assign rdi_bus.pl_error_rf          = i_rdi_pl_error_rf;
    assign rdi_bus.pl_cerror            = i_rdi_pl_cerror;
    assign rdi_bus.pl_nferror           = i_rdi_pl_nferror;
    assign rdi_bus.pl_phyinrecenter_rf  = i_rdi_pl_phyinrecenter;
    assign rdi_bus.pl_speedmode_rf      = i_rdi_pl_speedmode;
    assign rdi_bus.pl_lnk_cfg_rf        = i_rdi_pl_lnk_cfg;

    //----------------------------------------------------------
    // FDI — Sideband
    //----------------------------------------------------------
    assign fdi_bus.lp_cfg               = i_fdi_lp_cfg;
    assign fdi_bus.lp_cfg_vld           = i_fdi_lp_cfg_vld;
    assign fdi_bus.lp_cfg_crd           = i_fdi_lp_cfg_crd;
    assign o_fdi_pl_cfg                 = fdi_bus.pl_cfg;
    assign o_fdi_pl_cfg_vld             = fdi_bus.pl_cfg_vld;
    assign o_fdi_pl_cfg_crd             = fdi_bus.pl_cfg_crd;
    assign o_fdi_pl_protocol            = fdi_bus.pl_protocol;
    assign o_fdi_pl_flit_fmt            = fdi_bus.pl_flit_fmt;
    assign o_fdi_pl_valid               = fdi_bus.pl_valid;

    //----------------------------------------------------------
    // FDI — Mainband TX
    //----------------------------------------------------------
    assign fdi_bus.lp_irdy              = i_fdi_lp_irdy;
    assign fdi_bus.lp_valid             = i_fdi_lp_valid;
    assign fdi_bus.lp_data              = i_fdi_lp_data;
    assign fdi_bus.lp_dllp              = i_fdi_lp_dllp;
    assign fdi_bus.lp_dllp_valid        = i_fdi_lp_dllp_valid;
    assign fdi_bus.lp_dllp_ofc          = i_fdi_lp_dllp_ofc;
    assign fdi_bus.lp_stream            = i_fdi_lp_stream;
    assign o_fdi_pl_trdy                = fdi_bus.pl_trdy;

    //----------------------------------------------------------
    // FDI — Mainband RX
    //----------------------------------------------------------
    assign o_fdi_pl_data                = fdi_bus.pl_data;
    assign o_fdi_pl_valid_mb            = fdi_bus.pl_valid_mb;
    assign o_fdi_pl_stream              = fdi_bus.pl_stream;
    assign o_fdi_pl_dllp                = fdi_bus.pl_dllp;
    assign o_fdi_pl_dllp_valid          = fdi_bus.pl_dllp_valid;
    assign o_fdi_pl_dllp_ofc            = fdi_bus.pl_dllp_ofc;
    assign o_fdi_flit_cancel            = fdi_bus.flit_cancel;

    //----------------------------------------------------------
    // FDI — ALSM
    //----------------------------------------------------------
    assign fdi_bus.lp_state_req         = i_fdi_lp_state_req;
    assign fdi_bus.lp_linkerror         = i_fdi_lp_linkerror;
    assign fdi_bus.lp_rx_active_sts     = i_fdi_lp_rx_active_sts;
    assign fdi_bus.lp_stall_ack         = i_fdi_lp_stall_ack;
    assign fdi_bus.lp_clk_ack           = i_fdi_lp_clk_ack;
    assign fdi_bus.lp_wake_req          = i_fdi_lp_wake_req;

    assign o_fdi_pl_stallreq            = fdi_bus.pl_stallreq;
    assign o_fdi_pl_phyinrecenter       = fdi_bus.pl_phyinrecenter;
    assign o_fdi_pl_phyinl1             = fdi_bus.pl_phyinl1;
    assign o_fdi_pl_phyinl2             = fdi_bus.pl_phyinl2;
    assign o_fdi_pl_speedmode           = fdi_bus.pl_speedmode;
    assign o_fdi_pl_max_speedmode       = fdi_bus.pl_max_speedmode;
    assign o_fdi_pl_lnk_cfg             = fdi_bus.pl_lnk_cfg;
    assign o_fdi_pl_state_sts           = fdi_bus.pl_state_sts;
    assign o_fdi_pl_inband_pres         = fdi_bus.pl_inband_pres;
    assign o_fdi_pl_rx_active_req       = fdi_bus.pl_rx_active_req;
    assign o_fdi_pl_clk_req             = fdi_bus.pl_clk_req;
    assign o_fdi_pl_wake_ack            = fdi_bus.pl_wake_ack;

    //----------------------------------------------------------
    // FDI — RegFile
    //----------------------------------------------------------
    assign fdi_bus.lp_linkerror_rf      = i_fdi_lp_linkerror;
    assign o_fdi_pl_cerror              = fdi_bus.pl_cerror;
    assign o_fdi_pl_nferror             = fdi_bus.pl_nferror;
    assign o_fdi_pl_trainerror          = fdi_bus.pl_trainerror;

//==============================================================
// Internal Signal → RegFile Interface Assignments
//==============================================================

    // ALSM → RegFile (through rf_bus)
    assign rf_bus.alsm_response_type        = w_alsm_response_type;
    assign rf_bus.alsm_link_status          = w_alsm_link_status;
    assign rf_bus.alsm_ce_retrain           = w_alsm_ce_retrain;
    assign rf_bus.alsm_start_param_exch     = w_alsm_start_param_exch_rf;
    assign rf_bus.alsm_start_link_train_clear = w_rf_start_link_train_clear;

    // RegFile → ALSM (through rf_bus)
    assign w_rf_linkerror               = rf_bus.alsm_linkerror;
    assign w_rf_start_retrain           = rf_bus.alsm_start_retrain;
    assign w_rf_start_link_train        = rf_bus.alsm_start_link_train;

    // MB → RegFile
    assign rf_bus.mb_receiver_overflow  = w_mb_receiver_overflow;
    assign rf_bus.mb_crc_error          = w_mb_crc_error;
    assign rf_bus.mb_correctable_error  = w_mb_correctable_error;

    // SB → RegFile errors
    assign rf_bus.sb_invalid_param_exch = w_sb_invalid_param_exch;
    assign rf_bus.sb_param_exch_timeout = w_sb_param_exch_timeout;
    assign rf_bus.sb_rdi_overflow       = w_sb_rdi_overflow;
    assign rf_bus.sb_fdi_overflow       = w_sb_fdi_overflow;
    assign rf_bus.sb_parity_error       = w_sb_parity_error;
    assign rf_bus.sb_invalid_opcode_id  = w_sb_opid_err;
    assign rf_bus.sb_param_exch_done    = w_sb_param_exch_done;

    `ifndef END_POINT
    assign rf_bus.sb_remote_timeout     = o_sb_remote_timeout;
    assign rf_bus.sb_local_timeout      = '0;
    `else
    assign rf_bus.sb_local_timeout      = o_sb_local_timeout;
    assign rf_bus.sb_remote_timeout     = '0;
    `endif

    // SB cap logging → RegFile
    assign rf_bus.sb_adapter_advcap         = w_sb_adapter_advcap_out;
    assign rf_bus.sb_adapter_advcap_valid   = w_sb_adapter_advcap_valid;
    assign rf_bus.sb_cxl_advcap             = w_sb_cxl_advcap_out;
    assign rf_bus.sb_cxl_advcap_valid       = w_sb_cxl_advcap_valid;
    assign rf_bus.sb_adapter_fincap         = w_sb_adapter_fincap_out;
    assign rf_bus.sb_adapter_fincap_valid   = w_sb_adapter_fincap_valid;
    assign rf_bus.sb_cxl_fincap             = w_sb_cxl_fincap_out;
    assign rf_bus.sb_cxl_fincap_valid       = w_sb_cxl_fincap_valid;
    assign rf_bus.sb_flit_fmt_status_in     = w_sb_flit_format_status;
    assign rf_bus.sb_flitfmt_valid          = w_sb_flitfmt_valid;

    // RegFile → SB param exchange inputs
    assign w_rf_adapter_advcap          = rf_bus.sb_adapter_advcap_out;
    assign w_rf_cxl_advcap              = rf_bus.sb_cxl_advcap_out;
    assign w_rf_flit_fmt_status         = rf_bus.sb_flit_fmt_status_out;
    assign w_rf_format4_enabled         = rf_bus.sb_format4_enabled;
    assign w_rf_format6_enabled         = rf_bus.sb_format6_enabled;

    `ifdef END_POINT
    assign w_sb_err_msg_tx              = rf_bus.sb_out_error_msg_encoding;
    `endif

    // Top-level output assignments from internal wires
    assign o_sb_rdi_overflow            = w_sb_rdi_overflow;
    assign o_sb_fdi_overflow            = w_sb_fdi_overflow;
    assign o_sb_parity_error            = w_sb_parity_error;
    assign o_sb_opid_err                = w_sb_opid_err;
    assign o_sb_fdi_packer_error        = w_sb_fdi_packer_error;
    assign o_sb_invalid_param_exch      = w_sb_invalid_param_exch;
    assign o_sb_param_exch_timeout      = w_sb_param_exch_timeout;
    assign o_sb_param_exch_done         = w_sb_param_exch_done;
    assign o_sb_retry_negotiated        = w_sb_retry_negotiated_internal;
    assign o_sb_state_msg_rx            = w_sb_state_msg_rx;
    assign o_mb_tx_enable               = w_mb_tx_enable;
    assign o_mb_rx_enable               = w_mb_rx_enable;

//==============================================================
// DUT Instantiations
//==============================================================

    //----------------------------------------------------------
    // 1. Sideband Top
    //----------------------------------------------------------
    UC_sb_top_wrap #(
        .P_NC                   ( P_NC                  ),
        .P_RX_NUM_OF_COMP_PKTS  ( P_RX_NUM_OF_COMP_PKTS ),
        .P_RX_NUM_OF_MSG_PKTS   ( P_RX_NUM_OF_MSG_PKTS  ),
        .P_TX_FDI_FIFO_DEPTH    ( P_TX_FDI_FIFO_DEPTH   ),
        .P_TX_FIFO_WIDTH        ( P_TX_FIFO_WIDTH        ),
        .P_TX_DATA_W            ( P_TX_DATA_W            ),
        .P_CL_MAX_CREDITS       ( P_CL_MAX_CREDITS       )
    ) u_sb_top (
        .i_clk                  ( i_clk                         ),
        .i_rst_n                ( i_rst_n                        ),
        .i_init_n               ( i_init                         ),

        // Interfaces
        .rdi                    ( rdi_bus.sb_top                 ),
        .fdi                    ( fdi_bus.sb_top                 ),
        .rf                     ( rf_bus.sb_top                  ),

        // LSM Control
        .i_sb_start_param_exch  ( w_sb_start_param_exch          ),
        .o_sb_param_exch_done   ( w_sb_param_exch_done           ),
        .o_sb_invalid_param_exch( w_sb_invalid_param_exch        ),
        .o_sb_param_exch_timeout( w_sb_param_exch_timeout        ),
        .o_sb_retry_negotiated  ( w_sb_retry_negotiated_internal  ),
        .o_sb_rdi_overflow      ( w_sb_rdi_overflow              ),
        .o_sb_fdi_overflow      ( w_sb_fdi_overflow              ),
        .o_sb_parity_error      ( w_sb_parity_error              ),
        .o_sb_opid_err          ( w_sb_opid_err                  ),
        .o_sb_fdi_packer_error  ( w_sb_fdi_packer_error          ),
        .o_sb_state_msg_rx      ( w_sb_state_msg_rx              ),
        .i_sb_state_msg_tx      ( w_sb_state_msg_tx              ),
        .o_msg_timer_enable     ( o_msg_timer_enable             ),

        `ifndef END_POINT
        .o_sb_err_msg_rx        ( o_sb_err_msg_rx                ),
        .o_sb_remote_timeout    ( o_sb_remote_timeout            ),
        `else
        .o_sb_local_timeout     ( o_sb_local_timeout             ),
        .i_sb_err_msg_tx        ( w_sb_err_msg_tx                ),
        `endif

        // Parameter Exchange
        .i_adapter_advcap       ( w_rf_adapter_advcap            ),
        .i_cxl_advcap           ( w_rf_cxl_advcap                ),
        .i_format4_enabled      ( w_rf_format4_enabled           ),
        .i_format6_enabled      ( w_rf_format6_enabled           ),
        .i_retry_needed         ( '1                             ),
        .i_retry_negotiated     ( w_sb_retry_negotiated_internal  ),
        .i_flit_fmt_status      ( w_rf_flit_fmt_status           ),
        .o_adapter_advcap       ( w_sb_adapter_advcap_out        ),
        .o_adapter_fincap       ( w_sb_adapter_fincap_out        ),
        .o_cxl_advcap           ( w_sb_cxl_advcap_out            ),
        .o_cxl_fincap           ( w_sb_cxl_fincap_out            ),
        .o_adapter_advcap_valid ( w_sb_adapter_advcap_valid      ),
        .o_adapter_fincap_valid ( w_sb_adapter_fincap_valid      ),
        .o_cxl_advcap_valid     ( w_sb_cxl_advcap_valid          ),
        .o_cxl_fincap_valid     ( w_sb_cxl_fincap_valid          ),
        .o_flit_format_status   ( w_sb_flit_format_status        ),
        .o_flitfmt_valid        ( w_sb_flitfmt_valid             )
    );

    //----------------------------------------------------------
    // 2. Mainband
    //----------------------------------------------------------
    UC_MB_Mainband_wrap u_mainband (
        .DATA_PATH              ( DATA_PATH             ),
        .DLLP                   ( DLLP                  )
    ) u_mb (
        .i_clk                  ( i_clk                 ),
        .i_rst_n                ( i_rst_n               ),
        .i_init                 ( i_init                ),

        // Interfaces
        .fdi                    ( fdi_bus.mb            ),
        .rdi                    ( rdi_bus.mb            ),

        // LSM Packer
        .i_packer_en            ( w_mb_tx_enable        ),
        .i_flit_boundary        ( w_mb_retry_clean_boundary ),
        .i_flush                ( w_mb_flush            ),
        .i_drain                ( w_mb_drain            ),
        .o_flit_boundary_done   ( w_mb_retry_clean_boundary_done ),
        .o_flush_done           ( w_mb_flush_done       ),
        .o_drain_done           ( w_mb_drain_done       ),

        // LSM Unpacker
        .i_unpacker_en          ( w_mb_rx_enable        ),
        .i_stop_stream          ( w_stop_stream         )
    );

    //----------------------------------------------------------
    // 3. ALSM
    //----------------------------------------------------------
    UC_ALSM_wrap u_alsm (
        .i_clk                              ( i_clk                         ),
        .i_rst_n                            ( i_rst_n                       ),
        .i_init                             ( i_init                        ),

        // Interfaces
        .rdi                                ( rdi_bus.alsm                  ),
        .fdi                                ( fdi_bus.alsm                  ),
        .rf                                 ( rf_bus.alsm                   ),

        // SB ↔ ALSM
        .i_sb_state_rx                      ( w_sb_state_msg_rx             ),
        .i_sb_param_exch_done               ( w_sb_param_exch_done          ),
        .o_sb_start_param_exch              ( w_sb_start_param_exch         ),
        .o_sb_state_tx                      ( w_sb_state_msg_tx             ),

        // MB ↔ ALSM
        .i_mb_retry_clean_boundary_done     ( w_mb_retry_clean_boundary_done),
        .i_mb_flush_done                    ( w_mb_flush_done               ),
        .i_mb_retrain_trigger               ( w_mb_retrain_trigger          ),
        .i_mb_rx_path_empty                 ( w_mb_rx_path_empty            ),
        .i_mb_drain_done                    ( w_mb_drain_done               ),
        .o_mb_flush                         ( w_mb_flush                    ),
        .o_mb_retry_clean_boundary          ( w_mb_retry_clean_boundary     ),
        .o_mb_tx_enable                     ( w_mb_tx_enable                ),
        .o_mb_rx_enable                     ( w_mb_rx_enable                ),
        .o_mb_drain                         ( w_mb_drain                    )
    );

    //----------------------------------------------------------
    // 4. Register File
    //----------------------------------------------------------
    UC_regfile_wrap u_regfile (
        .i_clk                      ( i_clk                     ),
        .i_rst_n                    ( i_rst_n                   ),
        .i_init                     ( i_init                    ),

        // Interfaces
        .fdi                        ( fdi_bus.regfile           ),
        .rdi                        ( rdi_bus.regfile           ),
        .rf                         ( rf_bus.regfile            ),

        // SW Mailbox
        .i_sw_mailbox_data_low      ( i_sw_mailbox_data_low     ),
        .i_sw_mailbox_data_high     ( i_sw_mailbox_data_high    ),
        .i_sw_mailbox_status        ( i_sw_mailbox_status       ),
        .i_sw_mailbox_trigger_en    ( i_sw_mailbox_trigger_en   ),
        .o_sw_mailbox_trigger       ( o_sw_mailbox_trigger      ),
        .o_sw_mailbox_index_low     ( o_sw_mailbox_index_low    ),
        .o_sw_mailbox_index_high    ( o_sw_mailbox_index_high   ),
        .o_sw_mailbox_data_low      ( o_sw_mailbox_data_low     ),
        .o_sw_mailbox_data_high     ( o_sw_mailbox_data_high    ),

        // IRQ
        .o_uncorrectable_error_IRQ  ( o_uncorrectable_error_IRQ ),
        .o_correctable_error_IRQ    ( o_correctable_error_IRQ   )
    );

endmodule
