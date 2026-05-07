`timescale 1ns/1ps

module UC_MB_Packer_tb;

    import UC_MB_Mainband_pkg::*;

    // =========================================================
    // CLOCK
    // =========================================================

    logic i_clk;

    always #5 i_clk = ~i_clk;

    // =========================================================
    // INPUTS
    // =========================================================

    logic         i_rst_n;
    logic         i_init;

    logic         i_lp_irdy_fdi;
    logic         i_lp_valid_fdi;
    logic [511:0] i_lp_data_fdi;

    logic [31:0]  i_lp_dllp;
    logic         i_lp_dllp_valid;
    logic         i_lp_dllp_ofc;

    logic [7:0]   i_lp_stream;

    logic         i_pl_trdy;

    logic         i_packer_en;
    logic         i_stop_stream;

    logic [7:0]   i_seq_num;
    logic [1:0]   i_replay_command;

    logic         i_deassert_trdy;

    logic         i_retry_use;
    logic [511:0] i_retry_data;
    logic         i_retry_sid;
    logic [1:0]   i_retry_pid;

    logic         i_buffer_empty;

    logic         i_flit_boundary;
    logic         i_drain;
    logic         i_flush;

    // =========================================================
    // OUTPUTS
    // =========================================================

    logic         o_pl_trdy_fdi;

    logic         o_clean_boundary;

    logic [511:0] o_lp_data_rdi;
    logic         o_lp_valid_rdi;
    logic         o_lp_irdy_rdi;

    logic [511:0] o_buffer_data;
    logic [1:0]   o_buffer_pid;
    logic         o_buffer_sid;

    // =========================================================
    // DUT
    // =========================================================

    UC_MB_Packer DUT (

        .i_clk                (i_clk),
        .i_rst_n              (i_rst_n),

        .i_init             (i_init),

        .i_lp_irdy_fdi      (i_lp_irdy_fdi),
        .i_lp_valid_fdi     (i_lp_valid_fdi),
        .i_lp_data_fdi      (i_lp_data_fdi),

        .i_lp_dllp          (i_lp_dllp),
        .i_lp_dllp_valid    (i_lp_dllp_valid),
        .i_lp_dllp_ofc      (i_lp_dllp_ofc),

        .i_lp_stream        (i_lp_stream),

        .i_pl_trdy          (i_pl_trdy),

        .i_packer_en        (i_packer_en),

        .i_seq_num          (i_seq_num),
        .i_replay_command   (i_replay_command),

        .i_deassert_trdy    (i_deassert_trdy),

        .i_retry_use        (i_retry_use),
        .i_retry_data       (i_retry_data),
        .i_retry_sid        (i_retry_sid),
        .i_retry_pid        (i_retry_pid),

        .i_buffer_empty     (i_buffer_empty),

        .i_flit_boundary    (i_flit_boundary),
        .i_drain            (i_drain),
        .i_flush            (i_flush),

        .o_pl_trdy_fdi      (o_pl_trdy_fdi),

        .o_lp_data_rdi      (o_lp_data_rdi),
        .o_lp_valid_rdi     (o_lp_valid_rdi),
        .o_lp_irdy_rdi      (o_lp_irdy_rdi),

        .o_buffer_data      (o_buffer_data),
        .o_buffer_pid       (o_buffer_pid),
        .o_buffer_sid       (o_buffer_sid)
    );

    // =========================================================
    // TASK : INITIALIZE
    // =========================================================

    task initialize;
    begin

        i_rst_n            = 1'b1;
        i_init             = 1'b1;

        i_lp_irdy_fdi      = 1'b0;
        i_lp_valid_fdi     = 1'b0;
        i_lp_data_fdi      = '0;

        i_lp_dllp          = 32'h0;
        i_lp_dllp_valid    = 1'b0;
        i_lp_dllp_ofc      = 1'b0;

        i_lp_stream        = 8'h0;

        i_pl_trdy          = 1'b1;

        i_packer_en        = 1'b0;
        i_stop_stream      = 1'b0;

        i_seq_num          = 8'h0;
        i_replay_command   = 2'b00;

        i_deassert_trdy    = 1'b0;

        i_retry_use        = 1'b0;
        i_retry_data       = '0;
        i_retry_sid        = 1'b0;
        i_retry_pid        = 2'b00;

        i_buffer_empty     = 1'b0;

        i_flit_boundary    = 1'b0;

i_drain            = 1'b0;
        i_flush            = 1'b0;

        $display("INITIALIZE DONE");

    end
    endtask

    // =========================================================
    // TASK : RESET
    // =========================================================

    task reset_dut;
    begin

        i_rst_n = 1'b1;

        @(negedge i_clk);
        i_rst_n = 1'b0;

        @(negedge i_clk);
        i_rst_n = 1'b1;

        $display("RESET DONE");

    end
    endtask

    // =========================================================
    // TASK : NORMAL TX
    // =========================================================

    task normal_tx;
    begin

        i_packer_en      = 1'b1;
        repeat(4) begin
            @(negedge i_clk);
        end

        i_lp_irdy_fdi    = 1'b1;
        i_lp_data_fdi = {64{8'h11}};
        i_lp_valid_fdi   = 1'b1;

        i_lp_dllp        = 32'hAABBCCDD;
        i_lp_dllp_valid  = 1'b1;
        i_lp_dllp_ofc    = 1'b1;
        i_lp_stream      = 8'b1010_0000;
        i_seq_num        = 8'h5A;
        i_replay_command = 2'b01;

        @(negedge i_clk);

        // PID = 2'b10
        // SID = 1'b1


 // =====================================================
// CHUNK 0
// =====================================================


// @(negedge i_clk);

// =====================================================
// CHUNK 1
// =====================================================

i_lp_data_fdi = {64{8'h22}};

@(negedge i_clk);

// =====================================================
// CHUNK 2
// =====================================================

i_lp_data_fdi = {64{8'h33}};

@(negedge i_clk);

// =====================================================
// CHUNK 3
// only first 44B valid
// =====================================================

i_lp_data_fdi[351:0]   = {44{8'hAA}};
i_lp_data_fdi[511:352] = 160'h0;

@(negedge i_clk);
        // =====================================================
        // STOP INPUT
        // =====================================================

        i_lp_valid_fdi = 1'b0;
        i_lp_irdy_fdi  = 1'b0;
        i_lp_data_fdi  = '0;

        repeat(10) @(negedge i_clk);

        $display("NORMAL TX DONE");

    end
    endtask

    // =========================================================
    // INITIAL
    // =========================================================

    initial begin

        i_clk = 0;

        initialize();

        reset_dut();

        normal_tx();
        normal_tx();

        repeat(20) @(negedge i_clk);

        $stop;

    end

endmodule
