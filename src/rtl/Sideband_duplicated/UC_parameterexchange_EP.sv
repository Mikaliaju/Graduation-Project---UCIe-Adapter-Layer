// ================================================================================================================================
//  FILENAME    : UC_parameterexchange_EP.sv
//  MODULE      : UC_parameterexchange_EP
//  PROJECT     : UCIe 3.0 Adapter Layer
//  AUTHOR      : Ashraf sherif , Shahd Mohamed
// ================================================================================================================================
//  DESCRIPTION :
//   This module controls the Sideband Parameter Exchange process between two UCIe devices (Root Port and End Point) 
//   during the link initialization phase, It exchanges advertised capabilities messages with the remote device 
//   and determines the common finalized capabilities supported by both sides Based on these capabilities, 
//   the module checks protocol and format conditions and selects the appropriate Flit Format.
//   Finally, it reports the negotiation result by indicating whether the parameter exchange is
//   successful, invalid, or timed out, and forwards the selected protocol and flit format to the Protocol Layer.
// ===========================================================================================================================
module UC_parameterexchange_EP (
    input  logic               i_clk,                             // Clock of operation  
    input  logic               i_rstn,                            // HW reset : active low
    input  logic               i_init_n,                          // SW reset : active low 
    /* Local Capabilities */
    input  logic  [63 : 0]     i_adapter_advcap,                  // Advertised Adapter Capabilities
    input  logic  [63 : 0]     i_cxl_advcap,                      // Advertised CXL Capabilities                 
    input  logic               i_format4_enabled,                 // Format4 of PCIe is supported and enabled 
    input  logic               i_format6_enabled,                 // Format6 of PCIe is supported and enabled 
    input  logic               i_retry_needed,                    // from phy after training 
    /* RX Message Interface */
    input  logic  [127 : 0]    i_rx_msg_with_data,                // The Msg withdata that received from RX
    input  logic               i_rx_msg_valid,                    // Valid of i_rx_msg_with_data bus
    /* TX Message Interface */
    output logic  [127 : 0]    o_tx_msg_with_data,                // The Msg withdata to be trasmit 
    output logic               o_tx_msg_valid,                    // Valid of tx_msg_with_data bus 
    /* Capability Logging Outputs */
    output logic  [63 : 0]     o_adapter_advcap,                  // Advertised Adapter Capability Log Register  
    output logic  [63 : 0]     o_adapter_fincap,                  // Finalized Adapter Capability Log Register
    output logic  [63 : 0]     o_cxl_advcap,                      // Advertised CXL Capability Log Register
    output logic  [63 : 0]     o_cxl_fincap,                      // Finalized CXL Capability Log Register
    output logic               o_adapter_advcap_valid,            // Valid of o_adapter_advcap bus
    output logic               o_adapter_fincap_valid,            // Valid of o_adapter_fincap bus
    output logic               o_cxl_advcap_valid,                // Valid of o_cxl_advcap bus
    output logic               o_cxl_fincap_valid,                // Valid of o_cxl_fincap bus
    /* Flit Format Status */
    input  logic  [4 : 0]      i_flit_fmt_status,                 // Final negotiated format
    output logic  [4 : 0]      o_flit_fromat_status,              // Logg the final negotiated format into UCIe Link Status Register [25 : 22] and Header Log 2 Register [17 : 14]                                                      
    output logic               o_flitfmt_valid,                   // Valid of o_flit_fromat_status
    /* Parameter Exchange Control / Status */
    input  logic               i_start_PE,                        // Parameter exchange should be started
    output logic               o_PE_done,                         // Successful parameter exchange
    output logic               o_invalid_param_exch,              // Invalid parameter exchange
    output logic               o_param_exchange_timeout,          // timeout parameter exchange
    output logic               o_retry_negotiated,                // Indicates whether retry is negotiated or not for LSM 
    input  logic               i_retry_negotiated,                // retry is negotiated or not 
    /* Protocol Layer Interface */
    output logic  [3 : 0]      o_pl_protocol,                     // Adapter indication to Protocol Layer of the protocol that was negotiated during training
    output logic  [3 : 0]      o_pl_flit_fmt,                     // Indicates the negotiated Format to the Protocol Layer
    output logic               o_pl_valid                         // Valid of pl_protocol
);
 //================================================ PARAM & ENUMS ====================================================
