// =============================================================================
// TB: UC_MB_retry_top — Scenario-based flit-level simulation
// Simulates real flit traffic: SNH handshake, normal payload exchange,
// NAK-triggered replay, CRC errors, buffer write/readback
// =============================================================================
`timescale 1ns / 1ps
import UC_MB_retry_pkg::*;

module UC_MB_retry_top_scenario_tb;

  // -------------------------------------------------------------------------
  // Signals
  // -------------------------------------------------------------------------
  logic clk, rst_n, init;
  logic fdi_active, tx_en, rx_en;
  data_rate_t data_rate;
  logic       tx_flit_valid;
  logic       rx_flit_valid;
  logic transmitter_write, flush, drain;
  buffer_state_t buffer_state;
  logic                               rx_crc_error;
  logic            [             7:0] rx_seq_num;
  replay_command_t                    rx_replay_command;
  flit_type_t                         rx_flit_type;
  logic            [  DATA_WIDTH-1:0] tx_i_data;
  logic            [STREAM_WIDTH-1:0] tx_i_stream;
  logic            [  DATA_WIDTH-1:0] tx_o_data;
  logic            [STREAM_WIDTH-1:0] tx_o_stream;
  logic                               pl_trdy_control;
  replay_command_t                    tx_replay_command;
  logic            [             7:0] tx_seq_num;
  logic discard_flit, discard_payload;
  logic log_uie, log_cie, rdi_retrain;

  // -------------------------------------------------------------------------
  // DUT
  // -------------------------------------------------------------------------
  UC_MB_retry_top dut (.*);

  // -------------------------------------------------------------------------
  // Clock — 50 MHz (20ns period)
  // -------------------------------------------------------------------------
  initial clk = 0;
  always #10 clk = ~clk;

  // -------------------------------------------------------------------------
  // flit_valid generator — pulses every 4 clk (256B = 4 x 64B)
  // -------------------------------------------------------------------------
  logic [1:0] fv_cnt;
  always_ff @(negedge clk or negedge rst_n) begin
    if (!rst_n) fv_cnt <= 0;
    else if (!init) fv_cnt <= 0;
    else fv_cnt <= fv_cnt + 1;
  end
  assign tx_flit_valid = (fv_cnt == 0) && init && rst_n;

  // -------------------------------------------------------------------------
  // Monitoring — watch key signals each flit_valid
  // -------------------------------------------------------------------------
  always @(negedge clk) begin
    if (tx_flit_valid) begin
      $display(
          "[%0t] FLIT | tx_cmd=%-8s tx_seq=%3d pl_trdy=%0b | rx_cmd=%-8s rx_seq=%3d rx_flit_type=%-8s rx_crc=%0b | tx_phase = %-10s | rx_phase = %-10s | rx_next = 0x%0d, rx_implicit=0x%0d",
          $time, tx_replay_command.name(), tx_seq_num, pl_trdy_control, rx_replay_command.name(),
          rx_seq_num, rx_flit_type.name(), rx_crc_error, dut.u_transmitter_rules.o_tx_phase.name(),
          dut.u_receiver_rules.rx_phase.name(), dut.u_receiver_rules.next_expect_rx_flit_seq_num, dut.u_implicit_rx_rules.o_implicit_rx_flit_seq_num);
    end
  end

  // -------------------------------------------------------------------------
  // Assertion infrastructure
  // -------------------------------------------------------------------------
  int pass_cnt = 0, fail_cnt = 0;

  task automatic assert_chk(string phase, string sig, logic [31:0] actual, logic [31:0] expected);
    if (actual !== expected) begin
      $display("  [FAIL] %s | %s = 0x%0h, expected 0x%0h @ %0t", phase, sig, actual, expected,
               $time);
      fail_cnt++;
    end else begin
      $display("  [PASS] %s | %s = 0x%0h", phase, sig, actual);
      pass_cnt++;
    end
  endtask

  // -------------------------------------------------------------------------
  // Helper tasks
  // -------------------------------------------------------------------------

  task automatic reset_all();
    rst_n = 0;
    init = 0;
    fdi_active = 0;
    tx_en = 0;
    rx_en = 0;
    data_rate = GTs_32;
    transmitter_write = 0;
    flush = 0;
    drain = 0;
    rx_crc_error = 0;
    rx_seq_num = 0;
    rx_replay_command = explicit;
    rx_flit_type = NOP;
    tx_i_data = '0;
    tx_i_stream = '0;
    repeat (4) @(negedge clk);
    rst_n = 1;
    @(negedge clk);
    init = 1;
    @(negedge clk);
  endtask

  // Wait for the next flit_valid pulse
  task automatic wait_flit(int n = 1);
    repeat (n) begin
      @(negedge clk);
      while (!tx_flit_valid) @(negedge clk);
    end
  endtask

  // Drive RX flit for one full flit period (4 clk cycles)
  task automatic send_rx_flit(input replay_command_t cmd, input [7:0] seq, input flit_type_t ft,
                              input logic crc_err = 0);
    rx_replay_command = cmd;
    rx_seq_num        = seq;
    rx_flit_type      = ft;
    rx_crc_error      = crc_err;
    repeat (4) @(negedge clk);
  endtask

  // Write one 64B chunk into the buffer (call 4 times for a full 256B flit)
  task automatic write_buffer_chunk(input [DATA_WIDTH-1:0] data, input [STREAM_WIDTH-1:0] stream);
    transmitter_write = 1;
    tx_i_data         = data;
    tx_i_stream       = stream;
    @(negedge clk);
    transmitter_write = 0;
    tx_i_data         = '0;
    tx_i_stream       = '0;
  endtask

  // Write 4 chunks (one full 256B flit) into the buffer
  task automatic write_full_flit(input [7:0] flit_id);
    for (int i = 0; i < 4; i++) begin
      write_buffer_chunk({496'b0, flit_id, i[7:0]},  // data: flit_id + chunk index
                         flit_id[STREAM_WIDTH-1:0]    // stream: lower bits of flit_id
      );  
    end
  endtask

  // Clear RX signals to idle
  task automatic rx_idle();
    rx_replay_command = explicit;
    rx_seq_num        = 8'h00;
    rx_flit_type      = NOP;
    rx_crc_error      = 0;
  endtask
  
// property check_tx_seq_num;
//         @(posedge clk) disable iff (~rst_n || !init) (tx_seq_num != 0);
//     endproperty
//     check_tx_seq_num_assert: assert property (check_tx_seq_num);
//     cover property (check_tx_seq_num);

  // =========================================================================
  //                          SCENARIO 1 — SNH Handshake
  // Bring both TX and RX from R_IDLE through SNH to NORMAL_EXCHANGE
  // =========================================================================
  initial begin
    $display("\n================================================================");
    $display("     UCIe MB Retry — Scenario-Based Flit TB");
    $display("================================================================\n");

    // ---------------------------------------------------------------
    // Phase 0: Reset
    // ---------------------------------------------------------------
    $display("\n=== PHASE 0: Reset ===");
    reset_all();
    // --- Assertions: after reset all outputs must be safe ---
    assert_chk("P0", "pl_trdy", pl_trdy_control, 0);
    assert_chk("P0", "tx_cmd", tx_replay_command, explicit);
    assert_chk("P0", "tx_seq", tx_seq_num, 0);
    assert_chk("P0", "discard_flit", discard_flit, 0);
    assert_chk("P0", "discard_pay", discard_payload, 0);
    assert_chk("P0", "log_uie", log_uie, 0);
    assert_chk("P0", "log_cie", log_cie, 0);
    assert_chk("P0", "rdi_retrain", rdi_retrain, 0);

    // ---------------------------------------------------------------
    // Phase 1: Activate TX and RX — enter SNH
    // ---------------------------------------------------------------
    $display("\n=== PHASE 1: Enter SNH ===");
    tx_en = 1;
    rx_en = 1;
    // TX side: transmitting_rules sends explicit with seq=0xFF
    // RX side: we simulate the remote sending its SNH flits
    // First: remote sends explicit with seq=0xFF (SNH idle)
    send_rx_flit(explicit, 8'hFF, NOP);
    send_rx_flit(explicit, 8'hFF, NOP);
    send_rx_flit(explicit, 8'hFF, NOP);
    // --- Assertions: in SNH, TX must send explicit, seq=0xFF, pl_trdy=1 ---
    assert_chk("P1:SNH", "tx_cmd", tx_replay_command, explicit);
    assert_chk("P1:SNH", "tx_seq", tx_seq_num, 8'hFF);
    assert_chk("P1:SNH", "pl_trdy", pl_trdy_control, 1);

    // ---------------------------------------------------------------
    // Phase 2: FDI goes active — SNH_FDI_ACTIVE
    // ---------------------------------------------------------------
    // SNH completion is checked by TRANSMITTED flits, not received.
    // Rule: transmitter must transmit >=3 ACK and >=9 explicit flits
    //       with non-zero seq_num, after remote_sent_nonzero_fsn is set.
    // remote_sent_nonzero_fsn is set when tx_acknak_flit_seq_num != 0
    // (i.e., the receiver processed at least one non-explicit RX flit).
    // ---------------------------------------------------------------
    $display("\n=== PHASE 2: FDI Active to SNH_FDI_ACTIVE ===");
    fdi_active = 1;
    wait_flit(2);
    assert_chk("P2:SNH_FDI", "tx_phase", dut.u_transmitter_rules.o_tx_phase, SNH_FDI_ACTIVE);
    assert_chk("P2:SNH_FDI", "rx_phase", dut.u_receiver_rules.o_rx_phase, SNH_FDI_ACTIVE);
    assert_chk("P1:SNH", "pl_trdy", pl_trdy_control, 0);

    // Step 1: Send one non-explicit RX payload flit so the receiver
    //         schedules an ACK → tx_acknak_flit_seq_num becomes non-zero
    //         → remote_sent_nonzero_fsn is set in the SNH checker.
    $display("  Sending RX payload to trigger receiver ACK scheduling...");
    send_rx_flit(ack, 8'h01, PAYLOAD);
    wait_flit(2);

    // Step 2: Let the transmitter run through enough flit_valid cycles.
    //         In SNH_FDI_ACTIVE_CASE the transmitter alternates:
    //           - 1 explicit (consecutive_tx_explicit_seq_num < 1)
    //           - then 1 ACK (else branch)
    //         So every 2 flit_valid cycles we get 1 explicit + 1 ACK.
    //         We need >=9 explicits and >=3 ACKs → at least 9 pairs = 18 cycles.
    //         Wait extra to be safe.
    //$display("  Waiting for transmitter to send >=3 ACK + >=9 explicit flits...");
    repeat (30) begin
      wait_flit(1);
      $display("  [SNH TX] tx_cmd=%-8s tx_seq=0x%02h | ack_cnt=%0d expl_cnt=%0d snh_done=%0b",
               tx_replay_command.name(), tx_seq_num, dut.u_snh_condition_checker.tx_ack_flit_count,
               dut.u_snh_condition_checker.tx_explicit_flit_count,
               dut.u_snh_condition_checker.o_snh_done);
      if (dut.u_snh_condition_checker.o_snh_done) begin
        $display("  [SNH] snh_done asserted — breaking early");
        break;
      end
    end
    wait_flit(2);

    $display("[SNH] tx_cmd=%s tx_seq=0x%0h pl_trdy=%0b", tx_replay_command.name(), tx_seq_num,
             pl_trdy_control);
    // --- Assertions: SNH should be complete, phases should be NORMAL_EXCHANGE ---
    assert_chk("P2:SNH_FDI", "snh_done", dut.u_snh_condition_checker.o_snh_done, 1);
    assert_chk("P2:SNH_FDI", "rdi_retrain", rdi_retrain, 0);
    assert_chk("P2:SNH_FDI", "log_cie", log_cie, 0);
    assert_chk("P2:SNH_FDI", "tx_phase", dut.u_transmitter_rules.o_tx_phase, NORMAL_EXCHANGE);
    assert_chk("P2:SNH_FDI", "rx_phase", dut.u_receiver_rules.o_rx_phase, NORMAL_EXCHANGE);


    // ---------------------------------------------------------------
    // Phase 3: NORMAL_EXCHANGE — send & receive payload flits
    // ---------------------------------------------------------------
    $display("\n=== PHASE 3: Normal Payload Exchange ===");
    $display("  Writing 4 flits to buffer and sending payload...");

    // Write 4 full flits into the retry buffer
    write_full_flit(8'h01);
    wait_flit(1);
    write_full_flit(8'h02);
    wait_flit(1);
    write_full_flit(8'h03);
    wait_flit(1);
    write_full_flit(8'h04);
    wait_flit(1);

    // Remote ACKs flits 1-2 (advancing ackd pointer)
    $display("  Remote ACKs flit 1...");
    send_rx_flit(ack, 8'h01, PAYLOAD);
    wait_flit(2);
    $display("  Remote ACKs flit 2...");
    send_rx_flit(ack, 8'h02, PAYLOAD);
    wait_flit(2);

    $display("[NORMAL] tx_cmd=%s tx_seq=0x%0h pl_trdy=%0b", tx_replay_command.name(), tx_seq_num,
             pl_trdy_control);
    // --- Assertions: in normal exchange, pl_trdy should be 0 (accepting data) ---
    assert_chk("P3:NORMAL", "pl_trdy", pl_trdy_control, 0);
    assert_chk("P3:NORMAL", "rdi_retrain", rdi_retrain, 0);

    // ---------------------------------------------------------------
    // Phase 4: RX CRC Error — remote flit arrives corrupted
    // ---------------------------------------------------------------
    $display("\n=== PHASE 4: RX CRC Error to NAK Scheduled ===");
    // Receive a flit with CRC error
    send_rx_flit(ack, 8'h03, PAYLOAD, 1);  // crc_err = 1
    wait_flit(2);
    $display("[CRC ERR] discard_flit=%0b discard_payload=%0b", discard_flit, discard_payload);
    // --- Assertion: first CRC error must trigger discard_flit (nak_schedule_0) ---
    assert_chk("P4:CRC1", "discard_flit", discard_flit, 1);

    // Another CRC error while NAK already scheduled → flit discard
    send_rx_flit(ack, 8'h04, PAYLOAD, 1);  // second CRC err
    wait_flit(2);
    $display("[CRC ERR2] discard_flit=%0b (NAK already scheduled)", discard_flit);
    // --- Assertion: second CRC while NAK scheduled → flit_discard_1 ---
    assert_chk("P4:CRC2", "discard_flit", discard_flit, 1);

    // Clear CRC error
    rx_crc_error = 0;
    wait_flit(2);

    // ---------------------------------------------------------------
    // Phase 5: Remote sends NAK → triggers replay
    // ---------------------------------------------------------------
    $display("\n=== PHASE 5: Remote NAK → Replay Triggered ===");
    // Remote NAKs from seq 3 — means it wants replay from flit 3
    send_rx_flit(nak, 8'h03, PAYLOAD);
    wait_flit(1);
    $display("[NAK RECV] tx_cmd=%s tx_seq=0x%0h pl_trdy=%0b", tx_replay_command.name(), tx_seq_num,
             pl_trdy_control);
    // --- Assertion: after NAK, replay starts → pl_trdy=1 (block new data) ---
    assert_chk("P5:NAK", "pl_trdy", pl_trdy_control, 1);

    // Let replay execute — monitor buffer readback
    $display("  Replay in progress...");
    repeat (15) begin
      wait_flit(1);
      $display("  [REPLAY] tx_seq=%3d tx_cmd=%-8s pl_trdy=%0b | o_data[15:0]=0x%04h", tx_seq_num,
               tx_replay_command.name(), pl_trdy_control, tx_o_data[15:0]);
    end

    // After replay completes, pl_trdy should go back to 0
    $display("[REPLAY DONE?] pl_trdy=%0b tx_cmd=%s tx_seq=0x%0h", pl_trdy_control,
             tx_replay_command.name(), tx_seq_num);

    // ---------------------------------------------------------------
    // Phase 6: Resume normal after replay — send more flits
    // ---------------------------------------------------------------
    $display("\n=== PHASE 6: Resume Normal After Replay ===");
    rx_idle();
    write_full_flit(8'h05);
    wait_flit(1);
    write_full_flit(8'h06);
    wait_flit(1);

    // Remote ACKs everything up to flit 4
    send_rx_flit(ack, 8'h04, PAYLOAD);
    wait_flit(2);
    $display("[RESUME] tx_cmd=%s tx_seq=0x%0h pl_trdy=%0b", tx_replay_command.name(), tx_seq_num,
             pl_trdy_control);
    // --- Assertion: after replay done + ACK, normal ops → pl_trdy=0 ---
    assert_chk("P6:RESUME", "pl_trdy", pl_trdy_control, 0);
    assert_chk("P6:RESUME", "rdi_retrain", rdi_retrain, 0);

$stop;
    // ---------------------------------------------------------------
    // Phase 7: Bad sequence number from remote → NAK + discard
    // ---------------------------------------------------------------
    $display("\n=== PHASE 7: Bad Seq Number → NAK + Discard ===");
    // Send a flit with way-out-of-range seq
    send_rx_flit(ack, 8'hF0, PAYLOAD);
    wait_flit(2);
    $display("[BAD SEQ] discard_payload=%0b", discard_payload);
    // --- Assertion: bad seq → payload discarded ---
    assert_chk("P7:BADSEQ", "discard_payload", discard_payload, 1);

    // ---------------------------------------------------------------
    // Phase 8: Duplicate seq from remote → discard
    // ---------------------------------------------------------------
    $display("\n=== PHASE 8: Duplicate Seq → Discard ===");
    // seq 1 was already ACK'd — sending it again is a duplicate
    send_rx_flit(ack, 8'h01, PAYLOAD);
    wait_flit(2);
    $display("[DUP SEQ] discard_payload=%0b", discard_payload);
    // --- Assertion: duplicate seq → payload discarded ---
    assert_chk("P8:DUP", "discard_payload", discard_payload, 1);

    // ---------------------------------------------------------------
    // Phase 9: Explicit with seq=0 in NORMAL → error
    // ---------------------------------------------------------------
    $display("\n=== PHASE 9: Explicit seq=0 in Normal → Error ===");
    send_rx_flit(explicit, 8'h00, NOP);
    wait_flit(2);
    $display("[EXPL 0] discard_flit=%0b log_uie=%0b", discard_flit, log_uie);
    // --- Assertion: explicit seq=0 in NORMAL → discard + log_uie ---
    assert_chk("P9:EXPL0", "discard_flit", discard_flit, 1);
    assert_chk("P9:EXPL0", "log_uie", log_uie, 1);
    assert_chk("P9:EXPL0", "phase", dut.u_transmitter_rules.o_tx_phase, NORMAL_EXCHANGE);

    // ---------------------------------------------------------------
    // Phase 10: Second NAK → another replay cycle
    // ---------------------------------------------------------------
    $display("\n=== PHASE 10: Second NAK → Replay Cycle 2 ===");
    // Send more data first
    write_full_flit(8'h07);
    wait_flit(1);
    write_full_flit(8'h08);
    wait_flit(1);

    // NAK from seq 5 — replay from flit 5 onward
    send_rx_flit(nak, 8'h05, PAYLOAD);
    wait_flit(1);
    $display("[NAK2] tx_cmd=%s tx_seq=0x%0h pl_trdy=%0b", tx_replay_command.name(), tx_seq_num,
             pl_trdy_control);

    // Let replay run
    repeat (20) begin
      wait_flit(1);
      $display("  [REPLAY2] tx_seq=%3d tx_cmd=%-8s pl_trdy=%0b", tx_seq_num,
               tx_replay_command.name(), pl_trdy_control);
    end

    // ---------------------------------------------------------------
    // Phase 11: Flush / Drain
    // ---------------------------------------------------------------
    $display("\n=== PHASE 11: Buffer Flush & Drain ===");
    flush = 1;
    wait_flit(2);
    flush = 0;
    $display("[FLUSH] o_data[15:0]=0x%04h o_stream=0x%0h", tx_o_data[15:0], tx_o_stream);

    drain = 1;
    wait_flit(2);
    drain = 0;
    $display("[DRAIN] o_data[15:0]=0x%04h o_stream=0x%0h", tx_o_data[15:0], tx_o_stream);

    // ---------------------------------------------------------------
    // Phase 12: Deactivate TX/RX → back to R_IDLE
    // ---------------------------------------------------------------
    $display("\n=== PHASE 12: Deactivate → R_IDLE ===");
    tx_en = 0;
    wait_flit(2);
    $display("[TX OFF] tx_cmd=%s tx_seq=0x%0h pl_trdy=%0b", tx_replay_command.name(), tx_seq_num,
             pl_trdy_control);
    // --- Assertion: tx_en=0 → back to R_IDLE defaults ---
    assert_chk("P12:TXOFF", "tx_cmd", tx_replay_command, explicit);
    assert_chk("P12:TXOFF", "tx_seq", tx_seq_num, 0);

    rx_en = 0;
    wait_flit(2);
    $display("[RX OFF] discard_flit=%0b discard_payload=%0b", discard_flit, discard_payload);
    // --- Assertion: rx_en=0 → no stale discards ---
    assert_chk("P12:RXOFF", "discard_flit", discard_flit, 0);
    assert_chk("P12:RXOFF", "discard_pay", discard_payload, 0);

    // ---------------------------------------------------------------
    // Phase 13: Re-init — clean restart
    // ---------------------------------------------------------------
    $display("\n=== PHASE 13: Re-Init Recovery ===");
    init = 0;
    repeat (4) @(posedge clk);
    init = 1;
    fdi_active = 0;
    tx_en = 1;
    rx_en = 1;
    wait_flit(3);
    $display("[REINIT] tx_cmd=%s tx_seq=0x%0h pl_trdy=%0b", tx_replay_command.name(), tx_seq_num,
             pl_trdy_control);
    // --- Assertion: after reinit with tx_en=1, fdi_active=0 → SNH ---
    assert_chk("P13:REINIT", "tx_cmd", tx_replay_command, explicit);
    assert_chk("P13:REINIT", "tx_seq", tx_seq_num, 8'hFF);
    assert_chk("P13:REINIT", "pl_trdy", pl_trdy_control, 1);

    // ---------------------------------------------------------------
    // Done
    // ---------------------------------------------------------------
    repeat (10) @(posedge clk);
    $display("\n================================================================");
    $display("     Simulation Complete");
    $display("     PASSED: %0d   FAILED: %0d   TOTAL: %0d", pass_cnt, fail_cnt,
             pass_cnt + fail_cnt);
    if (fail_cnt == 0) $display("     >>> ALL ASSERTIONS PASSED <<<");
    else $display("     >>> SOME ASSERTIONS FAILED <<<");
    $display("================================================================\n");
    $stop;
  end

  // Watchdog
  initial begin
    #2_000_000;
    $display("[TIMEOUT] Simulation exceeded 2ms");
    $stop;
  end

endmodule

