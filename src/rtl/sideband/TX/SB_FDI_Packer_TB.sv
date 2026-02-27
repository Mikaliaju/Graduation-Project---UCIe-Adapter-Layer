`timescale 1ns/1ps

module SB_FDI_Packer_TB;

  // Parameters

  localparam int P_IN_W = 32;


  // r_ registers (TB drives)
 
  logic r_clk;
  logic r_rst_n;

  logic [P_IN_W-1:0] r_lp_cfg;
  logic              r_lp_cfg_valid;
  logic              r_full;
  logic [4:0]        r_opcode;

  // w_observed outputs
 
  logic [127:0] w_data_in;
  logic         w_wr_en;
  logic         w_is_config;
  logic         w_read_req;
  logic [4:0]   w_comp_opcode;
  logic         w_fifo_overflow;
  logic         w_opcode_error;

  // DUT

  SB_FDI_Packer #(. P_IN_W (P_IN_W)) dut (
    .i_clk          (r_clk),
    .i_rst_n        (r_rst_n),
    .i_lp_cfg       (r_lp_cfg),
    .i_lp_cfg_valid (r_lp_cfg_valid),
    .i_full         (r_full),
    .i_opcode       (r_opcode),

    .o_data_in        (w_data_in),
    .o_wr_en          (w_wr_en),
    .o_is_config      (w_is_config),
    .o_read_req       (w_read_req),
    .o_comp_opcode    (w_comp_opcode),
    .o_fifo_overflow  (w_fifo_overflow),
    .o_opcode_error   (w_opcode_error)
  );

  -
  // Opcodes
  
  localparam logic [4:0] OP_MEM_RD_32  = 5'b00000;
  localparam logic [4:0] OP_MEM_WR_32  = 5'b00001;
  localparam logic [4:0] OP_MEM_RD_64  = 5'b01000;
  localparam logic [4:0] OP_MEM_WR_64  = 5'b01001;

  localparam logic [4:0] OP_CFG_RD_32  = 5'b00100;
  localparam logic [4:0] OP_CFG_WR_32  = 5'b00101;
  localparam logic [4:0] OP_CFG_RD_64  = 5'b01100;
  localparam logic [4:0] OP_CFG_WR_64  = 5'b01101;


  // Clock
 
  initial r_clk = 1'b0;
  always #5 r_clk = ~r_clk;

 
  // Tasks

  task automatic t_start_pkt(input logic [4:0] i_op);
    begin
      r_opcode = i_op; // keep stable during packet
    end
  endtask

  task automatic t_drive_chunk(input logic [P_IN_W-1:0] i_v);
    begin
      // init
      r_lp_cfg       = i_v;
      r_lp_cfg_valid = 1'b1;
      @(posedge r_clk);
      r_lp_cfg_valid = 1'b0;
      r_lp_cfg       = '0;
      @(posedge r_clk); // gap
    end
  endtask

  task automatic t_wait_wr_en();
    int s_guard;
    begin
      s_guard = 0;
      while (!w_wr_en) begin
        @(posedge r_clk);
        s_guard++;
        if (s_guard > 200) begin
          $display("ERROR: timeout waiting for Wr_en");
          $finish;
        end
      end
    end
  endtask

  task automatic t_wait_overflow();
    int s_guard;
    begin
      s_guard = 0;
      while (!w_fifo_overflow) begin
        @(posedge r_clk);
        s_guard++;
        if (s_guard > 200) begin
          $display("ERROR: timeout waiting for fifo_overflow");
          $finish;
        end
      end
    end
  endtask


  // Monitor
 
  always @(posedge r_clk) begin : mon_init
    // init (nothing required)
    if (w_wr_en) begin
      $display("[%0t] WR: opcode=%05b is_cfg=%0d read=%0d comp=%05b Data[127:0]=%032h",
               $time, r_opcode, w_is_config, w_read_req, w_comp_opcode, w_data_in);
    end
    if (w_opcode_error)  $display("[%0t] ERR: opcode_error", $time);
    if (w_fifo_overflow) $display("[%0t] ERR: fifo_overflow (full=1 at PUSH)", $time);
  end


  // Main

  initial begin
    // init
    r_lp_cfg       = '0;
    r_lp_cfg_valid = 1'b0;
    r_full         = 1'b0;
    r_opcode       = '0;

    // reset
    r_rst_n = 1'b0;
    repeat (3) @(posedge r_clk);
    r_rst_n = 1'b1;
    repeat (2) @(posedge r_clk);


    // TEST 1: MEM_RD_32  (64 bits => 2 chunks of 32)
 
    $display("=== TEST1 MEM_RD_32 ===");
    t_start_pkt(OP_MEM_RD_32);
    t_drive_chunk(32'h1111_0000); // phase0 -> [31:0]
    t_drive_chunk(32'h2222_0000); // phase1 -> [63:32]
    t_wait_wr_en();
    repeat (2) @(posedge r_clk);

    // TEST 2: MEM_WR_32  (96 bits => 3 chunks)
    
    $display("=== TEST2 MEM_WR_32 ===");
    t_start_pkt(OP_MEM_WR_32);
    t_drive_chunk(32'hAAAA_0001); // phase0
    t_drive_chunk(32'hBBBB_0002); // phase1
    t_drive_chunk(32'hCCCC_0003); // data[31:0]
    t_wait_wr_en();
    repeat (2) @(posedge r_clk);

    
    // TEST 3: MEM_WR_64  (128 bits => 4 chunks)
   
    $display("=== TEST3 MEM_WR_64 ===");
    t_start_pkt(OP_MEM_WR_64);
    t_drive_chunk(32'hDEAD_BEEF); // phase0
    t_drive_chunk(32'hFEED_FACE); // phase1
    t_drive_chunk(32'h1234_5678); // data[31:0]
    t_drive_chunk(32'h9ABC_DEF0); // data[63:32]
    t_wait_wr_en();
    repeat (2) @(posedge r_clk);

   
    // TEST 4: CFG_RD_32  (64 bits => 2 chunks)  <-- NEW
    
    $display("=== TEST4 CFG_RD_32 ===");
    t_start_pkt(OP_CFG_RD_32);
    t_drive_chunk(32'h0C0C_0000);
    t_drive_chunk(32'h0D0D_0000);
    t_wait_wr_en();
    repeat (2) @(posedge r_clk);

  
    // TEST 5: CFG_WR_32  (96 bits => 3 chunks)  <-- NEW
   
    $display("=== TEST5 CFG_WR_32 ===");
    t_start_pkt(OP_CFG_WR_32);
    t_drive_chunk(32'h1000_0001);
    t_drive_chunk(32'h2000_0002);
    t_drive_chunk(32'h3000_0003);
    t_wait_wr_en();
    repeat (2) @(posedge r_clk);

    // TEST 6: CFG_RD_64  (64 bits => 2 chunks)  
  
    $display("=== TEST6 CFG_RD_64 ===");
    t_start_pkt(OP_CFG_RD_64);
    t_drive_chunk(32'h4444_0000);
    t_drive_chunk(32'h5555_0000);
    t_wait_wr_en();
    repeat (2) @(posedge r_clk);

   
    // TEST 7: CFG_WR_64  (128 bits => 4 chunks) 
    
    $display("=== TEST7 CFG_WR_64 ===");
    t_start_pkt(OP_CFG_WR_64);
    t_drive_chunk(32'hAAAA_BBBB);
    t_drive_chunk(32'hCCCC_DDDD);
    t_drive_chunk(32'h1111_2222);
    t_drive_chunk(32'h3333_4444);
    t_wait_wr_en();
    repeat (2) @(posedge r_clk);

   
    // TEST 8: INVALID OPCODE (expect opcode_error pulse) 
  
    $display("=== TEST8 INVALID OPCODE ===");
    t_start_pkt(5'b11111);
    t_drive_chunk(32'hDEAD_0001);
   
    repeat (6) @(posedge r_clk);

  
    // TEST 9: FIFO FULL overflow 
    // Keep full=1 LONG ENOUGH so it is still 1 at S_PUSH
 
    $display("=== TEST9 FIFO FULL overflow ===");
    r_full = 1'b1;
    t_start_pkt(OP_MEM_RD_32);
    t_drive_chunk(32'h0101_0101);
    t_drive_chunk(32'h0202_0202);
    // wait overflow pulse (instead of dropping full early)
    t_wait_overflow();
    r_full = 1'b0;
    repeat (4) @(posedge r_clk);

    $display("=== DONE ===");
    $finish;
  end

endmodule