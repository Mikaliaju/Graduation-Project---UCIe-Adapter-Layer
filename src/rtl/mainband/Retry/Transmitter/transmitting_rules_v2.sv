import common_pkg::*;

module transmitting_order (
    input logic             clk, rst_n,
    input phase_t           phase,
    input  logic            init,
    input  logic            i_replay_scheduled,
    input  [2:0]            consecutive_tx_explicit_seq_num,
    input  logic            i_nak_scheduled,
    input  nak_schedule_type_t i_nak_schedule_type,
    input  [7:0]            i_tx_acknak_flit_seq_num,
    output replay_command_t o_replay_command,
    output logic            o_pl_trdy_control,
    output logic            o_nop_payload_flit,
    output [7:0]            o_flit_seq_num
);

logic [1:0] consecutive_tx_nak_flits;
logic [7:0] next_tx_flit_seq_num;

always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        o_replay_command <= explicit;
        o_flit_seq_num <= 'b0;
        next_tx_flit_seq_num <= 'b0;
        consecutive_tx_nak_flits <= 'b0;
    end
    else if(!init) begin
        case(phase) 
            sequence_number_handshake : begin
                if(!i_replay_scheduled) begin
                    if(consecutive_tx_explicit_seq_num < 1) begin
                        o_replay_command <= explicit;
                        if(o_nop_payload_flit) begin
                            o_flit_seq_num <= next_tx_flit_seq_num - 1;
                        end
                        else begin
                            o_flit_seq_num <= next_tx_flit_seq_num;
                            next_tx_flit_seq_num <= next_tx_flit_seq_num + 1;
                        end
                    end
                    else if(i_nak_scheduled && i_nak_schedule_type == standard_nak) begin
                        o_replay_command <= nak;
                        o_flit_seq_num <= i_tx_acknak_flit_seq_num;
                        if(!o_nop_payload_flit) begin
                            next_tx_flit_seq_num <= next_tx_flit_seq_num + 1;
                        end
                    end
                    else begin
                        o_replay_command <= ack;
                        o_flit_seq_num <= i_tx_acknak_flit_seq_num;
                        if(!o_nop_payload_flit) begin
                            next_tx_flit_seq_num <= next_tx_flit_seq_num + 1;
                        end
                    end
                end
                else begin
                    if(consecutive_tx_explicit_seq_num < 1) begin
                        flit_replay_transmit_0();
                    end
                end
            end
            normal_exchange : begin
                if(normal_exchange_explicit_condition()) begin
                    o_replay_command <  = explicit;
                    if(!i_replay_scheduled) begin
                        if(o_nop_payload_flit) begin
                            o_flit_seq_num <= next_tx_flit_seq_num - 1; 
                        end
                        else begin
                            o_flit_seq_num <= next_tx_flit_seq_num;
                            next_tx_flit_seq_num <= next_tx_flit_seq_num + 1;
                        end
                    end
                    else
                        flit_replay_transmit_0();
                end
                else if(i_nak_scheduled && i_nak_schedule_type == standard_nak) begin
                    o_replay_command <= nak;
                    o_flit_seq_num <= i_tx_acknak_flit_seq_num;
                    consecutive_tx_nak_flits <= consecutive_tx_nak_flits + 1;
                    if(!o_nop_payload_flit) begin
                        next_tx_flit_seq_num <= next_tx_flit_seq_num + 1;
                    end
                end
                else begin
                    o_replay_command <= ack;
                    o_flit_seq_num <= i_tx_acknak_flit_seq_num;
                    if(!o_nop_payload_flit) begin
                        next_tx_flit_seq_num <= next_tx_flit_seq_num + 1;
                    end
                end       
            end
        endcase
    end
end


task automatic flit_replay_transmit_0();
    if(!(i_replay_flit_num >= 3'b110)) begin
        if(!o_replay_in_progress && replay_schedule_type == standard_replay) begin
            if((consecutive_tx_nak_flits >= 2 || consecutive_tx_nak_flits == 0) && DATA_RATE <= 32GT/s) begin
                o_pl_trdy_control <= 1'b1; //deassert pl_trdy
                o_replay_in_progress <= 1'b1;
                o_flit_seq_num <= i_replayed_flit_seq_num;
                o_flit_replay_num <= i_flit_replay_num + 2;
            end
        end
    end
endtask

function normal_exchange_explicit_condition()
    if(i_replay_scheduled || o_replay_in_progress || consecutive_tx_explicit_seq_num > 0) begin
        if(i_replay_scheduled && o_replay_in_progress && i_nak_ignore_flit_seq_num != 'b000) begin
            if(consecutive_tx_explicit_seq_num < 1 && (consecutive_tx_nak_flits > 2 || consecutive_tx_nak_flits == 0)) begin
                return 1;
            end
        end
    end
endfunction

endmodule