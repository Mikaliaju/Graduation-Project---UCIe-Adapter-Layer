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

    input  logic                  i_clk,               // Clock of operation "lclk"
    input  logic                  i_rstn,              // HW reset : active low
    input  logic                  i_init_n,            // SW reset : active low

    /* RDI Interface */
    input  logic  [NC-1 : 0]      i_pl_cfg,            // Packet chunks received from PHY over RDI
    input  logic                  i_pl_cfg_vld,        // Indicates valid chunks that should be received

    /* Completions FIFO */
    output logic  [NC-1 : 0]      o_comp_phase,        // Completion phase written to Completions FIFO
    output logic                  o_write_comp_fifo,   // Indicates valid comp phase to be written in the FIFO

    /* Remote Die Request Controller — Direct Full-Packet Interface (EP only) */
    output logic  [127 : 0]       o_remote_req_pkt,    // Full request packet forwarded to Remote Die Request Controller
    output logic                  o_remote_req_vld,    // Indicates a valid full request packet

    /* Messages FIFO */
    output logic  [NC-1 : 0]      o_msg_phase,         // Message phase written to Messages FIFO
    output logic                  o_write_msg_fifo,    // Indicates valid msg phase to be written in the FIFO

    /* Error Handler */
    output logic                  o_rsvd_opcode_err,   // Indicates that a reserved opcode has been received
   
    output logic                  o_req_parity_err     // Indicates that a request packet has a parity error -> Fatal UIE
   
);
//================================================== Internal Signals ====================================================

    rxd_sts  rxd_state, rxd_nextstate;              // Current state, Next state
    rxd_sts  w_opcode_state;                        // Decoded next state from opcode
    logic [CHUNK_COUNTER_WIDTH-1:0] r_chunk_counter;   // Counts received chunks for the current packet

    // Request packet collection & parity check
    logic [127:0]  r_req_pkt;               // Accumulated request packet register
    logic          s_IS_READ_REQ;           // Flag: current request is a Read (2 phases)
    logic          s_req_collecting_done;   // Flag: all chunks of the request have been collected
    logic          s_parityCalc_en;         // Enable parity calculation on the stored packet
    logic          s_calc_controlparity;    // Calculated control parity (bits [61:0])
    logic          s_calc_dataparity;       // Calculated data parity    (bits [127:64])

//================================================== Opcode Decoder ====================================================
// Combinationally maps the 5-bit opcode to the corresponding next FSM state.
// w_opcode_state is consumed by Next State Logic whenever i_pl_cfg_vld is high.

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

//================================================== Request Collect & Parity (EP only) ====================================================

    // Read request has opcode[1:0] == 2'b00 
    assign s_IS_READ_REQ = (r_req_pkt[1:0] == 2'b00);

    // Collecting is done when: last chunk of a 2-phase read req, OR last chunk of a 4-phase write req
    assign s_req_collecting_done = ((r_chunk_counter == 64/NC - 1) &&  s_IS_READ_REQ) |
                                    (r_chunk_counter == 128/NC - 1);

    // Even parity over the stored packet
    assign s_calc_controlparity = s_parityCalc_en ? ^r_req_pkt[61:0]   : 1'b0;
    assign s_calc_dataparity    = s_parityCalc_en ? ^r_req_pkt[127:64] : 1'b0;

    // Packet Storing — accumulates incoming chunks into r_req_pkt
    always_ff @(posedge i_clk or negedge i_rstn) begin : Req_Packet_Storing_proc
        if (!i_rstn) begin
            r_req_pkt       <= 'b0;
            r_chunk_counter <= 'b0;
        end
        else if (!i_init_n) begin
            r_req_pkt       <= 'b0;
            r_chunk_counter <= 'b0;
        end
        else begin
            case (rxd_state)
                RXD_COLLECT_READ_REQ,
                RXD_COLLECT_WRITE_REQ: begin
                    if (r_chunk_counter == 0) begin
                        r_req_pkt <= 128'(i_pl_cfg);                                                    // First chunk: clear and store directly
                    end else begin
                        r_req_pkt <= 128'(r_req_pkt | (128'(i_pl_cfg) << (r_chunk_counter * NC)));      // Append chunk at correct bit position
                    end
                end

                default: ;
            endcase
        end
    end

