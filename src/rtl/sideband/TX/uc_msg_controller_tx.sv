// =================================================================================================
//  FILENAME    : uc_msg_controller_tx.sv
//  MODULE      : uc_msg_controller_tx
//  PROJECT     : UCIe 3.0 Adapter Layer
//  AUTHOR      : Ashraf sherif , Shahd Mohamed
// =================================================================================================
//  DESCRIPTION :
//    Sideband LSM Messages Constructor block.
//    This module is responsible for constructing and forwarding Link State Management (LSM)
//    and optional Error messages to the RDI TX Controller for transmission over the Sideband
//    interface toward the remote link partner.
//    The module also passes Parameter Exchange capability messages (with data) to the RDI TX
//    Controller whenever they are received.
// ================================================================================================

import UC_sb_rx_pkg::*;
/*
typedef enum logic [3:0] {
    NONE,
    ACTIVE_REQ, 
    L1_REQ, 
    L2_REQ, 
    LINKRESET_REQ, 
    DISABLED_REQ, 
    ACTIVE_RESP,
    PMNAK_RESP, 
    L1_RESP, 
    L2_RESP, 
    LINKRESET_RESP, 
    DISABLED_RESP
} sb_state_msg_encoding;
typedef enum logic [1:0] {
    NONE_ERR, 
    Correctable_Err , 
    NON_FATAL_Err, 
    FATAL_Err
} sb_error_msg_encoding; */
module uc_msg_controller_tx(
    input   logic               i_clk,
    input   logic               i_rstn,
    input   logic               i_init_n,
    /*Interface with parameter exchange block*/
    input   logic [127 : 0]     i_tx_msg_with_data,
    input   logic               i_tx_msg_with_data_valid,
    input   logic               i_PE_done,
    /*Interface with RDI cntrl block*/
    input   logic               i_msg_is_req,
    input   logic               i_msgs_fifo_full,
    output  logic [127 : 0]     o_tx_msg,
    output  logic               o_tx_msg_valid,
    output  logic               o_tx_msg_length,
    /*Interface with Error handler block*/
    `ifdef END_POINT
    input sb_error_msg_encoding   i_err_msg,
    `endif
    /*Interface with LSM block*/
    input sb_state_msg_encoding  i_lsm_msg,
    /*Interface with Rx msg controller block */
    output logic                 o_msg_timer_enable
);
typedef enum bit {    
     SB_BEFORE_PARAM_EXCH,
     SB_AFTER_PARAM_EXCH
} msg_controller_tx_fsm;
msg_controller_tx_fsm r_lsm_msgs_pr, s_lsm_msgs_nxt;
// State Transition
always_ff @(posedge i_clk or negedge i_rstn) begin : State_Transition_proc
    if (!i_rstn) begin
        r_lsm_msgs_pr <= SB_BEFORE_PARAM_EXCH;
    end
    else if(!i_init_n) begin
        r_lsm_msgs_pr <= SB_BEFORE_PARAM_EXCH;
    end
    else begin
        r_lsm_msgs_pr <= s_lsm_msgs_nxt;
    end
end
/* =============================================================================================== */
// Next state logic
always_comb begin : Next_State_Logic_proc
    case (r_lsm_msgs_pr)
        SB_BEFORE_PARAM_EXCH: begin
            if (i_PE_done)
                s_lsm_msgs_nxt = SB_AFTER_PARAM_EXCH;
            else 
                s_lsm_msgs_nxt = SB_BEFORE_PARAM_EXCH;
        end
        SB_AFTER_PARAM_EXCH: begin
                s_lsm_msgs_nxt = SB_AFTER_PARAM_EXCH;
        end     
        default: s_lsm_msgs_nxt = SB_BEFORE_PARAM_EXCH;
    endcase
end
/* =============================================================================================== */
// Output logic 
assign o_msg_timer_enable = i_msg_is_req;
                    always_comb begin : Output_Logic

    // Default
    o_tx_msg        = '0;
    o_tx_msg_valid  = 1'b0;
    o_tx_msg_length = 1'b0;

    if (r_lsm_msgs_pr == SB_BEFORE_PARAM_EXCH) begin

        if (i_tx_msg_with_data_valid && !i_msgs_fifo_full) begin
            o_tx_msg         = i_tx_msg_with_data;
            o_tx_msg_valid   = 1'b1;
            o_tx_msg_length  = 1'b1;
        end

        `ifdef END_POINT
        else if (i_PE_done && !i_msgs_fifo_full) begin
            o_tx_msg         = {64'h0, 64'h05000100_20000012};
            o_tx_msg_valid   = 1'b1;
            o_tx_msg_length  = 1'b0;
        end
        `endif

    end
    else begin

        // ✅ PRIORITY: Error > LSM (مهم في البروتوكول)

        `ifdef END_POINT
        if (i_err_msg != NONE_ERR && !i_msgs_fifo_full) begin
            o_tx_msg_valid  = 1'b1;
            o_tx_msg_length = 1'b0;

            case(i_err_msg)
                Correctable_Err : o_tx_msg = {64'h0,64'h45000000_20024012};
                NON_FATAL_Err   : o_tx_msg = {64'h0,64'h05000001_20024012};
                FATAL_Err       : o_tx_msg = {64'h0,64'h05000002_20024012};
                default         : o_tx_msg = '0;
            endcase
        end
        else
        `endif
        if (i_lsm_msg != NONE && !i_msgs_fifo_full) begin

            o_tx_msg_valid  = 1'b1;
            o_tx_msg_length = 1'b0;

            case(i_lsm_msg)
                ACTIVE_REQ     : o_tx_msg = {64'h1,64'h05000001_2000C012};
                L1_REQ         : o_tx_msg = {64'h1,64'h05000004_2000C012};
                L2_REQ         : o_tx_msg = {64'h1,64'h05000008_2000C012};
                LINKRESET_REQ  : o_tx_msg = {64'h1,64'h45000009_2000C012};
                DISABLED_REQ   : o_tx_msg = {64'h1,64'h4500000C_2000C012};

                ACTIVE_RESP    : o_tx_msg = {64'h0,64'h45000001_20010012};
                PMNAK_RESP     : o_tx_msg = {64'h0,64'h45000002_20010012};    
                L1_RESP        : o_tx_msg = {64'h0,64'h45000004_20010012};
                L2_RESP        : o_tx_msg = {64'h0,64'h45000008_20010012};    
                LINKRESET_RESP : o_tx_msg = {64'h0,64'h05000009_20010012};
                DISABLED_RESP  : o_tx_msg = {64'h0,64'h0500000C_20010012};

                default        : o_tx_msg = '0;
            endcase
        end

    end
end
endmodule
