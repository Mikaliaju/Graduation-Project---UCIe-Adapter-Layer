import UC_ALSM_package::*;
import UC_sb_pkg::*;

// typedef enum logic [2:0] {
// 	Active_LSM_response_type    = 'b001,
// 	L1_LSM_response_type        = 'b010,
// 	L2_LSM_response_type        = 'b011,
// 	LinkReset_LSM_response_type = 'b100,
// 	Disable_LSM_response_type   = 'b101
// } Adapter_Response;
// typedef enum logic [3:0] { 
// 	Req_NOP       = 'b0000,
// 	Req_Active    = 'b0001,
// 	Req_L1        = 'b0100,
// 	Req_L2        = 'b1000,
// 	Req_LinkReset = 'b1001,
// 	Req_Retrain   = 'b1011,
// 	Req_Disable   = 'b1100
// } state_req;
// typedef enum logic [3:0] { 
// 	LL_Reset        = 'b0000,
// 	LL_Active       = 'b0001,
// 	LL_Active_PMNAK = 'b0011,
// 	LL_L1           = 'b0100,
// 	LL_L2           = 'b1000,
// 	LL_LinkReset    = 'b1001,
// 	LL_LinkError    = 'b1010,
// 	LL_Retrain      = 'b1011,
// 	LL_Disable      = 'b1100
// } ll_state;
// typedef enum { 
// 	SB_None,
// 	SB_Req_Active,
// 	SB_Req_L1,
// 	SB_Req_L2,
// 	SB_Req_LinkReset,
// 	SB_Req_Disable,
// 	SB_Rsp_Active,
// 	SB_Rsp_L1,
// 	SB_Rsp_L2,
// 	SB_Rsp_LinkReset,
// 	SB_Rsp_Disable,
// 	SB_Rsp_PMNAK
// } sb_state_msg_encoding;
// typedef enum {
// 	ALSM_Reset,
// 	ALSM_Param_exch,
// 	ALSM_Active_Entry,
// 	ALSM_SB_Active_Req,
// 	ALSM_Active_Req_Await,
// 	ALSM_rx_active_1,
// 	ALSM_SB_rsp_received,
// 	ALSM_rx_active_2,
// 	ALSM_Await_FDI_Active,
// 	ALSM_Active,
// 	ALSM_Stall,
// 	ALSM_Retrain,
// 	ALSM_LinkReset_Entry,      // handles drain + SB req/await combined
// 	ALSM_LinkReset_Transition,
// 	ALSM_LinkReset,
// 	ALSM_Disable_Entry,        // handles drain + SB req/await combined
// 	ALSM_Disable_Transition,
// 	ALSM_Disable,
// 	ALSM_Error_Entry,
// 	ALSM_LinkError,
// 	ALSM_Protocol_Exit,
// 	ALSM_Detected_Nop
// } ALSM_State;


