// =================================================================================================
//  FILENAME    : UC_MB_Packer.sv
//  MODULE      : UC_MB_Packer
//  PROJECT     : UCIe 3.0 Adapter Layer
//  AUTHOR      : Ali Noureldin Abdelaziz
// =================================================================================================
//  DESCRIPTION :
//    The Packer operates in the transmit path and is responsible for constructing outgoing flits.
//    It receives payload data from the protocol layer through the FDI interface and assembles
//    the full 256B flit including Flit Header, Payload, DLLP bytes, Reserved bytes, and CRC.
//
//  FUNCTIONALITY :
//    - Receives 4 x 64B chunks from FDI and feeds CRC_Generator in parallel (same cycle).
//    - Chunks 0,1,2 forwarded raw to RDI with 1-cycle pipeline delay.
//    - Chunk 3 is held ? on cycle 5 FH + DLP + Reserved + CRC0 + CRC1 are inserted then sent.
//    - Total latency: 5 cycles per flit.
//    - Supports NOP data, NOP DLLP, retry mode, flush, drain, flit_boundary.
//
//  Timing:
//    Cycle 1 : receive chunk0 -> feed CRC_Gen
//    Cycle 2 : receive chunk1 -> feed CRC_Gen | send chunk0 to RDI
//    Cycle 3 : receive chunk2 -> feed CRC_Gen | send chunk1 to RDI
//    Cycle 4 : receive chunk3 -> feed CRC_Gen masked | send chunk2 to RDI
//    Cycle 5 : CRC ready -> insert FH+DLP+RSV+CRC into chunk3 -> send chunk3 to RDI
// =================================================================================================

import UC_MB_Mainband_pkg::*;
module UC_MB_Packer (
  // -------------------------
  // Clock & Reset
  // -------------------------
  input  logic                    i_clk,
  input  logic                    i_rst_n,
  input  logic                    i_init,
  // -------------------------
  // FDI Interface (Inputs)
  // -------------------------
  input  logic                    i_lp_irdy_fdi,        // Protocol layer ready to send data
  input  logic                    i_lp_valid_fdi,       // Data from FDI is valid
  input  logic  [DATA_PATH-1:0]   i_lp_data_fdi,        // 512-bit payload from Protocol Layer
  input  logic  [DLLP-1:0]        i_lp_dllp,            // DLLP / optimized flow control info
  input  logic                    i_lp_dllp_valid,      // DLLP data is valid
  input  logic                    i_lp_dllp_ofc,        // DLLP carries optimized flow control
  input  logic  [7:0]             i_lp_stream,          // [2]=SID, [1:0]=PID
  // -------------------------
  // Retry Interface (Inputs)
  // -------------------------
  input  logic  [SEQUENS_NUM-1:0] i_seq_num,            // Sequence number for current flit
  input  logic  [REPLAY_CMD-1:0]  i_replay_command,     // Replay control command
  input  logic                    i_deassert_trdy,      // Deassert ready during retry
  input  logic  [DATA_PATH-1:0]   i_retry_data,         // Payload from retry buffer during replay
  input  logic                    i_retry_sid,          // Stack ID from retry buffer
  input  logic  [PROTOCOL_ID-1:0] i_retry_pid,          // Protocol ID from retry buffer
  input  logic                    i_buffer_empty,       // Retry buffer is empty
  input  logic                    i_retry_use,          // Enable using retry
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
  output logic  [DATA_PATH-1:0]   o_lp_data_rdi,        // Complete flit sent to RDI (64B/cycle)
  output logic                    o_lp_valid_rdi,       // Flit data to RDI is valid
  output logic                    o_lp_irdy_rdi         // Packer ready to transmit to RDI
);

// =============================================================================
// Internal Signals
// =============================================================================

logic [1:0]               r_collect_cnt;           // Count num of chunk received from FDI or retry buffer 
logic [3:0]               r_nop_chunk;             // NOP tracking ? one bit per chunk (1 = NOP, 0 = real data)  

// Pipeline register for RDI (1-cycle delay)
//logic [DATA_PATH-1:0]     r_pipe_data;             // Make data delay for 1 cycle
//logic                     r_pipe_valid;

// Chunk 3 buffer (held until S_INSERT)
logic [DATA_PATH-1:0]     r_chunk3_buf;

