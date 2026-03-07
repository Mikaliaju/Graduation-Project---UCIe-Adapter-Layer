// =================================================================================================
//  FILENAME    : Mainband_pkg.sv
//  MODULE      : Mainband_pkg
//  PROJECT     : UCIe 3.0 Adapter Layer
//  AUTHOR      : Ali Noureldin Abdelaziz
// =================================================================================================
//  DESCRIPTION :
//    pkg for mainband blocks.
//
//  FUNCTIONALITY :
//    Contain paramter , function and enum.
// =================================================================================================

package Mainband_pkg ;

//============================================ PARAM  =============================================== 
parameter CRC_POLY    = 16'h1021;       // Polynomial: x^16 + x^15 + x^2 + 1
parameter CRC_INIT    = 16'h0000;       // Initial value for crc
parameter DATA_PATH   = 512;            // data path = 64B
parameter CRC_SIZE    = 16;             // 2B
parameter FLIT_BITS   = 2048;           // 256B flit mode
parameter FLIT_HEADER = 8;              // 2B  (FH0=1B & FH1=1B)
parameter SEQUENS_NUM = 8;              // 1B  [7:4] upper & [3:0]l ower
parameter REPLAY_CMD  = 2;              // 2 bits
parameter DLLP        = 32;             // 4B
parameter PROTOCOL_ID = 2;              // 2 bits

// Chunk 3 relative bit offsets
parameter C3_FH_B0    = 352;            // FH Byte 0        (44*8)
parameter C3_FH_B1    = 360;            // FH Byte 1        (45*8)
parameter C3_DLP      = 368;            // DLP B2-B5 (4B)   (46*8)
parameter C3_RSV      = 400;            // 10B Reserved     (50*8)
parameter C3_CRC0     = 480;            // CRC0             (60*8)
parameter C3_CRC1     = 496;            // CRC1             (62*8)
parameter C3_ABS      = 3 * DATA_PATH;  // Chunk 3 absolute start bit (192B) in flit buffer (64*8 = 1536) 

// ==================================================================================================
 
//============================================ ENUM  ================================================ 
typedef enum logic [2:0] {   
  S_CHUNK0,                    // First 64B of flit
  S_CHUNK1,                    // Second 64B of flit
  S_CHUNK2,                    // Third 64B of flit
  S_CHUNK3,                    // Fourth 64B of flit
  S_COMPARE                    // Compare recived crc with generated
} chunk_state;

typedef enum logic [3:0] {
  S_IDLE          = 3'b0000,         // Wait for packer enable from LSM
  S_COLLECT       = 3'b0001,         // Receive 4x64B chunks from FDI or retry buffer
  S_FEED_CRC      = 3'b0010,         // Send assembled flit chunks to CRC_Generator (4 cycles)
  S_WAIT_CRC      = 3'b0011,         // Wait for crc_valid from CRC_Generator
  S_SEND          = 3'b0100,         // Transmit final flit to RDI (4 cycles)
  S_DONE          = 3'b0101,         // Assert clean_boundary, prepare for next flit
  S_FLIT_BOUNDARY = 4'b0110,         // Finish current flit then assert flit_boundary_done
  S_DRAIN         = 4'b0111,         // Send all data normally with replay until buffer empty
  S_FLUSH         = 4'b1000          // Send retry buffer data with retry off, valid on
} packer_state_e;
// ==================================================================================================

// ==================================================================================================
//  CRC Function calculation 
// ==================================================================================================

function [CRC_SIZE-1:0] next_crc16;
  input  logic  [CRC_SIZE-1:0]  w_crc;  // CRC generat in each chunk.
  input  logic  [DATA_PATH-1:0] w_data; // Data used in function (payload)

  reg    [CRC_SIZE-1:0] r_crc_temp;     // Make function operation on it.
  integer       i;                      // Used in for loop.
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

// ==================================================================================================

endpackage
