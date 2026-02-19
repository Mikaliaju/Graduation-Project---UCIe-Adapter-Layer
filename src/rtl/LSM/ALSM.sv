module ALSM (
    input logic clk,
    input logic rst_n,
    
    // RDI inputs
    input logic i_rdi_pl_inband_pres,
    input logic i_rdi_pl_phyinrecenter,
    input logic [2:0] i_rdi_pl_speedmode,
    input logic [2:0] i_rdi_pl_lnk_cfg,
    input logic [3:0] i_rdi_pl_state_sts,
    input logic i_rdi_pl_clk_req,
    input logic i_rdi_pl_wake_ack,

    // RDI outputs
    output logic o_rdi_lp_clk_ack,
    output logic o_rdi_lp_wake_req,
    output logic o_rdi_lp_linkerror,
    output logic [3:0] o_rdi_lp_state_req,

    // FDI inputs
    input logic [3:0] i_fdi_lp_state_req,
    input logic i_fdi_lp_linkerror,
    input logic i_fdi_lp_rx_active_sts,
    input logic i_fdi_lp_stall_ack,

    // FDI outputs
    input logic o_fdi_pl_stallreq,
    input logic o_fdi_pl_phyinrecenter,
    input logic o_fdi_pl_phyinl1,
    input logic o_fdi_pl_phyinl2,
    input logic [2:0] o_fdi_pl_speedmode,
    input logic o_fdi_pl_max_speedmode,
    input logic [2:0] o_fdi_pl_lnk_cfg,
    input logic [3:0] o_fdi_pl_state_sts,
    input logic o_fdi_pl_inband_pres,
    input logic o_fdi_pl_rx_active_req,

    // SB inputs
    input logic i_sb_state_rx,
    input logic i_sb_param_exch_done,

    // SB outputs
    output logic o_sb_start_param_exch,
    output logic o_sb_msg_request,
    output logic [3:0] o_sb_state_tx,

    // MB inputs
    input logic i_MB_retry_clean_boundary_done,
    input logic i_MB_flush_done,
    input logic i_MB_Retrain_Trigger,
    input logic i_MB_rx_path_empty,

    // MB outputs
    output logic o_MB_flush,
    output logic o_MB_retry_clean_boundary,
    output logic o_MB_tx_enable,
    output logic o_MB_rx_enable,

    // RegFile Inputs
    input logic i_Regfile_LinkError,

    // RegFile outputs
    output logic [2:0] o_Adpater_LSM_response_type,
    output logic o_uce_Adapter_timeout_non_active,
    output logic o_uce_Adapter_timeout_active,
    output logic o_Error_Valid,
    output logic o_Link_Status,
    output logic o_ce_Adapter_Transition_Retrain
);
    
endmodule