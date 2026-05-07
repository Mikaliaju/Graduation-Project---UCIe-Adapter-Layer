import UC_ALSM_package::*;
import UC_sb_rx_pkg::*;

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

module UC_regfile_tb;

  // Parameters

  //Ports
  logic i_init;
  logic i_clk;
  logic i_rst_n;
  logic i_fdi_lp_linkerror;
  logic i_rdi_pl_trainerror;
  logic i_rdi_pl_error;
  logic i_rdi_pl_cerror;
  logic i_rdi_pl_nferror;
  logic i_rdi_pl_phyinrecenter;
  logic [2:0] i_rdi_pl_speedmode;
  logic [2:0] i_rdi_pl_lnk_cfg;
  Adapter_Response i_adpater_lsm_response_type;
  logic i_link_status;
  logic i_ce_adapter_transition_retrain;
  logic i_ALSM_start_param_exch;
  logic i_MB_Receiver_Overflow;
  logic i_MB_CRC_Error_Detected;
  logic i_MB_Correctable_Internal_Error;
  logic [31:0] i_sb_mailbox_data_low;
  logic [31:0] i_sb_mailbox_data_high;
  logic [1:0] i_sb_mailbox_status;
  logic i_sb_mailbox_trigger_en;
  logic [63:0] i_sb_Header_log1;
  logic i_sb_Header_log1_valid;
  logic [63:0] i_sb_adapter_advcap;
  logic i_sb_adapter_advcap_valid;
  logic [63:0] i_sb_cxl_advcap;
  logic i_sb_cxl_advcap_valid;
  logic [63:0] i_sb_adapter_fincap;
  logic i_sb_adapter_fincap_valid;
  logic [63:0] i_sb_cxl_fincap;
  logic i_sb_cxl_fincap_valid;
  logic [4:0] i_sb_flit_format_status;
  logic i_sb_flitfmt_valid;
  logic [63:0] i_sb_write_data;
  logic i_sb_write_en;
  logic [7:0] i_sb_BE;
  logic [23:0] i_sb_address;
  logic i_sb_config_req;
  logic i_sb_32_B;
  logic i_sb_invalid_param_exch;
  logic i_sb_local_timeout;
  logic i_sb_remote_timeout;
  logic i_sb_fdi_overflow;
  logic i_sb_rdi_overflow;
  logic i_sb_parity_error;
  logic i_sb_param_exch_timeout;
  logic i_sb_invalid_opcode_id;
  logic i_sb_param_exch_done;
  sb_error_msg_encoding i_sb_in_error_msg_encoding;
  logic [31:0] i_sw_mailbox_data_low;
  logic [31:0] i_sw_mailbox_data_high;
  logic [1:0] i_sw_mailbox_status;
  logic i_sw_mailbox_trigger_en;
  logic o_sb_format4_enabled;
  logic o_sb_format6_enabled;
  logic o_sw_mailbox_trigger;
  logic [31:0] o_sw_mailbox_index_low;
  logic [4:0] o_sw_mailbox_index_high;
  logic [31:0] o_sw_mailbox_data_low;
  logic [31:0] o_sw_mailbox_data_high;
  logic o_uncorrectable_error_IRQ;
  logic o_correctable_error_IRQ;
  logic o_sb_mailbox_trigger;
  logic [31:0] o_sb_mailbox_index_low;
  logic [4:0] o_sb_mailbox_index_high;
  logic [31:0] o_sb_mailbox_data_low;
  logic [31:0] o_sb_mailbox_data_high;
  logic [3:0] o_sb_remote_threshold;
  logic [63:0] o_sb_adapter_advcap;
  logic [63:0] o_sb_cxl_advcap;
  logic [4:0] o_sb_flit_fmt_status;
  logic [2:0] o_sb_status;
  logic [63:0] o_sb_read_data;
  logic o_linkerror;
  logic o_start_retrain;
  logic o_fdi_pl_cerror;
  logic o_fdi_pl_nferror;
  logic o_fdi_pl_trainerror;
  sb_error_msg_encoding o_sb_out_error_msg_encoding;

  UC_regfile  UC_regfile_inst (
    .i_init(i_init),
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_fdi_lp_linkerror(i_fdi_lp_linkerror),
    .o_fdi_pl_cerror(o_fdi_pl_cerror),
    .o_fdi_pl_nferror(o_fdi_pl_nferror),
    .o_fdi_pl_trainerror(o_fdi_pl_trainerror),
    .i_rdi_pl_trainerror(i_rdi_pl_trainerror),
    .i_rdi_pl_error(i_rdi_pl_error),
    .i_rdi_pl_cerror(i_rdi_pl_cerror),
    .i_rdi_pl_nferror(i_rdi_pl_nferror),
    .i_rdi_pl_phyinrecenter(i_rdi_pl_phyinrecenter),
    .i_rdi_pl_speedmode(i_rdi_pl_speedmode),
    .i_rdi_pl_lnk_cfg(i_rdi_pl_lnk_cfg),
    .i_adpater_lsm_response_type(i_adpater_lsm_response_type),
    .i_link_status(i_link_status),
    .i_ce_adapter_transition_retrain(i_ce_adapter_transition_retrain),
    .i_ALSM_start_param_exch(i_ALSM_start_param_exch),
    .o_linkerror(o_linkerror),
    .o_start_retrain(o_start_retrain),
    .i_MB_Receiver_Overflow(i_MB_Receiver_Overflow),
    .i_MB_CRC_Error_Detected(i_MB_CRC_Error_Detected),
    .i_MB_Correctable_Internal_Error(i_MB_Correctable_Internal_Error),
    .i_sb_mailbox_data_low(i_sb_mailbox_data_low),
    .i_sb_mailbox_data_high(i_sb_mailbox_data_high),
    .i_sb_mailbox_status(i_sb_mailbox_status),
    .i_sb_mailbox_trigger_en(i_sb_mailbox_trigger_en),
    .i_sb_Header_log1(i_sb_Header_log1),
    .i_sb_Header_log1_valid(i_sb_Header_log1_valid),
    .i_sb_adapter_advcap(i_sb_adapter_advcap),
    .i_sb_adapter_advcap_valid(i_sb_adapter_advcap_valid),
    .i_sb_cxl_advcap(i_sb_cxl_advcap),
    .i_sb_cxl_advcap_valid(i_sb_cxl_advcap_valid),
    .i_sb_adapter_fincap(i_sb_adapter_fincap),
    .i_sb_adapter_fincap_valid(i_sb_adapter_fincap_valid),
    .i_sb_cxl_fincap(i_sb_cxl_fincap),
    .i_sb_cxl_fincap_valid(i_sb_cxl_fincap_valid),
    .i_sb_flit_format_status(i_sb_flit_format_status),
    .i_sb_flitfmt_valid(i_sb_flitfmt_valid),
    .i_sb_write_data(i_sb_write_data),
    .i_sb_write_en(i_sb_write_en),
    .i_sb_BE(i_sb_BE),
    .i_sb_address(i_sb_address),
    .i_sb_config_req(i_sb_config_req),
    .i_sb_32_B(i_sb_32_B),
    .i_sb_invalid_param_exch(i_sb_invalid_param_exch),
    .i_sb_local_timeout(i_sb_local_timeout),
    .i_sb_remote_timeout(i_sb_remote_timeout),
    .i_sb_fdi_overflow(i_sb_fdi_overflow),
    .i_sb_rdi_overflow(i_sb_rdi_overflow),
    .i_sb_parity_error(i_sb_parity_error),
    .i_sb_param_exch_timeout(i_sb_param_exch_timeout),
    .i_sb_invalid_opcode_id(i_sb_invalid_opcode_id),
    .i_sb_param_exch_done(i_sb_param_exch_done),
    .i_sb_in_error_msg_encoding(i_sb_in_error_msg_encoding),
    .o_sb_mailbox_trigger(o_sb_mailbox_trigger),
    .o_sb_mailbox_index_low(o_sb_mailbox_index_low),
    .o_sb_mailbox_index_high(o_sb_mailbox_index_high),
    .o_sb_mailbox_data_low(o_sb_mailbox_data_low),
    .o_sb_mailbox_data_high(o_sb_mailbox_data_high),
    .o_sb_remote_threshold(o_sb_remote_threshold),
    .o_sb_adapter_advcap(o_sb_adapter_advcap),
    .o_sb_cxl_advcap(o_sb_cxl_advcap),
    .o_sb_flit_fmt_status(o_sb_flit_fmt_status),
    .o_sb_status(o_sb_status),
    .o_sb_read_data(o_sb_read_data),
    .o_sb_out_error_msg_encoding(o_sb_out_error_msg_encoding),
    .o_sb_format4_enabled(o_sb_format4_enabled),
    .o_sb_format6_enabled(o_sb_format6_enabled),
    // .i_sw_mailbox_data_low(i_sw_mailbox_data_low),
    // .i_sw_mailbox_data_high(i_sw_mailbox_data_high),
    // .i_sw_mailbox_status(i_sw_mailbox_status),
    // .i_sw_mailbox_trigger_en(i_sw_mailbox_trigger_en),
    // .o_sw_mailbox_trigger(o_sw_mailbox_trigger),
    // .o_sw_mailbox_index_low(o_sw_mailbox_index_low),
    // .o_sw_mailbox_index_high(o_sw_mailbox_index_high),
    // .o_sw_mailbox_data_low(o_sw_mailbox_data_low),
    // .o_sw_mailbox_data_high(o_sw_mailbox_data_high),
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
  mem_read_test();
  config_read_test();
  mem_write_test();
  // mailbox_test();
  $stop;
  $finish;
end

// task mailbox_test();
//   assert(~o_sw_mailbox_trigger);
//   i_sw_mailbox_data_high  = 'hFF;
//   i_sw_mailbox_data_low   = 'hAA;
//   i_sw_mailbox_trigger_en = 'b1;
//   @(negedge i_clk);
//   assert(o_sw_mailbox_trigger);
//   i_sw_mailbox_data_high  = 'hBB;
//   i_sw_mailbox_data_low   = 'hCC;
//   i_sw_mailbox_trigger_en = 'b0;
//   @(negedge i_clk);
//   assert(o_sb_mailbox_trigger);
//   assert(o_sb_mailbox_data_high == 'hFF);
//   assert(o_sb_mailbox_data_low  == 'hAA);
//   i_sb_mailbox_trigger_en = 'b1;
//   @(negedge i_clk);
//   i_sb_mailbox_trigger_en = 'b0;
//   @(negedge i_clk);
//   assert(o_sb_mailbox_trigger);
// endtask

task mem_read_test();
  i_sb_BE         = 'b10101010;
  i_sb_32_B       = 'b0;
  i_sb_config_req = 'b0;
  i_sb_address    = 'd20;
  @(negedge i_clk);
  $display("o_sb_read_data = 0x%16h", o_sb_read_data);
  assert (o_sb_read_data == 'hff00ff00ff00ff00);
  i_sb_BE         = 'hFF;
  i_sb_32_B       = 'b0;
  i_sb_config_req = 'b0;
  i_sb_address    = 'd26;
  @(negedge i_clk);
  $display("o_sb_read_data = 0x%16h", o_sb_read_data);
  assert (o_sb_read_data == 'hffff00000000ffff);
  i_sb_BE         = 'hFF;
  i_sb_32_B       = 'b1;
  i_sb_config_req = 'b0;
  i_sb_address    = 'd26;
  @(negedge i_clk);
  $display("o_sb_read_data = 0x%16h", o_sb_read_data);
  assert (o_sb_read_data == 'h000000000000ffff);
  @(negedge i_clk);
endtask

task config_read_test();
  i_sb_BE         = 'hFF;
  i_sb_32_B       = 'b0;
  i_sb_config_req = 'b1;
  i_sb_address    = 'd0;
  @(negedge i_clk);
  $display("o_sb_read_data = 0x%16h", o_sb_read_data);
  assert (o_sb_read_data == 'h10023);
  i_sb_BE         = 'hFF;
  i_sb_32_B       = 'b0;
  i_sb_config_req = 'b1;
  i_sb_address    = 'd10;
  @(negedge i_clk);
  $display("o_sb_read_data = 0x%16h", o_sb_read_data);
  assert (o_sb_read_data == 'h20000000f);
  i_sb_BE         = 'hFF;
  i_sb_32_B       = 'b1;
  i_sb_config_req = 'b1;
  i_sb_address    = 'd10;
  @(negedge i_clk);
  $display("o_sb_read_data = 0x%16h", o_sb_read_data);
  assert (o_sb_read_data == 'hf);
  i_sb_BE         = 'b00010000;
  i_sb_32_B       = 'b0;
  i_sb_config_req = 'b1;
  i_sb_address    = 'd10;
  @(negedge i_clk);
  $display("o_sb_read_data = 0x%16h", o_sb_read_data);
  assert (o_sb_read_data == 'h200000000);
  @(negedge i_clk);
endtask

task mem_write_test();
  i_sb_BE         = 'hFF;
  i_sb_32_B       = 'b0;
  i_sb_config_req = 'b0;
  i_sb_address    = 32*4;
  i_sb_write_en   = 'b1;
  i_sb_write_data = {4{16'hABCD}};
  @(negedge i_clk);
  @(negedge i_clk);
  $display("o_sb_read_data = 0x%16h", o_sb_read_data);
  assert (o_sb_read_data == {4{16'hABCD}});
  i_sb_BE         = 'hF0;
  i_sb_32_B       = 'b0;
  i_sb_config_req = 'b0;
  i_sb_address    =  32*4;
  i_sb_write_en   = 'b1;
  i_sb_write_data = {4{16'hFFFF}};
  @(negedge i_clk);
  i_sb_BE         = 'hFF;
  i_sb_32_B       = 'b0;
  i_sb_config_req = 'b0;
  i_sb_address    =  32*4;
  i_sb_write_en   = 'b0; // don't write any more data
  i_sb_write_data = 'b0;
  @(negedge i_clk);
  $display("o_sb_read_data = 0x%16h", o_sb_read_data);
  assert (o_sb_read_data == 'hFFFFFFFFABCDABCD);
  i_sb_BE         = 'b01010101;
  i_sb_32_B       = 'b0;
  i_sb_config_req = 'b0;
  i_sb_address    =  32*4;
  i_sb_write_en   = 'b1;
  i_sb_write_data = 'b0;
  @(negedge i_clk);
  i_sb_BE         = 'hFF;
  i_sb_write_en   = 'b0;
  @(negedge i_clk);
  $display("o_sb_read_data = 0x%16h", o_sb_read_data);
  assert (o_sb_read_data == 'hFF00FF00AB00AB00);
  i_sb_BE         = 'b10101010;
  i_sb_32_B       = 'b0;
  i_sb_config_req = 'b0;
  i_sb_address    =  32*4;
  i_sb_write_en   = 'b1;
  i_sb_write_data = {8{8'hCD}};
  @(negedge i_clk);
  i_sb_BE         = 'hFF;
  i_sb_write_en   = 'b0;
  @(negedge i_clk);
  $display("o_sb_read_data = 0x%16h", o_sb_read_data);
  assert (o_sb_read_data == 'hCD00CD00CD00CD00);
  i_sb_BE         = 'hFF;
  i_sb_32_B       = 'b1;
  i_sb_config_req = 'b0;
  i_sb_address    =  32*4 + 2;
  i_sb_write_en   = 'b1;
  i_sb_write_data = {{2{16'hFFFF}}, {2{16'hABCD}}};
  @(negedge i_clk);
  i_sb_BE         = 'hFF;
  i_sb_write_en   = 'b0;
  @(negedge i_clk);
  $display("o_sb_read_data = 0x%16h", o_sb_read_data);
  assert (o_sb_read_data == 'hABCDABCD);
  i_sb_BE         = 'hFF;
  i_sb_32_B       = 'b0;
  i_sb_config_req = 'b0;
  i_sb_address    =  32*4;
  i_sb_write_en   = 'b1;
  i_sb_write_data = 'b0;
  @(negedge i_clk);
  i_sb_BE         = 'hFF;
  i_sb_write_en   = 'b0;
  @(negedge i_clk);
  $display("o_sb_read_data = 0x%16h", o_sb_read_data);
  assert (o_sb_read_data == 'h0);
endtask

task reset_values();
  i_rst_n = '0;
  i_init = '0;
  i_fdi_lp_linkerror = '0;
  i_rdi_pl_trainerror = '0;
  i_rdi_pl_error = '0;
  i_rdi_pl_cerror = '0;
  i_rdi_pl_nferror = '0;
  i_rdi_pl_phyinrecenter = '0;
  i_rdi_pl_speedmode = '0;
  i_rdi_pl_lnk_cfg = '0;
  i_adpater_lsm_response_type = Active_LSM_response_type;
  i_link_status = '0;
  i_ce_adapter_transition_retrain = '0;
  i_ALSM_start_param_exch = '0;
  i_MB_Receiver_Overflow = '0;
  i_MB_CRC_Error_Detected = '0;
  i_MB_Correctable_Internal_Error = '0;
  i_sb_mailbox_data_low = '0;
  i_sb_mailbox_data_high = '0;
  i_sb_mailbox_status = '0;
  i_sb_mailbox_trigger_en = '0;
  i_sb_Header_log1 = '0;
  i_sb_Header_log1_valid = '0;
  i_sb_adapter_advcap = '0;
  i_sb_adapter_advcap_valid = '0;
  i_sb_cxl_advcap = '0;
  i_sb_cxl_advcap_valid = '0;
  i_sb_adapter_fincap = '0;
  i_sb_adapter_fincap_valid = '0;
  i_sb_cxl_fincap = '0;
  i_sb_cxl_fincap_valid = '0;
  i_sb_flit_format_status = '0;
  i_sb_flitfmt_valid = '0;
  i_sb_write_data = '0;
  i_sb_write_en = '0;
  i_sb_BE = '0;
  i_sb_address = '0;
  i_sb_config_req = '0;
  i_sb_32_B = '0;
  i_sb_invalid_param_exch = '0;
  i_sb_local_timeout = '0;
  i_sb_remote_timeout = '0;
  i_sb_fdi_overflow = '0;
  i_sb_rdi_overflow = '0;
  i_sb_parity_error = '0;
  i_sb_param_exch_timeout = '0;
  i_sb_invalid_opcode_id = '0;
  i_sb_param_exch_done = '0;
  i_sb_in_error_msg_encoding = NONE_ERR;
  // i_sw_mailbox_data_low = '0;
  // i_sw_mailbox_data_high = '0;
  // i_sw_mailbox_status = '0;
  // i_sw_mailbox_trigger_en = '0;
  @(negedge i_clk);
  i_rst_n = '1;
  i_init = '1;
  @(negedge i_clk);
endtask
endmodule