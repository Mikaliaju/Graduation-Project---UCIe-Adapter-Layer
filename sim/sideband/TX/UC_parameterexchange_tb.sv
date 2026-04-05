`timescale 1ns/1ps

module UC_parameterexchange_tb;

  // =========================================================
  // Parameters
  // =========================================================
  localparam int TIMEOUT_WAIT = 140;

  // =========================================================
  // DUT I/O
  // =========================================================
  logic               i_clk;
  logic               i_rstn;
  logic               i_init_n;

  logic  [63:0]       i_adapter_advcap;
  logic  [63:0]       i_cxl_advcap;
  logic               i_format4_enabled;
  logic               i_format6_enabled;
  logic               i_retry_needed;

  logic  [127:0]      i_rx_msg_with_data;
  logic               i_rx_msg_valid;

  logic  [127:0]      o_tx_msg_with_data;
  logic               o_tx_msg_valid;

  logic  [63:0]       o_adapter_advcap;
  logic  [63:0]       o_adapter_fincap;
  logic  [63:0]       o_cxl_advcap;
  logic  [63:0]       o_cxl_fincap;
  logic               o_adapter_advcap_valid;
  logic               o_adapter_fincap_valid;
  logic               o_cxl_advcap_valid;
  logic               o_cxl_fincap_valid;

  logic  [4:0]        i_flit_fmt_status;
  logic  [4:0]        o_flit_fromat_status;
  logic               o_flitfmt_valid;

  logic               i_start_PE;
  logic               o_PE_done;
  logic               o_invalid_param_exch;
  logic               o_param_exchange_timeout;
  logic               o_retry_negotiated;
  logic               i_retry_negotiated;

  logic  [3:0]        o_pl_protocol;
  logic  [3:0]        o_pl_flit_fmt;
  logic               o_pl_valid;

  // =========================================================
  // DUT
  // RP mode => compile WITHOUT +define+END_POINT
  // =========================================================
  UC_parameterexchange dut (
    .i_clk                    (i_clk),
    .i_rstn                   (i_rstn),
    .i_init_n                 (i_init_n),
    .i_adapter_advcap         (i_adapter_advcap),
    .i_cxl_advcap             (i_cxl_advcap),
    .i_format4_enabled        (i_format4_enabled),
    .i_format6_enabled        (i_format6_enabled),
    .i_retry_needed           (i_retry_needed),
    .i_rx_msg_with_data       (i_rx_msg_with_data),
    .i_rx_msg_valid           (i_rx_msg_valid),
    .o_tx_msg_with_data       (o_tx_msg_with_data),
    .o_tx_msg_valid           (o_tx_msg_valid),
    .o_adapter_advcap         (o_adapter_advcap),
    .o_adapter_fincap         (o_adapter_fincap),
    .o_cxl_advcap             (o_cxl_advcap),
    .o_cxl_fincap             (o_cxl_fincap),
    .o_adapter_advcap_valid   (o_adapter_advcap_valid),
    .o_adapter_fincap_valid   (o_adapter_fincap_valid),
    .o_cxl_advcap_valid       (o_cxl_advcap_valid),
    .o_cxl_fincap_valid       (o_cxl_fincap_valid),
    .i_flit_fmt_status        (i_flit_fmt_status),
    .o_flit_fromat_status     (o_flit_fromat_status),
    .o_flitfmt_valid          (o_flitfmt_valid),
    .i_start_PE               (i_start_PE),
    .o_PE_done                (o_PE_done),
    .o_invalid_param_exch     (o_invalid_param_exch),
    .o_param_exchange_timeout (o_param_exchange_timeout),
    .o_retry_negotiated       (o_retry_negotiated),
    .i_retry_negotiated       (i_retry_negotiated),
    .o_pl_protocol            (o_pl_protocol),
    .o_pl_flit_fmt            (o_pl_flit_fmt),
    .o_pl_valid               (o_pl_valid)
  );

  // =========================================================
  // Clock
  // =========================================================
  initial i_clk = 1'b0;
  always #5 i_clk = ~i_clk;

  // =========================================================
  // Capability presets
  // =========================================================
  logic [63:0] local_adapter_cap_good;
  logic [63:0] remote_adapter_cap_good;
  logic [63:0] remote_adapter_cap_bad_stream;
  logic [63:0] local_cxl_cap_good;
  logic [63:0] remote_cxl_cap_good;
  logic [63:0] remote_cxl_cap_bad;

  initial begin
    local_adapter_cap_good       = 64'd0;
    local_adapter_cap_good[3:1]  = 3'b001; // valid PCIe protocol
    local_adapter_cap_good[7]    = 1'b1;   // stack0 enabled
    local_adapter_cap_good[24]   = 1'b1;   // format indication
    local_adapter_cap_good[5]    = 1'b0;   // retry consistent

    remote_adapter_cap_good      = 64'd0;
    remote_adapter_cap_good[3:1] = 3'b001;
    remote_adapter_cap_good[7]   = 1'b1;
    remote_adapter_cap_good[24]  = 1'b1;
    remote_adapter_cap_good[5]   = 1'b0;

    remote_adapter_cap_bad_stream      = 64'd0;
    remote_adapter_cap_bad_stream[4:1] = 4'b1000; // streaming => invalid
    remote_adapter_cap_bad_stream[7]   = 1'b1;

    local_cxl_cap_good     = 64'd0;
    local_cxl_cap_good[0]  = 1'b1;

    remote_cxl_cap_good    = 64'd0;
    remote_cxl_cap_good[0] = 1'b1;

    remote_cxl_cap_bad     = 64'd0; // invalid because bit0 = 0
  end

  // =========================================================
  // Helpers
  // =========================================================
  task automatic clear_inputs();
    i_adapter_advcap   = '0;
    i_cxl_advcap       = '0;
    i_format4_enabled  = 1'b0;
    i_format6_enabled  = 1'b0;
    i_retry_needed     = 1'b0;
    i_rx_msg_with_data = '0;
    i_rx_msg_valid     = 1'b0;
    i_flit_fmt_status  = 5'd0;
    i_start_PE         = 1'b0;
    i_retry_negotiated = 1'b0;
  endtask

  task automatic do_reset();
    clear_inputs();

    i_rstn   = 1'b0;
    i_init_n = 1'b1;
    repeat (3) @(posedge i_clk);

    i_rstn = 1'b1;
    repeat (2) @(posedge i_clk);

    i_init_n = 1'b0;
    repeat (2) @(posedge i_clk);

    i_init_n = 1'b1;
    repeat (2) @(posedge i_clk);
  endtask

  function automatic logic [127:0] build_rx_pkt(
    input logic [63:0] cap,
    input logic [7:0]  msgcode,
    input logic [7:0]  msgsubcode,
    input logic [15:0] msginfo
  );
    logic [127:0] pkt;
    begin
      pkt = '0;
      pkt[127:64] = cap;
      pkt[55:40]  = msginfo;
      pkt[39:32]  = msgsubcode;
      pkt[21:14]  = msgcode;
      return pkt;
    end
  endfunction

  task automatic pulse_start_pe_and_check_tx();
    @(negedge i_clk);
    i_start_PE = 1'b1;
    #1;
    if (o_tx_msg_valid !== 1'b1)
      $error("[FAIL] RP did not send initial adapter advcap");
    @(negedge i_clk);
    i_start_PE = 1'b0;
    #1;
  endtask

  task automatic start_rx_msg(
    input logic [63:0] cap,
    input logic [7:0]  msgcode,
    input logic [7:0]  msgsubcode,
    input logic [15:0] msginfo = 16'h0000
  );
    @(negedge i_clk);
    i_rx_msg_with_data = build_rx_pkt(cap, msgcode, msgsubcode, msginfo);
    i_rx_msg_valid     = 1'b1;
    #1;
  endtask

  task automatic stop_rx_msg();
    @(negedge i_clk);
    i_rx_msg_valid     = 1'b0;
    i_rx_msg_with_data = '0;
    #1;
  endtask

  task automatic drive_rx_msg(
    input logic [63:0] cap,
    input logic [7:0]  msgcode,
    input logic [7:0]  msgsubcode,
    input logic [15:0] msginfo = 16'h0000
  );
    start_rx_msg(cap, msgcode, msgsubcode, msginfo);
    stop_rx_msg();
  endtask

  task automatic wait_pe_done(input int max_cycles = 30);
    int i;
    begin
      for (i = 0; i < max_cycles; i++) begin
        @(posedge i_clk);
        if (o_PE_done) begin
          $display("[PASS] PE done asserted at time %0t", $time);
          return;
        end
      end
      $error("[FAIL] Timed out waiting for o_PE_done");
    end
  endtask

  task automatic wait_invalid(input int max_cycles = 30);
    int i;
    begin
      for (i = 0; i < max_cycles; i++) begin
        @(posedge i_clk);
        if (o_invalid_param_exch) begin
          $display("[PASS] Invalid exchange asserted at time %0t", $time);
          return;
        end
      end
      $error("[FAIL] Timed out waiting for o_invalid_param_exch");
    end
  endtask

  task automatic wait_timeout(input int max_cycles = TIMEOUT_WAIT);
    int i;
    begin
      for (i = 0; i < max_cycles; i++) begin
        @(posedge i_clk);
        if (o_param_exchange_timeout) begin
          $display("[PASS] Timeout asserted at time %0t", $time);
          return;
        end
      end
      $error("[FAIL] Timed out waiting for o_param_exchange_timeout");
    end
  endtask

  task automatic check_no_terminal_flags();
    if (o_PE_done || o_invalid_param_exch || o_param_exchange_timeout)
      $error("[FAIL] Unexpected terminal flag asserted. done=%0b invalid=%0b timeout=%0b",
             o_PE_done, o_invalid_param_exch, o_param_exchange_timeout);
  endtask

  // =========================================================
  // Test 1: RP success flow
  // =========================================================
  task automatic test_success_rp();
    logic [63:0] common_cap;
    begin
      $display("=== TEST 1: RP successful parameter exchange ===");
      do_reset();

      i_adapter_advcap  = local_adapter_cap_good;
      i_cxl_advcap      = local_cxl_cap_good;
      i_format4_enabled = 1'b0;
      i_format6_enabled = 1'b0;
      i_retry_needed    = 1'b0;
      i_flit_fmt_status = 5'd2;

      pulse_start_pe_and_check_tx();

      start_rx_msg(remote_adapter_cap_good, 8'h01, 8'h00, 16'h0000);

      common_cap = local_adapter_cap_good & remote_adapter_cap_good;

      if (!o_adapter_fincap_valid)
        $error("[FAIL] RP did not produce finalized adapter capability");

      if (o_adapter_fincap !== common_cap)
        $error("[FAIL] Wrong finalized adapter cap. EXP=%h GOT=%h",
               common_cap, o_adapter_fincap);

      stop_rx_msg();

      repeat (2) @(posedge i_clk);

      start_rx_msg(remote_cxl_cap_good, 8'h01, 8'h01, 16'h0000);
      stop_rx_msg();

      wait_pe_done(20);

      if (!o_pl_valid)
        $error("[FAIL] o_pl_valid not asserted on success");

      if (o_pl_protocol !== 4'b0000)
        $error("[FAIL] Wrong protocol to PL. GOT=%b", o_pl_protocol);
    end
  endtask

  // =========================================================
  // Test 2: Invalid due to streaming mode
  // =========================================================
  task automatic test_invalid_streaming_mode();
    begin
      $display("=== TEST 2: Invalid exchange due to streaming mode ===");
      do_reset();

      i_adapter_advcap  = local_adapter_cap_good;
      i_cxl_advcap      = local_cxl_cap_good;
      i_format4_enabled = 1'b0;
      i_format6_enabled = 1'b0;
      i_retry_needed    = 1'b0;

      pulse_start_pe_and_check_tx();

      drive_rx_msg(remote_adapter_cap_bad_stream, 8'h01, 8'h00, 16'h0000);

      wait_invalid(20);
    end
  endtask

  // =========================================================
  // Test 3: Invalid due to bad CXL capability
  // =========================================================
  task automatic test_invalid_cxl();
    begin
      $display("=== TEST 3: Invalid exchange due to bad CXL capability ===");
      do_reset();

      i_adapter_advcap  = local_adapter_cap_good;
      i_cxl_advcap      = local_cxl_cap_good;
      i_format4_enabled = 1'b0;
      i_format6_enabled = 1'b0;
      i_retry_needed    = 1'b0;

      pulse_start_pe_and_check_tx();

      drive_rx_msg(remote_adapter_cap_good, 8'h01, 8'h00, 16'h0000);

      repeat (2) @(posedge i_clk);

      drive_rx_msg(remote_cxl_cap_bad, 8'h01, 8'h01, 16'h0000);

      wait_invalid(20);
    end
  endtask

  // =========================================================
  // Test 4: Timeout while waiting for adapter capability
  // =========================================================
  task automatic test_timeout_wait_adapter();
    begin
      $display("=== TEST 4: Timeout while waiting for adapter capability ===");
      do_reset();

      i_adapter_advcap  = local_adapter_cap_good;
      i_cxl_advcap      = local_cxl_cap_good;
      i_format4_enabled = 1'b0;
      i_format6_enabled = 1'b0;
      i_retry_needed    = 1'b0;

      pulse_start_pe_and_check_tx();

      wait_timeout(TIMEOUT_WAIT);
    end
  endtask

  // =========================================================
  // Test 5: Wrong message ignored before correct one
  // =========================================================
  task automatic test_ignore_wrong_message_before_correct();
    begin
      $display("=== TEST 5: Wrong message should not complete exchange ===");
      do_reset();

      i_adapter_advcap  = local_adapter_cap_good;
      i_cxl_advcap      = local_cxl_cap_good;
      i_format4_enabled = 1'b0;
      i_format6_enabled = 1'b0;
      i_retry_needed    = 1'b0;

      pulse_start_pe_and_check_tx();

      drive_rx_msg(remote_adapter_cap_good, 8'h01, 8'h01, 16'h0000);
      repeat (3) @(posedge i_clk);
      check_no_terminal_flags();

      drive_rx_msg(remote_adapter_cap_good, 8'h01, 8'h00, 16'h0000);
      repeat (2) @(posedge i_clk);

      drive_rx_msg(remote_cxl_cap_good, 8'h01, 8'h01, 16'h0000);

      wait_pe_done(20);
    end
  endtask

  // =========================================================
  // Test 6: Choose Format 3
  // =========================================================
  task automatic test_choose_format3();
    logic [63:0] local_cap;
    logic [63:0] remote_cap;
    logic [63:0] common_cap;

    begin
      $display("=== TEST 6: Choose Format 3 ===");
      do_reset();

      local_cap  = 64'd0;
      remote_cap = 64'd0;

      // Make protocol valid AND make bit[3] = 1
      // DUT accepts [3:1] = 3'b101 when bit[31] = 0
      local_cap[3:1]   = 3'b101;
      remote_cap[3:1]  = 3'b101;
      local_cap[31]    = 1'b0;
      remote_cap[31]   = 1'b0;

      // Stack0 enabled
      local_cap[7]  = 1'b1;
      remote_cap[7] = 1'b1;

      // Retry consistent
      local_cap[5]  = 1'b0;
      remote_cap[5] = 1'b0;

      // Keep [24], [25], [27] low
      // so in branch {format6,format4}=2'b00 selection depends on bit[3]

      i_adapter_advcap  = local_cap;
      i_cxl_advcap      = local_cxl_cap_good;
      i_format4_enabled = 1'b0;
      i_format6_enabled = 1'b0;
      i_retry_needed    = 1'b0;

      pulse_start_pe_and_check_tx();

      start_rx_msg(remote_cap, 8'h01, 8'h00, 16'h0000);

      common_cap = local_cap & remote_cap;

      if (!o_adapter_fincap_valid)
        $error("[FAIL] Format3 test: o_adapter_fincap_valid not asserted");

      if (o_adapter_fincap !== common_cap)
        $error("[FAIL] Format3 test: wrong common adapter cap. EXP=%h GOT=%h",
               common_cap, o_adapter_fincap);

      if (!o_flitfmt_valid)
        $error("[FAIL] Format3 test: o_flitfmt_valid not asserted");

      if (o_flit_fromat_status !== 5'b00011)
        $error("[FAIL] Format3 test: expected Format 3, GOT=%b",
               o_flit_fromat_status);
      else
        $display("[PASS] Format3 test: selected format 3 correctly at time %0t", $time);

      stop_rx_msg();
    end
  endtask

  // =========================================================
  // Main
  // =========================================================
  initial begin
`ifdef END_POINT
    $display("WARNING: This TB is written for RP mode, but END_POINT is defined.");
`else
    $display("Running UC_parameterexchange_tb in RP mode");
`endif

    test_success_rp();
    test_invalid_streaming_mode();
    test_invalid_cxl();
    test_timeout_wait_adapter();
    test_ignore_wrong_message_before_correct();
    test_choose_format3();

    #100;
    $display("Simulation done.");
    $finish;
  end

endmodule