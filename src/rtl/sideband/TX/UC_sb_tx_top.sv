/*
===========================================================================
 File Name   : UC_sb_tx_top.sv
 Project     : UCIe 3.0 Adapter Layer - Sideband Unit
===========================================================================
 Module      : UC_sb_tx_top
 Description : Sideband Transmit Top-Level module

 Authors     : Shahd Mohamed, Ashraf Sherif
===========================================================================
*/

module UC_sb_tx_top #(
    parameter int  P_NC             = 32,
    parameter int  P_FDI_FIFO_DEPTH = 32,
    parameter int  P_FIFO_WIDTH     = 128,
    parameter int  P_DATA_W         = 64
)(
    /*------------------------------------------
      Global Signals
    ------------------------------------------*/
    input  logic                        i_clk,
    input  logic                        i_rst_n,
    input  logic                        i_init_n,

    /*---------------------------------------------
      FDI Interface
    ---------------------------------------------*/
    input  logic [P_NC-1:0]             i_fdi_lp_cfg,
    input  logic                        i_fdi_lp_cfg_vld,

    /*---------------------------------------------
      RDI Interface
    ---------------------------------------------*/
    output logic [P_NC-1:0]             o_rdi_lp_cfg,
    output logic                        o_rdi_lp_cfg_vld,

    /*---------------------------------------------
      LSM & Error Handling Interface
    ---------------------------------------------*/
    `ifdef END_POINT
    output logic                        o_tx_lsm_local_time_out,
    `else
    output logic                        o_tx_lsm_remote_time_out,
    `endif

    output logic                        o_tx_lsm_parity_error,
    output logic                        o_tx_fdi_overflow,
    output logic                        o_fdi_packer_error,

    /*---------------------------------------------
      Register File Interface
    ---------------------------------------------*/
    input  logic [63:0]                 i_reg_read_data,
    input  logic [2:0]                  i_reg_status,
    output logic [63:0]                 o_reg_write_data,
    output logic                        o_reg_write_en,
    output logic [23:0]                 o_reg_address,
    output logic [7:0]                  o_reg_be,
    output logic                        o_reg_config_req,
    output logic                        o_reg_32_B,
    output logic                        o_reg_valid,

    /*---------------------------------------------
      Mailbox Interface (RP only)
    ---------------------------------------------*/
    `ifndef END_POINT
    input  logic [31:0]                 i_mailbox_index_low,
    input  logic [4:0]                  i_mailbox_index_high,
    input  logic [31:0]                 i_mailbox_data_low,
    input  logic [31:0]                 i_mailbox_data_high,
    input  logic                        i_mailbox_trigger,
    input  logic [3:0]                  i_remote_access_threshold,
    input  logic                        i_e2e_crd_return,

    output logic [31:0]                 o_mailbox_data_low,
    output logic [31:0]                 o_mailbox_data_high,
    output logic                        o_mailbox_data_en,
    output logic                        o_mailbox_trigger_en,
    output logic [1:0]                  o_mailbox_status,
    output logic [63:0]                 o_header_log_1,
    output logic                        o_header_log_en,
    `endif

    /*---------------------------------------------
      Rx Controller Interface
    ---------------------------------------------*/
    input  logic                        i_rx_tx_chk_tag,
    input  logic [4:0]                  i_rx_tx_current_tag,
    output logic [4:0]                  o_rx_tx_orig_tag,
    output logic                        o_rx_tx_tag_notfound,

    `ifdef END_POINT
    input  logic [127:0]                i_rx_tx_remote_req_pkt,
    input  logic                        i_rx_tx_remote_req_vld,
    input  logic                        i_rx_tx_remote_comp_type,
    `endif

    input  logic [P_FIFO_WIDTH-1:0]     i_rx_tx_remote_comp_pkt,
    input  logic                        i_rx_tx_remote_comp_vld,

    output logic [P_FIFO_WIDTH-1:0]     o_tx_rx_comp_pkt,
    output logic                        o_tx_rx_comp_pkt_vld,
    input  logic                        i_tx_rx_comp_pkt_done,

    /*------------------------------------------
      Credit Interface
    ------------------------------------------*/
    input  logic                        i_tx_stall_signal,
    output logic                        o_tx_fdi_crd_release,
    output logic                        o_tx_dec_phy_buffer,

    /*------------------------------------------
      MSG / LSM Controller Interface
    ------------------------------------------*/
    input  logic [127:0]                i_tx_msg,
    input  logic                        i_tx_msg_vld,
    input  logic                        i_tx_msg_type,

    output logic                        o_tx_msgs_fifo_full,
    output logic                        o_tx_msg_handling_done
);

// ===========================================================================
//                          Internal Signals
// ===========================================================================

// --- FDI FIFO signals ---
logic                        s_fdi_fifo_full_flag;
logic                        s_fdi_fifo_empty_flag;
logic [P_FIFO_WIDTH-1:0]     s_fdi_fifo_write_data;
logic                        s_fdi_fifo_write_enable;
logic                        s_fdi_fifo_read_enable;
logic [P_FIFO_WIDTH-1:0]     s_fdi_fifo_read_data;

// --- FDI Packer / Decoder signals ---
logic [4:0]                  s_fdi_opcode;
logic                        s_fdi_request_type;
logic                        s_fdi_opcode_error;

// --- Decoded side signals for FDI Controller ---
logic [4:0]                  s_packer_comp_opcode;
logic                        s_packer_read_req;
logic                        s_packer_is_config;
logic                        s_packer_is_32bit;

logic                        s_decoder_write_operation;
logic                        s_decoder_operation_32bit;
logic                        s_decoder_request_type_unused;
logic                        s_decoder_config_req;
logic [4:0]                  s_decoder_comp_opcode;
logic                        s_decoder_opcode_error_unused;

// --- FDI Controller outputs ---
logic [P_FIFO_WIDTH:0]       s_fdi_ctrl_rdi_packet;
logic                        s_fdi_ctrl_rdi_write_en;
logic [P_DATA_W-1:0]         s_fdi_ctrl_local_write_data;
logic                        s_fdi_ctrl_local_write_enable;
logic                        s_fdi_ctrl_local_config_request;
logic                        s_fdi_ctrl_local_32bit_access;
logic [7:0]                  s_fdi_ctrl_local_byte_enable;
logic [23:0]                 s_fdi_ctrl_local_address;
logic                        s_fdi_ctrl_local_valid;
logic [127:0]                s_fdi_ctrl_rx_comp_packet;
logic                        s_fdi_ctrl_rx_comp_valid;
logic [4:0]                  s_fdi_ctrl_request_opcode;
logic                        s_fdi_ctrl_tag_valid;
logic [4:0]                  s_fdi_ctrl_phy_tag;
logic                        s_fdi_ctrl_parity_error;
logic                        s_fdi_ctrl_credit_release;

// --- Tag Manager ---
logic                        s_tag_mgr_correct_flag;
logic [4:0]                  s_tag_mgr_new_tag;
logic                        s_tag_mgr_not_found_flag;

// --- RDI FIFO ---
logic                        s_rdi_fifo_full_flag;
logic                        s_rdi_fifo_empty_flag;
logic [P_FIFO_WIDTH:0]       s_rdi_fifo_read_data;
logic                        s_rdi_fifo_read_enable;
//logic                        s_rdi_fifo_write_enable;

// --- RX FIFO ---
logic                        s_rx_fifo_full_flag;
logic                        s_rx_fifo_empty_flag;

// --- Access Arbiter ---
logic                        s_arbiter_local_done;
logic [2:0]                  s_arbiter_local_status;
logic [63:0]                 s_arbiter_local_read_data;

logic                        s_arbiter_remote_done;
logic [2:0]                  s_arbiter_remote_status;
logic [63:0]                 s_arbiter_remote_read_data;

// --- Remote Controller ---
logic [127:0]                s_remote_ctrl_packet;
logic                        s_remote_ctrl_packet_valid;
logic                        s_remote_ctrl_packet_length;
logic                        s_remote_ctrl_is_completion;
logic                        s_remote_ctrl_sent_ack;

logic [63:0]                 s_remote_ctrl_reg_write_data;
logic                        s_remote_ctrl_reg_write_enable;
logic [23:0]                 s_remote_ctrl_reg_address;
logic [7:0]                  s_remote_ctrl_reg_byte_enable;
logic                        s_remote_ctrl_reg_config_req;
logic                        s_remote_ctrl_reg_32bit_access;
logic                        s_remote_ctrl_arbiter_valid;

// --- Remote Decoder (EP only) ---
`ifdef END_POINT
logic [4:0]                  s_remote_dec_opcode;
logic [23:0]                 s_remote_dec_address;
logic                        s_remote_dec_is_adapter;
logic [4:0]                  s_remote_dec_comp_opcode;
logic                        s_remote_dec_write_operation;
logic                        s_remote_dec_op_32bit;
logic                        s_remote_dec_config_request;
logic                        s_remote_dec_comp_type;
logic                        s_remote_dec_packet_length;
`endif

// --- MSG FIFO ---
logic                        s_msg_fifo_empty_flag;
logic                        s_msg_fifo_read_enable;
logic [P_FIFO_WIDTH:0]       s_msg_fifo_read_data;


// ===========================================================================
//                    1. UC_sb_FDI_Packer
//                    FDI chunk collector / FIFO controller
// ===========================================================================

UC_sb_FDI_Packer #(
    .P_NC          (P_NC),
    .P_FIFO_WEDITH (P_FIFO_WIDTH)
) U_FDI_PACKER (
    .i_clk                  (i_clk),
    .i_rst_n                (i_rst_n),
    .i_init_n               (i_init_n),

    // From FDI
    .i_lp_cfg               (i_fdi_lp_cfg),
    .i_lp_cfg_vld           (i_fdi_lp_cfg_vld),

    // From FDI FIFO
    .i_fdi_fifo_full        (s_fdi_fifo_full_flag),

    // From opcode decoder
    .i_request_type         (s_fdi_request_type),
    .i_opcode_error         (s_fdi_opcode_error),

    // To opcode decoder
    .o_opcode               (s_fdi_opcode),

    // To LSM / error handling
    .o_fdi_overflow         (o_tx_fdi_overflow),
    .o_fdi_fifo_cntrl_error (o_fdi_packer_error),

    // To FDI FIFO
    .o_fdi_fifo_data_in     (s_fdi_fifo_write_data),
    .o_fdi_fifo_wr_en       (s_fdi_fifo_write_enable)
);


// ===========================================================================
//                    1.1 UC_fdi_decoder for FDI Packer
//                   
// ===========================================================================

logic        s_fdi_decoder_write_unused;
logic        s_fdi_decoder_32bit_unused;
logic        s_fdi_decoder_config_unused;
logic [4:0]  s_fdi_decoder_comp_unused;
logic        s_mailbox_dec_is_adapter_unused;
logic [4:0]  s_mailbox_dec_comp_opcode_unused;
logic        s_mailbox_dec_write_unused;
logic        s_mailbox_dec_config_unused;
UC_fdi_decoder U_FDI_DECODER_PACKER (
    .i_opcode           (s_fdi_opcode),
    .o_write_operation  (s_fdi_decoder_write_unused),
    .o_operation_32bit  (s_fdi_decoder_32bit_unused),
    .o_request_type     (s_fdi_request_type),
    .o_confg_req        (s_fdi_decoder_config_unused),
    .o_comp_opcode      (s_fdi_decoder_comp_unused),
    .o_opcode_error     (s_fdi_opcode_error)
);

// ===========================================================================
//                    2. FDI FIFO
// ===========================================================================

UC_sync_fifo #(
    .FIFO_DEPTH(P_FDI_FIFO_DEPTH),
    .DATA_WIDTH(P_FIFO_WIDTH)
) U_FDI_FIFO (
    .clk              (i_clk),
    .rst_n            (i_rst_n),
    .init_n           (i_init_n),
    .fifo_read_enable (s_fdi_fifo_read_enable),
    .fifo_data_in     (s_fdi_fifo_write_data),
    .fifo_write_enable(s_fdi_fifo_write_enable),
    .fifo_data_out    (s_fdi_fifo_read_data),
    .fifo_full        (s_fdi_fifo_full_flag),
    .fifo_empty       (s_fdi_fifo_empty_flag)
);


// ===========================================================================
//                    3. UC_sb_FDI_Controller
// ===========================================================================

UC_sb_FDI_Controller #(
    .FIFO_WEDITH(P_FIFO_WIDTH)
) U_FDI_CONTROLLER (
    .i_clk                  (i_clk),
    .i_rst_n                (i_rst_n),
    .i_init_n               (i_init_n),

    // FDI FIFO
    .i_fdi_fifo_out         (s_fdi_fifo_read_data),
    .i_fdi_fifo_empty       (s_fdi_fifo_empty_flag),
    .o_fdi_fifo_r_en        (s_fdi_fifo_read_enable),

    // RDI FIFO back-pressure
    .i_rdi_fifo_full        (s_rdi_fifo_full_flag),

    // Decoded sidecar signals from decoder
    .i_comp_opcode          (s_packer_comp_opcode),
    .i_read_req             (s_packer_read_req),
    .i_config_req           (s_packer_is_config),
    .i_is_32b               (s_packer_is_32bit),

    // RX FIFO back-pressure
    .i_rx_fifo_full         (s_rx_fifo_full_flag),

    // Access Arbiter
    .i_Local_status         (s_arbiter_local_status),
    .i_Local_read_data      (s_arbiter_local_read_data),
    .i_Local_arbiter_done   (s_arbiter_local_done),

    .o_Local_wr_data        (s_fdi_ctrl_local_write_data),
    .o_Local_wr_en          (s_fdi_ctrl_local_write_enable),
    .o_Local_config_req     (s_fdi_ctrl_local_config_request),
    .o_Local_32_B           (s_fdi_ctrl_local_32bit_access),
    .o_Local_BE             (s_fdi_ctrl_local_byte_enable),
    .o_Local_address        (s_fdi_ctrl_local_address),
    .o_Local_valid          (s_fdi_ctrl_local_valid),

    // Tag Manager response
    .i_tag_correct          (s_tag_mgr_correct_flag),
    .i_tag_new              (s_tag_mgr_new_tag),
    //.i_tag_uncorrect        (s_tag_mgr_not_found_flag),

    // Tag Manager request
    .o_tag_valid            (s_fdi_ctrl_tag_valid),
    .o_phy_tag              (s_fdi_ctrl_phy_tag),

    // RDI FIFO write
    .o_to_rdi_req           (s_fdi_ctrl_rdi_packet),
    .o_to_rdi_req_vlaid     (s_fdi_ctrl_rdi_write_en),

    // Completion to RX FIFO
    .o_rx_Comp_packet       (s_fdi_ctrl_rx_comp_packet),
    .o_rx_Comp_packet_valid (s_fdi_ctrl_rx_comp_valid),

    // Opcode of current captured request
    .o_req_opcode           (s_fdi_ctrl_request_opcode),

    // Credit release
    .o_Fdi_credit_release   (s_fdi_ctrl_credit_release),

    // LSM
    .o_lsm_parity_error     (s_fdi_ctrl_parity_error)
);

assign o_tx_fdi_crd_release  = s_fdi_ctrl_credit_release;
assign o_tx_lsm_parity_error = s_fdi_ctrl_parity_error;


// ===========================================================================
//                    3.1 UC_fdi_decoder for FDI Controller
//                    Decode the current opcode from FDI Controller
// ===========================================================================

UC_fdi_decoder U_FDI_DECODER_CONTROLLER (
    .i_opcode             (s_fdi_ctrl_request_opcode),
    .o_write_operation    (s_decoder_write_operation),
    .o_operation_32bit    (s_decoder_operation_32bit),
    .o_request_type       (s_decoder_request_type_unused),
    .o_confg_req          (s_decoder_config_req),
    .o_comp_opcode        (s_decoder_comp_opcode),
    .o_opcode_error       (s_decoder_opcode_error_unused)
);

assign s_packer_comp_opcode = s_decoder_comp_opcode;
assign s_packer_read_req    = ~s_decoder_write_operation;
assign s_packer_is_config   = s_decoder_config_req;
assign s_packer_is_32bit    = s_decoder_operation_32bit;


// ===========================================================================
//                    4. UC_sb_tag_manager
// ===========================================================================

UC_sb_tag_manager U_TAG_MANAGER (
    .i_clk          (i_clk),
    .i_rst_n        (i_rst_n),
    .i_init_n       (i_init_n),

    // TX path: validate and store tag from FDI Controller
    .i_valid        (s_fdi_ctrl_tag_valid),
    .i_tag_store    (s_fdi_ctrl_phy_tag),
    .o_correct      (s_tag_mgr_correct_flag),
    .o_new_tag      (s_tag_mgr_new_tag),

    // RX path: check completion tag from Rx
    .i_check        (i_rx_tx_chk_tag),
    .i_current_tag  (i_rx_tx_current_tag),
    .o_uncorrect_tag(s_tag_mgr_not_found_flag),
    .o_old_tag      (o_rx_tx_orig_tag)
);

assign o_rx_tx_tag_notfound = s_tag_mgr_not_found_flag;


// ===========================================================================
//                    5. RDI FIFO
// ===========================================================================

UC_sync_fifo #(
    .FIFO_DEPTH(32),
    .DATA_WIDTH(P_FIFO_WIDTH+1)
) U_RDI_FIFO (
    .clk              (i_clk),
    .rst_n            (i_rst_n),
    .init_n           (i_init_n),
    .fifo_read_enable (s_rdi_fifo_read_enable),
    .fifo_data_in     (s_fdi_ctrl_rdi_packet),
    .fifo_write_enable(s_fdi_ctrl_rdi_write_en),
    .fifo_data_out    (s_rdi_fifo_read_data),
    .fifo_full        (s_rdi_fifo_full_flag),
    .fifo_empty       (s_rdi_fifo_empty_flag)
);


// ===========================================================================
//                    6. RX FIFO  [Completions to Rx]
// ===========================================================================

UC_sync_fifo #(
    .FIFO_DEPTH(32),
    .DATA_WIDTH(P_FIFO_WIDTH)
) U_RX_FIFO (
    .clk              (i_clk),
    .rst_n            (i_rst_n),
    .init_n           (i_init_n),
    .fifo_read_enable (i_tx_rx_comp_pkt_done),
    .fifo_data_in     (s_fdi_ctrl_rx_comp_packet),
    .fifo_write_enable(s_fdi_ctrl_rx_comp_valid),
    .fifo_data_out    (o_tx_rx_comp_pkt),
    .fifo_full        (s_rx_fifo_full_flag),
    .fifo_empty       (s_rx_fifo_empty_flag)
);

assign o_tx_rx_comp_pkt_vld = ~s_rx_fifo_empty_flag;


// ===========================================================================
//                    7. MSG FIFO
// ===========================================================================

UC_sync_fifo #(
    .FIFO_DEPTH(4),
    .DATA_WIDTH(P_FIFO_WIDTH + 1)
) U_MSG_FIFO (
    .clk              (i_clk),
    .rst_n            (i_rst_n),
    .init_n           (i_init_n),
    .fifo_read_enable (s_msg_fifo_read_enable),
    .fifo_data_in     ({i_tx_msg_type, i_tx_msg}),
    .fifo_write_enable(i_tx_msg_vld),
    .fifo_data_out    (s_msg_fifo_read_data),
    .fifo_full        (o_tx_msgs_fifo_full),
    .fifo_empty       (s_msg_fifo_empty_flag)
);


// ===========================================================================
//                    8. tx_rdi_controller
// ===========================================================================

`ifdef END_POINT
logic s_remote_is_comp_endpoint;
assign s_remote_is_comp_endpoint = s_remote_ctrl_is_completion;
`endif

tx_rdi_controller #(
    .NC(P_NC)
) U_RDI_TX_CNTRL (
    .i_clk              (i_clk),
    .i_rstn             (i_rst_n),
    .i_init_n           (i_init_n),

    .i_fdi_pkt          (s_rdi_fifo_read_data[127:0]),
    .i_fdi_length       (~s_rdi_fifo_read_data[128]),
    .i_fdi_valid        (~s_rdi_fifo_empty_flag),
    .o_fdi_sent         (s_rdi_fifo_read_enable),

    .i_msg_pkt          (s_msg_fifo_read_data[P_FIFO_WIDTH-1:0]),
    .i_msg_length       (s_msg_fifo_read_data[P_FIFO_WIDTH]),
    .i_msg_valid        (~s_msg_fifo_empty_flag),
    .o_msg_sent         (s_msg_fifo_read_enable),
    .o_msg_is_req       (o_tx_msg_handling_done),

    .i_remote_pkt       (s_remote_ctrl_packet),
    .i_remote_length    (s_remote_ctrl_packet_length),
    .i_remote_valid     (s_remote_ctrl_packet_valid),
    .o_remote_sent      (s_remote_ctrl_sent_ack),

    `ifdef END_POINT
    .i_remote_comp      (s_remote_is_comp_endpoint),
    `endif

    .o_lp_cfg           (o_rdi_lp_cfg),
    .o_lp_cfg_vld       (o_rdi_lp_cfg_vld),

    .i_stall_tx         (i_tx_stall_signal),
    .o_decrease_counter (o_tx_dec_phy_buffer)
);


// ===========================================================================
//                    9. Remote Controller
// ===========================================================================

`ifndef END_POINT

// -------------------------------------------------------------------------
// ROOT PORT: uc_mailbox_controller
// -------------------------------------------------------------------------

logic [4:0]  s_mailbox_opcode;
logic        s_mailbox_request_length;
logic        s_mailbox_32bit_access;

uc_mailbox_controller U_MAILBOX_CTRL (
    .i_clk                (i_clk),
    .i_rstn               (i_rst_n),
    .i_init_n             (i_init_n),

    .i_remote_threshold   (i_remote_access_threshold),
    .o_Header_log1        (o_header_log_1),
    .o_Header_log1_valid  (o_header_log_en),

    .i_mailbox_trigger    (i_mailbox_trigger),
    .i_mailbox_index_low  (i_mailbox_index_low),
    .i_mailbox_index_high (i_mailbox_index_high),
    .i_mailbox_data_low   (i_mailbox_data_low),
    .i_mailbox_data_high  (i_mailbox_data_high),

    .o_mailbox_data_low   (o_mailbox_data_low),
    .o_mailbox_data_high  (o_mailbox_data_high),
    .o_mailbox_status     (o_mailbox_status),
    .o_mailbox_data_vld   (o_mailbox_data_en),
    .o_mailbox_trigger_en (o_mailbox_trigger_en),

    .i_comp_packet        (i_rx_tx_remote_comp_pkt),
    .i_comp_packet_vld    (i_rx_tx_remote_comp_vld),

    .i_req_sent           (s_remote_ctrl_sent_ack),
    .o_req_pkt            (s_remote_ctrl_packet),
    .o_req_pkt_vld        (s_remote_ctrl_packet_valid),
    .o_pkt_length         (s_remote_ctrl_packet_length),

    .o_opcode             (s_mailbox_opcode),
    .i_req_length         (s_mailbox_request_length),
    .i_32_b               (s_mailbox_32bit_access),

    .i_e2e_crd_return     (i_e2e_crd_return),
    .o_remote_time_out    (o_tx_lsm_remote_time_out)
);

UC_remote_decoder U_MAILBOX_DECODER (
    .i_decoder_addr     (24'd0),
    .i_decoder_opcode   (s_mailbox_opcode),

    .o_is_adapter       (s_mailbox_dec_is_adapter_unused),
    .o_comp_opcode      (s_mailbox_dec_comp_opcode_unused),
    .o_write_operation  (s_mailbox_dec_write_unused),
    .o_operation_32bit  (s_mailbox_32bit_access),
    .o_confg_req        (s_mailbox_dec_config_unused),
    .o_comp_type        (s_mailbox_request_length)
);

assign s_remote_ctrl_arbiter_valid    = 1'b0;
assign s_remote_ctrl_reg_write_data   = 64'b0;
assign s_remote_ctrl_reg_write_enable = 1'b0;
assign s_remote_ctrl_reg_address      = 24'b0;
assign s_remote_ctrl_reg_byte_enable  = 8'b0;
assign s_remote_ctrl_reg_config_req   = 1'b0;
assign s_remote_ctrl_reg_32bit_access = 1'b0;
assign s_remote_ctrl_is_completion    = 1'b0;

`else

// -------------------------------------------------------------------------
// END POINT: UC_sb_remote_die_request_controller + UC_remote_decoder
// -------------------------------------------------------------------------

UC_sb_remote_die_request_controller U_REMOTE_DIE_CTRL (
    .i_clk              (i_clk),
    .i_rst_n            (i_rst_n),
    .i_init_n           (i_init_n),

    .i_remote_req       (i_rx_tx_remote_req_pkt),
    .i_remote_req_vld   (i_rx_tx_remote_req_vld),

    .i_phy_comp         (i_rx_tx_remote_comp_pkt),
    .i_phy_comp_vld     (i_rx_tx_remote_comp_vld),
    .i_comp_length      (i_rx_tx_remote_comp_type),

    .i_is_phy_access    (~s_remote_dec_is_adapter),
    .i_comp_opcode      (s_remote_dec_comp_opcode),
    .i_read_req         (~s_remote_dec_write_operation),
    .i_config           (s_remote_dec_config_request),
    .i_pkt_length       (s_remote_dec_comp_type),
    .i_32_b             (s_remote_dec_op_32bit),

    .i_read_data        (s_arbiter_remote_read_data),
    .i_status           (s_arbiter_remote_status),
    .i_remote_done      (s_arbiter_remote_done),

    .i_req_sent         (s_remote_ctrl_sent_ack),

    .o_opcode           (s_remote_dec_opcode),
    .o_address          (s_remote_dec_address),

    .o_remote_write_data(s_remote_ctrl_reg_write_data),
    .o_remote_wr_en     (s_remote_ctrl_reg_write_enable),
    .o_remote_address   (s_remote_ctrl_reg_address),
    .o_remote_BE        (s_remote_ctrl_reg_byte_enable),
    .o_remote_config_req(s_remote_ctrl_reg_config_req),
    .o_remote_32_B      (s_remote_ctrl_reg_32bit_access),
    .o_remote_vld       (s_remote_ctrl_arbiter_valid),

    .o_pkt              (s_remote_ctrl_packet),
    .o_pkt_vld          (s_remote_ctrl_packet_valid),
    .o_pkt_length       (s_remote_ctrl_packet_length),
    .o_is_comp          (s_remote_ctrl_is_completion),

    .o_local_timeout    (o_tx_lsm_local_time_out)
);

UC_remote_decoder U_REMOTE_DECODER (
    .i_decoder_addr     (s_remote_dec_address),
    .i_decoder_opcode   (s_remote_dec_opcode),
    .o_is_adapter       (s_remote_dec_is_adapter),
    .o_comp_opcode      (s_remote_dec_comp_opcode),
    .o_write_operation  (s_remote_dec_write_operation),
    .o_operation_32bit  (s_remote_dec_op_32bit),
    .o_confg_req        (s_remote_dec_config_request),
    .o_comp_type        (s_remote_dec_comp_type)
);

`endif


// ===========================================================================
//                    10. uc_access_arbiter
// ===========================================================================

uc_access_arbiter U_ARBITER (
    .i_clk              (i_clk),
    .i_rstn             (i_rst_n),
    .i_init_n           (i_init_n),

    .i_Local_valid      (s_fdi_ctrl_local_valid),
    .i_Local_wr_data    (s_fdi_ctrl_local_write_data),
    .i_Local_wr_en      (s_fdi_ctrl_local_write_enable),
    .i_Local_cofig_req  (s_fdi_ctrl_local_config_request),
    .i_Local_address    (s_fdi_ctrl_local_address),
    .i_Local_BE         (s_fdi_ctrl_local_byte_enable),
    .i_Local_32_B       (s_fdi_ctrl_local_32bit_access),
    .o_Local_done       (s_arbiter_local_done),
    .o_Local_status     (s_arbiter_local_status),
    .o_Local_R_data     (s_arbiter_local_read_data),

    `ifdef END_POINT
    .i_remote_valid     (s_remote_ctrl_arbiter_valid),
    .i_remote_wr_data   (s_remote_ctrl_reg_write_data),
    .i_remote_wr_en     (s_remote_ctrl_reg_write_enable),
    .i_remote_address   (s_remote_ctrl_reg_address),
    .i_remote_BE        (s_remote_ctrl_reg_byte_enable),
    .i_remote_cofig_req (s_remote_ctrl_reg_config_req),
    .i_remote_32_B      (s_remote_ctrl_reg_32bit_access),
    .o_remote_done      (s_arbiter_remote_done),
    .o_remote_status    (s_arbiter_remote_status),
    .o_remote_R_data    (s_arbiter_remote_read_data),
    `else
    .i_remote_valid     (1'b0),
    .i_remote_wr_data   (64'b0),
    .i_remote_wr_en     (1'b0),
    .i_remote_address   (24'b0),
    .i_remote_BE        (8'b0),
    .i_remote_cofig_req (1'b0),
    .i_remote_32_B      (1'b0),
    .o_remote_done      (s_arbiter_remote_done),
    .o_remote_status    (s_arbiter_remote_status),
    .o_remote_R_data    (s_arbiter_remote_read_data),
    `endif
    .i_R_data           (i_reg_read_data),
    .i_Status           (i_reg_status),
    .o_wr_data          (o_reg_write_data),
    .o_wr_en            (o_reg_write_en),
    .o_address          (o_reg_address),
    .o_BE               (o_reg_be),
    .o_cofig_req        (o_reg_config_req),
    .o_32_B             (o_reg_32_B),
    .o_register_valid   (o_reg_valid)
);

endmodule
