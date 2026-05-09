// =================================================================================================
//  FILENAME    : UC_MB_Unpacker.sv
//  MODULE      : UC_MB_Unpacker
//  PROJECT     : UCIe 3.0 Adapter Layer - Mainband RX Path
//  AUTHOR      : Ali Noureldin Abdelaziz
// =================================================================================================
//  DESCRIPTION :
//    The Unpacker operates in the receive path and handles incoming flits from the RDI interface.
//    It decomposes the received 256B flit into its individual components and forwards them.
//
//  FUNCTIONALITY :
//    - Receives 4 x 64B chunks from RDI (cycles 1-4).
//    - In parallel: feeds each chunk to CRC_Generator in the same cycle it is received.
//    - Chunk 3 fed to CRC_Generator is masked (CRC0/CRC1 fields = 0).
//    - Cut-through forwarding to FDI with 1-cycle delay.
//    - Cycle 5 (CHECK): CRC_Generator result ready, compare vs received CRC,
//        retry result also available -> assert flit_cancel if any error.
//
//  Timing:
//    Cycle 1 : receive chunk0, feed CRC_Gen
//    Cycle 2 : receive chunk1, feed CRC_Gen, forward chunk0 to FDI
//    Cycle 3 : receive chunk2, feed CRC_Gen, forward chunk1 to FDI
//    Cycle 4 : receive chunk3, feed CRC_Gen (masked), forward chunk2 to FDI
//    Cycle 5 : CRC done + check + forward chunk3 to FDI + flit_cancel if error
// =================================================================================================

import UC_MB_Mainband_pkg::*;
module UC_MB_Unpacker (
  // -------------------------
  // Clock & Reset
  // -------------------------
  input  logic                      i_clk,
  input  logic                      i_rst_n,
  input  logic                      i_init,
  // -------------------------
  // RDI Interface (Inputs)
  // -------------------------
  input  logic    [DATA_PATH-1:0]   i_pl_data_rdi,       // Received flit data from RDI (64B/cycle)
  input  logic                      i_pl_valid_rdi,      // Incoming flit data is valid
  // -------------------------
  // Retry Interface (Inputs)
  // -------------------------
  input  logic                      i_check_pass,        // Retry: sequence check passed
  input  logic                      i_discarded_flit,    // Retry: flit must be discarded
  // -------------------------
  // LSM Interface (Inputs)
  // -------------------------
  input  logic                      i_unpacker_en,       // Enable unpacker operation
  input  logic                      i_stop_stream,       // Stop unpacking and forwarding
  // -------------------------
  // FDI Interface (Outputs)
  // -------------------------
  output logic    [DATA_PATH-1:0]   o_pl_data_fdi,       // Payload forwarded to FDI
  output logic                      o_pl_valid_fdi,      // Payload to FDI is valid
  output logic    [7:0]             o_pl_stream,         // {SID, PID} to FDI
  output logic    [DLLP-1:0]        o_pl_dllp,           // Extracted DLLP data to FDI
  output logic                      o_pl_dllp_valid,     // DLLP data is valid
  output logic                      o_pl_dllp_ofc,       // DLLP carries optimized flow control
  output logic                      o_flit_cancel,       // Cancel previously forwarded flit

  // -------------------------
  // Retry Interface (Outputs)
  // -------------------------
  output logic    [SEQUENS_NUM-1:0] o_seq_num,           // Sequence number extracted from FH
  output logic    [REPLAY_CMD-1:0]  o_replay_com,        // Replay command extracted from FH
  output logic                      o_crc_err            // CRC mismatch detected
);

// =============================================================================
// Internal Signals
// =============================================================================

logic [1:0]                r_chunk_cnt;           // Counts received chunks 0->3

// Pipeline register (1-cycle delay)
//logic [DATA_PATH-1:0]      r_pipe_data;           // Store data to delay it
//logic                      r_pipe_valid;          // Needed cause first cycle pipe_data are garbage

// Extracted chunk 3 fields
logic [PROTOCOL_ID-1:0]    r_pid;                 // Extract protocol id to send it in lp_stream
logic                      r_sid;                 // Extract stack id to send it in lp_stream
logic                      r_dllp_ofc;            // Store at FH_B0 at bit4
logic [SEQUENS_NUM-1:0]    r_seq_num;             // Sequence num to retry
logic [REPLAY_CMD-1:0]     r_replay_cmd;          // Replay command (ACK OR NAK) to retry
logic [DLLP-1:0]           r_dllp_buf;            // Store dllp from flit

