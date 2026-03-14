// =================================================================================================
//  FILENAME    : uc_tx_rdi_cntrl.sv
//  MODULE      : uc_tx_rdi_cntrl
//  PROJECT     : UCIe 3.0 Adapter Layer
//  AUTHORS     : Ashraf Sherif, Shahd Mohamed
// =================================================================================================
//  DESCRIPTION :
//    RDI Transmit Controller (TX Path).
//    This module arbitrates between multiple request sources (MSG, Remote, FDI)
//    and forwards the selected packet to the RDI interface according to the
//    defined priority scheme (MSG > Remote > FDI).
//    The controller serializes 128-bit packets into parameterized lp_cfg phases
//    (8/16/32-bit supported), manages transmission counters, and ensures proper
//    credit-based flow control before issuing requests to RDI.
//    It also handles the wake-up handshake with the LSM block, requests RDI wake
//    when needed, and decrements the physical buffer credit upon successful
//    packet transmission completion.
// =================================================================================================
module tx_rdi_controller #(
    parameter NC = 32 
 ) ( 
    input  logic                           i_clk,
    input  logic                           i_rstn,             // hardware reset >> active low
    input  logic                           i_init_n,           // Software reset >> active low
    /*Interface with Rdi fifo */
    input logic [127 : 0]                  i_fdi_pkt,          // FDI Request
    input logic                            i_fdi_length,       // FDI Request length 128 or 64 bit
    input logic                            i_fdi_valid,        // FDI request Valid
    output logic                           o_fdi_sent,         // done to FDI controller       
    /*Interface with msg fifo */
    input logic [127 : 0]                  i_msg_pkt,          // msg from msg controller
    input logic                            i_msg_length,       // type of the msg 128 or 64 bit
    input logic                            i_msg_valid,        // msg valid
    output logic                           o_msg_sent,         // assert read enable
    /*Interface with msg controller */
    output logic                           o_msg_is_req,       // start to msg controller
   /*Interface with Mailbox controller and remtoe die controller */
    input logic [127 : 0]                  i_remote_pkt,       // remote controller request or comp
    input logic                            i_remote_length,    // remote request type
    input logic                            i_remote_valid,     // remote request valid
    output logic                           o_remote_sent,      // signal to enable remote req timer
    /*Interface with remtoe die controller */
    `ifdef END_POINT
    input logic                            i_remote_comp,      // signal to check if the pky is completion
    `endif
    /*Interface with Rdi */
    output logic [NC-1 : 0 ]               o_lp_cfg,           // output to RDI
    output logic                           o_lp_cfg_vld,       // Valid signal to RDI
    /*Interface with Credit loop */
    input logic                            i_stall_tx,
    output logic                           o_decrease_counter
	);
 //================================================ PARAM & ENUMS ====================================================
    localparam TX_TOTAL_PHASES     = 128 / NC;    // Number of Phases for a 128-bit transfer
    localparam TX_HALF_PHASES      = 64  / NC;    // Number of Phases for a 64-bit transfer  
    
     typedef enum logic {
      TX_STATE_IDLE,
      TX_STATE_SEND
     } rdi_ctrl_state;
      rdi_ctrl_state r_current_state , r_next_state ;
 //=================================================== SIGNALS ====================================================
 logic [$clog2(TX_TOTAL_PHASES)-1:0]      r_phase_cnt;            // Counter that count phases
 logic                                    s_phase_cnt_rst;        // reset phase counter
 logic                                    s_phase_cnt_inc;        // increment phase counter
 logic                                    s_phase_last_flag;      // signal indicates that the counter reach max value
 logic                                    s_phase_half_flag;      // signal indicates that the counter reach min value

 logic [TX_TOTAL_PHASES-1:0][NC-1:0]      s_phase_array;          //  Array of phases extracted from the registered packet
 logic [127 : 0]                          r_pkt_tx;               //  register the pkt 
 logic [127 : 0]                          s_pkt_tx;               //  current pkt
 logic                                    r_pkt_length;           //  register the pkt length
 logic                                    s_pkt_length;           //  current pkt length
 logic                                    s_pkt_reg_vld;          //  valid signal to register the pkt 
 //================================================ Register the pkt ====================================================
 always_ff @( posedge i_clk , negedge i_rstn ) begin
    if(~i_rstn) begin
        r_pkt_tx <= 0;
        r_pkt_length <= 0;
    end else if (~i_init_n) begin
        r_pkt_tx <= 0;
        r_pkt_length <= 0;
    end else if (s_pkt_reg_vld) begin
        r_pkt_tx <= s_pkt_tx ;
        r_pkt_length <= s_pkt_length;
    end
 end
 //================================================ Phases Counter ====================================================
 always_ff @( posedge i_clk , negedge i_rstn ) begin
    if(~i_rstn) begin
        r_phase_cnt <= 0 ;
    end else if (~i_init_n) begin
        r_phase_cnt <= 0 ;
    end else if (s_phase_cnt_rst) begin
        r_phase_cnt <= 0 ;
    end else if (s_phase_cnt_inc) begin
        r_phase_cnt <= r_phase_cnt + 1;
    end
 end
 //mapping the 127 bit to parametrized phases
   genvar i;
   generate
        for (i=0; i < 128/NC; i++) begin
            assign s_phase_array[i] = r_pkt_tx[(i+1)*NC - 1 : i*NC];
        end
   endgenerate
 //============================================== RDI Ctrl FSM ===========================================
 always_ff @( posedge i_clk , negedge i_rstn ) begin
    if(~i_rstn) begin
        r_current_state <= TX_STATE_IDLE ;
    end else if (~i_init_n) begin
        r_current_state <= TX_STATE_IDLE ;
    end else begin
        r_current_state <= r_next_state ;
    end
 end
 always_comb begin
    // Default Assignments
    r_next_state          = r_current_state;
    s_pkt_reg_vld         = 0;
    s_pkt_tx              = 0;
    s_pkt_length          = 0;
    s_phase_cnt_rst       = 0;
    s_phase_cnt_inc       = 0;
    o_lp_cfg              = 0;
    o_lp_cfg_vld          = 0;
    o_fdi_sent            = 0;
    o_msg_sent            = 0;
    o_remote_sent         = 0;
    o_decrease_counter    = 0;
    o_msg_is_req          = 0;
    case (r_current_state)
    // ========================================================
    // IDLE STATE
    // ========================================================
    TX_STATE_IDLE: begin
        if(i_msg_valid && ~i_stall_tx) begin
            r_next_state   = TX_STATE_SEND;
            s_pkt_tx       = i_msg_pkt;
            s_pkt_length   = i_msg_length;
            s_pkt_reg_vld  = 1;
            o_msg_sent     = 1;

             if(!i_msg_length)
                o_msg_is_req = i_msg_pkt[64];

        end 
        else if (
                `ifdef END_POINT
                   (i_remote_valid && ~i_stall_tx) || (i_remote_valid && i_remote_comp)
                `else
                     (i_remote_valid && ~i_stall_tx)
                `endif
         ) begin
            r_next_state   = TX_STATE_SEND;
            s_pkt_tx  = i_remote_pkt;
            s_pkt_length     = i_remote_length;
            s_pkt_reg_vld   = 1;
            o_remote_sent  = 1;
        end 
        else if (i_fdi_valid && ~i_stall_tx ) begin
            r_next_state   = TX_STATE_SEND;
            s_pkt_tx  = i_fdi_pkt;
            s_pkt_length     = i_fdi_length;
            s_pkt_reg_vld   = 1;
            o_fdi_sent     = 1;
        end
        else begin
            r_next_state = TX_STATE_IDLE ;
        end
    end
    // ========================================================
    // SEND PACKET STATE
    // ========================================================
     TX_STATE_SEND : begin
        s_phase_cnt_inc = 1 ;
        o_lp_cfg = s_phase_array[r_phase_cnt];
        o_lp_cfg_vld = 1;
        if((s_phase_last_flag && r_pkt_length) || (s_phase_half_flag && !r_pkt_length)) begin
            s_phase_cnt_rst  = 1;
            o_decrease_counter = 1;
            if(i_msg_valid && ~i_stall_tx) begin
                r_next_state = TX_STATE_SEND ;
                s_pkt_tx = i_msg_pkt ;
                s_pkt_length = i_msg_length ;
                s_pkt_reg_vld = 1 ;
                o_msg_sent = 1 ;
                if(!i_msg_length) begin
                    if(i_msg_pkt[64])
                        o_msg_is_req = 1;
                end 
            end else if (
                `ifdef END_POINT
                   (i_remote_valid && ~i_stall_tx) || (i_remote_valid && i_remote_comp)
                `else
                     (i_remote_valid && ~i_stall_tx)
                `endif
                ) begin
                r_next_state = TX_STATE_SEND ;
                s_pkt_tx = i_remote_pkt ;
                s_pkt_length = i_remote_length ;
                s_pkt_reg_vld = 1 ;
                o_remote_sent = 1;
            end else if (i_fdi_valid && ~i_stall_tx) begin
                r_next_state = TX_STATE_SEND ;
                s_pkt_tx = i_fdi_pkt ;
                s_pkt_length    = i_fdi_length ;
                s_pkt_reg_vld = 1 ;
                o_fdi_sent = 1 ;
            end else begin
                r_next_state = TX_STATE_IDLE ;
            end
        end 
    end
  endcase
 end
 //============================================== Flags ===========================================
 assign s_phase_last_flag = (r_phase_cnt == TX_TOTAL_PHASES - 1) ;
 assign s_phase_half_flag = (r_phase_cnt == TX_HALF_PHASES - 1) ;

endmodule