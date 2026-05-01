import UC_ALSM_package::*;
import UC_sb_pkg::*;
import UC_MB_Mainband_pkg::*;
import UC_regfile_package::*;

`include "../../src/rtl/common/UC_all_defs.svh"

module UC_TOP_tb;

  // Parameters

  //Ports
  logic i_clk;
  logic i_rst_n;
  logic i_init;
  logic [`P_NC-1:0] i_rdi_pl_cfg;
  logic i_rdi_pl_cfg_vld;
  logic i_rdi_pl_cfg_crd;
  logic [`P_NC-1:0] o_rdi_lp_cfg;
  logic o_rdi_lp_cfg_vld;
  logic o_rdi_lp_cfg_crd;
  logic i_rdi_pl_trdy;
  logic [DATA_PATH-1:0] o_rdi_lp_data;
  logic o_rdi_lp_valid;
  logic o_rdi_lp_irdy;
  logic [DATA_PATH-1:0] i_rdi_pl_data;
  logic i_rdi_pl_valid;
  logic i_rdi_pl_inband_pres;
  logic i_rdi_pl_phyinrecenter;
  logic [2:0] i_rdi_pl_speedmode;
  logic [2:0] i_rdi_pl_lnk_cfg;
  ll_state i_rdi_pl_state_sts;
  logic i_rdi_pl_clk_req;
  logic i_rdi_pl_wake_ack;
  logic i_rdi_pl_stall_req;
  logic i_rdi_pl_error;
  logic i_rdi_pl_trdy_alsm;
  logic o_rdi_lp_clk_ack;
  logic o_rdi_lp_wake_req;
  logic o_rdi_lp_linkerror;
  state_req o_rdi_lp_state_req;
  logic o_rdi_lp_stall_ack;
  logic i_rdi_pl_trainerror;
  logic i_rdi_pl_error_rf;
  logic i_rdi_pl_cerror;
  logic i_rdi_pl_nferror;
  logic [`P_NC-1:0] i_fdi_lp_cfg;
  logic i_fdi_lp_cfg_vld;
  logic i_fdi_lp_cfg_crd;
  logic [`P_NC-1:0] o_fdi_pl_cfg;
  logic o_fdi_pl_cfg_vld;
  logic o_fdi_pl_cfg_crd;
  logic [3:0] o_fdi_pl_protocol;
  logic [3:0] o_fdi_pl_flit_fmt;
  logic o_fdi_pl_valid;
  logic i_fdi_lp_irdy;
  logic i_fdi_lp_valid;
  logic [DATA_PATH-1:0] i_fdi_lp_data;
  logic [DLLP-1:0] i_fdi_lp_dllp;
  logic i_fdi_lp_dllp_valid;
  logic i_fdi_lp_dllp_ofc;
  logic [7:0] i_fdi_lp_stream;
  logic o_fdi_pl_trdy;
  logic [DATA_PATH-1:0] o_fdi_pl_data;
  logic [7:0] o_fdi_pl_stream;
  logic [DLLP-1:0] o_fdi_pl_dllp;
  logic o_fdi_pl_dllp_valid;
  logic o_fdi_pl_dllp_ofc;
  logic o_fdi_flit_cancel;
  state_req i_fdi_lp_state_req;
  logic i_fdi_lp_linkerror;
  logic i_fdi_lp_rx_active_sts;
  logic i_fdi_lp_stall_ack;
  logic i_fdi_lp_clk_ack;
  logic i_fdi_lp_wake_req;
  logic o_fdi_pl_stallreq;
  logic o_fdi_pl_phyinrecenter;
  logic o_fdi_pl_phyinl1;
  logic o_fdi_pl_phyinl2;
  logic [2:0] o_fdi_pl_speedmode;
  logic o_fdi_pl_max_speedmode;
  logic [2:0] o_fdi_pl_lnk_cfg;
  ll_state o_fdi_pl_state_sts;
  logic o_fdi_pl_inband_pres;
  logic o_fdi_pl_rx_active_req;
  logic o_fdi_pl_clk_req;
  logic o_fdi_pl_wake_ack;
  logic o_uncorrectable_error_IRQ;
  logic o_correctable_error_IRQ;
  logic o_fdi_pl_cerror;
  logic o_fdi_pl_nferror;
  logic o_fdi_pl_trainerror;

  UC_TOP  UC_TOP_inst (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_init(i_init),
    .i_rdi_pl_cfg(i_rdi_pl_cfg),
    .i_rdi_pl_cfg_vld(i_rdi_pl_cfg_vld),
    .i_rdi_pl_cfg_crd(i_rdi_pl_cfg_crd),
    .o_rdi_lp_cfg(o_rdi_lp_cfg),
    .o_rdi_lp_cfg_vld(o_rdi_lp_cfg_vld),
    .o_rdi_lp_cfg_crd(o_rdi_lp_cfg_crd),
    .i_rdi_pl_trdy(i_rdi_pl_trdy),
    .o_rdi_lp_data(o_rdi_lp_data),
    .o_rdi_lp_valid(o_rdi_lp_valid),
    .o_rdi_lp_irdy(o_rdi_lp_irdy),
    .i_rdi_pl_data(i_rdi_pl_data),
    .i_rdi_pl_valid(i_rdi_pl_valid),
    .i_rdi_pl_inband_pres(i_rdi_pl_inband_pres),
    .i_rdi_pl_phyinrecenter(i_rdi_pl_phyinrecenter),
    .i_rdi_pl_speedmode(i_rdi_pl_speedmode),
    .i_rdi_pl_lnk_cfg(i_rdi_pl_lnk_cfg),
    .i_rdi_pl_state_sts(i_rdi_pl_state_sts),
    .i_rdi_pl_clk_req(i_rdi_pl_clk_req),
    .i_rdi_pl_wake_ack(i_rdi_pl_wake_ack),
    .i_rdi_pl_stall_req(i_rdi_pl_stall_req),
    .i_rdi_pl_error(i_rdi_pl_error),
    .i_rdi_pl_trdy_alsm(i_rdi_pl_trdy_alsm),
    .o_rdi_lp_clk_ack(o_rdi_lp_clk_ack),
    .o_rdi_lp_wake_req(o_rdi_lp_wake_req),
    .o_rdi_lp_linkerror(o_rdi_lp_linkerror),
    .o_rdi_lp_state_req(o_rdi_lp_state_req),
    .o_rdi_lp_stall_ack(o_rdi_lp_stall_ack),
    .i_rdi_pl_trainerror(i_rdi_pl_trainerror),
    .i_rdi_pl_error_rf(i_rdi_pl_error_rf),
    .i_rdi_pl_cerror(i_rdi_pl_cerror),
    .i_rdi_pl_nferror(i_rdi_pl_nferror),
    .i_fdi_lp_cfg(i_fdi_lp_cfg),
    .i_fdi_lp_cfg_vld(i_fdi_lp_cfg_vld),
    .i_fdi_lp_cfg_crd(i_fdi_lp_cfg_crd),
    .o_fdi_pl_cfg(o_fdi_pl_cfg),
    .o_fdi_pl_cfg_vld(o_fdi_pl_cfg_vld),
    .o_fdi_pl_cfg_crd(o_fdi_pl_cfg_crd),
    .o_fdi_pl_protocol(o_fdi_pl_protocol),
    .o_fdi_pl_flit_fmt(o_fdi_pl_flit_fmt),
    .o_fdi_pl_valid(o_fdi_pl_valid),
    .i_fdi_lp_irdy(i_fdi_lp_irdy),
    .i_fdi_lp_valid(i_fdi_lp_valid),
    .i_fdi_lp_data(i_fdi_lp_data),
    .i_fdi_lp_dllp(i_fdi_lp_dllp),
    .i_fdi_lp_dllp_valid(i_fdi_lp_dllp_valid),
    .i_fdi_lp_dllp_ofc(i_fdi_lp_dllp_ofc),
    .i_fdi_lp_stream(i_fdi_lp_stream),
    .o_fdi_pl_trdy(o_fdi_pl_trdy),
    .o_fdi_pl_data(o_fdi_pl_data),
    .o_fdi_pl_stream(o_fdi_pl_stream),
    .o_fdi_pl_dllp(o_fdi_pl_dllp),
    .o_fdi_pl_dllp_valid(o_fdi_pl_dllp_valid),
    .o_fdi_pl_dllp_ofc(o_fdi_pl_dllp_ofc),
    .o_fdi_flit_cancel(o_fdi_flit_cancel),
    .i_fdi_lp_state_req(i_fdi_lp_state_req),
    .i_fdi_lp_linkerror(i_fdi_lp_linkerror),
    .i_fdi_lp_rx_active_sts(i_fdi_lp_rx_active_sts),
    .i_fdi_lp_stall_ack(i_fdi_lp_stall_ack),
    .i_fdi_lp_clk_ack(i_fdi_lp_clk_ack),
    .i_fdi_lp_wake_req(i_fdi_lp_wake_req),
    .o_fdi_pl_stallreq(o_fdi_pl_stallreq),
    .o_fdi_pl_phyinrecenter(o_fdi_pl_phyinrecenter),
    .o_fdi_pl_phyinl1(o_fdi_pl_phyinl1),
    .o_fdi_pl_phyinl2(o_fdi_pl_phyinl2),
    .o_fdi_pl_speedmode(o_fdi_pl_speedmode),
    .o_fdi_pl_max_speedmode(o_fdi_pl_max_speedmode),
    .o_fdi_pl_lnk_cfg(o_fdi_pl_lnk_cfg),
    .o_fdi_pl_state_sts(o_fdi_pl_state_sts),
    .o_fdi_pl_inband_pres(o_fdi_pl_inband_pres),
    .o_fdi_pl_rx_active_req(o_fdi_pl_rx_active_req),
    .o_fdi_pl_clk_req(o_fdi_pl_clk_req),
    .o_fdi_pl_wake_ack(o_fdi_pl_wake_ack),
    .o_fdi_pl_cerror(o_fdi_pl_cerror),
    .o_fdi_pl_nferror(o_fdi_pl_nferror),
    .o_fdi_pl_trainerror(o_fdi_pl_trainerror),
    .o_uncorrectable_error_IRQ(o_uncorrectable_error_IRQ),
    .o_correctable_error_IRQ(o_correctable_error_IRQ)
  );

localparam CLK_PERIOD = 10;
initial begin
  i_clk = '0;
  forever begin
    #(CLK_PERIOD/2);
    i_clk = ~i_clk;
  end
end

initial begin
  reset_values();
  @(negedge i_clk);
  @(negedge i_clk);
  @(negedge i_clk);
  $stop();
  $finish();
end

task reset_values();
  i_rst_n = '0;
  i_init = '0;
  i_rdi_pl_cfg = '0;
  i_rdi_pl_cfg_vld = '0;
  i_rdi_pl_cfg_crd = '0;
  i_rdi_pl_trdy = '0;
  i_rdi_pl_data = '0;
  i_rdi_pl_valid = '0;
  i_rdi_pl_inband_pres = '0;
  i_rdi_pl_phyinrecenter = '0;
  i_rdi_pl_speedmode = '0;
  i_rdi_pl_lnk_cfg = '0;
  i_rdi_pl_state_sts = LL_Reset;
  i_rdi_pl_clk_req = '0;
  i_rdi_pl_wake_ack = '0;
  i_rdi_pl_stall_req = '0;
  i_rdi_pl_error = '0;
  i_rdi_pl_trdy_alsm = '0;
  i_rdi_pl_trainerror = '0;
  i_rdi_pl_error_rf = '0;
  i_rdi_pl_cerror = '0;
  i_rdi_pl_nferror = '0;
  i_fdi_lp_cfg = '0;
  i_fdi_lp_cfg_vld = '0;
  i_fdi_lp_cfg_crd = '0;
  i_fdi_lp_irdy = '0;
  i_fdi_lp_valid = '0;
  i_fdi_lp_data = '0;
  i_fdi_lp_dllp = '0;
  i_fdi_lp_dllp_valid = '0;
  i_fdi_lp_dllp_ofc = '0;
  i_fdi_lp_stream = '0;
  i_fdi_lp_state_req = Req_NOP;
  i_fdi_lp_linkerror = '0;
  i_fdi_lp_rx_active_sts = '0;
  i_fdi_lp_stall_ack = '0;
  i_fdi_lp_clk_ack = '0;
  i_fdi_lp_wake_req = '0;

  @(negedge i_clk);
  @(negedge i_clk);
  i_rst_n = 'b1;
  i_init  = 'b1;
endtask
endmodule