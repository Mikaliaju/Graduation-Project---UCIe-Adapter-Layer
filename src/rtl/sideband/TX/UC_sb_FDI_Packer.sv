/*
Author  : Shahd Mohamed, Ashraf Sherif

Module  : UC_sb_FDI_Packer

Description:
  The FDI Packer Block is responsible for handling local register access requests
  originating from the Protocol Layer. Its role is to construct the appropriate
  sideband packets for transmission over the sideband interface.
*/

module UC_sb_FDI_Packer #(
    parameter int P_IN_W = 32   // FDI chunk width: 8 / 16 / 32
)(
    // -----------------------------------------------------------------------
    //  Inputs
    // -----------------------------------------------------------------------
    input  logic               i_clk,           // clock
    input  logic               i_rst_n,         // async active-low HW reset
    input  logic [P_IN_W-1:0]  i_lp_cfg,        // incoming chunk from Protocol Layer
    input  logic               i_lp_cfg_valid,  // chunk valid
    input  logic               i_full,          // FDI FIFO full flag
    input  logic [4:0]         i_opcode,        // request opcode (phase-0 bits [4:0])
    input  logic               i_init,          // active-low SW reset

    // -----------------------------------------------------------------------
    //  Outputs
    // -----------------------------------------------------------------------
    output logic [127:0]       o_data_in,          // assembled 128-bit packet → FIFO
    output logic               o_wr_en,            // push enable (1-cycle pulse)
    output logic               o_is_config,        // decoded: configuration access
    output logic               o_read_req,         // decoded: read request (write = ~o_read_req)
    output logic               o_operation_32bit,  // decoded: 32-bit operation   ← ADDED
    output logic [4:0]         o_comp_opcode,      // decoded completion opcode
    output logic               o_fifo_overflow,    // overflow pulse (FIFO was full)
    output logic               o_opcode_error      // invalid / unsupported opcode pulse
);

// ===========================================================================
//  Inlined contents of UC_sb_block_pkg
// ===========================================================================

    // --- FSM states ---
    typedef enum logic [1:0] {
        S_IDLE    = 2'b00,
        S_COLLECT = 2'b01,
        S_PUSH    = 2'b10
    } fdi_state_e;

    // --- Decode result struct (extended with is_32bit) ---
    typedef struct packed {
        logic        valid;
        logic        is_read;
        logic        is_32bit;          // 32-bit operation flag  ← NEW
        logic        is_conf;
        logic [6:0]  data_bits;         // payload bits: 0 / 32 / 64
        logic [4:0]  completion_opcode;
    } fdi_dec_t;

    // --- Opcode constants ---
    localparam logic [4:0] FDI_OP_MEM_RD_32    = 5'b00000;
    localparam logic [4:0] FDI_OP_MEM_WR_32    = 5'b00001;
    localparam logic [4:0] FDI_OP_CFG_RD_32    = 5'b00100;
    localparam logic [4:0] FDI_OP_CFG_WR_32    = 5'b00101;
    localparam logic [4:0] FDI_OP_MEM_RD_64    = 5'b01000;
    localparam logic [4:0] FDI_OP_MEM_WR_64    = 5'b01001;
    localparam logic [4:0] FDI_OP_CFG_RD_64    = 5'b01100;
    localparam logic [4:0] FDI_OP_CFG_WR_64    = 5'b01101;
    localparam logic [4:0] FDI_OP_COMP_NO_DATA = 5'b10000;
    localparam logic [4:0] FDI_OP_COMP_32_DATA = 5'b10001;
    localparam logic [4:0] FDI_OP_COMP_64_DATA = 5'b11001;

    // --- Opcode decode function ---
    function automatic fdi_dec_t fdi_decode_opcode(input logic [4:0] op);
        fdi_dec_t r;
        r = '0;
        unique case (op)

            // 32-bit Memory / Config READ  (no payload → 64-bit packet)
            FDI_OP_MEM_RD_32,
            FDI_OP_CFG_RD_32: begin
                r.valid             = 1'b1;
                r.is_read           = 1'b1;
                r.is_32bit          = 1'b1;
                r.is_conf           = (op == FDI_OP_CFG_RD_32);
                r.data_bits         = 7'd0;
                r.completion_opcode = FDI_OP_COMP_32_DATA;
            end

            // 64-bit Memory / Config READ  (no payload → 64-bit packet)
            FDI_OP_MEM_RD_64,
            FDI_OP_CFG_RD_64: begin
                r.valid             = 1'b1;
                r.is_read           = 1'b1;
                r.is_32bit          = 1'b0;
                r.is_conf           = (op == FDI_OP_CFG_RD_64);
                r.data_bits         = 7'd0;
                r.completion_opcode = FDI_OP_COMP_64_DATA;
            end

            // 32-bit Memory / Config WRITE  (32-bit payload → 128-bit packet)
            FDI_OP_MEM_WR_32,
            FDI_OP_CFG_WR_32: begin
                r.valid             = 1'b1;
                r.is_read           = 1'b0;
                r.is_32bit          = 1'b1;
                r.is_conf           = (op == FDI_OP_CFG_WR_32);
                r.data_bits         = 7'd32;
                r.completion_opcode = FDI_OP_COMP_NO_DATA;
            end

            // 64-bit Memory / Config WRITE  (64-bit payload → 128-bit packet)
            FDI_OP_MEM_WR_64,
            FDI_OP_CFG_WR_64: begin
                r.valid             = 1'b1;
                r.is_read           = 1'b0;
                r.is_32bit          = 1'b0;
                r.is_conf           = (op == FDI_OP_CFG_WR_64);
                r.data_bits         = 7'd64;
                r.completion_opcode = FDI_OP_COMP_NO_DATA;
            end

            // Unsupported opcode (including completion opcodes as inputs)
            default: begin
                r.valid = 1'b0;
            end
        endcase
        return r;
    endfunction