module UC_ALSM_tb;

  // Parameters
  localparam CLK_PERIOD = 2;

  //Commmon Ports
  logic                 i_clk;
  logic                 i_rst_n;
  logic                 i_init;
  logic                 i_rdi_pl_inband_pres;
  logic                 i_rdi_pl_phyinrecenter;
  logic [2:0]           i_rdi_pl_speedmode;
  logic [2:0]           i_rdi_pl_lnk_cfg;
  logic                 i_rdi_pl_clk_req;
  logic                 i_rdi_pl_error;
  logic                 i_rdi_pl_trdy;
  logic                 i_fdi_lp_wake_req;


  // UP only ports
  ll_state              i_rdi_pl_state_sts_UP;
  logic                 i_rdi_pl_wake_ack_UP;
  logic                 i_rdi_pl_stall_req_UP;
  logic                 o_rdi_lp_clk_ack_UP;
  logic                 o_rdi_lp_wake_req_UP;
  logic                 o_rdi_lp_linkerror_UP;
  state_req             o_rdi_lp_state_req_UP;
  logic                 o_rdi_lp_stall_ack_UP;
  state_req             i_fdi_lp_state_req_UP;
  logic                 i_fdi_lp_linkerror_UP;
  logic                 i_fdi_lp_rx_active_sts_UP;
  logic                 i_fdi_lp_stall_ack_UP;
  logic                 i_fdi_lp_clk_ack_UP;
  logic                 o_fdi_pl_stallreq_UP;
  logic                 o_fdi_pl_phyinrecenter_UP;
  logic                 o_fdi_pl_phyinl1_UP;
  logic                 o_fdi_pl_phyinl2_UP;
  logic [2:0]           o_fdi_pl_speedmode_UP;
  logic                 o_fdi_pl_max_speedmode_UP;
  logic [2:0]           o_fdi_pl_lnk_cfg_UP;
  ll_state              o_fdi_pl_state_sts_UP;
  logic                 o_fdi_pl_inband_pres_UP;
  logic                 o_fdi_pl_rx_active_req_UP;
  logic                 o_fdi_pl_clk_req_UP;
  logic                 o_fdi_pl_wake_ack_UP;
  sb_state_msg_encoding i_sb_state_rx_UP;
  logic                 i_sb_param_exch_done_UP;
  logic                 o_sb_start_param_exch_UP;
  sb_state_msg_encoding o_sb_state_tx_UP;
  logic                 i_mb_retry_clean_boundary_done_UP;
  logic                 i_mb_flush_done_UP;
  logic                 i_mb_retrain_trigger_UP;
  logic                 i_mb_rx_path_empty_UP;
  logic                 o_mb_flush_UP;
  logic                 o_mb_retry_clean_boundary_UP;
  logic                 o_mb_tx_enable_UP;
  logic                 o_mb_rx_enable_UP;
  logic                 i_regfile_linkerror_UP;
  logic                 i_regfile_start_retrain_UP;
  Adapter_Response      o_adpater_lsm_response_type_UP;
  logic                 o_uce_adapter_timeout_non_active_UP;
  logic                 o_uce_adapter_timeout_active_UP;
  logic                 o_error_valid_UP;
  logic                 o_link_status_UP;
  logic                 o_ce_adapter_transition_retrain_UP;

  // DP only ports
  ll_state              i_rdi_pl_state_sts_DP;
  logic                 i_rdi_pl_wake_ack_DP;
  logic                 i_rdi_pl_stall_req_DP;
  logic                 o_rdi_lp_clk_ack_DP;
  logic                 o_rdi_lp_wake_req_DP;
  logic                 o_rdi_lp_linkerror_DP;
  state_req             o_rdi_lp_state_req_DP;
  logic                 o_rdi_lp_stall_ack_DP;
  state_req             i_fdi_lp_state_req_DP;
  logic                 i_fdi_lp_linkerror_DP;
  logic                 i_fdi_lp_rx_active_sts_DP;
  logic                 i_fdi_lp_stall_ack_DP;
  logic                 i_fdi_lp_clk_ack_DP;
  logic                 o_fdi_pl_stallreq_DP;
  logic                 o_fdi_pl_phyinrecenter_DP;
  logic                 o_fdi_pl_phyinl1_DP;
  logic                 o_fdi_pl_phyinl2_DP;
  logic [2:0]           o_fdi_pl_speedmode_DP;
  logic                 o_fdi_pl_max_speedmode_DP;
  logic [2:0]           o_fdi_pl_lnk_cfg_DP;
  ll_state              o_fdi_pl_state_sts_DP;
  logic                 o_fdi_pl_inband_pres_DP;
  logic                 o_fdi_pl_rx_active_req_DP;
  logic                 o_fdi_pl_clk_req_DP;
  logic                 o_fdi_pl_wake_ack_DP;
  sb_state_msg_encoding i_sb_state_rx_DP;
  logic                 i_sb_param_exch_done_DP;
  logic                 o_sb_start_param_exch_DP;
  sb_state_msg_encoding o_sb_state_tx_DP;
  logic                 i_mb_retry_clean_boundary_done_DP;
  logic                 i_mb_flush_done_DP;
  logic                 i_mb_retrain_trigger_DP;
  logic                 i_mb_rx_path_empty_DP;
  logic                 o_mb_flush_DP;
  logic                 o_mb_retry_clean_boundary_DP;
  logic                 o_mb_tx_enable_DP;
  logic                 o_mb_rx_enable_DP;
  logic                 i_regfile_linkerror_DP;
  logic                 i_regfile_start_retrain_DP;
  Adapter_Response      o_adpater_lsm_response_type_DP;
  logic                 o_uce_adapter_timeout_non_active_DP;
  logic                 o_uce_adapter_timeout_active_DP;
  logic                 o_error_valid_DP;
  logic                 o_link_status_DP;
  logic                 o_ce_adapter_transition_retrain_DP;

  logic                 i_regfile_start_link_train_UP;
  logic                 o_regfile_start_link_train_clear_UP;
  logic                 o_mb_drain_UP;
  logic                 i_mb_drain_done_UP;

  logic                 i_regfile_start_link_train_DP;
  logic                 o_regfile_start_link_train_clear_DP;
  logic                 o_mb_drain_DP;
  logic                 i_mb_drain_done_DP;

  UC_ALSM  U0_ALSM_UP (
    .i_clk                             (i_clk),
    .i_rst_n                           (i_rst_n),
    .i_init                            (i_init),
    .i_rdi_pl_inband_pres              (i_rdi_pl_inband_pres),
    .i_rdi_pl_phyinrecenter            (i_rdi_pl_phyinrecenter),
    .i_rdi_pl_speedmode                (i_rdi_pl_speedmode),
    .i_rdi_pl_lnk_cfg                  (i_rdi_pl_lnk_cfg),
    .i_rdi_pl_state_sts                (i_rdi_pl_state_sts_UP),
    .i_rdi_pl_clk_req                  (i_rdi_pl_clk_req),
    .i_rdi_pl_wake_ack                 (i_rdi_pl_wake_ack_UP),
    .i_rdi_pl_stall_req                (i_rdi_pl_stall_req_UP),
    .i_rdi_pl_error                    (i_rdi_pl_error),
    .i_rdi_pl_trdy                     (i_rdi_pl_trdy),
    .o_rdi_lp_clk_ack                  (o_rdi_lp_clk_ack_UP),
    .o_rdi_lp_wake_req                 (o_rdi_lp_wake_req_UP),
    .o_rdi_lp_linkerror                (o_rdi_lp_linkerror_UP),
    .o_rdi_lp_state_req                (o_rdi_lp_state_req_UP),
    .o_rdi_lp_stall_ack                (o_rdi_lp_stall_ack_UP),
    .i_fdi_lp_state_req                (i_fdi_lp_state_req_UP),
    .i_fdi_lp_linkerror                (i_fdi_lp_linkerror_UP),
    .i_fdi_lp_rx_active_sts            (i_fdi_lp_rx_active_sts_UP),
    .i_fdi_lp_stall_ack                (i_fdi_lp_stall_ack_UP),
    .i_fdi_lp_clk_ack                  (i_fdi_lp_clk_ack_UP),
    .i_fdi_lp_wake_req                 (i_fdi_lp_wake_req),
    .o_fdi_pl_stallreq                 (o_fdi_pl_stallreq_UP),
    .o_fdi_pl_phyinrecenter            (o_fdi_pl_phyinrecenter_UP),
    .o_fdi_pl_phyinl1                  (o_fdi_pl_phyinl1_UP),
    .o_fdi_pl_phyinl2                  (o_fdi_pl_phyinl2_UP),
    .o_fdi_pl_speedmode                (o_fdi_pl_speedmode_UP),
    .o_fdi_pl_max_speedmode            (o_fdi_pl_max_speedmode_UP),
    .o_fdi_pl_lnk_cfg                  (o_fdi_pl_lnk_cfg_UP),
    .o_fdi_pl_state_sts                (o_fdi_pl_state_sts_UP),
    .o_fdi_pl_inband_pres              (o_fdi_pl_inband_pres_UP),
    .o_fdi_pl_rx_active_req            (o_fdi_pl_rx_active_req_UP),
    .o_fdi_pl_clk_req                  (o_fdi_pl_clk_req_UP),
    .o_fdi_pl_wake_ack                 (o_fdi_pl_wake_ack_UP),
    .i_sb_state_rx                     (i_sb_state_rx_UP),
    .i_sb_param_exch_done              (i_sb_param_exch_done_UP),
    .o_sb_start_param_exch             (o_sb_start_param_exch_UP),
    .o_sb_state_tx                     (o_sb_state_tx_UP),
    .i_mb_retry_clean_boundary_done    (i_mb_retry_clean_boundary_done_UP),
    .i_mb_flush_done                   (i_mb_flush_done_UP),
    .i_mb_retrain_trigger              (i_mb_retrain_trigger_UP),
    .i_mb_drain_done                   (i_mb_drain_done_DP),
    .o_mb_flush                        (o_mb_flush_UP),
    .o_mb_retry_clean_boundary         (o_mb_retry_clean_boundary_UP),
    .o_mb_tx_enable                    (o_mb_tx_enable_UP),
    .o_mb_rx_enable                    (o_mb_rx_enable_UP),
    .o_mb_drain                        (o_mb_drain_UP),
    .i_regfile_linkerror               (i_regfile_linkerror_UP),
    .i_regfile_start_retrain           (i_regfile_start_retrain_UP),
    .i_regfile_start_link_train        (i_regfile_start_link_train_UP),
    .o_adpater_lsm_response_type       (o_adpater_lsm_response_type_UP),
    .o_uce_adapter_timeout_non_active  (o_uce_adapter_timeout_non_active_UP),
    .o_uce_adapter_timeout_active      (o_uce_adapter_timeout_active_UP),
    .o_error_valid                     (o_error_valid_UP),
    .o_link_status                     (o_link_status_UP),
    .o_ce_adapter_transition_retrain   (o_ce_adapter_transition_retrain_UP),
    .o_regfile_start_link_train_clear  (o_regfile_start_link_train_clear_UP)
  );

  UC_ALSM  U1_ALSM_DP (
    .i_clk                             (i_clk),
    .i_rst_n                           (i_rst_n),
    .i_init                            (i_init),
    .i_rdi_pl_inband_pres              (i_rdi_pl_inband_pres),
    .i_rdi_pl_phyinrecenter            (i_rdi_pl_phyinrecenter),
    .i_rdi_pl_speedmode                (i_rdi_pl_speedmode),
    .i_rdi_pl_lnk_cfg                  (i_rdi_pl_lnk_cfg),
    .i_rdi_pl_state_sts                (i_rdi_pl_state_sts_DP),
    .i_rdi_pl_clk_req                  (i_rdi_pl_clk_req),
    .i_rdi_pl_wake_ack                 (i_rdi_pl_wake_ack_DP),
    .i_rdi_pl_stall_req                (i_rdi_pl_stall_req_DP),
    .i_rdi_pl_error                    (i_rdi_pl_error),
    .i_rdi_pl_trdy                     (i_rdi_pl_trdy),
    .o_rdi_lp_clk_ack                  (o_rdi_lp_clk_ack_DP),
    .o_rdi_lp_wake_req                 (o_rdi_lp_wake_req_DP),
    .o_rdi_lp_linkerror                (o_rdi_lp_linkerror_DP),
    .o_rdi_lp_state_req                (o_rdi_lp_state_req_DP),
    .o_rdi_lp_stall_ack                (o_rdi_lp_stall_ack_DP),
    .i_fdi_lp_state_req                (i_fdi_lp_state_req_DP),
    .i_fdi_lp_linkerror                (i_fdi_lp_linkerror_DP),
    .i_fdi_lp_rx_active_sts            (i_fdi_lp_rx_active_sts_DP),
    .i_fdi_lp_stall_ack                (i_fdi_lp_stall_ack_DP),
    .i_fdi_lp_clk_ack                  (i_fdi_lp_clk_ack_DP),
    .i_fdi_lp_wake_req                 (i_fdi_lp_wake_req),
    .o_fdi_pl_stallreq                 (o_fdi_pl_stallreq_DP),
    .o_fdi_pl_phyinrecenter            (o_fdi_pl_phyinrecenter_DP),
    .o_fdi_pl_phyinl1                  (o_fdi_pl_phyinl1_DP),
    .o_fdi_pl_phyinl2                  (o_fdi_pl_phyinl2_DP),
    .o_fdi_pl_speedmode                (o_fdi_pl_speedmode_DP),
    .o_fdi_pl_max_speedmode            (o_fdi_pl_max_speedmode_DP),
    .o_fdi_pl_lnk_cfg                  (o_fdi_pl_lnk_cfg_DP),
    .o_fdi_pl_state_sts                (o_fdi_pl_state_sts_DP),
    .o_fdi_pl_inband_pres              (o_fdi_pl_inband_pres_DP),
    .o_fdi_pl_rx_active_req            (o_fdi_pl_rx_active_req_DP),
    .o_fdi_pl_clk_req                  (o_fdi_pl_clk_req_DP),
    .o_fdi_pl_wake_ack                 (o_fdi_pl_wake_ack_DP),
    .i_sb_state_rx                     (i_sb_state_rx_DP),
    .i_sb_param_exch_done              (i_sb_param_exch_done_DP),
    .o_sb_start_param_exch             (o_sb_start_param_exch_DP),
    .o_sb_state_tx                     (o_sb_state_tx_DP),
    .i_mb_retry_clean_boundary_done    (i_mb_retry_clean_boundary_done_DP),
    .i_mb_flush_done                   (i_mb_flush_done_DP),
    .i_mb_retrain_trigger              (i_mb_retrain_trigger_DP),
    .i_mb_drain_done                   (i_mb_drain_done_DP),
    .o_mb_flush                        (o_mb_flush_DP),
    .o_mb_retry_clean_boundary         (o_mb_retry_clean_boundary_DP),
    .o_mb_tx_enable                    (o_mb_tx_enable_DP),
    .o_mb_rx_enable                    (o_mb_rx_enable_DP),
    .o_mb_drain                        (o_mb_drain_DP),
    .i_regfile_linkerror               (i_regfile_linkerror_DP),
    .i_regfile_start_retrain           (i_regfile_start_retrain_DP),
    .i_regfile_start_link_train        (i_regfile_start_link_train_DP),
    .o_adpater_lsm_response_type       (o_adpater_lsm_response_type_DP),
    .o_uce_adapter_timeout_non_active  (o_uce_adapter_timeout_non_active_DP),
    .o_uce_adapter_timeout_active      (o_uce_adapter_timeout_active_DP),
    .o_error_valid                     (o_error_valid_DP),
    .o_link_status                     (o_link_status_DP),
    .o_ce_adapter_transition_retrain   (o_ce_adapter_transition_retrain_DP),
    .o_regfile_start_link_train_clear  (o_regfile_start_link_train_clear_DP)
  );


