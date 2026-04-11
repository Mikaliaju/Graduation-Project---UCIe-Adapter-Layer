`timescale 1ns/1ps

module tb_UC_sb_remote_die_request_controller;

// ── Parameters 
localparam integer CLK_FREQ_HZ  = 100;   // fake value for fast timeout simulation
localparam integer TIMEOUT_MS   = 100;   // => 10 cycles
localparam integer CLK_PERIOD   = 10;    // ns

// ── DUT ports 
logic         i_clk;
logic         i_rst_n;
logic         i_init;

logic [127:0] i_remote_req;
logic         i_remote_req_vld;

logic         i_read_req;
logic [4:0]   i_comp_opcode;
logic         i_is_phy_access;
logic         i_pkt_length;
logic         i_comp_length;
logic         i_32_b;
logic         i_config;

logic [63:0]  o_remote_write_data;
logic         o_remote_wr_en;
logic [23:0]  o_remote_address;
logic [7:0]   o_remote_BE;
logic         o_remote_config_req;
logic         o_remote_32_B;
logic         o_remote_vld;
logic [2:0]   i_status;
logic [63:0]  i_read_data;
logic         i_remote_done;

logic [127:0] i_phy_comp;
logic         i_phy_comp_vld;

logic [127:0] o_pkt;
logic         o_pkt_vld;
logic         o_pkt_length;
logic         o_is_comp;
logic         i_req_sent;

logic [4:0]   o_opcode;
logic [23:0]  o_address;

logic         o_local_timeout;

// DUT
UC_sb_remote_die_request_controller #(
    .CLK_FREQ_HZ(CLK_FREQ_HZ),
    .TIMEOUT_MS (TIMEOUT_MS)
) dut (.*);

//  Clock
initial i_clk = 0;
always #(CLK_PERIOD/2) i_clk = ~i_clk;

//  Scoreboard 
int pass_cnt = 0, fail_cnt = 0;

task automatic chk(input string lbl, input logic cond);
    if (cond) begin
        $display("  [PASS] %s", lbl);
        pass_cnt++;
    end
    else begin
        $display("  [FAIL] %s", lbl);
        fail_cnt++;
    end
endtask

// ============================================================================
// Packet helpers
// ============================================================================
function automatic logic fn_dp(input logic [127:0] pkt);
    fn_dp = ^pkt[127:64];
endfunction

function automatic logic fn_cp(input logic [127:0] pkt);
    fn_cp = ^{pkt[61:32], pkt[31:0]};
endfunction

function automatic logic [127:0] build_pkt(
    input logic [2:0]  srcid,
    input logic [4:0]  opcode,
    input logic [7:0]  be,
    input logic [2:0]  dstid,
    input logic [23:0] addr,
    input logic [63:0] data
);
    logic [127:0] p;
    p = '0;
    p[4:0]    = opcode;
    p[21:14]  = be;
    p[31:29]  = srcid;
    p[55:32]  = addr;
    p[58:56]  = dstid;
    p[95:64]  = data[31:0];
    p[127:96] = data[63:32];
    p[63]     = fn_dp(p);
    p[62]     = fn_cp(p);
    return p;
endfunction

function automatic logic [127:0] build_bad_cp_pkt(
    input logic [2:0]  srcid,
    input logic [4:0]  opcode,
    input logic [7:0]  be,
    input logic [2:0]  dstid,
    input logic [23:0] addr,
    input logic [63:0] data
);
    logic [127:0] p;
    p = build_pkt(srcid, opcode, be, dstid, addr, data);
    p[62] = ~p[62];
    return p;
endfunction

function automatic logic [127:0] build_bad_dp_pkt(
    input logic [2:0]  srcid,
    input logic [4:0]  opcode,
    input logic [7:0]  be,
    input logic [2:0]  dstid,
    input logic [23:0] addr,
    input logic [63:0] data
);
    logic [127:0] p;
    p = build_pkt(srcid, opcode, be, dstid, addr, data);
    p[63] = ~p[63];
    return p;
endfunction

// ── Defaults 
localparam logic [4:0] COMP_OPC = 5'b00100;
localparam logic [2:0] SRC_REM  = 3'b100;
localparam logic [2:0] DST_ADP  = 3'b001;
localparam logic [2:0] DST_PHY  = 3'b010;

// ============================================================================
// Helper tasks
// ============================================================================

// Reset side inputs between tests
task automatic clear_side_inputs;
begin
    i_remote_req      = '0;
    i_remote_req_vld  = 0;
    i_read_req        = 0;
    i_comp_opcode     = COMP_OPC;
    i_is_phy_access   = 0;
    i_pkt_length      = 1;
    i_comp_length     = 1;
    i_32_b            = 0;
    i_config          = 0;
    i_status          = 3'b000;
    i_read_data       = '0;
    i_remote_done     = 0;
    i_phy_comp        = '0;
    i_phy_comp_vld    = 0;
    i_req_sent        = 0;
end
endtask

task automatic send_req(
    input logic [127:0] pkt,
    input logic         rd,
    input logic         phy,
    input logic         b32,
    input logic         cfg
);
begin
    i_remote_req      = pkt;
    i_remote_req_vld  = 1'b1;
    i_read_req        = rd;
    i_is_phy_access   = phy;
    i_32_b            = b32;
    i_config          = cfg;
    i_comp_opcode     = COMP_OPC;
    i_pkt_length      = 1'b1;
    i_comp_length     = 1'b1;
    @(posedge i_clk);
    i_remote_req_vld  = 1'b0;
end
endtask

task automatic ack_rdi_once;
begin
    i_req_sent = 1'b1;
    @(posedge i_clk);
    i_req_sent = 1'b0;
end
endtask

task automatic wait_and_capture_pkt(
    input  logic expected_is_comp,
    output logic [127:0] captured_pkt
);
begin
    @(posedge i_clk iff (o_pkt_vld === 1'b1 && o_is_comp === expected_is_comp));
    captured_pkt = o_pkt;
end
endtask

task automatic drive_arbiter_done(
    input logic [63:0] rdata,
    input logic [2:0]  status,
    input int          latency
);
begin
    @(posedge i_clk iff (o_remote_vld === 1'b1));
    repeat(latency) @(posedge i_clk);
    i_read_data   = rdata;
    i_status      = status;
    i_remote_done = 1'b1;
    @(posedge i_clk);
    i_remote_done = 1'b0;
end
endtask

task automatic drive_phy_comp(
    input logic [127:0] phy_pkt,
    input int latency
);
begin
    repeat(latency) @(posedge i_clk);
    i_phy_comp     = phy_pkt;
    i_phy_comp_vld = 1'b1;
    @(posedge i_clk);
    i_phy_comp_vld = 1'b0;
end
endtask

// ============================================================================
// TEST CASES
// ============================================================================
initial begin
    clear_side_inputs();

    i_rst_n = 0;
    i_init  = 0;

    repeat(4) @(posedge i_clk);
    i_rst_n = 1;
    repeat(2) @(posedge i_clk);

    // =========================================================================
    // TC0 – i_init=0 → FSM stays IDLE
    // =========================================================================
    $display("\n─── TC0: i_init=0 gating ───");
    i_init           = 0;
    i_remote_req     = build_pkt(SRC_REM, 5'b00001, 8'hFF, DST_ADP, 24'hAABBCC, 64'h0);
    i_remote_req_vld = 1'b1;
    repeat(5) @(posedge i_clk);
    chk("TC0: no pkt_vld while i_init=0",    o_pkt_vld    === 1'b0);
    chk("TC0: no remote_vld while i_init=0", o_remote_vld === 1'b0);
    i_remote_req_vld = 1'b0;
    i_init           = 1'b1;
    clear_side_inputs();
    repeat(3) @(posedge i_clk);

    // =========================================================================
    // TC1 – CP parity error → packet dropped
    // =========================================================================
    $display("\n─── TC1: CP parity error → dropped ───");
    begin
        logic [127:0] bad_pkt;
        bad_pkt = build_bad_cp_pkt(SRC_REM, 5'b00001, 8'hFF, DST_ADP, 24'h001000, 64'h0);
        send_req(bad_pkt, 0, 0, 0, 0);
        repeat(6) @(posedge i_clk);
        chk("TC1: no pkt_vld after CP error",    o_pkt_vld    === 1'b0);
        chk("TC1: no remote_vld after CP error", o_remote_vld === 1'b0);
    end
    clear_side_inputs();
    repeat(3) @(posedge i_clk);

    // =========================================================================
    // TC2 – DP parity error → packet dropped
    // =========================================================================
    $display("\n─── TC2: DP parity error → dropped ───");
    begin
        logic [127:0] bad_pkt;
        bad_pkt = build_bad_dp_pkt(SRC_REM, 5'b00001, 8'hFF, DST_ADP, 24'h002000, 64'hDEAD);
        send_req(bad_pkt, 1, 0, 0, 0);
        repeat(6) @(posedge i_clk);
        chk("TC2: no pkt_vld after DP error",    o_pkt_vld    === 1'b0);
        chk("TC2: no remote_vld after DP error", o_remote_vld === 1'b0);
    end
    clear_side_inputs();
    repeat(3) @(posedge i_clk);

    // =========================================================================
    // TC3 – Adapter write
    // =========================================================================
    $display("\n─── TC3: Adapter write ───");
    begin
        logic [127:0] pkt, comp;
        logic [63:0]  wr_data;
        wr_data = 64'hCAFE_BABE_1234_5678;
        pkt = build_pkt(SRC_REM, 5'b00001, 8'hFF, DST_ADP, 24'h003000, wr_data);

        fork
            send_req(pkt, 0, 0, 0, 0);
            drive_arbiter_done(64'h0, 3'b000, 1);
        join

        // while waiting remote, arbiter-facing signals should be correct
        chk("TC3: arbiter wr_en=1 for write", o_remote_wr_en === 1'b1);

        wait_and_capture_pkt(1'b1, comp);
        chk("TC3: o_is_comp=1",            o_is_comp    === 1'b1);
        chk("TC3: comp opcode correct",    comp[4:0]    === COMP_OPC);
        chk("TC3: comp status=000",        comp[34:32]  === 3'b000);
        chk("TC3: write completion data=0",comp[127:64] === 64'h0);
        chk("TC3: comp dp correct",        comp[63]     === fn_dp(comp));
        chk("TC3: comp cp correct",        comp[62]     === fn_cp(comp));

        ack_rdi_once();
    end
    clear_side_inputs();
    repeat(3) @(posedge i_clk);

    // =========================================================================
    // TC4 – Adapter 64-bit read
    // =========================================================================
    $display("\n─── TC4: Adapter 64-bit read ───");
    begin
        logic [127:0] pkt, comp;
        logic [63:0]  rd_data;
        rd_data = 64'hDEAD_BEEF_CAFE_1234;
        pkt = build_pkt(SRC_REM, 5'b00010, 8'hFF, DST_ADP, 24'h004000, 64'h0);

        fork
            send_req(pkt, 1, 0, 0, 1);
            drive_arbiter_done(rd_data, 3'b000, 2);
        join

        wait_and_capture_pkt(1'b1, comp);
        chk("TC4: o_is_comp=1",             o_is_comp    === 1'b1);
        chk("TC4: comp data[31:0] correct", comp[95:64]  === rd_data[31:0]);
        chk("TC4: comp data[63:32] correct",comp[127:96] === rd_data[63:32]);
        chk("TC4: comp dp parity ok",       comp[63]     === fn_dp(comp));
        chk("TC4: comp cp parity ok",       comp[62]     === fn_cp(comp));

        ack_rdi_once();
    end
    clear_side_inputs();
    repeat(3) @(posedge i_clk);

    // =========================================================================
    // TC5 – Adapter 32-bit read
    // =========================================================================
    $display("\n─── TC5: Adapter 32-bit read ───");
    begin
        logic [127:0] pkt, comp;
        logic [63:0]  rd_data;
        rd_data = 64'h0000_0000_ABCD_EF01;
        pkt = build_pkt(SRC_REM, 5'b00010, 8'h0F, DST_ADP, 24'h005000, 64'h0);

        fork
            send_req(pkt, 1, 0, 1, 0);
            drive_arbiter_done(rd_data, 3'b000, 1);
        join

        wait_and_capture_pkt(1'b1, comp);
        chk("TC5: comp data[31:0] = rd_data[31:0]", comp[95:64]  === rd_data[31:0]);
        chk("TC5: comp data[63:32] = 0",            comp[127:96] === 32'h0);
        chk("TC5: comp dp parity ok",               comp[63]     === fn_dp(comp));

        ack_rdi_once();
    end
    clear_side_inputs();
    repeat(3) @(posedge i_clk);

    // =========================================================================
    // TC6 – Adapter read with UR status
    // =========================================================================
    $display("\n─── TC6: Adapter read, status=001 (UR) ───");
    begin
        logic [127:0] pkt, comp;
        pkt = build_pkt(SRC_REM, 5'b00010, 8'hFF, DST_ADP, 24'h006000, 64'h0);

        fork
            send_req(pkt, 1, 0, 0, 0);
            drive_arbiter_done(64'h0, 3'b001, 3);
        join

        wait_and_capture_pkt(1'b1, comp);
        chk("TC6: comp status = 001 (UR)", comp[34:32] === 3'b001);

        ack_rdi_once();
    end
    clear_side_inputs();
    repeat(3) @(posedge i_clk);

    // =========================================================================
    // TC7 – PHY access: forwarded request patched correctly
    // =========================================================================
    $display("\n─── TC7: PHY access – request routing patch ───");
    begin
        logic [127:0] pkt, fwd_pkt;
        pkt = build_pkt(SRC_REM, 5'b00010, 8'hFF, DST_ADP, 24'h007000, 64'h0);

        send_req(pkt, 1, 1, 0, 0);

        wait_and_capture_pkt(1'b0, fwd_pkt);
        chk("TC7: o_is_comp=0",              o_is_comp      === 1'b0);
        chk("TC7: fwd srcid = Adapter",      fwd_pkt[31:29] === 3'b001);
        chk("TC7: fwd dstid = PHY",          fwd_pkt[58:56] === 3'b010);
        chk("TC7: fwd cp parity ok",         fwd_pkt[62]    === fn_cp(fwd_pkt));
        chk("TC7: fwd dp unchanged",         fwd_pkt[63]    === pkt[63]);

        ack_rdi_once();
    end
    clear_side_inputs();
    repeat(3) @(posedge i_clk);

    // =========================================================================
    // TC8 – PHY access: valid completion restored and forwarded
    // =========================================================================
    $display("\n─── TC8: PHY access – completion routing restoration ───");
    begin
        logic [127:0] req_pkt, phy_comp_pkt, sent_comp;
        req_pkt = build_pkt(SRC_REM, 5'b00010, 8'hFF, DST_ADP, 24'h008000, 64'h0);

        send_req(req_pkt, 1, 1, 0, 0);

        // first packet is forwarded PHY request
        wait_and_capture_pkt(1'b0, sent_comp);
        ack_rdi_once();

        // now drive PHY completion
        phy_comp_pkt = build_pkt(3'b010, COMP_OPC, 8'hFF, 3'b001,
                                 24'h008000, 64'hABCD_EF12_3456_7890);
        drive_phy_comp(phy_comp_pkt, 2);

        // capture forwarded completion
        wait_and_capture_pkt(1'b1, sent_comp);
        chk("TC8: o_is_comp=1",                 o_is_comp      === 1'b1);
        chk("TC8: restored srcid = Adapter",    sent_comp[31:29] === 3'b001);
        chk("TC8: restored dstid = Remote",     sent_comp[58:56] === 3'b100);
        chk("TC8: comp cp parity ok",           sent_comp[62]    === fn_cp(sent_comp));

        ack_rdi_once();
    end
    clear_side_inputs();
    repeat(3) @(posedge i_clk);

    // =========================================================================
    // TC9 – PHY access: bad PHY completion parity → dropped
    // =========================================================================
    $display("\n─── TC9: PHY access – bad PHY completion parity → dropped ───");
    begin
        logic [127:0] req_pkt, bad_comp;
        req_pkt = build_pkt(SRC_REM, 5'b00010, 8'hFF, DST_ADP, 24'h009000, 64'h0);

        send_req(req_pkt, 1, 1, 0, 0);

        wait_and_capture_pkt(1'b0, bad_comp); // capture forwarded req just to sync
        ack_rdi_once();

        bad_comp = build_bad_cp_pkt(3'b010, COMP_OPC, 8'hFF, 3'b001,
                                    24'h009000, 64'h0);
        drive_phy_comp(bad_comp, 2);

        repeat(5) @(posedge i_clk);
        chk("TC9: no completion after bad PHY comp", o_pkt_vld === 1'b0);
    end
    clear_side_inputs();
    repeat(3) @(posedge i_clk);

    // =========================================================================
    // TC10 – PHY access timeout
    // =========================================================================
    $display("\n─── TC10: PHY access timeout ───");
    begin
        logic [127:0] req_pkt;
        req_pkt = build_pkt(SRC_REM, 5'b00010, 8'hFF, DST_ADP, 24'h00A000, 64'h0);

        send_req(req_pkt, 1, 1, 0, 0);

        wait_and_capture_pkt(1'b0, req_pkt);
        ack_rdi_once();

        @(posedge i_clk iff (o_local_timeout === 1'b1));
        chk("TC10: o_local_timeout asserted",      o_local_timeout === 1'b1);
        chk("TC10: no completion sent on timeout", o_pkt_vld       === 1'b0);
        @(posedge i_clk);
        chk("TC10: timeout clears after one cycle", o_local_timeout === 1'b0);
    end
    clear_side_inputs();
    repeat(3) @(posedge i_clk);

    // =========================================================================
    // TC11 – Adapter read with 5-cycle arbiter latency
    // =========================================================================
    $display("\n─── TC11: Adapter read with 5-cycle arbiter latency ───");
    begin
        logic [127:0] pkt, comp;
        logic [63:0]  rd_data;
        rd_data = 64'h1111_2222_3333_4444;
        pkt = build_pkt(SRC_REM, 5'b00010, 8'hFF, DST_ADP, 24'h00B000, 64'h0);

        fork
            send_req(pkt, 1, 0, 0, 0);
            drive_arbiter_done(rd_data, 3'b000, 5);
        join

        wait_and_capture_pkt(1'b1, comp);
        chk("TC11: completion valid",     o_pkt_vld    === 1'b1);
        chk("TC11: data[31:0] correct",   comp[95:64]  === rd_data[31:0]);
        chk("TC11: data[63:32] correct",  comp[127:96] === rd_data[63:32]);
        chk("TC11: dp parity ok",         comp[63]     === fn_dp(comp));

        ack_rdi_once();
    end
    clear_side_inputs();
    repeat(3) @(posedge i_clk);

    // =========================================================================
    // TC12 – Back-to-back: Adapter write then Adapter read
    // =========================================================================
    $display("\n─── TC12: Back-to-back Adapter write then read ───");
    begin
        logic [127:0] pkt1, pkt2, comp;
        logic [63:0]  rd_data3;
        rd_data3 = 64'hAAAA_BBBB_CCCC_DDDD;

        pkt1 = build_pkt(SRC_REM, 5'b00001, 8'hFF, DST_ADP, 24'h00C000, 64'hDEAD_CAFE);
        pkt2 = build_pkt(SRC_REM, 5'b00010, 8'hFF, DST_ADP, 24'h00C004, 64'h0);

        // first write
        fork
            send_req(pkt1, 0, 0, 0, 0);
            drive_arbiter_done(64'h0, 3'b000, 1);
        join
        wait_and_capture_pkt(1'b1, comp);
        chk("TC12-a: write completion sent", o_is_comp    === 1'b1);
        chk("TC12-a: write comp data=0",     comp[127:64] === 64'h0);
        ack_rdi_once();

        repeat(2) @(posedge i_clk);

        // second read
        fork
            send_req(pkt2, 1, 0, 0, 0);
            drive_arbiter_done(rd_data3, 3'b000, 2);
        join
        wait_and_capture_pkt(1'b1, comp);
        chk("TC12-b: read completion sent",     o_is_comp    === 1'b1);
        chk("TC12-b: read data[31:0] correct",  comp[95:64]  === rd_data3[31:0]);
        chk("TC12-b: read data[63:32] correct", comp[127:96] === rd_data3[63:32]);
        ack_rdi_once();
    end

    // ── Summary 
    repeat(5) @(posedge i_clk);
    $display("\n╔═══════════════════════════════════════════╗");
    $display("║  Results: %3d PASSED  |  %3d FAILED      ║", pass_cnt, fail_cnt);
    $display("╚═══════════════════════════════════════════╝");
    if (fail_cnt == 0)
        $display("  ✓ ALL TESTS PASSED\n");
    else
        $display("  ✗ SOME TESTS FAILED – review log\n");

    $finish;
end

// ── Timeout watchdog 
initial begin
    #500_000;
    $display("WATCHDOG TIMEOUT – simulation exceeded time limit");
    $finish;
end

// ── Waveform dump 
initial begin
    $dumpfile("tb_remote_die.vcd");
    $dumpvars(0, tb_UC_sb_remote_die_request_controller);
end

endmodule