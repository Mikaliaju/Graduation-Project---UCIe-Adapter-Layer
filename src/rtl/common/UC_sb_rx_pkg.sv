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
endpackage : UC_sb_rx_pkg