initial begin
  i_clk = 'b0;
  forever begin
    #(CLK_PERIOD/2)
    i_clk = ~i_clk;
  end
end

assign i_sb_state_rx_UP = o_sb_state_tx_DP;
assign i_sb_state_rx_DP = o_sb_state_tx_UP;

always_ff @(posedge i_clk or negedge i_rst_n) begin
  if (~i_rst_n || ~i_init) begin
    i_rdi_pl_wake_ack_UP              <= 'b0;
    i_fdi_lp_clk_ack_UP               <= 'b0;
    i_mb_retry_clean_boundary_done_UP <= 'b0;
    i_fdi_lp_rx_active_sts_UP         <= 'b0;
    i_sb_param_exch_done_UP           <= 'b0;

    i_rdi_pl_wake_ack_DP              <= 'b0;
    i_fdi_lp_clk_ack_DP               <= 'b0;
    i_mb_retry_clean_boundary_done_DP <= 'b0;
    i_fdi_lp_rx_active_sts_DP         <= 'b0;
    i_sb_param_exch_done_DP           <= 'b0;
  end
  else begin
    i_rdi_pl_wake_ack_UP              <= o_rdi_lp_wake_req_UP;
    i_fdi_lp_clk_ack_UP               <= o_fdi_pl_clk_req_UP;
    i_mb_retry_clean_boundary_done_UP <= o_mb_retry_clean_boundary_UP;
    i_fdi_lp_rx_active_sts_UP         <= o_fdi_pl_rx_active_req_UP;
    i_sb_param_exch_done_UP           <= 'b1;

    i_rdi_pl_wake_ack_DP              <= o_rdi_lp_wake_req_DP;
    i_fdi_lp_clk_ack_DP               <= o_fdi_pl_clk_req_DP;
    i_mb_retry_clean_boundary_done_DP <= o_mb_retry_clean_boundary_DP;
    i_fdi_lp_rx_active_sts_DP         <= o_fdi_pl_rx_active_req_DP;
    i_sb_param_exch_done_DP           <= 'b1;
  end
