`timescale 1ns/1ps

module UC_sb_tag_manager_tb;

    //------------------------- DUT Signals -------------------------//
    logic        i_clk;
    logic        i_rst_n;
    logic        i_valid;
    logic [4:0]  i_tag_store;
    logic        i_check;
    logic [4:0]  i_current_tag;
    logic        i_init;

    logic        o_correct;
    logic [4:0]  o_new_tag;
    logic        o_uncorrect_tag;
    logic [4:0]  o_old_tag;

    logic [4:0]  remapped_tag_reserved;
    logic [4:0]  remapped_tag_reused;

    //------------------------- DUT Instance ------------------------//
    UC_sb_tag_manager dut (
        .i_clk           (i_clk),
        .i_rst_n         (i_rst_n),
        .i_valid         (i_valid),
        .i_tag_store     (i_tag_store),
        .i_check         (i_check),
        .i_current_tag   (i_current_tag),
        .i_init          (i_init),
        .o_correct       (o_correct),
        .o_new_tag       (o_new_tag),
        .o_uncorrect_tag (o_uncorrect_tag),
        .o_old_tag       (o_old_tag)
    );

    //------------------------- Clock Generation --------------------//
    initial begin
        i_clk = 0;
        forever #5 i_clk = ~i_clk;
    end

    //------------------------- Reset Task --------------------------//
    task reset_dut;
    begin
        i_rst_n       = 0;
        i_valid       = 0;
        i_tag_store   = 0;
        i_check       = 0;
        i_current_tag = 0;
        i_init        = 0;

        repeat (2) @(posedge i_clk);
        i_rst_n = 1;
        i_init  = 1;
        @(posedge i_clk);

        $display("--------------------------------------------------");
        $display("RESET and INIT DONE at time = %0t", $time);
        $display("--------------------------------------------------");
    end
    endtask

    //------------------------- TX Task -----------------------------//
    task send_tag(input [4:0] tag_in);
    begin
        @(posedge i_clk);
        i_valid     <= 1'b1;
        i_tag_store <= tag_in;

        @(posedge i_clk);
        i_valid     <= 1'b0;
        i_tag_store <= 5'd0;

        #1;
        $display("[TX] time=%0t | input tag=%0d | correct=%0b | new_tag=%0d",
                 $time, tag_in, o_correct, o_new_tag);
    end
    endtask

    //------------------------- RX Task -----------------------------//
    task check_tag(input [4:0] tag_in);
    begin
        @(posedge i_clk);
        i_check       <= 1'b1;
        i_current_tag <= tag_in;

        @(posedge i_clk);
        i_check       <= 1'b0;
        i_current_tag <= 5'd0;

        #1;
        $display("[RX] time=%0t | current_tag=%0d | uncorrect_tag=%0b | old_tag=%0d",
                 $time, tag_in, o_uncorrect_tag, o_old_tag);
    end
    endtask

    //------------------------- Test Sequence -----------------------//
    initial begin
        i_rst_n       = 0;
        i_valid       = 0;
        i_tag_store   = 0;
        i_check       = 0;
        i_current_tag = 0;
        i_init        = 0;
        remapped_tag_reserved = 0;
        remapped_tag_reused   = 0;

        // Test 1: Reset
        reset_dut();

        // Test 2: Valid unique tag
        $display("\nTEST 1: Valid unique tag");
        send_tag(5'd3);

        // Test 3: Reserved tag -> remap
        $display("\nTEST 2: Reserved tag -> remap");
        send_tag(5'd31);
        remapped_tag_reserved = o_new_tag;

        // Test 4: Reused tag -> remap
        $display("\nTEST 3: Reused tag -> remap");
        send_tag(5'd3);
        remapped_tag_reused = o_new_tag;

        // Test 5: Completion for normal tag
        $display("\nTEST 4: Completion for normal tag");
        check_tag(5'd3);

        // Test 6: Completion for remapped reserved tag
        $display("\nTEST 5: Completion for remapped reserved tag");
        check_tag(remapped_tag_reserved);

        // Test 7: Completion for remapped reused tag
        $display("\nTEST 6: Completion for remapped reused tag");
        check_tag(remapped_tag_reused);

        // Test 8: Invalid completion tag
        $display("\nTEST 7: Invalid completion tag");
        check_tag(5'd20);

        // Test 9: No free tags available
        $display("\nTEST 8: No free tags available");

        reset_dut();

        for (int t = 0; t < 31; t++) begin
            send_tag(t[4:0]);
        end

        send_tag(5'd31);

        $display("\nAll tests completed successfully.");
        #20;
        $stop;
    end

endmodule