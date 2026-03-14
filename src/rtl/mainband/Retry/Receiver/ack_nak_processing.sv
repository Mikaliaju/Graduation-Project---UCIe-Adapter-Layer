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
    output logic            o_valid_ack_nak,            // valid ack/nak
    output logic            o_valid,                    // valid ack/nak
    output logic            o_log_uie,                  // log uncorrectable internal error in register file
    output logic [7:0]      o_received_valid_seq_num    // sequence number of the received valid ack/nak flit
);

always_ff @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        o_valid_ack_nak          <= 1'b0;
        o_log_uie                <= 1'b0;
        o_received_valid_seq_num <= 8'b0;
        o_valid                  <= 1'b0;
    end
    else if (!init) begin
        o_valid_ack_nak          <= 1'b0;
        o_log_uie                <= 1'b0;
        o_received_valid_seq_num <= 8'b0;
        o_valid                  <= 1'b0;
    end
    else begin
        if ((i_replay_command == ack || i_replay_command == nak)) begin
            if (i_seq_num == 8'b0) begin
                // ignore ack/nak
            end
            else if (!valid_sequence_number(i_seq_num)) begin
                o_log_uie <= 1'b1;
                // ignore ack/nak
            end
            else begin
                o_valid_ack_nak          <= 1'b1;
                o_valid                  <= 1'b1;
                o_received_valid_seq_num <= i_seq_num;
            end
        end
    end
end

function automatic valid_sequence_number(input [7:0] seq_num);
    return ((i_tx_acknak_flit_seq_num - 1) - seq_num) % 255 <= MAX_UNACKNOWLEDGED_FLITS &&
           (seq_num - i_ackd_flit_seq_num) % 255 <= MAX_UNACKNOWLEDGED_FLITS;
endfunction

endmodule