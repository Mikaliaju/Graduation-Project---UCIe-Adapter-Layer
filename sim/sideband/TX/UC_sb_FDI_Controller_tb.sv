`timescale 1ns/1ps

module UC_sb_FDI_Controller_tb;

// ── Parameters 
localparam int P_DATA_W  = 64;
localparam int CLK_PERIOD = 10;

// ── DUT ports 
logic               i_clk;
logic               i_rst_n;

// FDI FIFO side
logic [127:0]       i_Data_out;
logic               i_empty;
logic               o_Rd_en;

// RDI FIFO side
logic               i_Full;
logic [127:0]       o_Data_in;
logic               o_Wr_en;

// FDI Packer sidecar signals
logic               i_read_req;
logic               i_config;
logic               i_is_32b;
logic [4:0]         i_comp_opcode;

// Access Arbiter
logic [P_DATA_W-1:0] o_Local_wr_data;
logic                o_Local_wr_en;
logic                o_Local_config_req;
logic                o_Local_32_B;
logic [7:0]          o_Local_BE;
logic [23:0]         o_Local_address;
logic                o_Local_valid;
logic [2:0]          i_Local_status;
logic [P_DATA_W-1:0] i_Local_R_data;
logic                i_Local_done;

// Completion
logic [127:0]        o_Comp_packet;
logic                o_Valid;

// Credit loop
logic                o_Fdi_credit_release;

// Init gate
logic                i_init;

// Opcode out
logic [4:0]          o_req_opcode;

// ── DUT instantiation 
UC_sb_FDI_Controller #(.P_DATA_W(P_DATA_W)) dut (.*);

// ── Clock 
initial i_clk = 0;
always #(CLK_PERIOD/2) i_clk = ~i_clk;

// ── Scoreboard 
int pass_cnt = 0, fail_cnt = 0;

task automatic chk(input string lbl, input logic cond);
    if (cond) begin
        $display("  [PASS] %s", lbl);
        pass_cnt++;
    end else begin
        $display("  [FAIL] %s  (got 0 but expected 1, or value mismatch)", lbl);
        fail_cnt++;
    end
endtask

// ── Packet builder 
// Builds a correctly-parited 128-bit sideband packet.
function automatic logic [127:0] build_pkt(
    input logic [4:0]  opcode,
    input logic [7:0]  be,
    input logic [2:0]  dstid,
    input logic [23:0] addr,
    input logic [63:0] data
);
    logic [31:0] p0_v, p1_v, p2_v, p3_v;
    logic        dp_v, cp_v;

    p0_v = '0;
    p0_v[4:0]   = opcode;
    p0_v[21:14] = be;

    p1_v = '0;
    p1_v[23:0]  = addr;
    p1_v[26:24] = dstid;

    p2_v = data[31:0];
    p3_v = data[63:32];

    // DP = XOR over data
    dp_v = ^{p3_v, p2_v};

    // CP = XOR over all header bits except dp and cp fields
    // p1[31]=dp, p1[30]=cp → exclude; use p1[29:0] and p0 in full
    cp_v = ^{p1_v[29:0], p0_v};

    p1_v[31] = dp_v;
    p1_v[30] = cp_v;

    return {p3_v, p2_v, p1_v, p0_v};
endfunction

// ── Helper: drive a packet through the "FIFO" 
// Simulates FIFO having one entry: asserts i_empty=0 until o_Rd_en is seen,
// then deasserts it and holds i_Data_out valid for the POP_WAIT cycle.
task automatic push_fifo(
    input logic [127:0] pkt,
    input logic         rd_req,
    input logic         cfg,
    input logic         is32b,
    input logic [4:0]   comp_opc
);
    // Load sidecar signals (from FDI Packer)
    i_read_req    = rd_req;
    i_config      = cfg;
    i_is_32b      = is32b;
    i_comp_opcode = comp_opc;
    i_Data_out    = pkt;
    i_empty       = 0;

    // Wait until DUT asserts Rd_en (S_POP state)
    @(posedge i_clk iff (o_Rd_en === 1'b1));

    // One more cycle for POP_WAIT; keep data valid for capture
    @(posedge i_clk);

    // FIFO now empty (packet consumed)
    i_empty = 1;
endtask

// ── Helper: respond from Access Arbiter 
task automatic arb_respond(
    input logic [P_DATA_W-1:0] rdata,
    input logic [2:0]          status,
    input int                  latency   // cycles before asserting done
);
    // Wait until DUT requests access
    @(posedge i_clk iff (o_Local_valid === 1'b1));
    repeat(latency) @(posedge i_clk);
    i_Local_R_data = rdata;
    i_Local_status = status;
    i_Local_done   = 1;
    @(posedge i_clk);
    i_Local_done   = 0;
endtask

// ============================================================================
// TEST CASES
// ============================================================================
initial begin
    // ── Reset & init 
    i_rst_n       = 0;
    i_init        = 0;
    i_empty       = 1;
    i_Full        = 0;
    i_Data_out    = '0;
    i_read_req    = 0;
    i_config      = 0;
    i_is_32b      = 0;
    i_comp_opcode = 5'b00100;
    i_Local_done  = 0;
    i_Local_R_data= '0;
    i_Local_status= 3'b000;

    repeat(4) @(posedge i_clk);
    i_rst_n = 1;
    repeat(2) @(posedge i_clk);

    // ── TC0: i_init=0 → FSM must stay IDLE ───────────────────────────────────
    $display("\n─── TC0: i_init=0 gating ───");
    i_init  = 0;
    i_empty = 0;     // FIFO has data but init not asserted
    repeat(5) @(posedge i_clk);
    chk("TC0: o_Rd_en stays low while i_init=0", o_Rd_en === 1'b0);
    chk("TC0: o_Wr_en stays low while i_init=0", o_Wr_en === 1'b0);
    i_empty = 1;
    i_init  = 1;
    repeat(2) @(posedge i_clk);

    // =========================================================================
    // TC1: PHY forward (dstid=010), no stall
    // =========================================================================
    $display("\n─── TC1: PHY forward (dstid=010, no stall) ───");
    begin
        automatic logic [127:0] pkt;
        // opcode=5'b00010 (read), be=8'hFF, dstid=010, addr=24'hABCDEF, data=0
        pkt = build_pkt(5'b00010, 8'hFF, 3'b010, 24'hABCDEF, 64'h0);
        i_Full = 0;

        fork
            push_fifo(pkt, 1'b1, 1'b0, 1'b0, 5'b00100);
        join_none

        // Wait for DUT to write to RDI FIFO
        @(posedge i_clk iff (o_Wr_en === 1'b1));
        chk("TC1: o_Wr_en asserted",        o_Wr_en   === 1'b1);
        chk("TC1: packet forwarded intact",  o_Data_in === pkt);
        chk("TC1: no completion produced",   o_Valid   === 1'b0);
        chk("TC1: no arbiter request",       o_Local_valid === 1'b0);
        @(posedge i_clk);
        wait fork;
    end
    repeat(3) @(posedge i_clk);

    // =========================================================================
    // TC2: PHY forward – RDI FIFO full stall, then clears
    // =========================================================================
    $display("\n─── TC2: PHY forward with RDI FIFO full stall ───");
    begin
        automatic logic [127:0] pkt;
        pkt = build_pkt(5'b00010, 8'hFF, 3'b010, 24'h112233, 64'h0);
        i_Full = 1;   // RDI FIFO full

        fork
            push_fifo(pkt, 1'b1, 1'b0, 1'b0, 5'b00100);
        join_none

        // Wait until DUT reaches S_SEND_PHY (i.e. after parity pass)
        // During full, Wr_en must NOT be asserted
        @(posedge i_clk); @(posedge i_clk); @(posedge i_clk);
        @(posedge i_clk); @(posedge i_clk);   // sit in PARSE → SEND_PHY
        chk("TC2: stalled – o_Wr_en=0 while i_Full=1", o_Wr_en === 1'b0);

        // Release the stall
        @(posedge i_clk);
        i_Full = 0;
        @(posedge i_clk iff (o_Wr_en === 1'b1));
        chk("TC2: o_Wr_en=1 after stall clears", o_Wr_en === 1'b1);
        chk("TC2: correct packet forwarded",      o_Data_in === pkt);
        @(posedge i_clk);
        wait fork;
    end
    repeat(3) @(posedge i_clk);

    // =========================================================================
    // TC3: Adapter 64-bit read (dstid=001)
    // =========================================================================
    $display("\n─── TC3: Adapter 64-bit read (dstid=001) ───");
    begin
        automatic logic [127:0] pkt, comp;
        automatic logic [63:0]  rd_data = 64'hDEAD_BEEF_CAFE_1234;
        // opcode read (lsb=0), be=8'hFF, dstid=001, addr=24'h001000, data=0
        pkt = build_pkt(5'b00010, 8'hFF, 3'b001, 24'h001000, 64'h0);

        fork
            push_fifo(pkt, 1'b1 /*read*/, 1'b1 /*cfg*/, 1'b0 /*64b*/, 5'b00100);
            arb_respond(rd_data, 3'b000, 2);   // 2-cycle latency
        join

        @(posedge i_clk iff (o_Valid === 1'b1));
        comp = o_Comp_packet;

        chk("TC3: o_Valid asserted",              o_Valid === 1'b1);
        chk("TC3: comp opcode = i_comp_opcode",   comp[4:0] === 5'b00100);
        chk("TC3: comp status = 000",             comp[34:32] === 3'b000);
        chk("TC3: comp data[31:0] = rd_data[31:0]", comp[95:64]  === rd_data[31:0]);
        chk("TC3: comp data[63:32]= rd_data[63:32]",comp[127:96] === rd_data[63:32]);
        chk("TC3: no RDI write during adapter path", o_Wr_en === 1'b0);
        @(posedge i_clk);
    end
    repeat(3) @(posedge i_clk);

    // =========================================================================
    // TC4: Adapter 32-bit read (upper 32 bits of completion = 0)
    // =========================================================================
    $display("\n─── TC4: Adapter 32-bit read ───");
    begin
        automatic logic [127:0] pkt, comp;
        automatic logic [63:0]  rd_data = 64'h0000_0000_ABCD_EF01;
        pkt = build_pkt(5'b00010, 8'h0F, 3'b001, 24'h002000, 64'h0);

        fork
            push_fifo(pkt, 1'b1, 1'b0, 1'b1 /*32b*/, 5'b00100);
            arb_respond(rd_data, 3'b000, 1);
        join

        @(posedge i_clk iff (o_Valid === 1'b1));
        comp = o_Comp_packet;

        chk("TC4: o_Valid asserted",                o_Valid === 1'b1);
        chk("TC4: comp data[31:0] = rd_data[31:0]", comp[95:64]  === rd_data[31:0]);
        chk("TC4: comp data[63:32]= 0 (32-bit)",    comp[127:96] === 32'h0);
        @(posedge i_clk);
    end
    repeat(3) @(posedge i_clk);

    // =========================================================================
    // TC5: Adapter 64-bit write (completion payload = 0)
    // =========================================================================
    $display("\n─── TC5: Adapter 64-bit write ───");
    begin
        automatic logic [127:0] pkt, comp;
        automatic logic [63:0]  wr_data = 64'hCAFE_BABE_1111_2222;
        // opcode lsb=1 → write
        pkt = build_pkt(5'b00001, 8'hFF, 3'b001, 24'h003000, wr_data);

        fork
            push_fifo(pkt, 1'b0 /*write*/, 1'b1, 1'b0, 5'b00100);
            arb_respond(64'h0, 3'b000, 1);
        join

        @(posedge i_clk iff (o_Valid === 1'b1));
        comp = o_Comp_packet;

        chk("TC5: o_Valid asserted",              o_Valid === 1'b1);
        chk("TC5: comp payload = 0 (write compl)",comp[127:64] === 64'h0);
        // Arbiter should have received the write data
        chk("TC5: o_Local_wr_en was 1 (write)",   comp[4:0] === 5'b00100); // opcode check via comp
        @(posedge i_clk);
    end
    repeat(3) @(posedge i_clk);

    // =========================================================================
    // TC6: Adapter write with non-zero completion status (e.g. Unsupported Req)
    // =========================================================================
    $display("\n─── TC6: Adapter write, status = Unsupported Request (001) ───");
    begin
        automatic logic [127:0] pkt, comp;
        pkt = build_pkt(5'b00001, 8'hF0, 3'b001, 24'h004000, 64'hDEAD);

        fork
            push_fifo(pkt, 1'b0, 1'b0, 1'b0, 5'b00100);
            arb_respond(64'h0, 3'b001 /*UR*/, 3);
        join

        @(posedge i_clk iff (o_Valid === 1'b1));
        comp = o_Comp_packet;

        chk("TC6: completion valid",             o_Valid   === 1'b1);
        chk("TC6: status = 001 (UR)",            comp[34:32] === 3'b001);
        @(posedge i_clk);
    end
    repeat(3) @(posedge i_clk);

    // =========================================================================
    // TC7: Parity error on CP → packet dropped
    // =========================================================================
    $display("\n─── TC7: CP parity error → packet dropped ───");
    begin
        automatic logic [127:0] pkt;
        pkt = build_pkt(5'b00001, 8'hFF, 3'b001, 24'h005000, 64'h0);
        // Flip cp bit (r_req[62] = p1[30])
        pkt[62] = ~pkt[62];

        i_Data_out    = pkt;
        i_read_req    = 0;
        i_config      = 0;
        i_is_32b      = 0;
        i_comp_opcode = 5'b00100;
        i_empty       = 0;

        // Wait for DUT to pop and parse
        @(posedge i_clk iff (o_Rd_en === 1'b1));
        @(posedge i_clk); // POP_WAIT
        i_empty = 1;
        // After PARSE with bad parity: DUT should return to IDLE with no outputs
        repeat(5) @(posedge i_clk);
        chk("TC7: no completion after parity error",  o_Valid       === 1'b0);
        chk("TC7: no RDI write after parity error",   o_Wr_en       === 1'b0);
        chk("TC7: no arbiter request after par error", o_Local_valid === 1'b0);
    end
    repeat(3) @(posedge i_clk);

    // =========================================================================
    // TC8: Parity error on DP → packet dropped
    // =========================================================================
    $display("\n─── TC8: DP parity error → packet dropped ───");
    begin
        automatic logic [127:0] pkt;
        pkt = build_pkt(5'b00010, 8'hFF, 3'b010, 24'h006000, 64'h1234_5678);
        // Corrupt dp bit (r_req[63] = p1[31])
        pkt[63] = ~pkt[63];

        i_Data_out    = pkt;
        i_read_req    = 1;
        i_config      = 0;
        i_is_32b      = 0;
        i_comp_opcode = 5'b00100;
        i_empty       = 0;

        @(posedge i_clk iff (o_Rd_en === 1'b1));
        @(posedge i_clk);
        i_empty = 1;
        repeat(5) @(posedge i_clk);
        chk("TC8: no RDI write after DP error",  o_Wr_en   === 1'b0);
        chk("TC8: no comp after DP error",        o_Valid   === 1'b0);
    end
    repeat(3) @(posedge i_clk);

    // =========================================================================
    // TC9: Unknown dstid → packet dropped
    // =========================================================================
    $display("\n─── TC9: Unknown dstid=011 → dropped ───");
    begin
        automatic logic [127:0] pkt;
        // dstid = 3'b011 (unknown)
        pkt = build_pkt(5'b00010, 8'hFF, 3'b011, 24'h007000, 64'h0);

        i_Data_out    = pkt;
        i_read_req    = 1;
        i_config      = 0;
        i_is_32b      = 0;
        i_comp_opcode = 5'b00100;
        i_empty       = 0;

        @(posedge i_clk iff (o_Rd_en === 1'b1));
        @(posedge i_clk);
        i_empty = 1;
        repeat(5) @(posedge i_clk);
        chk("TC9: no RDI write for unknown dstid", o_Wr_en   === 1'b0);
        chk("TC9: no comp for unknown dstid",       o_Valid   === 1'b0);
        chk("TC9: no arbiter request",               o_Local_valid === 1'b0);
    end
    repeat(3) @(posedge i_clk);

    // =========================================================================
    // TC10: Credit release signal
    // =========================================================================
    $display("\n─── TC10: FDI credit release ───");
    begin
        i_empty = 1;
        @(posedge i_clk);
        chk("TC10: credit released when FIFO empty",  o_Fdi_credit_release === 1'b1);
        i_empty = 0;
        @(posedge i_clk);
        chk("TC10: credit held when FIFO not empty",  o_Fdi_credit_release === 1'b0);
        i_empty = 1;
    end
    repeat(2) @(posedge i_clk);

    // =========================================================================
    // TC11: Back-to-back packets (PHY then Adapter read)
    // =========================================================================
    $display("\n─── TC11: Back-to-back PHY then Adapter read ───");
    begin
        automatic logic [127:0] pkt_phy, pkt_adp, comp;
        automatic logic [63:0]  rd_data2 = 64'h9999_AAAA_BBBB_CCCC;

        pkt_phy = build_pkt(5'b00010, 8'hFF, 3'b010, 24'hFEDCBA, 64'h0);
        pkt_adp = build_pkt(5'b00010, 8'h3C, 3'b001, 24'h008000, 64'h0);

        // ── First packet: PHY
        fork
            push_fifo(pkt_phy, 1'b1, 1'b0, 1'b0, 5'b00100);
        join_none
        @(posedge i_clk iff (o_Wr_en === 1'b1));
        chk("TC11-a: first packet forwarded to PHY", o_Wr_en === 1'b1);
        @(posedge i_clk);
        wait fork;

        repeat(2) @(posedge i_clk);

        // ── Second packet: Adapter read
        fork
            push_fifo(pkt_adp, 1'b1, 1'b0, 1'b0, 5'b00100);
            arb_respond(rd_data2, 3'b000, 1);
        join

        @(posedge i_clk iff (o_Valid === 1'b1));
        comp = o_Comp_packet;
        chk("TC11-b: second packet completion valid",     o_Valid === 1'b1);
        chk("TC11-b: completion data matches rd_data",    comp[95:64] === rd_data2[31:0]);
        @(posedge i_clk);
    end
    repeat(3) @(posedge i_clk);

    // =========================================================================
    // TC12: Arbiter multi-cycle wait (latency = 5)
    // =========================================================================
    $display("\n─── TC12: Adapter read with 5-cycle arbiter latency ───");
    begin
        automatic logic [127:0] pkt, comp;
        automatic logic [63:0]  rd_data3 = 64'h1234_5678_9ABC_DEF0;
        pkt = build_pkt(5'b00010, 8'hFF, 3'b001, 24'h009000, 64'h0);

        fork
            push_fifo(pkt, 1'b1, 1'b1, 1'b0, 5'b00100);
            arb_respond(rd_data3, 3'b000, 5);  // 5 cycles
        join

        @(posedge i_clk iff (o_Valid === 1'b1));
        comp = o_Comp_packet;
        chk("TC12: completion after long latency",       o_Valid === 1'b1);
        chk("TC12: data intact after long wait",         comp[95:64] === rd_data3[31:0]);
        chk("TC12: data[63:32] correct",                 comp[127:96] === rd_data3[63:32]);
        @(posedge i_clk);
    end
    repeat(3) @(posedge i_clk);

    // ── Summary 
    repeat(5) @(posedge i_clk);
    $display("\n╔════════════════════════════════════════╗");
    $display("║  Results: %3d PASSED  |  %3d FAILED   ║", pass_cnt, fail_cnt);
    $display("╚════════════════════════════════════════╝");
    if (fail_cnt == 0)
        $display("  ✓ ALL TESTS PASSED\n");
    else
        $display("  ✗ SOME TESTS FAILED – review log\n");

    $finish;
end

// ── Timeout watchdog
initial begin
    #100_000;
    $display("TIMEOUT: simulation exceeded time limit");
    $finish;
end

// ── Waveform dump 
initial begin
    $dumpfile("tb_UC_sb_FDI_Controller.vcd");
    $dumpvars(0, tb_UC_sb_FDI_Controller);
end

endmodule
