import UC_ALSM_package::*;

// typedef enum logic [2:0] {
// 	Active_LSM_response_type    = 'b001,
// 	L1_LSM_response_type        = 'b010,
// 	L2_LSM_response_type        = 'b011,
// 	LinkReset_LSM_response_type = 'b100,
// 	Disable_LSM_response_type   = 'b101
// } Adapter_Response;
// // all lp_state_req encodings
// typedef enum logic [3:0] { 
// 	Req_NOP       = 'b0000,
// 	Req_Active    = 'b0001,
// 	Req_L1        = 'b0100,
// 	Req_L2        = 'b1000,
// 	Req_LinkReset = 'b1001,
// 	Req_Retrain   = 'b1011,
// 	Req_Disable   = 'b1100
// } state_req;
// // all pl_sts encodings
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
// // all valid sb message encodings
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
// // ------------------------------------------------------------
// // Adapter Link State Machine state encodings
// // ------------------------------------------------------------
// typedef enum {
//   ALSM_Reset,
//   ALSM_Param_exch,
//   ALSM_Active_Entry,
//   ALSM_SB_Active_Req,
//   ALSM_Active_Req_Await,
//   ALSM_rx_active_1,
//   ALSM_SB_rsp_received,
//   ALSM_rx_active_2,
//   ALSM_Await_FDI_Active,
//   ALSM_Active,
//   ALSM_Stall,
//   ALSM_Retrain,
//   ALSM_Error_Entry,
//   ALSM_LinkError,
//   ALSM_Protocol_Exit,
//   ALSM_Detected_Nop
// } ALSM_State;


