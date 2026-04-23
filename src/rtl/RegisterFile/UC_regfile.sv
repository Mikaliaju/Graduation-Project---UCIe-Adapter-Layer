import UC_ALSM_package::*;
import UC_SB_package::*;
import UC_regfile_package::*;

// typedef enum logic [1:0] {
//     NONE_ERR, 
//     Correctable_Err, 
//     NON_FATAL_Err, 
//     FATAL_Err
// } sb_error_msg_encoding;
// typedef enum logic [2:0] {
// 	Active_LSM_response_type    = 'b001,
// 	L1_LSM_response_type        = 'b010,
// 	L2_LSM_response_type        = 'b011,
// 	LinkReset_LSM_response_type = 'b100,
// 	Disable_LSM_response_type   = 'b101
// } Adapter_Response;

module UC_regfile
(

  input logic       i_init,
  input logic       i_clk,
  input logic       i_rst_n,

  // FDI Inputs
  input logic       i_fdi_lp_linkerror,                        // Must be used in the Uncorrectable Error reg
  
  // FDI Outputs
  // output logic      o_fdi_pl_error,                          // masked
  output logic      o_fdi_pl_cerror,                         // logged
  output logic      o_fdi_pl_nferror,                        // logged only
  output logic      o_fdi_pl_trainerror,                     // any internal errors set this signal


  // RDI Inputs
  input logic       i_rdi_pl_trainerror,                        // phy Error
  input logic       i_rdi_pl_error,                             // recoverable through retrain
  input logic       i_rdi_pl_cerror,                            // logged correctable error
  input logic       i_rdi_pl_nferror,                           // logged only

  input logic       i_rdi_pl_phyinrecenter,                     // used to tell whether the link is training or retraining
  input logic [2:0] i_rdi_pl_speedmode,                         // logging
  input logic [2:0] i_rdi_pl_lnk_cfg,                           // logging 
  

	// ALSM Inputs
	input Adapter_Response i_adpater_lsm_response_type,       //! state at which timeout happened
	// input logic            i_lsm_error_valid, 						  	//! error valid signal to Regfile
	input logic            i_link_status, 										//! Link Status indication
	input logic            i_ce_adapter_transition_retrain,   //! ALSM in retrain indication
	input logic       		 i_ALSM_start_param_exch,           //! ALSM trigger for parameter exchange to SB

	// ALSM Outputs
	output logic        o_linkerror, 		                 //! Uncorrectable error signal from regfile
	output logic 			  o_start_retrain,                 //! SW retrain through Register File

  // Inputs from MB
  input  logic        i_MB_Receiver_Overflow,
  input  logic        i_MB_CRC_Error_Detected,
  input  logic        i_MB_Correctable_Internal_Error,
  // input  logic        i_MB_Error_Valid,


  // Inputs from SB
  input  logic [31:0] i_sb_mailbox_data_low,          // Completion data low written back to mailbox
  input  logic [31:0] i_sb_mailbox_data_high,         // Completion data high written back to mailbox
  input  logic [1:0]  i_sb_mailbox_status,            // Mailbox status encoding (success/UR/CA)
  input  logic        i_sb_mailbox_data_vld,          // Indicates mailbox data is valid (success completion)
  input  logic        i_sb_mailbox_trigger_en,        // Used to clear trigger after completion/timeout

  input  logic [63:0] i_sb_Header_log1,               // Log header for error cases (UR/CA)
  input  logic        i_sb_Header_log1_valid,         // Pulse to indicate log is valid
  input  logic [63:0] i_sb_adapter_advcap,            // Logging: advertised adapter cap value written to regfile
  input  logic        i_sb_adapter_advcap_valid,      // Write enable for advertised adapter cap log
  input  logic [63:0] i_sb_cxl_advcap,                // Logging: advertised CXL cap value written to regfile
  input  logic        i_sb_cxl_advcap_valid,          // Write enable for advertised CXL cap log
  input  logic [63:0] i_sb_adapter_fincap,            // Logging: finalized adapter cap written to regfile
  input  logic        i_sb_adapter_fincap_valid,      // Write enable for finalized adapter cap log
  input  logic [63:0] i_sb_cxl_fincap,                // Logging: finalized CXL cap written to regfile
  input  logic        i_sb_cxl_fincap_valid,          // Write enable for cxl fincap status register

  input  logic [4:0]  i_sb_flit_fromat_status,        // Writes final negotiated flit format into Link Status + Header Log2 locations
  input  logic        i_sb_flitfmt_valid,             // Write enable for flit format status register

  input  logic [63:0] i_sb_write_data,                // Write data of the request
  input  logic        i_sb_write_en,                  // Write enable
  input  logic [7:0]  i_sb_BE,                        // Byte enable
  input  logic [23:0] i_sb_address,                   // Address of request
  input  logic        i_sb_config_req,                // Config or memory request flag
  input  logic        i_sb_32_B,                      // 32 or 64 bits for data flag

  input  logic        i_sb_invalid_param_exch,        // Invalid parameter exchange
  input  logic        i_sb_local_timeout,             // Timeout due to local request
  input  logic        i_sb_remote_timeout,            // Timeout due to remote request
  input  logic        i_sb_fdi_overflow,              // FDI overflow
  input  logic        i_sb_rdi_overflow,              // RDI overflow
  input  logic        i_sb_parity_error,              // Parity error from TX or RX
  input  logic        i_sb_param_exch_timeout,        // Parameter exchange timeout
  input  logic        i_sb_invalid_opcode_id,         // Uncorrectable error due to invalid ID or invalid opcode
	input  logic 				i_sb_param_exch_done,           // SB finished parameter exchange signal

  input  sb_error_msg_encoding  i_sb_in_error_msg_encoding,     // Receiving err msg from remote die (fatal, non fatal, etc)

  // Outputs to SB
  output logic        o_sb_mailbox_trigger,           // Mailbox trigger bit
  output logic [31:0] o_sb_mailbox_index_low,         // Contains opcode/BE/address lower bits
  output logic [4:0]  o_sb_mailbox_index_high,        // Upper bits of address
  output logic [31:0] o_sb_mailbox_data_low,          // Payload lower 32b
  output logic [31:0] o_sb_mailbox_data_high,         // Payload upper 32b

  output logic [3:0]  o_sb_remote_threshold,          // Max allowed number of timeouts before raising "remote_time_out"
  output logic [63:0] o_sb_adapter_advcap,            // Local Advertised Adapter Capabilities used for negotiation
  output logic [63:0] o_sb_cxl_advcap,                // Local Advertised CXL Capabilities used for CXL negotiation stage
  output logic [4:0]  o_sb_flit_fmt_status,           // Current negotiated flit format from regfile, used when reporting to protocol layer
  output logic [2:0]  o_sb_status,                    // Completion status
  output logic [63:0] o_sb_read_data,                 // Read data from register

  output sb_error_msg_encoding  o_sb_out_error_msg_encoding,     // Sending err msg from remote die (fatal, non fatal, etc)

  output  logic       o_sb_format4_enabled,           // Enable format 4
  output  logic       o_sb_format6_enabled,           // Enable format 6

  // Input to SW
  input  logic [31:0] i_sw_mailbox_data_low,          // Completion data low written back to mailbox
  input  logic [31:0] i_sw_mailbox_data_high,         // Completion data high written back to mailbox
  input  logic [1:0]  i_sw_mailbox_status,            // Mailbox status encoding (success/UR/CA)
  input  logic        i_sw_mailbox_trigger_en,        // Used to clear trigger after completion/timeout

  // Output to SW
  output logic        o_sw_mailbox_trigger,           // Mailbox trigger bit
  output logic [31:0] o_sw_mailbox_index_low,         // Contains opcode/BE/address lower bits
  output logic [4:0]  o_sw_mailbox_index_high,        // Upper bits of address
  output logic [31:0] o_sw_mailbox_data_low,          // Payload lower 32b
  output logic [31:0] o_sw_mailbox_data_high,         // Payload upper 32b

  output logic        o_uncorrectable_error_IRQ,
  output logic        o_correctable_error_IRQ

);

