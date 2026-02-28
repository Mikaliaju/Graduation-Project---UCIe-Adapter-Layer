// =================================================================================================
//  FILENAME    : CRC_Check.sv
//  MODULE      : CRC_Check
//  PROJECT     : UCIe 3.0 Adapter Layer
//  AUTHOR      : Ali Noureldin Abdelaziz
// =================================================================================================
//  DESCRIPTION :
//    It recomputes CRC0 and CRC1 using the same fixed windows applied during transmission,
//    and compares them with the received CRC values.
//
//  FUNCTIONALITY :
//    - Incoming data is processed to recompute CRC0 and CRC1.
//    - The newly computed CRC values are then compared against the received ones.
//    - If both CRC values match, the block asserts crc_correct.
//    - If a mismatch is detected, a crc_error signal is sent to the Retry block.
// =================================================================================================

import CRC_Check_pkg ::*;
module CRC_Check (
  input  logic                    i_clk,
  input  logic                    i_rst_n,
  input  logic                    i_crc_payload_valid,  // Indicates valid data for CRC. 
  input  logic    [DATA_PATH-1:0] i_crc_payload,        // Flit data excluding CRC fields 64B per clock.
  input  logic    [CRC_SIZE-1:0]  i_crc0_ch,            // CRC0 value received within the flit.. 
  input  logic    [CRC_SIZE-1:0]  i_crc1_ch,            // CRC1 value received within the flit..
  output logic                    o_crc_correct,        // Asserted when calculated CRC matches received CRC values. 
  output logic                    o_crc_err             // Asserted when a CRC mismatch is detected.
);

//================================================ SIGNALS ===================================================
logic [CRC_SIZE-1:0] r_crc_reg0;     // Store value of CRC  for CRC0.
logic [CRC_SIZE-1:0] r_crc_reg1;     // Store value of CRC  for CRC1.
logic [CRC_SIZE-1:0] r_crc_next;     // Used in Combinational CRC calculation Logic.

logic [CRC_SIZE-1:0] r_crc0_final;   // Hold final value of CRC  for CRC0 for 1 clk.
logic [CRC_SIZE-1:0] r_crc1_final;   // Hold final value of CRC  for CRC1 for 1 clk.
logic [CRC_SIZE-1:0] r_crc0_ch_reg;  // Hold value of i_CRC0_ch.
logic [CRC_SIZE-1:0] r_crc1_ch_reg;  // Hold value of i_CRC1_ch.

chunk_state_e r_state;               // Count 4chunk of 256B.
// ===========================================================================================================

// =========================================================
//  CRC Function calculation 
// =========================================================

function [CRC_SIZE-1:0] next_crc16;
  input  logic [CRC_SIZE-1:0]  w_crc;  // CRC generat in each chunk.
  input  logic [DATA_PATH-1:0] w_data; // Data used in function (payload)

  reg    [CRC_SIZE-1:0] r_crc_temp;      // Make function operation on it.
  integer       i;               // Used in for loop.
  begin
    r_crc_temp = w_crc;
    for ( i=DATA_PATH-1 ; i>=0 ; i=i-1) begin
        if (r_crc_temp[CRC_SIZE-1] ^ w_data[i])
           r_crc_temp = (r_crc_temp << 1) ^ CRC_POLY;
        else
           r_crc_temp = (r_crc_temp << 1);
    end
    next_crc16 = r_crc_temp;
  end
endfunction

// =========================================================
// Combinational CRC calculation Logic
// =========================================================

always_ff @(*) begin
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
    r_crc_reg0    <= CRC_INIT;
    r_crc_reg1    <= CRC_INIT;
    r_state       <= S_CHUNK0;
    r_crc0_final  <= 0;
    r_crc1_final  <= 0;
    o_crc_correct <= 0;
    o_crc_err     <= 0;
  end
  else begin
    o_crc_correct <= 0;
    o_crc_err     <= 0;
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
           r_crc_reg1    <= r_crc_next;
           // Store final CRC in separate register.
           r_crc0_final  <= r_crc_reg0;
           r_crc1_final  <= r_crc_next;
           r_crc0_ch_reg <= i_crc0_ch;   //Store crc0_ch value cause it will chang after cycle 4.
           r_crc1_ch_reg <= i_crc1_ch;   //Store crc1_ch value cause it will chang after cycle 4.
           r_state       <= S_COMPARE;
         end
         // Compare phase (1 cycle after full flit)
         S_COMPARE: begin
           if ( (r_crc0_final == r_crc0_ch_reg)&&(r_crc1_final == r_crc1_ch_reg) ) begin
             o_crc_correct <= 1'b1;
             o_crc_err     <= 1'b0;
           end
           else begin
             o_crc_correct <= 1'b0;
             o_crc_err     <= 1'b1;
           end
           // prepare for next flit
           r_crc_reg0      <= CRC_INIT;
           r_crc_reg1      <= CRC_INIT;
           r_state         <= S_CHUNK0;
         end
       endcase
     end
   end
end

endmodule