parameter TIMEOUT_CYCLES = 100;
// Parameter Exchange States
    typedef enum bit [2:0] {
        ST_IDLE                = 3'b000,
        ST_WAIT_ADAPTER_CAP    = 3'b001,
        ST_WAIT_FINAL_CAP      = 3'b011,
        ST_WAIT_CXL_ADV_CAP    = 3'b010,
        ST_WAIT_CXL_FINAL_CAP  = 3'b110,
        ST_SUCCESS_EXCHANGE    = 3'b111,
        ST_INVALID_EXCHANGE    = 3'b101,       
        ST_TIMEOUT             = 3'b100
    } paramexchange_state;

 //===================================================== SIGNALS ====================================================
    paramexchange_state  r_current_state, r_next_state; 
    logic         s_streaming_mode;                                // indicates that the protocol that will be advertised is streaming protocol
    logic [63:0]  s_rx_adapter_advcap;                             // Received adv cap
    logic [63:0]  s_rx_cxl_advcap;                                 // Received cxl adv cap 
    logic [7:0]   s_Msgcode;                     
    logic [7:0]   s_MsgSubcode; 
    logic [15:0]  s_MsgInfo;   
    logic         s_param_exch_active;                             // indicates that parameter exchange FSM is still active
    logic         s_param_exch_timeout_hit;                        // timeout flag 
    logic [$clog2(TIMEOUT_CYCLES)-1:0] r_param_exch_counter;       // counts cycles while parameter exchange is in progress
    logic [63:0]  s_common_adapter_cap;
    logic [63:0]  s_fin_adapter_cap_ep;
 //================================================== PARAM EXCH TIMER ====================================================
 // proc_param_exch_counter: counts cycles while parameter exchange is active
 always_ff @(posedge i_clk or negedge i_rstn) begin : proc_param_exch_counter
    if (!i_rstn) begin
        r_param_exch_counter <= '0;
    end
    else if (!i_init_n) begin
        r_param_exch_counter <= '0;
    end
    else if (s_param_exch_active) begin
        r_param_exch_counter <= r_param_exch_counter + 1'b1;
    end
    else begin
        r_param_exch_counter <= '0;
    end
 end
 //================================================== ASSIGNS ====================================================
 // s_param_exch_timeout_hit: becomes 1 when counter reaches timeout cycles
 assign s_param_exch_timeout_hit = (r_param_exch_counter == TIMEOUT_CYCLES[$bits(r_param_exch_counter)-1:0]);
 // s_param_exch_active: indicates that parameter exchange FSM is still active
 assign s_param_exch_active = (r_current_state != ST_IDLE) &&
                              (r_current_state != ST_SUCCESS_EXCHANGE) &&
                              (r_current_state != ST_INVALID_EXCHANGE) &&
                              (r_current_state != ST_TIMEOUT);
 // streaming protocol : if none of the PCIe or CXL protocols are going to be advertised and Streaming = 1
 assign s_streaming_mode    = (i_adapter_advcap[4:1] == 4'b1000);  
 assign s_Msgcode           = i_rx_msg_valid ? i_rx_msg_with_data[21:14] : 8'b0;     
 assign s_MsgSubcode        = i_rx_msg_valid ? i_rx_msg_with_data[39:32] : 8'b0;  
 assign s_MsgInfo           = i_rx_msg_valid ? i_rx_msg_with_data[55:40] : 16'b0;  
 assign s_rx_adapter_advcap = (i_rx_msg_valid && r_current_state == ST_WAIT_ADAPTER_CAP) ? i_rx_msg_with_data[127:64] : 64'b0; 
 assign s_rx_cxl_advcap     = (i_rx_msg_valid && r_current_state == ST_WAIT_CXL_ADV_CAP) ? i_rx_msg_with_data[127:64] : 64'b0; 
 assign o_retry_negotiated  = i_retry_negotiated;
 //================================================== DIRECT CHECK LOGIC  ====================================================
 // Common adapter capability for RP path
 assign s_common_adapter_cap = i_adapter_advcap & s_rx_adapter_advcap;
 // EP finalized adapter capability comes directly from RX data in WAIT_FINAL_CAP
 assign s_fin_adapter_cap_ep = i_rx_msg_with_data[127:64];
 // ---------------- Common PCIe capability selection ----------------
// RP checks the common capability = local AdvCap AND remote AdvCap
// EP checks the finalized capability received from RP
logic [63:0] s_pcie_cap_to_check;
logic        s_protocol_ok;
logic        s_retry_ok;
logic        s_format_ok;
logic        s_stack0_ok;
logic        s_reserved_ok;
logic        s_pcie_valid;
logic        s_ep_cxl_valid;
// For EP: validate the received finalized capability
    assign s_pcie_cap_to_check = s_fin_adapter_cap_ep;
// 1 - Check PCIe Protocol Condition
assign s_protocol_ok = (s_pcie_cap_to_check[3:1] == 3'b001) || ((s_pcie_cap_to_check[3:1] == 3'b101) && !s_pcie_cap_to_check[31]);
// 2 - Check if Retry_Is_Needed and capability[5] are consistent
assign s_retry_ok = (i_retry_needed == s_pcie_cap_to_check[5]);
// 3 - Check Flit formats for PCIe Protocol
assign s_format_ok = !(i_format4_enabled | i_format6_enabled) ? !s_pcie_cap_to_check[0] :
                     (!s_pcie_cap_to_check[0] && (s_pcie_cap_to_check[27] ||s_pcie_cap_to_check[25] ||s_pcie_cap_to_check[24] || s_pcie_cap_to_check[23]));
