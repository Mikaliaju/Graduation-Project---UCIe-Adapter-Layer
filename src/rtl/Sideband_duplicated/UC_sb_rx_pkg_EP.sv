package UC_sb_rx_pkg_EP;


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
        RXD_ERROR             = 4'd5,
        RXD_COLLECT_READ_REQ  = 4'd6,   // Collecting a Read Request  (2 phases)
        RXD_COLLECT_WRITE_REQ = 4'd7,   // Collecting a Write Request (4 phases)
        RXD_REQ_PARITY_CHK    = 4'd8,   // Parity check on fully collected request
        RXD_REQ_PARITY_ERR    = 4'd9    // Stuck state on parity error
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


endpackage