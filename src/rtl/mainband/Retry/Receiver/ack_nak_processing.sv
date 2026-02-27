import common_pkg::*;

module ack_nak_proccessing (
    input  replay_command_t i_REPLAY_COMMAND,
    input  logic [7:0] i_SEQ_NUM,
    input  logic [7:0] i_TX_ACKNAK_FLIT_SEQ_NUM,
    input  logic [7:0] i_ACKD_FLIT_SEQ_NUM,
    input  logic       init,
    input  logic       i_enable,
    input  logic       clk, rst,
    output logic       o_valid_ack_nak, 
    output logic       o_valid,
    output logic       o_log_UIE,
    output logic [7:0] o_N
);

always_ff @ (posedge clk) begin
    if(i_enable) begin
        if(rst) begin
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
end

function valid_sequence_number(input [7:0] SEQ_NUM);
    return ((i_TX_ACKNAK_FLIT_SEQ_NUM - 1) - SEQ_NUM) % 255 <= MAX_UNACKNOWLEDGED_FLITS && 
   (SEQ_NUM - i_ACKD_FLIT_SEQ_NUM) % 255 <= MAX_UNACKNOWLEDGED_FLITS;
endfunction

endmodule