end

assign i_fdi_lp_wake_req = 'b1;
assign i_rdi_pl_clk_req = 'b1;

initial begin : BOTH_ALSM_TEST
  reset_values();
  bringup_UP_first();
  // bringup_both_at_same_time();
  retrain_entry_both();
  bringup_both_at_same_time();
  link_error_entry_both();
  bringup_both_at_same_time();

  $stop();
  $finish();
end

task link_error_entry_both();
  i_regfile_linkerror_UP = 'b1;
  @(negedge i_clk);
  i_rdi_pl_state_sts_UP = LL_LinkError;
  repeat(2) begin
    @(negedge i_clk);
  end
  assert(o_fdi_pl_state_sts_UP == LL_LinkError);
  i_rdi_pl_state_sts_DP = LL_LinkError;
  repeat(3) begin
    @(negedge i_clk);
  end
  i_fdi_lp_state_req_UP = Req_NOP;
  i_fdi_lp_state_req_DP = Req_NOP;
  assert(o_fdi_pl_state_sts_UP == LL_LinkError);
  repeat(10) begin
    @(negedge i_clk);
  end
  i_rdi_pl_state_sts_DP = LL_Reset;
  i_regfile_linkerror_UP = 'b0;
  i_fdi_lp_state_req_UP = Req_Active;
  repeat(2) begin
    @(negedge i_clk);
  end
  assert(o_rdi_lp_state_req_UP == Req_Active);
  i_rdi_pl_state_sts_UP = LL_Reset;
  repeat(2) begin
    @(negedge i_clk);
  end
  assert(o_fdi_pl_state_sts_UP == LL_Reset);
  i_fdi_lp_state_req_UP = Req_NOP;
  @(negedge i_clk);
  i_fdi_lp_state_req_UP = Req_Active;
  repeat(2) begin
    @(negedge i_clk);
  end
  assert(o_rdi_lp_state_req_UP == Req_Active);