// Retry signals
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

// =============================================================================
// Next State Signals (driven by always_comb)
// =============================================================================

logic [1:0]               w_nxt_collect_cnt;
logic [3:0]               w_nxt_nop_chunk;
logic [DATA_PATH-1:0]     w_nxt_chunk3_buf;
logic [PROTOCOL_ID-1:0]   w_nxt_pid;
logic                     w_nxt_sid;
logic [SEQUENS_NUM-1:0]   w_nxt_seq_num;
logic [REPLAY_CMD-1:0]    w_nxt_replay_cmd;
logic [DLLP-1:0]          w_nxt_dllp_buf;
logic                     w_nxt_dllp_valid;
logic                     w_nxt_dllp_ofc;
logic                     w_nxt_flit_boundary_pending;
logic                     w_nxt_drain_pending;
logic                     w_nxt_flush_pending;
logic [DATA_PATH-1:0]     w_nxt_crc_payload;
logic                     w_nxt_crc_payload_valid;

// Output next values
logic                     w_nxt_pl_trdy_fdi;
logic [DATA_PATH-1:0]     w_nxt_lp_data_rdi;
logic                     w_nxt_lp_valid_rdi;
logic                     w_nxt_lp_irdy_rdi;
logic                     w_nxt_flit_boundary_done;
logic                     w_nxt_flush_done;
logic                     w_nxt_drain_done;

packer_state_e r_state;                            // packer state
packer_state_e w_nxt_state;                        // next state

function CRC_COLLECT_CASE();

  
endfunction

