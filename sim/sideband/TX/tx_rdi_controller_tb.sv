`timescale 1ns/1ps

module tx_rdi_controller_tb;

  // =========================
  // Parameters
  // =========================
  localparam int NC              = 32;
  localparam int TX_TOTAL_PHASES = 128/NC;
  localparam int TX_HALF_PHASES  = 64/NC;

  // =========================
  // DUT I/O
  // =========================
  logic                 i_clk;
  logic                 i_rstn;
  logic                 i_init_n;

  logic [127:0]         i_fdi_pkt;
  logic                 i_fdi_length;
  logic                 i_fdi_valid;
  logic                 o_fdi_sent;

  logic [127:0]         i_msg_pkt;
  logic                 i_msg_length;
  logic                 i_msg_valid;
  logic                 o_msg_sent;
  logic                 o_msg_is_req;

  logic [127:0]         i_remote_pkt;
  logic                 i_remote_length;
  logic                 i_remote_valid;
  logic                 o_remote_sent;

  logic [NC-1:0]        o_lp_cfg;
  logic                 o_lp_cfg_vld;

  logic                 i_stall_tx;
  logic                 o_decrease_counter;

  logic [127:0]         assembled;

  // =========================
  // Instantiate DUT
  // =========================
  tx_rdi_controller #(.NC(NC)) dut (
    .i_clk(i_clk),
    .i_rstn(i_rstn),
    .i_init_n(i_init_n),

    .i_fdi_pkt(i_fdi_pkt),
    .i_fdi_length(i_fdi_length),
    .i_fdi_valid(i_fdi_valid),
    .o_fdi_sent(o_fdi_sent),

    .i_msg_pkt(i_msg_pkt),
    .i_msg_length(i_msg_length),
    .i_msg_valid(i_msg_valid),
    .o_msg_sent(o_msg_sent),
    .o_msg_is_req(o_msg_is_req),

    .i_remote_pkt(i_remote_pkt),
    .i_remote_length(i_remote_length),
    .i_remote_valid(i_remote_valid),
    .o_remote_sent(o_remote_sent),

    .o_lp_cfg(o_lp_cfg),
    .o_lp_cfg_vld(o_lp_cfg_vld),

    .i_stall_tx(i_stall_tx),
    .o_decrease_counter(o_decrease_counter)
  );

  // =========================
  // Clock
  // =========================
  initial i_clk = 1'b0;
  always #5 i_clk = ~i_clk; // 100 MHz

  // =========================
  // Simple scoreboard item
  // =========================
  typedef struct {
    logic [127:0] pkt;
    logic         length;
    string        src;
  } exp_item_t;

  exp_item_t exp_q[$];

  // Must be declared before any test task/initial that uses it
  task push_expected(input logic [127:0] pkt,
                     input logic length,
                     input string src);
    exp_item_t it;
    it.pkt    = pkt;
    it.length = length;
    it.src    = src;
    exp_q.push_back(it);
  endtask

  // =========================
  // Monitor: collect phases (FIXED)
  // =========================
  logic [127:0]  mon_pkt_shift;
  int            mon_phase_cnt;
  int            mon_need_phases;
  bit            mon_en;

  function automatic int phases_for_length(input logic length);
    return length ? TX_TOTAL_PHASES : TX_HALF_PHASES;
  endfunction

  task automatic monitor_reset();
    mon_pkt_shift   = '0;
    mon_phase_cnt   = 0;
    mon_need_phases = 0;
  endtask

  always_ff @(posedge i_clk or negedge i_rstn) begin
    if (!i_rstn) begin
      monitor_reset();
    end else if (!i_init_n) begin
      monitor_reset();
    end else begin
      if (mon_en && o_lp_cfg_vld) begin

        // If no expected packet exists, ignore (protects from glitches)
        if (exp_q.size() == 0) begin
          $warning("MON: o_lp_cfg_vld high but exp_q empty. time=%0t o_lp_cfg=%h (ignoring)",
                   $time, o_lp_cfg);
          monitor_reset();
        end else begin

          // Determine required number of phases from the expected head
          if (mon_need_phases == 0)
            mon_need_phases <= phases_for_length(exp_q[0].length);

          // Assemble packet using blocking update (avoids NBA timing issues)
          assembled = mon_pkt_shift;
          assembled[mon_phase_cnt*NC +: NC] = o_lp_cfg;

          // Increment phase counter
          mon_phase_cnt <= mon_phase_cnt + 1;

          // Store assembled data for next cycle
          mon_pkt_shift <= assembled;

          // If packet is complete, pop expected and compare
          if ((mon_need_phases != 0) && ((mon_phase_cnt + 1) == mon_need_phases)) begin
            automatic exp_item_t got;
            got = exp_q.pop_front();

            if (assembled === got.pkt) begin
              $display("[PASS] %s packet matched (len=%0d) time=%0t",
                       got.src, got.length, $time);
            end else begin
              $error("[FAIL] %s packet mismatch (len=%0d) time=%0t\nEXP=%032h\nGOT=%032h",
                     got.src, got.length, $time, got.pkt, assembled);
            end

            monitor_reset();
          end
        end
      end
    end
  end

  // =========================
  // Drive helpers
  // =========================
  task automatic clear_inputs();
    i_fdi_pkt       = '0;
    i_fdi_length    = 1'b0;
    i_fdi_valid     = 1'b0;

    i_msg_pkt       = '0;
    i_msg_length    = 1'b0;
    i_msg_valid     = 1'b0;

    i_remote_pkt    = '0;
    i_remote_length = 1'b0;
    i_remote_valid  = 1'b0;

    i_stall_tx      = 1'b0;
  endtask

  task automatic do_reset();
    clear_inputs();
    mon_en = 1'b0;
    monitor_reset();

    // Hardware reset (active low)
    i_rstn   = 1'b0;
    i_init_n = 1'b1;
    repeat (3) @(posedge i_clk);

    // Release HW reset
    i_rstn = 1'b1;
    repeat (2) @(posedge i_clk);

    // Software reset (active low)
    i_init_n = 1'b0;
    repeat (2) @(posedge i_clk);
    i_init_n = 1'b1;
    repeat (2) @(posedge i_clk);

    // Enable monitor only after resets are clean
    mon_en = 1'b1;
  endtask

  // Drive a one-cycle valid request on a given source (stable before posedge)
  task automatic drive_msg(input logic [127:0] pkt, input logic length);
    @(negedge i_clk);
    i_msg_pkt    <= pkt;
    i_msg_length <= length;
    i_msg_valid  <= 1'b1;
    @(negedge i_clk);
    i_msg_valid  <= 1'b0;
  endtask

  task automatic drive_remote(input logic [127:0] pkt, input logic length);
    @(negedge i_clk);
    i_remote_pkt    <= pkt;
    i_remote_length <= length;
    i_remote_valid  <= 1'b1;
    @(negedge i_clk);
    i_remote_valid  <= 1'b0;
  endtask

  task automatic drive_fdi(input logic [127:0] pkt, input logic length);
    @(negedge i_clk);
    i_fdi_pkt    <= pkt;
    i_fdi_length <= length;
    i_fdi_valid  <= 1'b1;
    @(negedge i_clk);
    i_fdi_valid  <= 1'b0;
  endtask

  // =========================
  // Assertions / checks
  // =========================
  task automatic test_priority_all_valid();
    logic [127:0] p_msg, p_rem, p_fdi;
    int tmo;

    // Distinct patterns to identify phases easily
    p_msg = 128'h0123_4567_89AB_CDEF_FEDC_BA98_7654_3210;
    p_rem = 128'h1111_2222_3333_4444_5555_6666_7777_8888;
    p_fdi = 128'hAAAA_BBBB_CCCC_DDDD_EEEE_FFFF_0000_1111;

    // Ensure stall = 0
    i_stall_tx = 1'b0;

    // Expect MSG first
    push_expected(p_msg, 1'b1, "MSG");

    // Assert all valids before posedge and keep them stable across it
    @(negedge i_clk);
    $display("TB: assert all valids @%0t", $time);
    i_msg_pkt        = p_msg; i_msg_length = 1'b1; i_msg_valid = 1'b1;
    i_remote_pkt     = p_rem; i_remote_length = 1'b1; i_remote_valid = 1'b1;
    i_fdi_pkt        = p_fdi; i_fdi_length = 1'b1; i_fdi_valid = 1'b1;

    #3;

    if (!o_msg_sent)
      $error("Priority test: MSG was not accepted when all valids asserted!");

    // Hold across at least one posedge
    @(posedge i_clk);

    // Deassert valids after DUT samples them
    @(negedge i_clk);
    $display("TB: deassert all valids @%0t", $time);
    i_msg_valid    = 1'b0;
    i_remote_valid = 1'b0;
    i_fdi_valid    = 1'b0;

    // Ensure other sources were not accepted together with MSG
    if (o_remote_sent || o_fdi_sent)
      $error("Priority test: REMOTE/FDI should not be accepted in same cycle as MSG!");

    // Wait for full packet transmission
    repeat (TX_TOTAL_PHASES + 5) @(posedge i_clk);
  endtask

  task automatic test_length_64_then_128();
    logic [127:0] p64, p128;
    p64  = 128'hAAAA_BBBB_CCCC_DDDD_EEEE_FFFF_0000_1111;
    p128 = 128'hDEAD_BEEF_0123_4567_89AB_CDEF_FEDC_BA98;

    // 64-bit => TX_HALF_PHASES
    push_expected(p64, 1'b0, "FDI");
    drive_fdi(p64, 1'b0);

    repeat (TX_HALF_PHASES + 5) @(posedge i_clk);

    // 128-bit => TX_TOTAL_PHASES
    push_expected(p128, 1'b1, "REMOTE");
    drive_remote(p128, 1'b1);

    repeat (TX_TOTAL_PHASES + 5) @(posedge i_clk);
  endtask

  task automatic test_stall_blocks_idle_accept();
    logic [127:0] p;
    p = 128'hFACE_CAFE_0000_0000_1111_2222_3333_4444;

    // Assert stall, then try to send MSG: should NOT be accepted until stall deasserted
    @(negedge i_clk);
    i_stall_tx   <= 1'b1;
    i_msg_pkt    <= p;
    i_msg_length <= 1'b1;
    i_msg_valid  <= 1'b1;

    repeat (3) @(posedge i_clk);
    if (o_msg_sent) $error("STALL test: o_msg_sent asserted while i_stall_tx=1!");

    // Release stall -> expect acceptance next cycle and transmission begins
    push_expected(p, 1'b1, "MSG");
    @(negedge i_clk);
    i_stall_tx <= 1'b0;

    @(posedge i_clk);
    if (!o_msg_sent) $error("STALL test: MSG not accepted after stall released!");

    @(negedge i_clk);
    i_msg_valid <= 1'b0;

    repeat (TX_TOTAL_PHASES + 5) @(posedge i_clk);
  endtask

  // =========================
  // Main stimulus
  // =========================
  initial begin
    do_reset();

    $display("=== TEST 1: Priority (MSG > REMOTE > FDI) when all valid ===");
    test_priority_all_valid();

    $display("=== TEST 2: 64-bit then 128-bit length handling ===");
    test_length_64_then_128();

    $display("=== TEST 3: Stall blocks acceptance in IDLE ===");
    test_stall_blocks_idle_accept();

    #200;
    $display("Simulation done.");
    $finish;
  end

endmodule