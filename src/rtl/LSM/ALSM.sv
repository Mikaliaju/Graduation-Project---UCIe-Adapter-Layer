typedef enum logic [3:0] { 
    Req_NOP       = 'b0000,
    Req_Active    = 'b0001,
    Req_L1        = 'b0100,
    Req_L2        = 'b1000,
    Req_LinkReset = 'b1001,
    Req_Retrain   = 'b1011,
    Req_Disable   = 'b1100
} state_req;

typedef enum logic [3:0] { 
    LL_Reset        = 'b0000,
    LL_Active       = 'b0001,
    LL_Active_PMNAK = 'b0011,
    LL_L1           = 'b0100,
    LL_L2           = 'b1000,
    LL_LinkReset    = 'b1001,
    LL_LinkError    = 'b1010,
    LL_Retrain      = 'b1011,
    LL_Disable      = 'b1100
} ll_state;

typedef enum  { 
    Reset,
    Active,
    Retrain,
    L1,
    L2,
    LinkError,
    LinkReset,
    Disable
} Main_State;

typedef enum {
    Reset_sub_state,
    Param_exch,
    Active_Entry,
    SB_Active_Req,
    Active_Req_Await,
    rx_active_1,
    SB_rsp_recieved,
    rx_active_2,
    Await_FDI_Active
} Reset_SUB_STATE;

module ALSM (
    input logic       clk,
    input logic       rst_n,
    
    // RDI inputs
    input logic       i_rdi_pl_inband_pres,
    input logic       i_rdi_pl_phyinrecenter,
    input logic [2:0] i_rdi_pl_speedmode,
    input logic [2:0] i_rdi_pl_lnk_cfg,
    input ll_state    i_rdi_pl_state_sts,
    input logic       i_rdi_pl_clk_req,
    input logic       i_rdi_pl_wake_ack,

    // RDI outputs
    output logic       o_rdi_lp_clk_ack,
    output logic       o_rdi_lp_wake_req,
    output logic       o_rdi_lp_linkerror,
    output state_req   o_rdi_lp_state_req,

    // FDI inputs
    input state_req   i_fdi_lp_state_req,
    input logic       i_fdi_lp_linkerror,
    input logic       i_fdi_lp_rx_active_sts,
    input logic       i_fdi_lp_stall_ack,

    // FDI outputs
    input logic       o_fdi_pl_stallreq,
    input logic       o_fdi_pl_phyinrecenter,
    input logic       o_fdi_pl_phyinl1,
    input logic       o_fdi_pl_phyinl2,
    input logic [2:0] o_fdi_pl_speedmode,
    input logic       o_fdi_pl_max_speedmode,
    input logic [2:0] o_fdi_pl_lnk_cfg,
    input ll_state    o_fdi_pl_state_sts,
    input logic       o_fdi_pl_inband_pres,
    input logic       o_fdi_pl_rx_active_req,

    // SB inputs
    input ll_state     i_sb_state_rx,
    input logic        i_sb_param_exch_done,

    // SB outputs
    output logic       o_sb_start_param_exch,
    output logic       o_sb_msg_request,
    output ll_state    o_sb_state_tx,

    // MB inputs
    input logic        i_MB_retry_clean_boundary_done,
    input logic        i_MB_flush_done,
    input logic        i_MB_Retrain_Trigger,
    input logic        i_MB_rx_path_empty,

    // MB outputs
    output logic       o_MB_flush,
    output logic       o_MB_retry_clean_boundary,
    output logic       o_MB_tx_enable,
    output logic       o_MB_rx_enable,

    // RegFile Inputs
    input logic        i_Regfile_LinkError,

    // RegFile outputs
    output logic [2:0] o_Adpater_LSM_response_type,
    output logic       o_uce_Adapter_timeout_non_active,
    output logic       o_uce_Adapter_timeout_active,
    output logic       o_Error_Valid,
    output logic       o_Link_Status,
    output logic       o_ce_Adapter_Transition_Retrain
);

    // current main state, next sub state
    Main_State cms, nms;

    // current sub state, next sub state
    logic [3:0] css, nss;

    logic Protocol_Active, SB_Active;

    always_comb begin

        nms = cms;
        nss = css;

        case (css)
            Reset_sub_state: 
                if (i_rdi_pl_state_sts == LL_Active) begin
                    nss = Param_exch;
                end
                else begin
                    nss = Reset_sub_state;
                end
            Param_exch: 
                if (i_sb_param_exch_done) begin
                    nss = Active_Entry;
                end
                else begin
                    nss = Param_exch;
                end
            Active_Entry:
                if (Protocol_Active) begin
                    nss = SB_Active_Req;
                end
                else if (SB_Active) begin
                    nss = rx_active_2;
                end
        endcase
    end

    // Protocol_Active and SB_Active only start being taken into account when the State is in 
    // Reset, otherwise they are zero
    always_ff @(negedge rst_n, posedge clk) begin
        if (~rst_n) begin
            Protocol_Active <= 'b0;
            SB_Active <= 'b0;
        end
        else if (cms == Reset) begin
            Protocol_Active <= Protocol_Active | (i_fdi_lp_state_req == Req_Active);
            SB_Active <= SB_Active | (i_sb_state_rx == LL_Active);
        end
        else begin
            Protocol_Active <= 'b0;
            SB_Active <= 'b0;
        end
    end

    always_ff @(negedge rst_n, posedge clk) begin
        if (~rst_n) begin
            cms <= Reset;
            css <= 'b0;
        end
        else begin
            cms <= nms;
            css <= nss;
        end
    end
endmodule