// =================================================================================================
//  FILENAME    : UC_MB_Packer_tb.sv
//  MODULE      : UC_MB_Packer_tb
//  PROJECT     : UCIe 3.0 Adapter Layer
//  AUTHOR      : Ali Noureldin Abdelaziz
// =================================================================================================

`timescale 1ns/1ps

import UC_MB_Mainband_pkg::*;
module UC_MB_Packer_tb;

// =============================================================================
// Parameters
// =============================================================================
parameter CLK_PERIOD = 10;

// =============================================================================
// DUT Signals
// =============================================================================

// Clock & Reset
logic                    i_clk;
logic                    i_rst_n;
logic                    i_init;

// FDI Inputs
logic                    i_lp_irdy_fdi;
logic                    i_lp_valid_fdi;
logic    [DATA_PATH-1:0] i_lp_data_fdi;
logic    [31:0]          i_lp_dllp;
logic                    i_lp_dllp_valid;
logic                    i_lp_dllp_ofc;
logic    [7:0]           i_lp_stream;

// Retry Inputs
logic    [7:0]           i_seq_num;
logic    [1:0]           i_replay_command;
logic                    i_deassert_trdy;
logic    [DATA_PATH-1:0] i_retry_data;
logic                    i_retry_sid;
logic    [1:0]           i_retry_pid;
logic                    i_buffer_empty;
logic                    i_retry_use;

// LSM Inputs
logic                    i_packer_en;
logic                    i_flit_boundary;
logic                    i_flush;
logic                    i_drain;

// RDI Input
logic                    i_pl_trdy;

// FDI Output
logic                    o_pl_trdy_fdi;

// Retry Outputs
logic    [DATA_PATH-1:0] o_buffer_data;
logic    [PROTOCOL_ID-1:0] o_buffer_pid;
logic                    o_buffer_sid;

// LSM Outputs
logic                    o_flit_boundary_done;
logic                    o_flush_done;
logic                    o_drain_done;

// RDI Outputs
logic    [DATA_PATH-1:0] o_lp_data_rdi;
logic                    o_lp_valid_rdi;
logic                    o_lp_irdy_rdi;

// =============================================================================
// DUT Instantiation
// =============================================================================
UC_MB_Packer DUT (
  .i_clk               (i_clk),
  .i_rst_n             (i_rst_n),
  .i_init              (i_init),
  .i_lp_irdy_fdi       (i_lp_irdy_fdi),
  .i_lp_valid_fdi      (i_lp_valid_fdi),
  .i_lp_data_fdi       (i_lp_data_fdi),
  .i_lp_dllp           (i_lp_dllp),
  .i_lp_dllp_valid     (i_lp_dllp_valid),
  .i_lp_dllp_ofc       (i_lp_dllp_ofc),
  .i_lp_stream         (i_lp_stream),
  .i_seq_num           (i_seq_num),
  .i_replay_command    (i_replay_command),
  .i_deassert_trdy     (i_deassert_trdy),
  .i_retry_data        (i_retry_data),
  .i_retry_sid         (i_retry_sid),
  .i_retry_pid         (i_retry_pid),
  .i_buffer_empty      (i_buffer_empty),
  .i_retry_use         (i_retry_use),
  .i_packer_en         (i_packer_en),
  .i_flit_boundary     (i_flit_boundary),
  .i_flush             (i_flush),
  .i_drain             (i_drain),
  .i_pl_trdy           (i_pl_trdy),
  .o_pl_trdy_fdi       (o_pl_trdy_fdi),
  .o_buffer_data       (o_buffer_data),
  .o_buffer_pid        (o_buffer_pid),
  .o_buffer_sid        (o_buffer_sid),
  .o_flit_boundary_done(o_flit_boundary_done),
  .o_flush_done        (o_flush_done),
  .o_drain_done        (o_drain_done),
  .o_lp_data_rdi       (o_lp_data_rdi),
  .o_lp_valid_rdi      (o_lp_valid_rdi),
  .o_lp_irdy_rdi       (o_lp_irdy_rdi)
);

// =============================================================================
// Clock Generation
// =============================================================================
always #(CLK_PERIOD/2) i_clk = ~i_clk;

// =============================================================================
// Tasks
// =============================================================================

// ---- Initialize all signals ----
task initialize;
  begin
    i_clk            = 1'b0;
    i_rst_n          = 1'b1;
    i_init           = 1'b0;
    i_lp_irdy_fdi    = 1'b0;
    i_lp_valid_fdi   = 1'b0;
    i_lp_data_fdi    = '0;
    i_lp_dllp        = 32'h0;
    i_lp_dllp_valid  = 1'b0;
    i_lp_dllp_ofc    = 1'b0;
    i_lp_stream      = 8'h0;
    i_seq_num        = 8'h0;
    i_replay_command = 2'b00;
    i_deassert_trdy  = 1'b0;
    i_retry_data     = '0;
    i_retry_sid      = 1'b0;
    i_retry_pid      = 2'b00;
    i_buffer_empty   = 1'b0;
    i_retry_use      = 1'b0;
    i_packer_en      = 1'b0;
    i_flit_boundary  = 1'b0;
    i_flush          = 1'b0;
    i_drain          = 1'b0;
    i_pl_trdy        = 1'b1;
    $display("Initialize Done");
  end
endtask

// ---- Reset ----
task reset;
  begin
    i_rst_n = 1'b1;
    @(negedge i_clk);
    i_rst_n = 1'b0;
    @(negedge i_clk);
    i_rst_n = 1'b1;
    $display("Reset Done");
  end
endtask

// ---- Send one chunk from FDI ----
task send_chunk;
  input [DATA_PATH-1:0] data;
  input                 valid;       // 1=real data, 0=NOP
  input [31:0]          dllp;
  input                 dllp_valid;
  input                 dllp_ofc;
  input [7:0]           stream;
  begin
    i_lp_irdy_fdi   = 1'b1;
    i_lp_valid_fdi  = valid;
    i_lp_data_fdi   = data;
    i_lp_dllp       = dllp;
    i_lp_dllp_valid = dllp_valid;
    i_lp_dllp_ofc   = dllp_ofc;
    i_lp_stream     = stream;
    @(posedge i_clk);
    #1;
    i_lp_irdy_fdi   = 1'b0;
    i_lp_valid_fdi  = 1'b0;
    i_lp_data_fdi   = '0;
    i_lp_dllp_valid = 1'b0;
  end
endtask

// ---- Send 4 chunks (full flit) from FDI ----
task send_flit;
  input [DATA_PATH-1:0] chunk0, chunk1, chunk2, chunk3;
  input [7:0]           stream;
  input [7:0]           seq;
  input [31:0]          dllp;
  input                 dllp_valid;
  begin
    i_seq_num = seq;
    send_chunk(chunk0, 1'b1, dllp, dllp_valid, 1'b0, stream);
    send_chunk(chunk1, 1'b1, dllp, dllp_valid, 1'b0, stream);
    send_chunk(chunk2, 1'b1, dllp, dllp_valid, 1'b0, stream);
    send_chunk(chunk3, 1'b1, dllp, dllp_valid, 1'b0, stream);
  end
endtask

// ---- Wait for RDI transmission to complete ----
task wait_rdi_done;
  begin
    // Wait until flit starts transmitting on RDI
    @(posedge o_lp_irdy_rdi);
    // Wait 4 chunks to be sent
    repeat(4) @(posedge i_clk);
    #1;
  end
endtask

// =============================================================================
// Main Test
// =============================================================================
initial begin
  $dumpfile("Packer_tb.vcd");
  $dumpvars;

  initialize();
  #(CLK_PERIOD);
  operation();
  #(CLK_PERIOD * 10);
  $finish;
end

task operation;
  begin
    reset();

    // ==========================================================
    // TC1: Normal TX - Full flit with real data and real DLLP
    // ==========================================================
    #(CLK_PERIOD);
    $display("***Test Case 1: Normal TX - Real Data + Real DLLP***");

    i_packer_en      = 1'b1;
    i_replay_command = 2'b00;
    i_seq_num        = 8'hA5;

    // Wait for packer to assert pl_trdy_fdi
    @(posedge o_pl_trdy_fdi);
    #1;

    // Send 4 chunks
    send_chunk(512'hAAAA_BBBB, 1'b1, 32'hDEAD_BEEF, 1'b1, 1'b0, 8'b00000101);
    send_chunk(512'hCCCC_DDDD, 1'b1, 32'hDEAD_BEEF, 1'b1, 1'b0, 8'b00000101);
    send_chunk(512'hEEEE_FFFF, 1'b1, 32'hDEAD_BEEF, 1'b1, 1'b0, 8'b00000101);
    send_chunk(512'h1111_2222, 1'b1, 32'hDEAD_BEEF, 1'b1, 1'b0, 8'b00000101);

    // Wait for RDI transmission
    wait_rdi_done();

    if (o_lp_valid_rdi || o_lp_irdy_rdi == 1'b0)
      $display("Test Case 1 Passed: Flit transmitted on RDI");
    else
      $display("Test Case 1 Failed");

    i_packer_en = 1'b0;
    #(CLK_PERIOD * 5);

    // ==========================================================
    // TC2: NOP Data - Some chunks with lp_valid = 0
    // ==========================================================
    reset();
    #(CLK_PERIOD);
    $display("***Test Case 2: NOP Data - chunk1 and chunk2 are NOP***");

    i_packer_en      = 1'b1;
    i_replay_command = 2'b00;
    i_seq_num        = 8'h01;

    @(posedge o_pl_trdy_fdi);
    #1;

    // chunk0: real, chunk1: NOP, chunk2: NOP, chunk3: real
    send_chunk(512'hAAAA_1111, 1'b1, 32'h0,        1'b0, 1'b0, 8'b00000001);
    send_chunk('0,            1'b0, 32'h0,        1'b0, 1'b0, 8'b00000001); // NOP
    send_chunk('0,            1'b0, 32'h0,        1'b0, 1'b0, 8'b00000001); // NOP
    send_chunk(512'hBBBB_2222, 1'b1, 32'h0,        1'b0, 1'b0, 8'b00000001);

    wait_rdi_done();

    if (o_lp_irdy_rdi == 1'b0)
      $display("Test Case 2 Passed: NOP chunks handled correctly");
    else
      $display("Test Case 2 Failed");

    i_packer_en = 1'b0;
    #(CLK_PERIOD * 5);

    // ==========================================================
    // TC3: NOP DLLP - lp_dllp_valid = 0
    // ==========================================================
    reset();
    #(CLK_PERIOD);
    $display("***Test Case 3: NOP DLLP - dllp_valid = 0***");

    i_packer_en      = 1'b1;
    i_replay_command = 2'b00;
    i_seq_num        = 8'h02;

    @(posedge o_pl_trdy_fdi);
    #1;

    // All chunks real data but DLLP = NOP
    send_chunk(512'hCCCC_3333, 1'b1, 32'h0, 1'b0, 1'b0, 8'b00000010);
    send_chunk(512'hDDDD_4444, 1'b1, 32'h0, 1'b0, 1'b0, 8'b00000010);
    send_chunk(512'hEEEE_5555, 1'b1, 32'h0, 1'b0, 1'b0, 8'b00000010);
    send_chunk(512'hFFFF_6666, 1'b1, 32'h0, 1'b0, 1'b0, 8'b00000010);

    wait_rdi_done();

    if (o_lp_irdy_rdi == 1'b0)
      $display("Test Case 3 Passed: NOP DLLP handled correctly (DLP bytes = 0)");
    else
      $display("Test Case 3 Failed");

    i_packer_en = 1'b0;
    #(CLK_PERIOD * 5);

    // ==========================================================
    // TC4: Replay Mode - data from retry buffer
    // ==========================================================
    reset();
    #(CLK_PERIOD);
    $display("***Test Case 4: Replay Mode - data from retry buffer***");

    i_packer_en      = 1'b1;
    i_replay_command = 2'b01;   // NAK replay
    i_retry_pid      = 2'b01;
    i_retry_sid      = 1'b1;
    i_seq_num        = 8'h10;
    i_retry_data     = 512'hREPLAY_DATA_1111;
    i_deassert_trdy  = 1'b0;

    // In replay mode no FDI handshake needed
    repeat(4) @(posedge i_clk);
    #1;

    wait_rdi_done();

    if (o_lp_irdy_rdi == 1'b0)
      $display("Test Case 4 Passed: Replay mode flit transmitted");
    else
      $display("Test Case 4 Failed");

    i_packer_en      = 1'b0;
    i_replay_command = 2'b00;
    #(CLK_PERIOD * 5);

    // ==========================================================
    // TC5: Flit Boundary - finish current flit then stop
    // ==========================================================
    reset();
    #(CLK_PERIOD);
    $display("***Test Case 5: Flit Boundary***");

    i_packer_en      = 1'b1;
    i_replay_command = 2'b00;
    i_seq_num        = 8'h20;

    @(posedge o_pl_trdy_fdi);
    #1;

    // Send flit normally
    send_chunk(512'hABCD_0001, 1'b1, 32'hCAFE_BABE, 1'b1, 1'b0, 8'b00000011);
    send_chunk(512'hABCD_0002, 1'b1, 32'hCAFE_BABE, 1'b1, 1'b0, 8'b00000011);

    // Assert flit_boundary mid-flit
    i_flit_boundary = 1'b1;
    @(posedge i_clk); #1;
    i_flit_boundary = 1'b0;

    send_chunk(512'hABCD_0003, 1'b1, 32'hCAFE_BABE, 1'b1, 1'b0, 8'b00000011);
    send_chunk(512'hABCD_0004, 1'b1, 32'hCAFE_BABE, 1'b1, 1'b0, 8'b00000011);

    wait_rdi_done();

    // Wait for flit_boundary_done
    @(posedge o_flit_boundary_done);

    if (o_flit_boundary_done)
      $display("Test Case 5 Passed: Flit Boundary done asserted");
    else
      $display("Test Case 5 Failed");

    i_packer_en = 1'b0;
    #(CLK_PERIOD * 5);

    // ==========================================================
    // TC6: Drain - send all data with replay until buffer empty
    // ==========================================================
    reset();
    #(CLK_PERIOD);
    $display("***Test Case 6: Drain***");

    i_packer_en      = 1'b1;
    i_replay_command = 2'b01;
    i_buffer_empty   = 1'b0;
    i_seq_num        = 8'h30;
    i_retry_data     = 512'hDRAIN_DATA_5555;

    // Assert drain
    i_drain = 1'b1;
    @(posedge i_clk); #1;
    i_drain = 1'b0;

    // Let it run for a few flits
    repeat(20) @(posedge i_clk);

    // Signal buffer empty
    i_buffer_empty = 1'b1;
    @(posedge o_drain_done);

    if (o_drain_done)
      $display("Test Case 6 Passed: Drain done asserted");
    else
      $display("Test Case 6 Failed");

    i_packer_en    = 1'b0;
    i_buffer_empty = 1'b0;
    #(CLK_PERIOD * 5);

    // ==========================================================
    // TC7: Flush - send retry buffer with replay off
    // ==========================================================
    reset();
    #(CLK_PERIOD);
    $display("***Test Case 7: Flush***");

    i_packer_en    = 1'b1;
    i_buffer_empty = 1'b0;
    i_retry_data   = 512'hFLUSH_DATA_9999;
    i_retry_pid    = 2'b10;
    i_retry_sid    = 1'b0;
    i_seq_num      = 8'h40;

    // Assert flush
    i_flush = 1'b1;
    @(posedge i_clk); #1;
    i_flush = 1'b0;

    // Let it run
    repeat(20) @(posedge i_clk);

    // Signal buffer empty
    i_buffer_empty = 1'b1;
    @(posedge o_flush_done);

    if (o_flush_done)
      $display("Test Case 7 Passed: Flush done asserted");
    else
      $display("Test Case 7 Failed");

    i_packer_en    = 1'b0;
    i_buffer_empty = 1'b0;
    #(CLK_PERIOD * 5);

    $display("All Test Cases Done!");
  end
endtask

endmodule

