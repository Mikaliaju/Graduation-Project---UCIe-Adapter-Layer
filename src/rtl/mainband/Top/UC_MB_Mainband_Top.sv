// =================================================================================================
//  FILENAME    : UC_MB_Mainband.sv
//  MODULE      : UC_MB_Mainband
//  PROJECT     : UCIe 3.0 Adapter Layer
//  AUTHOR      : Ali Noureldin Abdelaziz
// =================================================================================================
//  DESCRIPTION :
//    Top-level Mainband block containing Packer (TX path) and Unpacker (RX path).
//    Retry and LSM signals are left as ports to be connected externally.
//
//  External Interfaces:
//    - FDI  : Protocol Layer interface (TX + RX)
//    - RDI  : Physical Layer interface (TX + RX)
//    - LSM  : Link State Machine 
//    - Retry: Retry Buffer block (Fatma Fawzy)
// =================================================================================================

import UC_MB_Mainband_pkg::*;
module UC_MB_Mainband (
  // -------------------------
  // Clock & Reset
  // -------------------------
  input  logic                      i_clk,
  input  logic                      i_rst_n,
  input  logic                      i_init,

  // -------------------------
  // LSM & REG Ports (retry_top)
  // -------------------------
  input  logic                      i_fdi_active,         // connect to LSM
  output logic                      o_log_uie,
  output logic                      o_log_cie,
  output logic                      oo_rdi_retrain,

  // -------------------------
  // FDI TX Interface (from Protocol Layer to Packer)
  // -------------------------
  input  logic                      i_lp_irdy_fdi,        // Protocol layer ready to send
  input  logic                      i_lp_valid_fdi,       // TX data valid
  input  logic    [DATA_PATH-1:0]   i_lp_data_fdi,        // TX payload 512-bit
  input  logic    [DLLP-1:0]        i_lp_dllp,            // DLLP info
  input  logic                      i_lp_dllp_valid,      // DLLP valid
  input  logic                      i_lp_dllp_ofc,        // DLLP OFC flag
  input  logic    [7:0]             i_lp_stream,          // {SID, PID}
  output logic                      o_pl_trdy_fdi,        // Packer ready to receive from FDI

  // -------------------------
  // FDI RX Interface (from Unpacker to Protocol Layer)
  // -------------------------
  output logic    [DATA_PATH-1:0]   o_pl_data_fdi,        // RX payload forwarded to FDI
  output logic                      o_pl_valid_fdi,       // RX payload valid
  output logic    [7:0]             o_pl_stream,          // {SID, PID} extracted
  output logic    [DLLP-1:0]        o_pl_dllp,            // Extracted DLLP
  output logic                      o_pl_dllp_valid,      // Extracted DLLP valid
  output logic                      o_pl_dllp_ofc,        // Extracted DLLP OFC
  output logic                      o_flit_cancel,        // Cancel forwarded flit

  // -------------------------
  // RDI TX Interface (from Packer to Physical Layer)
  // -------------------------
  input  logic                      i_pl_trdy,            // PHY ready to accept flit
  output logic    [DATA_PATH-1:0]   o_lp_data_rdi,        // TX flit to RDI
  output logic                      o_lp_valid_rdi,       // TX flit valid
  output logic                      o_lp_irdy_rdi,        // Packer ready to transmit

  // -------------------------
  // RDI RX Interface (from Physical Layer to Unpacker)
  // -------------------------
  input  logic    [DATA_PATH-1:0]   i_pl_data_rdi,        // RX flit from RDI
  input  logic                      i_pl_valid_rdi,       // RX flit valid

  // -------------------------
  // LSM Interface ? Packer
  // -------------------------
  input  logic                      i_packer_en,          // Enable packer          
  input  logic                      i_flit_boundary,      // Flit boundary command  
  input  logic                      i_flush,              // Flush command          
  input  logic                      i_drain,              // Drain command          
  output logic                      o_flit_boundary_done, // Flit boundary done     
  output logic                      o_flush_done,         // Flush done             
  output logic                      o_drain_done,         // Drain done             

  // -------------------------
  // LSM Interface ? Unpacker
  // -------------------------
  input  logic                      i_unpacker_en,        // Enable unpacker        
  input  logic                      i_stop_stream        // Stop stream     

  );



  /////////////////// Internal wires ///////////////////


  // -------------------------
  // Retry Interface ? Packer (Inputs)
  // -------------------------
  logic    [SEQUENS_NUM-1:0] w_seq_num;            // Sequence number     
  logic    [REPLAY_CMD-1:0]  w_replay_command;     // Replay command       
  logic                      w_deassert_trdy;      // Deassert trdy        
  logic    [DATA_PATH-1:0]   w_retry_data;         // Retry payload       
  logic                      w_retry_sid;          // Retry SID           
  logic    [PROTOCOL_ID-1:0] w_retry_pid;          // Retry PID            
  logic                      w_buffer_empty;       // Buffer empty flag  
  logic                      w_retry_use;          // Retry enable     

  // -------------------------
  // Retry Interface ? Packer (Outputs)
  // -------------------------
  logic    [DATA_PATH-1:0]   w_buffer_data;        // Data to retry buffer   
  logic    [PROTOCOL_ID-1:0] w_buffer_pid;         // PID to retry buffer  
  logic                      w_buffer_sid;         // SID to retry buffer   


  // -------------------------
  // Retry Interface ? Unpacker (Inputs)
  // -------------------------
  logic                      w_check_pass;         // Sequence check passed  
  logic                      w_discarded_flit;     // Discard flit flag   

  // -------------------------
  // Retry Interface ? Unpacker (Outputs)
  // -------------------------
  logic    [SEQUENS_NUM-1:0] w_seq_num_o;          // Extracted seq num  
  logic    [REPLAY_CMD-1:0]  w_replay_com;         // Extracted replay cmd  
  logic                      w_crc_err;            // CRC error flag       
  logic                      w_rx_flit_type;
  // -------------------------
  // Internal Wires ? Retry 
  // -------------------------
  logic                      w_discard_flit_top;
  logic                      w_log_uie;
  logic                      w_log_cie;
  logic                      w_rdi_retrain;
  logic                      w_discard_payload;
  logic                      w_tx_flit_type;
  // -------------------------
  // LSM Retry 
  // -------------------------
  logic                      w_fdi_active;

