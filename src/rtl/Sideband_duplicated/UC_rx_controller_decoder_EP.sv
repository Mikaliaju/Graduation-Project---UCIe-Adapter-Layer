// ================================================================================================================================
//  FILENAME    : UC_rx_controller_decoder_EP.sv
//  MODULE      : UC_rx_controller_decoder_EP
//  PROJECT     : UCIe 3.0 Adapter Layer
//  AUTHOR      : Ashraf Sherif, Shahd Mohamed
// ================================================================================================================================
//  Description : It decodes the first phase from each received packet over RDI
//               and forwards it to the corresponding block based on its type:
//               - Register Access Requests  → Collected, parity checked, then sent directly to Remote Die Request Controller
//               - Completions               → Completions FIFO (phase by phase)
//               - Messages                  → Messages FIFO (phase by phase)
// ================================================================================================================================
import UC_sb_rx_pkg_EP::* ;
module UC_rx_controller_decoder_EP #(parameter NC = 32) (

    input  logic                  i_clk,
    input  logic                  i_rstn,
    input  logic                  i_init_n,

    /* RDI Interface */
    input  logic  [NC-1 : 0]      i_pl_cfg,
    input  logic                  i_pl_cfg_vld,

    /* Completions FIFO */
    output logic  [NC-1 : 0]      o_comp_phase,
    output logic                  o_write_comp_fifo,

    /* Remote Die Request Controller */
    output logic  [127 : 0]       o_remote_req_pkt,
    output logic                  o_remote_req_vld,

    /* Messages FIFO */
    output logic  [NC-1 : 0]      o_msg_phase,
    output logic                  o_write_msg_fifo,

    /* Error Handler */
    output logic                  o_rsvd_opcode_err,
    output logic                  o_req_parity_err

);

// ================================================== Internal Signals ====================================================

    rxd_sts  rxd_state, rxd_nextstate;
    rxd_sts  w_opcode_state;

    // Request counter — SOLE driver: Req_Packet_Storing_proc
    logic [CHUNK_COUNTER_WIDTH-1:0] r_chunk_counter;

    // Completion/Message counter — SOLE driver: Chunk_Counter_proc (BUG1 fix)
    logic [CHUNK_COUNTER_WIDTH-1:0] r_cm_chunk_counter;

    logic [127:0]  r_req_pkt;
    logic [4:0]    r_req_opcode;          // BUG3 fix: opcode latched from chunk0
    logic          s_IS_READ_REQ;
    logic          s_req_collecting_done;
    logic          s_parityCalc_en;
    logic          s_calc_controlparity;
    logic          s_calc_dataparity;

// ================================================== Opcode Decoder ====================================================

    always_comb begin : Opcode_Decode_proc
        case (i_pl_cfg[4:0])
            5'b10000:                                    w_opcode_state = RXD_COMP_WITHOUT_DATA;
            5'b10001, 5'b11001:                          w_opcode_state = RXD_COMP_WITH_DATA;
            5'b10010:                                    w_opcode_state = RXD_MSG_WITHOUT_DATA;
            5'b11011:                                    w_opcode_state = RXD_MSG_WITH_DATA;
            5'b00000, 5'b00100, 5'b01000, 5'b01100:     w_opcode_state = RXD_COLLECT_READ_REQ;
            5'b00001, 5'b00101, 5'b01001, 5'b01101:     w_opcode_state = RXD_COLLECT_WRITE_REQ;
            default:                                     w_opcode_state = RXD_ERROR;
        endcase
    end

