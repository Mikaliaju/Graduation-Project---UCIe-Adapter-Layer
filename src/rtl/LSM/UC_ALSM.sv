//! Author: Ali Mohammad Ali Sakr
//!
//! Module Name: ALSM
//! 
//! This is the Adapter Link State Machine module, it is responsible for
//! controlling the state machine hierarchy by going to and from states specified in the spec.
//! This module has control over the mb module and communicates state message info to and from
//! the SB module. The ALSM module also logs Errors and reads Uncorrectable errors from the
//! Register File. FDI and RDI signals are used to control/communicate the state of the adapter
//! with the upper and lower layers.

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
// 	ALSM_Error_Entry,
// 	ALSM_LinkError,
// 	ALSM_Protocol_Exit,
//  ALSM_Detected_Nop
// } ALSM_State;

module UC_ALSM (
	input logic       i_clk,   								//! input clock
	input logic       i_rst_n, 								//! system reset
	input logic				i_init,  								//! software level reset
	
	// RDI inputs
	input logic       i_rdi_pl_inband_pres,   //! phy ready to receive state req
	input logic       i_rdi_pl_phyinrecenter, //! phy in train/retrain
	input logic [2:0] i_rdi_pl_speedmode,     //! phy speed mode
	input logic [2:0] i_rdi_pl_lnk_cfg,       //! phy link configuration
	input ll_state    i_rdi_pl_state_sts,     //! phy state
	input logic       i_rdi_pl_clk_req,       //! phy request to ungate adapter
	input logic       i_rdi_pl_wake_ack,      //! phy response to ungating request signal from adapter
	input logic				i_rdi_pl_stall_req,			//! phy requests the adapter to stall transmission
	input logic				i_rdi_pl_error,					//! phy indication of error
	input logic				i_rdi_pl_trdy,					//! phy data path backpressure on adatpter transmitter

	// RDI outputs
	output logic       o_rdi_lp_clk_ack,      //! adpater response to ungating signal from phy
	output logic       o_rdi_lp_wake_req,     //! adapter request to ungate phy
	output logic       o_rdi_lp_linkerror,    //! link Error signal from adapter to phy
	output state_req   o_rdi_lp_state_req,    //! adapter state request
	output logic			 o_rdi_lp_stall_ack,		//! adapter confirmation of transmisstion stalling

	// FDI inputs
	input state_req   i_fdi_lp_state_req,     //! protocol state request
	input logic       i_fdi_lp_linkerror,     //! link error from protocol to adatper
	input logic       i_fdi_lp_rx_active_sts, //! protocol rx path status (open/~closed)
	input logic       i_fdi_lp_stall_ack,     //! protocol response to stall signal from adapter
	input logic       i_fdi_lp_clk_ack,       //! protocol response to ungating signal from adpater
	input logic       i_fdi_lp_wake_req,      //! protocol request to ungate adapter

	// FDI outputs
	output logic       o_fdi_pl_stallreq,      //! adpater request to protocol to stall
	output logic       o_fdi_pl_phyinrecenter, //! fdi signal for phy train/retrain
	output logic       o_fdi_pl_phyinl1,       //! fdi signal for phy in L1 PM
	output logic       o_fdi_pl_phyinl2,       //! fdi signal for phy in L2 PM
	output logic [2:0] o_fdi_pl_speedmode,     //! fdi signal for phy speedmode
	output logic       o_fdi_pl_max_speedmode, //! fdi signal for max_speedmode (>32 Gb/s)
	output logic [2:0] o_fdi_pl_lnk_cfg,       //! fdi signal for phy link configuration
	output ll_state    o_fdi_pl_state_sts,     //! adpater state
	output logic       o_fdi_pl_inband_pres,   //! adapter is capable of receiving protocol state requests
	output logic       o_fdi_pl_rx_active_req, //! adapter request to activate protocol rx path
	output logic       o_fdi_pl_clk_req,  		 //! adpater request to ungate protocol
	output logic       o_fdi_pl_wake_ack, 		 //! adpater response to ungating signal from protocol

	// SB inputs
	input sb_state_msg_encoding     i_sb_state_rx, 				//! SB state message to ALSM
	input logic        							i_sb_param_exch_done, //! SB finished parameter exchange signal

	// SB outputs
	output logic       							o_sb_start_param_exch, //! ALSM trigger for parameter exchange to SB
	output sb_state_msg_encoding    o_sb_state_tx, 				 //! ALSM state message to SB

	// mb inputs
	input logic        i_mb_retry_clean_boundary_done, //! mb has reached a clean boundary and is ready to dump it's data
	input logic        i_mb_flush_done, 							 //! mb has finished flushing
	input logic        i_mb_retrain_trigger, 					 //! mb retrain request to ALSM
	input logic        i_mb_rx_path_empty,  				 	 //! mb rx path is empty

	// mb outputs
	output logic       o_mb_flush, 						    //! ALSM request to flush the mb
	output logic       o_mb_retry_clean_boundary, //! ALSM request to the mb to stop transmission on a clean boundary
	output logic       o_mb_tx_enable, 					  //! ALSM enable signal for mb tx path
	output logic       o_mb_rx_enable, 					  //! ALSM enable signal for mb tx path

	// RegFile Inputs
	input logic        i_regfile_linkerror, 		  //! Uncorrectable error signal from regfile
	input logic 			 i_regfile_start_retrain,    //! SW retrain through Register File

	// RegFile outputs
	output Adapter_Response o_adpater_lsm_response_type,      //! state at which timeout happened
	output logic            o_uce_adapter_timeout_non_active, //! indication if timout happened in active
	output logic            o_uce_adapter_timeout_active,     //! indication if timout happened not in active
	output logic            o_error_valid, 										//! error valid signal to Regfile
	output logic            o_link_status, 										//! Link Status indication
	output logic            o_ce_adapter_transition_retrain   //! ALSM in retrain indication
);

 //! if speed_mode > MINIMUM_MAX_SPEED_VALUE, then max_speed_mode is high
	localparam MINIMUM_MAX_SPEED_VALUE = 3'b101;

	//! current state, next state
	ALSM_State s_cs, s_ns;

	
	logic s_in_alsm_reset,  					      //! signal to check wether the ALSM is in a certain 'Main' state
				r_protocol_active,						    //! registered signal to see if protocol ever asked for active transition
				r_sb_active_req_received,         //! registered signal to see if remote parter ever requested/received active 
				r_sb_active_rsp_received,
	      w_protocol_active_comb, 			    //! combinational signal to see if protocol ever asked for active transition
				w_sb_active_req_received_comb, 
				w_sb_active_rsp_received_comb,    //! combinational signal to see if remote parter ever requested/received active
	      w_rdi_lp_linkerror_comb, 
				w_rdi_lp_stall_ack_comb,
				w_fdi_pl_stallreq_comb,
				w_fdi_pl_inband_pres_comb,
				w_fdi_pl_rx_active_req_comb,
				w_sb_start_param_exch_comb,
				w_mb_flush_comb,
				w_mb_retry_clean_boundary_comb,
				w_mb_tx_enable_comb,
				w_mb_rx_enable_comb,
	      w_uce_adapter_timeout_non_active_comb,
				w_uce_adapter_timeout_active_comb,
				w_error_valid_comb,
				w_link_status_comb,
				w_retrain_triggers,              //! all retrain triggers
				s_link_error_state_condition,    //! Global condition signal at which must immediatly enter ALSM_LinkError
				s_error_entry_state_condition;   //! Global condition signal at which must immediatly enter ALSM_Error_Entry
	

	state_req w_rdi_lp_state_req_comb;
	ll_state w_fdi_pl_state_sts_comb;
	sb_state_msg_encoding w_sb_state_tx_comb;
	Adapter_Response  w_adpater_lsm_response_type_comb;



	// always request the FDI and RDI to be ungated
	assign o_rdi_lp_wake_req = 'b1;
	assign o_fdi_pl_clk_req = 'b1;

	assign w_protocol_active_comb 			 = r_protocol_active 			  | (i_fdi_lp_state_req == Req_Active);
	assign w_sb_active_req_received_comb = r_sb_active_req_received | (i_sb_state_rx      == SB_Req_Active);
	assign w_sb_active_rsp_received_comb = r_sb_active_rsp_received | (i_sb_state_rx      == SB_Rsp_Active);

	assign w_retrain_triggers = i_mb_retrain_trigger | i_regfile_start_retrain | i_rdi_pl_error;

	assign s_link_error_state_condition = (i_rdi_pl_state_sts == LL_LinkError) && // if RDI is in LinkError
																				(~o_mb_rx_enable || ~i_rdi_pl_trdy)  && // the mb is disabled or rdi_pl_trdy is off (must not drain)
																				(s_cs != ALSM_LinkError)						 && // Not already in ALSM_LinkError
																				(s_cs != ALSM_Protocol_Exit);

	assign s_error_entry_state_condition = (i_rdi_pl_state_sts == LL_LinkError)   && // if RDI is in LinkError
																			   (o_mb_tx_enable && i_rdi_pl_trdy)      && // the mb is enabled and rdi_pl_trdy is on (can drain)
																			   (s_cs != ALSM_Error_Entry)						  && // Not already in ALSM_Error_Entry
																			   (s_cs != ALSM_LinkError);								 // Not already in ALSM_LinkError
	//! current state logic
	always_ff @(negedge i_rst_n, posedge i_clk) begin : current_state_block
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

	//! ALSM outputs
	always_ff @(negedge i_rst_n, posedge i_clk) begin : ALSM_outputs_block
		if (~i_rst_n) begin
			// RDI outputs
			o_rdi_lp_linkerror <= 'b0;
			o_rdi_lp_state_req <= Req_NOP;
			o_rdi_lp_stall_ack <= 'b0;

			// FDI outputs
			o_fdi_pl_stallreq      <= 'b0;
			o_fdi_pl_state_sts     <= LL_Reset;
			o_fdi_pl_inband_pres   <= 'b0;
			o_fdi_pl_rx_active_req <= 'b0;

			// SB outputs
			o_sb_start_param_exch <= 'b0;
			o_sb_state_tx         <= SB_None;

			// mb outputs
			o_mb_flush                <= 'b0;
			o_mb_retry_clean_boundary <= 'b0;
			o_mb_tx_enable            <= 'b0;
			o_mb_rx_enable            <= 'b0;

			// Regfile outputs
			o_adpater_lsm_response_type      <= Active_LSM_response_type;
			o_uce_adapter_timeout_non_active <= 'b0;
			o_uce_adapter_timeout_active     <= 'b0;
			o_error_valid                    <= 'b0;
			o_link_status                    <= 'b0;
		end
		else if (~i_init) begin
			// RDI outputs
			o_rdi_lp_linkerror <= 'b0;
			o_rdi_lp_state_req <= Req_NOP;
			o_rdi_lp_stall_ack <= 'b0;

			// FDI outputs
			o_fdi_pl_stallreq      <= 'b0;
			o_fdi_pl_state_sts     <= LL_Reset;
			o_fdi_pl_inband_pres   <= 'b0;
			o_fdi_pl_rx_active_req <= 'b0;

			// SB outputs
			o_sb_start_param_exch <= 'b0;
			o_sb_state_tx         <= SB_None;

			// mb outputs
			o_mb_flush                <= 'b0;
			o_mb_retry_clean_boundary <= 'b0;
			o_mb_tx_enable            <= 'b0;
			o_mb_rx_enable            <= 'b0;

			// Regfile outputs
			o_adpater_lsm_response_type      <= Active_LSM_response_type;
			o_uce_adapter_timeout_non_active <= 'b0;
			o_uce_adapter_timeout_active     <= 'b0;
			o_error_valid                    <= 'b0;
			o_link_status                    <= 'b0;
		end
		else begin
			// RDI outputs
			o_rdi_lp_linkerror <= w_rdi_lp_linkerror_comb;
			o_rdi_lp_state_req <= w_rdi_lp_state_req_comb;
			o_rdi_lp_stall_ack <= w_rdi_lp_stall_ack_comb;

			// FDI outputs
			o_fdi_pl_stallreq      <= w_fdi_pl_stallreq_comb;
			o_fdi_pl_state_sts     <= w_fdi_pl_state_sts_comb;
			o_fdi_pl_inband_pres   <= w_fdi_pl_inband_pres_comb;
			o_fdi_pl_rx_active_req <= w_fdi_pl_rx_active_req_comb;

			// SB outputs
			o_sb_start_param_exch <= w_sb_start_param_exch_comb;
			o_sb_state_tx         <= w_sb_state_tx_comb;

			// mb outputs
			o_mb_flush                <= w_mb_flush_comb;
			o_mb_retry_clean_boundary <= w_mb_retry_clean_boundary_comb;
			o_mb_tx_enable            <= w_mb_tx_enable_comb;
			o_mb_rx_enable            <= w_mb_rx_enable_comb;

			// Regfile outputs
			o_adpater_lsm_response_type      <= w_adpater_lsm_response_type_comb;
			o_uce_adapter_timeout_non_active <= w_uce_adapter_timeout_non_active_comb;
			o_uce_adapter_timeout_active     <= w_uce_adapter_timeout_active_comb;
			o_error_valid                    <= w_error_valid_comb;
			o_link_status                    <= w_link_status_comb;
		end
	end

	//! Registered signals
	always_ff @(negedge i_rst_n, posedge i_clk) begin : registered_block
		if (~i_rst_n) begin
			o_fdi_pl_phyinrecenter          <= 'b0; 
			o_fdi_pl_speedmode              <= 'b0;
			o_fdi_pl_max_speedmode          <= 'b0;
			o_fdi_pl_lnk_cfg                <= 'b0;
			o_fdi_pl_phyinl1                <= 'b0;
			o_fdi_pl_phyinl2                <= 'b0;
			o_fdi_pl_wake_ack               <= 'b0;
			o_rdi_lp_clk_ack                <= 'b0;
			o_ce_adapter_transition_retrain <= 'b0;
		end
		else if (~i_init) begin
			o_fdi_pl_phyinrecenter 					<= 'b0; 
			o_fdi_pl_speedmode     					<= 'b0;
			o_fdi_pl_max_speedmode 					<= 'b0;
			o_fdi_pl_lnk_cfg       					<= 'b0;
			o_fdi_pl_phyinl1       					<= 'b0;
			o_fdi_pl_phyinl2       					<= 'b0;
			o_fdi_pl_wake_ack      					<= 'b0;
			o_rdi_lp_clk_ack       					<= 'b0;
			o_ce_adapter_transition_retrain <= 'b0;
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
			o_ce_adapter_transition_retrain <= (i_rdi_pl_state_sts == LL_Retrain || w_fdi_pl_state_sts_comb == LL_Retrain);
		end
	end

	//! These signals only start being taken into account when the Main State is in 
	//! Reset, otherwise they are zero
	always_ff @(negedge i_rst_n, posedge i_clk) begin : reset_to_active_flags
		if (~i_rst_n) begin
			r_protocol_active        <= 'b0;
			r_sb_active_req_received <= 'b0;
			r_sb_active_rsp_received <= 'b0;
		end
		else if (~i_init || ~s_in_alsm_reset) begin
			r_protocol_active        <= 'b0;
			r_sb_active_req_received <= 'b0;
			r_sb_active_rsp_received <= 'b0;
		end
		else begin
			r_protocol_active        <= w_protocol_active_comb;
			r_sb_active_req_received <= w_sb_active_req_received_comb;
			r_sb_active_rsp_received <= w_sb_active_rsp_received_comb;
		end
	end

	//! next state logic
	always_comb begin : next_state_logic_block
		s_ns = s_cs;

		// RDI outputs default combinational value
		w_rdi_lp_linkerror_comb = o_rdi_lp_linkerror;
		w_rdi_lp_state_req_comb = o_rdi_lp_state_req;
		w_rdi_lp_stall_ack_comb = o_rdi_lp_stall_ack;

		// FDI outputs default combinational value
		w_fdi_pl_stallreq_comb      = o_fdi_pl_stallreq;
		w_fdi_pl_state_sts_comb     = o_fdi_pl_state_sts;
		w_fdi_pl_inband_pres_comb   = o_fdi_pl_inband_pres;
		w_fdi_pl_rx_active_req_comb = o_fdi_pl_rx_active_req;

		// SB outputs default combinational value
		w_sb_start_param_exch_comb = o_sb_start_param_exch;
		w_sb_state_tx_comb         = o_sb_state_tx;

		// mb outputs default combinational value
		w_mb_flush_comb                = o_mb_flush;
		w_mb_retry_clean_boundary_comb = o_mb_retry_clean_boundary;
		w_mb_tx_enable_comb            = o_mb_tx_enable;
		w_mb_rx_enable_comb            = o_mb_rx_enable;

		// Regfile outputs default combinational value
		w_adpater_lsm_response_type_comb      = o_adpater_lsm_response_type;
		w_uce_adapter_timeout_non_active_comb = o_uce_adapter_timeout_non_active;
		w_uce_adapter_timeout_active_comb     = o_uce_adapter_timeout_active;
		w_error_valid_comb                    = o_error_valid;
		w_link_status_comb                    = o_link_status;

		if (s_link_error_state_condition) begin
			w_fdi_pl_state_sts_comb     = LL_LinkError;
			w_mb_tx_enable_comb         = 'b0;
			w_fdi_pl_rx_active_req_comb = 'b0;
			w_link_status_comb 					= 'b0;
			w_fdi_pl_inband_pres_comb   = 'b0;
			s_ns = ALSM_LinkError;
		end
		else if (s_error_entry_state_condition) begin
			w_mb_flush_comb = 'b1;
			s_ns = ALSM_Error_Entry;
		end
		else if ((s_cs != ALSM_Error_Entry) && (s_cs != ALSM_LinkError) && (i_fdi_lp_linkerror || i_regfile_linkerror)) begin
			w_rdi_lp_linkerror_comb = 'b1;
			s_ns = ALSM_Error_Entry;
		end
		else begin
			case (s_cs)
				ALSM_Reset: begin
					// RDI outputs zero combinational value
					w_rdi_lp_linkerror_comb = 'b0;

					// FDI outputs zero combinational value
					w_fdi_pl_stallreq_comb      = 'b0;
					w_fdi_pl_state_sts_comb     = LL_Reset;
					w_fdi_pl_inband_pres_comb   = 'b0;
					w_fdi_pl_rx_active_req_comb = 'b0;

					// SB outputs zero combinational value
					w_sb_start_param_exch_comb = 'b0;
					w_sb_state_tx_comb         = SB_None;

					// mb outputs zero combinational value
					w_mb_flush_comb                = 'b0;
					w_mb_retry_clean_boundary_comb = 'b0;
					w_mb_tx_enable_comb            = 'b0;
					w_mb_rx_enable_comb            = 'b0;

					// Regfile outputs zero combinational value
					w_adpater_lsm_response_type_comb      = Active_LSM_response_type;
					w_uce_adapter_timeout_non_active_comb = 'b0;
					w_uce_adapter_timeout_active_comb     = 'b0;
					w_error_valid_comb                    = 'b0;
					w_link_status_comb                    = 'b0;

					if (i_rdi_pl_state_sts == LL_Active) begin
						w_sb_start_param_exch_comb = 'b1;
						s_ns = ALSM_Param_exch;
					end
					else begin
						if (i_rdi_pl_inband_pres && i_rdi_pl_wake_ack && i_fdi_lp_clk_ack) begin
							w_rdi_lp_state_req_comb = Req_Active;
						end
						else begin
							w_rdi_lp_state_req_comb = Req_NOP;
						end
						s_ns = ALSM_Reset;
					end
				end
				ALSM_Param_exch: 
					if (i_sb_param_exch_done) begin
						w_fdi_pl_inband_pres_comb = 'b1;
						s_ns = ALSM_Active_Entry;
					end
					else begin
						w_sb_start_param_exch_comb = 'b0;
						s_ns = ALSM_Param_exch;
					end
				ALSM_Active_Entry:
					if (w_protocol_active_comb) begin
						w_sb_state_tx_comb = SB_Req_Active;
						s_ns = ALSM_SB_Active_Req;
					end
					else if (w_sb_active_req_received_comb) begin
						w_fdi_pl_rx_active_req_comb = 'b1;
						s_ns = ALSM_rx_active_2;
					end
					else begin
						s_ns = ALSM_Active_Entry;
					end
				ALSM_SB_Active_Req: begin
					w_sb_state_tx_comb = SB_None;
					if (r_sb_active_rsp_received) begin
						w_mb_tx_enable_comb = 'b1;
						s_ns 								= ALSM_Active_Req_Await;
					end 
					else if (w_sb_active_req_received_comb) begin
						w_fdi_pl_rx_active_req_comb = 'b1;
						s_ns = ALSM_rx_active_1;
					end
					else begin
						s_ns = ALSM_SB_Active_Req;
					end
				end
				ALSM_Active_Req_Await:
					if (w_sb_active_req_received_comb) begin
						w_fdi_pl_rx_active_req_comb = 'b1;
						s_ns = ALSM_rx_active_1;
					end
					else begin
						s_ns = ALSM_Active_Req_Await;
					end
				ALSM_rx_active_1:
					if (i_fdi_lp_rx_active_sts && r_sb_active_rsp_received) begin
						w_sb_state_tx_comb      = SB_Rsp_Active;
						w_mb_rx_enable_comb 		= 'b1;
						w_mb_tx_enable_comb 		= 'b1;
						w_fdi_pl_state_sts_comb = LL_Active;
						w_link_status_comb 			= 'b1;
						s_ns 										= ALSM_Active;
					end
					else if (i_fdi_lp_rx_active_sts && ~r_sb_active_rsp_received) begin
						w_sb_state_tx_comb  = SB_Rsp_Active;
						w_mb_rx_enable_comb = 'b1;
						s_ns 								= ALSM_SB_rsp_received;
					end
					else begin
						s_ns = ALSM_rx_active_1;
					end
				ALSM_rx_active_2:
					if (i_fdi_lp_rx_active_sts) begin
						w_sb_state_tx_comb 	= SB_Rsp_Active;
						w_mb_rx_enable_comb = 'b1;
						s_ns = ALSM_Await_FDI_Active;
					end
					else begin
						s_ns = ALSM_rx_active_2;
					end
				ALSM_Await_FDI_Active: begin
					w_sb_state_tx_comb = SB_None;
					if (i_fdi_lp_state_req == Req_Active) begin
						w_sb_state_tx_comb = SB_Req_Active;
						s_ns = ALSM_SB_rsp_received;
					end
					else begin
						s_ns = ALSM_Await_FDI_Active;
					end
				end
				ALSM_SB_rsp_received: begin
					w_sb_state_tx_comb = SB_None;
					if (w_sb_active_rsp_received_comb) begin
						w_mb_rx_enable_comb 		= 'b1;
						w_mb_tx_enable_comb 		= 'b1;
						w_fdi_pl_state_sts_comb = LL_Active;
						w_link_status_comb 			= 'b1;
						s_ns 										= ALSM_Active;
					end
					else begin
						s_ns = ALSM_SB_rsp_received;
					end
				end
				ALSM_Active: begin
					if (i_rdi_pl_stall_req) begin
						w_sb_state_tx_comb = SB_None;
						w_mb_retry_clean_boundary_comb = 'b1;
						s_ns = ALSM_Stall;
					end
					else if (w_retrain_triggers) begin
						w_sb_state_tx_comb = SB_None;
						w_rdi_lp_state_req_comb = Req_Retrain;
						s_ns = ALSM_Stall;
					end
					else begin
						w_sb_state_tx_comb = SB_None;
						s_ns = ALSM_Active;
					end
				end
				ALSM_Stall: begin
					w_mb_retry_clean_boundary_comb =   i_rdi_pl_stall_req;
					w_rdi_lp_stall_ack_comb        =   i_mb_retry_clean_boundary_done;
					w_fdi_pl_rx_active_req_comb    = ~(i_rdi_pl_state_sts == LL_Retrain);
					if (~i_fdi_lp_rx_active_sts && ~i_rdi_pl_stall_req) begin
						w_fdi_pl_state_sts_comb 						 = LL_Retrain;
						w_mb_rx_enable_comb 								 = 'b0;
						w_mb_tx_enable_comb 								 = 'b0;
						w_mb_retry_clean_boundary_comb			 = 'b0;
						w_rdi_lp_stall_ack_comb							 = 'b0;
						s_ns 																 = ALSM_Retrain;
					end
					else begin
						s_ns = ALSM_Stall;
					end
				end
				ALSM_Retrain: begin
					if (i_fdi_lp_state_req == Req_Active && i_rdi_pl_state_sts == LL_Active) begin
						w_rdi_lp_state_req_comb = Req_Active;
						s_ns = ALSM_Active_Entry;
					end
					else if (i_fdi_lp_state_req == Req_NOP || i_fdi_lp_state_req == Req_Active) begin
						w_rdi_lp_state_req_comb = i_fdi_lp_state_req;
						s_ns = ALSM_Retrain;
					end
					else begin
						s_ns = ALSM_Retrain;
					end
				end
				ALSM_Error_Entry: begin
					if (i_rdi_pl_stall_req && i_mb_flush_done) begin
						w_rdi_lp_stall_ack_comb     = 'b1;
						w_mb_tx_enable_comb         = 'b0;
						w_fdi_pl_state_sts_comb     =  LL_LinkError;
						w_fdi_pl_rx_active_req_comb = 'b0;
						w_link_status_comb					= 'b0;
						w_fdi_pl_inband_pres_comb   = 'b0;
						s_ns = ALSM_LinkError;
					end
					else if (i_rdi_pl_state_sts == LL_LinkError && i_rdi_pl_trdy && o_mb_tx_enable) begin
						w_mb_flush_comb = 'b1;
						s_ns = ALSM_Error_Entry;
					end
					else begin
						s_ns = ALSM_Error_Entry;
					end
				end
				ALSM_LinkError: begin
					w_rdi_lp_stall_ack_comb = i_rdi_pl_stall_req;
					// when fdi rx path is closed, close the mb rx path, otherwise keep it as is
					w_mb_rx_enable_comb = (i_fdi_lp_rx_active_sts == 'b0) ? 'b0 : o_mb_rx_enable;

					if (~i_regfile_linkerror            && 
					     i_rdi_pl_state_sts == LL_Reset &&
							~i_fdi_lp_rx_active_sts // cannot enter Reset if the rx path of the protocol layer is active according to spec
							) begin 
						w_fdi_pl_state_sts_comb = LL_Reset;
						s_ns = ALSM_Reset;
					end
					else if (~i_regfile_linkerror                &&
									 ~i_fdi_lp_linkerror                 && 
									  i_fdi_lp_state_req == Req_Active   && 
										// i_rdi_pl_state_sts != LL_LinkError &&
									 ~i_fdi_lp_rx_active_sts
						) begin
						w_rdi_lp_state_req_comb = Req_Active;
						s_ns = ALSM_Protocol_Exit;
					end
					else begin
						s_ns = ALSM_LinkError;
					end
				end
				ALSM_Protocol_Exit: begin
					if (i_fdi_lp_state_req == Req_NOP) begin
						w_rdi_lp_state_req_comb = Req_NOP;
						s_ns = ALSM_Detected_Nop;
					end
					else if (i_rdi_pl_state_sts == LL_Reset) begin
						w_fdi_pl_state_sts_comb = LL_Reset;
						s_ns = ALSM_Protocol_Exit;
					end
					else begin
						s_ns = ALSM_Protocol_Exit;
					end
				end
				ALSM_Detected_Nop: begin
					if (i_fdi_lp_state_req == Req_Active) begin
						w_rdi_lp_state_req_comb = Req_Active;
						s_ns = ALSM_Reset;
					end
					else begin
						s_ns = ALSM_Detected_Nop;
					end
				end
			endcase
	end
	end

	//! combinational block to set the value of s_in_alsm_reset
	always_comb begin : in_reset_block
		case (s_cs)
			ALSM_Reset,
			ALSM_Param_exch,
			ALSM_Active_Entry,
			ALSM_SB_Active_Req,
			ALSM_Active_Req_Await,
			ALSM_rx_active_1,
			ALSM_rx_active_2,
			ALSM_Await_FDI_Active,
			ALSM_SB_rsp_received: 
				s_in_alsm_reset = 'b1;
			default: s_in_alsm_reset = 'b0;
		endcase
	end
	
endmodule