// =============================================================================
// Packer Instantiation (TX Path)
// =============================================================================
UC_MB_Packer           U1_UC_MB_Packer (

  // Clock & Reset
  .i_clk               (i_clk),
  .i_rst_n             (i_rst_n),
  .i_init              (i_init),

  // FDI Inputs
  .i_lp_irdy_fdi       (i_lp_irdy_fdi),
  .i_lp_valid_fdi      (i_lp_valid_fdi),
  .i_lp_data_fdi       (i_lp_data_fdi),
  .i_lp_dllp           (i_lp_dllp),
  .i_lp_dllp_valid     (i_lp_dllp_valid),
  .i_lp_dllp_ofc       (i_lp_dllp_ofc),
  .i_lp_stream         (i_lp_stream),

  // Retry Inputs
  .i_seq_num           (w_seq_num),           // connect to Retry
  .i_replay_command    (w_replay_command),    // connect to Retry
  .i_deassert_trdy     (w_deassert_trdy),     // connect to Retry
  .i_retry_data        (w_retry_data),        // connect to Retry
  .i_retry_sid         (w_retry_sid),         // connect to Retry
  .i_retry_pid         (w_retry_pid),         // connect to Retry
  .i_buffer_empty      (w_buffer_empty),      // connect to Retry
  .i_retry_use         (w_retry_use),         // connect to Retry

  // LSM Inputs
  .i_packer_en         (i_packer_en),         
  .i_flit_boundary     (i_flit_boundary),     
  .i_flush             (i_flush),             
  .i_drain             (i_drain),            

  // RDI Input
  .i_pl_trdy           (i_pl_trdy),

  // FDI Output
  .o_pl_trdy_fdi       (o_pl_trdy_fdi),

  // Retry Outputs
  .o_buffer_data       (w_buffer_data),       // connect to Retry
  .o_buffer_pid        (w_buffer_pid),        // connect to Retry
  .o_buffer_sid        (w_buffer_sid),        // connect to Retry

  // LSM Outputs
  .o_flit_boundary_done(o_flit_boundary_done), 
  .o_flush_done        (o_flush_done),         
  .o_drain_done        (o_drain_done),   

  // RDI Outputs
  .o_lp_data_rdi       (o_lp_data_rdi),
  .o_lp_valid_rdi      (o_lp_valid_rdi),
  .o_lp_irdy_rdi       (o_lp_irdy_rdi)
);



