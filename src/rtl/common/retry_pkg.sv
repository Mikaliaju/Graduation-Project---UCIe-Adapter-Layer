package UC_retry_pkg;
    parameter MAX_UNACKNOWLEDGED_FLITS = 127;
    parameter NAK_WITHDRAWAL_ALLOWED = 0;
    
    parameter ADDR_DATA_WIDTH   = 10; //2 ^ 10 = 1024
    parameter ADDR_STREAM_WIDTH = 8; //2 ^ 8 = 256
    parameter DATA_WIDTH        = 512; //64B = 512 bits
    parameter STREAM_WIDTH      = 5; // 5 bits
    parameter DATA_DEPTH        = 1024; //256 * 4 = 1024; 
    parameter STREAM_DEPTH      = 256;

    typedef enum logic [1:0] {
        explicit = 2'b00,
        nak = 2'b10,
        ack = 2'b01
    } replay_command_t;

    typedef enum logic [1:0] {
        IDLE, //when tx and rx not enabled
        SNH, //Sequence Number Handshake
        SNH_FDI_ACTIVE, //Sequence Number Handshake when FDI is active
        NORMAL_EXCHANGE
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

    typedef enum {
        NOP = 1'b0,
        PAYLOAD = 1'b1
    } flit_type_t;

endpackage