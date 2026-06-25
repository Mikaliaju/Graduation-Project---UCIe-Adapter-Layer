import UC_MB_Mainband_pkg::*;
module UC_MB_Top_tb;

  //Ports
  logic i_clk;
  logic i_rst_n;
  logic i_init;

  logic i_fdi_active_UP;
  data_rate_t i_data_rate_UP;
  logic i_lp_irdy_fdi_UP;
  logic i_lp_valid_fdi_UP;
  logic [DATA_PATH-1:0] i_lp_data_fdi_UP;
  logic [DLLP-1:0] i_lp_dllp_UP;
  logic i_lp_dllp_valid_UP;
  logic i_lp_dllp_ofc_UP;
  logic [7:0] i_lp_stream_UP;
  logic i_pl_trdy_UP;
  logic i_packer_en_UP;
  logic i_flit_boundary_UP;
  logic i_flush_UP;
  logic i_drain_UP;
  logic i_unpacker_en_UP;
  logic i_stop_stream_UP;

  logic o_log_uie_UP;
  logic o_log_cie_UP;
  logic o_rdi_retrain_UP;
  logic o_pl_trdy_fdi_UP;
  logic [DATA_PATH-1:0] o_pl_data_fdi_UP;
  logic o_pl_valid_fdi_UP;
  logic [7:0] o_pl_stream_UP;
  logic [DLLP-1:0] o_pl_dllp_UP;
  logic o_pl_dllp_valid_UP;
  logic o_pl_dllp_ofc_UP;
  logic o_flit_cancel_UP;
  logic o_flit_boundary_done_UP;
  logic o_flush_done_UP;
  logic o_drain_done_UP;

  logic [DATA_PATH-1:0] o_lp_data_rdi_UP;
  logic o_lp_valid_rdi_UP;
  logic o_lp_irdy_rdi_UP;

  logic i_fdi_active_DP;
  data_rate_t i_data_rate_DP;
  logic o_log_uie_DP;
  logic o_log_cie_DP;
  logic o_rdi_retrain_DP;
  logic i_lp_irdy_fdi_DP;
  logic i_lp_valid_fdi_DP;
  logic [DATA_PATH-1:0] i_lp_data_fdi_DP;
  logic [DLLP-1:0] i_lp_dllp_DP;
  logic i_lp_dllp_valid_DP;
  logic i_lp_dllp_ofc_DP;
  logic [7:0] i_lp_stream_DP;
  logic o_pl_trdy_fdi_DP;
  logic [DATA_PATH-1:0] o_pl_data_fdi_DP;
  logic o_pl_valid_fdi_DP;
  logic [7:0] o_pl_stream_DP;
  logic [DLLP-1:0] o_pl_dllp_DP;
  logic o_pl_dllp_valid_DP;
  logic o_pl_dllp_ofc_DP;
  logic o_flit_cancel_DP;
  logic i_pl_trdy_DP;
  logic i_packer_en_DP;
  logic i_flit_boundary_DP;
  logic i_flush_DP;
  logic i_drain_DP;
  logic o_flit_boundary_done_DP;
  logic o_flush_done_DP;
  logic o_drain_done_DP;
  logic i_unpacker_en_DP;
  logic i_stop_stream_DP;

  logic [DATA_PATH-1:0] o_lp_data_rdi_DP;
  logic o_lp_valid_rdi_DP;
  logic o_lp_irdy_rdi_DP;

  UC_MB_Mainband  UC_MB_Mainband_inst_UP (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_init(i_init),

    .i_fdi_active(i_fdi_active_UP),
    .i_data_rate(i_data_rate_UP),
    .o_log_uie(o_log_uie_UP),
    .o_log_cie(o_log_cie_UP),
    .o_rdi_retrain(o_rdi_retrain_UP),
    .i_lp_irdy_fdi(i_lp_irdy_fdi_UP),
    .i_lp_valid_fdi(i_lp_valid_fdi_UP),
    .i_lp_data_fdi(i_lp_data_fdi_UP),
    .i_lp_dllp(i_lp_dllp_UP),
    .i_lp_dllp_valid(i_lp_dllp_valid_UP),
    .i_lp_dllp_ofc(i_lp_dllp_ofc_UP),
    .i_lp_stream(i_lp_stream_UP),
    .o_pl_trdy_fdi(o_pl_trdy_fdi_UP),
    .o_pl_data_fdi(o_pl_data_fdi_UP),
    .o_pl_valid_fdi(o_pl_valid_fdi_UP),
    .o_pl_stream(o_pl_stream_UP),
    .o_pl_dllp(o_pl_dllp_UP),
    .o_pl_dllp_valid(o_pl_dllp_valid_UP),
    .o_pl_dllp_ofc(o_pl_dllp_ofc_UP),
    .o_flit_cancel(o_flit_cancel_UP),
    .i_pl_trdy(i_pl_trdy_UP),
    .i_packer_en(i_packer_en_UP),
    .i_flit_boundary(i_flit_boundary_UP),
    .i_flush(i_flush_UP),
    .i_drain(i_drain_UP),
    .o_flit_boundary_done(o_flit_boundary_done_UP),
    .o_flush_done(o_flush_done_UP),
    .o_drain_done(o_drain_done_UP),
    .i_unpacker_en(i_unpacker_en_UP),
    .i_stop_stream(i_stop_stream_UP),

    .o_lp_data_rdi(o_lp_data_rdi_UP),
    .o_lp_valid_rdi(o_lp_valid_rdi_UP),
    .o_lp_irdy_rdi(o_lp_irdy_rdi_UP),
    .i_pl_data_rdi(o_lp_data_rdi_DP),
    .i_pl_valid_rdi(o_lp_valid_rdi_DP)
  );

  UC_MB_Mainband  UC_MB_Mainband_inst_DP (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_init(i_init),

    .i_fdi_active(i_fdi_active_DP),
    .i_data_rate(i_data_rate_DP),
    .o_log_uie(o_log_uie_DP),
    .o_log_cie(o_log_cie_DP),
    .o_rdi_retrain(o_rdi_retrain_DP),
    .i_lp_irdy_fdi(i_lp_irdy_fdi_DP),
    .i_lp_valid_fdi(i_lp_valid_fdi_DP),
    .i_lp_data_fdi(i_lp_data_fdi_DP),
    .i_lp_dllp(i_lp_dllp_DP),
    .i_lp_dllp_valid(i_lp_dllp_valid_DP),
    .i_lp_dllp_ofc(i_lp_dllp_ofc_DP),
    .i_lp_stream(i_lp_stream_DP),
    .o_pl_trdy_fdi(o_pl_trdy_fdi_DP),
    .o_pl_data_fdi(o_pl_data_fdi_DP),
    .o_pl_valid_fdi(o_pl_valid_fdi_DP),
    .o_pl_stream(o_pl_stream_DP),
    .o_pl_dllp(o_pl_dllp_DP),
    .o_pl_dllp_valid(o_pl_dllp_valid_DP),
    .o_pl_dllp_ofc(o_pl_dllp_ofc_DP),
    .o_flit_cancel(o_flit_cancel_DP),
    .i_pl_trdy(i_pl_trdy_DP),
    .i_packer_en(i_packer_en_DP),
    .i_flit_boundary(i_flit_boundary_DP),
    .i_flush(i_flush_DP),
    .i_drain(i_drain_DP),
    .o_flit_boundary_done(o_flit_boundary_done_DP),
    .o_flush_done(o_flush_done_DP),
    .o_drain_done(o_drain_done_DP),
    .i_unpacker_en(i_unpacker_en_DP),
    .i_stop_stream(i_stop_stream_DP),

    .o_lp_data_rdi(o_lp_data_rdi_DP),
    .o_lp_valid_rdi(o_lp_valid_rdi_DP),
    .o_lp_irdy_rdi(o_lp_irdy_rdi_DP),
    .i_pl_data_rdi(o_lp_data_rdi_UP),
    .i_pl_valid_rdi(o_lp_valid_rdi_UP)
  );