logic w_mailbox_control_bit;
logic [1:0] w_mailbox_status;

logic [DATA_WIDTH - 1 : 0] mem_block [0 : MEM_BLOCK_DEPTH - 1] ;
logic [DATA_WIDTH - 1 : 0] dvsec [0 : DVSEC_DEPTH - 1] ;

logic [31:0] r_header_log2;
logic [31:0] w_header_log2_comb;

logic w_adapter_timeout_comb, w_receiver_overflow_comb, w_internal_error_comb, w_sb_fatal_error_received_comb,
      w_sb_non_fatal_error_received_comb, w_invalid_parameter_exchange_comb;
logic [31:0] w_uncorrectable_error_status_comb;

logic w_crc_error_detected_comb, w_adapter_lsm_transition_retrain_comb, 
      w_correctable_internal_error_comb, w_sideband_cerror_msg_received_comb;
logic [31:0] w_correctable_error_status_comb;

logic [63:0] w_sb_read_data_comb;
logic w_fdi_pl_cerror_comb, w_fdi_pl_nferror_comb, w_fdi_pl_trainerror_comb;

assign w_fdi_pl_cerror_comb     = |{mem_block[UNCORRECTABLE_ERROR_STATUS_WORD_OFFSET] & mem_block[UNCORRECTABLE_ERROR_MASK_WORD_OFFSET]};