endtask

task retrain_entry_both();
  repeat(2) begin
    @(negedge i_clk);
  end
  i_mb_retrain_trigger_UP = 'b1;
  @(negedge i_clk);
  i_mb_retrain_trigger_UP = 'b0;
  assert(o_rdi_lp_state_req_UP == Req_Retrain);
  i_rdi_pl_stall_req_UP = 'b1;
  i_rdi_pl_stall_req_DP = 'b1;
  repeat(2) begin
    @(negedge i_clk);
  end
  assert(o_rdi_lp_clk_ack_UP);
  assert(o_rdi_lp_clk_ack_DP);
  i_rdi_pl_stall_req_UP = 'b0;
  i_rdi_pl_stall_req_DP = 'b0;
  i_rdi_pl_state_sts_UP = LL_Retrain;
  i_rdi_pl_state_sts_DP = LL_Retrain;
  repeat(4) begin
    @(negedge i_clk);
  end
  assert(~o_mb_rx_enable_UP);
  assert(~o_mb_tx_enable_UP);
  assert(~o_mb_rx_enable_DP);
  assert(~o_mb_tx_enable_DP);
  assert(o_ce_adapter_transition_retrain_UP);
  assert(o_ce_adapter_transition_retrain_DP);
  assert(o_fdi_pl_state_sts_UP == LL_Retrain);
  assert(o_fdi_pl_state_sts_DP == LL_Retrain);
