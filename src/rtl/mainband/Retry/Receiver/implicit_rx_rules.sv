//Author : Fatma Fawzy
//Module Description : update the implicit sequence number
//Date : 28/2/2026
import common_pkg::*;

module implicit_rx_rules (
    input  logic [7:0] i_SEQ_NUM, // Sequence number of the received flit
    input  logic       i_CRC_ERROR, // CRC error in the received flit from Mainband Receiver
    input  replay_command_t i_REPLAY_COMMAND, // ACK OR NAK OR EXPLICIT
    input  logic       i_NOP_PAYLOAD_FLIT, // 1 : NOP, 0 : Payload
    input  logic       init, //software reset
    input  logic       clk, rst_n,
    output logic [7:0] o_IMPLICIT_RX_FLIT_SEQ_NUM //implicit sequence number (new)  
);

logic r_NON_IDLE_EXPLICIT_SEQ_NUM_FLIT_RCVD;

always_ff @ (posedge clk or negedge rst_n) begin
    if(rst_n) begin
        o_IMPLICIT_RX_FLIT_SEQ_NUM <= 8'b0;
        r_NON_IDLE_EXPLICIT_SEQ_NUM_FLIT_RCVD <= 1'b0;
    end
    else begin
        if(!init) begin
            if(!i_CRC_ERROR && i_REPLAY_COMMAND == explicit && i_SEQ_NUM != 8'b0) begin
                o_IMPLICIT_RX_FLIT_SEQ_NUM <= i_SEQ_NUM;
                r_NON_IDLE_EXPLICIT_SEQ_NUM_FLIT_RCVD <= 1'b1;
            end
            else if(r_NON_IDLE_EXPLICIT_SEQ_NUM_FLIT_RCVD) begin
                if((i_NOP_PAYLOAD_FLIT && !i_CRC_ERROR && i_SEQ_NUM != 8'b0 
                && i_REPLAY_COMMAND != explicit) || i_CRC_ERROR) begin
                    o_IMPLICIT_RX_FLIT_SEQ_NUM <= o_IMPLICIT_RX_FLIT_SEQ_NUM + 1;
                end
            end
        end
    end
end


endmodule