assign w_fdi_pl_nferror_comb    = |{mem_block[UNCORRECTABLE_ERROR_STATUS_WORD_OFFSET] &
                                    mem_block[UNCORRECTABLE_ERROR_MASK_WORD_OFFSET]   &
                                   ~mem_block[UNCORRECTABLE_ERROR_MASK_WORD_OFFSET]
                                   };

assign w_fdi_pl_trainerror_comb = |{mem_block[UNCORRECTABLE_ERROR_STATUS_WORD_OFFSET] &
                                    mem_block[UNCORRECTABLE_ERROR_MASK_WORD_OFFSET]   &
                                    mem_block[UNCORRECTABLE_ERROR_MASK_WORD_OFFSET]
                                   };

assign o_start_retrain         =  dvsec[LINK_CONTROL_WORD_OFFSET][11];
assign o_linkerror             =  mem_block[UNCORRECTABLE_ERROR_STATUS_WORD_OFFSET][5] | {|dvsec[UNCORRECTABLE_ERROR_STATUS_WORD_OFFSET][3:0]};
assign w_mailbox_control_bit   =  dvsec[MAILBOX_DATA_HIGH_WORD_OFFSET + 1][0];
assign w_mailbox_status        =  dvsec[MAILBOX_DATA_HIGH_WORD_OFFSET + 1][9:8];

assign r_header_log2           =  mem_block[HEADER_LOG2_WORD_OFFSET];

assign o_sb_mailbox_trigger    =  w_mailbox_control_bit;
assign o_sb_mailbox_index_low  =  dvsec[MAILBOX_INDEX_LOW_WORD_OFFSET];
assign o_sb_mailbox_index_high =  dvsec[MAILBOX_INDEX_HIGH_WORD_OFFSET];
assign o_sb_mailbox_data_low   =  dvsec[MAILBOX_DATA_LOW_WORD_OFFSET];
assign o_sb_mailbox_data_high  =  dvsec[MAILBOX_DATA_HIGH_WORD_OFFSET];
assign o_sb_remote_threshold   =  dvsec[ERROR_AND_TESTING_WORD_OFFSET][3:0];
assign o_sb_adapter_advcap     =  {mem_block[ADV_CAP_WORD_OFFSET + 1], mem_block[ADV_CAP_WORD_OFFSET]};
assign o_sb_cxl_advcap         =  {mem_block[ADV_CAP_CXL_WORD_OFFSET + 1], mem_block[ADV_CAP_CXL_WORD_OFFSET]};
assign o_sb_flit_fmt_status    =  w_mailbox_status;

assign o_sb_format4_enabled = 'b0;
assign o_sb_format6_enabled = 'b0;
assign o_sb_status          = 'b0;

