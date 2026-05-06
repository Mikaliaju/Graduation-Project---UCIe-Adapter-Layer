/*
===========================================================================
 File Name   : UC_sb_top_tb.sv
 Project     : UCIe 3.0 Adapter Layer - Sideband Unit
===========================================================================
 Module      : UC_sb_top Testbench
 Authors     : Shahd Mohamed, Ashraf Sherif
=========================================================================== 
*/
`timescale 1ns/100ps
import UC_sb_rx_pkg::*;
/*
==============================================================================================
                                Request Packet Class                                    
==============================================================================================
*/
class Request_Pkt;
    // Header fields
    logic [2:0]  srcid;         // Source ID: fixed as 000b
    logic [4:0]  tag;           // 5-bit Tag field
    logic [7:0]  byte_en;       // 8-bit Byte Enable field
    randc logic [4:0] opcode;   // 5-bit opcode field
    logic [2:0]  dstid;         // 3-bit Destination ID
    logic [23:0] addr;          // 24-bit address
    logic        header_parity;
    logic        data_parity;

    // Data field
    rand logic [63:0] data;
    bit has_data;

    // Packet phases
    logic [31:0] phase1, phase2, phase3, phase4;
    logic [127:0] constructed_pkt;

    // Opcode definitions
    localparam logic [4:0] MEM_RD32 = 5'b00000;
    localparam logic [4:0] MEM_WR32 = 5'b00001;
    localparam logic [4:0] CFG_RD32 = 5'b00100;
    localparam logic [4:0] CFG_WR32 = 5'b00101;
    localparam logic [4:0] MEM_RD64 = 5'b01000;
    localparam logic [4:0] MEM_WR64 = 5'b01001;
    localparam logic [4:0] CFG_RD64 = 5'b01100;
    localparam logic [4:0] CFG_WR64 = 5'b01101;

    constraint c_opcode {
        opcode inside {MEM_RD32, MEM_WR32, CFG_RD32, CFG_WR32,
                       MEM_RD64, MEM_WR64, CFG_RD64, CFG_WR64};
    }

    function new(input logic [4:0] tag,
                 input logic [7:0] byte_en,
                 input logic [2:0] dstid,
                 input logic [23:0] addr = 24'd0);
        this.srcid   = 3'b000;
        this.tag     = tag;
        this.byte_en = byte_en;
        if (!this.randomize()) begin
            $display("Randomization failed");
            $finish;
        end
        this.addr  = addr;
        this.dstid = dstid;

        // Determine if packet has data
        if ((opcode == MEM_WR32) || (opcode == CFG_WR32) ||
            (opcode == MEM_WR64) || (opcode == CFG_WR64))
            has_data = 1;
        else
            has_data = 0;

        build_packet();
    endfunction

    function void build_packet();
        // Phase 1
        phase1 = {srcid, 2'b00, tag, byte_en, 9'b0, opcode};

        // Header parity
        header_parity = ^({phase1, 3'b000, dstid, addr});

        // Data phases
        if (has_data) begin
            phase3 = data[31:0];
            if ((opcode == MEM_WR32) || (opcode == CFG_WR32))
                phase4 = 32'd0;
            else
                phase4 = data[63:32];
        end else begin
            phase3 = 32'd0;
            phase4 = 32'd0;
        end

        data_parity = ^({phase4, phase3});
        phase2 = {data_parity, header_parity, 3'b000, dstid, addr};
        constructed_pkt = {phase4, phase3, phase2, phase1};
    endfunction
endclass

/*
==============================================================================================
                                      Testbench Module                                    
==============================================================================================
*/
module UC_sb_top_tb;

    /*---------------------------------------------
      Parameters
    ---------------------------------------------*/
    parameter CLK_PERIOD = 10;
    parameter DUTY_CYCLE = 0.5;
    parameter HIGH_TIME  = CLK_PERIOD * DUTY_CYCLE;
    parameter LOW_TIME   = CLK_PERIOD * (1 - DUTY_CYCLE);

    parameter P_NC = 32;
    parameter P_RX_NUM_OF_COMP_PKTS = 4;
    parameter P_RX_NUM_OF_MSG_PKTS  = 2;
    parameter P_TX_FDI_FIFO_DEPTH = 32;
    parameter P_TX_FIFO_WIDTH = 128;
    parameter P_TX_DATA_W = 64;
    parameter P_CL_MAX_CREDITS = 32;

    /*---------------------------------------------
      TB Signals
    ---------------------------------------------*/
    // Global
    logic i_clk;
    logic i_rst_n;
    logic i_init_n;

    // RDI Interface
    logic [P_NC-1:0] i_rdi_pl_cfg;
    logic            i_rdi_pl_cfg_vld;
    logic            i_rdi_pl_cfg_crd;
    logic [P_NC-1:0] o_rdi_lp_cfg;
    logic            o_rdi_lp_cfg_vld;
    logic            o_rdi_lp_cfg_crd;

    // FDI Interface
    logic [P_NC-1:0] i_fdi_lp_cfg;
    logic            i_fdi_lp_cfg_vld;
    logic            i_fdi_lp_cfg_crd;
    logic [P_NC-1:0] o_fdi_pl_cfg;
    logic            o_fdi_pl_cfg_vld;
    logic            o_fdi_pl_cfg_crd;
    logic [3:0]      o_fdi_pl_protocol;
    logic [3:0]      o_fdi_pl_flit_fmt;

    // LSM & Error Handling
    `ifndef END_POINT
    sb_error_msg_encoding o_sb_err_msg_rx;
    logic                 o_sb_remote_timeout;
    `else
    logic                 o_sb_local_timeout;
    `endif
    sb_state_msg_encoding o_sb_state_msg_rx;
    logic                 o_sb_rdi_overflow;
    logic                 o_sb_fdi_overflow;
    logic                 o_sb_parity_error;
    logic                 o_sb_linkerr_req;
    logic                 o_sb_fdi_packer_error;

    // LSM Control
    logic                 i_sb_start_param_exch;
    logic                 o_sb_param_exch_done;
    logic                 o_sb_invalid_param_exch;
    logic                 o_sb_param_exch_timeout;
    logic                 o_sb_retry_negotiated;
    sb_state_msg_encoding i_sb_state_msg_tx;
    `ifdef END_POINT
    sb_error_msg_encoding i_sb_err_msg_tx;
    `endif

    // Register File Interface
    logic [63:0] i_reg_read_data;
    logic [2:0]  i_reg_status;
    logic [63:0] o_reg_write_data;
    logic        o_reg_write_en;
    logic [23:0] o_reg_address;
    logic [7:0]  o_reg_be;
    logic        o_reg_config_req;
    logic        o_reg_32_B;
    logic        o_reg_valid;

    // Mailbox (RP only)
    `ifndef END_POINT
    logic [31:0] i_mailbox_index_low;
    logic [4:0]  i_mailbox_index_high;
    logic [31:0] i_mailbox_data_low;
    logic [31:0] i_mailbox_data_high;
    logic        i_mailbox_trigger;
    logic [3:0]  i_remote_access_threshold;
    logic [31:0] o_mailbox_data_low;
    logic [31:0] o_mailbox_data_high;
    logic        o_mailbox_data_en;
    logic        o_mailbox_trigger_en;
    logic [1:0]  o_mailbox_status;
    logic [63:0] o_header_log_1;
    logic        o_header_log_en;
    `endif

    // Parameter Exchange
    logic [63:0] i_adapter_advcap;
    logic [63:0] i_cxl_advcap;
    logic        i_format4_enabled;
    logic        i_format6_enabled;
    logic        i_retry_needed;
    logic        i_retry_negotiated;
    logic [4:0]  i_flit_fmt_status;
    logic [63:0] o_adapter_advcap;
    logic [63:0] o_adapter_fincap;
    logic [63:0] o_cxl_advcap;
    logic [63:0] o_cxl_fincap;
    logic        o_adapter_advcap_valid;
    logic        o_adapter_fincap_valid;
    logic        o_cxl_advcap_valid;
    logic        o_cxl_fincap_valid;
    logic [4:0]  o_flit_format_status;
    logic        o_flitfmt_valid;
    logic       i_flit_fmt_status_set;
    /*---------------------------------------------
      DUT Instantiation
    ---------------------------------------------*/
    UC_sb_top #(
        .P_NC                  (P_NC),
        .P_RX_NUM_OF_COMP_PKTS (P_RX_NUM_OF_COMP_PKTS),
        .P_RX_NUM_OF_MSG_PKTS  (P_RX_NUM_OF_MSG_PKTS),
        .P_TX_FDI_FIFO_DEPTH   (P_TX_FDI_FIFO_DEPTH),
        .P_TX_FIFO_WIDTH       (P_TX_FIFO_WIDTH),
        .P_TX_DATA_W           (P_TX_DATA_W),
        .P_CL_MAX_CREDITS      (P_CL_MAX_CREDITS)
    ) dut (
        // Global
        .i_clk                    (i_clk),
        .i_rst_n                  (i_rst_n),
        .i_init_n                 (i_init_n),

        // RDI
        .i_rdi_pl_cfg             (i_rdi_pl_cfg),
        .i_rdi_pl_cfg_vld         (i_rdi_pl_cfg_vld),
        .i_rdi_pl_cfg_crd         (i_rdi_pl_cfg_crd),
        .o_rdi_lp_cfg             (o_rdi_lp_cfg),
        .o_rdi_lp_cfg_vld         (o_rdi_lp_cfg_vld),
        .o_rdi_lp_cfg_crd         (o_rdi_lp_cfg_crd),

        // FDI
        .i_fdi_lp_cfg             (i_fdi_lp_cfg),
        .i_fdi_lp_cfg_vld         (i_fdi_lp_cfg_vld),
        .i_fdi_lp_cfg_crd         (i_fdi_lp_cfg_crd),
        .o_fdi_pl_cfg             (o_fdi_pl_cfg),
        .o_fdi_pl_cfg_vld         (o_fdi_pl_cfg_vld),
        .o_fdi_pl_cfg_crd         (o_fdi_pl_cfg_crd),
        .o_fdi_pl_protocol        (o_fdi_pl_protocol),
        .o_fdi_pl_flit_fmt        (o_fdi_pl_flit_fmt),

        // LSM & Error
        `ifndef END_POINT
        .o_sb_err_msg_rx          (o_sb_err_msg_rx),
        .o_sb_remote_timeout      (o_sb_remote_timeout),
        `else
        .o_sb_local_timeout       (o_sb_local_timeout),
        `endif
        .o_sb_state_msg_rx        (o_sb_state_msg_rx),
        .o_sb_rdi_overflow        (o_sb_rdi_overflow),
        .o_sb_fdi_overflow        (o_sb_fdi_overflow),
        .o_sb_parity_error        (o_sb_parity_error),
        .o_sb_opid_err            (o_sb_linkerr_req),
        .o_sb_fdi_packer_error    (o_sb_fdi_packer_error),

        // LSM Control
        .i_sb_start_param_exch    (i_sb_start_param_exch),
        .o_sb_param_exch_done     (o_sb_param_exch_done),
        .o_sb_invalid_param_exch  (o_sb_invalid_param_exch),
        .o_sb_param_exch_timeout  (o_sb_param_exch_timeout),
        .o_sb_retry_negotiated    (o_sb_retry_negotiated),
        .i_sb_state_msg_tx        (i_sb_state_msg_tx),
        `ifdef END_POINT
        .i_sb_err_msg_tx          (i_sb_err_msg_tx),
        `endif

        // Register File
        .i_reg_read_data          (i_reg_read_data),
        .i_reg_status             (i_reg_status),
        .o_reg_write_data         (o_reg_write_data),
        .o_reg_write_en           (o_reg_write_en),
        .o_reg_address            (o_reg_address),
        .o_reg_be                 (o_reg_be),
        .o_reg_config_req         (o_reg_config_req),
        .o_reg_32_B               (o_reg_32_B),
        .o_reg_valid              (o_reg_valid),

        // Mailbox (RP only)
        `ifndef END_POINT
        .i_mailbox_index_low      (i_mailbox_index_low),
        .i_mailbox_index_high     (i_mailbox_index_high),
        .i_mailbox_data_low       (i_mailbox_data_low),
        .i_mailbox_data_high      (i_mailbox_data_high),
        .i_mailbox_trigger        (i_mailbox_trigger),
        .i_remote_access_threshold(i_remote_access_threshold),
        .o_mailbox_data_low       (o_mailbox_data_low),
        .o_mailbox_data_high      (o_mailbox_data_high),
        .o_mailbox_data_en        (o_mailbox_data_en),
        .o_mailbox_trigger_en     (o_mailbox_trigger_en),
        .o_mailbox_status         (o_mailbox_status),
        .o_header_log_1           (o_header_log_1),
        .o_header_log_en          (o_header_log_en),
        `endif

        // Parameter Exchange
        .i_adapter_advcap         (i_adapter_advcap),
        .i_cxl_advcap             (i_cxl_advcap),
        .i_format4_enabled        (i_format4_enabled),
        .i_format6_enabled        (i_format6_enabled),
        .i_retry_needed           (i_retry_needed),
        .i_retry_negotiated       (i_retry_negotiated),
        .i_flit_fmt_status        (i_flit_fmt_status),
        .o_adapter_advcap         (o_adapter_advcap),
        .o_adapter_fincap         (o_adapter_fincap),
        .o_cxl_advcap             (o_cxl_advcap),
        .o_cxl_fincap             (o_cxl_fincap),
        .o_adapter_advcap_valid   (o_adapter_advcap_valid),
        .o_adapter_fincap_valid   (o_adapter_fincap_valid),
        .o_cxl_advcap_valid       (o_cxl_advcap_valid),
        .o_cxl_fincap_valid       (o_cxl_fincap_valid),
        .o_flit_format_status     (o_flit_format_status),
        .o_flitfmt_valid          (o_flitfmt_valid)
    );

    /*---------------------------------------------
      Clock Generator
    ---------------------------------------------*/
    always begin
        #LOW_TIME  i_clk = ~i_clk;
        #HIGH_TIME i_clk = ~i_clk;
    end

    /*---------------------------------------------
      Initial Block
    ---------------------------------------------*/
    initial begin
        $dumpfile("UC_sb_top.vcd");
        $dumpvars(0, UC_sb_top_tb);

        initialize();
        reset();


        // Test Case 2: PCIe Parameter Exchange with Format4
        $display("\n=== Test Case 1: PCIe Parameter Exchange ===");
        do_PCIe_parameter_exchange("Format3", 1);

        // Test Case 2: Send PHY request and receive completion
        $display("\n=== Test Case 2: PHY Request with Completion ===");
        send_phy_request_and_receive_its_completion();

        // Test Case 3: Send adapter request and pass completion
        $display("\n=== Test Case 3: Adapter Requests  ===");
        repeat (8) send_adapter_request_and_pass_its_completion();

        // Test Case 5: LSM State Messages
        $display("\n=== Test Case 4: LSM State Messages ===");
        send_lsm_state_msg(ACTIVE_REQ);
        send_lsm_state_msg(LINKRESET_REQ);
        send_two_consecutive_lsm_state_msg();
        #1000;
        $display("\n=== All tests completed successfully! ===");
        $finish;
    end

    /*---------------------------------------------
      Tasks
    ---------------------------------------------*/
    task initialize();
        i_clk    = 0;
        i_rst_n  = 1;
        i_init_n = 1;
        i_flit_fmt_status_set = 0;
        i_rdi_pl_cfg = '0;
        i_rdi_pl_cfg_vld = '0;
        i_rdi_pl_cfg_crd = '0;

        i_fdi_lp_cfg = '0;
        i_fdi_lp_cfg_vld = '0;
        i_fdi_lp_cfg_crd = '0;

        i_sb_start_param_exch = '0;
        i_sb_state_msg_tx = NONE;
        `ifdef END_POINT
        i_sb_err_msg_tx = NONE_ERR;
        `endif

        i_reg_read_data = '0;
        i_reg_status = '0;

        `ifndef END_POINT
        i_mailbox_index_low = '0;
        i_mailbox_index_high = '0;
        i_mailbox_data_low = '0;
        i_mailbox_data_high = '0;
        i_mailbox_trigger = '0;
        i_remote_access_threshold = '0;
        `endif

        i_adapter_advcap = '0;
        i_cxl_advcap = '0;
        i_format4_enabled = '0;
        i_format6_enabled = '0;
        i_retry_needed = '0;
        i_flit_fmt_status = '0;
    endtask

    task reset();
        $display("Applying reset...");
        i_rst_n = 0;
        #(CLK_PERIOD);
        i_rst_n = 1;
        #(CLK_PERIOD);
    endtask

    task receive_fdi_full_packet(logic [127:0] full_packet);
        for (int chunk = 0; chunk < 128/P_NC; chunk++) begin
            @(posedge i_clk);
            i_fdi_lp_cfg = (full_packet >> (chunk * P_NC));
            i_fdi_lp_cfg_vld = 1;
        end
        #CLK_PERIOD;
        i_fdi_lp_cfg_vld = 0;
    endtask

    task receive_fdi_half_packet(logic [63:0] half_packet);
        for (int chunk = 0; chunk < 64/P_NC; chunk++) begin
            @(posedge i_clk);
            i_fdi_lp_cfg = (half_packet >> (chunk * P_NC));
            i_fdi_lp_cfg_vld = 1;
        end
        #CLK_PERIOD;
        i_fdi_lp_cfg_vld = 0;
    endtask

    task receive_rdi_full_packet(logic [127:0] full_packet);
        for (int chunk = 0; chunk < 128/P_NC; chunk++) begin
            @(posedge i_clk);
            i_rdi_pl_cfg = (full_packet >> (chunk * P_NC));
            i_rdi_pl_cfg_vld = 1;
        end
        #CLK_PERIOD;
        i_rdi_pl_cfg_vld = 0;
    endtask

    task receive_rdi_half_packet(logic [63:0] half_packet);
        for (int chunk = 0; chunk < 64/P_NC; chunk++) begin
            @(posedge i_clk);
            i_rdi_pl_cfg = (half_packet >> (chunk * P_NC));
            i_rdi_pl_cfg_vld = 1;
        end
        #CLK_PERIOD;
        i_rdi_pl_cfg_vld = 0;
    endtask

    task collect_fdi_full_packet(output logic [127:0] full_packet);
        for (int chunk = 0; chunk < 128/P_NC; chunk++) begin
            @(posedge i_clk);
            if (chunk == 0)
                full_packet = o_fdi_pl_cfg;
            else
                full_packet = full_packet | (o_fdi_pl_cfg << (chunk * P_NC));
        end
    endtask

    task collect_fdi_half_packet(output logic [63:0] half_packet);
        for (int chunk = 0; chunk < 64/P_NC; chunk++) begin
            @(posedge i_clk);
            if (chunk == 0)
                half_packet = o_fdi_pl_cfg;
            else
                half_packet = half_packet | (o_fdi_pl_cfg << (chunk * P_NC));
        end
    endtask

    task collect_rdi_full_packet(output logic [127:0] full_packet);
        for (int chunk = 0; chunk < 128/P_NC; chunk++) begin
            @(posedge i_clk);
            if (chunk == 0)
                full_packet = o_rdi_lp_cfg;
            else
                full_packet = full_packet | (o_rdi_lp_cfg << (chunk * P_NC));
        end
    endtask

    task collect_rdi_half_packet(output logic [63:0] half_packet);
        for (int chunk = 0; chunk < 64/P_NC; chunk++) begin
            @(posedge i_clk);
            if (chunk == 0)
                half_packet = o_rdi_lp_cfg;
            else
                half_packet = half_packet | (o_rdi_lp_cfg << (chunk * P_NC));
        end
    endtask


    task do_PCIe_parameter_exchange(input string flit_format, input with_retry);
        if (with_retry) begin
            case (flit_format)
                "Format2": i_adapter_advcap = 64'h0_0080_00aa;
                "Format3": i_adapter_advcap = 64'h0_0100_00aa;
                "Format4": i_adapter_advcap = 64'h0_0700_00aa;
                "Format6": i_adapter_advcap = 64'h0_0F00_00aa;
                default: $error("Invalid flit format");
            endcase
            i_retry_needed = 1;
        end else begin
            case (flit_format)
                "Format2": i_adapter_advcap = 64'h0_0080_008a;
                "Format3": i_adapter_advcap = 64'h0_0100_008a;
                "Format4": i_adapter_advcap = 64'h0_0700_008a;
                "Format6": i_adapter_advcap = 64'h0_0F00_008a;
                default: $error("Invalid flit format");
            endcase
            i_retry_needed = 0;
        end

        i_cxl_advcap = 64'h1;
        i_format4_enabled = 1;
        i_format6_enabled = 1;

        @(posedge i_clk);
        i_sb_start_param_exch = 1;
        @(posedge i_clk);
        i_sb_start_param_exch = 0;

        `ifdef END_POINT
        receive_rdi_full_packet({i_adapter_advcap, ^i_adapter_advcap, 63'h05000000_2000401b});
        @(negedge o_rdi_lp_cfg_vld);
        #(10 * CLK_PERIOD);
        receive_rdi_full_packet({i_adapter_advcap, ^i_adapter_advcap, 63'h05000000_2000801b});
        receive_rdi_full_packet({i_cxl_advcap, ^i_cxl_advcap, 63'h45000001_2000401b});
        @(negedge o_rdi_lp_cfg_vld);
        #(10 * CLK_PERIOD);
        receive_rdi_full_packet({i_cxl_advcap, ^i_cxl_advcap, 63'h45000001_2000801b});
        `else
        @(negedge o_rdi_lp_cfg_vld);
        #(10 * CLK_PERIOD);
        receive_rdi_full_packet({i_adapter_advcap, ^i_adapter_advcap, 63'h05000000_2000401b});
        @(negedge o_rdi_lp_cfg_vld);
        #(10 * CLK_PERIOD);
        receive_rdi_full_packet({i_cxl_advcap, ^i_cxl_advcap, 63'h45000001_2000401b});
        @(negedge o_rdi_lp_cfg_vld);
        `endif

        wait (o_sb_param_exch_done);
        $display("PCIe PARAMETER EXCHANGE DONE! \n");
    endtask

    task send_phy_request_and_receive_its_completion();
        Request_Pkt req_pkt;
        logic [23:0] address;
        logic [4:0] orig_tag, new_tag;
        logic [127:0] comp_pkt, request_pkt;

        address = $random;
        do begin
            orig_tag = $random % 32;
        end while (orig_tag == 5'b11111);

        req_pkt = new(orig_tag, 8'hFF, 3'b010, address);
        if (req_pkt.has_data)
            receive_fdi_full_packet(req_pkt.constructed_pkt);
        else
            receive_fdi_half_packet(req_pkt.constructed_pkt);

        @(posedge o_rdi_lp_cfg_vld);
        if (req_pkt.has_data)
            collect_rdi_full_packet(request_pkt);
        else
            collect_rdi_half_packet(request_pkt);

        new_tag = request_pkt[26:22];

        if (req_pkt.has_data) begin
            comp_pkt = 128'h00000000_01C00010;
            comp_pkt[26:22] = new_tag;
            receive_rdi_half_packet(comp_pkt);
        end else begin
            comp_pkt = 128'hbbbbbbbb_aaaaaaaa_00000000_01C00019;
            comp_pkt[26:22] = new_tag;
            receive_rdi_full_packet(comp_pkt);
        end

        @(posedge o_fdi_pl_cfg_vld);
        if (req_pkt.has_data)
            collect_fdi_half_packet(comp_pkt);
        else
            collect_fdi_full_packet(comp_pkt);

        if (comp_pkt[26:22] != orig_tag)
            $display("PHY Request Test FAILED - Tag mismatch");
        else
            $display("PHY Request Test PASSED ");
    endtask

    task send_adapter_request_and_pass_its_completion();
        Request_Pkt req_pkt;
        logic [23:0] address;
        logic [4:0] tag;
        logic [127:0] comp_pkt_tx, comp_pkt_rx;

        address = $random;
        do begin
            tag = $random % 32;
        end while (tag == 5'b11111);

        req_pkt = new(tag, 8'hFF, 3'b001, address);
        if (req_pkt.has_data)
            receive_fdi_full_packet(req_pkt.constructed_pkt);
        else
            receive_fdi_half_packet(req_pkt.constructed_pkt);

        @(posedge o_reg_valid)
        i_reg_read_data = 'hdddd_cccc_bbbb_aaaa;
        i_reg_status = '0;

        @(posedge o_fdi_pl_cfg_vld);
        if (req_pkt.has_data)
            collect_fdi_half_packet(comp_pkt_rx);
        else
            collect_fdi_full_packet(comp_pkt_rx);

        $display("Adapter Request Test PASSED ");
    endtask

    task send_lsm_state_msg(input sb_state_msg_encoding lsm_msg);
        logic [63:0] tx_lsm_msg, expected_lsm_msg;

        i_sb_state_msg_tx = lsm_msg;
        #(CLK_PERIOD);
        i_sb_state_msg_tx = NONE;

        @(posedge o_rdi_lp_cfg_vld);
        collect_rdi_half_packet(tx_lsm_msg);

        case (lsm_msg)
            ACTIVE_REQ:     expected_lsm_msg = 64'h05000001_2000C012;
            L1_REQ:         expected_lsm_msg = 64'h05000004_2000C012;
            L2_REQ:         expected_lsm_msg = 64'h05000008_2000C012;
            LINKRESET_REQ:  expected_lsm_msg = 64'h45000009_2000C012;
            DISABLED_REQ:   expected_lsm_msg = 64'h4500000C_2000C012;
            ACTIVE_RESP:    expected_lsm_msg = 64'h45000001_20010012;
            PMNAK_RESP:     expected_lsm_msg = 64'h45000002_20010012;
            L1_RESP:        expected_lsm_msg = 64'h45000004_20010012;
            L2_RESP:        expected_lsm_msg = 64'h45000008_20010012;
            LINKRESET_RESP: expected_lsm_msg = 64'h05000009_20010012;
            DISABLED_RESP:  expected_lsm_msg = 64'h0500000C_20010012;
        endcase

        if (tx_lsm_msg == expected_lsm_msg)
            $display("LSM State Message Test PASSED ");
        else
            $display("LSM State Message Test FAILED - Expected: %h, Got: %h", expected_lsm_msg, tx_lsm_msg);
    endtask

    task send_two_consecutive_lsm_state_msg();
        logic [127:0] two_msgs;

        i_sb_state_msg_tx = ACTIVE_REQ;
        #(CLK_PERIOD);
        i_sb_state_msg_tx = LINKRESET_REQ;
        #(CLK_PERIOD);
        i_sb_state_msg_tx = NONE;

        @(posedge o_rdi_lp_cfg_vld);
        collect_rdi_full_packet(two_msgs);

        if (two_msgs == {64'h45000009_2000C012, 64'h05000001_2000C012})
            $display("Consecutive LSM Messages Test PASSED ");
        else
            $display("Consecutive LSM Messages Test FAILED");
    endtask


    // Capture flit format status when it changes
    always_comb begin
    if (!i_flit_fmt_status_set && o_flit_format_status != 0) begin
        i_flit_fmt_status = o_flit_format_status; // Set i_flit_fmt_status to o_flit_format_status
        i_flit_fmt_status_set = 1;  // Set the flag to indicate that i_flit_fmt_status is set
    end
    // Once i_flit_fmt_status is set, it will remain high regardless of changes to o_flit_format_status
    else if (i_flit_fmt_status_set) begin
        i_flit_fmt_status = i_flit_fmt_status;  // Keep it high
    end else begin
        i_flit_fmt_status = 5'b0;  // Keep it zero if the flag is not set
    end
end
    // Retry is negotiated if it's needed and parameter exchange is done successfully
    assign i_retry_negotiated = i_retry_needed & o_sb_param_exch_done;

endmodule