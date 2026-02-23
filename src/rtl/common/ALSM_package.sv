package ALSM_package;

  // ------------------------------------------------------------
  // Adapter response type encodings
  // ------------------------------------------------------------
  typedef enum logic [2:0] {
    Active_LSM_response_type    = 3'b001,
    L1_LSM_response_type        = 3'b010,
    L2_LSM_response_type        = 3'b011,
    LinkReset_LSM_response_type = 3'b100,
    Disable_LSM_response_type   = 3'b101
  } Adapter_Response;

  // ------------------------------------------------------------
  // All lp_state_req encodings
  // ------------------------------------------------------------
  typedef enum logic [3:0] {
    Req_NOP       = 4'b0000,
    Req_Active    = 4'b0001,
    Req_L1        = 4'b0100,
    Req_L2        = 4'b1000,
    Req_LinkReset = 4'b1001,
    Req_Retrain   = 4'b1011,
    Req_Disable   = 4'b1100
  } state_req;

  // ------------------------------------------------------------
  // All pl_sts encodings
  // ------------------------------------------------------------
  typedef enum logic [3:0] {
    LL_Reset        = 4'b0000,
    LL_Active       = 4'b0001,
    LL_Active_PMNAK = 4'b0011,
    LL_L1           = 4'b0100,
    LL_L2           = 4'b1000,
    LL_LinkReset    = 4'b1001,
    LL_LinkError    = 4'b1010,
    LL_Retrain      = 4'b1011,
    LL_Disable      = 4'b1100
  } ll_state;

  // ------------------------------------------------------------
  // All valid sideband message encodings
  // ------------------------------------------------------------
  typedef enum {
    SB_None,
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
  } sb_state_msg_encoding;

  // ------------------------------------------------------------
  // Active Link State Machine sub-state encodings
  // ------------------------------------------------------------
  typedef enum {
    ALSM_Reset,
    ALSM_Param_exch,
    ALSM_Active_Entry,
    ALSM_SB_Active_Req,
    ALSM_Active_Req_Await,
    ALSM_rx_active_1,
    ALSM_SB_rsp_received,
    ALSM_rx_active_2,
    ALSM_Await_FDI_Active,
    ALSM_Active
  } ALSM_State;

endpackage : ALSM_package