// =================================================================================================
//  FILENAME    : msg_controller_tx.sv
//  MODULE      : msg_controller_tx
//  PROJECT     : UCIe 3.0 Adapter Layer
//  AUTHOR      : Ashraf sherif , Shahd Mohamed
// =================================================================================================
//  DESCRIPTION :
//    Sideband LSM Messages Constructor block.
//    This module is responsible for constructing and forwarding Link State Management (LSM)
//    and optional Error messages to the RDI TX Controller for transmission over the Sideband
//    interface toward the remote link partner.
//
//    The module also passes Parameter Exchange capability messages (with data) to the RDI TX
//    Controller whenever they are received.
//
//  FUNCTIONALITY :
//    - Pass-through of Parameter Exchange capability messages (128-bit messages).
//    - Construct and transmit LSM state transition messages (Req/Resp).
//    - Construct and transmit error messages (Endpoint devices only).
//    - Provide a timer enable pulse when a request message is accepted for transmission.
// =================================================================================================

`define END_POINT
// Sideband State Transition Message Encodings
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

 // Sideband Error Message Encodings
   typedef enum logic [1:0] {
    NONE_ERR, 
    Correctable_Err , 
    NON_FATAL_Err, 
    FATAL_Err
   } sb_error_msg_encoding; 

module msg_controller_tx(

    input   logic               l_clk,                     // clock signal 
    input   logic               rstn,                      // Reset : Active low

    /*Interface with parameter exchange block*/
    input   logic [127 : 0]     tx_msg_with_data,          // input sb pkt 128 bit
    input   logic               tx_msg_with_data_valid,    // valid signal for tx_msg_with_data
    input   logic               PE_done,                   // parameter exchange done 

    /*Interface with RDI cntrl block*/

    input   logic               i_msg_is_req,             // the req is ready to sent over RDI 
    input   logic               i_msgs_fifo_full,         // msgs fifo full
    output  logic [127 : 0]     tx_msg,                   // sb pkt 128 bit  
    output  logic               tx_msg_valid,             // valid signal for tx_msg
    output  logic               tx_msg_length,            // indicate the length of the packet, 128 >> with data
                                                                                           64 >> without data

    /*Interface with Error handler block*/
    `ifdef END_POINT
    input sb_error_msg_encoding   i_err_msg,             // Error msgs encoding
    `endif
    /*Interface with LSM block*/
    input sb_state_msg_encoding  i_lsm_msg,              // lsm msgs encoding
    /*Interface with Rx msg controller block */
    output logic                 msg_timer_enable        // signal to enable the timer after sending the request (msg) over rdi

);


    typedef enum bit {    
     SB_BEFORE_PARAM_EXCH,
     SB_AFTER_PARAM_EXCH
    } msg_controller_tx_fsm;

    msg_controller_tx_fsm lsm_msgs_pr, lsm_msgs_nxt;


 // State Transition
    always @(posedge l_clk or negedge rstn) begin : State_Transition_proc
        if (!rstn) begin
            lsm_msgs_pr <= SB_BEFORE_PARAM_EXCH;
        end
        else begin
            lsm_msgs_pr <= lsm_msgs_nxt;
        end
    end
    
/* =============================================================================================== */

    // Next state logic
    always_comb begin : Next_State_Logic_proc
        case (lsm_msgs_pr)
            SB_BEFORE_PARAM_EXCH: begin
                if (PE_done)
                    lsm_msgs_nxt = SB_AFTER_PARAM_EXCH;
                else 
                    lsm_msgs_nxt = SB_BEFORE_PARAM_EXCH;
            end
            
            SB_AFTER_PARAM_EXCH: begin
                    lsm_msgs_nxt = SB_AFTER_PARAM_EXCH;
            end
            
            default: lsm_msgs_nxt = SB_BEFORE_PARAM_EXCH;
        endcase
    end


/* =============================================================================================== */

    // Output logic
    
    assign msg_timer_enable = i_msg_is_req;       // Enable timer when the the message is sent over RDI 

    always_comb begin : Output_Logic
        
        tx_msg      = 'b0;
        tx_msg_valid  = 'b0;
        tx_msg_length = 'b0;  
        
        if (lsm_msgs_pr == SB_BEFORE_PARAM_EXCH) begin
            
            if( tx_msg_with_data_valid && !i_msgs_fifo_full) begin   // Passing the Capability msgs whenever it received 
                
                tx_msg         = tx_msg_with_data;
                tx_msg_valid   = 1'b1;
                tx_msg_length  = 1'b1;   // Msg With data -> 4 Phases
            
            end
            
            `ifdef END_POINT
            
            else if (PE_done && !i_msgs_fifo_full) begin
                // Sending the NOP.crd Msg to the RP to inform that EP has an e2e credit for any remote register access request.
                tx_msg = {64'h0, 64'h05000100_20000012};
                tx_msg_valid  = 1'b1;
                tx_msg_length = 1'b0;   // Msg Without data -> 2 Phases
            
            end
            
            `endif
        
        end
        
        else begin           // Constructing the LSM Messages and pass it to the RDI Tx Controller 
        
            
            if (i_lsm_msg!= NONE && !i_msgs_fifo_full) begin
                
                tx_msg_valid  = 1'b1;
                tx_msg_length = 1'b0;   // Msg Without data -> 2 Phases
                
                case(i_lsm_msg) 
                    
                    ACTIVE_REQ     : tx_msg = {64'h1,64'h05000001_2000C012}; // 1 >> msg is request
                    L1_REQ         : tx_msg = {64'h1,64'h05000004_2000C012};
                    L2_REQ         : tx_msg = {64'h1,64'h05000008_2000C012};
                    LINKRESET_REQ  : tx_msg = {64'h1,64'h45000009_2000C012};
                    DISABLED_REQ   : tx_msg = {64'h1,64'h4500000C_2000C012};

                    ACTIVE_RESP    : tx_msg = {64'h0,64'h45000001_20010012}; // 1 >> msg is response
                    PMNAK_RESP     : tx_msg = {64'h0,64'h45000002_20010012};    
                    L1_RESP        : tx_msg = {64'h0,64'h45000004_20010012};
                    L2_RESP        : tx_msg = {64'h0,64'h45000008_20010012};    
                    LINKRESET_RESP : tx_msg = {64'h0,64'h05000009_20010012};
                    DISABLED_RESP  : tx_msg = {64'h0,64'h0500000C_20010012};

                endcase
        
            end
   
           `ifdef END_POINT
            
            if (i_err_msg!= NONE_ERR && !i_msgs_fifo_full) begin     // Give a priority for the Err msgs for the EP device if there are two msgs needs to be sent.
               
                tx_msg_valid  = 1'b1;
                tx_msg_length = 1'b0;   // Msg Without data -> 2 Phases
                
                case(i_err_msg)                  
                    Correctable_Err        : tx_msg = {64'h0,64'h45000000_20024012};
                    NON_FATAL_Err          : tx_msg = {64'h0,64'h05000001_20024012};
                    FATAL_Err              : tx_msg = {64'h0,64'h05000002_20024012};              
                endcase
        
            end
            
          `endif       
        end                    
    end

endmodule