assign o_sw_mailbox_trigger    = w_mailbox_control_bit;
assign o_sw_mailbox_index_low  = dvsec[MAILBOX_INDEX_LOW_WORD_OFFSET];
assign o_sw_mailbox_index_high = dvsec[MAILBOX_INDEX_HIGH_WORD_OFFSET];
assign o_sw_mailbox_data_low   = dvsec[MAILBOX_DATA_LOW_WORD_OFFSET];
assign o_sw_mailbox_data_high  = dvsec[MAILBOX_DATA_HIGH_WORD_OFFSET];

always_ff @(posedge i_clk , negedge i_rst_n) begin : DVSEC_BLOCK
  if (~i_rst_n) begin
    foreach (dvsec[i]) begin
      dvsec[i] <= '{default: 'b0};
    end
    dvsec[PCIE_EX_WORD_OFFSET][15:0]  <= 'h23;
    dvsec[PCIE_EX_WORD_OFFSET][19:16] <= 'h1;
    // DVSEC[CAPABILITY_DESCRIPTOR_OFFSET][3:0]  <= '{default: 'b1};
    dvsec[2][19:16]  <= '{default: 'b1};
    dvsec[LINK_CAPABILITY_WORD_OFFSET][17]         <= 'b1;
    dvsec[MAILBOX_INDEX_LOW_WORD_OFFSET][12:0]     <= {8'hF, 5'b00100};
    dvsec[ERROR_AND_TESTING_WORD_OFFSET][3:0]      <= 4'b0100;
  end
  else if (~i_init) begin
    foreach (dvsec[i]) begin
      dvsec[i] <= '{default: 'b0};
    end
    dvsec[PCIE_EX_WORD_OFFSET][15:0]  <= 'h23;
    dvsec[PCIE_EX_WORD_OFFSET][19:16] <= 'h1;
    // DVSEC[CAPABILITY_DESCRIPTOR_OFFSET][3:0]  <= '{default: 'b1};
    dvsec[2][19:16]                                <= '{default: 'b1};
    dvsec[LINK_CAPABILITY_WORD_OFFSET][17]         <= 'b1;
    dvsec[MAILBOX_INDEX_LOW_WORD_OFFSET][12:0]     <= {8'hF, 5'b00100};
    dvsec[ERROR_AND_TESTING_WORD_OFFSET][3:0]      <= 4'b0100;
  end
  else begin
    dvsec[LINK_STATUS_WORD_OFFSET][9:7]   <= i_rdi_pl_lnk_cfg;
    dvsec[LINK_STATUS_WORD_OFFSET][13:11] <= i_rdi_pl_speedmode;
    dvsec[LINK_STATUS_WORD_OFFSET][15]    <= i_link_status;
    dvsec[LINK_STATUS_WORD_OFFSET][16]    <= i_ce_adapter_transition_retrain | i_rdi_pl_phyinrecenter;
    dvsec[LINK_STATUS_WORD_OFFSET][17]    <= i_link_status ^ dvsec[LINK_STATUS_WORD_OFFSET][15];

    if (w_mailbox_control_bit && i_sb_mailbox_data_vld && i_sb_mailbox_trigger_en) begin
      dvsec[MAILBOX_DATA_HIGH_WORD_OFFSET]          <= i_sb_mailbox_data_high;
      dvsec[MAILBOX_DATA_LOW_WORD_OFFSET]           <= i_sb_mailbox_data_low;
      dvsec[MAILBOX_DATA_HIGH_WORD_OFFSET + 1][9:8] <= i_sb_mailbox_status;
      dvsec[MAILBOX_DATA_HIGH_WORD_OFFSET + 1][0]   <= 'b0;
    end
    else if (~w_mailbox_control_bit && i_sw_mailbox_trigger_en) begin
      dvsec[MAILBOX_DATA_HIGH_WORD_OFFSET]          <= i_sw_mailbox_data_high;
      dvsec[MAILBOX_DATA_LOW_WORD_OFFSET]           <= i_sw_mailbox_data_low;
      dvsec[MAILBOX_DATA_HIGH_WORD_OFFSET + 1][9:8] <= i_sw_mailbox_status;
      dvsec[MAILBOX_DATA_HIGH_WORD_OFFSET + 1][0]   <= 'b1;
    end
    if (i_sb_flitfmt_valid) begin
      dvsec[LINK_STATUS_WORD_OFFSET][25:22] <= i_sb_flit_fromat_status;
    end
    if (i_sb_write_en && i_sb_config_req) begin
      logic [11:0] wl;
      logic [4:0]  bl;
      for (int i = 0; i < 8; i = i + 1) begin
        if (i_sb_32_B && i == 4) break;
        if (i_sb_BE[i]) begin
          calc_config_lanes(i, i_sb_address[11:0], wl, bl);
          dvsec[wl][bl +: 8] <= i_sb_write_data[i * 8 +: 8];
        end
      end
    end
  end
