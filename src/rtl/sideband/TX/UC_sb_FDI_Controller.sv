/*
Authour: Shahd Mohamed, Ashraf sherif

Module_name: UC_sb_FDI_Controller

Description: The FDI Controller Block is responsible for managing the routing and
execution of local register access requests, determining whether each
request targets the PHY or the Adapter and if the request targets the Adapter layer then the
FDI Controller responsible to make it's complition
*/
import UC_sb_pkg::*;
module UC_sb_FDI_Controller #(
 parameter int P_DATA_W = 64 // 32 or 64
)
(
 //--------------------------- inputs ----------------------------//
 input logic                i_clk,          //clock
 input logic                i_rst_n,        //reset
 input logic [127:0]        i_Data_out,     // SB local request packet
 input logic                i_empty,        // empty flag from FDI FIFO
 input logic                i_Full,         // full flag from RDI FIFO
 input logic [4:0]          i_comp_opcode,  // completion opcode
 input logic                i_read_req,     // 1 mean the request is read request , 0 mean it's a write request
 input logic                i_config,       // 1 mean the request is configuration request , 0 mean it's a memory request
 input logic [2:0]          i_Local_status, // 000b Successful Completion, 001b Unsupported Request, 100b Completer Abort, 111b Stall
 input logic [P_DATA_W-1:0] i_Local_R_data, // data for the read request
 input logic                i_Local_done,   // from access Arbiter
 input logic                i_is_32b,       // indicate if data=32b or 64b
 input logic                i_init,

 //--------------------------outputs--------------------------//
 output logic [127:0]        o_Data_in,            // SB local request packet that it's dst is the physical layer
 output logic                o_Wr_en,              // write enable for RDI FIFO
 output logic                o_Rd_en,              // read enable for FDI FIFO
 output logic [P_DATA_W-1:0] o_Local_wr_data,      // data of the write request for the access arbiter
 output logic                o_Local_wr_en,        // write or read request send to access arbiter
 output logic                o_Local_config_req,   // configuration or memory request
 output logic                o_Local_32_B,         // 32 or 64 data request
 output logic [7:0]          o_Local_BE,           // Byte enable of the local request
 output logic [23:0]         o_Local_address,      // address of the local request
 output logic                o_Local_valid,        // 1 mean there is local request want to access a register , 0 if not
 output logic                o_Fdi_credit_release, // Enables Protocol to send a new local request
 output logic [127:0]        o_Comp_packet,        // response to local Protocol request (where dst of request is adapter)
 output logic                o_Valid,              // the valid signal for comp_packet
 output logic [4:0]          o_req_opcode          // opcode of the local request
);
//---------------------------------------------IOS finish------------------------------------//

// FSM state encoding
state_t r_state;

// ============================================================================
// Captured request packet + derived fields
// ============================================================================
logic [127:0] r_req;   // latched request packet

// Split into 32-bit phases
logic [31:0] p0, p1, p2, p3;
assign p0 = r_req[31:0];
assign p1 = r_req[63:32];
assign p2 = r_req[95:64];
assign p3 = r_req[127:96];

// Field extraction
logic [4:0]  opcode;
logic [7:0]  be;
logic        dp, cp;
logic [2:0]  dstid;
logic [23:0] addr;
logic [63:0] data64;

assign opcode  = p0[4:0];
assign be      = p0[21:14];

assign addr    = p1[23:0];
assign dstid   = p1[26:24];
assign cp      = p1[30];     // r_req[62]
assign dp      = p1[31];     // r_req[63]

assign data64  = {p3, p2};   // r_req[127:64]

// Opcode forwarded to FDI Packer (continuous)
assign o_req_opcode = opcode;

// ============================================================================
// Parity verification
// ============================================================================
// DP = XOR over data word (p2 ++ p3)
// CP = XOR over all header bits except the cp bit itself
//      header bits: p1[29:0] ++ p0[31:0]   (exclude p1[31]=dp, p1[30]=cp)
logic exp_dp, exp_cp;
logic cp_ok, dp_ok;

assign exp_dp = ^data64;
assign exp_cp = ^{p1[29:0], p0};   // exclude dp[31] and cp[30] from p1

assign dp_ok  = (dp == exp_dp);
assign cp_ok  = (cp == exp_cp);

// ============================================================================
// Completion packet register
// ============================================================================
logic [127:0] r_comp;

// ============================================================================
// Latch: captured packer-side signals when we pop the packet.
// These must be stable for the full Adapter access sequence.
// ============================================================================
logic       r_read_req;
logic       r_config;
logic       r_is_32b;
logic [4:0] r_comp_opcode;

// ============================================================================
// Helper function: build completion packet
// ============================================================================
function automatic logic [127:0] build_completion_pkt(
    input logic [127:0]        req_pkt,
    input logic [4:0]          comp_opcode,
    input logic [2:0]          local_status,
    input logic                read_req,
    input logic                is_32b,
    input logic [P_DATA_W-1:0] local_r_data
);
    logic [127:0] pkt;
    begin
        pkt = req_pkt;

        // Replace opcode with completion opcode
        pkt[4:0] = comp_opcode;

        // Completion status goes into bits [34:32]
        pkt[34:32] = local_status;

        // Payload
        if (read_req) begin
            if (is_32b) begin
                pkt[95:64]  = local_r_data[31:0];
                pkt[127:96] = 32'h0;
            end
            else begin
                pkt[95:64]  = local_r_data[31:0];
                pkt[127:96] = local_r_data[63:32];
            end
        end
        else begin
            pkt[127:64] = 64'h0;
        end

        // Recompute parity
        pkt[63] = ^pkt[127:64];
        pkt[62] = ^{pkt[61:32], pkt[31:0]};

        build_completion_pkt = pkt;
    end