// 4 - Stack 0 enabled
assign s_stack0_ok = s_pcie_cap_to_check[7];
// 5 - Reserved bits are zero
assign s_reserved_ok = ({s_pcie_cap_to_check[30:28], s_pcie_cap_to_check[22:11],s_pcie_cap_to_check[8], s_pcie_cap_to_check[6]} == 17'b0);
assign s_pcie_valid = s_protocol_ok && s_retry_ok && s_format_ok && s_stack0_ok && s_reserved_ok;
// ---------------- CXL checks ----------------
logic [63:0] s_common_cxl_cap;
assign s_common_cxl_cap = i_cxl_advcap & s_rx_cxl_advcap;
assign s_ep_cxl_valid = i_rx_msg_with_data[64] && ({i_rx_msg_with_data[81:78],i_rx_msg_with_data[76:72],i_rx_msg_with_data[68:65]} == 13'b0);
 //================================================== FSM : PROTOCOL / FLIT FORMAT OUTPUTS ====================================================
 always_ff @(posedge i_clk or negedge i_rstn) begin : proc_protocol_flitfmt
    if (!i_rstn) begin
        o_pl_protocol <= '0;
        o_pl_flit_fmt <= '0;
        o_pl_valid    <= 1'b0;
    end
    else if (!i_init_n) begin
        o_pl_protocol <= '0;
        o_pl_flit_fmt <= '0;
        o_pl_valid    <= 1'b0;
    end
    else if (r_next_state == ST_SUCCESS_EXCHANGE) begin
        o_pl_protocol <= 4'b0000; // PCIe Without Management Transport
        o_pl_flit_fmt <= i_flit_fmt_status;
        o_pl_valid    <= 1'b1;
    end
    else begin
        o_pl_valid <= 1'b0;
    end
 end
 //================================================== FSM : STATE REGISTER ====================================================
 always_ff @(posedge i_clk or negedge i_rstn) begin : proc_state_reg
    if (!i_rstn)
        r_current_state <= ST_IDLE;
    else if (!i_init_n)
        r_current_state <= ST_IDLE;
    else
        r_current_state <= r_next_state;
 end
 //================================================== FSM : NEXT STATE ====================================================
 always_comb begin : proc_next_state
    r_next_state = r_current_state;
    case (r_current_state)

        ST_IDLE: begin
            if (i_start_PE)
                r_next_state = ST_WAIT_ADAPTER_CAP;
            else
                r_next_state = ST_IDLE;
        end
        ST_WAIT_ADAPTER_CAP: begin
            if (!s_param_exch_timeout_hit) begin
                if (i_rx_msg_valid && (s_Msgcode == 8'h01) && (s_MsgSubcode == 8'h00) && (s_MsgInfo == 16'h0)) begin
                    // Streaming is not supported
                    if (s_streaming_mode || (s_rx_adapter_advcap[4:1] == 4'b1000))
                        r_next_state = ST_INVALID_EXCHANGE;
                    else
                        r_next_state = ST_WAIT_FINAL_CAP;
                end
                else
                    r_next_state = ST_WAIT_ADAPTER_CAP;
            end
            else begin
                r_next_state = ST_TIMEOUT;
            end
        end
        
        ST_WAIT_FINAL_CAP: begin
            if (!s_param_exch_timeout_hit) begin
                if (i_rx_msg_valid && (s_Msgcode == 8'h02) && (s_MsgSubcode == 8'h00) && (s_MsgInfo == 16'h0)) begin
                    if (s_pcie_valid)
                        r_next_state = ST_WAIT_CXL_ADV_CAP;
                    else
                        r_next_state = ST_INVALID_EXCHANGE;
                end
                else
                    r_next_state = ST_WAIT_FINAL_CAP;
            end
            else begin
                r_next_state = ST_TIMEOUT;
            end
        end

        ST_WAIT_CXL_ADV_CAP: begin
            if (!s_param_exch_timeout_hit) begin
                if (i_rx_msg_valid && (s_Msgcode == 8'h01) && (s_MsgSubcode == 8'h01) && (s_MsgInfo == 16'h0)) begin

                        r_next_state = ST_WAIT_CXL_FINAL_CAP;
                end
                else
                    r_next_state = ST_WAIT_CXL_ADV_CAP;
            end
            else begin
                r_next_state = ST_TIMEOUT;
            end
        end
        ST_WAIT_CXL_FINAL_CAP: begin
            if (!s_param_exch_timeout_hit) begin
                if (i_rx_msg_valid && (s_Msgcode == 8'h02) && (s_MsgSubcode == 8'h01) && (s_MsgInfo == 16'h0)) begin
                    if (s_ep_cxl_valid)
                        r_next_state = ST_SUCCESS_EXCHANGE;
                    else
                        r_next_state = ST_INVALID_EXCHANGE;
                end
                else
                    r_next_state = ST_WAIT_CXL_FINAL_CAP;
            end
            else begin
                r_next_state = ST_TIMEOUT;
            end
        end
        ST_SUCCESS_EXCHANGE: begin
            r_next_state = ST_SUCCESS_EXCHANGE;
        end
        ST_INVALID_EXCHANGE: begin
            r_next_state = ST_INVALID_EXCHANGE;
        end

        ST_TIMEOUT: begin
            r_next_state = ST_TIMEOUT;
        end

        default: begin
            r_next_state = ST_IDLE;
        end
    endcase
 end
 //================================================== FSM : OUTPUT LOGIC ====================================================
 always_comb begin : proc_output_logic
    o_tx_msg_with_data      = '0;
    o_tx_msg_valid          = 1'b0;
    o_adapter_advcap        = '0;
    o_adapter_fincap        = '0;
    o_cxl_advcap            = '0;
    o_cxl_fincap            = '0;
    o_adapter_advcap_valid  = 1'b0;
    o_adapter_fincap_valid  = 1'b0;
    o_cxl_advcap_valid      = 1'b0;
    o_cxl_fincap_valid      = 1'b0;
    o_flit_fromat_status    = '0;
    o_flitfmt_valid         = 1'b0;
    o_PE_done               = 1'b0;
    o_invalid_param_exch    = 1'b0;
    o_param_exchange_timeout= 1'b0;
    case (r_current_state)
        ST_IDLE: begin
        end
        ST_WAIT_ADAPTER_CAP: begin
            if (!s_param_exch_timeout_hit) begin
                if (i_rx_msg_valid && (s_Msgcode == 8'h01) && (s_MsgSubcode == 8'h00) && (s_MsgInfo == 16'h0)) begin
                    if (s_streaming_mode || (s_rx_adapter_advcap[4:1] == 4'b1000)) begin
                        // Streaming is not supported
                    end
                    else begin
                        // Send my adv cap after receiving the remote one (EP)
                        o_tx_msg_with_data     = {i_adapter_advcap, ^i_adapter_advcap, 63'h05000000_2000401b};
                        o_tx_msg_valid         = 1'b1;

                        o_adapter_advcap       = i_adapter_advcap;
                        o_adapter_advcap_valid = 1'b1;
                    end
                end
            end
        end

        ST_WAIT_FINAL_CAP: begin
            if (!s_param_exch_timeout_hit) begin
                if (i_rx_msg_valid && (s_Msgcode == 8'h02) && (s_MsgSubcode == 8'h00) && (s_MsgInfo == 16'h0)) begin
                    if (s_pcie_valid) begin
                        case ({i_format6_enabled, i_format4_enabled})
                            2'b00: begin
                                if (s_fin_adapter_cap_ep[3])
                                    o_flit_fromat_status = 4'b0011; // Format 3
                                else
                                    o_flit_fromat_status = 4'b0010; // Format 2
                            end
                            2'b01: begin
                                if (s_fin_adapter_cap_ep[25])
                                    o_flit_fromat_status = 4'b0100; // Format 4
                                else if (s_fin_adapter_cap_ep[24])
                                    o_flit_fromat_status = 4'b0011; // Format 3
                                else
                                    o_flit_fromat_status = 4'b0010; // Format 2
                            end
                            2'b10: begin
                                if (s_fin_adapter_cap_ep[27])
                                    o_flit_fromat_status = 4'b0110; // Format 6
                                else if (s_fin_adapter_cap_ep[24])
                                    o_flit_fromat_status = 4'b0011; // Format 3
                                else
                                    o_flit_fromat_status = 4'b0010; // Format 2
                            end
                            2'b11: begin
                                if (s_fin_adapter_cap_ep[27])
                                    o_flit_fromat_status = 4'b0110; // Format 6
                                else if (s_fin_adapter_cap_ep[25])
                                    o_flit_fromat_status = 4'b0100; // Format 4
                                else if (s_fin_adapter_cap_ep[24])
                                    o_flit_fromat_status = 4'b0011; // Format 3
                                else
                                    o_flit_fromat_status = 4'b0010; // Format 2
                            end
                        endcase
                        o_flitfmt_valid = 1'b1;
                    end
                    o_adapter_fincap       = s_fin_adapter_cap_ep;
                    o_adapter_fincap_valid = 1'b1;
                end
            end
        end

        ST_WAIT_CXL_ADV_CAP: begin
            if (!s_param_exch_timeout_hit) begin
                if (i_rx_msg_valid && (s_Msgcode == 8'h01) && (s_MsgSubcode == 8'h01) && (s_MsgInfo == 16'h0)) begin

                    // Send my adv_cap.cxl after receiving the remote one (EP)
                    o_tx_msg_with_data = {i_cxl_advcap, ^i_cxl_advcap, 63'h45000001_2000401b};
                    o_tx_msg_valid     = 1'b1;
                    o_cxl_advcap       = i_cxl_advcap;
                    o_cxl_advcap_valid = 1'b1;
                end
            end
        end

        ST_WAIT_CXL_FINAL_CAP: begin
            if (!s_param_exch_timeout_hit) begin
                if (i_rx_msg_valid && (s_Msgcode == 8'h02) && (s_MsgSubcode == 8'h01) && (s_MsgInfo == 16'h0)) begin
                    o_cxl_fincap       = i_rx_msg_with_data[127:64];
                    o_cxl_fincap_valid = 1'b1;
                end
            end
        end
        ST_SUCCESS_EXCHANGE: begin
            o_PE_done = 1'b1;
        end
        ST_INVALID_EXCHANGE: begin
            o_invalid_param_exch = 1'b1;
        end
        ST_TIMEOUT: begin
            o_param_exchange_timeout = 1'b1;
        end
        default: begin
        end
    endcase
   end 
endmodule