// =============================================================================
// CRC Generator Instantiation
// =============================================================================
UC_MB_CRC_Generator    U1_UC_MB_crc_gen (
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
  w_chunk3_masked[351:0]        = i_lp_data_fdi[351:0];
  // w_chunk3_masked[351:0]        = r_chunk3_buf[351:0];
  w_chunk3_masked[C3_FH_B0+:8]  = r_nop_chunk[3] ? 8'h0 : w_fh_b0;
  w_chunk3_masked[C3_FH_B1+:8]  = r_nop_chunk[3] ? 8'h0 : w_fh_b1;
  w_chunk3_masked[C3_DLP+:32]   = r_dllp_valid   ? r_dllp_buf : 32'h0;
  w_chunk3_masked[C3_RSV+:80]   = 80'h0;
  w_chunk3_masked[C3_CRC0+:16]  = 16'h0;
  w_chunk3_masked[C3_CRC1+:16]  = 16'h0;
end

// =============================================================================
// Retry Buffer Outputs (Combinational) only used retry buffer when use retry
// =============================================================================
always_comb begin
  if (!i_retry_use) begin
    o_buffer_data = i_lp_data_fdi;
    o_buffer_pid  = i_lp_stream[1:0];
    o_buffer_sid  = i_lp_stream[5];
  end
  else begin
    o_buffer_data = '0;                  // Don't send data to retry buffer when used retry
    o_buffer_pid  = '0;
    o_buffer_sid  = 1'b0;
  end
end

// =============================================================================
// FSM Combinational Block: Next State + Output Logic
// =============================================================================
always_comb begin
  // ------------------------------------------------------------------
  // Defaults: hold all registers, de-assert all pulse outputs
  // ------------------------------------------------------------------
  w_nxt_state                = r_state;
  w_nxt_collect_cnt          = r_collect_cnt;
  w_nxt_nop_chunk            = r_nop_chunk;
 //w_nxt_pipe_data            = r_pipe_data;
 // w_nxt_pipe_valid           = r_pipe_valid;
  w_nxt_chunk3_buf           = r_chunk3_buf;
  w_nxt_pid                  = r_pid;
  w_nxt_sid                  = r_sid;
  w_nxt_seq_num              = r_seq_num;
  w_nxt_replay_cmd           = r_replay_cmd;
  w_nxt_dllp_buf             = r_dllp_buf;
  w_nxt_dllp_valid           = r_dllp_valid;
  w_nxt_dllp_ofc             = r_dllp_ofc;
  w_nxt_flit_boundary_pending = r_flit_boundary_pending;
  w_nxt_drain_pending        = r_drain_pending;
  w_nxt_flush_pending        = r_flush_pending;
  w_nxt_crc_payload          = r_crc_payload;
  w_nxt_crc_payload_valid    = 1'b0;           // pulse: default de-asserted

  w_nxt_pl_trdy_fdi          = o_pl_trdy_fdi;
  w_nxt_lp_data_rdi          = o_lp_data_rdi;
  w_nxt_lp_valid_rdi         = 1'b0;           // pulse: default de-asserted
  w_nxt_lp_irdy_rdi          = o_lp_irdy_rdi;
  w_nxt_flit_boundary_done   = 1'b0;           // pulse: default de-asserted
  w_nxt_flush_done           = 1'b0;           // pulse: default de-asserted
  w_nxt_drain_done           = 1'b0;           // pulse: default de-asserted

  // Latch pending commands mid-flit
  if (i_flit_boundary) w_nxt_flit_boundary_pending = 1'b1;
  if (i_drain)         w_nxt_drain_pending         = 1'b1;
  if (i_flush)         w_nxt_flush_pending         = 1'b1;

  case (r_state)

    // =========================================================================
    // S_IDLE : Wait for LSM enable
    // =========================================================================
    S_IDLE: begin
      w_nxt_collect_cnt           = 2'd0;
      w_nxt_nop_chunk             = 4'b0000;
//      w_nxt_pipe_valid            = 1'b0;
      w_nxt_lp_irdy_rdi           = 1'b0;
      w_nxt_pl_trdy_fdi           = 1'b0;
      w_nxt_dllp_valid            = 1'b0;
      w_nxt_flit_boundary_pending = 1'b0;
      w_nxt_drain_pending         = 1'b0;
      w_nxt_flush_pending         = 1'b0;

      if (i_packer_en) begin
        if (i_flush) begin
          w_nxt_state      = S_FLUSH;
        end
        else if (i_drain) begin
          w_nxt_state = S_DRAIN;
        end
        else begin
          w_nxt_pl_trdy_fdi = 1'b1;
          w_nxt_lp_irdy_rdi = 1'b1;
          w_nxt_crc_payload       = i_lp_valid_fdi ? i_lp_data_fdi : '0;
          w_nxt_crc_payload_valid = i_lp_valid_fdi;
          w_nxt_state       = S_COLLECT;
        end
      end
    end

    // =========================================================================
    // S_COLLECT : Cycles 1-4
    //
    // Each cycle simultaneously:
    //   1) Receive chunk from FDI or retry buffer
    //   2) Feed chunk to CRC_Generator (chunk3 = masked)
    //   3) Send previous chunk to RDI (1-cycle pipeline delay, not chunk3)
    // =========================================================================
    S_COLLECT: begin
      if (!i_packer_en && !i_pl_trdy) begin
        w_nxt_pl_trdy_fdi = 1'b0;
        w_nxt_lp_irdy_rdi = 1'b0;
  //      w_nxt_pipe_valid  = 1'b0;
        w_nxt_state       = S_IDLE;
      end

      // Retry / Drain / Flush mode (data from retry buffer)
      else if (i_retry_use && !i_deassert_trdy) begin

        // 1) Receive from retry buffer
        w_nxt_nop_chunk[r_collect_cnt] = 1'b0;
        w_nxt_lp_data_rdi  = i_retry_data;
        w_nxt_lp_valid_rdi = 1'b1;

        if (r_collect_cnt == 2'd3) begin
          w_nxt_chunk3_buf = i_retry_data;
        end

        // DLLP always from FDI even in retry/drain/flush
        if (i_lp_dllp_valid) begin
          w_nxt_dllp_buf   = i_lp_dllp;
          w_nxt_dllp_valid = 1'b1;
          w_nxt_dllp_ofc   = i_lp_dllp_ofc;
        end
        else begin
          w_nxt_dllp_buf   = 32'h0;
          w_nxt_dllp_valid = 1'b0;
          w_nxt_dllp_ofc   = 1'b0;
        end

        if (r_collect_cnt == 2'd0) begin
          w_nxt_seq_num    = i_seq_num;
          w_nxt_replay_cmd = i_replay_command;
          w_nxt_pid        = i_retry_pid;
          w_nxt_sid        = i_retry_sid;
        end

        // 2) Feed CRC_Generator
        if (r_collect_cnt == 2'd3) begin
          w_nxt_crc_payload       = w_chunk3_masked;
          w_nxt_crc_payload_valid = 1'b1;
        end
        else begin
          w_nxt_crc_payload       = i_retry_data;
          w_nxt_crc_payload_valid = 1'b1;
        end

//          w_nxt_lp_data_rdi  = i_retey_data;
 //         w_nxt_lp_valid_rdi = 1'b1;

        if (r_collect_cnt == 2'd3) begin
          w_nxt_collect_cnt = 2'd0;
          w_nxt_state       = S_INSERT;
        end
        else begin
          w_nxt_collect_cnt = r_collect_cnt + 1'b1;
        end
      end

      // Normal mode (data from FDI)
      else if (i_lp_irdy_fdi && !i_deassert_trdy) begin

        // 1) Receive from FDI
        if (i_lp_valid_fdi) begin
          w_nxt_nop_chunk[r_collect_cnt] = 1'b0;
          w_nxt_pid                      = i_lp_stream[1:0];
          w_nxt_sid                      = i_lp_stream[5];
          if (r_collect_cnt == 2'd3) begin
            w_nxt_chunk3_buf = i_lp_data_fdi;
          end
        end
        else begin
          // NOP data
          w_nxt_nop_chunk[r_collect_cnt] = 1'b1;
          if (r_collect_cnt == 2'd3)
            w_nxt_chunk3_buf = '0;
        end

        // DLLP
        if (i_lp_dllp_valid) begin
          w_nxt_dllp_buf   = i_lp_dllp;
          w_nxt_dllp_valid = 1'b1;
          w_nxt_dllp_ofc   = i_lp_dllp_ofc;
        end
        else begin
          w_nxt_dllp_buf   = 32'h0;
          w_nxt_dllp_valid = 1'b0;
          w_nxt_dllp_ofc   = 1'b0;
        end

        if (r_collect_cnt == 2'd0) begin
          w_nxt_seq_num    = i_seq_num;
          w_nxt_replay_cmd = i_replay_command;
        end

        // 2) Feed CRC_Generator
        if (r_collect_cnt == 2'd3) begin
          w_nxt_crc_payload       = w_chunk3_masked;
          w_nxt_crc_payload_valid = 1'b1;
        end
        else begin
          w_nxt_crc_payload       = i_lp_valid_fdi ? i_lp_data_fdi : '0;
          w_nxt_crc_payload_valid = 1'b1;
        end

        w_nxt_lp_data_rdi  = i_lp_valid_fdi ? i_lp_data_fdi : '0;
        w_nxt_lp_valid_rdi = 1'b1;

       if (r_collect_cnt == 2'd3) begin
          w_nxt_lp_data_rdi  = i_lp_valid_fdi ? i_lp_data_fdi : '0;
          w_nxt_lp_valid_rdi = 1'b1;
       end
       
        if (r_collect_cnt == 2'd3) begin
          w_nxt_collect_cnt = 2'd0;
          w_nxt_pl_trdy_fdi = 1'b0;
          if (w_crc_valid) begin
            w_nxt_lp_data_rdi[351:0]       = i_lp_data_fdi[351:0];
            w_nxt_lp_data_rdi[C3_FH_B0+:8] = r_nop_chunk[3] ? 8'h0 : w_fh_b0;
            w_nxt_lp_data_rdi[C3_FH_B1+:8] = r_nop_chunk[3] ? 8'h0 : w_fh_b1;
            w_nxt_lp_data_rdi[C3_DLP+:32]  = r_dllp_valid   ? r_dllp_buf : 32'h0;
            w_nxt_lp_data_rdi[C3_RSV+:80]  = 80'h0;
            w_nxt_lp_data_rdi[C3_CRC0+:16] = w_crc0_gen;
            w_nxt_lp_data_rdi[C3_CRC1+:16] = w_crc1_gen;
            w_nxt_lp_valid_rdi             = 1'b1;
            w_nxt_state       = S_INSERT;
          end
        end
        else begin
          w_nxt_collect_cnt = r_collect_cnt + 1'b1;
        end
      end
    end

    // =========================================================================
    // S_INSERT : Cycle 5
    //   CRC ready -> insert FH + DLP + Reserved + CRC0 + CRC1 into chunk3
    //   Send final chunk3 to RDI
    // =========================================================================
    S_INSERT: begin
   //   w_nxt_pipe_valid  = 1'b0;
      // if (w_crc_valid) begin
      //   w_nxt_lp_data_rdi[351:0]       = r_chunk3_buf[351:0];
      //   w_nxt_lp_data_rdi[C3_FH_B0+:8] = r_nop_chunk[3] ? 8'h0 : w_fh_b0;
      //   w_nxt_lp_data_rdi[C3_FH_B1+:8] = r_nop_chunk[3] ? 8'h0 : w_fh_b1;
      //   w_nxt_lp_data_rdi[C3_DLP+:32]  = r_dllp_valid   ? r_dllp_buf : 32'h0;
      //   w_nxt_lp_data_rdi[C3_RSV+:80]  = 80'h0;
      //   w_nxt_lp_data_rdi[C3_CRC0+:16] = w_crc0_gen;
      //   w_nxt_lp_data_rdi[C3_CRC1+:16] = w_crc1_gen;
      //   w_nxt_lp_valid_rdi             = 1'b1;
      // end
        w_nxt_lp_irdy_rdi = 1'b0;
        w_nxt_nop_chunk   = 4'b0000;
        w_nxt_dllp_valid  = 1'b0;
        w_nxt_chunk3_buf  = '0;
        w_nxt_state                    = S_DONE;
    end

    // =========================================================================
    // S_DONE : Check pending commands, prepare for next flit
    // =========================================================================
    S_DONE: begin
      w_nxt_lp_irdy_rdi = 1'b0;
      w_nxt_nop_chunk   = 4'b0000;
      w_nxt_dllp_valid  = 1'b0;
      w_nxt_chunk3_buf  = '0;

      // Priority: flit_boundary > drain > flush > normal
      if (r_flit_boundary_pending || i_flit_boundary) begin
        w_nxt_flit_boundary_pending = 1'b0;
        w_nxt_state                 = S_FLIT_BOUNDARY;
      end
      else if (r_drain_pending || i_drain) begin
        w_nxt_drain_pending = 1'b0;
        w_nxt_state         = S_DRAIN;
      end
      else if (r_flush_pending || i_flush) begin
        w_nxt_flush_pending = 1'b0;
        w_nxt_state         = S_FLUSH;
      end
      else if (i_packer_en) begin
        w_nxt_collect_cnt = 2'd0;
        w_nxt_pl_trdy_fdi = 1'b1;
        w_nxt_lp_irdy_rdi = 1'b1;
        w_nxt_state       = S_COLLECT;
      end
      else begin
        w_nxt_state = S_IDLE;
      end
    end

    // =========================================================================
    // S_FLIT_BOUNDARY : Deassert trdy, assert done, go to IDLE
    // =========================================================================
    S_FLIT_BOUNDARY: begin
      w_nxt_pl_trdy_fdi        = 1'b0;
      w_nxt_lp_irdy_rdi        = 1'b0;
      w_nxt_flit_boundary_done = 1'b1;
      w_nxt_state              = S_IDLE;
    end

    // =========================================================================
    // S_DRAIN : Send retry buffer with replay enabled until buffer empty
    // =========================================================================
    S_DRAIN: begin
      w_nxt_pl_trdy_fdi = 1'b0;

      if (i_buffer_empty) begin
        w_nxt_drain_done = 1'b1;
        w_nxt_state      = S_IDLE;
      end
      else begin
        w_nxt_collect_cnt = 2'd0;
        w_nxt_lp_irdy_rdi = 1'b1;
        w_nxt_state       = S_COLLECT;
      end
    end

    // =========================================================================
    // S_FLUSH : Send retry buffer with replay OFF (replay_cmd forced = 00)
    // =========================================================================
    S_FLUSH: begin
      w_nxt_pl_trdy_fdi = 1'b0;

      if (i_buffer_empty) begin
        w_nxt_flush_done = 1'b1;
        w_nxt_state      = S_IDLE;
      end
      else begin
        w_nxt_collect_cnt = 2'd0;
        w_nxt_lp_irdy_rdi = 1'b1;
        w_nxt_state       = S_COLLECT;
      end
    end

    default: w_nxt_state = S_IDLE;

  endcase
end

// =============================================================================
// FSM Sequential Block: State & Register Updates
// =============================================================================
always_ff @(posedge i_clk or negedge i_rst_n) begin
  if (!i_rst_n) begin
    r_state                 <= S_IDLE;
    r_collect_cnt           <= 2'd0;
    r_nop_chunk             <= 4'b0000;
  //  r_pipe_data             <= '0;
  //  r_pipe_valid            <= 1'b0;
    r_chunk3_buf            <= '0;
    r_pid                   <= '0;
    r_sid                   <= 1'b0;
    r_seq_num               <= '0;
    r_replay_cmd            <= '0;
    r_dllp_buf              <= '0;
    r_dllp_valid            <= 1'b0;
    r_dllp_ofc              <= 1'b0;
    r_flit_boundary_pending <= 1'b0;
    r_drain_pending         <= 1'b0;
    r_flush_pending         <= 1'b0;
    r_crc_payload           <= '0;
    r_crc_payload_valid     <= 1'b0;
    o_pl_trdy_fdi           <= 1'b0;
    o_lp_data_rdi           <= '0;
    o_lp_valid_rdi          <= 1'b0;
    o_lp_irdy_rdi           <= 1'b0;
    o_flit_boundary_done    <= 1'b0;
    o_flush_done            <= 1'b0;
    o_drain_done            <= 1'b0;
  end
  else if (!i_init) begin
    r_state                 <= S_IDLE;
    r_collect_cnt           <= 2'd0;
    r_nop_chunk             <= 4'b0000;
   // r_pipe_data             <= '0;
   // r_pipe_valid            <= 1'b0;
    r_chunk3_buf            <= '0;
    r_pid                   <= '0;
    r_sid                   <= 1'b0;
    r_seq_num               <= '0;
    r_replay_cmd            <= '0;
    r_dllp_buf              <= '0;
    r_dllp_valid            <= 1'b0;
    r_dllp_ofc              <= 1'b0;
    r_flit_boundary_pending <= 1'b0;
    r_drain_pending         <= 1'b0;
    r_flush_pending         <= 1'b0;
    r_crc_payload           <= '0;
    r_crc_payload_valid     <= 1'b0;
    o_pl_trdy_fdi           <= 1'b0;
    o_lp_data_rdi           <= '0;
    o_lp_valid_rdi          <= 1'b0;
    o_lp_irdy_rdi           <= 1'b0;
    o_flit_boundary_done    <= 1'b0;
    o_flush_done            <= 1'b0;
    o_drain_done            <= 1'b0;
  end
  else begin
    // Latch next-state values computed by combinational block
    r_state                 <= w_nxt_state;
    r_collect_cnt           <= w_nxt_collect_cnt;
    r_nop_chunk             <= w_nxt_nop_chunk;
    //r_pipe_data             <= w_nxt_pipe_data;
    //r_pipe_valid            <= w_nxt_pipe_valid;
    r_chunk3_buf            <= w_nxt_chunk3_buf;
    r_pid                   <= w_nxt_pid;
    r_sid                   <= w_nxt_sid;
    r_seq_num               <= w_nxt_seq_num;
    r_replay_cmd            <= w_nxt_replay_cmd;
    r_dllp_buf              <= w_nxt_dllp_buf;
    r_dllp_valid            <= w_nxt_dllp_valid;
    r_dllp_ofc              <= w_nxt_dllp_ofc;
    r_flit_boundary_pending <= w_nxt_flit_boundary_pending;
    r_drain_pending         <= w_nxt_drain_pending;
    r_flush_pending         <= w_nxt_flush_pending;
    r_crc_payload           <= w_nxt_crc_payload;
    r_crc_payload_valid     <= w_nxt_crc_payload_valid;
    o_pl_trdy_fdi           <= w_nxt_pl_trdy_fdi;
    o_lp_data_rdi           <= w_nxt_lp_data_rdi;
    o_lp_valid_rdi          <= w_nxt_lp_valid_rdi;
    o_lp_irdy_rdi           <= w_nxt_lp_irdy_rdi;
    o_flit_boundary_done    <= w_nxt_flit_boundary_done;
    o_flush_done            <= w_nxt_flush_done;
    o_drain_done            <= w_nxt_drain_done;
  end
end

endmodule


