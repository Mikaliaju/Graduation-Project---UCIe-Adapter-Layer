// =================================================================================================
//  FILENAME    : uc_mailbox_controller.sv
//  MODULE      : uc_mailbox_controller
//  PROJECT     : UCIe 3.0 Adapter Layer
//  AUTHOR      : Ashraf sherif , Shahd Mohamed
// =================================================================================================
//  DESCRIPTION :
//    This module is responsible for initiating remote register access requests through the RDI
//    interface based on the Mailbox Trigger mechanism. It generates the remote request packet
//    (header + optional data + parity), forwards it to the RDI TX controller, then waits for the
//    corresponding completion packet from the RX path.
//    The module also implements a timeout mechanism to detect remote access request failures
//    and updates the mailbox status accordingly. A timeout counter is maintained and compared
//    against a programmable threshold; if exceeded, a timeout indication is asserted to the Error handler block.
// =================================================================================================
module uc_mailbox_controller(
  input  logic             i_clk,
  input  logic             i_rstn,
  input  logic             i_init_n,
 /*Interface with REG FILE */
  input  logic [3:0]       i_remote_threshold,     // Max allowed number of timeouts before raising "remote_time_out"
  output logic [63:0]      o_Header_log1,          // Log header for error cases (UR/CA)
  output logic             o_Header_log1_valid,    // Pulse to indicate log is valid
 /*Interface with MAILBOX */
  input  logic             i_mailbox_trigger,      // Mailbox trigger bit
  input  logic [31:0]      i_mailbox_index_low,    // Contains opcode/BE/address lower bits
  input  logic [4:0]       i_mailbox_index_high,   // Upper bits of address
  input  logic [31:0]      i_mailbox_data_low ,    // Payload lower 32b
  input  logic [31:0]      i_mailbox_data_high,    // Payload upper 32b 
  output logic [31:0]      o_mailbox_data_low,     // Completion data low written back to mailbox
  output logic [31:0]      o_mailbox_data_high,    // Completion data high written back to mailbox
  output logic [1:0]       o_mailbox_status,       // Mailbox status encoding (success/UR/CA)
  output logic             o_mailbox_data_vld,     // Indicates mailbox data is valid (success completion)
  output logic             o_mailbox_trigger_en,   // Used to clear trigger after completion/timeout
 /*Interface with RX block*/  
  input  logic [127:0]     i_comp_packet,          // Completion packet from RX
  input  logic             i_comp_packet_vld,      // Completion valid
 /*Interface with RDI controller block*/                    
  input  logic             i_req_sent,             // Comes from RDI: request was accepted/sent
  output logic [127:0]     o_req_pkt,              // Packet to RDI controller
  output logic             o_req_pkt_vld,          // Valid pulse to enqueue/send the request
  output logic             o_pkt_length,           // 1=128b, 0=64b request
 /*Interface with decoder block*/
  output logic [4:0]       o_opcode,               // Opcode extracted for external decoding
  input  logic             i_req_length,           // Desired request length: 1=128b,0=64b
  input  logic             i_32_b,                 // If 128b, choose 32-bit data vs 64-bit data 
 /*Interface with RX block*/
  input  logic             i_e2e_crd_return,       // Indicates E2E credit is available 
 /*Interface with Error handler block*/
  output logic             o_remote_time_out       // Assert when timeout_counter reaches threshold
);
//============================================ PARAM & ENUMS ==============================================
localparam int TIMEOUT_CYCLES = 100 ;

typedef enum logic [1:0] {
  WAIT_FOR_E2E_CRD,   // Wait until E2E credit is available before allowing remote access only for first time
  WAIT_FOR_TRIGG,     // Wait for mailbox trigger bit
  WAIT_FOR_SEND,      // Drive request to RDI until RDI asserts i_req_sent
  WAIT_FOR_COMP       // Wait for completion or timeout
} MAILBOX_FSM ;
MAILBOX_FSM r_pr,s_nxt;
//================================================ SIGNALS ====================================================
// These are the constructed fields for the outgoing request packet
 logic [2:0]   s_src_id,s_dst_id;   // IDs (fixed values)
 logic [4:0]   s_tag;               // transaction tag
 logic [4:0]   s_opcode;            // opcode field 
 logic [7:0]   s_be;                // byte enable
 logic [23:0]  s_address;           // remote address field
 logic         s_dp,s_cp;           // data parity, control parity
 logic [63:0]  s_data;              // request payload for 128b request (or 0 for 64b)
 logic [61:0]  s_header;            // header without parity bits 

