import common_pkg::*;

module transmitting_rules_v1 (
    input logic             clk, rst_n,
    input phase_t           i_phase,
    input  logic            init,
    input  logic            i_replay_scheduled,
    input  [2:0]            consecutive_tx_explicit_seq_num,
    input  logic            i_nak_scheduled,
    input data_rate_t       data_rate,
    input  nak_schedule_type_t i_nak_schedule_type,
    input  [7:0]            i_tx_acknak_flit_seq_num,
    output replay_command_t o_replay_command,
    output logic            o_deassert_pl_trdy,
    output logic            o_nop_payload_flit,
    output [7:0]            o_flit_seq_num
);

assign nop_payload_flit = deassert_pl_trdy ? 1'b1 : 1'b0;
logic state_t present_state, next_state;

always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        present_state <= IDLE;
    end
    else if(!init) begin
        present_state <= IDLE;
    end
    else begin
        present_state <= next_state;
    end
end

always_comb begin
    case(present_state) 
        IDLE : begin
            o_flit_seq_num = 1;
            o_replay_command = explicit;
            deassert_pl_trdy = 1'b1; //deassert pl_trdy
            nop_payload_flit = 1'b1; //nop flit 
            next_tx_flit_seq_num = 1;
            if(i_phase == sequence_number_handshake) begin
                next_state = sequence_number_handshake;
            end
            else 
                next_state = IDLE;
        end
        sequence_number_handshake : begin
            o_flit_replay_num = 255;
            o_replay_command = explicit;
            deassert_pl_trdy = 1'b1;
            o_nop_payload_flit = 1'b1;
            if(FDI_active) begin
                next_state = sequence_number_handshake_fdi_active;
                deassert_pl_trdy = 1'b0; //assert pl_trdy
                next_tx_flit_seq_num = 1;
            end
            else 
                next_state = sequence_number_handshake;
        end
        sequence_number_handshake_fdi_active : begin
            if(!i_replay_scheduled) begin
                    if(consecutive_tx_explicit_seq_num < 1) begin
                        o_replay_command <= explicit;
                        if(nop_payload_flit) begin
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
                        if(!nop_payload_flit) begin
                            next_tx_flit_seq_num <= next_tx_flit_seq_num + 1;
                        end
                    end
                    else begin
                        o_replay_command <= ack;
                        o_flit_seq_num <= i_tx_acknak_flit_seq_num;
                        if(!nop_payload_flit) begin
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
            if(i_phase == normal_exchange) begin
                next_state = normal_exchange;
            end
            else
                next_state = sequence_number_handshake_fdi_active;   
        normal_exchange : begin
            if(normal_exchange_explicit_condition()) begin
                    o_replay_command <  = explicit;
                    if(!i_replay_scheduled) begin
                        if(nop_payload_flit) begin
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
                else if(i_nak_scheduled && i_nak_schedule_type == standard_nak && consecutive_tx_nak_flits < 3) begin
                    o_replay_command <= nak;
                    o_flit_seq_num <= i_tx_acknak_flit_seq_num;
                    consecutive_tx_nak_flits <= consecutive_tx_nak_flits + 1;
                    if(!nop_payload_flit) begin
                        next_tx_flit_seq_num <= next_tx_flit_seq_num + 1;
                    end
                end
                else begin
                    o_replay_command <= ack;
                    o_flit_seq_num <= i_tx_acknak_flit_seq_num;
                    if(!nop_payload_flit) begin
                        next_tx_flit_seq_num <= next_tx_flit_seq_num + 1;
                    end
                end    
                if(i_phase == idle)   
                    next_state = IDLE;
                else
                    next_state = normal_exchange;
            end      
        endcase
    end


function normal_exchange_explicit_condition()
    if(i_replay_scheduled || o_replay_in_progress || consecutive_tx_explicit_seq_num > 0) begin
        if(i_replay_scheduled && o_replay_in_progress && i_nak_ignore_flit_seq_num != 'b000) begin
            if(consecutive_tx_explicit_seq_num < 1 && (consecutive_tx_nak_flits > 2 || consecutive_tx_nak_flits == 0)) begin
                return 1;
            end
        end
    end
endfunction

task automatic flit_replay_transmit_0();
    if(!(i_replay_flit_num >= 3'b110)) begin
        if(!o_replay_in_progress && replay_schedule_type == standard_replay) begin
            if((consecutive_tx_nak_flits >= 2 || consecutive_tx_nak_flits == 0) && data_rate <= GTs_32) begin
                o_deassert_pl_trdy <= 1'b1; //deassert pl_trdy
                o_replay_in_progress <= 1'b1;
                o_flit_seq_num <= i_replayed_flit_seq_num;
                o_flit_replay_num <= i_flit_replay_num + 2;
            end
        end
        if(i_replayed_finished) begin
            o_replay_in_progress <= 1'b0;
            o_deassert_pl_trdy <= 1'b0; //assert pl_trdy
        end
    end
endtask

endmodule