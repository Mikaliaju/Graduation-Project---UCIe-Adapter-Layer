// =================================================================================================
//  FILENAME    : Packer.sv
//  MODULE      : Packer
//  PROJECT     : UCIe 3.0 Adapter Layer
//  AUTHOR      : Ali Noureldin Abdelaziz
// =================================================================================================
//  DESCRIPTION :
//    The Packer operates in the transmit path and is responsible for constructing outgoing flits.
//    It receives payload data from the protocol layer through the FDI interface and assembles
//    the full 256B flit including Flit Header, Payload, DLLP bytes, Reserved bytes, and CRC.
//
//  FUNCTIONALITY :
//    - Receives 512-bit (64B) chunks from FDI over 4 cycles and stores in flit buffer.
//    - After collecting all 4 chunks, feeds complete flit to CRC_Generator chunk by chunk.
//    - Chunk 3 sent to CRC_Gen is masked: payload + FH + DLP + Reserved (real), CRC fields = 0.
//    - Waits for CRC_Generator crc_valid, then inserts CRC0/CRC1 into flit buffer.
//    - Transmits final complete flit to RDI interface chunk by chunk.
// =================================================================================================

import Mainband_pkg::*;
module Packer (
  // -------------------------
  // Clock & Reset
  // -------------------------
  input  logic                    i_clk,
  input  logic                    i_rst_n,
  // -------------------------
  // FDI Interface (Inputs)
  // -------------------------
  input  logic                    i_lp_irdy_fdi,        // Protocol layer ready to send data
  input  logic                    i_lp_valid_fdi,       // Data from FDI is valid
  input  logic    [DATA_PATH-1:0] i_lp_data_fdi,        // 512-bit payload from Protocol Layer
  input  logic    [31:0]          i_lp_dllp,            // DLLP / optimized flow control info
  input  logic                    i_lp_dllp_valid,      // DLLP data is valid
  input  logic                    i_lp_dllp_ofc,        // DLLP carries optimized flow control
  input  logic    [7:0]           i_lp_stream,          // [2]=SID, [1:0]=PID
  // -------------------------
  // Retry Interface (Inputs)
  // -------------------------
  input  logic    [7:0]           i_seq_num,            // Sequence number for current flit
  input  logic    [1:0]           i_replay_command,     // Replay control command
  input  logic                    i_deassert_trdy,      // Deassert ready during retry
  input  logic    [DATA_PATH-1:0] i_retry_data,         // Payload from retry buffer during replay
  input  logic                    i_retry_sid,          // Stack ID from retry buffer
  input  logic    [1:0]           i_retry_pid,          // Protocol ID from retry buffer
  input  logic                    i_buffer_empty,       // Retry buffer is empty
  input  logic                    i_retry_use,       // Enable using retry
  // -------------------------
  // LSM Interface (Inputs)
  // -------------------------
  input  logic                    i_packer_en,          // Enable packer operation
  input  logic                    i_flit_boundary,      // Clean flit boundary
  input  logic                    i_flush,              // Empty retry buffer 
  input  logic                    i_drain,              // Empty retry buffer but in normal operation
  // -------------------------
  // RDI Interface (Inputs)
  // -------------------------
  input  logic                    i_pl_trdy,            // PHY/RDI ready to accept flit
  // -------------------------
  // FDI Interface (Outputs)
  // -------------------------
  output logic                    o_pl_trdy_fdi,        // Adapter ready to receive from FDI
  // -------------------------
  // Retry Interface (Outputs)
  // -------------------------
  output logic  [DATA_PATH-1:0]   o_buffer_data,        // Payload stored for possible retry
  output logic  [PROTOCOL_ID-1:0] o_buffer_pid,         // Protocol ID for retry buffer
  output logic                    o_buffer_sid,         // Stack ID for retry buffer
  // -------------------------
  // LSM Interface (Outputs)
  // ------------------------- 
  output logic                    o_flit_boundary_done, // Clean boundary complet
  output logic                    o_flush_done,         // Assert after flash complete 
  output logic                    o_drain_done,         // Assert after drain complete
  // -------------------------
  // RDI Interface (Outputs)
  // -------------------------
  output logic    [DATA_PATH-1:0] o_lp_data_rdi,        // Complete flit sent to RDI (64B/cycle)
  output logic                    o_lp_valid_rdi,       // Flit data to RDI is valid
  output logic                    o_lp_irdy_rdi         // Packer ready to transmit to RDI
);