// ===========================================================================
//  Internal signals
// ===========================================================================

    fdi_dec_t     w_dec;            // combinational decode of current i_opcode
    logic [8:0]   w_tgt_bits;       // target bits = 64 (header) + data_bits

    fdi_state_e   r_state;
    fdi_dec_t     r_dec_lat;        // latched decode for the packet being assembled
    logic [127:0] r_sb_packet;      // packet accumulator
    logic [8:0]   r_bit_cnt;        // bits collected so far
    logic [8:0]   r_target_bits;    // target bits for this packet

    logic r_wr_en;
    logic r_fifo_overflow;
    logic r_opcode_error;

// ===========================================================================
//  Append-chunk helper function
// ===========================================================================

    function automatic logic [127:0] append_bits(
        input logic [127:0]      i_current,
        input logic [P_IN_W-1:0] i_chunk,
        input logic [8:0]        i_position
    );
        logic [127:0] s_next;
        s_next = i_current;
        s_next[i_position +: P_IN_W] = i_chunk;
        return s_next;
    endfunction

// ===========================================================================
//  Combinational decode of incoming opcode
// ===========================================================================

    always_comb begin : comb_decode
        w_dec      = fdi_decode_opcode(i_opcode);
        w_tgt_bits = 9'(64 + w_dec.data_bits);
    end

// ===========================================================================
//  Combinational outputs  (driven from latched decode of current packet)
// ===========================================================================

    always_comb begin : comb_outputs
        o_data_in         = r_sb_packet;
        o_is_config       = r_dec_lat.is_conf;
        o_read_req        = r_dec_lat.is_read;
        o_operation_32bit = r_dec_lat.is_32bit;       // ← ADDED
        o_comp_opcode     = r_dec_lat.completion_opcode;
        o_wr_en           = r_wr_en;
        o_fifo_overflow   = r_fifo_overflow;
        o_opcode_error    = r_opcode_error;
    end

// ===========================================================================
//  FSM  (sequential)
// ===========================================================================

    always_ff @(posedge i_clk or negedge i_rst_n) begin : seq_fsm

        // ----- HW reset (async) -----
        if (!i_rst_n) begin
            r_state         <= S_IDLE;
            r_dec_lat       <= '0;
            r_sb_packet     <= '0;
            r_bit_cnt       <= '0;
            r_target_bits   <= '0;
            r_wr_en         <= 1'b0;
            r_fifo_overflow <= 1'b0;
            r_opcode_error  <= 1'b0;
        end

        // ----- SW reset (sync) -----
        else if (!i_init) begin
            r_state         <= S_IDLE;
            r_dec_lat       <= '0;
            r_sb_packet     <= '0;
            r_bit_cnt       <= '0;
            r_target_bits   <= '0;
            r_wr_en         <= 1'b0;
            r_fifo_overflow <= 1'b0;
            r_opcode_error  <= 1'b0;
        end

        // ----- Normal operation -----
        else begin
            // Clear single-cycle pulses every cycle
            r_wr_en         <= 1'b0;
            r_fifo_overflow <= 1'b0;
            r_opcode_error  <= 1'b0;

            unique case (r_state)

                // -----------------------------------------------------------
                //  IDLE – wait for first valid chunk
                // -----------------------------------------------------------
                S_IDLE: begin
                    if (i_lp_cfg_valid) begin
                        if (!w_dec.valid) begin
                            // Invalid opcode → raise error, stay in IDLE
                            r_opcode_error <= 1'b1;
                            r_state        <= S_IDLE;
                        end else begin
                            // Latch the decoded fields for this packet
                            r_dec_lat     <= w_dec;
                            r_target_bits <= w_tgt_bits;

                            // Place the first chunk at bit position 0
                            r_sb_packet             <= '0;
                            r_sb_packet[P_IN_W-1:0] <= i_lp_cfg;
                            r_bit_cnt               <= 9'(P_IN_W);

                            // If first chunk already covers the whole packet, go straight to PUSH
                            if (P_IN_W >= w_tgt_bits)
                                r_state <= S_PUSH;
                            else
                                r_state <= S_COLLECT;
                        end
                    end
                end

                // -----------------------------------------------------------
                //  COLLECT – accumulate remaining chunks
                // -----------------------------------------------------------
                S_COLLECT: begin
                    if (i_lp_cfg_valid) begin
                        r_sb_packet <= append_bits(r_sb_packet, i_lp_cfg, r_bit_cnt);
                        r_bit_cnt   <= r_bit_cnt + 9'(P_IN_W);

                        if ((r_bit_cnt + 9'(P_IN_W)) >= r_target_bits)
                            r_state <= S_PUSH;
                    end
                end

                // -----------------------------------------------------------
                //  PUSH – write assembled packet to FDI FIFO
                // -----------------------------------------------------------
                S_PUSH: begin
                    if (!i_full) begin
                        r_wr_en <= 1'b1;         // one-cycle write-enable pulse
                    end else begin
                        r_fifo_overflow <= 1'b1; // FIFO full → signal overflow
                    end
                    r_state <= S_IDLE;
                end

                default: begin
                    r_state <= S_IDLE;
                end

            endcase
        end
    end

endmodule
