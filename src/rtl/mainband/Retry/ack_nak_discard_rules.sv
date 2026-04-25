//author : fatma fawzy
//module description : validate the received flits and schedule ack/nak flits
//date : 28/2/2026
import common_pkg::*;

module ack_nak_discard_rules (
    input  logic            clk, rst_n,
    input  logic            init,                          // software reset
    input  logic            i_crc_error,                  // crc error in the received flit from mainband receiver
    input  phase_t          i_phase,                      // phase of the link
    input  flit_type_t      i_flit_type,                  // 1 : payload, 0 : nop
    input  replay_command_t i_replay_command,             // ack or nak or explicit
    input  logic [7:0]      i_seq_num,                    // sequence number of the received flit
    input  logic [7:0]      i_implicit_rx_flit_seq_num,   // implicit sequence number from implicit seq number module (new)
    input  logic [7:0]      i_next_expect_rx_flit_seq_num, // from counter tracker
    input  logic [7:0]      i_tx_acknak_flit_seq_num,     // from counter tracker
    output logic            o_log_uie,                    // log uncorrectable internal error in register file
    output logic            o_discard_flit,               // discard flit
    output logic            o_discard_payload,            // discard payload
    output logic            o_nak_scheduled,              // nak scheduled
    output logic            o_nak_schedule_type,          // nak schedule type
    output logic [7:0]      o_tx_acknak_flit_seq_num,     // tx acknak flit to counter tracker
    output logic [7:0]      o_next_expect_rx_flit_seq_num // next expect rx flit to counter tracker
);

logic            r_crc_error_d;
logic            r_flit_type_d;
logic [7:0]      r_seq_num_d;
replay_command_t r_replay_command_d;

// delay by 1 cycle to wait for implicit rx seq num to be updated
always_ff @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        r_crc_error_d        <= 0;
        r_flit_type_d        <= NOP;
        r_seq_num_d          <= 0;
        r_replay_command_d   <= explicit;
    end
    else if (!init) begin
        r_crc_error_d        <= 0;
        r_flit_type_d        <= NOP;
        r_seq_num_d          <= 0;
        r_replay_command_d   <= explicit;
    end
    else begin
        r_crc_error_d        <= i_crc_error;
        r_flit_type_d        <= i_flit_type;
        r_seq_num_d          <= i_seq_num;
        r_replay_command_d   <= i_replay_command;
    end
end

always_ff @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        o_log_uie                     <= 1'b0;
        o_discard_flit                <= 1'b0;
        o_discard_payload             <= 1'b0;
        o_nak_scheduled               <= 1'b0;
        o_nak_schedule_type           <= 1'b0;
        o_tx_acknak_flit_seq_num      <= 8'b0;
        o_next_expect_rx_flit_seq_num <= 8'b0;
    end
    else if (!init) begin
        o_log_uie                     <= 1'b0;
        o_discard_flit                <= 1'b0;
        o_discard_payload             <= 1'b0;
        o_nak_scheduled               <= 1'b0;
        o_nak_schedule_type           <= 1'b0;
        o_tx_acknak_flit_seq_num      <= 8'b0;
        o_next_expect_rx_flit_seq_num <= 8'b0;
    end
    else begin
        o_discard_flit                <= 1'b0;
        o_discard_payload             <= 1'b0;
        o_log_uie                     <= 1'b0;
        if (r_crc_error_d) begin
            if (o_nak_scheduled) begin
                flit_discard_1();
            end
            else begin
                nak_schedule_0();
            end
        end
        else if (r_replay_command_d == explicit && i_phase == normal_exchange
                 && r_seq_num_d == 8'b0) begin
            flit_discard_2();
        end
        else begin
            if (r_flit_type_d == NOP) begin
                if (bad_nop_sequence_number()) begin
                    nak_schedule_2();
                end
                else begin
                    flit_discard_0();
                end
            end
            else begin
                if (o_nak_scheduled) begin
                    standard_nak_procedure();
                end
                else begin
                    if      (duplicate_sequence_number()) flit_discard_0();
                    else if (bad_sequence_number())       nak_schedule_2();
                    else                                  ack_schedule_0();
                end
            end
        end
    end
end

function bad_sequence_number();
    return (i_next_expect_rx_flit_seq_num - i_implicit_rx_flit_seq_num) % 255 > 127;
endfunction

function bad_nop_sequence_number();
    return bad_sequence_number() || (i_implicit_rx_flit_seq_num == i_next_expect_rx_flit_seq_num);
endfunction

function duplicate_sequence_number();
    return ((i_tx_acknak_flit_seq_num - i_implicit_rx_flit_seq_num) % 255 < 127);
endfunction

task standard_nak_procedure();
    if (duplicate_sequence_number()) begin
        if (o_nak_scheduled) begin
            flit_discard_0();
        end
        else begin
            nak_schedule_2();
        end
    end
    else if ((r_replay_command_d == explicit) &&
             (i_implicit_rx_flit_seq_num == i_next_expect_rx_flit_seq_num)) begin
        ack_schedule_1();
    end
    else begin
        if (o_nak_scheduled) begin
            flit_discard_0();
        end
        else begin
            nak_schedule_2();
        end
    end
endtask

task automatic ack_schedule_0();
    o_tx_acknak_flit_seq_num      <= i_next_expect_rx_flit_seq_num;
    o_next_expect_rx_flit_seq_num <= i_next_expect_rx_flit_seq_num + 1;
    o_nak_scheduled               <= 1'b0;
    o_nak_schedule_type           <= standard_nak;
endtask

task automatic ack_schedule_1();
    o_tx_acknak_flit_seq_num      <= i_implicit_rx_flit_seq_num;
    o_next_expect_rx_flit_seq_num <= i_implicit_rx_flit_seq_num + 1;
    o_nak_scheduled               <= 1'b0;
    o_nak_schedule_type           <= standard_nak;
endtask

task automatic nak_schedule_0();
    o_discard_flit                <= 1'b1;
    o_nak_scheduled               <= 1'b1;
    o_next_expect_rx_flit_seq_num <= i_next_expect_rx_flit_seq_num;
endtask

task automatic nak_schedule_2();
    o_discard_payload             <= 1'b1;
    o_tx_acknak_flit_seq_num      <= i_next_expect_rx_flit_seq_num - 1;
    o_nak_scheduled               <= 1'b1;
    o_nak_schedule_type           <= standard_nak;
    o_next_expect_rx_flit_seq_num <= i_next_expect_rx_flit_seq_num;
endtask

task automatic flit_discard_0();
    o_discard_payload             <= 1'b1;
    o_next_expect_rx_flit_seq_num <= i_next_expect_rx_flit_seq_num;
endtask

task automatic flit_discard_1();
    o_discard_flit                <= 1'b1;
    o_next_expect_rx_flit_seq_num <= i_next_expect_rx_flit_seq_num;
endtask

task automatic flit_discard_2();
    o_discard_flit                <= 1'b1;
    o_next_expect_rx_flit_seq_num <= i_next_expect_rx_flit_seq_num;
    o_log_uie                     <= 1'b1;
endtask

endmodule