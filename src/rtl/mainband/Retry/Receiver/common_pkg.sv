package common_pkg;
    localparam MAX_UNACKNOWLEDGED_FLITS = 127;
    localparam NAK_WITHDRAWAL_ALLOWED = 0;

    typedef enum logic [1:0] {
        explicit = 2'b00,
        nak = 2'b10,
        ack = 2'b01
    } replay_command_t;

    typedef enum logic {
        sequence_number_handshake,
        normal_exchange
    } phase_t;

    typedef enum logic {
        standard_nak,
        selective_nak
    } nak_schedule_type_t;

endpackage