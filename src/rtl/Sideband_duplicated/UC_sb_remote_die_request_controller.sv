/*
Authour: Shahd Mohamed , Ashraf sherif 

Module_name: UC_sb_remote_die_request_controller

Description: Receives remote register access requests from the remote die
and determines whether the target is the Adapter or the PHY.

   • Adapter access  → read/write via Access Arbiter, build completion packet locally.
   • PHY access      → forward request over RDI, wait for PHY completion (with timeout).

   All outgoing packets (requests + completions) are sent to
   the RDI Controller.
*/

module UC_sb_remote_die_request_controller #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer TIMEOUT_MS  = 8
)
(
//-------------------------------inputs-----------------------------------//
input  logic                        i_clk,
input  logic                        i_rst_n,
input  logic                        i_init_n,             // software reset : active low

// From : Access Arbiter
input  logic                        i_remote_done,      // done from access arbiter
output logic                        o_remote_arbiter_valid, // valid to access arbiter

// From : Rx
input  logic [127:0]                i_remote_req,       // request packet from remote die
input  logic                        i_remote_req_vld,   // valid remote request

// From : Rx (PHY completion)
input  logic [127:0]                i_phy_comp,         // completion packet from PHY
input  logic                        i_phy_comp_vld,     // valid PHY completion
input  logic                        i_comp_length,      // completion packet size: 1=128b, 0=64b

// From : Decoder
input  logic                        i_is_phy_access,    // 1=PHY access, 0=Adapter access
input  logic [4:0]                  i_comp_opcode,      // completion opcode from decoder
input  logic                        i_read_req,         // 1=read, 0=write
input  logic                        i_config,           // 1=config, 0=memory
input  logic                        i_pkt_length,       // request packet length 1=128b, 0=64b
input  logic                        i_32_b,             // 1=32-bit operation, 0=64-bit
// From : Register File
input  logic [63:0]                 i_read_data,        // read data from register file
input  logic [2:0]                  i_status,           // completion status from register file

// From : RDI
input  logic                        i_req_sent,         // packet accepted by RDI

//-----------------------------------outputs--------------------------------//
// To : Decoder
output logic [4:0]                  o_opcode,           // request opcode to decoder
output logic [23:0]                 o_address,          // request address to decoder

// To : Register File (Access Arbiter)
output logic [63:0]                 o_remote_write_data,  // write data to register file
output logic                        o_remote_wr_en,       // write enable
output logic [23:0]                 o_remote_address,     // address
output logic [7:0]                  o_remote_BE,          // byte enable
output logic                        o_remote_config_req,  // config or memory request
output logic                        o_remote_32_B,        // 32 or 64-bit operation
output logic                        o_remote_vld,         // valid to access arbiter

// To : RDI Controller
output logic [127:0]                o_pkt,              // packet to RDI
output logic                        o_pkt_vld,          // packet valid
output logic                        o_pkt_length,       // packet size
output logic                        o_is_comp,          // 1=completion, 0=request

// To : LSM / Error Handler
output logic                        o_local_timeout     // local timeout flag
);

// ===========================================================================
//                          Constants
// ===========================================================================

localparam logic [2:0] SRC_ADAPTER   = 3'b001; // adapter srcid on RDI
localparam logic [2:0] DST_LOCAL_PHY = 3'b010; // PHY dstid on RDI

localparam integer TIMEOUT_CYCLES = (CLK_FREQ_HZ / 1000) * TIMEOUT_MS;
localparam integer CNT_W = (TIMEOUT_CYCLES <= 1) ? 1 : $clog2(TIMEOUT_CYCLES + 1);

// ===========================================================================
//                          FSM States  
// ===========================================================================

typedef enum logic [2:0] {
    REMOTE_EP_READY,
    REMOTE_EP_CHECK_ADDR,       // parity check + latch decoder signals
    REMOTE_EP_REG_OPERATION,    // wait access arbiter
    REMOTE_EP_ADAPTER_SEND_COMP,// send adapter-built completion to RDI
    REMOTE_EP_REQ_TO_PHY,       // forward request to PHY via RDI
    REMOTE_EP_WAIT_FOR_COMP,    // wait PHY completion (with timeout)
    REMOTE_EP_PHY_SEND_COMP     // forward PHY completion to RDI
} state_t;

state_t r_cr_state, r_next_state;

// ===========================================================================
//                          Registers
// ===========================================================================

logic [127:0]    r_rx_req;      // latched incoming request
logic            r_read_req;
logic            r_config_req;
logic            r_access_32;
logic            r_phy_access;
logic [4:0]      r_comp_opcode;
logic            r_pkt_length;
logic            r_comp_length;
logic [2:0]      r_orig_src;
logic [2:0]      r_orig_dst;

// ===========================================================================
//                          Packet Field Extraction
// ===========================================================================
// [4:0]    opcode
// [21:14]  BE
// [31:29]  srcid
// [55:32]  address
// [58:56]  dstid
// [61]     CR bit
// [62]     CP (control parity)
// [63]     DP (data parity)
// [127:64] data

