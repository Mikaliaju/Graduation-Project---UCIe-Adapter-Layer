//Author : Fatma Fawzy
//Module Description : process the received ACK/NAK flits to get valid ones
//Date : 28/2/2026
import common_pkg::*;

module ack_nak_proccessing (
    input  replay_command_t i_REPLAY_COMMAND, // ACK OR NAK OR EXPLICIT
    input  logic [7:0] i_SEQ_NUM, // Sequence number of the received flit
    input  logic [7:0] i_TX_ACKNAK_FLIT_SEQ_NUM, // TX ACKNAK flit from counter tracker (old)
    input  logic [7:0] i_ACKD_FLIT_SEQ_NUM, // ACKD flit from counter tracker (old)
    input  logic       init, //software reset
    input  logic       clk, rst_n,
    output logic       o_valid_ack_nak, //valid ack/nak
    output logic       o_valid, //valid ack/nak
    output logic       o_log_UIE, //log Uncorrectable Internal Error in Register file
    output logic [7:0] o_N //sequence number of the received valid ack/nak flit
);

always_ff @ (posedge clk or negedge rst_n) begin
    if(rst_n) begin
        o_valid_ack_nak <= 1'b0;
        o_log_UIE <= 1'b0;
        o_N <= 8'b0;
        o_valid <= 1'b0;
    end
    else begin
        if(!init) begin
            if((i_REPLAY_COMMAND == ACK || i_REPLAY_COMMAND == NAK)) begin
                if(i_SEQ_NUM == 8'b0) begin 
                    //ignore ack/nak
                end
                else if(!valid_sequence_number(i_SEQ_NUM)) begin 
                    o_log_UIE = 1'b1;
                    //ignore ack/nak
                end
                else begin
                    o_valid_ack_nak = 1'b1;
                    o_valid = 1'b1;
                    o_N = i_SEQ_NUM;
                end
            end
        end
    end
end

function valid_sequence_number(input [7:0] SEQ_NUM);
    return ((i_TX_ACKNAK_FLIT_SEQ_NUM - 1) - SEQ_NUM) % 255 <= MAX_UNACKNOWLEDGED_FLITS && 
   (SEQ_NUM - i_ACKD_FLIT_SEQ_NUM) % 255 <= MAX_UNACKNOWLEDGED_FLITS;
endfunction

endmodule