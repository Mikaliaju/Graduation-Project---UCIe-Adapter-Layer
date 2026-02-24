//! Author: Ali Mohammad Ali Sakr
//!
//! Module Name: ALSM
//! 
//! This is the Adapter Link State Machine module, it is responsible for
//! controlling the state machine hierarchy by going to and from states specified in the spec.
//! This module has control over the MB module and communicates state message info to and from
//! the SB module. The ALSM module also logs Errors and reads Uncorrectable errors from the
//! Register File. FDI and RDI signals are used to control/communicate the state of the adapter
//! with the upper and lower layers.

// import ALSM_package::*;

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
// Adapter Link State Machine state encodings
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
	ALSM_Active,
	ALSM_Stall,
	ALSM_Retrain
} ALSM_State;

module ALSM (
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

	// MB inputs
	input logic        i_MB_retry_clean_boundary_done, //! MB has reached a clean boundary and is ready to dump it's data
	input logic        i_MB_flush_done, 							 //! MB has finished flushing
	input logic        i_MB_Retrain_Trigger, 					 //! MB retrain request to ALSM
	input logic        i_MB_rx_path_empty,  				 	 //! MB rx path is empty

	// MB outputs
	output logic       o_MB_flush, 						    //! ALSM request to flush the MB
	output logic       o_MB_retry_clean_boundary, //! ALSM request to the MB to stop transmission on a clean boundary
	output logic       o_MB_tx_enable, 					  //! ALSM enable signal for MB tx path
	output logic       o_MB_rx_enable, 					  //! ALSM enable signal for MB tx path

	// RegFile Inputs
	input logic        i_Regfile_LinkError, 		  //! Uncorrectable error signal from regfile

	// RegFile outputs
	output Adapter_Response o_Adpater_LSM_response_type,      //! state at which timeout happened
	output logic            o_uce_Adapter_timeout_non_active, //! indication if timout happened in active
	output logic            o_uce_Adapter_timeout_active,     //! indication if timout happened not in active
	output logic            o_Error_Valid, 										//! error valid signal to Regfile
	output logic            o_Link_Status, 										//! Link Status indication
	output logic            o_ce_Adapter_Transition_Retrain   //! ALSM in retrain indication
);

 //! if speed_mode > MINIMUM_MAX_SPEED_VALUE, then max_speed_mode is high
	localparam MINIMUM_MAX_SPEED_VALUE = 3'b101;

	//! current state, next state
	ALSM_State s_cs, s_ns;

	//! signal to check wether the ALSM is in a certain 'Main' state
	logic s_in_ALSM_reset;

	//! registered signal to see if protocol ever asked for active transition
	logic r_Protocol_Active;
	//! registered signal to see if remote parter ever requested/received active
	logic r_sb_active_req_received, r_sb_active_rsp_received;

	//! combinational signal to see if protocol ever asked for active transition
	logic w_Protocol_Active_comb;
	//! combinational signal to see if remote parter ever requested/received active
	logic w_sb_active_req_received_comb, w_sb_active_rsp_received_comb;

	//! RDI output (combinational)
	logic w_rdi_lp_linkerror_comb, w_rdi_lp_stall_ack; 
	//! RDI output (combinational)
	state_req w_rdi_lp_state_req_comb;

	//! FDI output (combinational)
	logic w_fdi_pl_stallreq_comb, w_fdi_pl_inband_pres_comb, w_fdi_pl_rx_active_req_comb;
	//! FDI output (combinational)
	ll_state w_fdi_pl_state_sts_comb;

	//! SB output (combinational)
	logic 								w_sb_start_param_exch_comb;
	//! SB output (combinational)
	sb_state_msg_encoding w_sb_state_tx_comb;

	//! MB output (combinational)
	logic w_MB_flush_comb, w_MB_retry_clean_boundary_comb, w_MB_tx_enable_comb, w_MB_rx_enable_comb;

	//! Regfile output (combinational)
	logic w_uce_Adapter_timeout_non_active_comb,
				w_uce_Adapter_timeout_active_comb,
				w_Error_Valid_comb,
				w_Link_Status_comb,
				w_ce_Adapter_Transition_Retrain_comb;

	//! Regfile output (combinational)
	Adapter_Response  w_Adpater_LSM_response_type_comb;

	// always request the FDI and RDI to be ungated
	assign o_rdi_lp_wake_req = 'b1;
	assign o_fdi_pl_clk_req = 'b1;

	assign w_Protocol_Active_comb = r_Protocol_Active | (i_fdi_lp_state_req == Req_Active);
	assign w_sb_active_req_received_comb = r_sb_active_req_received | (i_sb_state_rx == SB_Req_Active);
	assign w_sb_active_rsp_received_comb = r_sb_active_rsp_received | (i_sb_state_rx == SB_Rsp_Active);

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
			o_rdi_lp_stall_ack <= 'b0;

			// FDI outputs
			o_fdi_pl_stallreq      <= 'b0;
			o_fdi_pl_state_sts     <= LL_Reset;
			o_fdi_pl_inband_pres   <= 'b0;
			o_fdi_pl_rx_active_req <= 'b0;

			// SB outputs
			o_sb_start_param_exch <= 'b0;
			o_sb_state_tx         <= SB_None;

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
			o_rdi_lp_stall_ack <= w_rdi_lp_stall_ack;

			// FDI outputs
			o_fdi_pl_stallreq      <= w_fdi_pl_stallreq_comb;
			o_fdi_pl_state_sts     <= w_fdi_pl_state_sts_comb;
			o_fdi_pl_inband_pres   <= w_fdi_pl_inband_pres_comb;
			o_fdi_pl_rx_active_req <= w_fdi_pl_rx_active_req_comb;

			// SB outputs
			o_sb_start_param_exch <= w_sb_start_param_exch_comb;
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

	//! Registered signals
	always_ff @(negedge i_rst_n, posedge i_clk) begin : registered_block
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

	//! These signals only start being taken into account when the Main State is in 
	//! Reset, otherwise they are zero
	always_ff @(negedge i_rst_n, posedge i_clk) begin : reset_to_active_flags
		if (~i_rst_n) begin
			r_Protocol_Active        <= 'b0;
			r_sb_active_req_received <= 'b0;
			r_sb_active_rsp_received <= 'b0;
		end
		else if (~i_init && ~s_in_ALSM_reset) begin
			r_Protocol_Active        <= 'b0;
			r_sb_active_req_received <= 'b0;
			r_sb_active_rsp_received <= 'b0;
		end
		else begin
			r_Protocol_Active        <= w_Protocol_Active_comb;
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
		w_rdi_lp_stall_ack		  = o_rdi_lp_stall_ack;

		// FDI outputs default combinational value
		w_fdi_pl_stallreq_comb      = o_fdi_pl_stallreq;
		w_fdi_pl_state_sts_comb     = o_fdi_pl_state_sts;
		w_fdi_pl_inband_pres_comb   = o_fdi_pl_inband_pres;
		w_fdi_pl_rx_active_req_comb = o_fdi_pl_rx_active_req;

		// SB outputs default combinational value
		w_sb_start_param_exch_comb = o_sb_start_param_exch;
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

				// MB outputs zero combinational value
				w_MB_flush_comb                = 'b0;
				w_MB_retry_clean_boundary_comb = 'b0;
				w_MB_tx_enable_comb            = 'b0;
				w_MB_rx_enable_comb            = 'b0;

				// Regfile outputs zero combinational value
				w_Adpater_LSM_response_type_comb      = Active_LSM_response_type;
				w_uce_Adapter_timeout_non_active_comb = 'b0;
				w_uce_Adapter_timeout_active_comb     = 'b0;
				w_Error_Valid_comb                    = 'b0;
				w_Link_Status_comb                    = 'b0;
				w_ce_Adapter_Transition_Retrain_comb  = 'b0;

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
				if (w_Protocol_Active_comb) begin
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
					w_MB_tx_enable_comb = 'b1;
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
					w_MB_rx_enable_comb 		= 'b1;
					w_MB_tx_enable_comb 		= 'b1;
					w_fdi_pl_state_sts_comb = LL_Active;
					w_Link_Status_comb 			= 'b1;
					s_ns 										= ALSM_Active;
				end
				else if (i_fdi_lp_rx_active_sts && ~r_sb_active_rsp_received) begin
					w_sb_state_tx_comb      = SB_Rsp_Active;
					w_MB_rx_enable_comb = 'b1;
					s_ns 								= ALSM_SB_rsp_received;
				end
				else begin
					s_ns = ALSM_rx_active_1;
				end
			ALSM_rx_active_2:
				if (i_fdi_lp_rx_active_sts) begin
					w_sb_state_tx_comb 	= SB_Rsp_Active;
					w_MB_rx_enable_comb = 'b1;
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
					w_MB_rx_enable_comb 		= 'b1;
					w_MB_tx_enable_comb 		= 'b1;
					w_fdi_pl_state_sts_comb = LL_Active;
					w_Link_Status_comb 			= 'b1;
					s_ns 										= ALSM_Active;
				end
				else begin
					s_ns = ALSM_SB_rsp_received;
				end
			end
			ALSM_Active: begin
				w_sb_state_tx_comb = SB_None;
				if () begin
					pass
				end
				else (w_retrain_triggers) begin
					pass
				end
			end
		endcase
	end

	//! combinational block to set the value of s_in_ALSM_reset
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
				s_in_ALSM_reset = 'b1;
			default: s_in_ALSM_reset = 'b0;
		endcase
	end
	
endmodule