// =================================================================================================
//  FILENAME    : UC_MB_Unpacker_tb.sv
//  MODULE      : UC_MB_Unpacker_tb
//  PROJECT     : UCIe 3.0 Adapter Layer
//  AUTHOR      : Ali Noureldin Abdelaziz
// =================================================================================================
`timescale 1ns/1ps

module UC_MB_Unpacker_tb;

  // =====================================================
  // Signals
  // =====================================================

  logic         i_clk;
  logic         i_rst_n;

  logic [511:0] i_pl_data_rdi;
  logic         i_pl_valid_rdi;

  logic         i_check_pass;
  logic         i_discarded_flit;

  logic         i_stop_stream;
  logic         i_unpacker_en;

  logic [511:0] o_pl_data_fdi;
  logic         o_pl_valid_fdi;

  logic [7:0]   o_pl_stream;

  logic [31:0]  o_pl_dllp;
  logic         o_pl_dllp_valid;
  logic         o_pl_dllp_ofc;

  logic         o_flit_cancel;

  logic [7:0]   o_seq_num;
  logic [1:0]   o_replay_com;

  logic         o_crc_err;

  // =====================================================
  // DUT
  // =====================================================

  UC_MB_Unpacker DUT (

      .i_clk(i_clk),
      .i_rst_n(i_rst_n),

      .i_pl_data_rdi(i_pl_data_rdi),
      .i_pl_valid_rdi(i_pl_valid_rdi),

      .i_check_pass(i_check_pass),
      .i_discarded_flit(i_discarded_flit),

      .i_stop_stream(i_stop_stream),
      .i_unpacker_en(i_unpacker_en),

      .o_pl_data_fdi(o_pl_data_fdi),
      .o_pl_valid_fdi(o_pl_valid_fdi),

      .o_pl_stream(o_pl_stream),

      .o_pl_dllp(o_pl_dllp),
      .o_pl_dllp_valid(o_pl_dllp_valid),
      .o_pl_dllp_ofc(o_pl_dllp_ofc),

      .o_flit_cancel(o_flit_cancel),

      .o_seq_num(o_seq_num),
      .o_replay_com(o_replay_com),

      .o_crc_err(o_crc_err)
  );

  // =====================================================
  // Clock Generation
  // =====================================================

  initial begin
      i_clk = 0;
      forever #5 i_clk = ~i_clk;
  end

  // =====================================================
  // INITIALIZE
  // =====================================================

  task initialize;
  begin

      i_rst_n            = 1'b1;

      i_pl_data_rdi      = '0;
      i_pl_valid_rdi     = 1'b0;

      i_check_pass       = 1'b1;
      i_discarded_flit   = 1'b0;

      i_stop_stream      = 1'b0;
      i_unpacker_en      = 1'b0;

  end
  endtask

  // =====================================================
  // RESET
  // =====================================================

  task reset_dut;
  begin

      @(negedge i_clk);
      i_rst_n = 1'b0;

      @(negedge i_clk);

      i_rst_n = 1'b1;

      @(negedge i_clk);

  end
  endtask

  // =====================================================
  // TASK : NORMAL RX
  // =====================================================

  task normal_rx;
  begin

      i_unpacker_en = 1'b1;

      repeat(4) begin
          @(negedge i_clk);
      end

      i_pl_valid_rdi = 1'b1;

      // =================================================
      // CHUNK 0
      // =================================================

      i_pl_data_rdi = {64{8'h11}};

      @(negedge i_clk);

      // =================================================
      // CHUNK 1
      // =================================================

      i_pl_data_rdi = {64{8'h22}};

      @(negedge i_clk);

      // =================================================
      // CHUNK 2
      // =================================================

      i_pl_data_rdi = {64{8'h33}};

      @(negedge i_clk);

      // =================================================
      // CHUNK 3
      // =================================================

      i_pl_data_rdi = '0;

      // Payload 44B = AA
      i_pl_data_rdi[351:0] = {44{8'hAA}};

      // FH_B0
      // PID      = 2'b10
      // SID      = 1'b1
      // OFC      = 1'b1
      // SEQ[7:4] = 4'hA
      //
      // 10111010 = 8'hBA

      i_pl_data_rdi[359:352] = 8'hBA;

      // FH_B1
      // FlitType = 2'b00
      // Replay   = 2'b10
      // SEQ[3:0] = 4'h5
      //
      // 00100101 = 8'h25

      i_pl_data_rdi[367:360] = 8'h25;

      // DLLP

      i_pl_data_rdi[399:368] = 32'hDEADBEEF;

      // Reserved

      i_pl_data_rdi[479:400] = 80'h0;

      // CRC0

      i_pl_data_rdi[495:480] = 16'h4968;

      // CRC1

      i_pl_data_rdi[511:496] = 16'h3832;

      @(negedge i_clk);

      // =================================================
      // STOP INPUT
      // =================================================

      i_pl_valid_rdi = 1'b0;
      i_pl_data_rdi  = '0;

      repeat(10) @(negedge i_clk);

      $display("NORMAL RX DONE");

  end
  endtask

  // =====================================================
  // TEST SEQUENCE
  // =====================================================

  initial begin

      initialize();

      reset_dut();

      normal_rx();

      repeat(20) @(negedge i_clk);

      $stop;

  end

endmodule
