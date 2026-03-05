//author : fatma fawzy
//module description : update the implicit sequence number
//date : 28/2/2026
import common_pkg::*;

module implicit_rx_rules (
    input  logic [7:0] i_seq_num, // sequence number of the received flit
    input  logic       i_crc_error, // crc error in the received flit from mainband receiver
    input  replay_command_t i_replay_command, // ack or nak or explicit
    input  logic       i_nop_payload_flit, // 1 : nop, 0 : payload
    input  logic       init, //software reset
    input  logic       clk, rst_n,
    output logic [7:0] o_implicit_rx_flit_seq_num //implicit sequence number (new)  
);

logic r_non_idle_explicit_seq_num_flit_rcvd;

always_ff @ (posedge clk or negedge rst_n) begin
    if(rst_n) begin
        o_implicit_rx_flit_seq_num <= 8'b0;
        r_non_idle_explicit_seq_num_flit_rcvd <= 1'b0;
    end
    else begin
        if(!init) begin
            if(!i_crc_error && i_replay_command == explicit && i_seq_num != 8'b0) begin
                o_implicit_rx_flit_seq_num <= i_seq_num;
                r_non_idle_explicit_seq_num_flit_rcvd <= 1'b1;
            end
            else if(r_non_idle_explicit_seq_num_flit_rcvd) begin
                if((i_nop_payload_flit && !i_crc_error && i_seq_num != 8'b0 
                && i_replay_command != explicit) || i_crc_error) begin
                    o_implicit_rx_flit_seq_num <= o_implicit_rx_flit_seq_num + 1;
                end
            end
        end
    end
end


endmodule