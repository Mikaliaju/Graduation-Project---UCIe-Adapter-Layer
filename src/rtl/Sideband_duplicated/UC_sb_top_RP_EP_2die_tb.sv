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
  logic RP_i_clk;
  logic RP_i_rst_n;
  logic RP_i_init_n;

  logic EP_i_clk;
  logic EP_i_rst_n;
  logic EP_i_init_n;

  /*---------------------------------------------
    Root Port Signals
  ---------------------------------------------*/
  logic [P_NC-1:0] RP_i_rdi_pl_cfg;
  logic            RP_i_rdi_pl_cfg_vld;
  logic            RP_i_rdi_pl_cfg_crd;
  logic [P_NC-1:0] RP_o_rdi_lp_cfg;
  logic            RP_o_rdi_lp_cfg_vld;
  logic            RP_o_rdi_lp_cfg_crd;

  logic [P_NC-1:0] RP_i_fdi_lp_cfg;
  logic            RP_i_fdi_lp_cfg_vld;
  logic            RP_i_fdi_lp_cfg_crd;
  logic [P_NC-1:0] RP_o_fdi_pl_cfg;
  logic            RP_o_fdi_pl_cfg_vld;
  logic            RP_o_fdi_pl_cfg_crd;
  logic [3:0]      RP_o_fdi_pl_protocol;
  logic [3:0]      RP_o_fdi_pl_flit_fmt;
  logic            RP_o_fdi_pl_valid;

  sb_error_msg_encoding RP_o_sb_err_msg_rx;
  logic                 RP_o_sb_remote_timeout;
  sb_state_msg_encoding RP_o_sb_state_msg_rx;
  logic                 RP_o_sb_rdi_overflow;
  logic                 RP_o_sb_fdi_overflow;
  logic                 RP_o_sb_parity_error;
  logic                 RP_o_sb_opid_err;
  logic                 RP_o_sb_fdi_packer_error;

  logic                 RP_i_sb_start_param_exch;
  logic                 RP_o_sb_param_exch_done;
  logic                 RP_o_sb_invalid_param_exch;
  logic                 RP_o_sb_param_exch_timeout;
  logic                 RP_o_sb_retry_negotiated;
  sb_state_msg_encoding RP_i_sb_state_msg_tx;
  logic                 RP_o_msg_timer_enable;

  logic [63:0] RP_i_reg_read_data;
  logic [2:0]  RP_i_reg_status;
  logic [63:0] RP_o_reg_write_data;
  logic        RP_o_reg_write_en;
  logic [23:0] RP_o_reg_address;
  logic [7:0]  RP_o_reg_be;
  logic        RP_o_reg_config_req;
  logic        RP_o_reg_32_B;
  logic        RP_o_reg_valid;

  logic [31:0] RP_i_mailbox_index_low;
  logic [4:0]  RP_i_mailbox_index_high;
  logic [31:0] RP_i_mailbox_data_low;
  logic [31:0] RP_i_mailbox_data_high;
  logic        RP_i_mailbox_trigger;
  logic [3:0]  RP_i_remote_access_threshold;
  logic [31:0] RP_o_mailbox_data_low;
  logic [31:0] RP_o_mailbox_data_high;
  logic        RP_o_mailbox_data_en;
  logic        RP_o_mailbox_trigger_en;
  logic [1:0]  RP_o_mailbox_status;
  logic [63:0] RP_o_header_log_1;
  logic        RP_o_header_log_en;

  logic [63:0] RP_i_adapter_advcap;
  logic [63:0] RP_i_cxl_advcap;
  logic        RP_i_format4_enabled;
  logic        RP_i_format6_enabled;
  logic        RP_i_retry_needed;
  logic        RP_i_retry_negotiated;
  logic [4:0]  RP_i_flit_fmt_status;
  logic [63:0] RP_o_adapter_advcap;
  logic [63:0] RP_o_adapter_fincap;
  logic [63:0] RP_o_cxl_advcap;
  logic [63:0] RP_o_cxl_fincap;
  logic        RP_o_adapter_advcap_valid;
  logic        RP_o_adapter_fincap_valid;
  logic        RP_o_cxl_advcap_valid;
  logic        RP_o_cxl_fincap_valid;
  logic [4:0]  RP_o_flit_format_status;
  logic        RP_o_flitfmt_valid;
  logic        RP_i_flit_fmt_status_set;

  /*---------------------------------------------
    Endpoint Signals
  ---------------------------------------------*/
  logic [P_NC-1:0] EP_i_rdi_pl_cfg;
  logic            EP_i_rdi_pl_cfg_vld;
  logic            EP_i_rdi_pl_cfg_crd;
  logic [P_NC-1:0] EP_o_rdi_lp_cfg;
  logic            EP_o_rdi_lp_cfg_vld;
  logic            EP_o_rdi_lp_cfg_crd;

  logic [P_NC-1:0] EP_i_fdi_lp_cfg;
  logic            EP_i_fdi_lp_cfg_vld;
  logic            EP_i_fdi_lp_cfg_crd;
  logic [P_NC-1:0] EP_o_fdi_pl_cfg;
  logic            EP_o_fdi_pl_cfg_vld;
  logic            EP_o_fdi_pl_cfg_crd;
  logic [3:0]      EP_o_fdi_pl_protocol;
  logic [3:0]      EP_o_fdi_pl_flit_fmt;
  logic            EP_o_fdi_pl_valid;

  logic                 EP_o_sb_local_timeout;
  sb_state_msg_encoding EP_o_sb_state_msg_rx;
  logic                 EP_o_sb_rdi_overflow;
  logic                 EP_o_sb_fdi_overflow;
  logic                 EP_o_sb_parity_error;
  logic                 EP_o_sb_opid_err;
  logic                 EP_o_sb_fdi_packer_error;

  logic                 EP_i_sb_start_param_exch;
  logic                 EP_o_sb_param_exch_done;
  logic                 EP_o_sb_invalid_param_exch;
  logic                 EP_o_sb_param_exch_timeout;
  logic                 EP_o_sb_retry_negotiated;
  sb_state_msg_encoding EP_i_sb_state_msg_tx;
  sb_error_msg_encoding EP_i_sb_err_msg_tx;
  logic                 EP_o_msg_timer_enable;

  logic [63:0] EP_i_reg_read_data;
  logic [2:0]  EP_i_reg_status;
  logic [63:0] EP_o_reg_write_data;
  logic        EP_o_reg_write_en;
  logic [23:0] EP_o_reg_address;
  logic [7:0]  EP_o_reg_be;
  logic        EP_o_reg_config_req;
  logic        EP_o_reg_32_B;
  logic        EP_o_reg_valid;

  logic [63:0] EP_i_adapter_advcap;
  logic [63:0] EP_i_cxl_advcap;
  logic        EP_i_format4_enabled;
  logic        EP_i_format6_enabled;
  logic        EP_i_retry_needed;
  logic        EP_i_retry_negotiated;
  logic [4:0]  EP_i_flit_fmt_status;
  logic [63:0] EP_o_adapter_advcap;
  logic [63:0] EP_o_adapter_fincap;
  logic [63:0] EP_o_cxl_advcap;
  logic [63:0] EP_o_cxl_fincap;
  logic        EP_o_adapter_advcap_valid;
  logic        EP_o_adapter_fincap_valid;
  logic        EP_o_cxl_advcap_valid;
  logic        EP_o_cxl_fincap_valid;
  logic [4:0]  EP_o_flit_format_status;
  logic        EP_o_flitfmt_valid;
  logic        EP_i_flit_fmt_status_set;

  /*---------------------------------------------
    RDI Cross Connection Only
  ---------------------------------------------*/
  assign EP_i_rdi_pl_cfg     = RP_o_rdi_lp_cfg;
  assign EP_i_rdi_pl_cfg_vld = RP_o_rdi_lp_cfg_vld;

  assign RP_i_rdi_pl_cfg     = EP_o_rdi_lp_cfg;
  assign RP_i_rdi_pl_cfg_vld = EP_o_rdi_lp_cfg_vld;

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
  ) U_RP_DUT (
    .i_clk                     (RP_i_clk),
    .i_rst_n                   (RP_i_rst_n),
    .i_init_n                  (RP_i_init_n),

    .i_rdi_pl_cfg              (RP_i_rdi_pl_cfg),
    .i_rdi_pl_cfg_vld          (RP_i_rdi_pl_cfg_vld),
    .i_rdi_pl_cfg_crd          (RP_i_rdi_pl_cfg_crd),
    .o_rdi_lp_cfg              (RP_o_rdi_lp_cfg),
    .o_rdi_lp_cfg_vld          (RP_o_rdi_lp_cfg_vld),
    .o_rdi_lp_cfg_crd          (RP_o_rdi_lp_cfg_crd),

    .i_fdi_lp_cfg              (RP_i_fdi_lp_cfg),
    .i_fdi_lp_cfg_vld          (RP_i_fdi_lp_cfg_vld),
    .i_fdi_lp_cfg_crd          (RP_i_fdi_lp_cfg_crd),
    .o_fdi_pl_cfg              (RP_o_fdi_pl_cfg),
    .o_fdi_pl_cfg_vld          (RP_o_fdi_pl_cfg_vld),
    .o_fdi_pl_cfg_crd          (RP_o_fdi_pl_cfg_crd),
    .o_fdi_pl_protocol         (RP_o_fdi_pl_protocol),
    .o_fdi_pl_flit_fmt         (RP_o_fdi_pl_flit_fmt),
    .o_fdi_pl_valid            (RP_o_fdi_pl_valid),

    .o_sb_err_msg_rx           (RP_o_sb_err_msg_rx),
    .o_sb_remote_timeout       (RP_o_sb_remote_timeout),
    .o_sb_state_msg_rx         (RP_o_sb_state_msg_rx),
    .o_sb_rdi_overflow         (RP_o_sb_rdi_overflow),
    .o_sb_fdi_overflow         (RP_o_sb_fdi_overflow),
    .o_sb_parity_error         (RP_o_sb_parity_error),
    .o_sb_opid_err             (RP_o_sb_opid_err),
    .o_sb_fdi_packer_error     (RP_o_sb_fdi_packer_error),

    .i_sb_start_param_exch     (RP_i_sb_start_param_exch),
    .o_sb_param_exch_done      (RP_o_sb_param_exch_done),
    .o_sb_invalid_param_exch   (RP_o_sb_invalid_param_exch),
    .o_sb_param_exch_timeout   (RP_o_sb_param_exch_timeout),
    .o_sb_retry_negotiated     (RP_o_sb_retry_negotiated),
    .i_sb_state_msg_tx         (RP_i_sb_state_msg_tx),
    .o_msg_timer_enable        (RP_o_msg_timer_enable),

    .i_reg_read_data           (RP_i_reg_read_data),
    .i_reg_status              (RP_i_reg_status),
    .o_reg_write_data          (RP_o_reg_write_data),
    .o_reg_write_en            (RP_o_reg_write_en),
    .o_reg_address             (RP_o_reg_address),
    .o_reg_be                  (RP_o_reg_be),
    .o_reg_config_req          (RP_o_reg_config_req),
    .o_reg_32_B                (RP_o_reg_32_B),
    .o_reg_valid               (RP_o_reg_valid),

    .i_mailbox_index_low       (RP_i_mailbox_index_low),
    .i_mailbox_index_high      (RP_i_mailbox_index_high),
    .i_mailbox_data_low        (RP_i_mailbox_data_low),
    .i_mailbox_data_high       (RP_i_mailbox_data_high),
    .i_mailbox_trigger         (RP_i_mailbox_trigger),
    .i_remote_access_threshold (RP_i_remote_access_threshold),
    .o_mailbox_data_low        (RP_o_mailbox_data_low),
    .o_mailbox_data_high       (RP_o_mailbox_data_high),
    .o_mailbox_data_en         (RP_o_mailbox_data_en),
    .o_mailbox_trigger_en      (RP_o_mailbox_trigger_en),
    .o_mailbox_status          (RP_o_mailbox_status),
    .o_header_log_1            (RP_o_header_log_1),
    .o_header_log_en           (RP_o_header_log_en),

    .i_adapter_advcap          (RP_i_adapter_advcap),
    .i_cxl_advcap              (RP_i_cxl_advcap),
    .i_format4_enabled         (RP_i_format4_enabled),
    .i_format6_enabled         (RP_i_format6_enabled),
    .i_retry_needed            (RP_i_retry_needed),
    .i_retry_negotiated        (RP_i_retry_negotiated),
    .i_flit_fmt_status         (RP_i_flit_fmt_status),
    .o_adapter_advcap          (RP_o_adapter_advcap),
    .o_adapter_fincap          (RP_o_adapter_fincap),
    .o_cxl_advcap              (RP_o_cxl_advcap),
    .o_cxl_fincap              (RP_o_cxl_fincap),
    .o_adapter_advcap_valid    (RP_o_adapter_advcap_valid),
    .o_adapter_fincap_valid    (RP_o_adapter_fincap_valid),
    .o_cxl_advcap_valid        (RP_o_cxl_advcap_valid),
    .o_cxl_fincap_valid        (RP_o_cxl_fincap_valid),
    .o_flit_format_status      (RP_o_flit_format_status),
    .o_flitfmt_valid           (RP_o_flitfmt_valid)
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
  ) U_EP_DUT (
    .i_clk                     (EP_i_clk),
    .i_rst_n                   (EP_i_rst_n),
    .i_init_n                  (EP_i_init_n),

    .i_rdi_pl_cfg              (EP_i_rdi_pl_cfg),
    .i_rdi_pl_cfg_vld          (EP_i_rdi_pl_cfg_vld),
    .i_rdi_pl_cfg_crd          (EP_i_rdi_pl_cfg_crd),
    .o_rdi_lp_cfg              (EP_o_rdi_lp_cfg),
    .o_rdi_lp_cfg_vld          (EP_o_rdi_lp_cfg_vld),
    .o_rdi_lp_cfg_crd          (EP_o_rdi_lp_cfg_crd),

    .i_fdi_lp_cfg              (EP_i_fdi_lp_cfg),
    .i_fdi_lp_cfg_vld          (EP_i_fdi_lp_cfg_vld),
    .i_fdi_lp_cfg_crd          (EP_i_fdi_lp_cfg_crd),
    .o_fdi_pl_cfg              (EP_o_fdi_pl_cfg),
    .o_fdi_pl_cfg_vld          (EP_o_fdi_pl_cfg_vld),
    .o_fdi_pl_cfg_crd          (EP_o_fdi_pl_cfg_crd),
    .o_fdi_pl_protocol         (EP_o_fdi_pl_protocol),
    .o_fdi_pl_flit_fmt         (EP_o_fdi_pl_flit_fmt),
    .o_fdi_pl_valid            (EP_o_fdi_pl_valid),

    .o_sb_local_timeout        (EP_o_sb_local_timeout),
    .o_sb_state_msg_rx         (EP_o_sb_state_msg_rx),
    .o_sb_rdi_overflow         (EP_o_sb_rdi_overflow),
    .o_sb_fdi_overflow         (EP_o_sb_fdi_overflow),
    .o_sb_parity_error         (EP_o_sb_parity_error),
    .o_sb_opid_err             (EP_o_sb_opid_err),
    .o_sb_fdi_packer_error     (EP_o_sb_fdi_packer_error),

    .i_sb_start_param_exch     (EP_i_sb_start_param_exch),
    .o_sb_param_exch_done      (EP_o_sb_param_exch_done),
    .o_sb_invalid_param_exch   (EP_o_sb_invalid_param_exch),
    .o_sb_param_exch_timeout   (EP_o_sb_param_exch_timeout),
    .o_sb_retry_negotiated     (EP_o_sb_retry_negotiated),
    .i_sb_state_msg_tx         (EP_i_sb_state_msg_tx),
    .i_sb_err_msg_tx           (EP_i_sb_err_msg_tx),
    .o_msg_timer_enable        (EP_o_msg_timer_enable),

    .i_reg_read_data           (EP_i_reg_read_data),
    .i_reg_status              (EP_i_reg_status),
    .o_reg_write_data          (EP_o_reg_write_data),
    .o_reg_write_en            (EP_o_reg_write_en),
    .o_reg_address             (EP_o_reg_address),
    .o_reg_be                  (EP_o_reg_be),
    .o_reg_config_req          (EP_o_reg_config_req),
    .o_reg_32_B                (EP_o_reg_32_B),
    .o_reg_valid               (EP_o_reg_valid),

    .i_adapter_advcap          (EP_i_adapter_advcap),
    .i_cxl_advcap              (EP_i_cxl_advcap),
    .i_format4_enabled         (EP_i_format4_enabled),
    .i_format6_enabled         (EP_i_format6_enabled),
    .i_retry_needed            (EP_i_retry_needed),
    .i_retry_negotiated        (EP_i_retry_negotiated),
    .i_flit_fmt_status         (EP_i_flit_fmt_status),
    .o_adapter_advcap          (EP_o_adapter_advcap),
    .o_adapter_fincap          (EP_o_adapter_fincap),
    .o_cxl_advcap              (EP_o_cxl_advcap),
    .o_cxl_fincap              (EP_o_cxl_fincap),
    .o_adapter_advcap_valid    (EP_o_adapter_advcap_valid),
    .o_adapter_fincap_valid    (EP_o_adapter_fincap_valid),
    .o_cxl_advcap_valid        (EP_o_cxl_advcap_valid),
    .o_cxl_fincap_valid        (EP_o_cxl_fincap_valid),
    .o_flit_format_status      (EP_o_flit_format_status),
    .o_flitfmt_valid           (EP_o_flitfmt_valid)
  );

  /*---------------------------------------------
    Clock Generator
  ---------------------------------------------*/
  always begin
    #LOW_TIME  RP_i_clk = ~RP_i_clk;
    #HIGH_TIME RP_i_clk = ~RP_i_clk;
  end

  assign EP_i_clk = RP_i_clk;

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
    RP_i_clk    = 0;
    RP_i_rst_n  = 1;
    RP_i_init_n = 1;

    EP_i_rst_n  = 1;
    EP_i_init_n = 1;

    RP_i_flit_fmt_status_set = 0;
    EP_i_flit_fmt_status_set = 0;

    RP_i_fdi_lp_cfg     = '0;
    RP_i_fdi_lp_cfg_vld = 1'b0;
    RP_i_fdi_lp_cfg_crd = 1'b1;

    EP_i_fdi_lp_cfg     = '0;
    EP_i_fdi_lp_cfg_vld = 1'b0;
    EP_i_fdi_lp_cfg_crd = 1'b1;

    RP_i_sb_start_param_exch = 1'b0;
    EP_i_sb_start_param_exch = 1'b0;

    RP_i_sb_state_msg_tx = NONE;
    EP_i_sb_state_msg_tx = NONE;
    EP_i_sb_err_msg_tx   = NONE_ERR;

    RP_i_reg_read_data = '0;
    RP_i_reg_status    = '0;
    EP_i_reg_read_data = '0;
    EP_i_reg_status    = '0;

    RP_i_mailbox_index_low       = '0;
    RP_i_mailbox_index_high      = '0;
    RP_i_mailbox_data_low        = '0;
    RP_i_mailbox_data_high       = '0;
    RP_i_mailbox_trigger         = 1'b0;
    RP_i_remote_access_threshold = '0;

    RP_i_adapter_advcap   = '0;
    RP_i_cxl_advcap       = '0;
    RP_i_format4_enabled  = 1'b0;
    RP_i_format6_enabled  = 1'b0;
    RP_i_retry_needed     = 1'b0;
    RP_i_flit_fmt_status  = '0;

    EP_i_adapter_advcap   = '0;
    EP_i_cxl_advcap       = '0;
    EP_i_format4_enabled  = 1'b0;
    EP_i_format6_enabled  = 1'b0;
    EP_i_retry_needed     = 1'b0;
    EP_i_flit_fmt_status  = '0;
  endtask

  task reset();
    $display("Applying reset to both dies...");
    RP_i_rst_n = 1'b0;
    EP_i_rst_n = 1'b0;
    #(CLK_PERIOD);
    RP_i_rst_n = 1'b1;
    EP_i_rst_n = 1'b1;
    #(CLK_PERIOD);
  endtask

  task collect_rp_rdi_half_packet(output logic [63:0] half_packet);
    half_packet = '0;
    for (int chunk = 0; chunk < 64/P_NC; chunk++) begin
      @(posedge RP_i_clk);
      if (chunk == 0)
        half_packet = RP_o_rdi_lp_cfg;
      else
        half_packet = half_packet | (RP_o_rdi_lp_cfg << (chunk * P_NC));
    end
  endtask

  task collect_ep_rdi_half_packet(output logic [63:0] half_packet);
    half_packet = '0;
    for (int chunk = 0; chunk < 64/P_NC; chunk++) begin
      @(posedge RP_i_clk);
      if (chunk == 0)
        half_packet = EP_o_rdi_lp_cfg;
      else
        half_packet = half_packet | (EP_o_rdi_lp_cfg << (chunk * P_NC));
    end
  endtask

  task do_PCIe_parameter_exchange(input string flit_format, input with_retry);
    if (with_retry) begin
      case (flit_format)
        "Format2": begin
          RP_i_adapter_advcap = 64'h0_0080_00aa;
          EP_i_adapter_advcap = 64'h0_0080_00aa;
        end
        "Format3": begin
          RP_i_adapter_advcap = 64'h0_0100_00aa;
          EP_i_adapter_advcap = 64'h0_0100_00aa;
        end
        "Format4": begin
          RP_i_adapter_advcap = 64'h0_0700_00aa;
          EP_i_adapter_advcap = 64'h0_0700_00aa;
        end
        "Format6": begin
          RP_i_adapter_advcap = 64'h0_0F00_00aa;
          EP_i_adapter_advcap = 64'h0_0F00_00aa;
        end
        default: $error("Invalid flit format");
      endcase
      RP_i_retry_needed = 1'b1;
      EP_i_retry_needed = 1'b1;
    end else begin
      case (flit_format)
        "Format2": begin
          RP_i_adapter_advcap = 64'h0_0080_008a;
          EP_i_adapter_advcap = 64'h0_0080_008a;
        end
        "Format3": begin
          RP_i_adapter_advcap = 64'h0_0100_008a;
          EP_i_adapter_advcap = 64'h0_0100_008a;
        end
        "Format4": begin
          RP_i_adapter_advcap = 64'h0_0700_008a;
          EP_i_adapter_advcap = 64'h0_0700_008a;
        end
        "Format6": begin
          RP_i_adapter_advcap = 64'h0_0F00_008a;
          EP_i_adapter_advcap = 64'h0_0F00_008a;
        end
        default: $error("Invalid flit format");
      endcase
      RP_i_retry_needed = 1'b0;
      EP_i_retry_needed = 1'b0;
    end

    RP_i_cxl_advcap = 64'h1;
    EP_i_cxl_advcap = 64'h1;

    RP_i_format4_enabled = 1'b1;
    RP_i_format6_enabled = 1'b1;
    EP_i_format4_enabled = 1'b1;
    EP_i_format6_enabled = 1'b1;

    @(posedge RP_i_clk);
    RP_i_sb_start_param_exch = 1'b1;
    EP_i_sb_start_param_exch = 1'b1;
    @(posedge RP_i_clk);
    RP_i_sb_start_param_exch = 1'b0;
    EP_i_sb_start_param_exch = 1'b0;

    fork
      begin
        wait (RP_o_sb_param_exch_done || RP_o_sb_invalid_param_exch || RP_o_sb_param_exch_timeout);
      end
      begin
        wait (EP_o_sb_param_exch_done || EP_o_sb_invalid_param_exch || EP_o_sb_param_exch_timeout);
      end
    join

    if (RP_o_sb_param_exch_done && EP_o_sb_param_exch_done)
      $display("PCIe PARAMETER EXCHANGE DONE on both RP and EP!");
    else
      $display("PCIe PARAMETER EXCHANGE FAILED. RP_done=%0b EP_done=%0b RP_invalid=%0b EP_invalid=%0b RP_timeout=%0b EP_timeout=%0b",
               RP_o_sb_param_exch_done, EP_o_sb_param_exch_done,
               RP_o_sb_invalid_param_exch, EP_o_sb_invalid_param_exch,
               RP_o_sb_param_exch_timeout, EP_o_sb_param_exch_timeout);

    if ((RP_o_flit_format_status == 5'd3 || RP_o_fdi_pl_flit_fmt == 4'd3) &&
        (EP_o_flit_format_status == 5'd3 || EP_o_fdi_pl_flit_fmt == 4'd3))
      $display("FORMAT 3 selected on both RP and EP.");
    else
      $display("FORMAT CHECK WARNING: RP_status=%0d RP_fdi_fmt=%0d EP_status=%0d EP_fdi_fmt=%0d",
               RP_o_flit_format_status, RP_o_fdi_pl_flit_fmt,
               EP_o_flit_format_status, EP_o_fdi_pl_flit_fmt);
  endtask

  task send_lsm_state_msg(input sb_state_msg_encoding lsm_msg);
    logic [63:0] tx_lsm_msg;
    logic [63:0] expected_lsm_msg;

    RP_i_sb_state_msg_tx = lsm_msg;
    #(CLK_PERIOD);
    RP_i_sb_state_msg_tx = NONE;

    @(posedge RP_o_rdi_lp_cfg_vld);
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
 
    wait(EP_i_rdi_pl_cfg_vld); 
    repeat (3) @(posedge RP_i_clk);

    if ((EP_o_sb_state_msg_rx == lsm_msg))
      $display("LSM State Message RP -> EP PASSED. Msg=%0d Data=%h", lsm_msg, tx_lsm_msg);
    else
      $display("LSM State Message RP -> EP FAILED. ExpectedData=%h GotData=%h ExpectedMsg=%0d GotMsg=%0d",
               expected_lsm_msg, tx_lsm_msg, lsm_msg, EP_o_sb_state_msg_rx);
  endtask

  task send_lsm_state_msg_from_ep(input sb_state_msg_encoding lsm_msg);
    logic [63:0] tx_lsm_msg;
    logic [63:0] expected_lsm_msg;

    EP_i_sb_state_msg_tx = lsm_msg;
    #(CLK_PERIOD);
    EP_i_sb_state_msg_tx = NONE;

    @(posedge EP_o_rdi_lp_cfg_vld);
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
    wait(RP_i_rdi_pl_cfg_vld);

    repeat (3) @(posedge RP_i_clk);

    if ((RP_o_sb_state_msg_rx == lsm_msg))
      $display("LSM State Message EP -> RP PASSED. Msg=%0d Data=%h", lsm_msg, tx_lsm_msg);
    else
      $display("LSM State Message EP -> RP FAILED. ExpectedData=%h GotData=%h ExpectedMsg=%0d GotMsg=%0d",
               expected_lsm_msg, tx_lsm_msg, lsm_msg, RP_o_sb_state_msg_rx);
  endtask

  always_comb begin
    if (!RP_i_flit_fmt_status_set && RP_o_flit_format_status != 0) begin
      RP_i_flit_fmt_status = RP_o_flit_format_status;
      RP_i_flit_fmt_status_set = 1'b1;
    end else if (!RP_i_flit_fmt_status_set) begin
      RP_i_flit_fmt_status = 5'b0;
    end
  end

  always_comb begin
    if (!EP_i_flit_fmt_status_set && EP_o_flit_format_status != 0) begin
      EP_i_flit_fmt_status = EP_o_flit_format_status;
      EP_i_flit_fmt_status_set = 1'b1;
    end else if (!EP_i_flit_fmt_status_set) begin
      EP_i_flit_fmt_status = 5'b0;
    end
  end

  assign RP_i_retry_negotiated = RP_i_retry_needed & RP_o_sb_param_exch_done;
  assign EP_i_retry_negotiated = EP_i_retry_needed & EP_o_sb_param_exch_done;

endmodule