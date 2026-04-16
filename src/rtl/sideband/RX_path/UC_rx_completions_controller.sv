// ================================================================================================================================
//  FILENAME    : UC_rx_completions_controller.sv 
//  MODULE      : UC_rx_completions_controller
//  PROJECT     : UCIe 3.0 Adapter Layer
//  AUTHOR      : Ashraf Sherif, Shahd Mohamed
// ================================================================================================================================

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
//  FSM State Encoding 
// ======================================================================= //

    typedef enum logic [2:0] {
        COMP_CTRL_IDLE       = 3'd0,
        COLLECT_COMP_PKT     = 3'd1,
        PARITY_TAG_CHK       = 3'd2,
        FDI_IS_BUSY          = 3'd3,
        PASS_OVER_FDI        = 3'd4,
        PASS_REMOTE_COMP     = 3'd5,
        COMP_PARITY_ERR_STATE = 3'd6
    } completions_ctrl_state_e;

// ======================================================================= //
//  Local Parameters
// ======================================================================= //

    localparam CHUNK_COUNTER_WIDTH = $clog2(128/NC);
    localparam HALF_CHUNKS         = 64  / NC;
    localparam FULL_CHUNKS         = 128 / NC;
    localparam logic [4:0] REMOTE_TAG = 5'b11111;

// ======================================================================= //
//  Internal Signals
// ======================================================================= //

    completions_ctrl_state_e  completions_ctrl_state, completions_ctrl_nextstate;

    logic [CHUNK_COUNTER_WIDTH-1:0]  r_storing_chunk_counter;
    logic [CHUNK_COUNTER_WIDTH-1:0]  r_passing_chunk_counter;
    logic [CHUNK_COUNTER_WIDTH-1:0]  r_tx_passing_chunk_counter;

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
        ((r_storing_chunk_counter == (HALF_CHUNKS - 1)) && s_COMP_WITHOUT_DATA) |
        (r_storing_chunk_counter == (FULL_CHUNKS - 1));

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
            r_comp_pkt              <= '0;
            r_storing_chunk_counter <= '0;
        end
        else if (!i_init_n) begin
            r_comp_pkt              <= '0;
            r_storing_chunk_counter <= '0;
        end
        else begin
            case (completions_ctrl_state)

                COLLECT_COMP_PKT: begin
                    // Store LSB first using proper bit indexing
                    if (r_storing_chunk_counter == 0) begin
                        r_comp_pkt <= i_comp_phase;
                    end else begin
                        // FIXED: No space before left shift
                        r_comp_pkt <= r_comp_pkt | (i_comp_phase << (r_storing_chunk_counter * NC));
                    end

                    // Increment counter
                    if (s_pkt_collecting_done)
                        r_storing_chunk_counter <= '0;
                    else
                        r_storing_chunk_counter <= r_storing_chunk_counter + 1'b1;
                end

                PARITY_TAG_CHK: begin
                    // Restore original tag for local completions
                    if (r_comp_pkt[26:22] != REMOTE_TAG)
                        r_comp_pkt[26:22] <= i_rx_orig_tag;

                    // Handle DATA POISON (bit 5)
                    if (r_comp_pkt[5])
                        r_comp_pkt[34:32] <= 3'b001;  // UR (Unsupported Request)
                end

                PASS_OVER_FDI: begin
                    // Update control parity after tag restoration
                    if (r_passing_chunk_counter == 1)
                        r_comp_pkt[62] <= s_calc_controlparity;
                end

                default: ;
            endcase
        end
    end

