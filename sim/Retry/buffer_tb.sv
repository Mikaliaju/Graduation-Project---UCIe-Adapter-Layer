import UC_retry_pkg::*;

module UC_MB_retry_buffer_tb;

  // -----------------------------------------------------------------------
  // Signals
  // -----------------------------------------------------------------------
  logic                             clk;
  logic                             rst_n;
  logic                             init;
  phase_t                           i_phase;
  logic          [             7:0] i_tx_replay_flit_seq_num;
  logic          [             7:0] i_ackd_flit_seq_num;
  logic                             i_replay_scheduled;
  logic                             i_replay_in_progress;
  logic                             i_flush;
  logic                             i_drain;
  logic                             i_pl_trdy_control;
  logic                             i_transmitter_write;
  logic          [             7:0] i_next_tx_flit_seq_num;
  logic          [  DATA_WIDTH-1:0] i_data;
  logic          [STREAM_WIDTH-1:0] i_stream;

  logic          [  DATA_WIDTH-1:0] o_data;
  logic          [STREAM_WIDTH-1:0] o_stream;
  buffer_state_t                    o_buffer_state;

  // -----------------------------------------------------------------------
  // DUT
  // -----------------------------------------------------------------------
  UC_MB_retry_buffer dut (
      .clk                     (clk),
      .rst_n                   (rst_n),
      .init                    (init),
      .i_phase                 (i_phase),
      .i_tx_replay_flit_seq_num(i_tx_replay_flit_seq_num),
      .i_ackd_flit_seq_num     (i_ackd_flit_seq_num),
      .i_replay_scheduled      (i_replay_scheduled),
      .i_replay_in_progress    (i_replay_in_progress),
      .i_flush                 (i_flush),
      .i_drain                 (i_drain),
      .i_pl_trdy_control       (i_pl_trdy_control),
      .i_transmitter_write     (i_transmitter_write),
      .i_next_tx_flit_seq_num  (i_next_tx_flit_seq_num),
      .i_data                  (i_data),
      .i_stream                (i_stream),
      .o_data                  (o_data),
      .o_stream                (o_stream),
      .o_buffer_state          (o_buffer_state)
  );

  // -----------------------------------------------------------------------
  // Clock
  // -----------------------------------------------------------------------
  initial clk = 0;
  always #10 clk = ~clk;

  // -----------------------------------------------------------------------
  // Reset Task
  // -----------------------------------------------------------------------
  task automatic reset_values();
    rst_n                    = 0;
    init                     = 0;
    i_phase                  = R_IDLE;
    i_tx_replay_flit_seq_num = 0;
    i_ackd_flit_seq_num      = 0;
    i_replay_scheduled       = 0;
    i_replay_in_progress     = 0;
    i_flush                  = 0;
    i_drain                  = 0;
    i_pl_trdy_control        = 0;
    i_next_tx_flit_seq_num   = 8'h01;
    i_data                   = '0;
    i_stream                 = '0;
    i_transmitter_write      = 0;
  endtask

  // -----------------------------------------------------------------------
  // Test Stimulus
  // -----------------------------------------------------------------------
  initial begin
    reset_values();
    @(negedge clk);
    rst_n = 1;
    init  = 1;
    @(negedge clk);
    i_phase = SNH;
    i_replay_scheduled = 0;
    i_next_tx_flit_seq_num = 3;
    i_transmitter_write = 1;
    i_data = 512'h1234567890ABCDEF;
    i_stream = 5'b10101;
    @(negedge clk);
    i_data   = {512{1'b1}};
    i_stream = 5'b10101;
    @(negedge clk);
    i_data   = 512'h2222222222222222;
    i_stream = 5'b10101;
    @(negedge clk);
    i_data   = 512'h3333333333333333;
    i_stream = 5'b10101;
    @(negedge clk);
    i_data = '0;
    i_stream = '0;
    i_tx_replay_flit_seq_num = 3;
    i_replay_scheduled = 1;
    @(negedge clk);
    i_replay_scheduled   = 0;
    i_replay_in_progress = 1;
    repeat (10) @(negedge clk);
    i_replay_in_progress = 0;
    i_transmitter_write = 1;
    i_next_tx_flit_seq_num = 4;
    i_data = {512{1'b1}};
    i_stream = 5'b10001;
    @(negedge clk);
    i_data = {512{1'b1}};
    i_stream = 5'b10001;
    repeat (2) @(negedge clk);
    i_transmitter_write = 0;
    i_ackd_flit_seq_num = 4;
    repeat (10) @(negedge clk);
    $stop;
  end

endmodule