end

always_ff @(posedge i_clk , negedge i_rst_n) begin : MEM_BLOCK
  if (~i_rst_n) begin
    foreach (mem_block[i]) begin
      mem_block[i] <= '{default: 'b0};
    end
    mem_block[VENDOR_ID_WORD_OFFSET][15:0]               <= 'hD2DE;
    mem_block[VENDOR_REGISTER_WORD_OFFSET]               <= 'h2000;
    mem_block[UNCORRECTABLE_ERROR_MASK_WORD_OFFSET]      <= '{default: 'b1};
    mem_block[UNCORRECTABLE_ERROR_SEVERITY_WORD_OFFSET]  <= '{default: 'b1};
    mem_block[CORRECTABLE_ERROR_MASK_WORD_OFFSET]        <= '{default: 'b1};
  end
  else if (~i_init) begin
    foreach (mem_block[i]) begin
      mem_block[i] <= '{default: 'b0};
    end
    mem_block[VENDOR_ID_WORD_OFFSET][15:0]               <= 'hD2DE;
    mem_block[VENDOR_REGISTER_WORD_OFFSET]               <= 'h2000;
    mem_block[UNCORRECTABLE_ERROR_MASK_WORD_OFFSET]      <= '{default: 'b1};
    mem_block[UNCORRECTABLE_ERROR_SEVERITY_WORD_OFFSET]  <= '{default: 'b1};
    mem_block[CORRECTABLE_ERROR_MASK_WORD_OFFSET]        <= '{default: 'b1};
  end
  else begin
    mem_block[UNCORRECTABLE_ERROR_STATUS_WORD_OFFSET]    <= mem_block[UNCORRECTABLE_ERROR_STATUS_WORD_OFFSET] | w_uncorrectable_error_status_comb; 
    mem_block[CORRECTABLE_ERROR_STATUS_WORD_OFFSET]      <= mem_block[CORRECTABLE_ERROR_STATUS_WORD_OFFSET]   | w_correctable_error_status_comb; 
    mem_block[HEADER_LOG2_WORD_OFFSET]                   <= w_header_log2_comb;

    if (i_sb_Header_log1_valid) begin
      mem_block[HEADER_LOG1_WORD_OFFSET]     <= i_sb_Header_log1[31:0];
      mem_block[HEADER_LOG1_WORD_OFFSET + 1] <= i_sb_Header_log1[63:32];
    end
    if (i_sb_adapter_advcap_valid) begin
      mem_block[ADV_CAP_WORD_OFFSET]         <= i_sb_adapter_advcap[31:0];
      mem_block[ADV_CAP_WORD_OFFSET + 1]     <= i_sb_adapter_advcap[63:32];
    end
    if (i_sb_adapter_fincap_valid) begin
      mem_block[FIN_CAP_WORD_OFFSET]         <= i_sb_adapter_fincap[31:0];
      mem_block[FIN_CAP_WORD_OFFSET + 1]     <= i_sb_adapter_fincap[63:32];
    end
    if (i_sb_cxl_advcap_valid) begin
      mem_block[ADV_CAP_CXL_WORD_OFFSET]     <= i_sb_cxl_advcap[31:0];
      mem_block[ADV_CAP_CXL_WORD_OFFSET + 1] <= i_sb_cxl_advcap[63:32];
    end
    if (i_sb_cxl_fincap_valid) begin
      mem_block[FIN_CAP_CXL_WORD_OFFSET]     <= i_sb_cxl_fincap[31:0];
      mem_block[FIN_CAP_CXL_WORD_OFFSET + 1] <= i_sb_cxl_fincap[63:32];
    end
    if (i_sb_write_en && ~i_sb_config_req) begin
      logic [19:0] wl;
      logic [4:0]  bl;
      for (int i = 0; i < 8; i = i + 1) begin
          if (i_sb_32_B && i == 4) break;
          if (i_sb_BE[i]) begin
              calc_mem_lanes(i, i_sb_address[19:0], wl, bl);
              mem_block[wl][bl +: 8] <= i_sb_write_data[i * 8 +: 8];
          end
      end
    end
  end
