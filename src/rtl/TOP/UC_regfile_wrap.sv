// ============================================================
// File: UC_regfile_wrap.sv
// Description: Wrapper binding interfaces to UC_regfile
// ============================================================
import UC_ALSM_package::*;
import UC_sb_pkg::*;
// `include "UC_rdi_if.sv"
// `include "UC_fdi_if.sv"
// `include "UC_regfile_if.sv"


module UC_regfile_wrap (
    input  logic        i_clk,
    input  logic        i_rst_n,
    input  logic        i_init,

    UC_fdi_if.regfile      fdi,
    UC_rdi_if.regfile      rdi,
    UC_regfile_if.regfile  rf,

    // SW Interface
    input  logic [31:0] i_sw_mailbox_data_low,
    input  logic [31:0] i_sw_mailbox_data_high,
    input  logic [1:0]  i_sw_mailbox_status,
    input  logic        i_sw_mailbox_trigger_en,
    output logic        o_sw_mailbox_trigger,
    output logic [31:0] o_sw_mailbox_index_low,
    output logic [4:0]  o_sw_mailbox_index_high,
    output logic [31:0] o_sw_mailbox_data_low,
    output logic [31:0] o_sw_mailbox_data_high,

    // IRQ
    output logic        o_uncorrectable_error_IRQ,
    output logic        o_correctable_error_IRQ
);

    //----------------------------------------------------------
    // Internal wires — FDI
    //----------------------------------------------------------
    logic               w_fdi_lp_linkerror;
    logic               w_fdi_pl_cerror;
    logic               w_fdi_pl_nferror;
    logic               w_fdi_pl_trainerror;

    //----------------------------------------------------------
    // Internal wires — RDI
    //----------------------------------------------------------
    logic               w_rdi_pl_trainerror;
    logic               w_rdi_pl_error;
    logic               w_rdi_pl_cerror;
    logic               w_rdi_pl_nferror;
    logic               w_rdi_pl_phyinrecenter;
    logic [2:0]         w_rdi_pl_speedmode;
    logic [2:0]         w_rdi_pl_lnk_cfg;

    //----------------------------------------------------------
    // Internal wires — ALSM
    //----------------------------------------------------------
    Adapter_Response    w_adpater_lsm_response_type;
    logic               w_link_status;
    logic               w_ce_adapter_transition_retrain;
    logic               w_alsm_start_param_exch;
    logic               w_linkerror_out;
    logic               w_start_retrain_out;
    logic               w_start_link_train_out;
    logic               w_start_link_train_clear;

    //----------------------------------------------------------
    // Internal wires — RegFile SB
    //----------------------------------------------------------
    logic [63:0]        w_sb_write_data;
    logic               w_sb_write_en;
    logic [7:0]         w_sb_BE;
    logic [23:0]        w_sb_address;
    logic               w_sb_config_req;
    logic               w_sb_32_B;
    logic [2:0]         w_status_out;
    logic [63:0]        w_read_data_out;

    logic [31:0]        w_sb_mailbox_data_low;
    logic [31:0]        w_sb_mailbox_data_high;
    logic [1:0]         w_sb_mailbox_status;
    logic               w_sb_mailbox_data_vld;
    logic               w_sb_mailbox_trigger_en;
    logic               w_sb_mailbox_trigger;
    logic [31:0]        w_sb_mailbox_index_low;
    logic [4:0]         w_sb_mailbox_index_high;
    logic [31:0]        w_sb_mailbox_data_low_out;
    logic [31:0]        w_sb_mailbox_data_high_out;
    logic [3:0]         w_sb_remote_threshold;

    logic [63:0]        w_sb_header_log1;
    logic               w_sb_header_log1_valid;

    logic [63:0]        w_sb_adapter_advcap;
    logic               w_sb_adapter_advcap_valid;
    logic [63:0]        w_sb_cxl_advcap;
    logic               w_sb_cxl_advcap_valid;
    logic [63:0]        w_sb_adapter_fincap;
    logic               w_sb_adapter_fincap_valid;
    logic [63:0]        w_sb_cxl_fincap;
    logic               w_sb_cxl_fincap_valid;

    logic [63:0]        w_sb_adapter_advcap_out;
    logic [63:0]        w_sb_cxl_advcap_out;

    logic [4:0]         w_sb_flit_fmt_status_in;
    logic               w_sb_flitfmt_valid;
    logic [4:0]         w_sb_flit_fmt_status_out;

    logic               w_sb_invalid_param_exch;
    logic               w_sb_local_timeout;
    logic               w_sb_remote_timeout;
    logic               w_sb_fdi_overflow;
    logic               w_sb_rdi_overflow;
    logic               w_sb_parity_error;
    logic               w_sb_param_exch_timeout;
    logic               w_sb_invalid_opcode_id;
    logic               w_sb_param_exch_done;

    sb_error_msg_encoding w_sb_in_error_msg_encoding;
    sb_error_msg_encoding w_sb_out_error_msg_encoding;

    logic               w_sb_format4_enabled;
    logic               w_sb_format6_enabled;

    //----------------------------------------------------------
    // Interface → wire (inputs to regfile)
    //----------------------------------------------------------

    // FDI
    assign w_fdi_lp_linkerror         = fdi.lp_linkerror_rf;

    // RDI
    assign w_rdi_pl_trainerror        = rdi.pl_trainerror;
    assign w_rdi_pl_error             = rdi.pl_error_rf;
    assign w_rdi_pl_cerror            = rdi.pl_cerror;
    assign w_rdi_pl_nferror           = rdi.pl_nferror;
    assign w_rdi_pl_phyinrecenter     = rdi.pl_phyinrecenter_rf;
    assign w_rdi_pl_speedmode         = rdi.pl_speedmode_rf;
    assign w_rdi_pl_lnk_cfg           = rdi.pl_lnk_cfg_rf;

    // ALSM
    assign w_adpater_lsm_response_type    = rf.alsm_response_type;
    assign w_link_status                  = rf.alsm_link_status;
    assign w_ce_adapter_transition_retrain= rf.alsm_ce_retrain;
    assign w_alsm_start_param_exch        = rf.alsm_start_param_exch;

    // SB
    assign w_sb_write_data            = rf.write_data;
    assign w_sb_write_en              = rf.write_en;
    assign w_sb_BE                    = rf.be;
    assign w_sb_address               = rf.address;
    assign w_sb_config_req            = rf.config_req;
    assign w_sb_32_B                  = rf.reg_32_B;

    assign w_sb_mailbox_data_low      = rf.sb_mailbox_data_low;
    assign w_sb_mailbox_data_high     = rf.sb_mailbox_data_high;
    assign w_sb_mailbox_status        = rf.sb_mailbox_status;
    assign w_sb_mailbox_data_vld      = rf.sb_mailbox_data_vld;
    assign w_sb_mailbox_trigger_en    = rf.sb_mailbox_trigger_en;

    assign w_sb_header_log1           = rf.sb_header_log1;
    assign w_sb_header_log1_valid     = rf.sb_header_log1_valid;

    assign w_sb_adapter_advcap        = rf.sb_adapter_advcap;
    assign w_sb_adapter_advcap_valid  = rf.sb_adapter_advcap_valid;
    assign w_sb_cxl_advcap            = rf.sb_cxl_advcap;
    assign w_sb_cxl_advcap_valid      = rf.sb_cxl_advcap_valid;
    assign w_sb_adapter_fincap        = rf.sb_adapter_fincap;
    assign w_sb_adapter_fincap_valid  = rf.sb_adapter_fincap_valid;
    assign w_sb_cxl_fincap            = rf.sb_cxl_fincap;
    assign w_sb_cxl_fincap_valid      = rf.sb_cxl_fincap_valid;

    assign w_sb_flit_fmt_status_in    = rf.sb_flit_fmt_status_in;
    assign w_sb_flitfmt_valid         = rf.sb_flitfmt_valid;

    assign w_sb_invalid_param_exch    = rf.sb_invalid_param_exch;
    assign w_sb_local_timeout         = rf.sb_local_timeout;
    assign w_sb_remote_timeout        = rf.sb_remote_timeout;
    assign w_sb_fdi_overflow          = rf.sb_fdi_overflow;
    assign w_sb_rdi_overflow          = rf.sb_rdi_overflow;
    assign w_sb_parity_error          = rf.sb_parity_error;
    assign w_sb_param_exch_timeout    = rf.sb_param_exch_timeout;
    assign w_sb_invalid_opcode_id     = rf.sb_invalid_opcode_id;
    assign w_sb_param_exch_done       = rf.sb_param_exch_done;
    assign w_sb_in_error_msg_encoding = rf.sb_in_error_msg_encoding;

    //----------------------------------------------------------
    // Wire → interface (outputs from regfile)
    //----------------------------------------------------------

    // FDI
    assign fdi.pl_cerror              = w_fdi_pl_cerror;
    assign fdi.pl_nferror             = w_fdi_pl_nferror;
    assign fdi.pl_trainerror          = w_fdi_pl_trainerror;

    // ALSM
    assign rf.alsm_linkerror          = w_linkerror_out;
    assign rf.alsm_start_retrain      = w_start_retrain_out;
    assign rf.alsm_start_link_train   = w_start_link_train_out;
    assign w_start_link_train_clear   = rf.alsm_start_link_train_clear;

    // SB
    assign rf.read_data               = w_read_data_out;
    assign rf.status                  = w_status_out;
    assign rf.sb_mailbox_trigger      = w_sb_mailbox_trigger;
    assign rf.sb_mailbox_index_low    = w_sb_mailbox_index_low;
    assign rf.sb_mailbox_index_high   = w_sb_mailbox_index_high;
    assign rf.sb_mailbox_data_low_out = w_sb_mailbox_data_low_out;
    assign rf.sb_mailbox_data_high_out= w_sb_mailbox_data_high_out;
    assign rf.sb_remote_threshold     = w_sb_remote_threshold;
    assign rf.sb_adapter_advcap_out   = w_sb_adapter_advcap_out;
    assign rf.sb_cxl_advcap_out       = w_sb_cxl_advcap_out;
    assign rf.sb_flit_fmt_status_out  = w_sb_flit_fmt_status_out;
    assign rf.sb_out_error_msg_encoding = w_sb_out_error_msg_encoding;
    assign rf.sb_format4_enabled      = w_sb_format4_enabled;
    assign rf.sb_format6_enabled      = w_sb_format6_enabled;

    //----------------------------------------------------------
    // DUT Instantiation
    //----------------------------------------------------------
    UC_regfile u_UC_regfile (
        .i_clk                          ( i_clk                          ),
        .i_rst_n                        ( i_rst_n                        ),
        .i_init                         ( i_init                         ),

        // FDI
        .i_fdi_lp_linkerror             ( w_fdi_lp_linkerror             ),
        .o_fdi_pl_cerror                ( w_fdi_pl_cerror                ),
        .o_fdi_pl_nferror               ( w_fdi_pl_nferror               ),
        .o_fdi_pl_trainerror            ( w_fdi_pl_trainerror            ),

        // RDI
        .i_rdi_pl_trainerror            ( w_rdi_pl_trainerror            ),
        .i_rdi_pl_error                 ( w_rdi_pl_error                 ),
        .i_rdi_pl_cerror                ( w_rdi_pl_cerror                ),
        .i_rdi_pl_nferror               ( w_rdi_pl_nferror               ),
        .i_rdi_pl_phyinrecenter         ( w_rdi_pl_phyinrecenter         ),
        .i_rdi_pl_speedmode             ( w_rdi_pl_speedmode             ),
        .i_rdi_pl_lnk_cfg               ( w_rdi_pl_lnk_cfg               ),

        // ALSM
        .i_adpater_lsm_response_type    ( w_adpater_lsm_response_type    ),
        .i_link_status                  ( w_link_status                  ),
        .i_ce_adapter_transition_retrain( w_ce_adapter_transition_retrain),
        .i_ALSM_start_param_exch        ( w_alsm_start_param_exch        ),
        .o_linkerror                    ( w_linkerror_out                ),
        .o_start_retrain                ( w_start_retrain_out            ),

        // MB
        .i_MB_Receiver_Overflow         ( rf.mb_receiver_overflow        ),
        .i_MB_CRC_Error_Detected        ( rf.mb_crc_error                ),
        .i_MB_Correctable_Internal_Error( rf.mb_correctable_error        ),

        // SB
        .i_sb_mailbox_data_low          ( w_sb_mailbox_data_low          ),
        .i_sb_mailbox_data_high         ( w_sb_mailbox_data_high         ),
        .i_sb_mailbox_status            ( w_sb_mailbox_status            ),
        .i_sb_mailbox_data_vld          ( w_sb_mailbox_data_vld          ),
        .i_sb_mailbox_trigger_en        ( w_sb_mailbox_trigger_en        ),
        .o_sb_mailbox_trigger           ( w_sb_mailbox_trigger           ),
        .o_sb_mailbox_index_low         ( w_sb_mailbox_index_low         ),
        .o_sb_mailbox_index_high        ( w_sb_mailbox_index_high        ),
        .o_sb_mailbox_data_low          ( w_sb_mailbox_data_low_out      ),
        .o_sb_mailbox_data_high         ( w_sb_mailbox_data_high_out     ),
        .o_sb_remote_threshold          ( w_sb_remote_threshold          ),

        .i_sb_Header_log1               ( w_sb_header_log1               ),
        .i_sb_Header_log1_valid         ( w_sb_header_log1_valid         ),

        .i_sb_adapter_advcap            ( w_sb_adapter_advcap            ),
        .i_sb_adapter_advcap_valid      ( w_sb_adapter_advcap_valid      ),
        .i_sb_cxl_advcap                ( w_sb_cxl_advcap                ),
        .i_sb_cxl_advcap_valid          ( w_sb_cxl_advcap_valid          ),
        .i_sb_adapter_fincap            ( w_sb_adapter_fincap            ),
        .i_sb_adapter_fincap_valid      ( w_sb_adapter_fincap_valid      ),
        .i_sb_cxl_fincap                ( w_sb_cxl_fincap                ),
        .i_sb_cxl_fincap_valid          ( w_sb_cxl_fincap_valid          ),
        .o_sb_adapter_advcap            ( w_sb_adapter_advcap_out        ),
        .o_sb_cxl_advcap                ( w_sb_cxl_advcap_out            ),

        .i_sb_flit_fromat_status        ( w_sb_flit_fmt_status_in        ),
        .i_sb_flitfmt_valid             ( w_sb_flitfmt_valid             ),
        .o_sb_flit_fmt_status           ( w_sb_flit_fmt_status_out       ),

        .i_sb_write_data                ( w_sb_write_data                ),
        .i_sb_write_en                  ( w_sb_write_en                  ),
        .i_sb_BE                        ( w_sb_BE                        ),
        .i_sb_address                   ( w_sb_address                   ),
        .i_sb_config_req                ( w_sb_config_req                ),
        .i_sb_32_B                      ( w_sb_32_B                      ),
        .o_sb_status                    ( w_status_out                   ),
        .o_sb_read_data                 ( w_read_data_out                ),

        .i_sb_invalid_param_exch        ( w_sb_invalid_param_exch        ),
        .i_sb_local_timeout             ( w_sb_local_timeout             ),
        .i_sb_remote_timeout            ( w_sb_remote_timeout            ),
        .i_sb_fdi_overflow              ( w_sb_fdi_overflow              ),
        .i_sb_rdi_overflow              ( w_sb_rdi_overflow              ),
        .i_sb_parity_error              ( w_sb_parity_error              ),
        .i_sb_param_exch_timeout        ( w_sb_param_exch_timeout        ),
        .i_sb_invalid_opcode_id         ( w_sb_invalid_opcode_id         ),
        .i_sb_param_exch_done           ( w_sb_param_exch_done           ),
        .i_sb_in_error_msg_encoding     ( w_sb_in_error_msg_encoding     ),
        .o_sb_out_error_msg_encoding    ( w_sb_out_error_msg_encoding    ),
        .o_sb_format4_enabled           ( w_sb_format4_enabled           ),
        .o_sb_format6_enabled           ( w_sb_format6_enabled           ),

        // SW
        .i_sw_mailbox_data_low          ( i_sw_mailbox_data_low          ),
        .i_sw_mailbox_data_high         ( i_sw_mailbox_data_high         ),
        .i_sw_mailbox_status            ( i_sw_mailbox_status            ),
        .i_sw_mailbox_trigger_en        ( i_sw_mailbox_trigger_en        ),
        .o_sw_mailbox_trigger           ( o_sw_mailbox_trigger           ),
        .o_sw_mailbox_index_low         ( o_sw_mailbox_index_low         ),
        .o_sw_mailbox_index_high        ( o_sw_mailbox_index_high        ),
        .o_sw_mailbox_data_low          ( o_sw_mailbox_data_low          ),
        .o_sw_mailbox_data_high         ( o_sw_mailbox_data_high         ),

        // IRQ
        .o_uncorrectable_error_IRQ      ( o_uncorrectable_error_IRQ      ),
        .o_correctable_error_IRQ        ( o_correctable_error_IRQ        )
    );

endmodule : UC_regfile_wrap