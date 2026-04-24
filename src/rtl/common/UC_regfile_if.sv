// ============================================================
// File: UC_regfile_if.sv
// Description: Register File Interface
// ============================================================
// `ifndef UC_REGFILE_IF
// `define UC_REGFILE_IF
import UC_ALSM_package::*;
import UC_sb_pkg::*;

interface UC_regfile_if (
    input logic i_clk
);

    //----------------------------------------------------------
    // SB ↔ RegFile Signals
    //----------------------------------------------------------
    // SB reads from RegFile
    logic [63:0]                read_data;          // Read data from RegFile
    logic [2:0]                 status;             // Completion status

    // SB writes to RegFile
    logic [63:0]                write_data;         // Write data
    logic                       write_en;           // Write enable
    logic [23:0]                address;            // Address of request
    logic [7:0]                 be;                 // Byte enable
    logic                       config_req;         // Config or memory request
    logic                       reg_32_B;           // 32 or 64-bit data flag
    logic                       valid;              // Access valid

    // Mailbox (RP only)
    logic [31:0]                sb_mailbox_data_low;
    logic [31:0]                sb_mailbox_data_high;
    logic [1:0]                 sb_mailbox_status;
    logic                       sb_mailbox_data_vld;
    logic                       sb_mailbox_trigger_en;

    logic                       sb_mailbox_trigger;
    logic [31:0]                sb_mailbox_index_low;
    logic [4:0]                 sb_mailbox_index_high;
    logic [31:0]                sb_mailbox_data_low_out;
    logic [31:0]                sb_mailbox_data_high_out;
    logic [3:0]                 sb_remote_threshold;

    // Header Log
    logic [63:0]                sb_header_log1;
    logic                       sb_header_log1_valid;

    // Parameter Exchange Logging
    logic [63:0]                sb_adapter_advcap;
    logic                       sb_adapter_advcap_valid;
    logic [63:0]                sb_cxl_advcap;
    logic                       sb_cxl_advcap_valid;
    logic [63:0]                sb_adapter_fincap;
    logic                       sb_adapter_fincap_valid;
    logic [63:0]                sb_cxl_fincap;
    logic                       sb_cxl_fincap_valid;

    logic [63:0]                sb_adapter_advcap_out;
    logic [63:0]                sb_cxl_advcap_out;

    // Flit Format
    logic [4:0]                 sb_flit_fmt_status_in;
    logic                       sb_flitfmt_valid;
    logic [4:0]                 sb_flit_fmt_status_out;

    // Error signals (SB → RegFile)
    logic                       sb_invalid_param_exch;
    logic                       sb_local_timeout;
    logic                       sb_remote_timeout;
    logic                       sb_fdi_overflow;
    logic                       sb_rdi_overflow;
    logic                       sb_parity_error;
    logic                       sb_param_exch_timeout;
    logic                       sb_invalid_opcode_id;
    logic                       sb_param_exch_done;

    // Error message encoding
    sb_error_msg_encoding       sb_in_error_msg_encoding;
    sb_error_msg_encoding       sb_out_error_msg_encoding;

    // Format enables
    logic                       sb_format4_enabled;
    logic                       sb_format6_enabled;

    //----------------------------------------------------------
    // ALSM ↔ RegFile Signals
    //----------------------------------------------------------
    Adapter_Response            alsm_response_type;
    logic                       alsm_linkerror;
    logic                       alsm_start_retrain;
    logic                       alsm_link_status;
    logic                       alsm_ce_retrain;
    logic                       alsm_start_param_exch;
    logic                       alsm_start_link_train;
    logic                       alsm_start_link_train_clear;

    //----------------------------------------------------------
    // MB ↔ RegFile Signals
    //----------------------------------------------------------
    logic                       mb_receiver_overflow;
    logic                       mb_crc_error;
    logic                       mb_correctable_error;

    //----------------------------------------------------------
    // SW ↔ RegFile Signals
    //----------------------------------------------------------
    logic [31:0]                sw_mailbox_data_low;
    logic [31:0]                sw_mailbox_data_high;
    logic [1:0]                 sw_mailbox_status;
    logic                       sw_mailbox_trigger_en;

    logic                       sw_mailbox_trigger;
    logic [31:0]                sw_mailbox_index_low;
    logic [4:0]                 sw_mailbox_index_high;
    logic [31:0]                sw_mailbox_data_low_out;
    logic [31:0]                sw_mailbox_data_high_out;

    // IRQ outputs
    logic                       uncorrectable_error_irq;
    logic                       correctable_error_irq;

    //----------------------------------------------------------
    // Modports
    //----------------------------------------------------------

    // SB Top modport
    modport sb_top (
        // Read interface (RegFile → SB)
        input  read_data,
        input  status,
        // Write interface (SB → RegFile)
        output write_data,
        output write_en,
        output address,
        output be,
        output config_req,
        output reg_32_B,
        output valid,
        // Mailbox (RP)
        input  sb_mailbox_trigger,
        input  sb_mailbox_index_low,
        input  sb_mailbox_index_high,
        input  sb_mailbox_data_low_out,
        input  sb_mailbox_data_high_out,
        input  sb_remote_threshold,
        output sb_mailbox_data_low,
        output sb_mailbox_data_high,
        output sb_mailbox_status,
        output sb_mailbox_data_vld,
        output sb_mailbox_trigger_en,
        // Header Log
        output sb_header_log1,
        output sb_header_log1_valid,
        // Cap logging
        output sb_adapter_advcap,
        output sb_adapter_advcap_valid,
        output sb_cxl_advcap,
        output sb_cxl_advcap_valid,
        output sb_adapter_fincap,
        output sb_adapter_fincap_valid,
        output sb_cxl_fincap,
        output sb_cxl_fincap_valid,
        input  sb_adapter_advcap_out,
        input  sb_cxl_advcap_out,
        // Flit format
        output sb_flit_fmt_status_in,
        output sb_flitfmt_valid,
        input  sb_flit_fmt_status_out,
        // Error signals
        output sb_invalid_param_exch,
        output sb_local_timeout,
        output sb_remote_timeout,
        output sb_fdi_overflow,
        output sb_rdi_overflow,
        output sb_parity_error,
        output sb_param_exch_timeout,
        output sb_invalid_opcode_id,
        output sb_param_exch_done,
        output sb_in_error_msg_encoding,
        input  sb_out_error_msg_encoding,
        // Format enables
        input  sb_format4_enabled,
        input  sb_format6_enabled
    );

    // ALSM modport
    modport alsm (
        input  alsm_linkerror,
        input  alsm_start_retrain,
        input  alsm_start_link_train,
        output alsm_response_type,
        output alsm_link_status,
        output alsm_ce_retrain,
        output alsm_start_param_exch,
        output alsm_start_link_train_clear
    );

    // RegFile module modport
    modport regfile (
        // SB connections
        output read_data,
        output status,
        input  write_data,
        input  write_en,
        input  address,
        input  be,
        input  config_req,
        input  reg_32_B,
        input  valid,
        // Mailbox
        input  sb_mailbox_data_low,
        input  sb_mailbox_data_high,
        input  sb_mailbox_status,
        input  sb_mailbox_data_vld,
        input  sb_mailbox_trigger_en,
        output sb_mailbox_trigger,
        output sb_mailbox_index_low,
        output sb_mailbox_index_high,
        output sb_mailbox_data_low_out,
        output sb_mailbox_data_high_out,
        output sb_remote_threshold,
        // Header log
        input  sb_header_log1,
        input  sb_header_log1_valid,
        // Cap logging
        input  sb_adapter_advcap,
        input  sb_adapter_advcap_valid,
        input  sb_cxl_advcap,
        input  sb_cxl_advcap_valid,
        input  sb_adapter_fincap,
        input  sb_adapter_fincap_valid,
        input  sb_cxl_fincap,
        input  sb_cxl_fincap_valid,
        output sb_adapter_advcap_out,
        output sb_cxl_advcap_out,
        // Flit format
        input  sb_flit_fmt_status_in,
        input  sb_flitfmt_valid,
        output sb_flit_fmt_status_out,
        // Error signals
        input  sb_invalid_param_exch,
        input  sb_local_timeout,
        input  sb_remote_timeout,
        input  sb_fdi_overflow,
        input  sb_rdi_overflow,
        input  sb_parity_error,
        input  sb_param_exch_timeout,
        input  sb_invalid_opcode_id,
        input  sb_param_exch_done,
        input  sb_in_error_msg_encoding,
        output sb_out_error_msg_encoding,
        // Format enables
        output sb_format4_enabled,
        output sb_format6_enabled,
        // ALSM
        input  alsm_response_type,
        input  alsm_link_status,
        input  alsm_ce_retrain,
        input  alsm_start_param_exch,
        output alsm_linkerror,
        output alsm_start_retrain,
        output alsm_start_link_train,
        input  alsm_start_link_train_clear,
        // MB
        input  mb_receiver_overflow,
        input  mb_crc_error,
        input  mb_correctable_error,
        // SW
        input  sw_mailbox_data_low,
        input  sw_mailbox_data_high,
        input  sw_mailbox_status,
        input  sw_mailbox_trigger_en,
        output sw_mailbox_trigger,
        output sw_mailbox_index_low,
        output sw_mailbox_index_high,
        output sw_mailbox_data_low_out,
        output sw_mailbox_data_high_out,
        // IRQ
        output uncorrectable_error_irq,
        output correctable_error_irq
    );

endinterface : UC_regfile_if
// `endif // UC_REGFILE_IF