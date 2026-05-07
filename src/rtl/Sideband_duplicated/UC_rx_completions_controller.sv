// ================================================================================================================================
//  FILENAME    : UC_rx_completions_controller.sv 
//  MODULE      : UC_rx_completions_controller
//  PROJECT     : UCIe 3.0 Adapter Layer
//  AUTHOR      : Ashraf Sherif, Shahd Mohamed
// ================================================================================================================================
// Description : It handles the two types of completions (with and without data)
//               and determine based on the tag field whether it was for a local 
//               or remote request.
// ================================================================================================================================
import UC_sb_rx_pkg_RP::*;
module UC_rx_completions_controller #(parameter NC = 32) (
    // ------------------------------------------------------------------ //
    //  Global Signals
    // ------------------------------------------------------------------ //
    input  logic              i_clk,
    input  logic              i_rst_n,
    input  logic              i_init_n,

    // ------------------------------------------------------------------ //
    //  Completions FIFO Interface
    // ------------------------------------------------------------------ //
    input  logic              i_comp_fifo_empty,
    input  logic [NC-1:0]     i_comp_phase,
    output logic              o_read_comp_fifo,

    // ------------------------------------------------------------------ //
    // Interface with tx
    // ------------------------------------------------------------------ //
    input  logic [127:0]      i_tx_Comp_pkt,
    input  logic              i_tx_Comp_pkt_vld,
    output logic              o_tx_Comp_pkt_done,

    // ------------------------------------------------------------------ //
    //  Mailbox Controller Interface
    // ------------------------------------------------------------------ //
    output logic [127:0]      o_rx_remote_comp_pkt,
    output logic              o_rx_remote_comp_vld,
    output logic              o_rx_remote_comp_length,

    // ------------------------------------------------------------------ //
    //  Tag manager Interface
    // ------------------------------------------------------------------ //
    output logic              o_rx_chk_tag,
    output logic  [4:0]       o_rx_current_tag,
    input  logic  [4:0]       i_rx_orig_tag,
    input  logic              i_rx_tag_notfound,

    // ------------------------------------------------------------------ //
    //   Error handler Interface
    // ------------------------------------------------------------------ //
    output logic              o_comp_parity_err,

    // ------------------------------------------------------------------ //
    //  FDI Interface
    // ------------------------------------------------------------------ //
    output logic [NC-1:0]     o_pl_cfg,
    output logic              o_pl_cfg_vld

);
// ======================================================================= //
//  Internal Signals
// ======================================================================= //

    completions_ctrl_sts  completions_ctrl_state, completions_ctrl_nextstate;

    logic [CHUNK_COUNTER_WIDTH-1:0]  r_rx_chunk_idx;    //    — index of chunk being received from RDI FIFO
    logic [CHUNK_COUNTER_WIDTH-1:0]  r_fdi_chunk_idx;   //    — index of chunk being transmitted over FDI (RDI path)
    logic [CHUNK_COUNTER_WIDTH-1:0]  r_tx_chunk_idx;    //    — index of chunk being transmitted over FDI (TX path)

    logic [127:0]      r_comp_pkt;
    logic              r_passing_done;
    logic              s_parityCalc_en;
    logic              s_calc_dataparity;
    logic              s_calc_controlparity;
    logic              s_COMP_WITHOUT_DATA;
    logic              s_pkt_collecting_done;

// ======================================================================= //
//  Combinational Flag Assignments
// ======================================================================= //
    assign s_COMP_WITHOUT_DATA = !r_comp_pkt[0];
    assign s_pkt_collecting_done = 
        ((r_rx_chunk_idx == (HALF_CHUNKS - 1)) && s_COMP_WITHOUT_DATA) |
        (r_rx_chunk_idx == (FULL_CHUNKS - 1));
// ======================================================================= //
//  Even Parity Calculator
// ======================================================================= //
    assign s_calc_controlparity = s_parityCalc_en ? (^r_comp_pkt[61:0])   : 1'b0;
    assign s_calc_dataparity    = s_parityCalc_en ? (^r_comp_pkt[127:64]) : 1'b0;
