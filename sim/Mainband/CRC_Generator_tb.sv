// =================================================================================================
//  FILENAME    : CRC_Generator_tb.sv
//  MODULE      : CRC_Generator Testbench
//  PROJECT     : UCIe 3.0 Adapter Layer
//  AUTHOR      : Ali Noureldin Abdelaziz
// =================================================================================================
//  DESCRIPTION : Simple testbench to verify CRC_Generator functionality
// =================================================================================================

`timescale 1ns/1ps
module CRC_Generator_tb;

  // ??? Parameters ????????????????????????????????????????????????????????????
  localparam DATA_PATH = 512;   // 64 Bytes per clock
  localparam CRC_SIZE  = 16;
  localparam CLK_PERIOD = 10;   // 10ns clock ? 100MHz

  // ??? DUT Signals ???????????????????????????????????????????????????????????
  logic                    clk;
  logic                    rst_n;
  logic                    crc_payload_valid;
  logic [DATA_PATH-1:0]    crc_payload;
  logic [CRC_SIZE-1:0]     crc0_gen;
  logic [CRC_SIZE-1:0]     crc1_gen;
  logic                    crc_valid;

  // ??? DUT Instantiation ?????????????????????????????????????????????????????
  CRC_Generator dut (
    .i_clk               (clk),
    .i_rst_n             (rst_n),
    .i_crc_payload_valid (crc_payload_valid),
    .i_crc_payload       (crc_payload),
    .o_crc0_gen          (crc0_gen),
    .o_crc1_gen          (crc1_gen),
    .o_crc_valid         (crc_valid)
  );

  // ??? Clock Generation ??????????????????????????????????????????????????????
  initial clk = 0;
  always #(CLK_PERIOD/2) clk = ~clk;

  // ??? Task: Apply Reset ?????????????????????????????????????????????????????
  task apply_reset();
    rst_n             = 0;
    crc_payload_valid = 0;
    crc_payload       = 0;
    repeat(4) @(posedge clk);
    #1;
    rst_n = 1;
    @(posedge clk);
    $display("[%0t] Reset released", $time);
  endtask

  // ??? Task: Send One Full Flit (4 chunks × 64B) ?????????????????????????????
  //   chunk0..chunk3 are the 4 pieces of the 256-Byte flit
  task send_flit(
    input logic [DATA_PATH-1:0] chunk0,
    input logic [DATA_PATH-1:0] chunk1,
    input logic [DATA_PATH-1:0] chunk2,
    input logic [DATA_PATH-1:0] chunk3,
    input string                test_name
  );
    $display("\n[%0t] ?? START: %s ??", $time, test_name);

    // Chunk 0
    @(posedge clk); #1;
    crc_payload_valid = 1;
    crc_payload       = chunk0;
    $display("[%0t]  Chunk 0 sent", $time);

    // Chunk 1
    @(posedge clk); #1;
    crc_payload = chunk1;
    $display("[%0t]  Chunk 1 sent", $time);

    // Chunk 2
    @(posedge clk); #1;
    crc_payload = chunk2;
    $display("[%0t]  Chunk 2 sent", $time);

    // Chunk 3
    @(posedge clk); #1;
    crc_payload = chunk3;
    $display("[%0t]  Chunk 3 sent", $time);

    // De-assert valid
    @(posedge clk); #1;
    crc_payload_valid = 0;
    crc_payload       = 0;

    // Wait for o_crc_valid
    @(posedge clk);
    if (crc_valid) begin
      $display("[%0t]  ? CRC Valid! CRC0 = 0x%04h  |  CRC1 = 0x%04h", $time, crc0_gen, crc1_gen);
    end else begin
      $display("[%0t]  ? ERROR: crc_valid not asserted!", $time);
    end

    $display("[%0t] ?? END: %s ??", $time, test_name);
  endtask

  // ??? Task: Check crc_valid is NOT asserted (idle check) ???????????????????
  task check_no_valid_during_reset();
    $display("\n[%0t] ?? TEST: No output during reset ??", $time);
    rst_n = 0;
    crc_payload_valid = 1;
    crc_payload = {DATA_PATH{1'b1}};
    repeat(4) @(posedge clk);
    if (!crc_valid)
      $display("[%0t]  ? Correct: crc_valid stays 0 during reset", $time);
    else
      $display("[%0t]  ? ERROR: crc_valid asserted during reset!", $time);
    rst_n = 1;
    crc_payload_valid = 0;
    repeat(2) @(posedge clk);
  endtask

  // ??? Main Test Sequence ????????????????????????????????????????????????????
  initial begin
    $dumpfile("crc_gen_tb.vcd");
    $dumpvars(0, CRC_Generator_tb);

    // ?? Test 1: Reset Behavior ????????????????????????????????????????????
    check_no_valid_during_reset();

    // Re-apply clean reset
    apply_reset();

    // ?? Test 2: All-Zeros Flit ????????????????????????????????????????????
    send_flit(
      {DATA_PATH{1'b0}},
      {DATA_PATH{1'b0}},
      {DATA_PATH{1'b0}},
      {DATA_PATH{1'b0}},
      "All-Zeros Flit"
    );

    repeat(2) @(posedge clk);

    // ?? Test 3: All-Ones Flit ?????????????????????????????????????????????
    send_flit(
      {DATA_PATH{1'b1}},
      {DATA_PATH{1'b1}},
      {DATA_PATH{1'b1}},
      {DATA_PATH{1'b1}},
      "All-Ones Flit"
    );

    repeat(2) @(posedge clk);

    // ?? Test 4: Walking-Ones Pattern ??????????????????????????????????????
    send_flit(
      512'hAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA,
      512'h5555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555,
      512'hAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA,
      512'h5555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555,
      "Alternating 0xAA/0x55 Pattern"
    );

    repeat(2) @(posedge clk);

    // ?? Test 5: Two Consecutive Flits (CRC resets between them) ???????????
    $display("\n[%0t] ?? TEST: Two Consecutive Flits ??", $time);

    send_flit(
      512'h0102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F202122232425262728292A2B2C2D2E2F303132333435363738393A3B3C3D3E3F40,
      512'h0102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F202122232425262728292A2B2C2D2E2F303132333435363738393A3B3C3D3E3F40,
      512'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
      512'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
      "Flit #1 of Consecutive Test"
    );

    send_flit(
      512'hDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF,
      512'hDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF,
      512'hCAFEBABECAFEBABECAFEBABECAFEBABECAFEBABECAFEBABECAFEBABECAFEBABECAFEBABECAFEBABECAFEBABECAFEBABECAFEBABECAFEBABECAFEBABECAFEBABE,
      512'hCAFEBABECAFEBABECAFEBABECAFEBABECAFEBABECAFEBABECAFEBABECAFEBABECAFEBABECAFEBABECAFEBABECAFEBABECAFEBABECAFEBABECAFEBABECAFEBABE,
      "Flit #2 of Consecutive Test"
    );

    repeat(4) @(posedge clk);

    $display("\n ??????????????????????????????????");
    $display("All tests done!");
    $display("[%0t] ??????????????????????????????????\n", $time);
    $stop;
  end

endmodule