module UC_ALSM_tb;

  // Parameters
  localparam CLK_PERIOD = 2;

  //Ports
  logic i_clk;
  logic i_rst_n;
  logic i_init;
  logic i_rdi_pl_inband_pres;
  logic i_rdi_pl_phyinrecenter;
  logic [2:0] i_rdi_pl_speedmode;
  logic [2:0] i_rdi_pl_lnk_cfg;
  ll_state i_rdi_pl_state_sts;
  logic i_rdi_pl_clk_req;
  logic i_rdi_pl_wake_ack;
  logic i_rdi_pl_stall_req;
  logic i_rdi_pl_error;
  logic i_rdi_pl_trdy;
  logic o_rdi_lp_clk_ack;
  logic o_rdi_lp_wake_req;
  logic o_rdi_lp_linkerror;
  state_req o_rdi_lp_state_req;
  logic o_rdi_lp_stall_ack;
  state_req i_fdi_lp_state_req;
  logic i_fdi_lp_linkerror;
  logic i_fdi_lp_rx_active_sts;
  logic i_fdi_lp_stall_ack;
  logic i_fdi_lp_clk_ack;
  logic i_fdi_lp_wake_req;
  logic o_fdi_pl_stallreq;
  logic o_fdi_pl_phyinrecenter;
  logic o_fdi_pl_phyinl1;
  logic o_fdi_pl_phyinl2;
  logic [2:0] o_fdi_pl_speedmode;
  logic o_fdi_pl_max_speedmode;
  logic [2:0] o_fdi_pl_lnk_cfg;
  ll_state o_fdi_pl_state_sts;
  logic o_fdi_pl_inband_pres;
  logic o_fdi_pl_rx_active_req;
  logic o_fdi_pl_clk_req;
  logic o_fdi_pl_wake_ack;
  sb_state_msg_encoding i_sb_state_rx;
  logic i_sb_param_exch_done;
  logic o_sb_start_param_exch;
  sb_state_msg_encoding o_sb_state_tx;
  logic i_mb_retry_clean_boundary_done;
  logic i_mb_flush_done;
  logic i_mb_retrain_trigger;
  logic i_mb_rx_path_empty;
  logic o_mb_flush;
  logic o_mb_retry_clean_boundary;
  logic o_mb_tx_enable;
  logic o_mb_rx_enable;
  logic i_regfile_linkerror;
  logic i_regfile_start_retrain;
  Adapter_Response o_adpater_lsm_response_type;
  logic o_uce_adapter_timeout_non_active;
  logic o_uce_adapter_timeout_active;
  logic o_error_valid;
  logic o_link_status;
  logic o_ce_adapter_transition_retrain;

  UC_ALSM  U0_ALSM_UP (
    .i_clk                             (i_clk),
    .i_rst_n                           (i_rst_n),
    .i_init                            (i_init),
    .i_rdi_pl_inband_pres              (i_rdi_pl_inband_pres),
    .i_rdi_pl_phyinrecenter            (i_rdi_pl_phyinrecenter),
    .i_rdi_pl_speedmode                (i_rdi_pl_speedmode),
    .i_rdi_pl_lnk_cfg                  (i_rdi_pl_lnk_cfg),
    .i_rdi_pl_state_sts                (i_rdi_pl_state_sts),
    .i_rdi_pl_clk_req                  (i_rdi_pl_clk_req),
    .i_rdi_pl_wake_ack                 (i_rdi_pl_wake_ack),
    .i_rdi_pl_stall_req                (i_rdi_pl_stall_req),
    .i_rdi_pl_error                    (i_rdi_pl_error),
    .i_rdi_pl_trdy                     (i_rdi_pl_trdy),
    .o_rdi_lp_clk_ack                  (o_rdi_lp_clk_ack),
    .o_rdi_lp_wake_req                 (o_rdi_lp_wake_req),
    .o_rdi_lp_linkerror                (o_rdi_lp_linkerror),
    .o_rdi_lp_state_req                (o_rdi_lp_state_req),
    .o_rdi_lp_stall_ack                (o_rdi_lp_stall_ack),
    .i_fdi_lp_state_req                (i_fdi_lp_state_req),
    .i_fdi_lp_linkerror                (i_fdi_lp_linkerror),
    .i_fdi_lp_rx_active_sts            (i_fdi_lp_rx_active_sts),
    .i_fdi_lp_stall_ack                (i_fdi_lp_stall_ack),
    .i_fdi_lp_clk_ack                  (i_fdi_lp_clk_ack),
    .i_fdi_lp_wake_req                 (i_fdi_lp_wake_req),
    .o_fdi_pl_stallreq                 (o_fdi_pl_stallreq),
    .o_fdi_pl_phyinrecenter            (o_fdi_pl_phyinrecenter),
    .o_fdi_pl_phyinl1                  (o_fdi_pl_phyinl1),
    .o_fdi_pl_phyinl2                  (o_fdi_pl_phyinl2),
    .o_fdi_pl_speedmode                (o_fdi_pl_speedmode),
    .o_fdi_pl_max_speedmode            (o_fdi_pl_max_speedmode),
    .o_fdi_pl_lnk_cfg                  (o_fdi_pl_lnk_cfg),
    .o_fdi_pl_state_sts                (o_fdi_pl_state_sts),
    .o_fdi_pl_inband_pres              (o_fdi_pl_inband_pres),
    .o_fdi_pl_rx_active_req            (o_fdi_pl_rx_active_req),
    .o_fdi_pl_clk_req                  (o_fdi_pl_clk_req),
    .o_fdi_pl_wake_ack                 (o_fdi_pl_wake_ack),
    .i_sb_state_rx                     (i_sb_state_rx),
    .i_sb_param_exch_done              (i_sb_param_exch_done),
    .o_sb_start_param_exch             (o_sb_start_param_exch),
    .o_sb_state_tx                     (o_sb_state_tx),
    .i_mb_retry_clean_boundary_done    (i_mb_retry_clean_boundary_done),
    .i_mb_flush_done                   (i_mb_flush_done),
    .i_mb_retrain_trigger              (i_mb_retrain_trigger),
    .i_mb_rx_path_empty                (i_mb_rx_path_empty),
    .o_mb_flush                        (o_mb_flush),
    .o_mb_retry_clean_boundary         (o_mb_retry_clean_boundary),
    .o_mb_tx_enable                    (o_mb_tx_enable),
    .o_mb_rx_enable                    (o_mb_rx_enable),
    .i_regfile_linkerror               (i_regfile_linkerror),
    .i_regfile_start_retrain           (i_regfile_start_retrain),
    .o_adpater_lsm_response_type       (o_adpater_lsm_response_type),
    .o_uce_adapter_timeout_non_active  (o_uce_adapter_timeout_non_active),
    .o_uce_adapter_timeout_active      (o_uce_adapter_timeout_active),
    .o_error_valid                     (o_error_valid),
    .o_link_status                     (o_link_status),
    .o_ce_adapter_transition_retrain   (o_ce_adapter_transition_retrain)
  );