// ======================================================================= //
//  Packet Assembly and Tag Restoration
// ======================================================================= //
    always_ff @(posedge i_clk or negedge i_rst_n) begin : Packet_Tag_Storing_proc
        if (!i_rst_n) begin
            r_comp_pkt     <= '0;
            r_rx_chunk_idx <= '0;
        end
        else if (!i_init_n) begin
            r_comp_pkt     <= '0;
            r_rx_chunk_idx <= '0;
        end
        else begin
            case (completions_ctrl_state)

                PKT_ASSEMBLY: begin
                    // Store LSB first using proper bit indexing
                    if (r_rx_chunk_idx == 0) begin
                        r_comp_pkt <= i_comp_phase;
                    end else begin
                        // FIXED: No space before left shift
                         r_comp_pkt <= r_comp_pkt | (128'(i_comp_phase << (r_rx_chunk_idx * NC)));
                    end

                    if ((r_rx_chunk_idx == 64/NC - 1) && s_COMP_WITHOUT_DATA) begin      // Comp Without data "2 Phases - Half Packet"
                        r_rx_chunk_idx   <= 'b0;
                    end
                    else begin
                        r_rx_chunk_idx <= r_rx_chunk_idx + 1'b1;
                    end
                end

                VALIDATE_PKT: begin
                    // Restore original tag for local completions
                    if (r_comp_pkt[26:22] != REMOTE_TAG)
                        r_comp_pkt[26:22] <= i_rx_orig_tag;

                    // Handle DATA POISON (bit 5)
                    if (r_comp_pkt[5])
                        r_comp_pkt[34:32] <= 3'b001;  // UR (Unsupported Request)
                end

                TRANSMIT_VIA_FDI: begin
                    // Update control parity after tag restoration
                    if (r_fdi_chunk_idx == 1)
                        r_comp_pkt[62] <= s_calc_controlparity;
                end

                default: ;
            endcase
        end
    end
// ======================================================================= //
//  FDI Transmission (Two Sources: Fdi controller + RDI Completions)
// ======================================================================= //

    always_ff @(posedge i_clk or negedge i_rst_n) begin : Pass_Over_FDI_proc
        if (!i_rst_n) begin
            r_fdi_chunk_idx    <= '0;
            r_tx_chunk_idx     <= '0;
            o_pl_cfg_vld       <= '0;
            o_pl_cfg           <= '0;
            o_tx_Comp_pkt_done <= '0;
            r_passing_done     <= '0;
        end
        else if (!i_init_n) begin
            r_fdi_chunk_idx    <= '0;
            r_tx_chunk_idx     <= '0;
            o_pl_cfg_vld       <= '0;
            o_pl_cfg           <= '0;
            o_tx_Comp_pkt_done <= '0;
            r_passing_done     <= '0;
        end
        // ----------------------------------------------------------------
        // PATH A: Fdi controller Completion (Priority)
        // ----------------------------------------------------------------
        else if (i_tx_Comp_pkt_vld && (r_fdi_chunk_idx == '0)) begin

            o_tx_Comp_pkt_done <= 1'b0;
            o_pl_cfg <= NC'(i_tx_Comp_pkt >> (r_tx_chunk_idx * NC));
            o_pl_cfg_vld   <= 'b1;
            r_passing_done <= 'b0;

            if ((r_tx_chunk_idx == (FULL_CHUNKS - 2)) && i_tx_Comp_pkt[0]) begin
                // 128-bit completion with data
               // o_tx_Comp_pkt_done         <= 1'b1;
                r_tx_chunk_idx <= r_tx_chunk_idx + 1'b1;
            end
            else if ((r_tx_chunk_idx == (HALF_CHUNKS - 2)) && !i_tx_Comp_pkt[0]) begin
                // 64-bit completion without data
                r_tx_chunk_idx <= r_tx_chunk_idx + 1'b1;
            end
            else if ((r_tx_chunk_idx == (HALF_CHUNKS - 1)) && !i_tx_Comp_pkt[0]) begin
                // Reset counter after last chunk
                r_tx_chunk_idx     <= '0;
                o_tx_Comp_pkt_done <= 1'b1;
            end
            else if ((r_tx_chunk_idx == (FULL_CHUNKS - 1)) && i_tx_Comp_pkt[0]) begin
                // Reset counter after last chunk
                r_tx_chunk_idx     <= '0;
                o_tx_Comp_pkt_done <= 1'b1;
            end
            else begin
                r_tx_chunk_idx <= r_tx_chunk_idx + 1'b1;
            end
        end
        // ----------------------------------------------------------------
        // PATH B: RDI Local Completion
        // ----------------------------------------------------------------
        else if (completions_ctrl_nextstate == TRANSMIT_VIA_FDI) begin

            o_tx_Comp_pkt_done <= 1'b0;

            // Special handling for phase 1 (contains updated control parity)
            if ((r_fdi_chunk_idx == 1) && (NC == 32))
                o_pl_cfg <= {r_comp_pkt[63], s_calc_controlparity, r_comp_pkt[61:32]};
            else
                // FIXED: Direct bit extraction
                o_pl_cfg <= NC'(r_comp_pkt >> (r_fdi_chunk_idx * NC));
                o_pl_cfg_vld   <= 'b1;
                r_passing_done <= 'b0;
            // Check for completion
            if (s_COMP_WITHOUT_DATA && (r_fdi_chunk_idx == (HALF_CHUNKS - 1))) begin
                r_fdi_chunk_idx <= '0;
                r_passing_done  <= 1'b1;
            end
            else if ( r_fdi_chunk_idx == (FULL_CHUNKS - 1)) begin
                r_fdi_chunk_idx <= '0;
                r_passing_done  <= 1'b1;
            end
            else begin
                r_fdi_chunk_idx <= r_fdi_chunk_idx + 1'b1;
            end
        end

        else begin
            o_tx_Comp_pkt_done <= 1'b0;
            o_pl_cfg_vld       <= 1'b0;
            o_pl_cfg           <= '0;
            r_passing_done     <= 1'b0;
        end
    end
// ======================================================================= //
//  State Register
// ======================================================================= //
    always_ff @(posedge i_clk or negedge i_rst_n) begin : State_Transition_proc
        if (!i_rst_n)
            completions_ctrl_state <= IDLE;
        else if (!i_init_n)
            completions_ctrl_state <= IDLE;
        else
            completions_ctrl_state <= completions_ctrl_nextstate;
    end
// ======================================================================= //
//  Next-State Logic
// ======================================================================= //
    always_comb begin : Next_State_Logic_proc
        case (completions_ctrl_state)

            IDLE: begin
                if (!i_comp_fifo_empty)
                    completions_ctrl_nextstate = PKT_ASSEMBLY;
                else
                    completions_ctrl_nextstate = IDLE;
            end

            PKT_ASSEMBLY: begin
                if (s_pkt_collecting_done)
                    completions_ctrl_nextstate = VALIDATE_PKT;
                else
                    completions_ctrl_nextstate = PKT_ASSEMBLY;
            end

            VALIDATE_PKT: begin
                if ((s_calc_controlparity != r_comp_pkt[62]) || 
                    (s_calc_dataparity    != r_comp_pkt[63]))
                    completions_ctrl_nextstate = PARITY_ERROR;
                else if (r_comp_pkt[26:22] == REMOTE_TAG)
                    completions_ctrl_nextstate = FORWARD_REMOTE_COMP;
                else if (i_rx_tag_notfound)
                    completions_ctrl_nextstate = IDLE;
                else if (i_tx_Comp_pkt_vld)
                    completions_ctrl_nextstate = WAIT_FDI_FREE;
                else
                    completions_ctrl_nextstate = TRANSMIT_VIA_FDI;
            end

            WAIT_FDI_FREE: begin
                if (o_tx_Comp_pkt_done)
                    completions_ctrl_nextstate = TRANSMIT_VIA_FDI;
                else
                    completions_ctrl_nextstate = WAIT_FDI_FREE;
            end

            FORWARD_REMOTE_COMP: begin
                if (!i_comp_fifo_empty)
                    completions_ctrl_nextstate = PKT_ASSEMBLY;
                else
                    completions_ctrl_nextstate = IDLE;
            end

            TRANSMIT_VIA_FDI: begin
                if (r_passing_done) begin
                    if (!i_comp_fifo_empty)
                        completions_ctrl_nextstate = PKT_ASSEMBLY;
                    else
                        completions_ctrl_nextstate = IDLE;
                end
                else
                    completions_ctrl_nextstate = TRANSMIT_VIA_FDI;
            end

            PARITY_ERROR: begin
                completions_ctrl_nextstate = PARITY_ERROR;
            end

            default: 
                completions_ctrl_nextstate = IDLE;

        endcase
    end
// ======================================================================= //
//  Output Logic
// ======================================================================= //
    always_comb begin : Output_Logic_proc

        o_read_comp_fifo      = 1'b0;
        o_rx_chk_tag          = 1'b0;
        o_rx_current_tag      = '0;
        s_parityCalc_en       = 1'b0;
        o_rx_remote_comp_pkt  = '0;
        o_rx_remote_comp_vld  = 1'b0;
        o_rx_remote_comp_length = 1'b0;
        o_comp_parity_err     = 1'b0;

        case (completions_ctrl_state)

            IDLE: begin
                if (!i_comp_fifo_empty)
                    o_read_comp_fifo = 1'b1;
            end

            PKT_ASSEMBLY: begin
                o_read_comp_fifo = 1'b1;
                if (s_pkt_collecting_done)
                    o_read_comp_fifo = 1'b0;
            end

            VALIDATE_PKT: begin
                if (r_comp_pkt[26:22] != REMOTE_TAG) begin
                    o_rx_chk_tag     = 1'b1;
                    o_rx_current_tag = r_comp_pkt[26:22];
                end
                s_parityCalc_en = 1'b1;
            end

            FORWARD_REMOTE_COMP: begin
                if (r_comp_pkt[5])  // DATA POISON set
                    o_rx_remote_comp_pkt = {r_comp_pkt[127:35], 3'b001, r_comp_pkt[31:0]};
                else
                    o_rx_remote_comp_pkt = r_comp_pkt;

                o_rx_remote_comp_vld    = 1'b1;
                o_rx_remote_comp_length = r_comp_pkt[0];  // 1=128b, 0=64b

                if (!i_comp_fifo_empty)
                    o_read_comp_fifo = 1'b1;
            end

            TRANSMIT_VIA_FDI: begin
                s_parityCalc_en = 1'b1;
                if (r_passing_done && !i_comp_fifo_empty)
                    o_read_comp_fifo = 1'b1;
            end

            PARITY_ERROR: begin
                o_comp_parity_err = 1'b1;
            end

            default: ;

        endcase
    end

endmodule