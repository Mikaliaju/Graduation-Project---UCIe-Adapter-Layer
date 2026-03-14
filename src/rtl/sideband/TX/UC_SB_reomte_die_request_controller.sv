/*
Authour: Shahd Mohamed , Ashraf sherif 

Module_name: UC_SB_remote_die_request_controller

Description: Receives remote register access requests from the remote die
and determines whether the target is the Adapter or the PHY.

   • Adapter access  → read/write via Access Arbiter, build completion packet locally.
   • PHY access      → forward request over RDI, wait for PHY completion (with timeout).

   All outgoing packets (requests + completions) are sent to
   the RDI Controller.
*/
module UC_SB_remote_die_request_controller #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer TIMEOUT_MS  = 8
)
(
//-------------------------------inputs-----------------------------------//
input logic                        i_clk,
input logic                        i_rst_n,
input logic                        i_init_n,
input logic [127:0]                i_remote_req,         // request packet from remote die
input logic                        i_remote_req_vld,     //Indicates valid remote request.
input logic                        i_read_req,           // 1 mean read request , 0 mean write request 
input logic [4:0]                  i_comp_opcode,        // opcode of completion
input logic                        i_is_phy_access,      // 1 mean request to access phy register , 0 mean request to access adapter register
input logic                        i_pkt_length,         // Packet length indicator (64-bit / 128-bit)
input logic [127:0]                i_phy_comp,           // completion packet receive from phy
input logic                        i_phy_comp_vld,       // indicates valid completion
input logic                        i_comp_length,        // Completion packet size
input logic [2:0]                  i_status,             // status of completion from register file (to make a completion for adapter access request)
input logic [63:0]                 i_read_data,         // Read data from register file.
input logic                        i_req_sent,           //Indicates packet accepted by RDI
input logic                        i_remote_done,        // from access Arbiter 
input logic                        i_32_b,               // indicate if data 32 or 64 bit
input logic                        i_config,             // indicate if request configuration or memory request

//-----------------------------------outputs--------------------------------//
output logic [4:0]                 o_opcode,             // request opcode to the decoder
output logic [23:0]                o_address,            // request address
output logic [63:0]                o_remote_write_data,  //Write data sent to register file
output logic                       o_remote_wr_en,       //Register file write enable
output logic [23:0]                o_remote_address,     // Register file address
output logic [7:0]                 o_remote_BE,          // Byte enable for register access     
output logic                       o_remote_config_req,  // configuration or memory request to register file
output logic                       o_remote_vld,         // Valid request to access arbiter
output logic [127:0]               o_pkt,                //Packet sent to RDI 
output logic                       o_pkt_vld,            // Packet valid signal
output logic                       o_pkt_length,         //Packet size indicator (128-bit / 64-bit)
output logic                       o_is_comp,            //Indicates completion packet
output logic                       o_local_timeout      //Local timeout indication to  Error_handler
);
//---------------------------------------------IOS finish------------------------------------//

//--------------------------- constants ----------------------------//
localparam logic [2:0] SRC_ADAPTER   = 3'b001; // srcid encoding on RDI for adapter layer
localparam logic [2:0] DST_LOCAL_PHY = 3'b010; // dst encoding on RDI for physical layer (local request)

localparam integer TIMEOUT_CYCLES = (CLK_FREQ_HZ / 1000) * TIMEOUT_MS;
localparam integer CNT_W = (TIMEOUT_CYCLES <= 1) ? 1 : $clog2(TIMEOUT_CYCLES);

//--------------------------- state ----------------------------//
    typedef enum logic [2:0] {
        S_IDLE,
        S_WAIT_DECODER,
        S_SEND_PHY_REQ,
        S_WAIT_PHY_COMP,
        S_WAIT_REMOTE,
        S_BUILD_COMP,
        S_SEND_COMP
    } state_t;

    state_t state;

//--------------------------- registers ----------------------------//
    logic [127:0] r_req;
    logic [127:0] r_comp;

    logic [2:0]   r_orig_src;
    logic [2:0]   r_orig_dst;

    logic         r_read_req;
    logic         r_config_req;
    logic         r_access_32;
    logic         r_phy_access;

    logic [4:0]   r_comp_opcode;
    logic         r_pkt_length;
    logic         r_comp_length;

    logic             timeout_en;
    logic [CNT_W-1:0] timeout_cnt;
