/*
Author      : Shahd Mohamed , Ashraf Sherif
Module_name : UC_sb_remote_die_request_controller

Description :
Receives remote register access requests from the remote die and determines
whether the target is the Adapter or the PHY.

- Adapter access  -> read/write via Access Arbiter, build completion locally.
- PHY access      -> forward request over RDI, wait for PHY completion with timeout.

All outgoing packets (requests + completions) are sent to the RDI Controller.
*/
import UC_sb_pkg::*;
module UC_sb_remote_die_request_controller #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer TIMEOUT_MS  = 8
)(
    //------------------------------- inputs -----------------------------------//
    input  logic         i_clk,
    input  logic         i_rst_n,
    input  logic         i_init,
    input  logic [127:0] i_remote_req,
    input  logic         i_remote_req_vld,
    input  logic         i_read_req,
    input  logic [4:0]   i_comp_opcode,
    input  logic         i_is_phy_access,
    input  logic         i_pkt_length,
    input  logic [127:0] i_phy_comp,
    input  logic         i_phy_comp_vld,
    input  logic         i_comp_length,
    input  logic [2:0]   i_status,
    input  logic [63:0]  i_read_data,
    input  logic         i_req_sent,
    input  logic         i_remote_done,
    input  logic         i_32_b,
    input  logic         i_config,

    //----------------------------------- outputs --------------------------------//
    output logic [4:0]   o_opcode,
    output logic [23:0]  o_address,
    output logic [63:0]  o_remote_write_data,
    output logic         o_remote_wr_en,
    output logic [23:0]  o_remote_address,
    output logic [7:0]   o_remote_BE,
    output logic         o_remote_config_req,
    output logic         o_remote_32_B,
    output logic         o_remote_vld,
    output logic [127:0] o_pkt,
    output logic         o_pkt_vld,
    output logic         o_pkt_length,
    output logic         o_is_comp,
    output logic         o_local_timeout
);

    //--------------------------- constants ----------------------------//
    localparam logic [2:0] SRC_ADAPTER   = 3'b001;
    localparam logic [2:0] DST_LOCAL_PHY = 3'b010;

    localparam integer TIMEOUT_CYCLES = (CLK_FREQ_HZ / 1000) * TIMEOUT_MS;
    localparam integer CNT_W = (TIMEOUT_CYCLES <= 1) ? 1 : $clog2(TIMEOUT_CYCLES);

  
    //--------------------------- registers ----------------------------//
    remote_req_state_t        state, next_state;

    logic [127:0]  r_req,        n_req;
    logic [127:0]  r_comp,       n_comp;

    logic [2:0]    r_orig_src,   n_orig_src;
    logic [2:0]    r_orig_dst,   n_orig_dst;

    logic          r_read_req,   n_read_req;
    logic          r_config_req, n_config_req;
    logic          r_access_32,  n_access_32;
    logic          r_phy_access, n_phy_access;

    logic [4:0]    r_comp_opcode, n_comp_opcode;
    logic          r_pkt_length,  n_pkt_length;
    logic          r_comp_length, n_comp_length;

    logic               timeout_en;
    logic [CNT_W-1:0]   timeout_cnt;
    logic               r_local_timeout;

    //--------------------------- fields from current request ----------------------------//
    logic [31:0] phase0, phase1, phase2, phase3;
    logic [4:0]  opcode;
    logic [7:0]  be;
    logic [23:0] addr;
    logic [63:0] data64;
    logic [2:0]  srcid;
    logic [2:0]  dstid;

    logic        s_timeout_done;

    assign phase0 = r_req[31:0];
    assign phase1 = r_req[63:32];
    assign phase2 = r_req[95:64];
    assign phase3 = r_req[127:96];

    assign srcid  = phase0[31:29];
    assign opcode = phase0[4:0];
    assign be     = phase0[21:14];

    assign dstid  = phase1[26:24];
    assign addr   = phase1[23:0];

    assign data64 = {phase3[31:0], phase2[31:0]};

    assign s_timeout_done = timeout_en && (timeout_cnt == TIMEOUT_CYCLES - 1);

    //--------------------------- outputs to decoder ----------------------------//
    assign o_opcode  = opcode;
    assign o_address = addr;

    //--------------------------- outputs to access arbiter ----------------------------//
    assign o_remote_write_data = data64;
    assign o_remote_wr_en      = ~r_read_req;
    assign o_remote_address    = addr;
    assign o_remote_BE         = be;
    assign o_remote_config_req = r_config_req;
    assign o_remote_32_B       = r_access_32;
    assign o_remote_vld        = (state == TXRDR_WAIT_REMOTE);

    //--------------------------- outputs to RDI ----------------------------//
    assign o_pkt        = (state == TXRDR_SEND_PHY_REQ) ? r_req : r_comp;
    assign o_pkt_vld    = (state == TXRDR_SEND_PHY_REQ) || (state == TXRDR_SEND_COMP);
    assign o_pkt_length = (state == TXRDR_SEND_PHY_REQ) ? r_pkt_length : r_comp_length;
    assign o_is_comp    = (state == TXRDR_SEND_PHY_REQ) ? 1'b0 : 1'b1;

    //--------------------------- timeout output ----------------------------//
    assign o_local_timeout = r_local_timeout;

    //--------------------------- parity helpers ----------------------------//
    function automatic logic calc_dp(input logic [63:0] data_bits);
        begin
            calc_dp = ^data_bits;
        end
    endfunction

    function automatic logic calc_cp(input logic [127:0] pkt);
        begin
            calc_cp = ^{pkt[61:32], pkt[31:0]};
        end
    endfunction

    function automatic logic check_req_parity(input logic [127:0] pkt);
        logic [63:0] data_field;
        logic        exp_dp, exp_cp;
        begin
            data_field       = pkt[127:64];
            exp_dp           = ^data_field;
            exp_cp           = ^{pkt[61:32], pkt[31:0]};
            check_req_parity = (pkt[63] == exp_dp) && (pkt[62] == exp_cp);
        end
    endfunction

    function automatic logic [127:0] build_phy_req(input logic [127:0] pkt);
        logic [127:0] t;
        begin
            t         = pkt;
            t[31:29]  = SRC_ADAPTER;
            t[58:56]  = DST_LOCAL_PHY;
            t[62]     = calc_cp(t); // DP unchanged
            build_phy_req = t;
        end
    endfunction

    function automatic logic [127:0] rewrite_phy_comp(
        input logic [127:0] pkt,
        input logic [2:0]   orig_src,
        input logic [2:0]   orig_dst
    );
        logic [127:0] t;
        begin
            t         = pkt;
            t[31:29]  = orig_src;
            t[58:56]  = orig_dst;
            t[62]     = calc_cp(t); // DP unchanged
            rewrite_phy_comp = t;
        end
    endfunction

    function automatic logic [127:0] build_local_comp(
        input logic [127:0] req_pkt,
        input logic [4:0]   comp_opcode,
        input logic [2:0]   status,
        input logic         read_req,
        input logic         access_32,
        input logic [63:0]  read_data
    );
        logic [127:0] t;
        begin
            t = req_pkt;

            t[4:0]   = comp_opcode;
            t[34:32] = status;

            if (read_req) begin
                if (access_32) begin
                    t[95:64]  = read_data[31:0];
                    t[127:96] = 32'b0;
                end
                else begin
                    t[95:64]  = read_data[31:0];
                    t[127:96] = read_data[63:32];
                end
            end
            else begin
                t[127:64] = 64'b0;
            end

            t[63] = calc_dp(t[127:64]);
            t[62] = calc_cp(t);

            build_local_comp = t;
        end
    endfunction

