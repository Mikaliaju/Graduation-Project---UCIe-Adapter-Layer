
// import UC_ALSM_package::*;

typedef enum logic [2:0] {
	Active_LSM_response_type    = 'b001,
	L1_LSM_response_type        = 'b010,
	L2_LSM_response_type        = 'b011,
	LinkReset_LSM_response_type = 'b100,
	Disable_LSM_response_type   = 'b101
} Adapter_Response;

module UC_regfile # (
  parameter  DVSEC_DEPTH   = 'd48,
  localparam DATA_WIDTH    = 'd32,
  localparam BLOCK_DEPTH   = 'd4096
) (

  input logic i_init,
  input logic i_clk,
  input logic i_rst_n,

  // FDI Inputs
  input logic i_fdi_lp_linkerror,                        // Must be used in the Uncorrectable Error reg
  
  // FDI Outputs
  output logic i_fdi_pl_error,                          // masked
  output logic i_fdi_pl_cerror,                         // logged
  output logic i_fdi_pl_nferror,                        // logged only
  output logic i_fdi_pl_trainerror,                     // any internal errors set this signal


  // RDI Inputs
  input logic i_rdi_pl_trainerror,                        // phy Error
  input logic i_rdi_lp_linkerror,                         // phy Error
  input logic i_rdi_pl_error,                             // recoverable through retrain
  input logic i_rdi_pl_cerror,                            // logged correctable error
  input logic i_rdi_pl_nferror,                           // logged only
  input logic i_rdi_pl_phyinrecenter,                     // used to tell whether the link is training or retraining
  input logic i_rdi_pl_speedmode,                         // logging
  input logic i_rdi_pl_lnk_cfg,                           // logging 
  

	// RegFile Inputs
	input Adapter_Response i_adpater_lsm_response_type,       //! state at which timeout happened
	input logic            i_lsm_error_valid, 						  	//! error valid signal to Regfile
	input logic            i_link_status, 										//! Link Status indication
	input logic            i_ce_adapter_transition_retrain,   //! ALSM in retrain indication

	// RegFile Outputs
	output logic            o_linkerror, 		                 //! Uncorrectable error signal from regfile
	output logic 			      o_start_retrain,                 //! SW retrain through Register File

  // Inputs from MB
  input  logic        i_MB_Receiver_Overflow,
  input  logic        i_MB_CRC_Error_Detected,
  input  logic        i_MB_Correctable_Internal_Error,
  input  logic        i_MB_Error_Valid,


  // Inputs from SB
  input  logic [31:0] i_sb_mailbox_data_low,          // Completion data low written back to mailbox
  input  logic [31:0] i_sb_mailbox_data_high,         // Completion data high written back to mailbox
  input  logic [1:0]  i_sb_mailbox_status,            // Mailbox status encoding (success/UR/CA)
  input  logic        i_sb_mailbox_data_vld,          // Indicates mailbox data is valid (success completion)
  input  logic        i_sb_mailbox_trigger_en,        // Used to clear trigger after completion/timeout
  input  logic [63:0] i_sb_Header_log1,               // Log header for error cases (UR/CA)
  input  logic        i_sb_Header_log1_valid,         // Pulse to indicate log is valid
  input  logic [4:0]  i_sb_flit_fromat_status,        // Writes final negotiated flit format into Link Status + Header Log2 locations
  input  logic        i_sb_format3_enabled,           // Enable format 3
  input  logic [63:0] i_sb_adapter_advcap,            // Logging: advertised adapter cap value written to regfile
  input  logic [63:0] i_sb_cxl_advcap,                // Logging: advertised CXL cap value written to regfile
  input  logic [63:0] i_sb_adapter_fincap,            // Logging: finalized adapter cap written to regfile
  input  logic [63:0] i_sb_cxl_fincap,                // Logging: finalized CXL cap written to regfile
  input  logic        i_sb_adapter_advcap_valid,      // Write enable for advertised adapter cap log
  input  logic        i_sb_cxl_advcap_valid,          // Write enable for advertised CXL cap log
  input  logic        i_sb_adapter_fincap_valid,      // Write enable for finalized adapter cap log
  input  logic        i_sb_flitfmt_valid,             // Write enable for flit format status register
  input  logic        i_sb_cxl_fincap_valid,          // Write enable for cxl fincap status register
  input  logic [63:0] i_sb_write_data,                // Write data of the request
  input  logic [7:0]  i_sb_BE,                        // Byte enable
  input  logic [23:0] i_sb_address,                   // Address of request
  input  logic        i_sb_config_req,                // Config or memory request flag
  input  logic        i_sb_32_B,                      // 32 or 64 bits for data flag
  input  logic        i_sb_write_en,                  // Write enable
  input  logic        i_sb_invalid_param_exch,        // Invalid parameter exchange
  input  logic        i_sb_local_timeout,             // Timeout due to local request
  input  logic        i_sb_remote_timeout,            // Timeout due to remote request
  input  logic [1:0]  i_sb_in_error_msg_encoding,     // Receiving err msg from remote die (fatal, non fatal, etc)
  input  logic        i_sb_fdi_overflow,              // FDI overflow
  input  logic        i_sb_rdi_overflow,              // RDI overflow
  input  logic        i_sb_parity_error,              // Parity error from TX or RX
  input  logic        i_sb_param_exch_timeout,        // Parameter exchange timeout
  input  logic        i_sb_invalid_opcode_id,         // Uncorrectable error due to invalid ID or invalid opcode

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
  output logic [63:0] o_sb_read_data,                 // Read data from register
  output logic [2:0]  o_sb_status,                    // Completion status
  output logic        o_sb_out_error_msg_encoding     // Sending err msg from remote die (fatal, non fatal, etc)
);


