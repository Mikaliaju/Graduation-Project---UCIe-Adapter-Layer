// =================================================================================================
//  FILENAME    : UC_MB_Unpacker_tb.sv
//  MODULE      : UC_MB_Unpacker_tb
//  PROJECT     : UCIe 3.0 Adapter Layer
//  AUTHOR      : Ali Noureldin Abdelaziz
// =================================================================================================

`timescale 1ns/1ps

import UC_MB_Mainband_pkg::*;
module UC_MB_Unpacker_tb;

// =============================================================================
// Parameters
// =============================================================================
parameter CLK_PERIOD = 10;

// Chunk 3 field positions (relative bit offsets)
localparam C3_FH_B0_TB = 352;
localparam C3_FH_B1_TB = 360;
localparam C3_DLP_TB   = 368;
localparam C3_RSV_TB   = 400;
localparam C3_CRC0_TB  = 480;
localparam C3_CRC1_TB  = 496;

// =============================================================================
// DUT Signals
// =============================================================================

// Clock & Reset
logic                      i_clk;
logic                      i_rst_n;
logic                      i_init;

// RDI Inputs
logic    [DATA_PATH-1:0]   i_pl_data_rdi;
logic                      i_pl_valid_rdi;

// Retry Inputs
logic                      i_check_pass;
logic                      i_discarded_flit;

// LSM Inputs
logic                      i_unpacker_en;
logic                      i_stop_stream;

// FDI Outputs
logic    [DATA_PATH-1:0]   o_pl_data_fdi;
logic                      o_pl_valid_fdi;
logic    [7:0]             o_pl_stream;
logic    [DLLP-1:0]        o_pl_dllp;
logic                      o_pl_dllp_valid;
logic                      o_pl_dllp_ofc;
logic                      o_flit_cancel;

// Retry Outputs
logic    [SEQUENS_NUM-1:0] o_seq_num;
logic    [REPLAY_CMD-1:0]  o_replay_com;
logic                      o_crc_err;

// =============================================================================
// DUT Instantiation
// =============================================================================
UC_MB_Unpacker DUT (
  .i_clk            (i_clk),
  .i_rst_n          (i_rst_n),
  .i_init           (i_init),
  .i_pl_data_rdi    (i_pl_data_rdi),
  .i_pl_valid_rdi   (i_pl_valid_rdi),
  .i_check_pass     (i_check_pass),
  .i_discarded_flit (i_discarded_flit),
  .i_unpacker_en    (i_unpacker_en),
  .i_stop_stream    (i_stop_stream),
  .o_pl_data_fdi    (o_pl_data_fdi),
  .o_pl_valid_fdi   (o_pl_valid_fdi),
  .o_pl_stream      (o_pl_stream),
  .o_pl_dllp        (o_pl_dllp),
  .o_pl_dllp_valid  (o_pl_dllp_valid),
  .o_pl_dllp_ofc    (o_pl_dllp_ofc),
  .o_flit_cancel    (o_flit_cancel),
  .o_seq_num        (o_seq_num),
  .o_replay_com     (o_replay_com),
  .o_crc_err        (o_crc_err)
);

// =============================================================================
// Clock Generation
// =============================================================================
always #(CLK_PERIOD/2) i_clk = ~i_clk;

// =============================================================================
// Helper Function: Build chunk3 with FH, DLP, CRC fields
// =============================================================================
function automatic [DATA_PATH-1:0] build_chunk3;
  input [DATA_PATH-1:0] payload_44b;   // 44B payload (bits 351:0)
  input [1:0]           pid;
  input                 sid;
  input                 ofc;
  input [7:0]           seq_num;
  input [1:0]           replay_cmd;
  input [31:0]          dllp;
  input [15:0]          crc0;
  input [15:0]          crc1;
  logic [DATA_PATH-1:0] chunk;
  begin
    chunk                          = '0;
    chunk[351:0]                   = payload_44b[351:0];
    chunk[C3_FH_B0_TB +: 8]       = {pid, sid, ofc, seq_num[7:4]};
    chunk[C3_FH_B1_TB +: 8]       = {2'b00, replay_cmd, seq_num[3:0]};
    chunk[C3_DLP_TB   +: 32]      = dllp;
    chunk[C3_RSV_TB   +: 80]      = 80'h0;
    chunk[C3_CRC0_TB  +: 16]      = crc0;
    chunk[C3_CRC1_TB  +: 16]      = crc1;
    build_chunk3                   = chunk;
  end
endfunction

// =============================================================================
// Tasks
// =============================================================================

// ---- Initialize ----
task initialize;
  begin
    i_clk            = 1'b0;
    i_rst_n          = 1'b1;
    i_init           = 1'b1;
    i_pl_data_rdi    = '0;
    i_pl_valid_rdi   = 1'b0;
    i_check_pass     = 1'b0;
    i_discarded_flit = 1'b0;
    i_unpacker_en    = 1'b0;
    i_stop_stream    = 1'b0;
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

// ---- Send one chunk from RDI ----
task send_rdi_chunk;
  input [DATA_PATH-1:0] data;
  begin
    i_pl_data_rdi  = data;
    i_pl_valid_rdi = 1'b1;
    @(posedge i_clk);
    #1;
  end
endtask

// ---- Send full flit (4 chunks) with correct chunk3 ----
task send_flit;
  input [DATA_PATH-1:0] chunk0, chunk1, chunk2;
  input [DATA_PATH-1:0] payload_44b;
  input [1:0]           pid;
  input                 sid;
  input                 ofc;
  input [7:0]           seq_num;
  input [1:0]           replay_cmd;
  input [31:0]          dllp;
  input [15:0]          crc0;
  input [15:0]          crc1;
  logic [DATA_PATH-1:0] chunk3;
  begin
    chunk3 = build_chunk3(payload_44b, pid, sid, ofc, seq_num, replay_cmd, dllp, crc0, crc1);
    send_rdi_chunk(chunk0);
    send_rdi_chunk(chunk1);
    send_rdi_chunk(chunk2);
    send_rdi_chunk(chunk3);
    i_pl_valid_rdi = 1'b0;
  end
endtask

// ---- Wait for S_CHECK cycle ----
task wait_check;
  begin
    // After 4 chunks received, S_CHECK is next cycle
    @(posedge i_clk);
    #1;
  end
endtask

// =============================================================================
// Main Test
// =============================================================================
initial begin
  $dumpfile("Unpacker_tb.vcd");
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
    // TC1: Normal RX - Valid flit with correct CRC
    //      Expected: no flit_cancel, no crc_err
    // ==========================================================
    #(CLK_PERIOD);
    $display("***Test Case 1: Normal RX - Correct CRC***");

    i_unpacker_en    = 1'b1;
    i_discarded_flit = 1'b0;
    i_check_pass     = 1'b1;

    // Note: CRC values here are dummy ? in real sim they should match computed CRC
    send_flit(
      512'hAAAA_1111_BBBB_2222,   // chunk0
      512'hCCCC_3333_DDDD_4444,   // chunk1
      512'hEEEE_5555_FFFF_6666,   // chunk2
      512'h1234_5678_9ABC_DEF0,   // payload 44B
      2'b01,                       // pid
      1'b1,                        // sid
      1'b0,                        // ofc
      8'hA5,                       // seq_num
      2'b00,                       // replay_cmd
      32'hDEAD_BEEF,               // dllp
      16'h0000,                    // crc0 (will cause err if not matching computed)
      16'h0000                     // crc1
    );

    wait_check();

    if (!o_flit_cancel && !o_crc_err)
      $display("Test Case 1 Passed: No error detected");
    else
      $display("Test Case 1 Failed: Unexpected error");

    i_unpacker_en = 1'b0;
    #(CLK_PERIOD * 3);

    // ==========================================================
    // TC2: CRC Error - Wrong CRC values in flit
    //      Expected: crc_err=1, flit_cancel=1
    // ==========================================================
    reset();
    #(CLK_PERIOD);
    $display("***Test Case 2: CRC Error - Wrong CRC***");

    i_unpacker_en    = 1'b1;
    i_discarded_flit = 1'b0;
    i_check_pass     = 1'b0;

    // Send flit with intentionally wrong CRC values
    send_flit(
      512'hAAAA_BBBB_CCCC_DDDD,
      512'hEEEE_FFFF_1111_2222,
      512'h3333_4444_5555_6666,
      512'h7777_8888_9999_AAAA,
      2'b10,
      1'b0,
      1'b0,
      8'h55,
      2'b00,
      32'hCAFE_BABE,
      16'hDEAD,    // Wrong CRC0
      16'hBEEF     // Wrong CRC1
    );

    wait_check();

    if (o_crc_err && o_flit_cancel)
      $display("Test Case 2 Passed: CRC error detected, flit_cancel asserted");
    else
      $display("Test Case 2 Failed");

    i_unpacker_en = 1'b0;
    #(CLK_PERIOD * 3);

    // ==========================================================
    // TC3: Cut-through Forwarding Check
    //      Expected: chunk0 forwarded in cycle2, chunk1 in cycle3...
    // ==========================================================
    reset();
    #(CLK_PERIOD);
    $display("***Test Case 3: Cut-through Forwarding***");

    i_unpacker_en    = 1'b1;
    i_discarded_flit = 1'b0;
    i_check_pass     = 1'b1;

    // Send chunk0
    send_rdi_chunk(512'hAAAA_0001);

    // In cycle2: chunk0 should appear on o_pl_data_fdi
    send_rdi_chunk(512'hBBBB_0002);

    if (o_pl_valid_fdi && o_pl_data_fdi == 512'hAAAA_0001)
      $display("Test Case 3: chunk0 forwarded correctly in cycle2");
    else
      $display("Test Case 3: chunk0 forwarding failed");

    // Continue sending rest of flit
    send_rdi_chunk(512'hCCCC_0003);
    send_rdi_chunk(build_chunk3(512'hDDDD_0004, 2'b01, 1'b0, 1'b0, 8'h01, 2'b00, 32'h0, 16'h0, 16'h0));
    i_pl_valid_rdi = 1'b0;

    wait_check();

    $display("Test Case 3 Done");
    i_unpacker_en = 1'b0;
    #(CLK_PERIOD * 3);

    // ==========================================================
    // TC4: Sequence Error - discarded_flit from retry
    //      Expected: flit_cancel=1
    // ==========================================================
    reset();
    #(CLK_PERIOD);
    $display("***Test Case 4: Sequence Error - discarded_flit***");

    i_unpacker_en    = 1'b1;
    i_discarded_flit = 1'b0;
    i_check_pass     = 1'b0;

    send_flit(
      512'h1111_AAAA,
      512'h2222_BBBB,
      512'h3333_CCCC,
      512'h4444_DDDD,
      2'b00,
      1'b0,
      1'b0,
      8'h10,
      2'b01,
      32'h0,
      16'h0,
      16'h0
    );

    // Assert discarded_flit in S_CHECK cycle
    i_discarded_flit = 1'b1;
    wait_check();
    i_discarded_flit = 1'b0;

    if (o_flit_cancel)
      $display("Test Case 4 Passed: flit_cancel asserted on sequence error");
    else
      $display("Test Case 4 Failed");

    i_unpacker_en = 1'b0;
    #(CLK_PERIOD * 3);

    // ==========================================================
    // TC5: Stop Stream - stop_stream asserted mid-receive
    //      Expected: FSM goes back to S_START
    // ==========================================================
    reset();
    #(CLK_PERIOD);
    $display("***Test Case 5: Stop Stream***");

    i_unpacker_en  = 1'b1;
    i_stop_stream  = 1'b0;

    // Send 2 chunks then assert stop_stream
    send_rdi_chunk(512'hAAAA_5555);
    send_rdi_chunk(512'hBBBB_6666);

    i_stop_stream  = 1'b1;
    i_pl_valid_rdi = 1'b0;
    @(posedge i_clk); #1;
    i_stop_stream  = 1'b0;

    // Check unpacker went back to idle (no valid output)
    if (!o_pl_valid_fdi && !o_flit_cancel)
      $display("Test Case 5 Passed: Stop stream handled correctly");
    else
      $display("Test Case 5 Failed");

    i_unpacker_en = 1'b0;
    #(CLK_PERIOD * 3);

    // ==========================================================
    // TC6: DLLP Extraction - verify DLP bytes extracted correctly
    //      Expected: o_pl_dllp = 32'hCAFE_1234, o_pl_dllp_valid=1
    // ==========================================================
    reset();
    #(CLK_PERIOD);
    $display("***Test Case 6: DLLP Extraction***");

    i_unpacker_en    = 1'b1;
    i_discarded_flit = 1'b0;
    i_check_pass     = 1'b1;

    send_flit(
      512'hAAAA_6666,
      512'hBBBB_7777,
      512'hCCCC_8888,
      512'hDDDD_9999,
      2'b11,
      1'b1,
      1'b1,          // OFC = 1
      8'h33,
      2'b00,
      32'hCAFE_1234,  // DLLP value to check
      16'h0,
      16'h0
    );

    wait_check();

    if (o_pl_dllp == 32'hCAFE_1234 && o_pl_dllp_valid)
      $display("Test Case 6 Passed: DLLP extracted correctly = 0x%h", o_pl_dllp);
    else
      $display("Test Case 6 Failed: DLLP = 0x%h", o_pl_dllp);

    i_unpacker_en = 1'b0;
    #(CLK_PERIOD * 3);

    // ==========================================================
    // TC7: Consecutive Flits - two flits back to back
    //      Expected: both flits processed correctly, no gap
    // ==========================================================
    reset();
    #(CLK_PERIOD);
    $display("***Test Case 7: Consecutive Flits***");

    i_unpacker_en    = 1'b1;
    i_discarded_flit = 1'b0;
    i_check_pass     = 1'b1;

    // ---- Flit 1 ----
    send_flit(
      512'hFLIT1_C0,
      512'hFLIT1_C1,
      512'hFLIT1_C2,
      512'hFLIT1_C3,
      2'b01,
      1'b0,
      1'b0,
      8'h01,
      2'b00,
      32'hAAAA_1111,
      16'h0,
      16'h0
    );

    wait_check();

    $display("TC7: Flit 1 processed - cancel=%b err=%b", o_flit_cancel, o_crc_err);

    // ---- Flit 2 (back to back) ----
    send_flit(
      512'hFLIT2_C0,
      512'hFLIT2_C1,
      512'hFLIT2_C2,
      512'hFLIT2_C3,
      2'b10,
      1'b1,
      1'b0,
      8'h02,
      2'b00,
      32'hBBBB_2222,
      16'h0,
      16'h0
    );

    wait_check();

    $display("TC7: Flit 2 processed - cancel=%b err=%b", o_flit_cancel, o_crc_err);

    if (!o_flit_cancel)
      $display("Test Case 7 Passed: Consecutive flits processed correctly");
    else
      $display("Test Case 7 Failed");

    i_unpacker_en = 1'b0;
    #(CLK_PERIOD * 3);

    $display("All Test Cases Done!");
  end
endtask

endmodule