// ======================================================================= //
//  FDI Transmission (Two Sources: Tx Controller + RDI Completions)
// ======================================================================= //

    always_ff @(posedge i_clk or negedge i_rst_n) begin : Pass_Over_FDI_proc
        if (!i_rst_n) begin
            r_passing_chunk_counter    <= '0;
            r_tx_passing_chunk_counter <= '0;
            o_pl_cfg_vld               <= '0;
            o_pl_cfg                   <= '0;
            o_tx_Comp_pkt_done         <= '0;
            r_passing_done             <= '0;
        end
        else if (!i_init_n) begin
            r_passing_chunk_counter    <= '0;
            r_tx_passing_chunk_counter <= '0;
            o_pl_cfg_vld               <= '0;
            o_pl_cfg                   <= '0;
            o_tx_Comp_pkt_done         <= '0;
            r_passing_done             <= '0;
        end

        // ----------------------------------------------------------------
        // PATH A: Tx Controller Completion (Priority)
        // ----------------------------------------------------------------
        else if (i_tx_Comp_pkt_vld && (r_passing_chunk_counter == '0)) begin

            o_tx_Comp_pkt_done <= 1'b0;
            // FIXED: Direct bit extraction without casting
            o_pl_cfg           <= (i_tx_Comp_pkt >> (r_tx_passing_chunk_counter * NC));
            o_pl_cfg_vld       <= 1'b1;
            r_passing_done     <= 1'b0;

            if ((r_tx_passing_chunk_counter == (FULL_CHUNKS - 2)) && i_tx_Comp_pkt[0]) begin
                // 128-bit completion with data
                o_tx_Comp_pkt_done         <= 1'b1;
                r_tx_passing_chunk_counter <= r_tx_passing_chunk_counter + 1'b1;
            end
            else if ((r_tx_passing_chunk_counter == (HALF_CHUNKS - 2)) && !i_tx_Comp_pkt[0]) begin
                // 64-bit completion without data
                o_tx_Comp_pkt_done         <= 1'b1;
                r_tx_passing_chunk_counter <= r_tx_passing_chunk_counter + 1'b1;
            end
            else if ((r_tx_passing_chunk_counter == (HALF_CHUNKS - 1)) && !i_tx_Comp_pkt[0]) begin
                // Reset counter after last chunk
                r_tx_passing_chunk_counter <= '0;
            end
            else begin
                r_tx_passing_chunk_counter <= r_tx_passing_chunk_counter + 1'b1;
            end
        end

        // ----------------------------------------------------------------
        // PATH B: RDI Local Completion
        // ----------------------------------------------------------------
        else if (completions_ctrl_nextstate == PASS_OVER_FDI) begin

            o_tx_Comp_pkt_done <= 1'b0;
            r_passing_done     <= 1'b0;
            o_pl_cfg_vld       <= 1'b1;

            // Special handling for phase 1 (contains updated control parity)
            if ((r_passing_chunk_counter == 1) && (NC == 32))
                o_pl_cfg <= {r_comp_pkt[63], s_calc_controlparity, r_comp_pkt[61:32]};
            else
                // FIXED: Direct bit extraction
                o_pl_cfg <= (r_comp_pkt >> (r_passing_chunk_counter * NC));

            // Check for completion
            if (s_COMP_WITHOUT_DATA && (r_passing_chunk_counter == (HALF_CHUNKS - 1))) begin
                r_passing_chunk_counter <= '0;
                r_passing_done          <= 1'b1;
            end
            else if (!s_COMP_WITHOUT_DATA && (r_passing_chunk_counter == (FULL_CHUNKS - 1))) begin
                r_passing_chunk_counter <= '0;
                r_passing_done          <= 1'b1;
            end
            else begin
                r_passing_chunk_counter <= r_passing_chunk_counter + 1'b1;
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
            completions_ctrl_state <= COMP_CTRL_IDLE;
        else if (!i_init_n)
            completions_ctrl_state <= COMP_CTRL_IDLE;
        else
            completions_ctrl_state <= completions_ctrl_nextstate;
    end

// ======================================================================= //
//  Next-State Logic
// ======================================================================= //

    always_comb begin : Next_State_Logic_proc
        case (completions_ctrl_state)

            COMP_CTRL_IDLE: begin
                if (!i_comp_fifo_empty)
                    completions_ctrl_nextstate = COLLECT_COMP_PKT;
                else
                    completions_ctrl_nextstate = COMP_CTRL_IDLE;
            end

            COLLECT_COMP_PKT: begin
                if (s_pkt_collecting_done)
                    completions_ctrl_nextstate = PARITY_TAG_CHK;
                else
                    completions_ctrl_nextstate = COLLECT_COMP_PKT;
            end

            PARITY_TAG_CHK: begin
                if ((s_calc_controlparity != r_comp_pkt[62]) || 
                    (s_calc_dataparity    != r_comp_pkt[63]))
                    completions_ctrl_nextstate = COMP_PARITY_ERR_STATE;
                else if (r_comp_pkt[26:22] == REMOTE_TAG)
                    completions_ctrl_nextstate = PASS_REMOTE_COMP;
                else if (i_rx_tag_notfound)
                    completions_ctrl_nextstate = COMP_CTRL_IDLE;
                else if (i_tx_Comp_pkt_vld)
                    completions_ctrl_nextstate = FDI_IS_BUSY;
                else
                    completions_ctrl_nextstate = PASS_OVER_FDI;
            end

            FDI_IS_BUSY: begin
                if (o_tx_Comp_pkt_done)
                    completions_ctrl_nextstate = PASS_OVER_FDI;
                else
                    completions_ctrl_nextstate = FDI_IS_BUSY;
            end

            PASS_REMOTE_COMP: begin
                if (!i_comp_fifo_empty)
                    completions_ctrl_nextstate = COLLECT_COMP_PKT;
                else
                    completions_ctrl_nextstate = COMP_CTRL_IDLE;
            end

            PASS_OVER_FDI: begin
                if (r_passing_done) begin
                    if (!i_comp_fifo_empty)
                        completions_ctrl_nextstate = COLLECT_COMP_PKT;
                    else
                        completions_ctrl_nextstate = COMP_CTRL_IDLE;
                end
                else
                    completions_ctrl_nextstate = PASS_OVER_FDI;
            end

            COMP_PARITY_ERR_STATE: begin
                completions_ctrl_nextstate = COMP_PARITY_ERR_STATE;
            end

            default: 
                completions_ctrl_nextstate = COMP_CTRL_IDLE;

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

            COMP_CTRL_IDLE: begin
                if (!i_comp_fifo_empty)
                    o_read_comp_fifo = 1'b1;
            end

            COLLECT_COMP_PKT: begin
                o_read_comp_fifo = 1'b1;
                if (s_pkt_collecting_done)
                    o_read_comp_fifo = 1'b0;
            end

            PARITY_TAG_CHK: begin
                if (r_comp_pkt[26:22] != REMOTE_TAG) begin
                    o_rx_chk_tag     = 1'b1;
                    o_rx_current_tag = r_comp_pkt[26:22];
                end
                s_parityCalc_en = 1'b1;
            end

            PASS_REMOTE_COMP: begin
                if (r_comp_pkt[5])  // DATA POISON set
                    o_rx_remote_comp_pkt = {r_comp_pkt[127:35], 3'b001, r_comp_pkt[31:0]};
                else
                    o_rx_remote_comp_pkt = r_comp_pkt;

                o_rx_remote_comp_vld    = 1'b1;
                o_rx_remote_comp_length = r_comp_pkt[0];  // 1=128b, 0=64b

                if (!i_comp_fifo_empty)
                    o_read_comp_fifo = 1'b1;
            end

            PASS_OVER_FDI: begin
                s_parityCalc_en = 1'b1;
                if (r_passing_done && !i_comp_fifo_empty)
                    o_read_comp_fifo = 1'b1;
            end

            COMP_PARITY_ERR_STATE: begin
                o_comp_parity_err = 1'b1;
            end

            default: ;

        endcase
    end

endmodule
