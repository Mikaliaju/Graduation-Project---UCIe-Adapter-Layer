`timescale 1ns/1ps

module UC_sb_credit_loop_tb;

    parameter int MAX_CREDITS = 32;
    parameter int CREDIT_W    = $clog2(MAX_CREDITS + 1);

    logic i_clk;
    logic i_rst_n;
    logic i_init;

    logic i_rdi_credit_release;
    logic i_fdi_credit_release;
    logic i_decrease_counter;

    logic i_lp_cfg_crd;
    logic i_pl_cfg_crd;

    logic o_stall;
    logic o_pl_cfg_crd;
    logic o_lp_cfg_crd;

    // DUT
    UC_sb_credit_loop #(
        .MAX_CREDITS(MAX_CREDITS),
        .CREDIT_W(CREDIT_W)
    ) dut (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_init(i_init),
        .i_rdi_credit_release(i_rdi_credit_release),
        .i_fdi_credit_release(i_fdi_credit_release),
        .i_decrease_counter(i_decrease_counter),
        .i_lp_cfg_crd(i_lp_cfg_crd),
        .i_pl_cfg_crd(i_pl_cfg_crd),
        .o_stall(o_stall),
        .o_pl_cfg_crd(o_pl_cfg_crd),
        .o_lp_cfg_crd(o_lp_cfg_crd)
    );

    // Clock generation
    initial begin
        i_clk = 0;
        forever #5 i_clk = ~i_clk;
    end

    // Task: pulse for one clock cycle
    task automatic pulse_signal(ref logic sig);
        begin
            sig = 1'b1;
            @(posedge i_clk);
            #1;
            sig = 1'b0;
        end
    endtask

    initial begin
        // Initial values
        i_rst_n              = 0;
        i_init               = 0;
        i_rdi_credit_release = 0;
        i_fdi_credit_release = 0;
        i_decrease_counter   = 0;
        i_lp_cfg_crd         = 0;
        i_pl_cfg_crd         = 0;

        // =====================================================
        // TEST 1: Reset
        // =====================================================
        repeat(2) @(posedge i_clk);
        i_rst_n = 1;
        i_init  = 1;
        @(posedge i_clk);

        $display("TEST 1: After reset, credit_count = %0d, o_stall = %0b",
                 dut.credit_count, o_stall);


        $display("TEST 2: After init active, credit_count = %0d", dut.credit_count);

        // =====================================================
        // TEST 3: FDI credit release forwarding
        // =====================================================
        $display("TEST 3: FDI release forwarding");
        i_fdi_credit_release = 1;
        #1;
        $display("o_pl_cfg_crd = %0b (expected 1)", o_pl_cfg_crd);
        @(posedge i_clk);
        i_fdi_credit_release = 0;
        #1;
        $display("o_pl_cfg_crd = %0b (expected 0)", o_pl_cfg_crd);

        // =====================================================
        // TEST 4: RDI credit release forwarding
        // =====================================================
        $display("TEST 4: RDI release forwarding");
        i_rdi_credit_release = 1;
        #1;
        $display("o_lp_cfg_crd = %0b (expected 1)", o_lp_cfg_crd);
        @(posedge i_clk);
        i_rdi_credit_release = 0;
        #1;
        $display("o_lp_cfg_crd = %0b (expected 0)", o_lp_cfg_crd);

        // =====================================================
        // TEST 5: Decrease counter 3 times
        // =====================================================
        $display("TEST 5: Decrease counter 3 times");
        repeat(3) begin
            pulse_signal(i_decrease_counter);
            @(posedge i_clk);
            $display("credit_count = %0d", dut.credit_count);
        end

        // =====================================================
        // TEST 6: Decrease until zero -> stall must go high
        // =====================================================
        $display("TEST 6: Decrease until zero");
        repeat(MAX_CREDITS - 3) begin
            pulse_signal(i_decrease_counter);
        end
        @(posedge i_clk);
        $display("credit_count = %0d, o_stall = %0b (expected 0,1)",
                 dut.credit_count, o_stall);

        // =====================================================
        // TEST 7: Increase one credit using i_pl_cfg_crd
        // =====================================================
        $display("TEST 7: Restore one credit");
        pulse_signal(i_pl_cfg_crd);
        @(posedge i_clk);
        $display("credit_count = %0d, o_stall = %0b (expected 1,0)",
                 dut.credit_count, o_stall);

        // =====================================================
        // TEST 8: Increment and decrement together
        // =====================================================
        $display("TEST 8: Increment and decrement together");
        i_pl_cfg_crd       = 1;
        i_decrease_counter = 1;
        @(posedge i_clk);
        #1;
        i_pl_cfg_crd       = 0;
        i_decrease_counter = 0;
        @(posedge i_clk);
        $display("credit_count = %0d (expected no change)", dut.credit_count);

        // =====================================================
        // TEST 9: Saturation at MAX_CREDITS
        // =====================================================
        $display("TEST 9: Saturation at MAX_CREDITS");
        repeat(40) begin
            pulse_signal(i_pl_cfg_crd);
        end
        @(posedge i_clk);
        $display("credit_count = %0d (expected %0d max)", dut.credit_count, MAX_CREDITS);

        // =====================================================
        // TEST 10: Init low reloads counter
        // =====================================================
        $display("TEST 10: Init low reload");
        i_init = 0;
        @(posedge i_clk);
        #1;
        $display("credit_count = %0d (expected %0d)", dut.credit_count, MAX_CREDITS);

        $stop;
    end

endmodule