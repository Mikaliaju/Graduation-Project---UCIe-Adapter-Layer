import UC_retry_pkg::*;

module UC_MB_retry_transmitting_rules (
    input logic             clk, rst_n,
    input  logic            init,
    input  logic            i_snh_done,
    input logic             i_snh_timeout,
    input  logic            i_replay_scheduled,
    input  replay_schedule_type_t i_replay_scheduled_type,
    input  logic            i_nak_scheduled,
    input  nak_schedule_type_t i_nak_schedule_type,
    input logic             i_consecutive_reset,
    input  logic [7:0]     i_tx_acknak_flit_seq_num,
    input  logic            i_tx_en,
    input  logic            i_fdi_active,
    input  data_rate_t      i_data_rate,
    input  logic [2:0]      i_flit_replay_num,
    input  logic [7:0]      i_replayed_flit_seq_num,
    input  logic [7:0]      i_nak_ignore_flit_seq_num,
    output logic [7:0]      o_next_tx_flit_seq_num,
    output replay_command_t o_tx_replay_command,
    output logic            o_pl_trdy_control,
    output flit_type_t      o_tx_flit_type,
    output logic [7:0]     o_tx_seq_num,
    output logic            o_rdi_retrain,
    output logic            o_replay_in_progress,
    output logic [2:0]      o_flit_replay_num,
    output logic            o_log_cie
);


// Phase controller 

phase_t phase;
logic [2:0] consecutive_tx_nak_flits;
logic [7:0] next_tx_flit_seq_num;
logic [2:0] consecutive_tx_explicit_seq_num;

always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        phase <= IDLE;
    end
    else if(!init) begin
        phase <= IDLE;
    end
    else begin
        case(phase)
            IDLE: 
            begin
                o_rdi_retrain <= 1'b0;
                if(i_tx_en) phase <= SNH;
            end
            SNH:  begin
                if(i_fdi_active)     phase <= SNH_FDI_ACTIVE;
                else if(i_snh_done)  phase <= NORMAL_EXCHANGE;
                else if(i_snh_timeout) begin
                    o_rdi_retrain <= 1'b1;
                    phase <= IDLE;
                end
            end
            SNH_FDI_ACTIVE: begin
                if(i_snh_done)       phase <= NORMAL_EXCHANGE;
                else if(i_snh_timeout) begin
                    o_rdi_retrain <= 1'b1;
                    phase <= IDLE;
                end
            end
            NORMAL_EXCHANGE: if(!i_tx_en) phase <= IDLE;
        endcase
    end
end

