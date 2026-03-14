//author : fatma fawzy
//module description : validate the received ack/nak flits and schedule a replay as neccessary
//date : 10/3/2026
import common_pkg::*;
module valid_ack_nak_processing (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       init, 
    input  logic       i_valid, //works as enable for the system
    input  logic       i_valid_ack_nak,
    input  logic [7:0] i_n,
    input  logic [7:0] i_ackd_flit_seq_num,
    input  logic [7:0] i_tx_replay_flit_seq_num,
    input  logic [7:0] i_next_tx_flit_seq_num,
    input  logic [7:0] i_nak_ignore_flit_seq_num,
    output logic [2:0] o_flit_replay_num,
    output logic [7:0] o_ackd_flit_seq_num,
    output logic [7:0] o_tx_replay_flit_seq_num,
    output logic [7:0] o_nak_ignore_flit_seq_num,
    output logic       o_start_replay
);

always_ff @ (posedge clk) begin
    if(!rst_n) begin
        o_flit_replay_num         <= 3'b0;
        o_ackd_flit_seq_num       <= 8'b0;
        o_tx_replay_flit_seq_num  <= 8'b0;
        o_nak_ignore_flit_seq_num <= 8'b0;
        o_start_replay            <= 1'b0;
    end
    else if(!init) begin
        o_flit_replay_num         <= 3'b0;
        o_ackd_flit_seq_num       <= 8'b0;
        o_tx_replay_flit_seq_num  <= 8'b0;
        o_nak_ignore_flit_seq_num <= 8'b0;
        o_start_replay            <= 1'b0;
    end
    else begin 
        if(i_valid) begin
            if((i_n - i_ackd_flit_seq_num) % 255 > 0) begin
                o_flit_replay_num <= 3'b0;
                o_ackd_flit_seq_num <= i_n;
            end
            if(i_valid_ack_nak) begin // valid ack
                o_nak_ignore_flit_seq_num <= 0;
                if(((i_n - i_tx_replay_flit_seq_num) % 255) < max_unacknowledged_flits)
                    o_tx_replay_flit_seq_num <= 0;
            end
            else begin // valid nak
                if(i_n == (i_next_tx_flit_seq_num - 1)) begin
                    o_nak_ignore_flit_seq_num <= i_n;
                end
                o_start_replay <= 1'b1;  // schedule a replay as neccessary
            end
            if(!i_valid_ack_nak && i_n != i_nak_ignore_flit_seq_num && i_n != (i_next_tx_flit_seq_num - 1)) begin 
                o_nak_ignore_flit_seq_num <= 0;
            end
        end
    end
end

endmodule