// ======================================================================= //
//  State Register
// ======================================================================= //
    always_ff @(posedge i_clk or negedge i_rst_n) begin : State_Transition_proc
        if (!i_rst_n)
            state <= TXRDR_IDLE;
        else if (!i_init)
            state <= TXRDR_IDLE;
        else
            state <= next_state;
    end

// ======================================================================= //
//  Next-State Logic
// ======================================================================= //
    always_comb begin : Next_State_Logic_proc
        case (state)

            TXRDR_IDLE: begin
                if (i_remote_req_vld)
                    next_state = TXRDR_WAIT_DECODER;
                else
                    next_state = TXRDR_IDLE;
            end

            TXRDR_WAIT_DECODER: begin
                if (!check_req_parity(r_req))
                    next_state = TXRDR_IDLE;
                else if (i_is_phy_access)
                    next_state = TXRDR_SEND_PHY_REQ;
                else
                    next_state = TXRDR_WAIT_REMOTE;
            end

            TXRDR_SEND_PHY_REQ: begin
                if (i_req_sent)
                    next_state = TXRDR_WAIT_PHY_COMP;
                else
                    next_state = TXRDR_SEND_PHY_REQ;
            end

            TXRDR_WAIT_PHY_COMP: begin
                if (s_timeout_done)
                    next_state = TXRDR_IDLE;
                else if (i_phy_comp_vld) begin
                    if (check_req_parity(i_phy_comp))
                        next_state = TXRDR_SEND_COMP;
                    else
                        next_state = TXRDR_IDLE;
                end
                else
                    next_state = TXRDR_WAIT_PHY_COMP;
            end

            TXRDR_WAIT_REMOTE: begin
                if (i_remote_done)
                    next_state = TXRDR_BUILD_COMP;
                else
                    next_state = TXRDR_WAIT_REMOTE;
            end

            TXRDR_BUILD_COMP: begin
                next_state = TXRDR_SEND_COMP;
            end

            TXRDR_SEND_COMP: begin
                if (i_req_sent)
                    next_state = TXRDR_IDLE;
                else
                    next_state = TXRDR_SEND_COMP;
            end

            default: begin
                next_state = TXRDR_IDLE;
            end

        endcase
    end