always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        o_tx_replay_command <= explicit;
        o_tx_seq_num <= 'b0;
        next_tx_flit_seq_num <= 8'b1;
        consecutive_tx_nak_flits <= 'b0;
        consecutive_tx_explicit_seq_num <= 3'b0;
        o_pl_trdy_control <= 1'b0;
        o_replay_in_progress <= 1'b0;
        o_flit_replay_num <= 3'b0;
        o_log_cie <= 1'b0;
        o_rdi_retrain <= 1'b0;
    end
    else if(!init) begin
        o_tx_replay_command <= explicit;
        o_tx_seq_num <= 'b1;
        next_tx_flit_seq_num <= 8'b1;
        consecutive_tx_nak_flits <= 'b0;
        consecutive_tx_explicit_seq_num <= 3'b0;
        o_pl_trdy_control <= 1'b0;
        o_replay_in_progress <= 1'b0;
        o_flit_replay_num <= 3'b0;
        o_log_cie <= 1'b0;
        o_rdi_retrain <= 1'b0;
    end
    else begin
        o_log_cie <= 1'b0;
        // Clear consecutive_tx_explicit_seq_num on consecutive_reset (Replay Schedule Rule 0)
        if (i_consecutive_reset) begin
            consecutive_tx_explicit_seq_num <= 3'b0;
        end
        case(phase) 
            IDLE: begin

            end
            SNH: begin
                o_tx_flit_type <= NOP;
                o_tx_replay_command <= explicit;
                o_tx_seq_num <= 8'b1111_1111; 
                o_pl_trdy_control <= 1'b0;
                consecutive_tx_explicit_seq_num <= consecutive_tx_explicit_seq_num + 1;
            end
            SNH_FDI_ACTIVE : begin
                if(!i_replay_scheduled) begin
                    if(consecutive_tx_explicit_seq_num < 1) begin
                        o_tx_replay_command <= explicit;
                        if(o_tx_flit_type == NOP) begin
                            o_tx_seq_num <= next_tx_flit_seq_num - 1;
                        end
                        else begin
                            o_tx_seq_num <= next_tx_flit_seq_num;
                            next_tx_flit_seq_num <= next_tx_flit_seq_num + 1;
                        end
                    end
                    else if(i_nak_scheduled && i_nak_schedule_type == standard_nak) begin
                        o_tx_replay_command <= nak;
                        o_tx_seq_num <= i_tx_acknak_flit_seq_num;
                        if(o_tx_flit_type != NOP) begin
                            next_tx_flit_seq_num <= next_tx_flit_seq_num + 1;
                        end
                    end
                    else begin
                        o_tx_replay_command <= ack;
                        o_tx_seq_num <= i_tx_acknak_flit_seq_num;
                        if(o_tx_flit_type != NOP) begin
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
            NORMAL_EXCHANGE : begin
                if(normal_exchange_explicit_condition()) begin
                    o_tx_replay_command <= explicit;
                    consecutive_tx_nak_flits <= 3'b0;
                    consecutive_tx_explicit_seq_num <= consecutive_tx_explicit_seq_num + 1;
                    if(i_replay_scheduled && !o_replay_in_progress
                        && consecutive_tx_explicit_seq_num == 3'b000) begin
                        flit_replay_transmit_0();
                    end
                    else begin
                        if(o_tx_flit_type == NOP) begin
                            o_tx_seq_num <= next_tx_flit_seq_num - 1; 
                        end
                        else begin
                            o_tx_seq_num <= next_tx_flit_seq_num;
                            next_tx_flit_seq_num <= next_tx_flit_seq_num + 1;
                        end
                    end
                end
                else if(i_nak_scheduled && i_nak_schedule_type == standard_nak) begin
                    o_tx_replay_command <= nak;
                    o_tx_seq_num <= i_tx_acknak_flit_seq_num;
                    consecutive_tx_nak_flits <= consecutive_tx_nak_flits + 1;
                    if(o_tx_flit_type != NOP) begin
                        next_tx_flit_seq_num <= next_tx_flit_seq_num + 1;
                    end
                end
                else begin
                    o_tx_replay_command <= ack;
                    o_tx_seq_num <= i_tx_acknak_flit_seq_num;
                    consecutive_tx_nak_flits <= 3'b0;
                    if(o_tx_flit_type != NOP) begin
                        next_tx_flit_seq_num <= next_tx_flit_seq_num + 1;
                    end
                end
                // Check for excessive replays — triggers retrain
                flit_replay_transmit_2();
            end
        endcase
    end
end


task automatic flit_replay_transmit_0();
    if(i_flit_replay_num < 3'b110) begin
        if(i_replay_scheduled && !o_replay_in_progress 
            && i_replay_scheduled_type == standard_replay) begin
            if((consecutive_tx_nak_flits >= 2 || consecutive_tx_nak_flits == 0) 
                && i_data_rate == GTs_32) begin
                o_pl_trdy_control <= 1'b1; //deassert pl_trdy
                o_replay_in_progress <= 1'b1;
                o_tx_seq_num <= i_replayed_flit_seq_num;
                o_flit_replay_num <= i_flit_replay_num + 2;
            end
        end
    end
endtask

task automatic flit_replay_transmit_2();
    if (i_replay_scheduled && !o_replay_in_progress) begin
        if (i_data_rate <= GTs_32 && i_flit_replay_num >= 3'b110) begin
          o_flit_replay_num <= i_flit_replay_num + 2;
          o_rdi_retrain <= 1'b1;
          o_log_cie <= 1'b1;
        end
    end
endtask

function automatic logic normal_exchange_explicit_condition();
    if ((i_replay_scheduled || o_replay_in_progress) &&
        (consecutive_tx_explicit_seq_num == 0) &&
        (i_nak_ignore_flit_seq_num != 8'h00)) begin
        if (consecutive_tx_explicit_seq_num < 1 && 
            (consecutive_tx_nak_flits == 0 || consecutive_tx_nak_flits > 2))
            return 1;
    end
    return 0;
endfunction

assign o_next_tx_flit_seq_num = next_tx_flit_seq_num;

endmodule