endfunction

// ============================================================================
// Output logic (combinational)
// ============================================================================
always_comb begin
    // Safe defaults
    o_Data_in            = r_req;
    o_Wr_en              = 1'b0;
    o_Rd_en              = 1'b0;
    o_Local_wr_data      = '0;
    o_Local_wr_en        = 1'b0;
    o_Local_config_req   = 1'b0;
    o_Local_32_B         = 1'b0;
    o_Local_BE           = '0;
    o_Local_address      = '0;
    o_Local_valid        = 1'b0;
    o_Fdi_credit_release = i_empty;   // credit released whenever FDI FIFO is empty
    o_Comp_packet        = r_comp;
    o_Valid              = 1'b0;

    case (r_state)
        // ── Pop: assert read-enable if FIFO has data
        TXCTRL_POP: begin
            if (!i_empty)
                o_Rd_en = 1'b1;
        end

        // ── PHY forward: write to RDI FIFO; stall if full
        TXCTRL_SEND_PHY: begin
            if (!i_Full) begin
                o_Data_in = r_req;
                o_Wr_en   = 1'b1;
            end
        end

        // ── Adapter request: hold signals stable across both issue states
        TXCTRL_ISSUE_LOCAL,
        TXCTRL_WAIT_LOCAL: begin
            o_Local_address    = addr;
            o_Local_BE         = be;
            o_Local_config_req = r_config;
            o_Local_wr_en      = ~r_read_req;   // 1 = write, 0 = read
            o_Local_32_B       = r_is_32b;

            // Write data: zero-extend to P_DATA_W; use lower 32 bits for 32-bit ops
            if (r_is_32b)
                o_Local_wr_data = {{(P_DATA_W-32){1'b0}}, data64[31:0]};
            else
                o_Local_wr_data = data64[P_DATA_W-1:0];

            o_Local_valid = 1'b1;
        end

        // ── Push completion: one-cycle valid pulse
          TXCTRL_PUSH_COMP   : begin
            o_Comp_packet = r_comp;
            o_Valid       = 1'b1;
        end

        default: ;
    endcase
end

// ============================================================================
// FSM + data-path sequential logic
// ============================================================================
always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        r_state       <= TXCTRL_IDLE;
        r_req         <= '0;
        r_comp        <= '0;
        r_read_req    <= 1'b0;
        r_config      <= 1'b0;
        r_is_32b      <= 1'b0;
        r_comp_opcode <= '0;
    end
    else if (!i_init) begin
        // Sideband not yet initialised: hold idle, clear state
        r_state       <= TXCTRL_IDLE;
        r_req         <= '0;
        r_comp        <= '0;
        r_read_req    <= 1'b0;
        r_config      <= 1'b0;
        r_is_32b      <= 1'b0;
        r_comp_opcode <= '0;
    end
    else begin
        case (r_state)

            // Wait for a packet to appear in FDI FIFO
            TXCTRL_IDLE: begin
                if (!i_empty)
                    r_state <= TXCTRL_POP;
            end

            // Assert Rd_en; if FIFO still has data advance, else retry
            TXCTRL_POP: begin
                if (!i_empty)
                    r_state <= TXCTRL_POP_WAIT;
                else
                    r_state <= TXCTRL_IDLE;
            end

            // Capture packet + sidecar signals on next clock edge
            TXCTRL_POP_WAIT: begin
                r_req         <= i_Data_out;
                r_read_req    <= i_read_req;
                r_config      <= i_config;
                r_is_32b      <= i_is_32b;
                r_comp_opcode <= i_comp_opcode;
                r_state       <= TXCTRL_PARSE;
            end

            // Check parity; route
            TXCTRL_PARSE: begin
                if (!cp_ok || !dp_ok) begin
                    // Drop silently – parity error
                    r_state <= TXCTRL_IDLE;
                end
                else if (dstid == 3'b010) begin
                    // PHY (RDI) path
                    r_state <= TXCTRL_SEND_PHY;
                end
                else if (dstid == 3'b001) begin
                    // Adapter (local register) path
                    r_state <= TXCTRL_ISSUE_LOCAL;
                end
                else begin
                    // Unknown destination – drop
                    r_state <= TXCTRL_IDLE;
                end
            end

            // Forward to RDI FIFO; stay here while full
            TXCTRL_SEND_PHY: begin
                if (!i_Full)
                    r_state <= TXCTRL_IDLE;
            end

            // First cycle of Adapter request; advance immediately
            TXCTRL_ISSUE_LOCAL: begin
                r_state <= TXCTRL_WAIT_LOCAL;
            end

            // Hold request; wait for Arbiter done
            TXCTRL_WAIT_LOCAL: begin
                if (i_Local_done)
                    r_state <= TXCTRL_BUILD_COMP   ;
            end

            // Build completion packet (registered stage)
            TXCTRL_BUILD_COMP   : begin
                r_comp  <= build_completion_pkt(
                              r_req,
                              r_comp_opcode,
                              i_Local_status,
                              r_read_req,
                              r_is_32b,
                              i_Local_R_data
                           );
                r_state <=   TXCTRL_PUSH_COMP   ;
            end

            // Output completion for one cycle
              TXCTRL_PUSH_COMP   : begin
                r_state <= TXCTRL_IDLE;
            end

            default: r_state <= TXCTRL_IDLE;

        endcase
    end
end

endmodule