// ======================================================================= //
//  Timeout Logic
// ======================================================================= //
    always_ff @(posedge i_clk or negedge i_rst_n) begin : Timeout_proc
        if (!i_rst_n) begin
            timeout_en      <= 1'b0;
            timeout_cnt     <= '0;
            r_local_timeout <= 1'b0;
        end
        else if (!i_init) begin
            timeout_en      <= 1'b0;
            timeout_cnt     <= '0;
            r_local_timeout <= 1'b0;
        end
        else begin
            r_local_timeout <= 1'b0;

            case (state)
                TXRDR_IDLE: begin
                    timeout_en  <= 1'b0;
                    timeout_cnt <= '0;
                end

                TXRDR_SEND_PHY_REQ: begin
                    if (i_req_sent) begin
                        timeout_en  <= 1'b1;
                        timeout_cnt <= '0;
                    end
                end

                TXRDR_WAIT_PHY_COMP: begin
                    if (i_phy_comp_vld) begin
                        timeout_en  <= 1'b0;
                        timeout_cnt <= '0;
                    end
                    else if (timeout_en) begin
                        if (timeout_cnt == TIMEOUT_CYCLES - 1) begin
                            timeout_cnt     <= '0;
                            timeout_en      <= 1'b0;
                            r_local_timeout <= 1'b1;
                        end
                        else begin
                            timeout_cnt <= timeout_cnt + 1'b1;
                        end
                    end
                end

                default: begin
                    // hold
                end
            endcase
        end
    end

// ======================================================================= //
//  Data Path Register Update
// ======================================================================= //
    always_ff @(posedge i_clk or negedge i_rst_n) begin : DataPath_Register_proc
        if (!i_rst_n) begin
            r_req         <= '0;
            r_comp        <= '0;
            r_orig_src    <= '0;
            r_orig_dst    <= '0;
            r_read_req    <= 1'b0;
            r_config_req  <= 1'b0;
            r_access_32   <= 1'b0;
            r_phy_access  <= 1'b0;
            r_comp_opcode <= '0;
            r_pkt_length  <= 1'b0;
            r_comp_length <= 1'b1;
        end
        else if (!i_init) begin
            r_req         <= '0;
            r_comp        <= '0;
            r_orig_src    <= '0;
            r_orig_dst    <= '0;
            r_read_req    <= 1'b0;
            r_config_req  <= 1'b0;
            r_access_32   <= 1'b0;
            r_phy_access  <= 1'b0;
            r_comp_opcode <= '0;
            r_pkt_length  <= 1'b0;
            r_comp_length <= 1'b1;
        end
        else begin
            case (state)
                TXRDR_IDLE: begin
                    if (i_remote_req_vld) begin
                        r_req <= i_remote_req;
                    end
                end

                TXRDR_WAIT_DECODER: begin
                    if (check_req_parity(r_req)) begin
                        r_orig_src    <= srcid;
                        r_orig_dst    <= dstid;
                        r_read_req    <= i_read_req;
                        r_config_req  <= i_config;
                        r_access_32   <= i_32_b;
                        r_phy_access  <= i_is_phy_access;
                        r_comp_opcode <= i_comp_opcode;
                        r_pkt_length  <= i_pkt_length;
                        r_comp_length <= i_comp_length;

                        if (i_is_phy_access) begin
                            r_req <= build_phy_req(r_req);
                        end
                    end
                end

                TXRDR_WAIT_PHY_COMP: begin
                    if (i_phy_comp_vld && check_req_parity(i_phy_comp)) begin
                        r_comp <= rewrite_phy_comp(i_phy_comp, r_orig_src, r_orig_dst);
                    end
                end

                TXRDR_BUILD_COMP: begin
                    r_comp        <= build_local_comp(
                                        r_req,
                                        r_comp_opcode,
                                        i_status,
                                        r_read_req,
                                        r_access_32,
                                        i_read_data
                                     );
                    r_comp_length <= 1'b1;
                end

                default: begin
                    // hold
                end
            endcase
        end
    end

endmodule