// ================================================== Request Collect & Parity ====================================================

    // BUG3 fix: use r_req_opcode (latched in IDLE) instead of r_req_pkt[1:0]
    // r_req_pkt[1:0] is only valid one cycle AFTER chunk0 is stored, which is
    // too late — s_IS_READ_REQ would read 2'b00 for any write packet on the
    // first collect cycle and incorrectly assert s_req_collecting_done at counter=1.
    assign s_IS_READ_REQ = (r_req_opcode[1:0] == 2'b00);

    assign s_req_collecting_done = ((r_chunk_counter == 64/NC - 1) &&  s_IS_READ_REQ) |
                                    (r_chunk_counter == 128/NC - 1);

    assign s_calc_controlparity  = s_parityCalc_en ? ^r_req_pkt[61:0]   : 1'b0;
    assign s_calc_dataparity     = s_parityCalc_en ? ^r_req_pkt[127:64] : 1'b0;

    // ── Request packet accumulator ───────────────────────────────────────────────
    // BUG2 fix: RXD_IDLE branch captures chunk0 in the same cycle it arrives.
    // BUG3 fix: r_req_opcode latched from i_pl_cfg[4:0] in RXD_IDLE so that
    //           s_IS_READ_REQ is correct from counter=1 onward.
    // This block is the SOLE driver of r_chunk_counter and r_req_opcode.
    always_ff @(posedge i_clk or negedge i_rstn) begin : Req_Packet_Storing_proc
        if (!i_rstn) begin
            r_req_pkt       <= 'b0;
            r_chunk_counter <= 'b0;
            r_req_opcode    <= 'b0;
        end
        else if (!i_init_n) begin
            r_req_pkt       <= 'b0;
            r_chunk_counter <= 'b0;
            r_req_opcode    <= 'b0;
        end
        else begin
            case (rxd_state)

                // ── Capture chunk0 while still in IDLE ───────────────────────────
                // rxd_nextstate is combinational so we can see the decision this
                // cycle and store the data before the state register updates.
                RXD_IDLE: begin
                    if (i_pl_cfg_vld &&
                       (rxd_nextstate == RXD_COLLECT_READ_REQ ||
                        rxd_nextstate == RXD_COLLECT_WRITE_REQ)) begin
                        r_req_pkt       <= 128'(i_pl_cfg);   // chunk0 → bits [NC-1:0]
                        r_req_opcode    <= i_pl_cfg[4:0];    // latch opcode immediately
                        r_chunk_counter <= 1;                 // chunk1 is next
                    end else begin
                        r_req_pkt       <= 'b0;
                        r_req_opcode    <= 'b0;
                        r_chunk_counter <= 'b0;
                    end
                end

                // ── Append chunks 1..N ───────────────────────────────────────────
                // r_req_opcode already valid → s_IS_READ_REQ correct → 
                // s_req_collecting_done fires at the right counter value.
                RXD_COLLECT_READ_REQ,
                RXD_COLLECT_WRITE_REQ: begin
                    r_req_pkt <= r_req_pkt | (128'(i_pl_cfg) << (r_chunk_counter * NC));

                    if (s_req_collecting_done)
                        r_chunk_counter <= 'b0;
                    else
                        r_chunk_counter <= r_chunk_counter + 1'b1;
                end

                default: begin
                    r_chunk_counter <= 'b0;
                    r_req_opcode    <= 'b0;
                end

            endcase
        end
    end

// ================================================= Chunk Counter (Completions & Messages) ====================================================
    // BUG1 fix: r_cm_chunk_counter is the SOLE signal driven by this block.
    // r_chunk_counter (requests) is never touched here.

    always_ff @(posedge i_clk or negedge i_rstn) begin : Chunk_Counter_proc
        if (!i_rstn) begin
            r_cm_chunk_counter <= 'b0;
        end
        else if (!i_init_n) begin
            r_cm_chunk_counter <= 'b0;
        end
        else begin
            case (rxd_state)
                RXD_IDLE: begin
                    r_cm_chunk_counter <= 'b0;
                end
                RXD_COMP_WITH_DATA, RXD_MSG_WITH_DATA: begin
                    r_cm_chunk_counter <= r_cm_chunk_counter + 1'b1;
                end
                RXD_COMP_WITHOUT_DATA, RXD_MSG_WITHOUT_DATA: begin
                    if (r_cm_chunk_counter == (64/NC - 1))
                        r_cm_chunk_counter <= 'b0;
                    else
                        r_cm_chunk_counter <= r_cm_chunk_counter + 1'b1;
                end
                default: r_cm_chunk_counter <= 'b0;
            endcase
        end
    end

// ================================================= State Transition ====================================================

    always_ff @(posedge i_clk or negedge i_rstn) begin : State_Transition_proc
        if (!i_rstn) begin
            rxd_state <= RXD_IDLE;
        end
        else if (!i_init_n) begin
            rxd_state <= RXD_IDLE;
        end
        else begin
            rxd_state <= rxd_nextstate;
        end
    end

// ================================================= Next State Logic ====================================================
// BUG1 fix: completion/message checks use r_cm_chunk_counter

    always_comb begin : Next_State_Logic_proc
        case (rxd_state)

            RXD_IDLE: begin
                if (i_pl_cfg_vld)
                    rxd_nextstate = w_opcode_state;
                else
                    rxd_nextstate = RXD_IDLE;
            end

            RXD_COMP_WITH_DATA, RXD_MSG_WITH_DATA: begin
                if (r_cm_chunk_counter == (128/NC - 1))
                    rxd_nextstate = i_pl_cfg_vld ? w_opcode_state : RXD_IDLE;
                else
                    rxd_nextstate = i_pl_cfg_vld ? rxd_state      : RXD_ERROR;
            end

            RXD_COMP_WITHOUT_DATA, RXD_MSG_WITHOUT_DATA: begin
                if (r_cm_chunk_counter == (64/NC - 1))
                    rxd_nextstate = i_pl_cfg_vld ? w_opcode_state : RXD_IDLE;
                else
                    rxd_nextstate = i_pl_cfg_vld ? rxd_state      : RXD_ERROR;
            end

            RXD_COLLECT_READ_REQ: begin
                if (s_req_collecting_done)
                    rxd_nextstate = RXD_REQ_PARITY_CHK;
                else
                    rxd_nextstate = i_pl_cfg_vld ? RXD_COLLECT_READ_REQ : RXD_ERROR;
            end

            RXD_COLLECT_WRITE_REQ: begin
                if (s_req_collecting_done)
                    rxd_nextstate = RXD_REQ_PARITY_CHK;
                else
                    rxd_nextstate = i_pl_cfg_vld ? RXD_COLLECT_WRITE_REQ : RXD_ERROR;
            end

            RXD_REQ_PARITY_CHK: begin
                if (s_calc_controlparity != r_req_pkt[62] || s_calc_dataparity != r_req_pkt[63])
                    rxd_nextstate = RXD_REQ_PARITY_ERR;
                else
                    rxd_nextstate = i_pl_cfg_vld ? w_opcode_state : RXD_IDLE;
            end

            RXD_REQ_PARITY_ERR: begin
                rxd_nextstate = rxd_state;
            end

            RXD_ERROR: begin
                rxd_nextstate = rxd_state;
            end

            default: begin
                rxd_nextstate = RXD_IDLE;
            end

        endcase
    end

// ================================================= Output Logic ====================================================
// BUG1 fix: completion/message output checks use r_cm_chunk_counter

    always_comb begin : Output_Logic_proc

        o_comp_phase      = 'b0;
        o_write_comp_fifo = 'b0;
        o_msg_phase       = 'b0;
        o_write_msg_fifo  = 'b0;
        o_rsvd_opcode_err = 'b0;
        o_remote_req_pkt  = 'b0;
        o_remote_req_vld  = 'b0;
        o_req_parity_err  = 'b0;
        s_parityCalc_en   = 'b0;

        case (rxd_state)

            // ── IDLE ──────────────────────────────────────────────────────────────────────
            RXD_IDLE: begin
                if (i_pl_cfg_vld) begin
                    case (i_pl_cfg[4:0])
                        5'b10000, 5'b10001, 5'b11001: begin
                            o_write_comp_fifo = 1'b1;
                            o_comp_phase      = i_pl_cfg;
                        end
                        5'b10010, 5'b11011: begin
                            o_write_msg_fifo = 1'b1;
                            o_msg_phase      = i_pl_cfg;
                        end
                    endcase
                end
            end

            // ── Completions 4-phase ───────────────────────────────────────────────────────
            RXD_COMP_WITH_DATA: begin
                if (r_cm_chunk_counter == (128/NC - 1)) begin
                    if (i_pl_cfg_vld) begin
                        case (i_pl_cfg[4:0])
                            5'b10000, 5'b10001, 5'b11001: begin
                                o_write_comp_fifo = 1'b1;
                                o_comp_phase      = i_pl_cfg;
                            end
                            5'b10010, 5'b11011: begin
                                o_write_msg_fifo = 1'b1;
                                o_msg_phase      = i_pl_cfg;
                            end
                        endcase
                    end
                end else begin
                    o_write_comp_fifo = 1'b1;
                    o_comp_phase      = i_pl_cfg;
                end
            end

            // ── Completions 2-phase ───────────────────────────────────────────────────────
            RXD_COMP_WITHOUT_DATA: begin
                if (r_cm_chunk_counter == (64/NC - 1)) begin
                    if (i_pl_cfg_vld) begin
                        case (i_pl_cfg[4:0])
                            5'b10000, 5'b10001, 5'b11001: begin
                                o_write_comp_fifo = 1'b1;
                                o_comp_phase      = i_pl_cfg;
                            end
                            5'b10010, 5'b11011: begin
                                o_write_msg_fifo = 1'b1;
                                o_msg_phase      = i_pl_cfg;
                            end
                        endcase
                    end
                end else begin
                    o_write_comp_fifo = 1'b1;
                    o_comp_phase      = i_pl_cfg;
                end
            end

            // ── Messages 4-phase ──────────────────────────────────────────────────────────
            RXD_MSG_WITH_DATA: begin
                if (r_cm_chunk_counter == (128/NC - 1)) begin
                    if (i_pl_cfg_vld) begin
                        case (i_pl_cfg[4:0])
                            5'b10000, 5'b10001, 5'b11001: begin
                                o_write_comp_fifo = 1'b1;
                                o_comp_phase      = i_pl_cfg;
                            end
                            5'b10010, 5'b11011: begin
                                o_write_msg_fifo = 1'b1;
                                o_msg_phase      = i_pl_cfg;
                            end
                        endcase
                    end
                end else begin
                    o_write_msg_fifo = 1'b1;
                    o_msg_phase      = i_pl_cfg;
                end
            end

            // ── Messages 2-phase ──────────────────────────────────────────────────────────
            RXD_MSG_WITHOUT_DATA: begin
                if (r_cm_chunk_counter == (64/NC - 1)) begin
                    if (i_pl_cfg_vld) begin
                        case (i_pl_cfg[4:0])
                            5'b10000, 5'b10001, 5'b11001: begin
                                o_write_comp_fifo = 1'b1;
                                o_comp_phase      = i_pl_cfg;
                            end
                            5'b10010, 5'b11011: begin
                                o_write_msg_fifo = 1'b1;
                                o_msg_phase      = i_pl_cfg;
                            end
                        endcase
                    end
                end else begin
                    o_write_msg_fifo = 1'b1;
                    o_msg_phase      = i_pl_cfg;
                end
            end

            // ── Request collection: no outputs, FF handles accumulation ───────────────────
            RXD_COLLECT_READ_REQ,
            RXD_COLLECT_WRITE_REQ: begin
            end

            // ── Parity check: release full packet if clean ────────────────────────────────
            RXD_REQ_PARITY_CHK: begin
                s_parityCalc_en = 1'b1;
                if (s_calc_controlparity != r_req_pkt[62] || s_calc_dataparity != r_req_pkt[63]) begin
                    o_req_parity_err = 1'b1;
                end else begin
                    o_remote_req_pkt = r_req_pkt;
                    o_remote_req_vld = 1'b1;
                end
            end

            RXD_REQ_PARITY_ERR: begin
                o_req_parity_err = 1'b1;
            end

            RXD_ERROR: begin
                o_rsvd_opcode_err = 1'b1;
            end

            default: ;

        endcase
    end

endmodule