//================================================= Chunk Counter (Completions & Messages) ====================================================
// Tracks how many chunks of the current Completion or Message packet have been forwarded to their FIFO.
// Requests have their own counter inside Req_Packet_Storing_proc above.

    always_ff @(posedge i_clk or negedge i_rstn) begin : Chunk_Counter_proc
        if (!i_rstn) begin
            r_chunk_counter <= 'b0;
        end
        else if (!i_init_n) begin
            r_chunk_counter <= 'b0;
        end
        else begin
            case (rxd_state)
                RXD_IDLE: begin
                    r_chunk_counter <= 'b0;
                end
                // 4-phase types
                RXD_COMP_WITH_DATA, RXD_MSG_WITH_DATA: begin
                    r_chunk_counter <= r_chunk_counter + 1'b1;
                end
                // 2-phase types
                RXD_COMP_WITHOUT_DATA, RXD_MSG_WITHOUT_DATA: begin
                    if (r_chunk_counter == (64/NC - 1))
                        r_chunk_counter <= 'b0;
                    else
                        r_chunk_counter <= r_chunk_counter + 1'b1;
                end
                RXD_COLLECT_WRITE_REQ: begin
                    if (s_req_collecting_done) begin
                        r_chunk_counter <= 'b0;                                                         // Reset counter once packet is complete
                    end else begin
                        r_chunk_counter <= r_chunk_counter + 1'b1;
                    end
                end
                default: r_chunk_counter <= 'b0;
            endcase
        end
    end

//================================================= State Transition ====================================================

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

//================================================= Next State Logic ====================================================

    always_comb begin : Next_State_Logic_proc
        case (rxd_state)
            RXD_IDLE: begin
                if (i_pl_cfg_vld)
                    rxd_nextstate = w_opcode_state;
                else
                    rxd_nextstate = RXD_IDLE;
            end

            // ── Completions & Messages: phase-by-phase forwarding ──────────────────────────
            RXD_COMP_WITH_DATA, RXD_MSG_WITH_DATA: begin
                if (r_chunk_counter == (128/NC - 1))
                    rxd_nextstate = i_pl_cfg_vld ? w_opcode_state : RXD_IDLE;
                else
                    rxd_nextstate = i_pl_cfg_vld ? rxd_state      : RXD_ERROR;
            end

            RXD_COMP_WITHOUT_DATA, RXD_MSG_WITHOUT_DATA: begin
                if (r_chunk_counter == (64/NC - 1))
                    rxd_nextstate = i_pl_cfg_vld ? w_opcode_state : RXD_IDLE;
                else
                    rxd_nextstate = i_pl_cfg_vld ? rxd_state      : RXD_ERROR;
            end

            // ── Requests: collect all chunks then parity-check ─────────────────────────────
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
                    rxd_nextstate = i_pl_cfg_vld ? w_opcode_state : RXD_IDLE;   // Ready for next packet
            end

            RXD_REQ_PARITY_ERR: begin
                rxd_nextstate = rxd_state;   // Stuck here until HW or SW reset
            end

            RXD_ERROR: begin
                rxd_nextstate = rxd_state;   // Stuck here until HW or SW reset
            end

            default: begin
                rxd_nextstate = RXD_IDLE;
            end
        endcase
    end

//================================================= Output Logic ====================================================

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
            // ── IDLE: first chunk of a new packet ─────────────────────────────────────────
            RXD_IDLE: begin
                if (i_pl_cfg_vld) begin
                    case (i_pl_cfg[4:0])
                        5'b10000, 5'b10001, 5'b11001: begin            // Completion phase → FIFO
                            o_write_comp_fifo = 1'b1;
                            o_comp_phase      = i_pl_cfg;
                        end
                        5'b10010, 5'b11011: begin                      // Message phase → FIFO
                            o_write_msg_fifo = 1'b1;
                            o_msg_phase      = i_pl_cfg;
                        end
                    endcase
                end
            end

            // ── Completions (4-phase): forward each chunk to FIFO ─────────────────────────
            RXD_COMP_WITH_DATA: begin
                if (r_chunk_counter == (128/NC - 1)) begin
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

            // ── Completions (2-phase): forward each chunk to FIFO ─────────────────────────
            RXD_COMP_WITHOUT_DATA: begin
                if (r_chunk_counter == (64/NC - 1)) begin
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

            // ── Messages (4-phase): forward each chunk to FIFO ────────────────────────────
            RXD_MSG_WITH_DATA: begin
                if (r_chunk_counter == (128/NC - 1)) begin
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

            // ── Messages (2-phase): forward each chunk to FIFO ────────────────────────────
            RXD_MSG_WITHOUT_DATA: begin
                if (r_chunk_counter == (64/NC - 1)) begin
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

            // ── Request collection states: no output — chunks go into r_req_pkt via FF ────
            RXD_COLLECT_READ_REQ,
            RXD_COLLECT_WRITE_REQ: begin
                
            end

            // ── Request parity check: validate then release full packet ───────────────────
            RXD_REQ_PARITY_CHK: begin
                s_parityCalc_en = 1'b1;
                if (s_calc_controlparity != r_req_pkt[62] || s_calc_dataparity != r_req_pkt[63]) begin
                    o_req_parity_err = 1'b1;
                end else begin
                    o_remote_req_pkt = r_req_pkt;   // Send full 128-bit packet
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