//--------------------------- fields from current request ----------------------------//
    logic [31:0] p0, p1, p2, p3;
    logic [4:0]  opcode;
    logic [7:0]  be;
    logic [23:0] addr;
    logic [63:0] data64;
    logic [2:0]  srcid;
    logic [2:0]  dstid;
    logic        cp, dp;

    assign p0 = r_req[31:0];
    assign p1 = r_req[63:32];
    assign p2 = r_req[95:64];
    assign p3 = r_req[127:96];

    assign srcid  = p0[31:29];
    assign opcode = p0[4:0];
    assign be     = p0[21:14];

    assign dp     = p1[31];
    assign cp     = p1[30];
    assign dstid  = p1[26:24];
    assign addr   = p1[23:0];

    assign data64 = {p3[31:0], p2[31:0]};

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
    assign o_remote_vld        = (state == S_WAIT_REMOTE);

    //--------------------------- outputs to RDI ----------------------------//
    assign o_pkt        = (state == S_SEND_PHY_REQ) ? r_req : r_comp;
    assign o_pkt_vld    = (state == S_SEND_PHY_REQ) || (state == S_SEND_COMP);
    assign o_pkt_length = (state == S_SEND_PHY_REQ) ? r_pkt_length : r_comp_length;
    assign o_is_comp    = (state == S_SEND_PHY_REQ) ? 1'b0 : 1'b1;

    //--------------------------- parity calculation ----------------------------//
    function automatic logic calc_dp(input logic [63:0] data_bits);
        begin
            calc_dp = ^data_bits;
        end
    endfunction

    function automatic logic calc_cp(input logic [127:0] pkt);
        begin
            // parity calculation for header excluding DP bit
            calc_cp = ^{pkt[61:32], pkt[31:0]};
        end
    endfunction

    function automatic logic check_req_parity(input logic [127:0] pkt);
        logic [63:0] data_field;
        logic exp_dp, exp_cp;
        begin
            data_field = {pkt[127:96], pkt[95:64]};
            exp_dp = ^data_field;
            exp_cp = ^{pkt[61:32], pkt[31:0]};
            check_req_parity = (pkt[63] == exp_dp) && (pkt[62] == exp_cp);
        end
    endfunction

    //--------------------------- main logic ----------------------------//
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        logic [127:0] temp_pkt;

        if (!i_rst_n) begin
            state           <= S_IDLE;
            r_req           <= '0;
            r_comp          <= '0;
            r_orig_src      <= '0;
            r_orig_dst      <= '0;
            r_read_req      <= 1'b0;
            r_config_req    <= 1'b0;
            r_access_32     <= 1'b0;
            r_phy_access    <= 1'b0;
            r_comp_opcode   <= '0;
            r_pkt_length    <= 1'b0;
            r_comp_length   <= 1'b1;
            timeout_en      <= 1'b0;
            timeout_cnt     <= '0;
            o_local_timeout <= 1'b0;
        end
        else begin
            o_local_timeout <= 1'b0;

                // timeout runs only while waiting PHY completion
                if (timeout_en) begin
                    if (timeout_cnt == TIMEOUT_CYCLES - 1) begin
                        timeout_cnt     <= '0;
                        timeout_en      <= 1'b0;
                        o_local_timeout <= 1'b1;
                        state           <= S_IDLE;
                    end
                    else begin
                        timeout_cnt <= timeout_cnt + 1'b1;
                    end
                end
                else begin
                    timeout_cnt <= '0;
                end

                case (state)

                    //------------------------ wait request---------------------------//
                    S_IDLE: begin
                        timeout_en <= 1'b0;

                        if (i_remote_req_vld) begin
                            r_req  <= i_remote_req;
                            state  <= S_WAIT_DECODER;
                        end
                    end

                    //-------------------- check parity + take decoder decision ---------------------//
                    S_WAIT_DECODER: begin
                        if (!check_req_parity(r_req)) begin
                            state <= S_IDLE; // drop bad request
                        end
                        else begin
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
                                temp_pkt = r_req;
                                temp_pkt[31:29] = SRC_ADAPTER;
                                temp_pkt[58:56] = DST_LOCAL_PHY;
                                temp_pkt[62]    = calc_cp(temp_pkt); // DP unchanged
                                r_req           <= temp_pkt;
                                state           <= S_SEND_PHY_REQ;
                            end
                            else begin
                                state <= S_WAIT_REMOTE;
                            end
                        end
                    end

                    //--------------------------------------------------
                    // send local PHY request to RDI
                    //--------------------------------------------------
                    S_SEND_PHY_REQ: begin
                        if (i_req_sent) begin
                            timeout_en <= 1'b1;
                            state      <= S_WAIT_PHY_COMP;
                        end
                    end

                    //--------------------------------------------------
                    // wait PHY completion
                    //--------------------------------------------------
                    S_WAIT_PHY_COMP: begin
                        if (i_phy_comp_vld) begin
                            timeout_en <= 1'b0;

                            if (check_req_parity(i_phy_comp)) begin
                                temp_pkt = i_phy_comp;
                                temp_pkt[31:29] = r_orig_src;
                                temp_pkt[58:56] = r_orig_dst;
                                temp_pkt[62]    = calc_cp(temp_pkt); // DP unchanged
                                r_comp          <= temp_pkt;
                                state           <= S_SEND_COMP;
                            end
                            else begin
                                state <= S_IDLE; // drop bad PHY completion
                            end
                        end
                    end

                    //--------------------------------------------------
                    // wait access arbiter
                    //--------------------------------------------------
                    S_WAIT_REMOTE: begin
                        if (i_remote_done) begin
                            state <= S_BUILD_COMP;
                        end
                    end

                    //--------------------------------------------------
                    // build adapter completion locally
                    //--------------------------------------------------
                    S_BUILD_COMP: begin
                        temp_pkt = r_req;

                        // completion opcode
                        temp_pkt[4:0] = r_comp_opcode;

                        // completion status
                        temp_pkt[34:32] = i_status;

                        // data
                        if (r_read_req) begin
                            if (r_access_32) begin
                                temp_pkt[95:64]   = i_read_data[31:0];
                                temp_pkt[127:96]  = 32'b0;
                            end
                            else begin
                                temp_pkt[95:64]   = i_read_data[31:0];
                                temp_pkt[127:96]  = i_read_data[63:32];
                            end
                        end
                        else begin
                            temp_pkt[127:64] = 64'b0;
                        end

                        // final completion packet always 128-bit
                        r_comp_length <= 1'b1;

                        // recompute parity
                        temp_pkt[63] = calc_dp(temp_pkt[127:64]);
                        temp_pkt[62] = calc_cp(temp_pkt);

                        r_comp <= temp_pkt;
                        state  <= S_SEND_COMP;
                    end

                    //--------------------------------------------------
                    // send completion to RDI
                    //--------------------------------------------------
                    S_SEND_COMP: begin
                        if (i_req_sent) begin
                            state <= S_IDLE;
                        end
                    end

                    default: begin
                        state <= S_IDLE;
                    end
                endcase
            end
        end
endmodule