// =============================================================================
// Internal Signals
// =============================================================================

logic [1:0]               r_collect_cnt;           // Count num of chunk received from FDI or retry buffer
logic [1:0]               r_feed_cnt;              // Count num of chunk send to crc_generator
logic [1:0]               r_send_cnt;              // Count num of chunk send to RDI 
logic [3:0]               r_nop_chunk;             // NOP tracking ? one bit per chunk (1 = NOP, 0 = real data)  

// Retry signals
logic [FLIT_BITS-1:0]     r_flit_buf;              // Main buffer store flit after collect then send it
logic [PROTOCOL_ID-1:0]   r_pid;                   // Extract protocol id from lp_stream
logic                     r_sid;                   // Extract stack id from lp_stream
logic [SEQUENS_NUM-1:0]   r_seq_num;               // Sequence num from retry
logic [REPLAY_CMD-1:0]    r_replay_cmd;            // Replay command (ACK OR NAK) from retry

// DLLP information
logic [DLLP-1:0]          r_dllp_buf;              // Store dllp from fdi 
logic                     r_dllp_valid;            // Valid dllp data
logic                     r_dllp_ofc;              // Store at FH_B0 at bit4

// Pending command flags ? latched when command arrives mid-flit
logic                     r_flit_boundary_pending;
logic                     r_drain_pending;
logic                     r_flush_pending;

// CRC Generator connections
logic [CRC_SIZE-1:0]      w_crc0_gen;              // CRC value calculated for the first 128 bytes.
logic [CRC_SIZE-1:0]      w_crc1_gen;              // CRC value calculated for the second CRC.
logic                     w_crc_valid;             // Indicates that CRC calculation is complete and valid.
logic [DATA_PATH-1:0]     r_crc_payload;           // Flit data excluding CRC fields 64B per clock.
logic                     r_crc_payload_valid;     // Indicates valid data for CRC.

// Headear signals
logic [FLIT_HEADER-1:0]   w_fh_b0;                 // Collect flit header first byte (pid,sid,dllp_ofc,seq[7:4])
logic [FLIT_HEADER-1:0]   w_fh_b1;                 // Collect flit header second byte (replay_cmd,seq[3:0])
logic [DATA_PATH-1:0]     w_chunk3_masked;         // chunk3 after adding header ,reserved and dllp but crc=0

packer_state_e r_state;                            // packer state

// =============================================================================
// CRC Generator Instantiation
// =============================================================================
CRC_Generator U1 (
  .i_clk               (i_clk),
  .i_rst_n             (i_rst_n),
  .i_crc_payload_valid (r_crc_payload_valid),
  .i_crc_payload       (r_crc_payload),
  .o_crc0_gen          (w_crc0_gen),
  .o_crc1_gen          (w_crc1_gen),
  .o_crc_valid         (w_crc_valid)
);