end

always_ff @(posedge i_clk , negedge i_rst_n) begin : OUTPUT_BLOCK
  if (~i_rst_n) begin
    o_fdi_pl_cerror             <= 'b0;
    o_fdi_pl_nferror            <= 'b0;
    o_fdi_pl_trainerror         <= 'b0;
    o_uncorrectable_error_IRQ   <= 'b0;
    o_correctable_error_IRQ     <= 'b0;
    o_sb_out_error_msg_encoding <= NONE_ERR;
    o_sb_read_data              <= 'b0;
  end
  else if (~i_init) begin
    o_fdi_pl_cerror             <= 'b0;
    o_fdi_pl_nferror            <= 'b0;
    o_fdi_pl_trainerror         <= 'b0;
    o_uncorrectable_error_IRQ   <= 'b0;
    o_correctable_error_IRQ     <= 'b0;
    o_sb_out_error_msg_encoding <= NONE_ERR;
    o_sb_read_data              <= 'b0;
  end
  else begin
    if (o_fdi_pl_cerror) begin
      o_fdi_pl_cerror <= 'b0;
    end
    else begin
      o_fdi_pl_cerror <= w_fdi_pl_cerror_comb;
    end
    if (o_fdi_pl_nferror) begin
      o_fdi_pl_nferror <= 'b0;
    end
    else begin
      o_fdi_pl_nferror <= w_fdi_pl_nferror_comb;
    end
    o_fdi_pl_trainerror       <= w_fdi_pl_trainerror_comb;
    o_uncorrectable_error_IRQ <= |{mem_block[UNCORRECTABLE_ERROR_STATUS_WORD_OFFSET] | mem_block[UNCORRECTABLE_ERROR_MASK_WORD_OFFSET]};
    o_correctable_error_IRQ   <= |{mem_block[CORRECTABLE_ERROR_STATUS_WORD_OFFSET]   | mem_block[CORRECTABLE_ERROR_MASK_WORD_OFFSET]};
    o_sb_read_data            <= w_sb_read_data_comb;
  end
end

always_comb begin : UNCORRECTABLE_ERROR_BLOCK
  w_adapter_timeout_comb             =  i_sb_local_timeout     | i_sb_remote_timeout | i_sb_param_exch_timeout;
  w_receiver_overflow_comb           =  i_MB_Receiver_Overflow | i_sb_fdi_overflow   | i_sb_rdi_overflow;
  w_internal_error_comb              =  i_fdi_lp_linkerror     | i_sb_parity_error   | i_sb_invalid_opcode_id;
  w_sb_fatal_error_received_comb     = (i_sb_in_error_msg_encoding == FATAL_Err)     | i_rdi_pl_trainerror;
  w_sb_non_fatal_error_received_comb = (i_sb_in_error_msg_encoding == NON_FATAL_Err) | i_rdi_pl_nferror;
  w_invalid_parameter_exchange_comb  = (i_sb_invalid_param_exch);
  w_uncorrectable_error_status_comb  = {26'b0, w_invalid_parameter_exchange_comb, w_sb_non_fatal_error_received_comb, w_sb_fatal_error_received_comb,
                                        w_internal_error_comb, w_receiver_overflow_comb, w_adapter_timeout_comb};
end

