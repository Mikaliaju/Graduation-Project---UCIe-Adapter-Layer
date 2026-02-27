import common_pkg::*;

module ack_nak_discard_rules (
    input  logic       i_CRC_ERROR,
    input  phase_t     i_phase,
    input  logic       i_NOP_PAYLOAD_FLIT,
    input  replay_command_t i_REPLAY_COMMAND,
    input  logic [7:0] i_SEQ_NUM,
    input  logic [7:0] i_IMPLICIT_RX_FLIT_SEQ_NUM,
    input  logic [7:0] i_NEXT_EXPECT_RX_FLIT_SEQ_NUM,
    input  logic [7:0] i_TX_ACKNAK_FLIT_SEQ_NUM,
    input  logic       i_enable,
    input  logic       init,
    input  logic       clk, rst,
    output logic       o_log_UIE,
    output logic       o_discard_flit, 
    output logic       o_discard_payload,
    output logic       o_NAK_SCHEDULED,
    output logic       o_NAK_SCHEDULE_TYPE,
    output logic [7:0] o_TX_ACKNAK_FLIT_SEQ_NUM,
    output logic [7:0] o_NEXT_EXPECT_RX_FLIT_SEQ_NUM
);

logic r_CRC_ERROR_d;
logic r_NOP_PAYLOAD_FLIT_d;
logic r_SEQ_NUM_d; 
logic r_REPLAY_COMMAND_d;

always_ff @ (posedge clk) begin
    if(rst) begin
        r_CRC_ERROR_d <= 0;
        r_NOP_PAYLOAD_FLIT_d <= 0;
        r_SEQ_NUM_d <= 0;
        r_REPLAY_COMMAND_d <= 0;
    end
    else begin
        r_CRC_ERROR_d <= i_CRC_ERROR;
        r_NOP_PAYLOAD_FLIT_d <= i_NOP_PAYLOAD_FLIT;
        r_SEQ_NUM_d <= i_SEQ_NUM;
        r_REPLAY_COMMAND_d <= i_REPLAY_COMMAND;
    end
end

always_ff @ (posedge clk) begin
    if(i_enable) begin
        if(rst) begin
            o_log_UIE <= 1'b0;
            o_discard_flit <= 1'b0;
            o_discard_payload <= 1'b0;
            o_NAK_SCHEDULED <= 1'b0;
            o_NAK_SCHEDULE_TYPE <= 1'b0;
            o_TX_ACKNAK_FLIT_SEQ_NUM <= 8'b0;
            o_NEXT_EXPECT_RX_FLIT_SEQ_NUM <= 8'b0;
        end
        else begin
            if(!init) begin
                if(r_CRC_ERROR_d) begin
                    if(o_NAK_SCHEDULED) begin
                        FLIT_DISCARD_1();
                    end
                    else begin 
                        NAK_SCHEDULE_0();
                    end
                end
                else if(r_REPLAY_COMMAND_d == explicit 
                && i_phase == normal_exchange && r_SEQ_NUM_d == 8'b0) begin
                    FLIT_DISCARD_2();
                end
                else begin
                    if(!r_NOP_PAYLOAD_FLIT_d) begin
                        if(bad_nop_sequence_number()) begin
                            NAK_SCHEDULE_2();
                        end
                        else begin
                            FLIT_DISCARD_0();
                        end
                    end
                    else begin
                        if(o_NAK_SCHEDULED) begin
                            standard_nak_procedure();
                        end
                        else begin
                            if(duplicate_sequence_number()) FLIT_DISCARD_0();
                            else if(bad_sequence_number()) NAK_SCHEDULE_2();
                            else ACK_SCHEDULE_0();
                        end
                    end
                end
            end
        end
    end
end

function bad_sequence_number();
    return (o_NEXT_EXPECT_RX_FLIT_SEQ_NUM - i_IMPLICIT_RX_FLIT_SEQ_NUM) % 255 > 127;
endfunction

function bad_nop_sequence_number();
    return bad_sequence_number() || (i_IMPLICIT_RX_FLIT_SEQ_NUM == i_NEXT_EXPECT_RX_FLIT_SEQ_NUM);
endfunction

function duplicate_sequence_number();
    return ((i_TX_ACKNAK_FLIT_SEQ_NUM - i_IMPLICIT_RX_FLIT_SEQ_NUM) % 255 < 127);
endfunction

task standard_nak_procedure();
    if (duplicate_sequence_number()) begin
        if (o_NAK_SCHEDULED) begin
            FLIT_DISCARD_0();
        end
        else begin
            NAK_SCHEDULE_2();
        end
    end
    else if ((i_REPLAY_COMMAND == explicit) &&
        (i_IMPLICIT_RX_FLIT_SEQ_NUM == i_NEXT_EXPECT_RX_FLIT_SEQ_NUM)) begin
		    ACK_SCHEDULE_1();
	    end
	    else begin
		    if (o_NAK_SCHEDULED) begin
		        FLIT_DISCARD_0();
		    end
		    else begin
		        NAK_SCHEDULE_2();
		end
    end
endtask

    task automatic ACK_SCHEDULE_0();
        o_TX_ACKNAK_FLIT_SEQ_NUM <= i_NEXT_EXPECT_RX_FLIT_SEQ_NUM;
        o_NEXT_EXPECT_RX_FLIT_SEQ_NUM <= i_NEXT_EXPECT_RX_FLIT_SEQ_NUM + 1;
    endtask
    task automatic ACK_SCHEDULE_1();
        o_TX_ACKNAK_FLIT_SEQ_NUM <= i_IMPLICIT_RX_FLIT_SEQ_NUM;
        o_NEXT_EXPECT_RX_FLIT_SEQ_NUM <= i_IMPLICIT_RX_FLIT_SEQ_NUM - 1;
    endtask
    task automatic NAK_SCHEDULE_0();
        o_discard_flit <= 1'b1;
        o_NAK_SCHEDULED <= 1'b1;
        o_NEXT_EXPECT_RX_FLIT_SEQ_NUM <= i_NEXT_EXPECT_RX_FLIT_SEQ_NUM;
    endtask
    task automatic NAK_SCHEDULE_2();
        o_discard_payload <= 1'b1;
        o_TX_ACKNAK_FLIT_SEQ_NUM <= i_NEXT_EXPECT_RX_FLIT_SEQ_NUM - 1;
        o_NAK_SCHEDULED <= 1'b1;
        o_NAK_SCHEDULE_TYPE <= STANDARD_NAK;
        o_NEXT_EXPECT_RX_FLIT_SEQ_NUM <= i_NEXT_EXPECT_RX_FLIT_SEQ_NUM;
    endtask 
    task automatic FLIT_DISCARD_0();
        o_discard_payload <= 1'b1;
        o_NEXT_EXPECT_RX_FLIT_SEQ_NUM <= i_NEXT_EXPECT_RX_FLIT_SEQ_NUM;
    endtask
    task automatic FLIT_DISCARD_1();
        o_discard_flit <= 1'b1;
        o_NEXT_EXPECT_RX_FLIT_SEQ_NUM <= i_NEXT_EXPECT_RX_FLIT_SEQ_NUM;
    endtask
    task automatic FLIT_DISCARD_2();
        o_discard_flit <= 1'b1;
        o_NEXT_EXPECT_RX_FLIT_SEQ_NUM <= i_NEXT_EXPECT_RX_FLIT_SEQ_NUM;
        o_log_UIE <= 1'b1;
    endtask 
    
endmodule