initial begin
  i_clk = 'b0;
  forever begin
    #(CLK_PERIOD/2)
    i_clk = ~i_clk;
  end
end

always_ff @(posedge i_clk or negedge i_rst_n) begin
  if (~i_rst_n || ~i_init) begin
    i_rdi_pl_wake_ack <= 'b0;
    i_fdi_lp_clk_ack <= 'b0;
    i_mb_retry_clean_boundary_done <= 'b0;
    i_fdi_lp_rx_active_sts         <= 'b0;
  end
  else begin
    i_rdi_pl_wake_ack <= o_rdi_lp_wake_req;
    i_fdi_lp_clk_ack <= o_fdi_pl_clk_req;
    i_mb_retry_clean_boundary_done <= o_mb_retry_clean_boundary;
    i_fdi_lp_rx_active_sts         <= o_fdi_pl_rx_active_req;
  end
end

assign i_fdi_lp_wake_req = 'b1;
assign i_rdi_pl_clk_req = 'b1;

initial begin
  reset_values();
  rdi_active();
  parameter_exchange();
  local_die_start_scenario();
  // remote_die_start_scenario();
  retratin_to_active();
  protocol_exit_linkerror();
  $stop();
  $finish();
end

task reset_values();
  i_rst_n                        = 'b0;
  i_init                         = 'b0;
  i_rdi_pl_inband_pres           = 'b0;
  i_rdi_pl_phyinrecenter         = 'b0;
  i_rdi_pl_speedmode             = 'b0;
  i_rdi_pl_lnk_cfg               = 'b0;
  i_rdi_pl_state_sts             = LL_Reset;
  i_regfile_linkerror            = 'b0;
  i_fdi_lp_state_req             = Req_NOP;
  i_fdi_lp_linkerror             = 'b0;
  i_fdi_lp_rx_active_sts         = 'b0;
  i_fdi_lp_stall_ack             = 'b0;
  i_sb_state_rx                  = SB_None;
  i_sb_param_exch_done           = 'b0;
  i_mb_flush_done                = 'b0;
  i_mb_retrain_trigger           = 'b0;
  i_mb_rx_path_empty             = 'b0;
  i_rdi_pl_stall_req             = 'b0;
  i_rdi_pl_trdy                  = 'b0;
  i_rdi_pl_error                 = 'b0;
  i_regfile_start_retrain        = 'b0;
  @(negedge i_clk);
  @(negedge i_clk);
  i_rst_n = 'b1;
  i_init = 'b1;
endtask

task rdi_active();
  @(negedge i_clk);
  i_rdi_pl_inband_pres = 'b1;
  i_rdi_pl_state_sts = LL_Active;
  i_rdi_pl_trdy = 'b1;
endtask

task parameter_exchange();
  @(negedge i_clk);
  param_exch_start: assert (o_sb_start_param_exch)
    else $error("Assertion param_exch_start failed!");
  @(negedge i_clk);
  param_exch_stop: assert (~o_sb_start_param_exch)
    else $error("Assertion param_exch_stop failed!");
  i_sb_param_exch_done = 'b1;
  @(negedge i_clk);
endtask

task local_die_start_scenario();
  i_fdi_lp_state_req = Req_Active;
  @(negedge i_clk);
  sb_active_req: assert (o_sb_state_tx == SB_Req_Active)
    else $error("Assertion sb_active_req failed!");
  @(negedge i_clk);
  @(negedge i_clk);
  i_sb_state_rx = SB_Rsp_Active;
  // i_sb_state_rx = SB_Req_Active;
  @(negedge i_clk);
  i_sb_state_rx = SB_None;
  // i_sb_state_rx = SB_Rsp_Active;
  @(negedge i_clk);
  mb_enabled: assert (o_mb_tx_enable)
    else $error("Assertion mb_enabled failed!");
  i_sb_state_rx = SB_Req_Active;
  @(negedge i_clk);
  i_sb_state_rx = SB_None;
  @(negedge i_clk);
  i_fdi_lp_rx_active_sts = 'b1;
  @(negedge i_clk);
  @(negedge i_clk);