// Received CRC values extracted from chunk 3
logic [CRC_SIZE-1:0]       r_crc0_ch;             // Recived crc0 to check
logic [CRC_SIZE-1:0]       r_crc1_ch;             // Recived crc1 to check
logic [CRC_SIZE-1:0]       w_crc0_gen;            // CRC value calculated for the first 128 bytes.
logic [CRC_SIZE-1:0]       w_crc1_gen;            // CRC value calculated for the second CRC.
logic                      w_crc_valid;           // Indicates that CRC calculation is complete and valid.
logic [DATA_PATH-1:0]      r_crc_payload;         // Flit data excluding CRC fields 64B per clock.
logic                      r_crc_payload_valid;   // Indicates valid data for CRC.
logic [DATA_PATH-1:0]      w_chunk3_masked;       // Chunk 3 masked combinational (CRC fields = 0)
logic [DATA_PATH-1:0]      w_chunk3_Raw;          // Chunk 3 masked st Raw data

unpacker_state_e r_state;                         // packer states
unpacker_state_e w_nxt_state;                     // next state

// =============================================================================
// Next-state & output signals (driven by comb block)
// =============================================================================

// Next-state values for all registers
logic [1:0]                w_nxt_chunk_cnt;
//logic [DATA_PATH-1:0]      w_nxt_pipe_data;
//logic                      w_nxt_pipe_valid;
logic [PROTOCOL_ID-1:0]    w_nxt_pid;
logic                      w_nxt_sid;
logic                      w_nxt_dllp_ofc;
logic [SEQUENS_NUM-1:0]    w_nxt_seq_num;
logic [REPLAY_CMD-1:0]     w_nxt_replay_cmd;
logic [DLLP-1:0]           w_nxt_dllp_buf;
logic [CRC_SIZE-1:0]       w_nxt_crc0_ch;
logic [CRC_SIZE-1:0]       w_nxt_crc1_ch;
logic [DATA_PATH-1:0]      w_nxt_crc_payload;
logic                      w_nxt_crc_payload_valid;

// Output next values
logic [DATA_PATH-1:0]      w_nxt_pl_data_fdi;
logic                      w_nxt_pl_valid_fdi;
logic                      w_nxt_pl_dllp_valid;
logic                      w_nxt_pl_dllp_ofc;
logic                      w_nxt_flit_cancel;
logic                      w_nxt_crc_err;


// =============================================================================
// CRC_Generator Instantiation
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
// Chunk 3 Raw (Combinational)
// =============================================================================
always_comb begin
  w_chunk3_Raw[351:0]       = i_pl_data_rdi[351:0];
  w_chunk3_Raw[C3_FH_B0+:8] = 8'h0 ;
  w_chunk3_Raw[C3_FH_B1+:8] = 8'h0 ;
  w_chunk3_Raw[C3_DLP+:32]  = 32'h0;
  w_chunk3_Raw[C3_RSV+:80]  = 80'h0;
  w_chunk3_Raw[C3_CRC0+:16] = 16'h0;
  w_chunk3_Raw[C3_CRC1+:16] = 16'h0;
end

// =============================================================================
// Chunk 3 Masked (Combinational)
// =============================================================================
// Takes current incoming chunk from RDI and zeros CRC fields for CRC_Gen input
always_comb begin
  w_chunk3_masked[C3_CRC0-1:0] = i_pl_data_rdi[C3_CRC0-1:0];
  w_chunk3_masked[C3_CRC0+:16] = 16'h0;
  w_chunk3_masked[C3_CRC1+:16] = 16'h0;
end

