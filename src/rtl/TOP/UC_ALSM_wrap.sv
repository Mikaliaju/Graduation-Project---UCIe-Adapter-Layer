// ============================================================
// File: UC_ALSM_wrap.sv
// Description: Wrapper binding interfaces to UC_ALSM
// ============================================================

import UC_ALSM_package::*;
import UC_sb_pkg::*;
// `include "UC_rdi_if.sv"
// `include "UC_fdi_if.sv"
// `include "UC_regfile_if.sv"

module UC_ALSM_wrap (
    input  logic        i_clk,
    input  logic        i_rst_n,
    input  logic        i_init,

    rdi_if.alsm         rdi,
    fdi_if.alsm         fdi,
    regfile_if.alsm     rf,

    // SB Interface (not in standard interfaces)
    input  sb_state_msg_encoding    i_sb_state_rx,
    input  logic                    i_sb_param_exch_done,
    output logic                    o_sb_start_param_exch,
    output sb_state_msg_encoding    o_sb_state_tx,

    // MB Interface
    input  logic        i_mb_retry_clean_boundary_done,
    input  logic        i_mb_flush_done,
    input  logic        i_mb_retrain_trigger,
    input  logic        i_mb_rx_path_empty,
    input  logic        i_mb_drain_done,
    output logic        o_mb_flush,
    output logic        o_mb_retry_clean_boundary,
    output logic        o_mb_tx_enable,
    output logic        o_mb_rx_enable,
    output logic        o_mb_drain
);

    //----------------------------------------------------------
    // Internal wires
    //----------------------------------------------------------

    // RDI inputs
    logic               w_rdi_pl_inband_pres;
    logic               w_rdi_pl_phyinrecenter;
    logic [2:0]         w_rdi_pl_speedmode;
    logic [2:0]         w_rdi_pl_lnk_cfg;
    ll_state            w_rdi_pl_state_sts;
    logic               w_rdi_pl_clk_req;
    logic               w_rdi_pl_wake_ack;
    logic               w_rdi_pl_stall_req;
    logic               w_rdi_pl_error;
    logic               w_rdi_pl_trdy;

    // RDI outputs
    logic               w_rdi_lp_clk_ack;
    logic               w_rdi_lp_wake_req;
    logic               w_rdi_lp_linkerror;
    state_req           w_rdi_lp_state_req;
    logic               w_rdi_lp_stall_ack;

    // FDI inputs
    state_req           w_fdi_lp_state_req;
    logic               w_fdi_lp_linkerror;
    logic               w_fdi_lp_rx_active_sts;
    logic               w_fdi_lp_stall_ack;
    logic               w_fdi_lp_clk_ack;
    logic               w_fdi_lp_wake_req;

    // FDI outputs
    logic               w_fdi_pl_stallreq;
    logic               w_fdi_pl_phyinrecenter;
    logic               w_fdi_pl_phyinl1;
    logic               w_fdi_pl_phyinl2;
    logic [2:0]         w_fdi_pl_speedmode;
    logic               w_fdi_pl_max_speedmode;
    logic [2:0]         w_fdi_pl_lnk_cfg;
    ll_state            w_fdi_pl_state_sts;
    logic               w_fdi_pl_inband_pres;
    logic               w_fdi_pl_rx_active_req;
    logic               w_fdi_pl_clk_req;
    logic               w_fdi_pl_wake_ack;

    // RegFile outputs
    Adapter_Response    w_adpater_lsm_response_type;
    logic               w_link_status;
    logic               w_ce_adapter_transition_retrain;
    logic               w_regfile_start_link_train_clear;

    // RegFile inputs
    logic               w_regfile_linkerror;
    logic               w_regfile_start_retrain;
    logic               w_regfile_start_link_train;

    //----------------------------------------------------------
    // Interface → wire (inputs)
    //----------------------------------------------------------
    assign w_rdi_pl_inband_pres    = rdi.pl_inband_pres;
    assign w_rdi_pl_phyinrecenter  = rdi.pl_phyinrecenter;
    assign w_rdi_pl_speedmode      = rdi.pl_speedmode;
    assign w_rdi_pl_lnk_cfg        = rdi.pl_lnk_cfg;
    assign w_rdi_pl_state_sts      = rdi.pl_state_sts;
    assign w_rdi_pl_clk_req        = rdi.pl_clk_req;
    assign w_rdi_pl_wake_ack       = rdi.pl_wake_ack;
    assign w_rdi_pl_stall_req      = rdi.pl_stall_req;
    assign w_rdi_pl_error          = rdi.pl_error;
    assign w_rdi_pl_trdy           = rdi.pl_trdy_alsm;

    assign w_fdi_lp_state_req      = fdi.lp_state_req;
    assign w_fdi_lp_linkerror      = fdi.lp_linkerror;
    assign w_fdi_lp_rx_active_sts  = fdi.lp_rx_active_sts;
    assign w_fdi_lp_stall_ack      = fdi.lp_stall_ack;
    assign w_fdi_lp_clk_ack        = fdi.lp_clk_ack;
    assign w_fdi_lp_wake_req       = fdi.lp_wake_req;

    assign w_regfile_linkerror          = rf.alsm_linkerror;
    assign w_regfile_start_retrain      = rf.alsm_start_retrain;
    assign w_regfile_start_link_train   = rf.alsm_start_link_train;

    //----------------------------------------------------------
    // Wire → interface (outputs)
    //----------------------------------------------------------
    assign rdi.lp_clk_ack     = w_rdi_lp_clk_ack;
    assign rdi.lp_wake_req    = w_rdi_lp_wake_req;
    assign rdi.lp_linkerror   = w_rdi_lp_linkerror;
    assign rdi.lp_state_req   = w_rdi_lp_state_req;
    assign rdi.lp_stall_ack   = w_rdi_lp_stall_ack;

    assign fdi.pl_stallreq       = w_fdi_pl_stallreq;
    assign fdi.pl_phyinrecenter  = w_fdi_pl_phyinrecenter;
    assign fdi.pl_phyinl1        = w_fdi_pl_phyinl1;
    assign fdi.pl_phyinl2        = w_fdi_pl_phyinl2;
    assign fdi.pl_speedmode      = w_fdi_pl_speedmode;
    assign fdi.pl_max_speedmode  = w_fdi_pl_max_speedmode;
    assign fdi.pl_lnk_cfg        = w_fdi_pl_lnk_cfg;
    assign fdi.pl_state_sts      = w_fdi_pl_state_sts;
    assign fdi.pl_inband_pres    = w_fdi_pl_inband_pres;
    assign fdi.pl_rx_active_req  = w_fdi_pl_rx_active_req;
    assign fdi.pl_clk_req        = w_fdi_pl_clk_req;
    assign fdi.pl_wake_ack       = w_fdi_pl_wake_ack;

    assign rf.alsm_response_type         = w_adpater_lsm_response_type;
    assign rf.alsm_link_status           = w_link_status;
    assign rf.alsm_ce_retrain            = w_ce_adapter_transition_retrain;
    assign rf.alsm_start_link_train_clear= w_regfile_start_link_train_clear;

    //----------------------------------------------------------
    // DUT Instantiation
    //----------------------------------------------------------
    UC_ALSM u_UC_ALSM (
        .i_clk                              ( i_clk                              ),
        .i_rst_n                            ( i_rst_n                            ),
        .i_init                             ( i_init                             ),

        // RDI
        .i_rdi_pl_inband_pres               ( w_rdi_pl_inband_pres               ),
        .i_rdi_pl_phyinrecenter             ( w_rdi_pl_phyinrecenter             ),
        .i_rdi_pl_speedmode                 ( w_rdi_pl_speedmode                 ),
        .i_rdi_pl_lnk_cfg                   ( w_rdi_pl_lnk_cfg                   ),
        .i_rdi_pl_state_sts                 ( w_rdi_pl_state_sts                 ),
        .i_rdi_pl_clk_req                   ( w_rdi_pl_clk_req                   ),
        .i_rdi_pl_wake_ack                  ( w_rdi_pl_wake_ack                  ),
        .i_rdi_pl_stall_req                 ( w_rdi_pl_stall_req                 ),
        .i_rdi_pl_error                     ( w_rdi_pl_error                     ),
        .i_rdi_pl_trdy                      ( w_rdi_pl_trdy                      ),
        .o_rdi_lp_clk_ack                   ( w_rdi_lp_clk_ack                   ),
        .o_rdi_lp_wake_req                  ( w_rdi_lp_wake_req                  ),
        .o_rdi_lp_linkerror                 ( w_rdi_lp_linkerror                 ),
        .o_rdi_lp_state_req                 ( w_rdi_lp_state_req                 ),
        .o_rdi_lp_stall_ack                 ( w_rdi_lp_stall_ack                 ),

        // FDI
        .i_fdi_lp_state_req                 ( w_fdi_lp_state_req                 ),
        .i_fdi_lp_linkerror                 ( w_fdi_lp_linkerror                 ),
        .i_fdi_lp_rx_active_sts             ( w_fdi_lp_rx_active_sts             ),
        .i_fdi_lp_stall_ack                 ( w_fdi_lp_stall_ack                 ),
        .i_fdi_lp_clk_ack                   ( w_fdi_lp_clk_ack                   ),
        .i_fdi_lp_wake_req                  ( w_fdi_lp_wake_req                  ),
        .o_fdi_pl_stallreq                  ( w_fdi_pl_stallreq                  ),
        .o_fdi_pl_phyinrecenter             ( w_fdi_pl_phyinrecenter             ),
        .o_fdi_pl_phyinl1                   ( w_fdi_pl_phyinl1                   ),
        .o_fdi_pl_phyinl2                   ( w_fdi_pl_phyinl2                   ),
        .o_fdi_pl_speedmode                 ( w_fdi_pl_speedmode                 ),
        .o_fdi_pl_max_speedmode             ( w_fdi_pl_max_speedmode             ),
        .o_fdi_pl_lnk_cfg                   ( w_fdi_pl_lnk_cfg                   ),
        .o_fdi_pl_state_sts                 ( w_fdi_pl_state_sts                 ),
        .o_fdi_pl_inband_pres               ( w_fdi_pl_inband_pres               ),
        .o_fdi_pl_rx_active_req             ( w_fdi_pl_rx_active_req             ),
        .o_fdi_pl_clk_req                   ( w_fdi_pl_clk_req                   ),
        .o_fdi_pl_wake_ack                  ( w_fdi_pl_wake_ack                  ),

        // SB
        .i_sb_state_rx                      ( i_sb_state_rx                      ),
        .i_sb_param_exch_done               ( i_sb_param_exch_done               ),
        .o_sb_start_param_exch              ( o_sb_start_param_exch              ),
        .o_sb_state_tx                      ( o_sb_state_tx                      ),

        // MB
        .i_mb_retry_clean_boundary_done     ( i_mb_retry_clean_boundary_done     ),
        .i_mb_flush_done                    ( i_mb_flush_done                    ),
        .i_mb_retrain_trigger               ( i_mb_retrain_trigger               ),
        .i_mb_rx_path_empty                 ( i_mb_rx_path_empty                 ),
        .i_mb_drain_done                    ( i_mb_drain_done                    ),
        .o_mb_flush                         ( o_mb_flush                         ),
        .o_mb_retry_clean_boundary          ( o_mb_retry_clean_boundary          ),
        .o_mb_tx_enable                     ( o_mb_tx_enable                     ),
        .o_mb_rx_enable                     ( o_mb_rx_enable                     ),
        .o_mb_drain                         ( o_mb_drain                         ),

        // RegFile
        .i_regfile_linkerror                ( w_regfile_linkerror                ),
        .i_regfile_start_retrain            ( w_regfile_start_retrain            ),
        .i_regfile_start_link_train         ( w_regfile_start_link_train         ),
        .o_adpater_lsm_response_type        ( w_adpater_lsm_response_type        ),
        .o_uce_adapter_timeout_non_active   (                                    ),
        .o_uce_adapter_timeout_active       (                                    ),
        .o_error_valid                      (                                    ),
        .o_link_status                      ( w_link_status                      ),
        .o_ce_adapter_transition_retrain    ( w_ce_adapter_transition_retrain    ),
        .o_regfile_start_link_train_clear   ( w_regfile_start_link_train_clear   )
    );

endmodule : UC_ALSM_wrap