endtask

task bringup_both_at_same_time();
  i_rdi_pl_inband_pres  = 'b1;
  i_rdi_pl_state_sts_UP = LL_Active;
  i_rdi_pl_state_sts_DP = LL_Active;
  repeat(2) begin
    @(negedge i_clk);
  end
  assert (o_fdi_pl_inband_pres_UP);
  assert (o_fdi_pl_inband_pres_DP);
  i_fdi_lp_state_req_UP = Req_Active;
  i_fdi_lp_state_req_DP = Req_Active;
  repeat(5) begin
    @(negedge i_clk);
  end
  assert(o_fdi_pl_state_sts_UP == LL_Active);
  assert(o_fdi_pl_state_sts_DP == LL_Active);
endtask

task bringup_UP_first();
  i_rdi_pl_inband_pres  = 'b1;
  i_rdi_pl_state_sts_UP = LL_Active;
  i_rdi_pl_state_sts_DP = LL_Active;
  repeat(2) begin
    @(negedge i_clk);
  end
  assert (o_fdi_pl_inband_pres_UP);
  assert (o_fdi_pl_inband_pres_DP);
  i_fdi_lp_state_req_UP = Req_Active;
  repeat(3) begin
    @(negedge i_clk);
  end
  i_fdi_lp_state_req_DP = Req_Active;
  repeat(8) begin
    @(negedge i_clk);
  end
  assert(o_fdi_pl_state_sts_UP == LL_Active);
  assert(o_fdi_pl_state_sts_DP == LL_Active);