// =============================================================================
// Output Assignments (Combinational)
// =============================================================================
always_comb begin
  o_seq_num    = r_seq_num;
  o_replay_com = r_replay_cmd;
  o_pl_stream  = {5'b0, r_sid, r_pid};
  o_pl_dllp    = r_dllp_buf;
end

// =============================================================================
// FSM Combinational Block : Next-State + Output Logic
// =============================================================================
always_comb begin
  // -----------------------------------------------------------------
  // Default: hold all registers, de-assert all pulse outputs
  // -----------------------------------------------------------------
  w_nxt_state            = r_state;
  w_nxt_chunk_cnt        = r_chunk_cnt;
  //w_nxt_pipe_data        = r_pipe_data;
 // w_nxt_pipe_valid       = r_pipe_valid;
  w_nxt_pid              = r_pid;
  w_nxt_sid              = r_sid;
  w_nxt_dllp_ofc         = r_dllp_ofc;
  w_nxt_seq_num          = r_seq_num;
  w_nxt_replay_cmd       = r_replay_cmd;
  w_nxt_dllp_buf         = r_dllp_buf;
  w_nxt_crc0_ch          = r_crc0_ch;
  w_nxt_crc1_ch          = r_crc1_ch;
  w_nxt_crc_payload      = r_crc_payload;
  w_nxt_crc_payload_valid = 1'b0;          // pulse: default de-asserted

  w_nxt_pl_data_fdi      = o_pl_data_fdi;
  w_nxt_pl_valid_fdi     = 1'b0;           // pulse: default de-asserted
  w_nxt_pl_dllp_valid    = 1'b0;           // pulse: default de-asserted
  w_nxt_pl_dllp_ofc      = o_pl_dllp_ofc;
  w_nxt_flit_cancel      = 1'b0;           // pulse: default de-asserted
  w_nxt_crc_err          = 1'b0;           // pulse: default de-asserted

  case (r_state)

    // =====================================================================
    // S_START : Wait for unpacker enable
    // =====================================================================
    S_START: begin
      w_nxt_chunk_cnt  = 2'd0;
 //     w_nxt_pipe_valid = 1'b0;

      if (i_unpacker_en && !i_stop_stream)
        w_nxt_state = S_RECEIVE;
    end

    // =====================================================================
    // S_RECEIVE : Cycles 1-4
    //   1) Feed current chunk to CRC_Generator
    //      - Chunks 0,1,2 : raw data
    //      - Chunk 3      : masked (CRC fields = 0)
    //   2) Forward previous chunk to FDI (1-cycle pipeline delay)
    // =====================================================================
    S_RECEIVE: begin
      if (i_stop_stream || !i_unpacker_en) begin
      //  w_nxt_pipe_valid = 1'b0;
        w_nxt_state      = S_START;
      end
      else if (i_pl_valid_rdi) begin

        if (r_chunk_cnt == 2'd3) begin
          // Chunk 3: masked input to CRC_Generator
          w_nxt_crc_payload       = w_chunk3_masked;
          w_nxt_crc_payload_valid = 1'b1;

          // Extract chunk 3 fields
          // FH Byte 0: [7:6]=PID  [5]=SID  [4]=OFC  [3:0]=SEQ[7:4]
          // FH Byte 1: [7:6]=Flit_Type  [5:4]=Ack/Nak  [3:0]=SEQ[3:0]
          w_nxt_pid        = i_pl_data_rdi[C3_FH_B0+7 : C3_FH_B0+6];
          w_nxt_sid        = i_pl_data_rdi[C3_FH_B0+5];
          w_nxt_dllp_ofc   = i_pl_data_rdi[C3_FH_B0+4];
          w_nxt_replay_cmd = i_pl_data_rdi[C3_FH_B1+5 : C3_FH_B1+4];

          // Sequence number: upper=FH_B0[3:0], lower=FH_B1[3:0]
          w_nxt_seq_num    = {i_pl_data_rdi[C3_FH_B0+3 : C3_FH_B0], i_pl_data_rdi[C3_FH_B1+3 : C3_FH_B1]};

          // DLLP bytes
          w_nxt_dllp_buf   = i_pl_data_rdi[C3_DLP +: 32];

          // Received CRC values (for comparison in S_CHECK)
          w_nxt_crc0_ch    = i_pl_data_rdi[C3_CRC0 +: 16];
          w_nxt_crc1_ch    = i_pl_data_rdi[C3_CRC1 +: 16];

          // Forward DLLP info to FDI
          w_nxt_pl_dllp_valid = 1'b1;
          w_nxt_pl_dllp_ofc   = r_dllp_ofc;

          w_nxt_chunk_cnt = 2'd0;
          w_nxt_state     = S_CHECK;
        end
        else begin
          // Chunks 0,1,2: raw data to CRC_Generator
          w_nxt_crc_payload       = i_pl_data_rdi;
          w_nxt_crc_payload_valid = 1'b1;
          w_nxt_chunk_cnt         = r_chunk_cnt + 1'b1;
        end

        // Cut-through: forward previous chunk to FDI
        if (i_pl_valid_rdi && r_chunk_cnt == 2'd3) begin //&& r_chunk_cnt == 2'd3
          w_nxt_pl_data_fdi  = w_chunk3_Raw;
          w_nxt_pl_valid_fdi = 1'b1;
        end
        else if (i_pl_valid_rdi) begin
          w_nxt_pl_data_fdi  = i_pl_data_rdi;
          w_nxt_pl_valid_fdi = 1'b1;
        end

        // Pipeline: store current chunk for next cycle
     //   w_nxt_pipe_data  = i_pl_data_rdi;
     //   w_nxt_pipe_valid = 1'b1;
      end
    end

    // =====================================================================
    // S_CHECK : Cycle 5
    //   - Forward last chunk (chunk 3) to FDI
    //   - Compare computed CRC vs received CRC
    //   - Check retry sequence result
    //   - Assert flit_cancel if any error
    // =====================================================================
    S_CHECK: begin
      // Forward chunk 3 to FDI (last pipeline flush)
      // if (i_pl_valid_rdi) begin
      //   w_nxt_pl_data_fdi  = w_chunk3_Raw;
      //   w_nxt_pl_valid_fdi = 1'b1;
  //      w_nxt_pipe_valid   = 1'b0;
      // end

      // CRC comparison (CRC_Gen takes exactly 4 cycles, result ready here)
      if (w_crc_valid) begin
        if ((w_crc0_gen != r_crc0_ch) || (w_crc1_gen != r_crc1_ch)) begin
          w_nxt_crc_err     = 1'b1;
          w_nxt_flit_cancel = 1'b1;
          $display("CRC0 = %h | CRC1 = %h", w_crc0_gen, w_crc1_gen);
        end
      end

      // Sequence check from retry block
      if (i_discarded_flit || i_check_pass != 1'b1)
        w_nxt_flit_cancel = 1'b1;

      // Reset for next flit
      w_nxt_chunk_cnt  = 2'd0;
      w_nxt_pl_valid_fdi = 1'b0;

      if (i_unpacker_en && !i_stop_stream)
        w_nxt_state = S_RECEIVE;
      else
        w_nxt_state = S_START;
    end

    default: w_nxt_state = S_START;

  endcase
end

// =============================================================================
// FSM Sequential Block : State & Register Updates
// =============================================================================
always_ff @(posedge i_clk or negedge i_rst_n) begin
  if (!i_rst_n) begin
    r_state             <= S_START;
    r_chunk_cnt         <= 2'd0;
 //   r_pipe_data         <= '0;
 //   r_pipe_valid        <= 1'b0;
    r_pid               <= 2'b00;
    r_sid               <= 1'b0;
    r_dllp_ofc          <= 1'b0;
    r_seq_num           <= 8'h0;
    r_replay_cmd        <= 2'b00;
    r_dllp_buf          <= 32'h0;
    r_crc0_ch           <= '0;
    r_crc1_ch           <= '0;
    r_crc_payload       <= '0;
    r_crc_payload_valid <= 1'b0;
    o_pl_data_fdi       <= '0;
    o_pl_valid_fdi      <= 1'b0;
    o_pl_dllp_valid     <= 1'b0;
    o_pl_dllp_ofc       <= 1'b0;
    o_flit_cancel       <= 1'b0;
    o_crc_err           <= 1'b0;
  end
  else if (!i_init) begin
    r_state             <= S_START;
    r_chunk_cnt         <= 2'd0;
 //   r_pipe_data         <= '0;
 //   r_pipe_valid        <= 1'b0;
    r_pid               <= 2'b00;
    r_sid               <= 1'b0;
    r_dllp_ofc          <= 1'b0;
    r_seq_num           <= 8'h0;
    r_replay_cmd        <= 2'b00;
    r_dllp_buf          <= 32'h0;
    r_crc0_ch           <= '0;
    r_crc1_ch           <= '0;
    r_crc_payload       <= '0;
    r_crc_payload_valid <= 1'b0;
    o_pl_data_fdi       <= '0;
    o_pl_valid_fdi      <= 1'b0;
    o_pl_dllp_valid     <= 1'b0;
    o_pl_dllp_ofc       <= 1'b0;
    o_flit_cancel       <= 1'b0;
    o_crc_err           <= 1'b0;
  end
  else begin
    // Latch next-state values computed by combinational block
    r_state             <= w_nxt_state;
    r_chunk_cnt         <= w_nxt_chunk_cnt;
   // r_pipe_data         <= w_nxt_pipe_data;
  //  r_pipe_valid        <= w_nxt_pipe_valid;
    r_pid               <= w_nxt_pid;
    r_sid               <= w_nxt_sid;
    r_dllp_ofc          <= w_nxt_dllp_ofc;
    r_seq_num           <= w_nxt_seq_num;
    r_replay_cmd        <= w_nxt_replay_cmd;
    r_dllp_buf          <= w_nxt_dllp_buf;
    r_crc0_ch           <= w_nxt_crc0_ch;
    r_crc1_ch           <= w_nxt_crc1_ch;
    r_crc_payload       <= w_nxt_crc_payload;
    r_crc_payload_valid <= w_nxt_crc_payload_valid;
    o_pl_data_fdi       <= w_nxt_pl_data_fdi;
    o_pl_valid_fdi      <= w_nxt_pl_valid_fdi;
    o_pl_dllp_valid     <= w_nxt_pl_dllp_valid;
    o_pl_dllp_ofc       <= w_nxt_pl_dllp_ofc;
    o_flit_cancel       <= w_nxt_flit_cancel;
    o_crc_err           <= w_nxt_crc_err;
  end
end

endmodule


