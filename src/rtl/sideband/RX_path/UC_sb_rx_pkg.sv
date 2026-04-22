package UC_sb_rx_pkg;

// =========================================================================
//  LSM (Link State Management) Message Encodings
// =========================================================================

    // State Message Encoding (4-bit)
    typedef enum logic [3:0] {
        NONE           = 4'd0,
        ACTIVE_REQ     = 4'd1,
        L1_REQ         = 4'd2,
        L2_REQ         = 4'd3,
        LINKRESET_REQ  = 4'd4,
        DISABLED_REQ   = 4'd5,
        ACTIVE_RESP    = 4'd6,
        PMNAK_RESP     = 4'd7,
        L1_RESP        = 4'd8,
        L2_RESP        = 4'd9,
        LINKRESET_RESP = 4'd10,
        DISABLED_RESP  = 4'd11
    } sb_state_msg_encoding;

    // Error Message Encoding (2-bit)
    typedef enum logic [1:0] {
        NONE_ERR        = 2'd0,
        Correctable_Err = 2'd1,
        NON_FATAL_Err   = 2'd2,
        FATAL_Err       = 2'd3
    } sb_error_msg_encoding;

// =========================================================================
//  UC_rx_completions_controller - FSM & Parameters
// =========================================================================

    // FSM State Encoding
    typedef enum logic [2:0] {
        IDLE                = 3'd0,   // Waiting for incoming completion
        PKT_ASSEMBLY        = 3'd1,   // Assembling phase chunks into full packet
        VALIDATE_PKT        = 3'd2,   // Checking parity and tag validity
        WAIT_FDI_FREE       = 3'd3,   // Waiting for FDI bus to become available
        TRANSMIT_VIA_FDI    = 3'd4,   // Streaming local completion over FDI
        FORWARD_REMOTE_COMP = 3'd5,   // Forwarding remote completion to mailbox
        PARITY_ERROR        = 3'd6    // Latched parity error state
    } completions_ctrl_sts;

    // Local Parameters - Completions Controller
    localparam logic [4:0] REMOTE_TAG = 5'b11111;

// =========================================================================
//  UC_rx_controller_decoder - FSM & Parameters
// =========================================================================

    // RX Decoder FSM State Encoding
    typedef enum logic [3:0] {
        RXD_IDLE              = 4'd0,
        RXD_COMP_WITHOUT_DATA = 4'd1,
        RXD_COMP_WITH_DATA    = 4'd2,
        RXD_MSG_WITHOUT_DATA  = 4'd3,
        RXD_MSG_WITH_DATA     = 4'd4,
        RXD_ERROR             = 4'd5
        `ifdef END_POINT
        ,
        RXD_COLLECT_READ_REQ  = 4'd6,   // Collecting a Read Request  (2 phases)
        RXD_COLLECT_WRITE_REQ = 4'd7,   // Collecting a Write Request (4 phases)
        RXD_REQ_PARITY_CHK    = 4'd8,   // Parity check on fully collected request
        RXD_REQ_PARITY_ERR    = 4'd9    // Stuck state on parity error
        `endif
    } rxd_sts;

// =========================================================================
//  UC_rx_msgs_ctrl - FSM & Parameters
// =========================================================================

    // Message Controller FSM State Encoding
    typedef enum logic [2:0] {
        MSGC_IDLE         = 3'd0,
        MSGC_COLLECT_PKT  = 3'd1,
        MSGC_PARITY_CHK   = 3'd2,
        MSGC_PARITY_ERR   = 3'd3,
        MSGC_INVLD_ID_ERR = 3'd4
    } msgc_sts;

// =========================================================================
//  Common Local Parameters (NC-Based Calculations)
// =========================================================================
    localparam NC = 32;
    // Chunk Counter Width - calculated based on 128-bit packet and NC
    localparam int CHUNK_COUNTER_WIDTH = $clog2(128/NC);  // Default NC=32
    
    // Packet Chunk Counts
    localparam int HALF_CHUNKS = 64  / NC;   // Chunks in half packet (64-bit)
    localparam int FULL_CHUNKS = 128 / NC;   // Chunks in full packet (128-bit)
    localparam int PKT_CHUNKS_NUM = 128 / NC; // Max number of chunks per packet


endpackage : UC_sb_rx_pkg