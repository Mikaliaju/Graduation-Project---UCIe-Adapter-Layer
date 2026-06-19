import UC_MB_retry_pkg::*;

module UC_MB_retry_top_tb;

  // -----------------------------------------------------------------------
  // Signals — Global
  // -----------------------------------------------------------------------
  logic                               clk;
  logic                               rst_n;
  logic                               init;

  // -----------------------------------------------------------------------
  // Signals — System
  // -----------------------------------------------------------------------
  logic                               fdi_active;
  logic                               tx_en;
  logic                               rx_en;
  data_rate_t                         data_rate;
  logic                               flit_valid;
  logic                               transmitter_write;
  logic                               flush;
  logic                               drain;

  // -----------------------------------------------------------------------
  // Signals — RX from mainband receiver
  // -----------------------------------------------------------------------
  logic                               rx_crc_error;
  logic            [             7:0] rx_seq_num;
  replay_command_t                    rx_replay_command;
  flit_type_t                         rx_flit_type;

  // -----------------------------------------------------------------------
  // Signals — TX buffer
  // -----------------------------------------------------------------------
  logic            [  DATA_WIDTH-1:0] tx_i_data;
  logic            [STREAM_WIDTH-1:0] tx_i_stream;
  logic            [  DATA_WIDTH-1:0] tx_o_data;
  logic            [STREAM_WIDTH-1:0] tx_o_stream;

  // -----------------------------------------------------------------------
  // Signals — Outputs to transmitter
  // -----------------------------------------------------------------------
  logic                               pl_trdy_control;
  replay_command_t                    tx_replay_command;
  logic            [             7:0] tx_seq_num;

  // -----------------------------------------------------------------------
  // Signals — Error / status
  // -----------------------------------------------------------------------
  logic                               discard_flit;
  logic                               discard_payload;
  logic                               log_uie;
  logic                               log_cie;
  logic                               rdi_retrain;

  // -----------------------------------------------------------------------
  // DUT
  // -----------------------------------------------------------------------
  UC_MB_retry_top dut (
      .clk              (clk),
      .rst_n            (rst_n),
      .init             (init),
      .fdi_active       (fdi_active),
      .tx_en            (tx_en),
      .rx_en            (rx_en),
      .data_rate        (data_rate),
      .flit_valid       (flit_valid),
      .transmitter_write(transmitter_write),
      .flush            (flush),
      .drain            (drain),
      .rx_crc_error     (rx_crc_error),
      .rx_seq_num       (rx_seq_num),
      .rx_replay_command(rx_replay_command),
      .rx_flit_type     (rx_flit_type),
      .tx_i_data        (tx_i_data),
      .tx_i_stream      (tx_i_stream),
      .tx_o_data        (tx_o_data),
      .tx_o_stream      (tx_o_stream),
      .pl_trdy_control  (pl_trdy_control),
      .tx_replay_command(tx_replay_command),
      .tx_seq_num       (tx_seq_num),
      .discard_flit     (discard_flit),
      .discard_payload  (discard_payload),
      .log_uie          (log_uie),
      .log_cie          (log_cie),
      .rdi_retrain      (rdi_retrain)
  );

  // -----------------------------------------------------------------------
  // Clock — 50 MHz
  // -----------------------------------------------------------------------
  initial clk = 0;
  always #10 clk = ~clk;

  // -----------------------------------------------------------------------
  // Reset Task
  // -----------------------------------------------------------------------
  task automatic reset_values();
    rst_n             = 0;
    init              = 0;
    fdi_active        = 0;
    tx_en             = 0;
    rx_en             = 0;
    data_rate         = GTs_32;
    flit_valid        = 0;
    transmitter_write = 0;
    flush             = 0;
    drain             = 0;
    rx_crc_error      = 0;
    rx_seq_num        = 8'h00;
    rx_replay_command = explicit;
    rx_flit_type      = NOP;
    tx_i_data         = '0;
    tx_i_stream       = '0;
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
    rx_en = 1;
    @(negedge clk);
    rx_seq_num = 8'hff;
    rx_replay_command = explicit;
    rx_flit_type = NOP;
    repeat (4) @(negedge clk);
    rx_seq_num = 8'hff;
    rx_replay_command = explicit;
    rx_flit_type = NOP;
    repeat (4) @(negedge clk);
    rx_seq_num = 8'h01;
    rx_replay_command = explicit;
    rx_flit_type = PAYLOAD;
    repeat (4) @(negedge clk);

    // --- Add test scenarios here ---

    repeat (10) @(negedge clk);
    $stop;
  end

endmodule
