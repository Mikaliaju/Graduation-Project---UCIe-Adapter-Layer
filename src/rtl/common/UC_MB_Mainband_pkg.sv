// =================================================================================================
//  FILENAME    : UC_MB_Mainband_pkg.sv
//  MODULE      : UC_MB_Mainband_pkg
//  PROJECT     : UCIe 3.0 Adapter Layer
//  AUTHOR      : Ali Noureldin Abdelaziz & Fatma Fawzy
// =================================================================================================
//  DESCRIPTION :
//    pkg for mainband blocks.
//
//  FUNCTIONALITY :
//    Contain paramter , function and enum.
// =================================================================================================

package UC_MB_Mainband_pkg ;

//============================================ PARAM  =============================================== 
parameter CRC_POLY    = 16'h1021;       // Polynomial: x^16 + x^15 + x^2 + 1
parameter CRC_INIT    = 16'h0000;       // Initial value for crc
parameter DATA_PATH   = 512;            // data path = 64B
parameter CRC_SIZE    = 16;             // 2B
parameter FLIT_BITS   = 2048;           // 256B flit mode
parameter FLIT_HEADER = 8;              // 2B  (FH0=1B & FH1=1B)
parameter SEQUENS_NUM = 8;              // 1B  [7:4] upper & [3:0] lower
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
  S_CHUNK0,                         // First 64B of flit
  S_CHUNK1,                         // Second 64B of flit
  S_CHUNK2,                         // Third 64B of flit
  S_CHUNK3,                         // Fourth 64B of flit
  S_COMPARE                         // Compare recived crc with generated
} chunk_state;  

typedef enum logic [1:0] {
  S_START         = 2'b00,          // Wait for unpacker enable from LSM
  S_RECEIVE       = 2'b01,          // Cycles 1-4: receive chunks, feed CRC_Gen, cut-through forward
  S_CHECK         = 2'b10,          // Cycle 5: compare CRC, check retry result, assert flit_cancel if error
  S_COMPLET       = 2'b11           // Prepare for next flit
} unpacker_state_e;

typedef enum logic [2:0] {
  S_IDLE          = 3'b000,         // Wait for packer enable from LSM
  S_COLLECT       = 3'b001,         // Cycles 1-4 receive, feed CRC_Gen, pipeline send to RDI
  S_INSERT        = 3'b010,         // Cycle 5 insert fields into chunk3, send to RDI
  S_DONE          = 3'b011,         // Check pending commands, prepare for next flit
  S_FLIT_BOUNDARY = 3'b100,         // Finish current flit then assert flit_boundary_done
  S_DRAIN         = 3'b101,         // Send all data normally with replay until buffer empty
  S_FLUSH         = 3'b110          // Send retry buffer data with retry off, valid on
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

//============================================ RETRY  ================================================

    parameter MAX_UNACKNOWLEDGED_FLITS = 127;
    parameter NAK_WITHDRAWAL_ALLOWED = 0;
    
    parameter ADDR_DATA_WIDTH   = 10; //2 ^ 10 = 1024
    parameter ADDR_STREAM_WIDTH = 8; //2 ^ 8 = 256
    parameter DATA_WIDTH        = 512; //64B = 512 bits
    parameter STREAM_WIDTH      = 5; // 5 bits
    parameter DATA_DEPTH        = 1024; //256 * 4 = 1024; 
    parameter STREAM_DEPTH      = 256;

    typedef enum logic [1:0] {
        IDLE, 
        sequence_number_handshake_st, 
        sequence_number_handshake_fdi_active, 
        normal_exchange_st
    } state_t;

    typedef enum logic [1:0] {
        explicit = 2'b00,
        nak = 2'b10,
        ack = 2'b01
    } replay_command_t;

    typedef enum logic [1:0] {
        idle, //when tx and rx not enabled
        sequence_number_handshake_ph,
        normal_exchange_ph
    } phase_t;

    typedef enum {
        standard_nak,
        selective_nak
    } nak_schedule_type_t;

    typedef enum {
        standard_replay,
        selective_replay
    } replay_schedule_type_t;

    typedef enum {
        GTs_32,
        GTs_16
    } data_rate_t;


// ==================================================================================================

endpackage