// =============================================================================
// Flit Header Assembly (Combinational)
// =============================================================================
// FH_B0 : [7:6]=PID  [5]=SID  [4]=OFC  [3:0]=SEQ[7:4]
// FH_B1 : [7:6]=Flit_Type(00b)  [5:4]=Ack/Nak  [3:0]=SEQ[3:0]
always_comb begin
  w_fh_b0 = {r_pid, r_sid, r_dllp_ofc, r_seq_num[7:4]};
  w_fh_b1 = {2'b00, r_replay_cmd, r_seq_num[3:0]};
end

// =============================================================================
// Chunk 3 Masked ? for CRC_Generator input (Combinational)
// =============================================================================
always_comb begin
  w_chunk3_masked               = '0;                                     // all zeors
  w_chunk3_masked[351:0]        = r_flit_buf[C3_ABS+351 : C3_ABS];        // 44B payload
  w_chunk3_masked[C3_FH_B0+:8]  = r_nop_chunk[3] ? 8'h0 : w_fh_b0;        // FH if real data
  w_chunk3_masked[C3_FH_B1+:8]  = r_nop_chunk[3] ? 8'h0 : w_fh_b1;        // FH if real data
  w_chunk3_masked[C3_DLP+:32]   = r_dllp_valid   ? r_dllp_buf : 32'h0;    // DLP or zeros
  w_chunk3_masked[C3_RSV+:80]   = 80'h0;                                  // Reserved = 0
  w_chunk3_masked[C3_CRC0+:16]  = 16'h0;                                  // excluded from CRC
  w_chunk3_masked[C3_CRC1+:16]  = 16'h0;                                  // excluded from CRC
end

// =============================================================================
// Retry Buffer Outputs (Combinational)
// =============================================================================
always_comb begin
  o_buffer_data = i_lp_data_fdi;
  o_buffer_pid  = i_lp_stream[1:0];
  o_buffer_sid  = i_lp_stream[4];
end

// =============================================================================
// Main FSM (Sequential)
// =============================================================================
always_ff @(posedge i_clk or negedge i_rst_n) begin
  if (!i_rst_n) begin
    r_state                 <= S_IDLE;
    r_collect_cnt           <= 2'd0;
    r_feed_cnt              <= 2'd0;
    r_send_cnt              <= 2'd0;
    r_flit_buf              <= '0;
    r_pid                   <= '0;
    r_sid                   <= '0;
    r_seq_num               <= '0;
    r_replay_cmd            <= '0;
    r_dllp_buf              <= '0;
    r_dllp_valid            <= 1'b0;
    r_dllp_ofc              <= 1'b0;
    r_nop_chunk             <= 4'b0000;
    r_flit_boundary_pending <= 1'b0;
    r_drain_pending         <= 1'b0;
    r_flush_pending         <= 1'b0;
    r_crc_payload           <= '0;
    r_crc_payload_valid     <= 1'b0;
    o_lp_data_rdi           <= '0;
    o_lp_valid_rdi          <= 1'b0;
    o_lp_irdy_rdi           <= 1'b0;
    o_pl_trdy_fdi           <= 1'b0;
    o_flit_boundary_done    <= 1'b0;
    o_drain_done            <= 1'b0;
    o_flush_done            <= 1'b0;
  end
  else begin
    r_crc_payload_valid  <= 1'b0;
    o_lp_valid_rdi       <= 1'b0;
    o_flit_boundary_done <= 1'b0;
    o_drain_done         <= 1'b0;
    o_flush_done         <= 1'b0;

    // Latch pending commands when they arrive mid-flit
    if (i_flit_boundary) r_flit_boundary_pending <= 1'b1;
    if (i_drain)         r_drain_pending         <= 1'b1;
    if (i_flush)         r_flush_pending         <= 1'b1;

    case (r_state)

      // =====================================================================
      // S_IDLE : Wait for LSM enable
      // =====================================================================
      S_IDLE: begin
        r_collect_cnt           <= 2'd0;
        r_feed_cnt              <= 2'd0;
        r_send_cnt              <= 2'd0;
        o_lp_valid_rdi          <= 1'b0;
        o_lp_irdy_rdi           <= 1'b0;
        o_pl_trdy_fdi           <= 1'b0;
        r_flit_buf              <= '0;
        r_dllp_valid            <= 1'b0;
        r_flit_boundary_pending <= 1'b0;
        r_drain_pending         <= 1'b0;
        r_flush_pending         <= 1'b0;

        if (i_packer_en) begin
          if (i_flush)
            r_state <= S_FLUSH;
          else if (i_drain)
            r_state <= S_DRAIN;
          else begin
            o_pl_trdy_fdi <= 1'b1;
            r_state       <= S_COLLECT;
          end
        end
      end
      // =====================================================================
      // S_COLLECT : Receive 4 x 64B chunks -> store in flit buffer
      //   Retry mode  : data from retry block directly (no FDI handshake)
      //   Normal mode : wait for FDI handshake
      //   NOP data    : lp_valid = 0 -> zeros, no FH
      //   NOP DLLP    : lp_dllp_valid = 0 -> DLP = zeros
      // =====================================================================
      S_COLLECT: begin
        if (i_drain || i_flush || !i_packer_en) begin
          o_pl_trdy_fdi <= 1'b0;
          r_state       <= S_IDLE;
        end
        // ---- Retry mode ----
        else if (i_retry_use  && i_deassert_trdy) begin
          r_nop_chunk[r_collect_cnt]                            <= 1'b0;
          r_flit_buf[r_collect_cnt * DATA_PATH +: DATA_PATH]    <= i_retry_data;
          r_pid                                                 <= i_retry_pid;
          r_sid                                                 <= i_retry_sid;
          // DLLP always from FDI even in replay
          if (i_lp_dllp_valid) begin
            r_dllp_buf   <= i_lp_dllp;
            r_dllp_valid <= 1'b1;
            r_dllp_ofc   <= i_lp_dllp_ofc;
          end
          else begin
            r_dllp_buf   <= 32'h0;
            r_dllp_valid <= 1'b0;
            r_dllp_ofc   <= 1'b0;
          end

          if (r_collect_cnt == 2'd0) begin
            r_seq_num    <= i_seq_num;
            r_replay_cmd <= i_replay_command;
          end
          if (r_collect_cnt == 2'd3) begin
            r_collect_cnt <= 2'd0;
            o_pl_trdy_fdi <= 1'b0;
            r_state       <= S_FEED_CRC;
          end
          else begin
            r_collect_cnt <= r_collect_cnt + 1'b1;
          end
        end

        // ---- Normal mode ----
        else if (i_lp_irdy_fdi && !i_deassert_trdy) begin
          // Data: Real or NOP
          if (i_lp_valid_fdi) begin
            r_nop_chunk[r_collect_cnt]                            <= 1'b0;
            r_flit_buf[r_collect_cnt * DATA_PATH +: DATA_PATH]    <= i_lp_data_fdi;
            r_pid                                                 <= i_lp_stream[1:0];
            r_sid                                                 <= i_lp_stream[5];
          end
          else begin
            r_nop_chunk[r_collect_cnt]                            <= 1'b1;
            r_flit_buf[r_collect_cnt * DATA_PATH +: DATA_PATH]    <= '0;
          end

          // DLLP: Real or NOP
          if (i_lp_dllp_valid) begin
            r_dllp_buf   <= i_lp_dllp;
            r_dllp_valid <= 1'b1;
            r_dllp_ofc   <= i_lp_dllp_ofc;
          end
          else begin
            r_dllp_buf   <= 32'h0;
            r_dllp_valid <= 1'b0;
            r_dllp_ofc   <= 1'b0;
          end

          if (r_collect_cnt == 2'd0) begin
            r_seq_num    <= i_seq_num;
            r_replay_cmd <= i_replay_command;
          end
          if (r_collect_cnt == 2'd3) begin
            r_collect_cnt <= 2'd0;
            o_pl_trdy_fdi <= 1'b0;
            r_state       <= S_FEED_CRC;
          end
          else begin
            r_collect_cnt <= r_collect_cnt + 1'b1;
          end
        end
      end

      // =====================================================================
      // S_FEED_CRC : Feed flit to CRC_Generator, 64B per cycle
      //   Cycles 0-2 : raw payload chunks from flit buffer
      //   Cycle  3   : masked chunk 3 (FH+DLP+RSV real, CRC fields = 0)
      // =====================================================================
      S_FEED_CRC: begin
        if (r_feed_cnt == 2'd3) begin
          r_crc_payload       <= w_chunk3_masked;
          r_crc_payload_valid <= 1'b1;
          r_feed_cnt          <= 2'd0;
          r_state             <= S_WAIT_CRC;
        end
        else begin
          r_crc_payload       <= r_flit_buf[r_feed_cnt * DATA_PATH +: DATA_PATH];
          r_crc_payload_valid <= 1'b1;
          r_feed_cnt          <= r_feed_cnt + 1'b1;
        end
      end

      // =====================================================================
      // S_WAIT_CRC : Wait for CRC_Generator to finish
      //   On crc_valid -> insert FH (if real), DLP, Reserved, CRC0, CRC1
      // =====================================================================
      S_WAIT_CRC: begin
        if (w_crc_valid) begin
          r_flit_buf[C3_ABS + C3_FH_B0 +: 8]  <= r_nop_chunk[3] ? 8'h0 : w_fh_b0;
          r_flit_buf[C3_ABS + C3_FH_B1 +: 8]  <= r_nop_chunk[3] ? 8'h0 : w_fh_b1;
          r_flit_buf[C3_ABS + C3_DLP   +: 32] <= r_dllp_valid   ? r_dllp_buf : 32'h0;
          r_flit_buf[C3_ABS + C3_RSV   +: 80] <= 80'h0;
          r_flit_buf[C3_ABS + C3_CRC0  +: 16] <= w_crc0_gen;
          r_flit_buf[C3_ABS + C3_CRC1  +: 16] <= w_crc1_gen;

          r_send_cnt    <= 2'd0;
          o_lp_irdy_rdi <= 1'b1;
          r_state       <= S_SEND;
        end
      end

      // =====================================================================
      // S_SEND : Transmit complete flit to RDI, 64B per cycle (4 cycles)
      // =====================================================================
      S_SEND: begin
        if (i_pl_trdy) begin
          o_lp_data_rdi  <= r_flit_buf[r_send_cnt * DATA_PATH +: DATA_PATH];
          o_lp_valid_rdi <= 1'b1;

          if (r_send_cnt == 2'd3) begin
            o_lp_irdy_rdi  <= 1'b0;
            o_lp_valid_rdi <= 1'b0;
            r_state        <= S_DONE;
          end
          else begin
            r_send_cnt <= r_send_cnt + 1'b1;
          end
        end
      end

      // =====================================================================
      // S_DONE : Assert clean_boundary, check for pending commands
      // =====================================================================
      S_DONE: begin
        o_flit_boundary_done <= 1'b1;
        r_dllp_valid         <= 1'b0;
        r_flit_buf           <= '0;
        r_nop_chunk          <= 4'b0000;

        // Priority: flit_boundary > drain > flush > normal
        if (r_flit_boundary_pending || i_flit_boundary) begin
          r_flit_boundary_pending <= 1'b0;
          r_state                 <= S_FLIT_BOUNDARY;
        end
        else if (r_drain_pending || i_drain) begin
          r_drain_pending <= 1'b0;
          r_state         <= S_DRAIN;
        end
        else if (r_flush_pending || i_flush) begin
          r_flush_pending <= 1'b0;
          r_state         <= S_FLUSH;
        end
        else if (i_packer_en) begin
          r_collect_cnt <= 2'd0;
          o_pl_trdy_fdi <= 1'b1;
          r_state       <= S_COLLECT;
        end
        else begin
          r_state <= S_IDLE;
        end
      end

      // =====================================================================
      // S_FLIT_BOUNDARY : Current flit already sent in S_SEND
      //   -> Deassert pl_trdy, assert flit_boundary_done, wait for tx disable
      // =====================================================================
      S_FLIT_BOUNDARY: begin
        o_pl_trdy_fdi        <= 1'b0;
        o_flit_boundary_done <= 1'b1;
        r_state              <= S_IDLE;
      end

      // =====================================================================
      // S_DRAIN : Send all data normally with replay enabled until buffer empty
      //   -> Deassert pl_trdy, continue normal operation, assert drain_done
      // =====================================================================
      S_DRAIN: begin
        o_pl_trdy_fdi <= 1'b0;   // Stop accepting new FDI data

        if (i_buffer_empty) begin
          o_drain_done <= 1'b1;
          r_state      <= S_IDLE;
        end
        else begin
          // Continue sending flits from retry buffer with replay enabled
          r_collect_cnt <= 2'd0;
          r_state       <= S_COLLECT;
        end
      end

      // =====================================================================
      // S_FLUSH : Send retry buffer data with retry off and valid on
      //   -> Deassert pl_trdy, send buffer contents, assert flush_done
      // =====================================================================
      S_FLUSH: begin
        o_pl_trdy_fdi <= 1'b0;   // Stop accepting new FDI data

        if (i_buffer_empty) begin
          o_flush_done <= 1'b1;
          r_state      <= S_IDLE;
        end
        else begin
          // Send from retry buffer with replay off, valid on
          r_nop_chunk[r_collect_cnt]                            <= 1'b0;
          r_flit_buf[r_collect_cnt * DATA_PATH +: DATA_PATH]    <= i_retry_data;
          r_pid                                                 <= i_retry_pid;
          r_sid                                                 <= i_retry_sid;
          r_dllp_buf                                            <= 32'h0;
          r_dllp_valid                                          <= 1'b0;
          r_dllp_ofc                                            <= 1'b0;

          if (r_collect_cnt == 2'd0) begin
            r_seq_num    <= i_seq_num;
            r_replay_cmd <= 2'b00;   // replay OFF during flush
          end

          if (r_collect_cnt == 2'd3) begin
            r_collect_cnt <= 2'd0;
            r_state       <= S_FEED_CRC;
          end
          else begin
            r_collect_cnt <= r_collect_cnt + 1'b1;
          end
        end
      end

      default: r_state <= S_IDLE;

    endcase
  end
end

endmodule