// TIMEOUT COUNTERS
 logic [$clog2(TIMEOUT_CYCLES)-1:0] r_cycles_counter;      // counts cycles while waiting for completion
 logic [3:0]                        r_timeout_counter;     // counts number of timeouts (not cycles)
 logic                              s_timeout_hit;         // asserted when cycles_counter reaches TIMEOUT_CYCLES
 logic                              s_rdi_trigger;         // internal enable to drive o_req_pkt_vld
//=========================================== Assign fixed fields ===========================================
 // fixed values: src/dst/tag are constant
 assign s_src_id  = 3'b001 ;
 assign s_dst_id  = 3'b100;
 assign s_tag     = 5'b11111; //constant for remote req
// opcode/BE/address are extracted from mailbox inputs 
 assign s_opcode  = i_mailbox_index_low[4:0];        
 assign s_be      = i_mailbox_index_low[12:5];
 assign s_address = {i_mailbox_index_high , i_mailbox_index_low[31:13]};
// header without parity bits 
// This packs fields into header; cp will be XOR of this header.
 assign s_header  = {1'b0 , 2'b0, s_dst_id, s_address, s_src_id, 2'b0, s_tag, s_be, 8'b0, 1'b0 ,s_opcode};
 assign o_opcode = s_opcode;      // export opcode to decoder block
 // Data generation
 // If i_req_length==1 => 128-bit request (header + data )
 // If i_req_length==0 => 64-bit request (header only) so data forced to 0
 always_comb begin
      if(i_req_length)begin
         if (i_32_b) begin
        // 32-bit operation: data_low only
        s_data = {32'b0, i_mailbox_data_low};
       end
       else begin
        // 64-bit operation: data_high:data_low
        s_data = {i_mailbox_data_high, i_mailbox_data_low};
           end
        end 
        else begin
            // 64b request => no data payload
            s_data = 64'b0 ; 
        end   
 end
 // parity generation 
 // dp = XOR over data; cp = XOR over header
 assign s_dp = ^s_data ;
 assign s_cp = ^s_header ;
//=========================================== Mailbox FSM ===========================================
    always_ff @(posedge i_clk or negedge i_rstn) begin : Sequential
      if(~i_rstn) begin
     r_pr <= WAIT_FOR_E2E_CRD;
      end else if(~i_init_n) begin
     r_pr <= WAIT_FOR_E2E_CRD;
      end else begin
     r_pr <= s_nxt ;
      end
    end
    // next state logic
    always_comb begin
      case (r_pr)
        WAIT_FOR_E2E_CRD : begin
           if(i_e2e_crd_return)
            s_nxt <= WAIT_FOR_TRIGG;
           else
            s_nxt <= WAIT_FOR_E2E_CRD;
       end
     WAIT_FOR_TRIGG : begin
          if(i_mailbox_trigger)
            s_nxt <= WAIT_FOR_SEND;
          else
            s_nxt <= WAIT_FOR_TRIGG;
         end
     WAIT_FOR_SEND  : begin
          if(i_req_sent)
            s_nxt <= WAIT_FOR_COMP;
          else
            s_nxt <= WAIT_FOR_SEND;
         end
     WAIT_FOR_COMP  : begin
          if(i_comp_packet_vld || s_timeout_hit)
            s_nxt <= WAIT_FOR_TRIGG;
          else
            s_nxt <= WAIT_FOR_COMP; 
         end
      endcase
   end
   // output logic
   // s_rdi_trigger becomes 1 when:
   // Trigger just detected in WAIT_FOR_TRIGG, OR
   // Still in WAIT_FOR_SEND and RDI has not yet asserted i_req_sent 
   assign s_rdi_trigger = (((r_pr == WAIT_FOR_TRIGG) && (i_mailbox_trigger))|| ((r_pr == WAIT_FOR_SEND) && (!i_req_sent)));
    always_ff @(posedge i_clk or negedge i_rstn) begin : output_logic
      if(~i_rstn) begin
         o_req_pkt     <= '0;
         o_req_pkt_vld <= 1'b0;
         o_pkt_length  <= 1'b0;
      end else if(~i_init_n) begin
         o_req_pkt     <= '0;
         o_req_pkt_vld <= 1'b0;
         o_pkt_length  <= 1'b0;
      end 
      else if (s_rdi_trigger)begin
         o_req_pkt     <= {s_data, s_dp, s_cp ,s_header} ;
         o_req_pkt_vld <= 1'b1;
         o_pkt_length  <= i_req_length;   // 1=128b, 0=64b   
      end
      else begin
         o_req_pkt     <= '0;
         o_req_pkt_vld <= 1'b0;
         o_pkt_length  <= 1'b0;
      end
    end
//=========================================== TIMEOUT COUNTER ===========================================
  // cycles_counter: counts cycles while in WAIT_FOR_COMP
always_ff @(posedge i_clk or negedge i_rstn) begin : proc_cycles_counter
      if(~i_rstn) begin
         r_cycles_counter <= 0;
      end else if(~i_init_n) begin
         r_cycles_counter <= 0;
      end else if( r_pr == WAIT_FOR_COMP ) begin
         r_cycles_counter <= r_cycles_counter + 1;
      end else
           r_cycles_counter <= 0 ;
end
// s_timeout_hit: becomes 1 when cycles_counter reaches TIMEOUT_CYCLES
assign s_timeout_hit = (r_cycles_counter == TIMEOUT_CYCLES[$bits(r_cycles_counter)-1:0]); 
// timeout_counter: counts number of timeouts
always_ff @(posedge i_clk or negedge i_rstn) begin : proc_timeout_counter
      if(~i_rstn) begin
         r_timeout_counter <= 'b0;
      end else if(~i_init_n) begin
         r_timeout_counter <= 'b0;
      end else if(s_timeout_hit && (r_timeout_counter < i_remote_threshold)) begin
         r_timeout_counter <= r_timeout_counter + 1;
      end 
end
// Remote timeout indicator asserted when timeout_counter reaches threshold
assign o_remote_time_out = (r_timeout_counter == i_remote_threshold);
//=========================================== COMPLETION HANDLING ===========================================
 // Completion packet fields returned back to mailbox/regfile
assign o_Header_log1       = i_comp_packet[127:64];  // TO REG FILE (log header)
assign o_mailbox_data_high = i_comp_packet[127:96];  // UPDATE MAILBOX (data high)
assign o_mailbox_data_low  = i_comp_packet[95:64];   // UPDATE MAILBOX (data low)
always_comb begin
     // defaults: default outputs when not in WAIT_FOR_COMP or no events
    o_mailbox_data_vld    = 1'b0;
    o_mailbox_trigger_en  = 1'b0;
    o_mailbox_status      = 2'b00;
    o_Header_log1_valid   = 1'b0;
    // Only update mailbox/log while waiting for completion
    if ( r_pr == WAIT_FOR_COMP) begin
      if (i_comp_packet_vld) begin
        // completion received -> clear trigger
        o_mailbox_trigger_en = 1'b1;
        if (i_comp_packet[34:32] == 3'b000) begin
          // success completion
          o_mailbox_data_vld = 1'b1;      // mailbox data valid
          o_mailbox_status   = 2'b11;     // your chosen "success" encoding
        end else begin
          // error completion -> log header
          o_Header_log1_valid = 1'b1;
          // Example mapping:
          // if completion code == 3'b100 -> status=00 else status=01
          o_mailbox_status    = (i_comp_packet[34:32] == 3'b100 ) ? 2'b00 : 2'b01;
        end                                       
      end
      else if (s_timeout_hit) begin
        // timeout happened -> clear trigger
        o_mailbox_trigger_en = 1'b1;
        // If this timeout is the last allowed attempt (threshold-1 because counter starts from 0)
        // then log "CA" else return "UR" 
        if (r_timeout_counter== i_remote_threshold - 1) 
          o_mailbox_status = 2'b00; //CA
        else
          o_mailbox_status = 2'b01; //UA
      end
    end
end
endmodule
