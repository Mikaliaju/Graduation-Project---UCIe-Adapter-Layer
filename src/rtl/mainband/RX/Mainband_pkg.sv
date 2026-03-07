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
parameter CRC_POLY = 16'h1021 ;       // Polynomial: x^16 + x^15 + x^2 + 1
parameter CRC_INIT = 16'h0000 ;
parameter DATA_PATH = 512 ;
parameter CRC_SIZE = 16 ;
// ==================================================================================================
 
//============================================ ENUM  ================================================ 
typedef enum logic [2:0] {   
    S_CHUNK0,
    S_CHUNK1,
    S_CHUNK2,
    S_CHUNK3,
    S_COMPARE
} chunk_state;
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