endtask

task reset_values();
  i_rst_n                        = 'b0;
  i_init                         = 'b0;
  i_rdi_pl_inband_pres           = 'b0;
  i_rdi_pl_phyinrecenter         = 'b0;
  i_rdi_pl_speedmode             = 'b0;
  i_rdi_pl_lnk_cfg               = 'b0;
  i_rdi_pl_trdy                  = 'b0;
  i_rdi_pl_error                 = 'b0;

  i_rdi_pl_state_sts_UP          = LL_Reset;
  i_regfile_linkerror_UP         = 'b0;
  i_fdi_lp_state_req_UP          = Req_NOP;
  i_fdi_lp_linkerror_UP          = 'b0;
  i_fdi_lp_stall_ack_UP          = 'b0;
  // i_sb_state_rx_UP               = SB_None;
  i_sb_param_exch_done_UP        = 'b0;
  i_mb_flush_done_UP             = 'b0;
  i_mb_retrain_trigger_UP        = 'b0;
  i_mb_rx_path_empty_UP          = 'b0;
  i_rdi_pl_stall_req_UP          = 'b0;
  i_regfile_start_retrain_UP     = 'b0;
  i_mb_drain_done_UP             = 'b0;
  i_regfile_start_link_train_UP  = 'b0;

  i_rdi_pl_state_sts_DP          = LL_Reset;
  i_regfile_linkerror_DP         = 'b0;
  i_fdi_lp_state_req_DP          = Req_NOP;
  i_fdi_lp_linkerror_DP          = 'b0;
  i_fdi_lp_stall_ack_DP          = 'b0;
  // i_sb_state_rx_DP               = SB_None;
  i_sb_param_exch_done_DP        = 'b0;
  i_mb_flush_done_DP             = 'b0;
  i_mb_retrain_trigger_DP        = 'b0;
  i_mb_rx_path_empty_DP          = 'b0;
  i_rdi_pl_stall_req_DP          = 'b0;
  i_regfile_start_retrain_DP     = 'b0;
  i_mb_drain_done_DP             = 'b0;
  i_regfile_start_link_train_DP  = 'b0;

  repeat(2) begin
    @(negedge i_clk);
  end
  i_rst_n = 'b1;
  i_init = 'b1;
  repeat(2) begin
    @(negedge i_clk);
  end
endtask

task rdi_active_UP();
  @(negedge i_clk);
  i_rdi_pl_inband_pres = 'b1;
  i_rdi_pl_state_sts_UP = LL_Active;
  i_rdi_pl_trdy = 'b1;
endtask

endmodule