logic [4:0]  opcode;
logic [7:0]  be;
logic [2:0]  srcid, dstid;
logic [23:0] addr;
logic [63:0] data64;
logic        cp, dp;

assign opcode = r_rx_req[4:0];
assign be     = r_rx_req[21:14];
assign srcid  = r_rx_req[31:29];
assign dstid  = r_rx_req[58:56];
assign cp     = r_rx_req[62];
assign dp     = r_rx_req[63];
assign addr   = r_rx_req[55:32];
assign data64 = r_rx_req[127:64];

// Outputs to decoder 
assign o_opcode  = opcode;
assign o_address = addr;

// ===========================================================================
//                          Parity Check
// ===========================================================================

logic exp_cp, exp_dp;
logic cp_ok,  dp_ok;

assign exp_cp = ^{r_rx_req[61:0]};
assign exp_dp = ^r_rx_req[127:64];

assign cp_ok  = (cp == exp_cp);
assign dp_ok  = (dp == exp_dp);

// ===========================================================================
//                          Completion Building (Adapter)
// ===========================================================================
logic                s_reg_ur_ca;
logic [4:0]          s_comp_opcode;
logic                s_comp_type;
logic [61:0]         s_adapter_comp_header;
logic                s_dp;
logic                s_cp;

assign s_reg_ur_ca           = (i_status != 3'b0);
assign s_comp_opcode         = s_reg_ur_ca ? 5'b11001 : i_comp_opcode;
assign s_comp_type           = s_reg_ur_ca ? 1'b1     : i_comp_length;

assign s_adapter_comp_header = {
    3'b100,               // srcid = adapter (bits 61:59)
    3'b101,               // dstid = remote  (bits 58:56)
    r_rx_req[55:35],      // address upper   (bits 55:35)
    i_status,             // completion status (bits 34:32)
    3'b001,               // reserved / tag  (bits 31:29)
    r_rx_req[28:14],      // lower addr / BE (bits 28:14)
    9'b0,                 // reserved        (bits 13:5)
    s_comp_opcode         // opcode          (bits 4:0)
};

assign s_dp = ^i_read_data;         // data parity
assign s_cp = ^s_adapter_comp_header; // control parity

// ===========================================================================
//                          PHY Packet Parity Recalculation
// ===========================================================================

logic s_old_parity, s_new_parity;


logic s_rdi_out_comp;
logic s_rdi_out_req;
logic s_rdi_out_phy_comp;

assign s_rdi_out_comp     = (r_cr_state == REMOTE_EP_ADAPTER_SEND_COMP);
assign s_rdi_out_req      = (r_cr_state == REMOTE_EP_REQ_TO_PHY);
assign s_rdi_out_phy_comp = (r_cr_state == REMOTE_EP_PHY_SEND_COMP);

assign s_old_parity = s_rdi_out_req
    ? (^ r_rx_req[58:56])
    : (^ {r_rx_req[58:56], r_rx_req[31:29], r_rx_req[61]});

assign s_new_parity = s_rdi_out_req
    ? (1'b1 ^ s_old_parity)  
    : (1'b0 ^ s_old_parity);  

// ===========================================================================
//                          RDI Output Packet MUX
// ===========================================================================

always_comb begin : construct_rdi_pkt_proc
    o_pkt        = '0;
    o_pkt_length = 1'b0;
    o_is_comp    = 1'b0;

    if (s_rdi_out_comp) begin
        // Adapter-built completion
        o_pkt        = {i_read_data, s_dp, s_cp, s_adapter_comp_header};
        o_pkt_length = s_comp_type;
        o_is_comp    = 1'b1;

    end else if (s_rdi_out_req) begin
        // PHY-bound request: substitute dstid=010 and fix CP
        o_pkt        = {r_rx_req[127:63], s_new_parity,
                        r_rx_req[61:59], DST_LOCAL_PHY, r_rx_req[55:0]};
        o_pkt_length = r_pkt_length;
        o_is_comp    = 1'b0;

    end else if (s_rdi_out_phy_comp) begin
        // PHY completion forwarded to remote: restore orig srcid/dstid, clear CR
        o_pkt        = {i_phy_comp[127:63], s_new_parity,
                        1'b1,               // CP recalculated position
                        i_phy_comp[60:59],
                        3'b101,             // dstid = remote die
                        i_phy_comp[55:32],
                        3'b001,             // srcid = adapter
                        i_phy_comp[28:0]};
        o_pkt_length = i_comp_length;
        o_is_comp    = 1'b1;
    end
end

assign o_pkt_vld = s_rdi_out_comp || s_rdi_out_req || s_rdi_out_phy_comp;

// ===========================================================================
//                          Register File / Arbiter Outputs
// ===========================================================================

assign o_remote_write_data = r_rx_req[127:64];
assign o_remote_address    = r_rx_req[55:32];
assign o_remote_BE         = r_access_32 ? {4'b0000, r_rx_req[17:14]} : r_rx_req[21:14];
assign o_remote_wr_en      = ~r_read_req;
assign o_remote_config_req = r_config_req;
assign o_remote_32_B       = r_access_32;
assign o_remote_vld        = (r_cr_state == REMOTE_EP_REG_OPERATION);
assign o_remote_arbiter_valid = (r_cr_state == REMOTE_EP_REG_OPERATION);

// ===========================================================================
//                          Timeout Counter
// ===========================================================================

logic [CNT_W-1:0] r_remote_cycles_counter;
logic             s_cycles_counter_en;

always_ff @(posedge i_clk or negedge i_rst_n) begin : counter_proc
    if (!i_rst_n)
        r_remote_cycles_counter <= '0;
    else if (!i_init_n)
        r_remote_cycles_counter <= '0;
    else if (s_cycles_counter_en)
        r_remote_cycles_counter <= r_remote_cycles_counter + 1'b1;
    else
        r_remote_cycles_counter <= '0;
end

assign s_cycles_counter_en = (r_cr_state == REMOTE_EP_WAIT_FOR_COMP);
assign o_local_timeout     = (r_remote_cycles_counter == TIMEOUT_CYCLES - 1);

// ===========================================================================
//                          State Register
// ===========================================================================

always_ff @(posedge i_clk or negedge i_rst_n) begin : state_reg_proc
    if (!i_rst_n)
        r_cr_state <= REMOTE_EP_READY;
    else if (!i_init_n)
        r_cr_state <= REMOTE_EP_READY;
    else
        r_cr_state <= r_next_state;
end

// ===========================================================================
//                          Next-State Logic
// ===========================================================================

always_comb begin : next_state_proc
    r_next_state = r_cr_state;

    case (r_cr_state)

        REMOTE_EP_READY: begin
            if (i_remote_req_vld)
                r_next_state = REMOTE_EP_CHECK_ADDR;
        end

        REMOTE_EP_CHECK_ADDR: begin
            if (!cp_ok || !dp_ok)
                r_next_state = REMOTE_EP_READY;
            else if (i_is_phy_access)
                r_next_state = REMOTE_EP_REQ_TO_PHY;
            else
                r_next_state = REMOTE_EP_REG_OPERATION;
        end

        REMOTE_EP_REG_OPERATION: begin
            if (i_remote_done)
                r_next_state = REMOTE_EP_ADAPTER_SEND_COMP;
        end

        REMOTE_EP_ADAPTER_SEND_COMP: begin
            if (i_req_sent)
                r_next_state = REMOTE_EP_READY;
        end

        REMOTE_EP_REQ_TO_PHY: begin
            if (i_req_sent)
                r_next_state = REMOTE_EP_WAIT_FOR_COMP;
        end

        REMOTE_EP_WAIT_FOR_COMP: begin
            if (i_phy_comp_vld)
                r_next_state = REMOTE_EP_PHY_SEND_COMP;
            else if (o_local_timeout)
                r_next_state = REMOTE_EP_READY;
        end

        REMOTE_EP_PHY_SEND_COMP: begin
            if (i_req_sent)
                r_next_state = REMOTE_EP_READY;
        end

        default: r_next_state = REMOTE_EP_READY;
    endcase
end

// ===========================================================================
//                          Request Latch
// ===========================================================================

logic s_reg_rx_req;
assign s_reg_rx_req = (r_cr_state == REMOTE_EP_READY) && i_remote_req_vld;

always_ff @(posedge i_clk or negedge i_rst_n) begin : reg_rx_req_proc
    if (!i_rst_n) begin
        r_rx_req      <= '0;
        r_read_req    <= 1'b0;
        r_config_req  <= 1'b0;
        r_access_32   <= 1'b0;
        r_phy_access  <= 1'b0;
        r_comp_opcode <= '0;
        r_pkt_length  <= 1'b0;
        r_comp_length <= 1'b1;
        r_orig_src    <= '0;
        r_orig_dst    <= '0;
    end
    else if (!i_init_n) begin
        r_rx_req      <= '0;
        r_read_req    <= 1'b0;
        r_config_req  <= 1'b0;
        r_access_32   <= 1'b0;
        r_phy_access  <= 1'b0;
        r_comp_opcode <= '0;
        r_pkt_length  <= 1'b0;
        r_comp_length <= 1'b1;
        r_orig_src    <= '0;
        r_orig_dst    <= '0;
    end
    else begin
        
        if (s_reg_rx_req) begin
            r_rx_req <= i_remote_req;
        end
        
        if (r_cr_state == REMOTE_EP_CHECK_ADDR && (cp_ok && dp_ok)) begin
            r_read_req    <= i_read_req;
            r_config_req  <= i_config;
            r_access_32   <= i_32_b;
            r_phy_access  <= i_is_phy_access;
            r_comp_opcode <= i_comp_opcode;
            r_pkt_length  <= i_pkt_length;
            r_comp_length <= i_comp_length;
            r_orig_src    <= r_rx_req[31:29];
            r_orig_dst    <= r_rx_req[58:56];
        end
    end
end

endmodule