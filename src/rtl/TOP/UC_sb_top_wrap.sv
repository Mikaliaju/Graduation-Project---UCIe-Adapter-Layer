// ============================================================
// File: UC_sb_top_wrap.sv
// Description: Wrapper binding interfaces to UC_sb_top ports
// ============================================================
include UC_sb_pkg::*;
module UC_sb_top_wrap #(
    parameter int P_NC                  = 32,
    parameter int P_RX_NUM_OF_COMP_PKTS = 4,
    parameter int P_RX_NUM_OF_MSG_PKTS  = 2,
    parameter int P_TX_FDI_FIFO_DEPTH   = 32,
    parameter int P_TX_FIFO_WIDTH       = 128,
    parameter int P_TX_DATA_W           = 64,
    parameter int P_CL_MAX_CREDITS      = 32
)(
    input  logic        i_clk,
    input  logic        i_rst_n,
    input  logic        i_init_n,

    rdi_if.sb_top       rdi,
    fdi_if.sb_top       fdi,
    regfile_if.sb_top   rf,

    // LSM Control (not in interfaces)
    input  logic                    i_sb_start_param_exch,
    output logic                    o_sb_param_exch_done,
    output logic                    o_sb_invalid_param_exch,
    output logic                    o_sb_param_exch_timeout,
    output logic                    o_sb_retry_negotiated,
    output logic                    o_sb_rdi_overflow,
    output logic                    o_sb_fdi_overflow,
    output logic                    o_sb_parity_error,
    output logic                    o_sb_opid_err,
    output logic                    o_sb_fdi_packer_error,
    output sb_state_msg_encoding    o_sb_state_msg_rx,
    output logic                    o_msg_timer_enable,
    input  sb_state_msg_encoding    i_sb_state_msg_tx,

    `ifndef END_POINT
    output sb_error_msg_encoding    o_sb_err_msg_rx,
    output logic                    o_sb_remote_timeout,
    `else
    output logic                    o_sb_local_timeout,
    `endif

    // Parameter Exchange
    input  logic [63:0]             i_adapter_advcap,
    input  logic [63:0]             i_cxl_advcap,
    input  logic                    i_format4_enabled,
    input  logic                    i_format6_enabled,
    input  logic                    i_retry_needed,
    input  logic                    i_retry_negotiated,
    input  logic [4:0]              i_flit_fmt_status,
    output logic [63:0]             o_adapter_advcap,
    output logic [63:0]             o_adapter_fincap,
    output logic [63:0]             o_cxl_advcap,
    output logic [63:0]             o_cxl_fincap,
    output logic                    o_adapter_advcap_valid,
    output logic                    o_adapter_fincap_valid,
    output logic                    o_cxl_advcap_valid,
    output logic                    o_cxl_fincap_valid,
    output logic [4:0]              o_flit_format_status,
    output logic                    o_flitfmt_valid

    `ifdef END_POINT
    ,input  sb_error_msg_encoding   i_sb_err_msg_tx
    `endif
);

    //----------------------------------------------------------
    // Internal wires for old-style port names
    //----------------------------------------------------------

    // RDI Sideband
    logic [P_NC-1:0]    w_rdi_pl_cfg;
    logic               w_rdi_pl_cfg_vld;
    logic               w_rdi_pl_cfg_crd;
    logic [P_NC-1:0]    w_rdi_lp_cfg;
    logic               w_rdi_lp_cfg_vld;
    logic               w_rdi_lp_cfg_crd;

    // FDI Sideband
    logic [P_NC-1:0]    w_fdi_lp_cfg;
    logic               w_fdi_lp_cfg_vld;
    logic               w_fdi_lp_cfg_crd;
    logic [P_NC-1:0]    w_fdi_pl_cfg;
    logic               w_fdi_pl_cfg_vld;
    logic               w_fdi_pl_cfg_crd;
    logic [3:0]         w_fdi_pl_protocol;
    logic [3:0]         w_fdi_pl_flit_fmt;
    logic               w_fdi_pl_valid;

    // RegFile
    logic [63:0]        w_reg_read_data;
    logic [2:0]         w_reg_status;
    logic [63:0]        w_reg_write_data;
    logic               w_reg_write_en;
    logic [23:0]        w_reg_address;
    logic [7:0]         w_reg_be;
    logic               w_reg_config_req;
    logic               w_reg_32_B;
    logic               w_reg_valid;

    `ifndef END_POINT
    logic [31:0]        w_mailbox_index_low;
    logic [4:0]         w_mailbox_index_high;
    logic [31:0]        w_mailbox_data_low;
    logic [31:0]        w_mailbox_data_high;
    logic               w_mailbox_trigger;
    logic [3:0]         w_remote_access_threshold;
    logic [31:0]        w_mailbox_data_low_out;
    logic [31:0]        w_mailbox_data_high_out;
    logic               w_mailbox_data_en;
    logic               w_mailbox_trigger_en;
    logic [1:0]         w_mailbox_status;
    logic [63:0]        w_header_log_1;
    logic               w_header_log_en;
    `endif

    //----------------------------------------------------------
    // Interface → internal wire assignments (inputs to DUT)
    //----------------------------------------------------------
    assign w_rdi_pl_cfg      = rdi.pl_cfg;
    assign w_rdi_pl_cfg_vld  = rdi.pl_cfg_vld;
    assign w_rdi_pl_cfg_crd  = rdi.pl_cfg_crd;

    assign w_fdi_lp_cfg      = fdi.lp_cfg;
    assign w_fdi_lp_cfg_vld  = fdi.lp_cfg_vld;
    assign w_fdi_lp_cfg_crd  = fdi.lp_cfg_crd;

    assign w_reg_read_data   = rf.read_data;
    assign w_reg_status      = rf.status;

    `ifndef END_POINT
    assign w_mailbox_index_low       = rf.sb_mailbox_index_low;
    assign w_mailbox_index_high      = rf.sb_mailbox_index_high;
    assign w_mailbox_data_low        = rf.sb_mailbox_data_low_out;
    assign w_mailbox_data_high       = rf.sb_mailbox_data_high_out;
    assign w_mailbox_trigger         = rf.sb_mailbox_trigger;
    assign w_remote_access_threshold = rf.sb_remote_threshold;
    `endif

    //----------------------------------------------------------
    // Internal wire → interface assignments (outputs from DUT)
    //----------------------------------------------------------
    assign rdi.lp_cfg       = w_rdi_lp_cfg;
    assign rdi.lp_cfg_vld   = w_rdi_lp_cfg_vld;
    assign rdi.lp_cfg_crd   = w_rdi_lp_cfg_crd;

    assign fdi.pl_cfg       = w_fdi_pl_cfg;
    assign fdi.pl_cfg_vld   = w_fdi_pl_cfg_vld;
    assign fdi.pl_cfg_crd   = w_fdi_pl_cfg_crd;
    assign fdi.pl_protocol  = w_fdi_pl_protocol;
    assign fdi.pl_flit_fmt  = w_fdi_pl_flit_fmt;
    assign fdi.pl_valid     = w_fdi_pl_valid;

    assign rf.write_data    = w_reg_write_data;
    assign rf.write_en      = w_reg_write_en;
    assign rf.address       = w_reg_address;
    assign rf.be            = w_reg_be;
    assign rf.config_req    = w_reg_config_req;
    assign rf.reg_32_B      = w_reg_32_B;
    assign rf.valid         = w_reg_valid;

    `ifndef END_POINT
    assign rf.sb_mailbox_data_low    = w_mailbox_data_low_out;
    assign rf.sb_mailbox_data_high   = w_mailbox_data_high_out;
    assign rf.sb_mailbox_data_vld    = w_mailbox_data_en;
    assign rf.sb_mailbox_trigger_en  = w_mailbox_trigger_en;
    assign rf.sb_header_log1         = w_header_log_1;
    assign rf.sb_header_log1_valid   = w_header_log_en;
    `endif

    //----------------------------------------------------------
    // DUT Instantiation
    //----------------------------------------------------------
    UC_sb_top #(
        .P_NC                   ( P_NC                  ),
        .P_RX_NUM_OF_COMP_PKTS  ( P_RX_NUM_OF_COMP_PKTS ),
        .P_RX_NUM_OF_MSG_PKTS   ( P_RX_NUM_OF_MSG_PKTS  ),
        .P_TX_FDI_FIFO_DEPTH    ( P_TX_FDI_FIFO_DEPTH   ),
        .P_TX_FIFO_WIDTH        ( P_TX_FIFO_WIDTH        ),
        .P_TX_DATA_W            ( P_TX_DATA_W            ),
        .P_CL_MAX_CREDITS       ( P_CL_MAX_CREDITS       )
    ) u_UC_sb_top (
        .i_clk                  ( i_clk                  ),
        .i_rst_n                ( i_rst_n                ),
        .i_init_n               ( i_init_n               ),

        // RDI
        .i_rdi_pl_cfg           ( w_rdi_pl_cfg           ),
        .i_rdi_pl_cfg_vld       ( w_rdi_pl_cfg_vld       ),
        .i_rdi_pl_cfg_crd       ( w_rdi_pl_cfg_crd       ),
        .o_rdi_lp_cfg           ( w_rdi_lp_cfg           ),
        .o_rdi_lp_cfg_vld       ( w_rdi_lp_cfg_vld       ),
        .o_rdi_lp_cfg_crd       ( w_rdi_lp_cfg_crd       ),

        // FDI
        .i_fdi_lp_cfg           ( w_fdi_lp_cfg           ),
        .i_fdi_lp_cfg_vld       ( w_fdi_lp_cfg_vld       ),
        .i_fdi_lp_cfg_crd       ( w_fdi_lp_cfg_crd       ),
        .o_fdi_pl_cfg           ( w_fdi_pl_cfg           ),
        .o_fdi_pl_cfg_vld       ( w_fdi_pl_cfg_vld       ),
        .o_fdi_pl_cfg_crd       ( w_fdi_pl_cfg_crd       ),
        .o_fdi_pl_protocol      ( w_fdi_pl_protocol      ),
        .o_fdi_pl_flit_fmt      ( w_fdi_pl_flit_fmt      ),
        .o_fdi_pl_valid         ( w_fdi_pl_valid         ),

        // LSM
        `ifndef END_POINT
        .o_sb_err_msg_rx        ( o_sb_err_msg_rx        ),
        .o_sb_remote_timeout    ( o_sb_remote_timeout    ),
        `else
        .o_sb_local_timeout     ( o_sb_local_timeout     ),
        `endif
        .o_sb_state_msg_rx      ( o_sb_state_msg_rx      ),
        .o_sb_rdi_overflow      ( o_sb_rdi_overflow      ),
        .o_sb_fdi_overflow      ( o_sb_fdi_overflow      ),
        .o_sb_parity_error      ( o_sb_parity_error      ),
        .o_sb_opid_err          ( o_sb_opid_err          ),
        .o_sb_fdi_packer_error  ( o_sb_fdi_packer_error  ),
        .i_sb_start_param_exch  ( i_sb_start_param_exch  ),
        .o_sb_param_exch_done   ( o_sb_param_exch_done   ),
        .o_sb_invalid_param_exch( o_sb_invalid_param_exch),
        .o_sb_param_exch_timeout( o_sb_param_exch_timeout),
        .o_sb_retry_negotiated  ( o_sb_retry_negotiated  ),
        .i_sb_state_msg_tx      ( i_sb_state_msg_tx      ),
        `ifdef END_POINT
        .i_sb_err_msg_tx        ( i_sb_err_msg_tx        ),
        `endif
        .o_msg_timer_enable     ( o_msg_timer_enable     ),

        // Register File
        .i_reg_read_data        ( w_reg_read_data        ),
        .i_reg_status           ( w_reg_status           ),
        .o_reg_write_data       ( w_reg_write_data       ),
        .o_reg_write_en         ( w_reg_write_en         ),
        .o_reg_address          ( w_reg_address          ),
        .o_reg_be               ( w_reg_be               ),
        .o_reg_config_req       ( w_reg_config_req       ),
        .o_reg_32_B             ( w_reg_32_B             ),
        .o_reg_valid            ( w_reg_valid            ),

        `ifndef END_POINT
        .i_mailbox_index_low    ( w_mailbox_index_low    ),
        .i_mailbox_index_high   ( w_mailbox_index_high   ),
        .i_mailbox_data_low     ( w_mailbox_data_low     ),
        .i_mailbox_data_high    ( w_mailbox_data_high    ),
        .i_mailbox_trigger      ( w_mailbox_trigger      ),
        .i_remote_access_threshold( w_remote_access_threshold ),
        .o_mailbox_data_low     ( w_mailbox_data_low_out ),
        .o_mailbox_data_high    ( w_mailbox_data_high_out),
        .o_mailbox_data_en      ( w_mailbox_data_en      ),
        .o_mailbox_trigger_en   ( w_mailbox_trigger_en   ),
        .o_mailbox_status       ( w_mailbox_status       ),
        .o_header_log_1         ( w_header_log_1         ),
        .o_header_log_en        ( w_header_log_en        ),
        `endif

        // Parameter Exchange
        .i_adapter_advcap       ( i_adapter_advcap       ),
        .i_cxl_advcap           ( i_cxl_advcap           ),
        .i_format4_enabled      ( i_format4_enabled      ),
        .i_format6_enabled      ( i_format6_enabled      ),
        .i_retry_needed         ( i_retry_needed         ),
        .i_retry_negotiated     ( i_retry_negotiated     ),
        .i_flit_fmt_status      ( i_flit_fmt_status      ),
        .o_adapter_advcap       ( o_adapter_advcap       ),
        .o_adapter_fincap       ( o_adapter_fincap       ),
        .o_cxl_advcap           ( o_cxl_advcap           ),
        .o_cxl_fincap           ( o_cxl_fincap           ),
        .o_adapter_advcap_valid ( o_adapter_advcap_valid ),
        .o_adapter_fincap_valid ( o_adapter_fincap_valid ),
        .o_cxl_advcap_valid     ( o_cxl_advcap_valid     ),
        .o_cxl_fincap_valid     ( o_cxl_fincap_valid     ),
        .o_flit_format_status   ( o_flit_format_status   ),
        .o_flitfmt_valid        ( o_flitfmt_valid        )
    );

endmodule : UC_sb_top_wrap