endtask

task remote_die_start_scenario();
  i_sb_state_rx = SB_Req_Active;
  @(negedge i_clk);
  @(negedge i_clk);
  i_fdi_lp_rx_active_sts = o_fdi_pl_rx_active_req;
  @(negedge i_clk);
  sent_sb_active_and_mb_enable: assert (o_sb_state_tx == SB_Rsp_Active && o_mb_rx_enable)
    else $error("Assertion sent_sb_active_and_mb_enable failed!");
  i_fdi_lp_state_req = Req_Active;
  @(negedge i_clk);
  sb_active_req_sent: assert (o_sb_state_tx == SB_Req_Active)
    else $error("Assertion sb_active_req_sent failed!");
  i_sb_state_rx = SB_Rsp_Active;
  @(negedge i_clk);
  @(negedge i_clk);
  assert (o_fdi_pl_state_sts == LL_Active && o_mb_tx_enable && o_mb_rx_enable && o_link_status);
endtask

task retratin_to_active();
  i_mb_retrain_trigger = 'b1;
  @(negedge i_clk);
  assert (o_rdi_lp_state_req == Req_Retrain)
    else $error("Assertion failed!");
  i_mb_retrain_trigger = 'b0;
  @(negedge i_clk);
  i_rdi_pl_stall_req = 'b1;
  @(negedge i_clk);
  assert (o_mb_retry_clean_boundary)
    else $error("Assertion failed");
  @(negedge i_clk);
  @(negedge i_clk);
  assert (o_rdi_lp_stall_ack)
    else $error("Assertion failed");
  i_rdi_pl_state_sts = LL_Retrain;
  i_rdi_pl_stall_req = 'b0;
  @(negedge i_clk);
  @(negedge i_clk);
  @(negedge i_clk);
  assert (o_fdi_pl_state_sts == LL_Retrain)
    else $error("Assertion failed");
  $display("state is %s", U0_ALSM_UP.s_cs.name());
  i_rdi_pl_state_sts = LL_Active;
  @(negedge i_clk);
  @(negedge i_clk);
  @(negedge i_clk);
  @(negedge i_clk);
  i_sb_state_rx = SB_Rsp_Active;
  @(negedge i_clk);
  i_sb_state_rx = SB_Req_Active;
  @(negedge i_clk);
  @(negedge i_clk);
  @(negedge i_clk);
  @(negedge i_clk);
  @(negedge i_clk);
endtask
task protocol_exit_linkerror();
  i_fdi_lp_linkerror = 'b1;
  @(negedge i_clk);
  i_rdi_pl_trdy      = 'b1;
  i_rdi_pl_state_sts = LL_LinkError;
  i_rdi_pl_stall_req = 'b1; 
  @(negedge i_clk);
  assert(o_mb_flush);
  @(negedge i_clk);
  i_mb_flush_done = 'b1;
  @(negedge i_clk);
  assert(o_fdi_pl_state_sts == LL_LinkError);
  assert(o_rdi_lp_stall_ack);
  assert(~o_link_status);
  assert(~o_mb_tx_enable);
  assert(~o_fdi_pl_inband_pres);
  assert(~o_fdi_pl_rx_active_req);
  i_rdi_pl_stall_req = 'b0;
  @(negedge i_clk);
  @(negedge i_clk);
  assert(~o_mb_rx_enable);
  i_fdi_lp_linkerror = 'b0;
  i_fdi_lp_state_req =  Req_Active;
  @(negedge i_clk);
  assert(o_rdi_lp_state_req == Req_Active);
  i_rdi_pl_state_sts = LL_Reset;
  i_regfile_linkerror     = 'b0;
  @(negedge i_clk);
  assert(o_fdi_pl_state_sts == LL_Reset);
  i_fdi_lp_state_req =  Req_NOP;
  @(negedge i_clk);
  assert(o_rdi_lp_state_req == Req_NOP);
  @(negedge i_clk);
  assert(o_rdi_lp_state_req == Req_NOP);
  i_fdi_lp_state_req =  Req_Active;
  @(negedge i_clk);
  assert(o_rdi_lp_state_req == Req_Active);
  @(negedge i_clk);
  @(negedge i_clk);
endtask
endmodule