initial begin
  i_clk = '0;
  forever begin
    #5
    i_clk = ~i_clk;
  end
end

initial begin : main_initial_block
  reset_values();
  repeat(10) begin
    @(negedge i_clk);
  end
  $stop;
  $finish;
end

task reset_values();
  i_rst_n = '0;
  i_init  = '0;
  i_fdi_active_UP = '0;
  i_data_rate_UP = GTs_32;
  i_lp_irdy_fdi_UP = '0;
  i_lp_valid_fdi_UP = '0;
  i_lp_data_fdi_UP = '0;
  i_lp_dllp_UP = '0;
  i_lp_dllp_valid_UP = '0;
  i_lp_dllp_ofc_UP = '0;
  i_lp_stream_UP = '0;
  i_pl_trdy_UP = '0;
  i_packer_en_UP = '0;
  i_flit_boundary_UP = '0;
  i_flush_UP = '0;
  i_drain_UP = '0;
  i_unpacker_en_UP = '0;
  i_stop_stream_UP = '0;

  i_fdi_active_DP = '0;
  i_data_rate_DP = GTs_32;
  i_lp_irdy_fdi_DP = '0;
  i_lp_valid_fdi_DP = '0;
  i_lp_data_fdi_DP = '0;
  i_lp_dllp_DP = '0;
  i_lp_dllp_valid_DP = '0;
  i_lp_dllp_ofc_DP = '0;
  i_lp_stream_DP = '0;
  i_pl_trdy_DP = '0;
  i_packer_en_DP = '0;
  i_flit_boundary_DP = '0;
  i_flush_DP = '0;
  i_drain_DP = '0;
  i_unpacker_en_DP = '0;
  i_stop_stream_DP = '0;

  @(negedge i_clk);
  @(negedge i_clk);
  i_rst_n = '1;
  i_init  = '1;
endtask

endmodule