localparam [DVSEC_DEPTH - 1 : 0] PCIE_EX_WORD_OFFSET               = 'h0  / 'd4;
localparam [DVSEC_DEPTH - 1 : 0] LINK_CAPABILITY_WORD_OFFSET       = 'hA  / 'd4;
localparam [DVSEC_DEPTH - 1 : 0] LINK_CONTROL_WORD_OFFSET          = 'h10 / 'd4;
localparam [DVSEC_DEPTH - 1 : 0] LINK_STATUS_WORD_OFFSET           = 'h14 / 'd4;
localparam [DVSEC_DEPTH - 1 : 0] LINK_NOTIFICATION_WORD_OFFSET     = 'h18 / 'd4;
localparam [DVSEC_DEPTH - 1 : 0] MAILBOX_INDEX_LOW_WORD_OFFSET  = 'd24;
localparam [DVSEC_DEPTH - 1 : 0] MAILBOX_INDEX_HIGH_WORD_OFFSET = MAILBOX_INDEX_LOW_WORD_OFFSET + 1;
localparam [DVSEC_DEPTH - 1 : 0] MAILBOX_DATA_LOW_WORD_OFFSET   = MAILBOX_INDEX_LOW_WORD_OFFSET + 2;
localparam [DVSEC_DEPTH - 1 : 0] MAILBOX_DATA_HIGH_WORD_OFFSET  = MAILBOX_INDEX_LOW_WORD_OFFSET + 3;

localparam [BLOCK_DEPTH - 1 : 0] UNCORRECTABLE_ERROR_STATUS_WORD_OFFSET   = 'h14 / 'd4;
localparam [BLOCK_DEPTH - 1 : 0] UNCORRECTABLE_ERROR_MASK_WORD_OFFSET     = 'h14 / 'd4;
localparam [BLOCK_DEPTH - 1 : 0] UNCORRECTABLE_ERROR_SEVERITY_WORD_OFFSET = 'h18 / 'd4;
localparam [BLOCK_DEPTH - 1 : 0] CORRECTABLE_ERROR_MASK_WORD_OFFSET       = 'h20 / 'd4;

localparam [BLOCK_DEPTH - 1 : 0] HEADER_LOG2_WORD_OFFSET = 'h2C / 'd4;

logic block [0 : BLOCK_DEPTH - 1] [DATA_WIDTH - 1 : 0];
logic dvsec [0 : DVSEC_DEPTH - 1] [DATA_WIDTH - 1 : 0];

assign o_start_retrain = dvsec[LINK_CONTROL_WORD_OFFSET][11];
assign o_linkerror = |{<<{dvsec[UNCORRECTABLE_ERROR_STATUS_WORD_OFFSET][5:0]}};



always_ff @(posedge i_clk, negedge i_rst_n) begin
  if (~i_rst_n) begin
    foreach (block[i]) begin
      block[i] <= '{default: 'b0};
    end
    dvsec[PCIE_EX_WORD_OFFSET][15:0] <= {>>{'h23}};
    dvsec[PCIE_EX_WORD_OFFSET][19:16] <= {>>{'h1}};

    // DVSEC[CAPABILITY_DESCRIPTOR_OFFSET][3:0]  <= '{default: 'b1};
    dvsec[2][19:16]  <= '{default: 'b1};

    dvsec[LINK_CAPABILITY_WORD_OFFSET][17]         <= 'b1;
    dvsec[MAILBOX_INDEX_LOW_WORD_OFFSET][12:0]     <= {>>{8'hF, 5'b00100}};

    block[UNCORRECTABLE_ERROR_MASK_WORD_OFFSET]      <= '{default: 'b1};
    block[UNCORRECTABLE_ERROR_SEVERITY_WORD_OFFSET]  <= '{default: 'b1};
    block[CORRECTABLE_ERROR_MASK_WORD_OFFSET]        <= '{default: 'b1};
  end
  else if (~i_init) begin
    foreach (block[i]) begin
      block[i] <= '{default: 'b0};
    end
    dvsec[PCIE_EX_WORD_OFFSET][15:0] <= {>>{'h23}};
    dvsec[PCIE_EX_WORD_OFFSET][19:16] <= {>>{'h1}};

    // DVSEC[CAPABILITY_DESCRIPTOR_OFFSET][3:0]  <= '{default: 'b1};
    dvsec[2][19:16]  <= '{default: 'b1};

    dvsec[LINK_CAPABILITY_WORD_OFFSET][17]         <= 'b1;
    dvsec[MAILBOX_INDEX_LOW_WORD_OFFSET][12:0]     <= {>>{8'hF, 5'b00100}};

    block[UNCORRECTABLE_ERROR_MASK_WORD_OFFSET]      <= '{default: 'b1};
    block[UNCORRECTABLE_ERROR_SEVERITY_WORD_OFFSET]  <= '{default: 'b1};
    block[CORRECTABLE_ERROR_MASK_WORD_OFFSET]        <= '{default: 'b1};
  end
  else begin
    dvsec[LINK_STATUS_WORD_OFFSET][15]  <= i_link_status;
    dvsec[LINK_STATUS_WORD_OFFSET][16]  <= i_ce_adapter_transition_retrain | i_rdi_pl_phyinrecenter;
    dvsec[LINK_STATUS_WORD_OFFSET][17]  <= i_link_status ^ dvsec[LINK_STATUS_WORD_OFFSET][15];
    block[HEADER_LOG2_WORD_OFFSET][9:7] <= {>>{i_adpater_lsm_response_type}};
  end
end
endmodule