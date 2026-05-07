/*
===========================================================================
 File Name   : UC_sb_top_RP_EP_2die_tb.sv
 Project     : UCIe 3.0 Adapter Layer - Sideband Unit
===========================================================================
 Module      : UC_sb_top_RP_EP_2die_tb
 Description : New dual-die system-level testbench after splitting RP/EP:
               - Instantiates UC_sb_top_RP
               - Instantiates UC_sb_top_EP
               - Cross-connects RDI only
               - Keeps FDI unconnected/default from TB side
===========================================================================
*/
`timescale 1ns/100ps
import UC_sb_rx_pkg::*;
import UC_sb_rx_pkg_RP::*;
module UC_sb_top_RP_EP_2die_tb;

  /*---------------------------------------------
    Parameters
  ---------------------------------------------*/
  parameter CLK_PERIOD = 10;
  parameter DUTY_CYCLE = 0.5;
  parameter HIGH_TIME  = CLK_PERIOD * DUTY_CYCLE;
  parameter LOW_TIME   = CLK_PERIOD * (1 - DUTY_CYCLE);

  parameter P_NC = 32;
  parameter P_RX_NUM_OF_COMP_PKTS = 4;
  parameter P_RX_NUM_OF_MSG_PKTS  = 2;
  parameter P_TX_FDI_FIFO_DEPTH = 32;
  parameter P_TX_FIFO_WIDTH = 128;
  parameter P_TX_DATA_W = 64;
  parameter P_CL_MAX_CREDITS = 32;

  /*---------------------------------------------
    Shared Global Signals
  ---------------------------------------------*/
  logic RB_i_clk;
  logic RB_i_rst_n;
  logic RB_i_init_n;

  logic EB_i_clk;
  logic EB_i_rst_n;
  logic EB_i_init_n;

  /*---------------------------------------------
    Root Port Signals
  ---------------------------------------------*/
  logic [P_NC-1:0] RB_i_rdi_pl_cfg;
  logic            RB_i_rdi_pl_cfg_vld;
  logic            RB_i_rdi_pl_cfg_crd;
  logic [P_NC-1:0] RB_o_rdi_lp_cfg;
  logic            RB_o_rdi_lp_cfg_vld;
  logic            RB_o_rdi_lp_cfg_crd;

  logic [P_NC-1:0] RB_i_fdi_lp_cfg;
  logic            RB_i_fdi_lp_cfg_vld;
  logic            RB_i_fdi_lp_cfg_crd;
  logic [P_NC-1:0] RB_o_fdi_pl_cfg;
  logic            RB_o_fdi_pl_cfg_vld;
  logic            RB_o_fdi_pl_cfg_crd;
  logic [3:0]      RB_o_fdi_pl_protocol;
  logic [3:0]      RB_o_fdi_pl_flit_fmt;
  logic            RB_o_fdi_pl_valid;

  sb_error_msg_encoding RB_o_sb_err_msg_rx;
  logic                 RB_o_sb_remote_timeout;
  sb_state_msg_encoding RB_o_sb_state_msg_rx;
  logic                 RB_o_sb_rdi_overflow;
  logic                 RB_o_sb_fdi_overflow;
  logic                 RB_o_sb_parity_error;
  logic                 RB_o_sb_opid_err;
  logic                 RB_o_sb_fdi_packer_error;

  logic                 RB_i_sb_start_param_exch;
  logic                 RB_o_sb_param_exch_done;
  logic                 RB_o_sb_invalid_param_exch;
  logic                 RB_o_sb_param_exch_timeout;
  logic                 RB_o_sb_retry_negotiated;
  sb_state_msg_encoding RB_i_sb_state_msg_tx;
  logic                 RB_o_msg_timer_enable;

  logic [63:0] RB_i_reg_read_data;
  logic [2:0]  RB_i_reg_status;
  logic [63:0] RB_o_reg_write_data;
  logic        RB_o_reg_write_en;
  logic [23:0] RB_o_reg_address;
  logic [7:0]  RB_o_reg_be;
  logic        RB_o_reg_config_req;
  logic        RB_o_reg_32_B;
  logic        RB_o_reg_valid;

  logic [31:0] RB_i_mailbox_index_low;
  logic [4:0]  RB_i_mailbox_index_high;
  logic [31:0] RB_i_mailbox_data_low;
  logic [31:0] RB_i_mailbox_data_high;
  logic        RB_i_mailbox_trigger;
  logic [3:0]  RB_i_remote_access_threshold;
  logic [31:0] RB_o_mailbox_data_low;
  logic [31:0] RB_o_mailbox_data_high;
  logic        RB_o_mailbox_data_en;
  logic        RB_o_mailbox_trigger_en;
  logic [1:0]  RB_o_mailbox_status;
  logic [63:0] RB_o_header_log_1;
  logic        RB_o_header_log_en;

  logic [63:0] RB_i_adapter_advcap;
  logic [63:0] RB_i_cxl_advcap;
  logic        RB_i_format4_enabled;
  logic        RB_i_format6_enabled;
  logic        RB_i_retry_needed;
  logic        RB_i_retry_negotiated;
  logic [4:0]  RB_i_flit_fmt_status;
  logic [63:0] RB_o_adapter_advcap;
  logic [63:0] RB_o_adapter_fincap;
  logic [63:0] RB_o_cxl_advcap;
  logic [63:0] RB_o_cxl_fincap;
  logic        RB_o_adapter_advcap_valid;
  logic        RB_o_adapter_fincap_valid;
  logic        RB_o_cxl_advcap_valid;
  logic        RB_o_cxl_fincap_valid;
  logic [4:0]  RB_o_flit_format_status;
  logic        RB_o_flitfmt_valid;
  logic        RB_i_flit_fmt_status_set;

  /*---------------------------------------------
    Endpoint Signals
  ---------------------------------------------*/
  logic [P_NC-1:0] EB_i_rdi_pl_cfg;
  logic            EB_i_rdi_pl_cfg_vld;
  logic            EB_i_rdi_pl_cfg_crd;
  logic [P_NC-1:0] EB_o_rdi_lp_cfg;
  logic            EB_o_rdi_lp_cfg_vld;
  logic            EB_o_rdi_lp_cfg_crd;

  logic [P_NC-1:0] EB_i_fdi_lp_cfg;
  logic            EB_i_fdi_lp_cfg_vld;
  logic            EB_i_fdi_lp_cfg_crd;
  logic [P_NC-1:0] EB_o_fdi_pl_cfg;
  logic            EB_o_fdi_pl_cfg_vld;
  logic            EB_o_fdi_pl_cfg_crd;
  logic [3:0]      EB_o_fdi_pl_protocol;
  logic [3:0]      EB_o_fdi_pl_flit_fmt;
  logic            EB_o_fdi_pl_valid;

  logic                 EB_o_sb_local_timeout;
  sb_state_msg_encoding EB_o_sb_state_msg_rx;
  logic                 EB_o_sb_rdi_overflow;
  logic                 EB_o_sb_fdi_overflow;
  logic                 EB_o_sb_parity_error;
  logic                 EB_o_sb_opid_err;
  logic                 EB_o_sb_fdi_packer_error;

  logic                 EB_i_sb_start_param_exch;
  logic                 EB_o_sb_param_exch_done;
  logic                 EB_o_sb_invalid_param_exch;
  logic                 EB_o_sb_param_exch_timeout;
  logic                 EB_o_sb_retry_negotiated;
  sb_state_msg_encoding EB_i_sb_state_msg_tx;
  sb_error_msg_encoding EB_i_sb_err_msg_tx;
  logic                 EB_o_msg_timer_enable;

  logic [63:0] EB_i_reg_read_data;
  logic [2:0]  EB_i_reg_status;
  logic [63:0] EB_o_reg_write_data;
  logic        EB_o_reg_write_en;
  logic [23:0] EB_o_reg_address;
  logic [7:0]  EB_o_reg_be;
  logic        EB_o_reg_config_req;
  logic        EB_o_reg_32_B;
  logic        EB_o_reg_valid;

  logic [63:0] EB_i_adapter_advcap;
  logic [63:0] EB_i_cxl_advcap;
  logic        EB_i_format4_enabled;
  logic        EB_i_format6_enabled;
  logic        EB_i_retry_needed;
  logic        EB_i_retry_negotiated;
  logic [4:0]  EB_i_flit_fmt_status;
  logic [63:0] EB_o_adapter_advcap;
  logic [63:0] EB_o_adapter_fincap;
  logic [63:0] EB_o_cxl_advcap;
  logic [63:0] EB_o_cxl_fincap;
  logic        EB_o_adapter_advcap_valid;
  logic        EB_o_adapter_fincap_valid;
  logic        EB_o_cxl_advcap_valid;
  logic        EB_o_cxl_fincap_valid;
  logic [4:0]  EB_o_flit_format_status;
  logic        EB_o_flitfmt_valid;
  logic        EB_i_flit_fmt_status_set;

  /*---------------------------------------------
    RDI Cross Connection Only
  ---------------------------------------------*/
  assign EB_i_rdi_pl_cfg     = RB_o_rdi_lp_cfg;
  assign EB_i_rdi_pl_cfg_vld = RB_o_rdi_lp_cfg_vld;

  assign RB_i_rdi_pl_cfg     = EB_o_rdi_lp_cfg;
  assign RB_i_rdi_pl_cfg_vld = EB_o_rdi_lp_cfg_vld;

  /*---------------------------------------------
    DUT: Root Port
  ---------------------------------------------*/
  UC_sb_top_RP #(
    .P_NC                  (P_NC),
    .P_RX_NUM_OF_COMP_PKTS (P_RX_NUM_OF_COMP_PKTS),
    .P_RX_NUM_OF_MSG_PKTS  (P_RX_NUM_OF_MSG_PKTS),
    .P_TX_FDI_FIFO_DEPTH   (P_TX_FDI_FIFO_DEPTH),
    .P_TX_FIFO_WIDTH       (P_TX_FIFO_WIDTH),
    .P_TX_DATA_W           (P_TX_DATA_W),
    .P_CL_MAX_CREDITS      (P_CL_MAX_CREDITS)
  ) U_RB_DUT (
    .i_clk                     (RB_i_clk),
    .i_rst_n                   (RB_i_rst_n),
    .i_init_n                  (RB_i_init_n),

    .i_rdi_pl_cfg              (RB_i_rdi_pl_cfg),
    .i_rdi_pl_cfg_vld          (RB_i_rdi_pl_cfg_vld),
    .i_rdi_pl_cfg_crd          (RB_i_rdi_pl_cfg_crd),
    .o_rdi_lp_cfg              (RB_o_rdi_lp_cfg),
    .o_rdi_lp_cfg_vld          (RB_o_rdi_lp_cfg_vld),
    .o_rdi_lp_cfg_crd          (RB_o_rdi_lp_cfg_crd),

    .i_fdi_lp_cfg              (RB_i_fdi_lp_cfg),
    .i_fdi_lp_cfg_vld          (RB_i_fdi_lp_cfg_vld),
    .i_fdi_lp_cfg_crd          (RB_i_fdi_lp_cfg_crd),
    .o_fdi_pl_cfg              (RB_o_fdi_pl_cfg),
    .o_fdi_pl_cfg_vld          (RB_o_fdi_pl_cfg_vld),
    .o_fdi_pl_cfg_crd          (RB_o_fdi_pl_cfg_crd),
    .o_fdi_pl_protocol         (RB_o_fdi_pl_protocol),
    .o_fdi_pl_flit_fmt         (RB_o_fdi_pl_flit_fmt),
    .o_fdi_pl_valid            (RB_o_fdi_pl_valid),

    .o_sb_err_msg_rx           (RB_o_sb_err_msg_rx),
    .o_sb_remote_timeout       (RB_o_sb_remote_timeout),
    .o_sb_state_msg_rx         (RB_o_sb_state_msg_rx),
    .o_sb_rdi_overflow         (RB_o_sb_rdi_overflow),
    .o_sb_fdi_overflow         (RB_o_sb_fdi_overflow),
    .o_sb_parity_error         (RB_o_sb_parity_error),
    .o_sb_opid_err             (RB_o_sb_opid_err),
    .o_sb_fdi_packer_error     (RB_o_sb_fdi_packer_error),

    .i_sb_start_param_exch     (RB_i_sb_start_param_exch),
    .o_sb_param_exch_done      (RB_o_sb_param_exch_done),
    .o_sb_invalid_param_exch   (RB_o_sb_invalid_param_exch),
    .o_sb_param_exch_timeout   (RB_o_sb_param_exch_timeout),
    .o_sb_retry_negotiated     (RB_o_sb_retry_negotiated),
    .i_sb_state_msg_tx         (RB_i_sb_state_msg_tx),
    .o_msg_timer_enable        (RB_o_msg_timer_enable),

    .i_reg_read_data           (RB_i_reg_read_data),
    .i_reg_status              (RB_i_reg_status),
    .o_reg_write_data          (RB_o_reg_write_data),
    .o_reg_write_en            (RB_o_reg_write_en),
    .o_reg_address             (RB_o_reg_address),
    .o_reg_be                  (RB_o_reg_be),
    .o_reg_config_req          (RB_o_reg_config_req),
    .o_reg_32_B                (RB_o_reg_32_B),
    .o_reg_valid               (RB_o_reg_valid),

    .i_mailbox_index_low       (RB_i_mailbox_index_low),
    .i_mailbox_index_high      (RB_i_mailbox_index_high),
    .i_mailbox_data_low        (RB_i_mailbox_data_low),
    .i_mailbox_data_high       (RB_i_mailbox_data_high),
    .i_mailbox_trigger         (RB_i_mailbox_trigger),
    .i_remote_access_threshold (RB_i_remote_access_threshold),
    .o_mailbox_data_low        (RB_o_mailbox_data_low),
    .o_mailbox_data_high       (RB_o_mailbox_data_high),
    .o_mailbox_data_en         (RB_o_mailbox_data_en),
    .o_mailbox_trigger_en      (RB_o_mailbox_trigger_en),
    .o_mailbox_status          (RB_o_mailbox_status),
    .o_header_log_1            (RB_o_header_log_1),
    .o_header_log_en           (RB_o_header_log_en),

    .i_adapter_advcap          (RB_i_adapter_advcap),
    .i_cxl_advcap              (RB_i_cxl_advcap),
    .i_format4_enabled         (RB_i_format4_enabled),
    .i_format6_enabled         (RB_i_format6_enabled),
    .i_retry_needed            (RB_i_retry_needed),
    .i_retry_negotiated        (RB_i_retry_negotiated),
    .i_flit_fmt_status         (RB_i_flit_fmt_status),
    .o_adapter_advcap          (RB_o_adapter_advcap),
    .o_adapter_fincap          (RB_o_adapter_fincap),
    .o_cxl_advcap              (RB_o_cxl_advcap),
    .o_cxl_fincap              (RB_o_cxl_fincap),
    .o_adapter_advcap_valid    (RB_o_adapter_advcap_valid),
    .o_adapter_fincap_valid    (RB_o_adapter_fincap_valid),
    .o_cxl_advcap_valid        (RB_o_cxl_advcap_valid),
    .o_cxl_fincap_valid        (RB_o_cxl_fincap_valid),
    .o_flit_format_status      (RB_o_flit_format_status),
    .o_flitfmt_valid           (RB_o_flitfmt_valid)
  );

  /*---------------------------------------------
    DUT: Endpoint
  ---------------------------------------------*/
  UC_sb_top_EP #(
    .P_NC                  (P_NC),
    .P_RX_NUM_OF_COMP_PKTS (P_RX_NUM_OF_COMP_PKTS),
    .P_RX_NUM_OF_MSG_PKTS  (P_RX_NUM_OF_MSG_PKTS),
    .P_TX_FDI_FIFO_DEPTH   (P_TX_FDI_FIFO_DEPTH),
    .P_TX_FIFO_WIDTH       (P_TX_FIFO_WIDTH),
    .P_TX_DATA_W           (P_TX_DATA_W),
    .P_CL_MAX_CREDITS      (P_CL_MAX_CREDITS)
  ) U_EB_DUT (
    .i_clk                     (EB_i_clk),
    .i_rst_n                   (EB_i_rst_n),
    .i_init_n                  (EB_i_init_n),

    .i_rdi_pl_cfg              (EB_i_rdi_pl_cfg),
    .i_rdi_pl_cfg_vld          (EB_i_rdi_pl_cfg_vld),
    .i_rdi_pl_cfg_crd          (EB_i_rdi_pl_cfg_crd),
    .o_rdi_lp_cfg              (EB_o_rdi_lp_cfg),
    .o_rdi_lp_cfg_vld          (EB_o_rdi_lp_cfg_vld),
    .o_rdi_lp_cfg_crd          (EB_o_rdi_lp_cfg_crd),

    .i_fdi_lp_cfg              (EB_i_fdi_lp_cfg),
    .i_fdi_lp_cfg_vld          (EB_i_fdi_lp_cfg_vld),
    .i_fdi_lp_cfg_crd          (EB_i_fdi_lp_cfg_crd),
    .o_fdi_pl_cfg              (EB_o_fdi_pl_cfg),
    .o_fdi_pl_cfg_vld          (EB_o_fdi_pl_cfg_vld),
    .o_fdi_pl_cfg_crd          (EB_o_fdi_pl_cfg_crd),
    .o_fdi_pl_protocol         (EB_o_fdi_pl_protocol),
    .o_fdi_pl_flit_fmt         (EB_o_fdi_pl_flit_fmt),
    .o_fdi_pl_valid            (EB_o_fdi_pl_valid),

    .o_sb_local_timeout        (EB_o_sb_local_timeout),
    .o_sb_state_msg_rx         (EB_o_sb_state_msg_rx),
    .o_sb_rdi_overflow         (EB_o_sb_rdi_overflow),
    .o_sb_fdi_overflow         (EB_o_sb_fdi_overflow),
    .o_sb_parity_error         (EB_o_sb_parity_error),
    .o_sb_opid_err             (EB_o_sb_opid_err),
    .o_sb_fdi_packer_error     (EB_o_sb_fdi_packer_error),

    .i_sb_start_param_exch     (EB_i_sb_start_param_exch),
    .o_sb_param_exch_done      (EB_o_sb_param_exch_done),
    .o_sb_invalid_param_exch   (EB_o_sb_invalid_param_exch),
    .o_sb_param_exch_timeout   (EB_o_sb_param_exch_timeout),
    .o_sb_retry_negotiated     (EB_o_sb_retry_negotiated),
    .i_sb_state_msg_tx         (EB_i_sb_state_msg_tx),
    .i_sb_err_msg_tx           (EB_i_sb_err_msg_tx),
    .o_msg_timer_enable        (EB_o_msg_timer_enable),

    .i_reg_read_data           (EB_i_reg_read_data),
    .i_reg_status              (EB_i_reg_status),
    .o_reg_write_data          (EB_o_reg_write_data),
    .o_reg_write_en            (EB_o_reg_write_en),
    .o_reg_address             (EB_o_reg_address),
    .o_reg_be                  (EB_o_reg_be),
    .o_reg_config_req          (EB_o_reg_config_req),
    .o_reg_32_B                (EB_o_reg_32_B),
    .o_reg_valid               (EB_o_reg_valid),

    .i_adapter_advcap          (EB_i_adapter_advcap),
    .i_cxl_advcap              (EB_i_cxl_advcap),
    .i_format4_enabled         (EB_i_format4_enabled),
    .i_format6_enabled         (EB_i_format6_enabled),
    .i_retry_needed            (EB_i_retry_needed),
    .i_retry_negotiated        (EB_i_retry_negotiated),
    .i_flit_fmt_status         (EB_i_flit_fmt_status),
    .o_adapter_advcap          (EB_o_adapter_advcap),
    .o_adapter_fincap          (EB_o_adapter_fincap),
    .o_cxl_advcap              (EB_o_cxl_advcap),
    .o_cxl_fincap              (EB_o_cxl_fincap),
    .o_adapter_advcap_valid    (EB_o_adapter_advcap_valid),
    .o_adapter_fincap_valid    (EB_o_adapter_fincap_valid),
    .o_cxl_advcap_valid        (EB_o_cxl_advcap_valid),
    .o_cxl_fincap_valid        (EB_o_cxl_fincap_valid),
    .o_flit_format_status      (EB_o_flit_format_status),
    .o_flitfmt_valid           (EB_o_flitfmt_valid)
  );

  /*---------------------------------------------
    Clock Generator
  ---------------------------------------------*/
  always begin
    #LOW_TIME  RB_i_clk = ~RB_i_clk;
    #HIGH_TIME RB_i_clk = ~RB_i_clk;
  end

  assign EB_i_clk = RB_i_clk;

  /*---------------------------------------------
    Initial Block
  ---------------------------------------------*/
  initial begin
    $dumpfile("UC_sb_top_RP_EP_2die.vcd");
    $dumpvars(0, UC_sb_top_RP_EP_2die_tb);

    initialize();
    reset();

    $display("\n=== Test Case 1: PCIe Parameter Exchange RP <-> EP / Format 3 ===");
    do_PCIe_parameter_exchange("Format3", 1);

    $display("\n=== Test Case 2: LSM Active_req RP -> EP, then Active_response EP -> RP ===");
    send_lsm_state_msg(ACTIVE_REQ);
    send_lsm_state_msg_from_ep(ACTIVE_RESP);

    #1000;
    $display("\n=== Required RP/EP sideband tests completed! ===");
    $finish;
  end

  /*---------------------------------------------
    Tasks
  ---------------------------------------------*/
  task initialize();
    RB_i_clk    = 0;
    RB_i_rst_n  = 1;
    RB_i_init_n = 1;

    EB_i_rst_n  = 1;
    EB_i_init_n = 1;

    RB_i_flit_fmt_status_set = 0;
    EB_i_flit_fmt_status_set = 0;

    RB_i_fdi_lp_cfg     = '0;
    RB_i_fdi_lp_cfg_vld = 1'b0;
    RB_i_fdi_lp_cfg_crd = 1'b1;

    EB_i_fdi_lp_cfg     = '0;
    EB_i_fdi_lp_cfg_vld = 1'b0;
    EB_i_fdi_lp_cfg_crd = 1'b1;

    RB_i_sb_start_param_exch = 1'b0;
    EB_i_sb_start_param_exch = 1'b0;

    RB_i_sb_state_msg_tx = NONE;
    EB_i_sb_state_msg_tx = NONE;
    EB_i_sb_err_msg_tx   = NONE_ERR;

    RB_i_reg_read_data = '0;
    RB_i_reg_status    = '0;
    EB_i_reg_read_data = '0;
    EB_i_reg_status    = '0;

    RB_i_mailbox_index_low       = '0;
    RB_i_mailbox_index_high      = '0;
    RB_i_mailbox_data_low        = '0;
    RB_i_mailbox_data_high       = '0;
    RB_i_mailbox_trigger         = 1'b0;
    RB_i_remote_access_threshold = '0;

    RB_i_adapter_advcap   = '0;
    RB_i_cxl_advcap       = '0;
    RB_i_format4_enabled  = 1'b0;
    RB_i_format6_enabled  = 1'b0;
    RB_i_retry_needed     = 1'b0;
    RB_i_flit_fmt_status  = '0;

    EB_i_adapter_advcap   = '0;
    EB_i_cxl_advcap       = '0;
    EB_i_format4_enabled  = 1'b0;
    EB_i_format6_enabled  = 1'b0;
    EB_i_retry_needed     = 1'b0;
    EB_i_flit_fmt_status  = '0;
  endtask

  task reset();
    $display("Applying reset to both dies...");
    RB_i_rst_n = 1'b0;
    EB_i_rst_n = 1'b0;
    #(CLK_PERIOD);
    RB_i_rst_n = 1'b1;
    EB_i_rst_n = 1'b1;
    #(CLK_PERIOD);
  endtask

  task collect_rp_rdi_half_packet(output logic [63:0] half_packet);
    half_packet = '0;
    for (int chunk = 0; chunk < 64/P_NC; chunk++) begin
      @(posedge RB_i_clk);
      if (chunk == 0)
        half_packet = RB_o_rdi_lp_cfg;
      else
        half_packet = half_packet | (RB_o_rdi_lp_cfg << (chunk * P_NC));
    end
  endtask

  task collect_ep_rdi_half_packet(output logic [63:0] half_packet);
    half_packet = '0;
    for (int chunk = 0; chunk < 64/P_NC; chunk++) begin
      @(posedge RB_i_clk);
      if (chunk == 0)
        half_packet = EB_o_rdi_lp_cfg;
      else
        half_packet = half_packet | (EB_o_rdi_lp_cfg << (chunk * P_NC));
    end
  endtask

  task do_PCIe_parameter_exchange(input string flit_format, input with_retry);
    if (with_retry) begin
      case (flit_format)
        "Format2": begin
          RB_i_adapter_advcap = 64'h0_0080_00aa;
          EB_i_adapter_advcap = 64'h0_0080_00aa;
        end
        "Format3": begin
          RB_i_adapter_advcap = 64'h0_0100_00aa;
          EB_i_adapter_advcap = 64'h0_0100_00aa;
        end
        "Format4": begin
          RB_i_adapter_advcap = 64'h0_0700_00aa;
          EB_i_adapter_advcap = 64'h0_0700_00aa;
        end
        "Format6": begin
          RB_i_adapter_advcap = 64'h0_0F00_00aa;
          EB_i_adapter_advcap = 64'h0_0F00_00aa;
        end
        default: $error("Invalid flit format");
      endcase
      RB_i_retry_needed = 1'b1;
      EB_i_retry_needed = 1'b1;
    end else begin
      case (flit_format)
        "Format2": begin
          RB_i_adapter_advcap = 64'h0_0080_008a;
          EB_i_adapter_advcap = 64'h0_0080_008a;
        end
        "Format3": begin
          RB_i_adapter_advcap = 64'h0_0100_008a;
          EB_i_adapter_advcap = 64'h0_0100_008a;
        end
        "Format4": begin
          RB_i_adapter_advcap = 64'h0_0700_008a;
          EB_i_adapter_advcap = 64'h0_0700_008a;
        end
        "Format6": begin
          RB_i_adapter_advcap = 64'h0_0F00_008a;
          EB_i_adapter_advcap = 64'h0_0F00_008a;
        end
        default: $error("Invalid flit format");
      endcase
      RB_i_retry_needed = 1'b0;
      EB_i_retry_needed = 1'b0;
    end

    RB_i_cxl_advcap = 64'h1;
    EB_i_cxl_advcap = 64'h1;

    RB_i_format4_enabled = 1'b1;
    RB_i_format6_enabled = 1'b1;
    EB_i_format4_enabled = 1'b1;
    EB_i_format6_enabled = 1'b1;

    @(posedge RB_i_clk);
    RB_i_sb_start_param_exch = 1'b1;
    EB_i_sb_start_param_exch = 1'b1;
    @(posedge RB_i_clk);
    RB_i_sb_start_param_exch = 1'b0;
    EB_i_sb_start_param_exch = 1'b0;

    fork
      begin
        wait (RB_o_sb_param_exch_done || RB_o_sb_invalid_param_exch || RB_o_sb_param_exch_timeout);
      end
      begin
        wait (EB_o_sb_param_exch_done || EB_o_sb_invalid_param_exch || EB_o_sb_param_exch_timeout);
      end
    join

    if (RB_o_sb_param_exch_done && EB_o_sb_param_exch_done)
      $display("PCIe PARAMETER EXCHANGE DONE on both RP and EP!");
    else
      $display("PCIe PARAMETER EXCHANGE FAILED. RB_done=%0b EB_done=%0b RB_invalid=%0b EB_invalid=%0b RB_timeout=%0b EB_timeout=%0b",
               RB_o_sb_param_exch_done, EB_o_sb_param_exch_done,
               RB_o_sb_invalid_param_exch, EB_o_sb_invalid_param_exch,
               RB_o_sb_param_exch_timeout, EB_o_sb_param_exch_timeout);

    if ((RB_o_flit_format_status == 5'd3 || RB_o_fdi_pl_flit_fmt == 4'd3) &&
        (EB_o_flit_format_status == 5'd3 || EB_o_fdi_pl_flit_fmt == 4'd3))
      $display("FORMAT 3 selected on both RP and EP.");
    else
      $display("FORMAT CHECK WARNING: RB_status=%0d RB_fdi_fmt=%0d EB_status=%0d EB_fdi_fmt=%0d",
               RB_o_flit_format_status, RB_o_fdi_pl_flit_fmt,
               EB_o_flit_format_status, EB_o_fdi_pl_flit_fmt);
  endtask

  task send_lsm_state_msg(input sb_state_msg_encoding lsm_msg);
    logic [63:0] tx_lsm_msg;
    logic [63:0] expected_lsm_msg;

    RB_i_sb_state_msg_tx = lsm_msg;
    #(CLK_PERIOD);
    RB_i_sb_state_msg_tx = NONE;

    @(posedge RB_o_rdi_lp_cfg_vld);
    collect_rp_rdi_half_packet(tx_lsm_msg);

    case (lsm_msg)
      ACTIVE_REQ:     expected_lsm_msg = 64'h05000001_2000C012;
      L1_REQ:         expected_lsm_msg = 64'h05000004_2000C012;
      L2_REQ:         expected_lsm_msg = 64'h05000008_2000C012;
      LINKRESET_REQ:  expected_lsm_msg = 64'h45000009_2000C012;
      DISABLED_REQ:   expected_lsm_msg = 64'h4500000C_2000C012;
      ACTIVE_RESP:    expected_lsm_msg = 64'h45000001_20010012;
      PMNAK_RESP:     expected_lsm_msg = 64'h45000002_20010012;
      L1_RESP:        expected_lsm_msg = 64'h45000004_20010012;
      L2_RESP:        expected_lsm_msg = 64'h45000008_20010012;
      LINKRESET_RESP: expected_lsm_msg = 64'h05000009_20010012;
      DISABLED_RESP:  expected_lsm_msg = 64'h0500000C_20010012;
      default:        expected_lsm_msg = 64'h0;
    endcase
 
    wait(EB_i_rdi_pl_cfg_vld); 
    repeat (3) @(posedge RB_i_clk);

    if ((EB_o_sb_state_msg_rx == lsm_msg))
      $display("LSM State Message RP -> EP PASSED. Msg=%0d Data=%h", lsm_msg, tx_lsm_msg);
    else
      $display("LSM State Message RP -> EP FAILED. ExpectedData=%h GotData=%h ExpectedMsg=%0d GotMsg=%0d",
               expected_lsm_msg, tx_lsm_msg, lsm_msg, EB_o_sb_state_msg_rx);
  endtask

  task send_lsm_state_msg_from_ep(input sb_state_msg_encoding lsm_msg);
    logic [63:0] tx_lsm_msg;
    logic [63:0] expected_lsm_msg;

    EB_i_sb_state_msg_tx = lsm_msg;
    #(CLK_PERIOD);
    EB_i_sb_state_msg_tx = NONE;

    @(posedge EB_o_rdi_lp_cfg_vld);
    collect_ep_rdi_half_packet(tx_lsm_msg);

    case (lsm_msg)
      ACTIVE_REQ:     expected_lsm_msg = 64'h05000001_2000C012;
      L1_REQ:         expected_lsm_msg = 64'h05000004_2000C012;
      L2_REQ:         expected_lsm_msg = 64'h05000008_2000C012;
      LINKRESET_REQ:  expected_lsm_msg = 64'h45000009_2000C012;
      DISABLED_REQ:   expected_lsm_msg = 64'h4500000C_2000C012;
      ACTIVE_RESP:    expected_lsm_msg = 64'h45000001_20010012;
      PMNAK_RESP:     expected_lsm_msg = 64'h45000002_20010012;
      L1_RESP:        expected_lsm_msg = 64'h45000004_20010012;
      L2_RESP:        expected_lsm_msg = 64'h45000008_20010012;
      LINKRESET_RESP: expected_lsm_msg = 64'h05000009_20010012;
      DISABLED_RESP:  expected_lsm_msg = 64'h0500000C_20010012;
      default:        expected_lsm_msg = 64'h0;
    endcase
    wait(RB_i_rdi_pl_cfg_vld);

    repeat (3) @(posedge RB_i_clk);

    if ((RB_o_sb_state_msg_rx == lsm_msg))
      $display("LSM State Message EP -> RP PASSED. Msg=%0d Data=%h", lsm_msg, tx_lsm_msg);
    else
      $display("LSM State Message EP -> RP FAILED. ExpectedData=%h GotData=%h ExpectedMsg=%0d GotMsg=%0d",
               expected_lsm_msg, tx_lsm_msg, lsm_msg, RB_o_sb_state_msg_rx);
  endtask

  always_comb begin
    if (!RB_i_flit_fmt_status_set && RB_o_flit_format_status != 0) begin
      RB_i_flit_fmt_status = RB_o_flit_format_status;
      RB_i_flit_fmt_status_set = 1'b1;
    end else if (!RB_i_flit_fmt_status_set) begin
      RB_i_flit_fmt_status = 5'b0;
    end
  end

  always_comb begin
    if (!EB_i_flit_fmt_status_set && EB_o_flit_format_status != 0) begin
      EB_i_flit_fmt_status = EB_o_flit_format_status;
      EB_i_flit_fmt_status_set = 1'b1;
    end else if (!EB_i_flit_fmt_status_set) begin
      EB_i_flit_fmt_status = 5'b0;
    end
  end

  assign RB_i_retry_negotiated = RB_i_retry_needed & RB_o_sb_param_exch_done;
  assign EB_i_retry_negotiated = EB_i_retry_needed & EB_o_sb_param_exch_done;

endmodule