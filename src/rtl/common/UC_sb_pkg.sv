package UC_sb_pkg;
// 1) TX:-
// =========================================================================
//............................ UC_SB_FDI_PACKER............................
// =========================================================================
// --- FSM states ---
    typedef enum logic [1:0] {
        S_IDLE    = 2'b00,   // FIFO_READY  equivalent: waiting for first valid chunk
        S_COLLECT = 2'b01,   // FIFO_COLLECT equivalent: accumulating remaining chunks
        S_PUSH    = 2'b10    // write assembled packet to FDI FIFO
    } fdi_state_e;

    // --- Decode result struct ---
    typedef struct packed {
        logic        valid;
        logic        is_read;
        logic        is_32bit;          // 32-bit operation flag
        logic        is_conf;
        logic [6:0]  data_bits;         // payload bits: 0 / 32 / 64
        logic [4:0]  completion_opcode;
    } fdi_dec_t;
// =========================================================================
//.......................... UC_SB_FDI_Controller...........................
// =========================================================================
// FSM state encoding
// ============================================================================
typedef enum logic [3:0] {
    TXCTRL_IDLE        = 4'd0,
    TXCTRL_POP         = 4'd1,   // assert o_Rd_en
    TXCTRL_POP_WAIT    = 4'd2,   // wait 1 cycle for data to appear on i_Data_out
    TXCTRL_PARSE       = 4'd3,   // parity check + routing decision
    TXCTRL_SEND_PHY    = 4'd4,   // forward packet to RDI FIFO (stall if full)
    TXCTRL_ISSUE_LOCAL = 4'd5,   // present request to Access Arbiter (first cycle)
    TXCTRL_WAIT_LOCAL  = 4'd6,   // hold request until i_Local_done
    TXCTRL_BUILD_COMP  = 4'd7,   // build completion packet (registered)
    TXCTRL_PUSH_COMP   = 4'd8    // output completion for one cycle
} state_t;
// =========================================================================
//.......................... UC_SB_FDI_REMOTE_DIE_REQUEST....................
// =========================================================================
       //--------------------------- state ----------------------------//
    typedef enum logic [2:0] {
        TXRDR_IDLE, // RDR for remote die request
        TXRDR_WAIT_DECODER,
        TXRDR_SEND_PHY_REQ,
        TXRDR_WAIT_PHY_COMP,
        TXRDR_WAIT_REMOTE,
        TXRDR_BUILD_COMP,
        TXRDR_SEND_COMP
    } remote_req_state_t;

// =========================================================================
//.......................... UC_SB_TX__RDI_CONTROLLER.......................
// =========================================================================
typedef enum logic {
      TX_STATE_IDLE,
      TX_STATE_SEND
     } rdi_ctrl_state;

// =========================================================================
//....................... UC_SB_TX__MAILBOX_CONTROLLER......................
// =========================================================================
    typedef enum logic [1:0] {
  WAIT_FOR_E2E_CRD,   // Wait until E2E credit is available before allowing remote access only for first time
  WAIT_FOR_TRIGG,     // Wait for mailbox trigger bit
  WAIT_FOR_SEND,      // Drive request to RDI until RDI asserts i_req_sent
  WAIT_FOR_COMP       // Wait for completion or timeout
} MAILBOX_FSM ;
// 2) RX:-
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


endpackage : UC_sb_pkg