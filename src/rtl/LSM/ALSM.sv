typedef enum logic [2:0] { 
    Active_LSM_response_type    = 'b001,
    L1_LSM_response_type        = 'b010,
    L2_LSM_response_type        = 'b011,
    LinkReset_LSM_response_type = 'b100,
    Disable_LSM_response_type   = 'b101
} Adapter_Response;

// all lp_state_req encodings
typedef enum logic [3:0] { 
    Req_NOP       = 'b0000,
    Req_Active    = 'b0001,
    Req_L1        = 'b0100,
    Req_L2        = 'b1000,
    Req_LinkReset = 'b1001,
    Req_Retrain   = 'b1011,
    Req_Disable   = 'b1100
} state_req;

// all pl_sts encodings
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

// all valid sb message encodings
typedef enum { 
    SB_Req_Active,
    SB_Req_L1,
    SB_Req_L2,
    SB_Req_LinkReset,
    SB_Req_Disable,
    SB_Rsp_Active,
    SB_Rsp_L1,
    SB_Rsp_L2,
    SB_Rsp_LinkReset,
    SB_Rsp_Disable,
    SB_Rsp_PMNAK
 } SB_state;

// Internal Main state encodings
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

// Reset sub state encodings
typedef enum {
    Reset_SS,
    Param_exch_SS,
    Active_Entry_SS,
    SB_Active_Req_SS,
    Active_Req_Await_SS,
    rx_active_1_SS,
    SB_rsp_recieved_SS,
    rx_active_2_SS,
    Await_FDI_Active_SS
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
    input logic       i_fdi_lp_clk_ack,
    input logic       i_fdi_lp_wake_req,

    // FDI outputs
    output logic       o_fdi_pl_stallreq,
    output logic       o_fdi_pl_phyinrecenter,
    output logic       o_fdi_pl_phyinl1,
    output logic       o_fdi_pl_phyinl2,
    output logic [2:0] o_fdi_pl_speedmode,
    output logic       o_fdi_pl_max_speedmode,
    output logic [2:0] o_fdi_pl_lnk_cfg,
    output ll_state    o_fdi_pl_state_sts,
    output logic       o_fdi_pl_inband_pres,
    output logic       o_fdi_pl_rx_active_req,
    output logic       o_fdi_pl_clk_req,
    output logic       o_fdi_pl_wake_ack,

    // SB inputs
    input SB_state     i_sb_state_rx,
    input logic        i_sb_param_exch_done,

    // SB outputs
    output logic       o_sb_start_param_exch,
    output logic       o_sb_msg_request,
    output SB_state    o_sb_state_tx,

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
    output Adapter_Response o_Adpater_LSM_response_type,
    output logic            o_uce_Adapter_timeout_non_active,
    output logic            o_uce_Adapter_timeout_active,
    output logic            o_Error_Valid,
    output logic            o_Link_Status,
    output logic            o_ce_Adapter_Transition_Retrain
);

    // current main state, next sub state
    Main_State cms, nms;

    // current sub state, next sub state
    logic [3:0] css, nss;

    // internal signal definitions
    logic Protocol_Active;
    logic sb_active_req_received, sb_active_rsp_received;

    // always request the FDI and RDI to be ungated
    assign o_rdi_lp_wake_req = 'b1;
    assign fdi_pl_clk_req = 'b1;

    // RDI outputs
    logic o_rdi_lp_linkerror_comb; 
    state_req o_rdi_lp_state_req_comb;

    // FDI outputs
    logic o_fdi_pl_stallreq_comb, o_fdi_pl_inband_pres_comb, o_fdi_pl_rx_active_req_comb;
    ll_state o_fdi_pl_state_sts_comb;
    // SB outputs
    logic o_sb_start_param_exch_comb, o_sb_msg_request_comb;
    SB_state o_sb_state_tx_comb;

    // MB outputs
    logic o_MB_flush_comb, o_MB_retry_clean_boundary_comb, o_MB_tx_enable_comb, o_MB_rx_enable_comb;

    // Regfile outputs
    logic o_uce_Adapter_timeout_non_active_comb,
          o_uce_Adapter_timeout_active_comb,
          o_Error_Valid_comb,
          o_Link_Status_comb,
          o_ce_Adapter_Transition_Retrain_comb;

    Adapter_Response  o_Adpater_LSM_response_type_comb;

    // next state
    always_comb begin
        nms = cms;
        nss = css;

        // RDI outputs
        o_rdi_lp_linkerror_comb = o_rdi_lp_linkerror;
        o_rdi_lp_state_req_comb = o_rdi_lp_state_req;

        // FDI outputs
        o_fdi_pl_stallreq_comb      = o_fdi_pl_stallreq;
        o_fdi_pl_state_sts_comb     = o_fdi_pl_state_sts;
        o_fdi_pl_inband_pres_comb   = o_fdi_pl_inband_pres;
        o_fdi_pl_rx_active_req_comb = o_fdi_pl_rx_active_req;

        // SB outputs
        o_sb_start_param_exch_comb = o_sb_start_param_exch;
        o_sb_msg_request_comb      = o_sb_msg_request;
        o_sb_state_tx_comb         = o_sb_state_tx;

        // MB outputs
        o_MB_flush_comb                = o_MB_flush;
        o_MB_retry_clean_boundary_comb = o_MB_retry_clean_boundary;
        o_MB_tx_enable_comb            = o_MB_tx_enable;
        o_MB_rx_enable_comb            = o_MB_rx_enable;

        // Regfile outputs
        o_Adpater_LSM_response_type_comb      = o_Adpater_LSM_response_type;
        o_uce_Adapter_timeout_non_active_comb = o_uce_Adapter_timeout_non_active;
        o_uce_Adapter_timeout_active_comb     = o_uce_Adapter_timeout_active;
        o_Error_Valid_comb                    = o_Error_Valid;
        o_Link_Status_comb                    = o_Link_Status;
        o_ce_Adapter_Transition_Retrain_comb  = o_ce_Adapter_Transition_Retrain;

        case (cms)
            Reset: 
            case (css)
                Reset_SS: 
                    if (i_rdi_pl_state_sts == LL_Active) begin
                        nss = Param_exch_SS;
                    end
                    else begin
                        nss = Reset_SS;
                    end
                Param_exch_SS: 
                    if (i_sb_param_exch_done) begin
                        nss = Active_Entry_SS;
                    end
                    else begin
                        nss = Param_exch_SS;
                    end
                Active_Entry_SS:
                    if (Protocol_Active) begin
                        nss = SB_Active_Req_SS;
                    end
                    else if (sb_active_req_received && o_rdi_lp_clk_ack) begin
                        nss = rx_active_2_SS;
                    end
                    else begin
                        nss = Active_Entry_SS;
                    end
                SB_Active_Req_SS:
                    if (sb_active_rsp_received) begin
                        nss = Active_Req_Await_SS;
                    end 
                    else if (sb_active_req_received) begin
                        nss = rx_active_1_SS;
                    end
                    else begin
                        nss = SB_Active_Req_SS;
                    end
                Active_Req_Await_SS:
                    if (sb_active_req_received) begin
                        nss = rx_active_1_SS;
                    end
                    else begin
                        nss = Active_Req_Await_SS;
                    end
                rx_active_1_SS:
                    if (i_fdi_lp_rx_active_sts && sb_active_rsp_received) begin
                        nss = 'b0;
                        nms = Active;
                    end
                    else if (i_fdi_lp_rx_active_sts && ~sb_active_rsp_received) begin
                        nss = SB_rsp_recieved_SS;
                    end
                    else begin
                        nss = rx_active_1_SS;
                    end
                rx_active_2_SS:
                    if (i_fdi_lp_rx_active_sts) begin
                        nss = Await_FDI_Active_SS;
                    end
                    else begin
                        nss = rx_active_2_SS;
                    end
                Await_FDI_Active_SS:
                    if (i_fdi_lp_state_req == Req_Active) begin
                        nss = SB_rsp_recieved_SS;
                    end
                    else begin
                        nss = Await_FDI_Active_SS;
                    end
                SB_rsp_recieved_SS:
                    if (sb_active_rsp_received) begin
                        nss = 'b0;
                        nms = Active;
                    end
                    else begin
                        nss = SB_rsp_recieved_SS;
                    end
                default: begin
                    nss = 'b0; nms = Reset;
                end
            endcase
            default: begin
                nss = 'b0; nms = Reset;
            end
        endcase
    end

    // These signals only start being taken into account when the Main State is in 
    // Reset, otherwise they are zero
    always_ff @(negedge rst_n, posedge clk) begin
        if (~rst_n) begin
            Protocol_Active        <= 'b0;
            sb_active_req_received <= 'b0;
            sb_active_rsp_received <= 'b0;
        end
        else if (cms == Reset) begin
            Protocol_Active        <= Protocol_Active | (i_fdi_lp_state_req == Req_Active);
            sb_active_req_received <= sb_active_req_received | (i_sb_state_rx == SB_Req_Active);
            sb_active_rsp_received <= sb_active_rsp_received | (i_sb_state_rx == SB_Rsp_Active);
        end
        else begin
            Protocol_Active        <= 'b0;
            sb_active_req_received <= 'b0;
            sb_active_rsp_received <= 'b0;
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

    // ALSM outputs
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            // RDI outputs
            o_rdi_lp_linkerror <= 'b0;
            o_rdi_lp_state_req <= Req_NOP;

            // FDI outputs
            o_fdi_pl_stallreq      <= 'b0;
            o_fdi_pl_state_sts     <= LL_Reset;
            o_fdi_pl_inband_pres   <= 'b0;
            o_fdi_pl_rx_active_req <= 'b0;

            // SB outputs
            o_sb_start_param_exch <= 'b0;
            o_sb_msg_request      <= 'b0;
            o_sb_state_tx         <= SB_Req_Active;

            // MB outputs
            o_MB_flush                <= 'b0;
            o_MB_retry_clean_boundary <= 'b0;
            o_MB_tx_enable            <= 'b0;
            o_MB_rx_enable            <= 'b0;

            // Regfile outputs
            o_Adpater_LSM_response_type      <= Active_LSM_response_type;
            o_uce_Adapter_timeout_non_active <= 'b0;
            o_uce_Adapter_timeout_active     <= 'b0;
            o_Error_Valid                    <= 'b0;
            o_Link_Status                    <= 'b0;
            o_ce_Adapter_Transition_Retrain  <= 'b0;
        end
        else begin
            // RDI outputs
            o_rdi_lp_linkerror <= o_rdi_lp_linkerror_comb;
            o_rdi_lp_state_req <= o_rdi_lp_state_req_comb;

            // FDI outputs
            o_fdi_pl_stallreq      <= o_fdi_pl_stallreq_comb;
            o_fdi_pl_state_sts     <= o_fdi_pl_state_sts_comb;
            o_fdi_pl_inband_pres   <= o_fdi_pl_inband_pres_comb;
            o_fdi_pl_rx_active_req <= o_fdi_pl_rx_active_req_comb;

            // SB outputs
            o_sb_start_param_exch <= o_sb_start_param_exch_comb;
            o_sb_msg_request      <= o_sb_msg_request_comb;
            o_sb_state_tx         <= o_sb_state_tx_comb;

            // MB outputs
            o_MB_flush                <= o_MB_flush_comb;
            o_MB_retry_clean_boundary <= o_MB_retry_clean_boundary_comb;
            o_MB_tx_enable            <= o_MB_tx_enable_comb;
            o_MB_rx_enable            <= o_MB_rx_enable_comb;

            // Regfile outputs
            o_Adpater_LSM_response_type      <= o_Adpater_LSM_response_type_comb;
            o_uce_Adapter_timeout_non_active <= o_uce_Adapter_timeout_non_active_comb;
            o_uce_Adapter_timeout_active     <= o_uce_Adapter_timeout_active_comb;
            o_Error_Valid                    <= o_Error_Valid_comb;
            o_Link_Status                    <= o_Link_Status_comb;
            o_ce_Adapter_Transition_Retrain  <= o_ce_Adapter_Transition_Retrain_comb;
        end
    end
    // Registered signals
    always_ff @(negedge rst_n, posedge clk) begin
        if (~rst_n) begin
            o_fdi_pl_phyinrecenter <= 'b0; 
            o_fdi_pl_speedmode     <= 'b0;
            o_fdi_pl_max_speedmode <= 'b0;
            o_fdi_pl_lnk_cfg       <= 'b0;
            o_fdi_pl_phyinl1       <= 'b0;
            o_fdi_pl_phyinl2       <= 'b0;
            o_fdi_pl_wake_ack      <= 'b0;
            o_rdi_lp_clk_ack       <= 'b0;
        end
        else begin
            o_fdi_pl_phyinrecenter <= i_rdi_pl_phyinrecenter; 
            o_fdi_pl_speedmode     <= i_rdi_pl_speedmode;
            o_fdi_pl_max_speedmode <= (i_rdi_pl_speedmode > 'b101);
            o_fdi_pl_lnk_cfg       <= i_rdi_pl_lnk_cfg;
            o_fdi_pl_phyinl1       <= (i_rdi_pl_state_sts == LL_L1);
            o_fdi_pl_phyinl2       <= (i_rdi_pl_state_sts == LL_L2);
            o_fdi_pl_wake_ack      <= i_fdi_lp_wake_req;
            o_rdi_lp_clk_ack       <= i_rdi_pl_clk_req;
        end
    end
endmodule