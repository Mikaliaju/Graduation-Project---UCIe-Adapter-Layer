import UC_retry_pkg::*;
module UC_MB_retry_transmitting_rules_tb;

  // Parameters

  //Ports
  logic clk;
  logic rst_n;
  logic init;
  logic i_snh_done;
  logic i_snh_timeout;
  logic i_replay_scheduled;
  replay_schedule_type_t i_replay_scheduled_type;
  logic i_nak_scheduled;
  nak_schedule_type_t i_nak_schedule_type;
  logic i_consecutive_reset;
  logic [7:0] i_tx_acknak_flit_seq_num;
  logic i_tx_en;
  buffer_state_t i_buffer_state;
  logic i_fdi_active;
  logic i_flit_valid;
  data_rate_t i_data_rate;
  logic [2:0] i_flit_replay_num;
  logic [7:0] i_tx_replay_flit_seq_num;
  logic [7:0] i_nak_ignore_flit_seq_num;
  logic [7:0] i_ackd_flit_seq_num;
  logic [7:0] o_next_tx_flit_seq_num;
  logic [8:0] o_replay_timeout_flit_count;
  replay_command_t o_tx_replay_command;
  logic o_pl_trdy_control;
  logic [7:0] o_tx_seq_num;
  logic o_rdi_retrain;
  logic o_replay_in_progress;
  logic o_log_cie;

  UC_MB_retry_transmitting_rules UC_MB_retry_transmitting_rules_inst (
      .clk(clk),
      .rst_n(rst_n),
      .init(init),
      .i_snh_done(i_snh_done),
      .i_snh_timeout(i_snh_timeout),
      .i_replay_scheduled(i_replay_scheduled),
      .i_replay_scheduled_type(i_replay_scheduled_type),
      .i_nak_scheduled(i_nak_scheduled),
      .i_nak_schedule_type(i_nak_schedule_type),
      .i_consecutive_reset(i_consecutive_reset),
      .i_tx_acknak_flit_seq_num(i_tx_acknak_flit_seq_num),
      .i_tx_en(i_tx_en),
      .i_buffer_state(i_buffer_state),
      .i_fdi_active(i_fdi_active),
      .i_flit_valid(i_flit_valid),
      .i_data_rate(i_data_rate),
      .i_flit_replay_num(i_flit_replay_num),
      .i_tx_replay_flit_seq_num(i_tx_replay_flit_seq_num),
      .i_nak_ignore_flit_seq_num(i_nak_ignore_flit_seq_num),
      .i_ackd_flit_seq_num(i_ackd_flit_seq_num),
      .o_next_tx_flit_seq_num(o_next_tx_flit_seq_num),
      .o_replay_timeout_flit_count(o_replay_timeout_flit_count),
      .o_tx_replay_command(o_tx_replay_command),
      .o_pl_trdy_control(o_pl_trdy_control),
      .o_tx_seq_num(o_tx_seq_num),
      .o_rdi_retrain(o_rdi_retrain),
      .o_replay_in_progress(o_replay_in_progress),
      .o_log_cie(o_log_cie)
  );

  initial begin
    clk = 0;
    forever #10 clk = ~clk;
  end

  initial begin
    reset_values();
    @(negedge clk);
    i_tx_en = 1;
    init = 1;
    rst_n = 1;
    i_flit_valid = 1;
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    i_fdi_active = 1;
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    i_snh_done = 1;
    i_nak_ignore_flit_seq_num = 1;
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    i_nak_scheduled = 1;
    i_nak_ignore_flit_seq_num = 0;
    @(negedge clk);
    @(negedge clk);
    i_nak_scheduled = 0;
    i_nak_ignore_flit_seq_num = 1;
    @(negedge clk);
    @(negedge clk);
    i_replay_scheduled = 1;
    @(posedge o_replay_in_progress) i_replay_scheduled = 0;
    repeat (51 - 12) @(negedge clk);
    $stop;
  end

  task automatic reset_values();
    init                      = 0;
    rst_n                     = 0;
    i_snh_done                = 0;
    i_snh_timeout             = 0;
    i_replay_scheduled        = 0;
    i_replay_scheduled_type   = standard_replay;
    i_nak_scheduled           = 0;
    i_nak_schedule_type       = standard_nak;
    i_consecutive_reset       = 0;
    i_tx_acknak_flit_seq_num  = 0;
    i_tx_en                   = 0;
    i_flit_valid              = 0;
    i_buffer_state            = empty;
    i_fdi_active              = 0;
    i_data_rate               = GTs_32;
    i_flit_replay_num         = 0;
    i_tx_replay_flit_seq_num  = 0;
    i_nak_ignore_flit_seq_num = 0;
    i_ackd_flit_seq_num       = 0;
  endtask

endmodule
