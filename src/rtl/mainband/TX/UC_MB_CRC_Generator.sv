// =================================================================================================
//  FILENAME    : UC_MB_CRC_Generator.sv
//  MODULE      : UC_MB_CRC_Generator
//  PROJECT     : UCIe 3.0 Adapter Layer
//  AUTHOR      : Ali Noureldin Abdelaziz
// =================================================================================================
//  DESCRIPTION :
//    The CRC calculation includes the flit header, payload data, and any inserted DLLP bytes, 
//    while excluding the CRC fields themselves.
//
//  FUNCTIONALITY :
//    - The CRC block implements a 16-bit Cyclic Redundancy Check.
//    - The CRC computation is based on the Linear Feedback Shift Register (LFSR).
//    - Instead of processing one bit per clock cycle, the design processes 512 bits.
//    - Full 256-Byte Flit requires four clock cycles to complete CRC computation.
// =================================================================================================

import UC_MB_Mainband_pkg ::*;
module UC_MB_CRC_Generator (
  input  logic                    i_clk,
  input  logic                    i_rst_n,
  input  logic                    i_crc_payload_valid,  // Indicates valid data for CRC. 
  input  logic    [DATA_PATH-1:0] i_crc_payload,        // Flit data excluding CRC fields 64B per clock.
  output logic    [CRC_SIZE-1:0]  o_crc0_gen,           // CRC value calculated for the first 128 bytes. 
  output logic    [CRC_SIZE-1:0]  o_crc1_gen,           // CRC value calculated for the second CRC.
  output logic                    o_crc_valid           // Indicates that CRC calculation is complete and valid.
);

//================================================ SIGNALS ===================================================
logic [CRC_SIZE-1:0] r_crc_reg0;     // Store value of CRC  for CRC0.
logic [CRC_SIZE-1:0] r_crc_reg1;     // Store value of CRC  for CRC1.
logic [CRC_SIZE-1:0] r_crc_next;     // Used in Combinational CRC calculation Logic.

chunk_state r_state;                 // Count 4chunk of 256B.
// ===========================================================================================================

// =============================================================================
// Output Assignments (Combinational ? same cycle as chunk3 received)
// =============================================================================
assign o_crc_valid = (r_state == S_CHUNK3) && i_crc_payload_valid;
assign o_crc0_gen  = (r_state == S_CHUNK3) && i_crc_payload_valid ? r_crc_reg0 : '0;
assign o_crc1_gen  = (r_state == S_CHUNK3) && i_crc_payload_valid ? r_crc_next : '0;
// ==============================================================================

// =========================================================
// Combinational CRC calculation Logic
// =========================================================

always_comb begin
  case (r_state)
    // First 64B of CRC0
    S_CHUNK0: r_crc_next = next_crc16(CRC_INIT, i_crc_payload);
    // Second 64B of CRC0
    S_CHUNK1: r_crc_next = next_crc16(r_crc_reg0, i_crc_payload);
    // First 64B of CRC1
    S_CHUNK2: r_crc_next = next_crc16(CRC_INIT, i_crc_payload);
    // Second 64B of CRC1
    S_CHUNK3: r_crc_next = next_crc16(r_crc_reg1, i_crc_payload);

    default: r_crc_next = CRC_INIT;
  endcase
end

// =========================================================
// Sequential Logic
// =========================================================

always_ff @(posedge i_clk or negedge i_rst_n) begin
  if (!i_rst_n) begin
    r_crc_reg0   <= CRC_INIT;
    r_crc_reg1   <= CRC_INIT;
    r_state      <= S_CHUNK0;
  end
  else if (~i_crc_payload_valid) begin
    r_crc_reg0   <= CRC_INIT;
    r_crc_reg1   <= CRC_INIT;
    r_state      <= S_CHUNK0;
  end
  else begin
//    o_crc_valid <= 0;
    if (i_crc_payload_valid) begin
      case (r_state)
        // First 64B ? CRC0 window
        S_CHUNK0: begin
          r_crc_reg0  <= r_crc_next;
          r_state     <= S_CHUNK1;
        end
         // Second 64B ? CRC0 window ends (128B total)
         S_CHUNK1: begin
           r_crc_reg0  <= r_crc_next;
           r_state     <= S_CHUNK2;
         end
         // Third 64B ? CRC1 window starts
         S_CHUNK2: begin
           r_crc_reg1  <= r_crc_next;
           r_state     <= S_CHUNK3;
         end
         // Fourth 64B ? CRC1 window ends
         S_CHUNK3: begin
           r_state     <= S_CHUNK0;
         end

         default: r_state <= S_CHUNK0;
       endcase
     end
   end
end

endmodule

