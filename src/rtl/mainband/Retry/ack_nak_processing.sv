//author : fatma fawzy
//module description : process the received ack/nak flits to get valid ones
//date : 28/2/2026
import common_pkg::*;

module ack_nak_processing (
    input  logic            clk, rst_n,
    input  logic            init,                       // software reset
    input  replay_command_t i_replay_command,           // ack or nak or explicit
    input  logic [7:0]      i_seq_num,                  // sequence number of the received flit
    input  logic [7:0]      i_tx_acknak_flit_seq_num,   // tx acknak flit from counter tracker (old)
    input  logic [7:0]      i_ackd_flit_seq_num,        // ackd flit from counter tracker (old)
    input  logic [7:0]      i_tx_replay_flit_seq_num,
    input  logic            i_crc_error,                // crc error in the received flit from mainband receiver
    input  logic [7:0]      i_next_tx_flit_seq_num,
    input  logic [7:0]      i_nak_ignore_flit_seq_num,
    output logic [2:0]      o_flit_replay_num,
    output logic [7:0]      o_ackd_flit_seq_num,
    output logic [7:0]      o_tx_replay_flit_seq_num,
    output logic [7:0]      o_nak_ignore_flit_seq_num,
    output logic            o_start_replay,             //start replaying data in case of NAK recieved
    output logic            o_log_uie                  // log uncorrectable internal error in register file
);

always_ff @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        o_log_uie                <= 1'b0;
        o_flit_replay_num        <= 3'b0;
        o_ackd_flit_seq_num      <= 8'b0;
        o_tx_replay_flit_seq_num <= 8'b0;
        o_nak_ignore_flit_seq_num<= 8'b0;
        o_start_replay           <= 1'b0;
    end
    else if (!init) begin
        o_log_uie                <= 1'b0;
        o_flit_replay_num        <= 3'b0;
        o_ackd_flit_seq_num      <= 8'b0;
        o_tx_replay_flit_seq_num <= 8'b0;
        o_nak_ignore_flit_seq_num<= 8'b0;
        o_start_replay           <= 1'b0;
    end
    else begin
        o_start_replay <= 1'b0;
        o_log_uie      <= 1'b0;
        if(!i_crc_error) begin
            if ((i_replay_command == ack || i_replay_command == nak)) begin
                if (i_seq_num == 8'b0) begin
                    // ignore ack/nak
                end
                else if (!valid_sequence_number(i_seq_num)) begin
                    o_log_uie <= 1'b1;
                    // ignore ack/nak
                end
                else begin // valid ack/nak
                    if ((i_seq_num - i_ackd_flit_seq_num) % 255 > 0) begin
                        o_flit_replay_num <= 3'b0;
                        o_ackd_flit_seq_num <= i_seq_num;
                    end
                    // pruge retry buffer 
                end
                if (i_replay_command == ack) begin // valid ack
                    o_nak_ignore_flit_seq_num <= 0;
                    if(((i_seq_num - i_tx_replay_flit_seq_num) % 255) < MAX_UNACKNOWLEDGED_FLITS)
                        o_tx_replay_flit_seq_num <= 0;
                end
                else begin // valid nak
                    if (i_seq_num == (i_next_tx_flit_seq_num - 1)) begin
                        o_nak_ignore_flit_seq_num <= i_seq_num;
                    end else if (i_seq_num != i_nak_ignore_flit_seq_num) begin 
                        o_nak_ignore_flit_seq_num <= 0;
                    end
                    o_start_replay <= 1'b1;  // schedule a replay as neccessary
                end
            end
        end
    end
end

function automatic valid_sequence_number(input [7:0] seq_num);
    return ((i_next_tx_flit_seq_num - 1) - seq_num) % 255 <= MAX_UNACKNOWLEDGED_FLITS &&
           (seq_num - i_ackd_flit_seq_num) % 255 <= MAX_UNACKNOWLEDGED_FLITS;
endfunction

endmodule