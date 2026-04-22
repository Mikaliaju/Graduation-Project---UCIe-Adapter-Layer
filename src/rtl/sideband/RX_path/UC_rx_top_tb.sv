// ================================================================================================================================
//  FILENAME    : UC_rx_top_tb.sv
//  MODULE      : UC_rx_top_tb
//  PROJECT     : UCIe 3.0 Adapter Layer
//  AUTHOR      : Ashraf Sherif, Shahd Mohamed
// ================================================================================================================================
`timescale 1ns/100ps

import UC_sb_rx_pkg::*;
module UC_rx_top_tb;

// ======================================================================= //
//  Parameters
// ======================================================================= //

    parameter int CLK_PERIOD = 10;
    parameter real DUTY_CYCLE = 0.5;
    parameter real HIGH_TIME  = CLK_PERIOD * DUTY_CYCLE;
    parameter real LOW_TIME   = CLK_PERIOD * (1.0 - DUTY_CYCLE);
    parameter int  NC         = 32;  // 32-bit chunks

// ======================================================================= //
//  TB Signals
// ======================================================================= //

    logic              i_clk;
    logic              i_rst_n;
    logic              i_init_n;

    logic [NC-1:0]     i_rdi_pl_cfg;
    logic              i_rdi_pl_cfg_vld;

    logic [4:0]        i_rx_orig_tag;
    logic              i_rx_tag_notfound;

    logic [127:0]      i_tx_comp_pkt;
    logic              i_tx_comp_pkt_vld;

    logic [NC-1:0]     o_fdi_pl_cfg;
    logic              o_fdi_pl_cfg_vld;

    `ifndef END_POINT
    sb_error_msg_encoding   o_sb_err_msg_rx;
    `endif
    sb_state_msg_encoding   o_sb_state_msg_rx;

    logic              o_sb_rdi_overflow;
    logic              o_sb_rx_parity_error;
    logic              o_sb_rx_opid_err;
    logic              o_rdi_crd_release;
    logic              o_rx_chk_tag;
    logic [4:0]        o_rx_current_tag;
    logic              o_tx_comp_pkt_done;

    `ifdef END_POINT
    logic [127:0]      o_remote_req_pkt;
    logic              o_remote_req_vld;
    `else
    logic              o_e2e_crds_return_vld;
    `endif

    logic [127:0]      o_rx_remote_comp_pkt;
    logic              o_rx_remote_comp_vld;
    logic              o_rx_remote_comp_length;
    logic [127:0]      o_rx_msg;
    logic              o_rx_msg_vld;