always_comb begin : CORRECTABLE_ERROR_BLOCK
  w_crc_error_detected_comb               = i_MB_CRC_Error_Detected;
  w_adapter_lsm_transition_retrain_comb   = i_ce_adapter_transition_retrain;
  w_correctable_internal_error_comb       = i_MB_Correctable_Internal_Error | i_rdi_pl_error | i_rdi_pl_cerror;
  w_sideband_cerror_msg_received_comb     = (i_sb_in_error_msg_encoding == Correctable_Err);
  w_correctable_error_status_comb         = {27'b0, w_crc_error_detected_comb, w_adapter_lsm_transition_retrain_comb,
                                             w_correctable_internal_error_comb, w_sideband_cerror_msg_received_comb};
end

always_comb begin : HEADER_LOG2_BLOCK
  w_header_log2_comb = 'b0;

  if (r_header_log2[6:4] == 'b0) begin
    casex ({i_MB_Receiver_Overflow, i_sb_fdi_overflow, i_sb_rdi_overflow})
      'b1xx  : w_header_log2_comb[6:4]   = 'b001;
      'b01x  : w_header_log2_comb[6:4]   = 'b011;
      'b001  : w_header_log2_comb[6:4]   = 'b100;
      default: w_header_log2_comb[6:4]   = 'b000;
    endcase
  end
  else begin
    w_header_log2_comb[6:4] = r_header_log2[6:4];
  end
  if (i_ALSM_start_param_exch) begin
    w_header_log2_comb[13] =  'b0;
  end
  else if (i_sb_param_exch_done) begin
    w_header_log2_comb[13] = 'b1;
  end
  else begin
    w_header_log2_comb[13] = r_header_log2[13];
  end
  if (i_sb_flitfmt_valid) begin
    w_header_log2_comb[17:14] = i_sb_flit_fromat_status;
  end
  else begin
    w_header_log2_comb[17:14] = r_header_log2[17:14];
  end
  if (r_header_log2[22:18] == 'b0) begin
    casex ({mem_block[UNCORRECTABLE_ERROR_STATUS_WORD_OFFSET][5], mem_block[UNCORRECTABLE_ERROR_STATUS_WORD_OFFSET][3:0]})
      'b1xxxx: w_header_log2_comb[22:18] = 'h4;
      'b01xxx: w_header_log2_comb[22:18] = 'h3;
      'b001xx: w_header_log2_comb[22:18] = 'h2;
      'b0001x: w_header_log2_comb[22:18] = 'h1;
      'b00001: w_header_log2_comb[22:18] = 'h0;
      default: w_header_log2_comb[22:18] = 'h0; // no meaning
    endcase
  end
  else begin
    w_header_log2_comb[22:18] = r_header_log2;
  end
end

always_comb begin : READ_DATA_BLOCK
  w_sb_read_data_comb = 'b0;
  if (i_sb_config_req) begin
    logic [11:0] wl;
    logic [4:0]  bl;
    for (int i = 0; i < 8; i = i + 1) begin
      if (i_sb_32_B && i == 4) break;
      if (i_sb_BE[i]) begin
        calc_config_lanes(i, i_sb_address[11:0], wl, bl);
        // word_offset = byte_offset/4,  bit_offset = byte_offset * 8
        w_sb_read_data_comb[i * 8 +: 8] = dvsec[wl][bl +: 8];
      end
      else begin
        w_sb_read_data_comb[i * 8 +: 8] = 'b0;
      end
    end
  end
  else begin
    logic [19:0] wl;
    logic [4:0]  bl;
    for (int i = 0; i < 8; i = i + 1) begin
      if (i_sb_32_B && i == 4) break;
      if (i_sb_BE[i]) begin
        calc_mem_lanes(i, i_sb_address[19:0], wl, bl);
        // word_offset = byte_offset/4,  bit_offset = byte_offset * 8
        w_sb_read_data_comb[i * 8 +: 8] = mem_block[wl][bl +: 8];
      end
      else begin
        w_sb_read_data_comb[i * 8 +: 8] = 'b0;
      end
    end
  end
end
endmodule