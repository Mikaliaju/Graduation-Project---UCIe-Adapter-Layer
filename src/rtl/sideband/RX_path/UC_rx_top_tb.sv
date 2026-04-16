// ================================================================================================================================
//  FILENAME    : UC_rx_top_tb.sv (CORRECTED VERSION)
//  FIXES       : Proper packet chunking for NC=16, correct parity calculation
// ================================================================================================================================

`timescale 1ns/100ps

typedef enum logic [3:0] {
    NONE            = 4'd0,
    ACTIVE_REQ      = 4'd1,
    L1_REQ          = 4'd2,
    L2_REQ          = 4'd3,
    LINKRESET_REQ   = 4'd4,
    DISABLED_REQ    = 4'd5,
    ACTIVE_RESP     = 4'd6,
    PMNAK_RESP      = 4'd7,
    L1_RESP         = 4'd8,
    L2_RESP         = 4'd9,
    LINKRESET_RESP  = 4'd10,
    DISABLED_RESP   = 4'd11
} sb_state_msg_encoding;

typedef enum logic [1:0] {
    NONE_ERR        = 2'd0,
    Correctable_Err = 2'd1,
    NON_FATAL_Err   = 2'd2,
    FATAL_Err       = 2'd3
} sb_error_msg_encoding;

module UC_rx_top_tb;

// ======================================================================= //
//  Parameters
// ======================================================================= //

    parameter int CLK_PERIOD = 10;
    parameter real DUTY_CYCLE = 0.5;
    parameter real HIGH_TIME  = CLK_PERIOD * DUTY_CYCLE;
    parameter real LOW_TIME   = CLK_PERIOD * (1.0 - DUTY_CYCLE);
    parameter int  NC         = 16;  // 16-bit chunks

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
    logic              o_sb_rx_linkerr_req;
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

    UC_rx_top #(
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
        .o_sb_rx_linkerr_req     (o_sb_rx_linkerr_req),
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

    always_ff @(posedge i_clk) begin
        if (o_rx_chk_tag) begin
            do begin
                i_rx_orig_tag <= $urandom_range(0, 30);
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
        // TC-1: Full Completion Packets (128-bit / 8 phases for NC=16)
        // ----------------------------------------------------------------
        $display("[%0t] TC-1 START: Full Completion Packets", $time);

        // Remote completion with data (tag = 0x1F = 5'b11111)
        send_rdi_full_pkt_correct(128'hbbbbbbbb_aaaaaaaa_00000000_07C00019);

        // Local completion with data (tag != 0x1F)
        send_rdi_full_pkt_correct(128'hbbbbbbbb_aaaaaaaa_00000000_01400019);

        // Concurrent: RDI + Tx Controller
        fork
            send_rdi_full_pkt_correct(128'hdddddddd_cccccccc_00000000_01800019);
            begin
                @(posedge i_clk);
                i_tx_comp_pkt     = 128'h11111111_22222222_33333333_44444444;
                i_tx_comp_pkt_vld = 1'b1;
                wait (o_tx_comp_pkt_done);
                @(posedge i_clk);
                i_tx_comp_pkt_vld = 1'b0;
            end
        join

        #(10*CLK_PERIOD);
        $display("[%0t] TC-1 DONE", $time);

        // ----------------------------------------------------------------
        // TC-2: Half Completion Packets (64-bit / 4 phases for NC=16)
        // ----------------------------------------------------------------
        $display("[%0t] TC-2 START: Half Completion Packets", $time);

        // Remote completion without data
        send_rdi_half_pkt_correct(64'h00000000_07C00010);

        // Local completion without data
        send_rdi_half_pkt_correct(64'h00000000_01400010);

        #(10*CLK_PERIOD);
        $display("[%0t] TC-2 DONE", $time);

        // ----------------------------------------------------------------
        // TC-3: Message Packets with Data
        // ----------------------------------------------------------------
        $display("[%0t] TC-3 START: Message Packets", $time);

        // Adapter Advertise Capabilities (with correct parity)
        send_rdi_full_pkt_correct(128'h12345678_9abcdef0_05000000_2000401b);

        #(10*CLK_PERIOD);
        $display("[%0t] TC-3 DONE", $time);

        // ----------------------------------------------------------------
        // TC-4: LSM State Messages
        // ----------------------------------------------------------------
        $display("[%0t] TC-4 START: LSM State Messages", $time);

        send_rdi_half_pkt_correct(64'h05000001_2000C012);  // ACTIVE_REQ
        send_rdi_half_pkt_correct(64'h05000004_2000C012);  // L1_REQ

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

    // ================================================================
    // CORRECTED: Proper LSB-first transmission for NC=16
    // ================================================================
    task automatic send_rdi_full_pkt_correct(input logic [127:0] pkt);
        logic [127:0] pkt_with_parity;
        logic header_parity, data_parity;
        
        // Calculate parities
        data_parity   = ^pkt[127:64];  // Parity of data field
        header_parity = ^{pkt[31:0], pkt[63:32]}; // Parity of header (phases 1 & 2 bits except parity)
        
        // Insert parities into packet
        pkt_with_parity = pkt;
        pkt_with_parity[63] = data_parity;   // Data parity bit
        pkt_with_parity[62] = header_parity; // Header parity bit
        
        $display("[%0t] Sending FULL packet: 0x%h", $time, pkt_with_parity);
        
        // Send LSB first (phases 0→7 for NC=16)
        for (int chunk = 0; chunk < 128/NC; chunk++) begin
            @(posedge i_clk);
            i_rdi_pl_cfg     = pkt_with_parity[chunk*NC +: NC]; // Extract 16 bits starting at chunk*16
            i_rdi_pl_cfg_vld = 1'b1;
            $display("  Phase %0d: 0x%04h", chunk, i_rdi_pl_cfg);
        end
        
        @(posedge i_clk);
        i_rdi_pl_cfg_vld = 1'b0;
        i_rdi_pl_cfg     = '0;
    endtask

    task automatic send_rdi_half_pkt_correct(input logic [63:0] pkt);
        logic [63:0] pkt_with_parity;
        logic header_parity;
        
        // Calculate header parity
        header_parity = ^{pkt[31:0], pkt[61:32]}; // All header bits except parity bit itself
        
        // Insert parity
        pkt_with_parity = pkt;
        pkt_with_parity[62] = header_parity;
        pkt_with_parity[63] = 1'b0; // No data parity for half packets
        
        $display("[%0t] Sending HALF packet: 0x%h", $time, pkt_with_parity);
        
        // Send LSB first (phases 0→3 for NC=16)
        for (int chunk = 0; chunk < 64/NC; chunk++) begin
            @(posedge i_clk);
            i_rdi_pl_cfg     = pkt_with_parity[chunk*NC +: NC];
            i_rdi_pl_cfg_vld = 1'b1;
            $display("  Phase %0d: 0x%04h", chunk, i_rdi_pl_cfg);
        end
        
        @(posedge i_clk);
        i_rdi_pl_cfg_vld = 1'b0;
        i_rdi_pl_cfg     = '0;
    endtask

// ======================================================================= //
//  Monitors
// ======================================================================= //

    always @(posedge i_clk) begin
        if (o_fdi_pl_cfg_vld)
            $display("[%0t] FDI OUT  -> 0x%04h", $time, o_fdi_pl_cfg);
    end

    always @(posedge i_clk) begin
        if (o_rx_remote_comp_vld)
            $display("[%0t] REMOTE COMP -> 0x%h (len=%0b)", $time, o_rx_remote_comp_pkt, o_rx_remote_comp_length);
    end

    always @(posedge i_clk) begin
        if (o_rx_chk_tag)
            $display("[%0t] TAG CHK -> current=0x%h orig=0x%h", $time, o_rx_current_tag, i_rx_orig_tag);
    end

    always @(posedge i_clk) begin
        if (o_sb_rx_parity_error)
            $display("[%0t] *** PARITY ERROR ***", $time);
        if (o_sb_rdi_overflow)
            $display("[%0t] *** RDI OVERFLOW ***", $time);
        if (o_sb_rx_linkerr_req)
            $display("[%0t] *** LINK ERROR ***", $time);
    end

endmodule