// ======================================================================= //
//  DUT Instantiation
// ======================================================================= //

    UC_sb_rx_top #(
        .NC              (NC),
        .NUM_OF_COMP_PKTS(4),
        .NUM_OF_MSG_PKTS (2)
    ) dut (
        .i_clk                   (i_clk),
        .i_rst_n                 (i_rst_n),
        .i_init_n                (i_init_n),
        .i_rdi_pl_cfg            (i_rdi_pl_cfg),
        .i_rdi_pl_cfg_vld        (i_rdi_pl_cfg_vld),
        .o_fdi_pl_cfg            (o_fdi_pl_cfg),
        .o_fdi_pl_cfg_vld        (o_fdi_pl_cfg_vld),
        `ifndef END_POINT
        .o_sb_err_msg_rx         (o_sb_err_msg_rx),
        `endif
        .o_sb_state_msg_rx       (o_sb_state_msg_rx),
        .o_sb_rdi_overflow       (o_sb_rdi_overflow),
        .o_sb_rx_parity_error    (o_sb_rx_parity_error),
        .o_sb_rx_opid_err        (o_sb_rx_opid_err),
        .o_rdi_crd_release       (o_rdi_crd_release),
        .o_rx_chk_tag            (o_rx_chk_tag),
        .o_rx_current_tag        (o_rx_current_tag),
        .i_rx_orig_tag           (i_rx_orig_tag),
        .i_rx_tag_notfound       (i_rx_tag_notfound),
        .i_tx_comp_pkt           (i_tx_comp_pkt),
        .i_tx_comp_pkt_vld       (i_tx_comp_pkt_vld),
        .o_tx_comp_pkt_done      (o_tx_comp_pkt_done),
        `ifdef END_POINT
        .o_remote_req_pkt        (o_remote_req_pkt),
        .o_remote_req_vld        (o_remote_req_vld),
        `else
        .o_e2e_crds_return_vld   (o_e2e_crds_return_vld),
        `endif
        .o_rx_remote_comp_pkt    (o_rx_remote_comp_pkt),
        .o_rx_remote_comp_vld    (o_rx_remote_comp_vld),
        .o_rx_remote_comp_length (o_rx_remote_comp_length),
        .o_rx_msg                (o_rx_msg),
        .o_rx_msg_vld            (o_rx_msg_vld)
    );

// ======================================================================= //
//  Clock Generator
// ======================================================================= //
   
    initial i_clk = 0;
    always #(CLK_PERIOD/2) i_clk = ~i_clk;

// ======================================================================= //
//  Tag Manager Response
// ======================================================================= //

    always_comb begin
    if (o_rx_chk_tag) begin
        do begin
            i_rx_orig_tag <= $random % 32;
        end while (i_rx_orig_tag == 5'b11111);
    end
end

// ======================================================================= //
//  Main Test Stimulus
// ======================================================================= //

    initial begin
        $dumpfile("UC_rx_top.vcd");
        $dumpvars(0, UC_rx_top_tb);

        initialize();
        apply_hw_reset();

        // ----------------------------------------------------------------
        // TC-1: Full Completion Packets (128-bit / 8 phases for NC=32)
        // ----------------------------------------------------------------
        $display("[%0t] TC-1 START: Full Completion Packets", $time);

         // Send valid Completion packets on RDI interface
        send_rdi_full_packet(128'hbbbbbbbb_aaaaaaaa_00000000_07C00019); // Remote Completion with data
        send_rdi_full_packet(128'hbbbbbbbb_aaaaaaaa_00000000_01C00019); // Local Completion with data
        
        fork        
            // COMP With data to a local register access request
            begin
                send_rdi_full_packet(128'hbbbbbbbb_aaaaaaaa_00000000_01C00019); // Local Completion with data
            end 
            
            // COMP from the Tx_Reg block to be passed over FDI.
            begin
                i_tx_comp_pkt_vld = 1; 
                i_tx_comp_pkt = 128'hAABBCCDD_EEFF0011_22334455_66778899; // Tx comp packet with data

                wait(o_tx_comp_pkt_done)
                i_tx_comp_pkt_vld = 0;
            end 
        join

        #(10*CLK_PERIOD);
        $display("[%0t] TC-1 DONE", $time);

        // ----------------------------------------------------------------
        // TC-2: Half Completion Packets (64-bit / 4 phases for NC=32)
        // ----------------------------------------------------------------
        $display("[%0t] TC-2 START: Half Completion Packets", $time);
        // Send valid Completion packets on RDI interface
        send_rdi_half_packet(64'h00000000_07C00010); // Remote Completion without data
        send_rdi_half_packet(64'h00000000_01C00010); // Local Completion without data
        
        fork        
            // COMP With data to a local register access request
            begin
                send_rdi_half_packet(64'h40000000_01B00010); // Local Completion without data
            end 
            
            // COMP from the Tx_Reg block to be passed over FDI.
            begin
                i_tx_comp_pkt_vld = 1; 
                i_tx_comp_pkt = 128'h0_11223344_55667788; // Tx comp packet without data

                wait(o_tx_comp_pkt_done)
                i_tx_comp_pkt_vld = 0;
            end 
        join
        #(10*CLK_PERIOD);
        $display("[%0t] TC-2 DONE", $time);

        // ----------------------------------------------------------------
        // TC-3: Message Packets with Data
        // ----------------------------------------------------------------
        $display("[%0t] TC-3 START: Message Packets", $time);

         send_rdi_full_packet(128'hffffffff_eeeeeeee_05000000_2000401b); // Adapter Adv Cap "Msg with data"
    send_rdi_full_packet(128'h66666666_55555555_05000000_2000801b); // Adapter Fin Cap "Msg with data"

        #(10*CLK_PERIOD);
        $display("[%0t] TC-3 DONE", $time);

        // ----------------------------------------------------------------
        // TC-4: LSM State Messages
        // ----------------------------------------------------------------
        $display("[%0t] TC-4 START: LSM State Messages", $time);

        send_rdi_half_packet(64'h05000001_2000C012);  // ACTIVE_REQ
        send_rdi_half_packet(64'h05000004_2000C012);  // L1_REQ

        #(10*CLK_PERIOD);
        $display("[%0t] TC-4 DONE", $time);

        // ----------------------------------------------------------------
        // End of simulation
        // ----------------------------------------------------------------
        #(50*CLK_PERIOD);
        $display("[%0t] All test cases completed.", $time);
        $stop;
    end

// ======================================================================= //
//  Tasks
// ======================================================================= //

    task automatic initialize();
        i_rst_n           = 1'b1;
        i_init_n          = 1'b1;
        i_rdi_pl_cfg      = '0;
        i_rdi_pl_cfg_vld  = 1'b0;
        i_rx_orig_tag     = '0;
        i_rx_tag_notfound = 1'b0;
        i_tx_comp_pkt     = '0;
        i_tx_comp_pkt_vld = 1'b0;
    endtask

    task automatic apply_hw_reset();
        $display("[%0t] Applying HW reset...", $time);
        @(negedge i_clk);
        i_rst_n = 1'b0;
        repeat(3) @(posedge i_clk);
        i_rst_n = 1'b1;
        repeat(2) @(posedge i_clk);
        $display("[%0t] HW reset released.", $time);
    endtask

    task send_rdi_full_packet(logic [127:0] full_packet);
    // Simulate Receiving full packet on RDI transfer
    for (int chunk = 0; chunk < 128/NC; chunk++) begin
        @(posedge i_clk);
        // Extract chunk from full_packet
        i_rdi_pl_cfg = (full_packet >> (chunk * NC));
        i_rdi_pl_cfg_vld = 1;
    end 
    #CLK_PERIOD;
    i_rdi_pl_cfg_vld = 0;
endtask

task send_rdi_half_packet(logic [127:0] half_packet);
    // Simulate Receiving full packet on RDI transfer
    for (int chunk = 0; chunk < 64/NC; chunk++) begin
        @(posedge i_clk);
        // Extract chunk from full_packet
        i_rdi_pl_cfg = (half_packet >> (chunk * NC));
        i_rdi_pl_cfg_vld = 1;
    end 
    #CLK_PERIOD;
    i_rdi_pl_cfg_vld = 0;
endtask
endmodule : UC_rx_top_tb