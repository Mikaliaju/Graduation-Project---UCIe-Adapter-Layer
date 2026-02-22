/*
	Author: Ali Mohammad Ali Sakr
	Module Name: ALSM
	
	This is the Adapter Link State Machine module, it is responsible for
	controlling the state machine hierarchy by going to and from states specified in the spec.
	This module has control over the MB module and communicates state message info to and from
	the SB module. The ALSM module also logs Errors and reads Uncorrectable errors from the
	Register File. FDI and RDI signals are used to control/communicate the state of the adapter
	with the upper and lower layers.

*/
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

// Reset sub state encodings
typedef enum {
	ALSM_Reset,
	ALSM_Param_exch,
	ALSM_Active_Entry,
	ALSM_SB_Active_Req,
	ALSM_Active_Req_Await,
	ALSM_rx_active_1,
	ALSM_SB_rsp_recieved,
	ALSM_rx_active_2,
	ALSM_Await_FDI_Active,
	ALSM_Active
} ALSM_State;


module ALSM (
	input logic       i_clk,
	input logic       i_rst_n,
	input logic				i_init,
	
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

 // if speed_mode > MINIMUM_MAX_SPEED_VALUE, then max_speed_mode is high
	localparam MINIMUM_MAX_SPEED_VALUE = 3'b101;

	// current sub state, next sub state
	ALSM_State s_cs, s_ns;

	// signals to check wether the ALSM is in a certain 'Main' state
	logic s_in_ALSM_reset;
	// internal signal definitions
	logic r_Protocol_Active;
	logic r_sb_active_req_received, r_sb_active_rsp_received;

	// always request the FDI and RDI to be ungated
	assign o_rdi_lp_wake_req = 'b1;
	assign o_fdi_pl_clk_req = 'b1;

	// RDI outputs (combinational)
	logic w_rdi_lp_linkerror_comb; 
	state_req w_rdi_lp_state_req_comb;

	// FDI outputs (combinational)
	logic w_fdi_pl_stallreq_comb, w_fdi_pl_inband_pres_comb, w_fdi_pl_rx_active_req_comb;
	ll_state w_fdi_pl_state_sts_comb;
	// SB outputs (combinational)
	logic w_sb_start_param_exch_comb, w_sb_msg_request_comb;
	SB_state w_sb_state_tx_comb;

	// MB outputs (combinational)
	logic w_MB_flush_comb, w_MB_retry_clean_boundary_comb, w_MB_tx_enable_comb, w_MB_rx_enable_comb;

	// Regfile outputs (combinational)
	logic w_uce_Adapter_timeout_non_active_comb,
				w_uce_Adapter_timeout_active_comb,
				w_Error_Valid_comb,
				w_Link_Status_comb,
				w_ce_Adapter_Transition_Retrain_comb;

	Adapter_Response  w_Adpater_LSM_response_type_comb;

	// current state logic
	always_ff @(negedge i_rst_n, posedge i_clk) begin
		if (~i_rst_n) begin
			s_cs <= ALSM_Reset;
		end
		else if (~i_init) begin
			s_cs <= ALSM_Reset;
		end
		else begin
			s_cs <= s_ns;
		end
	end

	// ALSM outputs
	always_ff @(negedge i_rst_n, posedge i_clk) begin
		if (~i_rst_n) begin
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
		else if (~i_init) begin
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
			o_rdi_lp_linkerror <= w_rdi_lp_linkerror_comb;
			o_rdi_lp_state_req <= w_rdi_lp_state_req_comb;

			// FDI outputs
			o_fdi_pl_stallreq      <= w_fdi_pl_stallreq_comb;
			o_fdi_pl_state_sts     <= w_fdi_pl_state_sts_comb;
			o_fdi_pl_inband_pres   <= w_fdi_pl_inband_pres_comb;
			o_fdi_pl_rx_active_req <= w_fdi_pl_rx_active_req_comb;

			// SB outputs
			o_sb_start_param_exch <= w_sb_start_param_exch_comb;
			o_sb_msg_request      <= w_sb_msg_request_comb;
			o_sb_state_tx         <= w_sb_state_tx_comb;

			// MB outputs
			o_MB_flush                <= w_MB_flush_comb;
			o_MB_retry_clean_boundary <= w_MB_retry_clean_boundary_comb;
			o_MB_tx_enable            <= w_MB_tx_enable_comb;
			o_MB_rx_enable            <= w_MB_rx_enable_comb;

			// Regfile outputs
			o_Adpater_LSM_response_type      <= w_Adpater_LSM_response_type_comb;
			o_uce_Adapter_timeout_non_active <= w_uce_Adapter_timeout_non_active_comb;
			o_uce_Adapter_timeout_active     <= w_uce_Adapter_timeout_active_comb;
			o_Error_Valid                    <= w_Error_Valid_comb;
			o_Link_Status                    <= w_Link_Status_comb;
			o_ce_Adapter_Transition_Retrain  <= w_ce_Adapter_Transition_Retrain_comb;
		end
	end

	// Registered signals
	always_ff @(negedge i_rst_n, posedge i_clk) begin
		if (~i_rst_n) begin
			o_fdi_pl_phyinrecenter <= 'b0; 
			o_fdi_pl_speedmode     <= 'b0;
			o_fdi_pl_max_speedmode <= 'b0;
			o_fdi_pl_lnk_cfg       <= 'b0;
			o_fdi_pl_phyinl1       <= 'b0;
			o_fdi_pl_phyinl2       <= 'b0;
			o_fdi_pl_wake_ack      <= 'b0;
			o_rdi_lp_clk_ack       <= 'b0;
		end
		else if (~i_init) begin
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
			o_fdi_pl_phyinrecenter <=  i_rdi_pl_phyinrecenter; 
			o_fdi_pl_speedmode     <=  i_rdi_pl_speedmode;
			o_fdi_pl_max_speedmode <= (i_rdi_pl_speedmode > MINIMUM_MAX_SPEED_VALUE);
			o_fdi_pl_lnk_cfg       <=  i_rdi_pl_lnk_cfg;
			o_fdi_pl_phyinl1       <= (i_rdi_pl_state_sts == LL_L1);
			o_fdi_pl_phyinl2       <= (i_rdi_pl_state_sts == LL_L2);
			o_fdi_pl_wake_ack      <=  i_fdi_lp_wake_req;
			o_rdi_lp_clk_ack       <=  i_rdi_pl_clk_req;
		end
	end

	// These signals only start being taken into account when the Main State is in 
	// Reset, otherwise they are zero
	always_ff @(negedge i_rst_n, posedge i_clk) begin
		if (~i_rst_n) begin
			r_Protocol_Active        <= 'b0;
			r_sb_active_req_received <= 'b0;
			r_sb_active_rsp_received <= 'b0;
		end
		else if (~i_init) begin
			r_Protocol_Active        <= 'b0;
			r_sb_active_req_received <= 'b0;
			r_sb_active_rsp_received <= 'b0;
		end
		else if (s_in_ALSM_reset) begin
			r_Protocol_Active        <= r_Protocol_Active | (i_fdi_lp_state_req == Req_Active);
			r_sb_active_req_received <= r_sb_active_req_received | (i_sb_state_rx == SB_Req_Active);
			r_sb_active_rsp_received <= r_sb_active_rsp_received | (i_sb_state_rx == SB_Rsp_Active);
		end
		else begin
			r_Protocol_Active        <= 'b0;
			r_sb_active_req_received <= 'b0;
			r_sb_active_rsp_received <= 'b0;
		end
	end

	// next state logic
	always_comb begin
		s_ns = s_cs;

		// RDI outputs default combinational value
		w_rdi_lp_linkerror_comb = o_rdi_lp_linkerror;
		w_rdi_lp_state_req_comb = o_rdi_lp_state_req;

		// FDI outputs default combinational value
		w_fdi_pl_stallreq_comb      = o_fdi_pl_stallreq;
		w_fdi_pl_state_sts_comb     = o_fdi_pl_state_sts;
		w_fdi_pl_inband_pres_comb   = o_fdi_pl_inband_pres;
		w_fdi_pl_rx_active_req_comb = o_fdi_pl_rx_active_req;

		// SB outputs default combinational value
		w_sb_start_param_exch_comb = o_sb_start_param_exch;
		w_sb_msg_request_comb      = o_sb_msg_request;
		w_sb_state_tx_comb         = o_sb_state_tx;

		// MB outputs default combinational value
		w_MB_flush_comb                = o_MB_flush;
		w_MB_retry_clean_boundary_comb = o_MB_retry_clean_boundary;
		w_MB_tx_enable_comb            = o_MB_tx_enable;
		w_MB_rx_enable_comb            = o_MB_rx_enable;

		// Regfile outputs default combinational value
		w_Adpater_LSM_response_type_comb      = o_Adpater_LSM_response_type;
		w_uce_Adapter_timeout_non_active_comb = o_uce_Adapter_timeout_non_active;
		w_uce_Adapter_timeout_active_comb     = o_uce_Adapter_timeout_active;
		w_Error_Valid_comb                    = o_Error_Valid;
		w_Link_Status_comb                    = o_Link_Status;
		w_ce_Adapter_Transition_Retrain_comb  = o_ce_Adapter_Transition_Retrain;

		case (s_cs)
			ALSM_Reset: 
				if (i_rdi_pl_state_sts == LL_Active) begin
					s_ns = ALSM_Param_exch;
				end
				else begin
					s_ns = ALSM_Reset;
				end
			ALSM_Param_exch: 
				if (i_sb_param_exch_done) begin
					s_ns = ALSM_Active_Entry;
				end
				else begin
					s_ns = ALSM_Param_exch;
				end
			ALSM_Active_Entry:
				if (r_Protocol_Active) begin
					s_ns = ALSM_SB_Active_Req;
				end
				else if (r_sb_active_req_received && o_rdi_lp_clk_ack) begin
					s_ns = ALSM_rx_active_2;
				end
				else begin
					s_ns = ALSM_Active_Entry;
				end
			ALSM_SB_Active_Req:
				if (r_sb_active_rsp_received) begin
					s_ns = ALSM_Active_Req_Await;
				end 
				else if (r_sb_active_req_received) begin
					s_ns = ALSM_rx_active_1;
				end
				else begin
					s_ns = ALSM_SB_Active_Req;
				end
			ALSM_Active_Req_Await:
				if (r_sb_active_req_received) begin
					s_ns = ALSM_rx_active_1;
				end
				else begin
					s_ns = ALSM_Active_Req_Await;
				end
			ALSM_rx_active_1:
				if (i_fdi_lp_rx_active_sts && r_sb_active_rsp_received) begin
					s_ns = ALSM_Active;
				end
				else if (i_fdi_lp_rx_active_sts && ~r_sb_active_rsp_received) begin
					s_ns = ALSM_SB_rsp_recieved;
				end
				else begin
					s_ns = ALSM_rx_active_1;
				end
			ALSM_rx_active_2:
				if (i_fdi_lp_rx_active_sts) begin
					s_ns = ALSM_Await_FDI_Active;
				end
				else begin
					s_ns = ALSM_rx_active_2;
				end
			ALSM_Await_FDI_Active:
				if (i_fdi_lp_state_req == Req_Active) begin
					s_ns = ALSM_SB_rsp_recieved;
				end
				else begin
					s_ns = ALSM_Await_FDI_Active;
				end
			ALSM_SB_rsp_recieved:
				if (r_sb_active_rsp_received) begin
					s_ns = ALSM_Active;
				end
				else begin
					s_ns = ALSM_SB_rsp_recieved;
				end
		endcase
	end

	// combinational block to set the value of s_in_ALSM_reset
	always_comb begin
		case (s_cs)
			ALSM_Reset,
			ALSM_Param_exch,
			ALSM_Active_Entry,
			ALSM_SB_Active_Req,
			ALSM_Active_Req_Await,
			ALSM_rx_active_1,
			ALSM_rx_active_2,
			ALSM_Await_FDI_Active,
			ALSM_SB_rsp_recieved: 
				s_in_ALSM_reset = 'b1;
			default: s_in_ALSM_reset = 'b0;
		endcase
	end
	
endmodule