// =============================================================================
// Unpacker Instantiation (RX Path)
// =============================================================================
UC_MB_Unpacker         U2_UC_MB_Unpacker (

  // Clock & Reset
  .i_clk               (i_clk),
  .i_rst_n             (i_rst_n),
  .i_init              (i_init),

  // RDI Inputs
  .i_pl_data_rdi       (i_pl_data_rdi),
  .i_pl_valid_rdi      (i_pl_valid_rdi),

  // Retry Inputs
  .i_check_pass        (w_check_pass),        // connect to Retry
  .i_discarded_flit    (w_discarded_flit),    // connect to Retry

  // LSM Inputs
  .i_unpacker_en       (i_unpacker_en),   
  .i_stop_stream       (i_stop_stream),    

  // FDI Outputs
  .o_pl_data_fdi       (o_pl_data_fdi),
  .o_pl_valid_fdi      (o_pl_valid_fdi),
  .o_pl_stream         (o_pl_stream),
  .o_pl_dllp           (o_pl_dllp),
  .o_pl_dllp_valid     (o_pl_dllp_valid),
  .o_pl_dllp_ofc       (o_pl_dllp_ofc),
  .o_flit_cancel       (o_flit_cancel),

  // Retry Outputs
  .o_seq_num           (w_seq_num_o),         // connect to Retry
  .o_replay_com        (w_replay_com),        // connect to Retry
  .o_crc_err           (w_crc_err)            // connect to Retry

);

// =============================================================================
// Retry Instantiation
// =============================================================================

retry_top U3_retry_top (

  // Global
  .clk                 (i_clk),
  .rst_n               (i_rst_n),
  .init                (i_init),

  // System
  .fdi_active          (w_fdi_active),          
  .tx_en               (i_packer_en),
  .rx_en               (i_unpacker_en),

// RX ports from Unpacker
  .rx_crc_error        (w_crc_err),
  .rx_seq_num          (w_seq_num_o),
  .rx_replay_command   (w_replay_com),
  .rx_flit_type        (w_rx_flit_type),     

  // TX buffer ports (to/from Packer)
  .tx_i_data           (w_tx_i_data),
  .tx_i_stream         ({w_buffer_sid, w_buffer_pid}),
  .tx_o_data           (w_tx_o_data),
  .tx_o_stream         ({w_retry_sid, w_retry_pid}),
  .discard_flit        (w_discard_flit),
  .discard_payload     (o_discard_payload),

  // Outputs to Packer
  .pl_trdy_control     (w_deassert_trdy),
  .tx_replay_command   (w_replay_command),
  .tx_flit_type        (w_tx_flit_type),
  .tx_seq_num          (w_seq_num),

  // REG file
  .log_uie             (o_log_uie),
  .log_cie             (o_log_cie),

  // LSM 
  .rdi_retrain         (o_rdi_retrain)
);
endmodule

