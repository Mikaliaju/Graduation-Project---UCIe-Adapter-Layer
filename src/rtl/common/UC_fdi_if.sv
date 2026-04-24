// ============================================================
// File: UC_fdi_if.sv
// Description: FDI (Flit-aware D2D Interface) Interface
// ============================================================
// `ifndef UC_FDI_IF
// `define UC_FDI_IF

import UC_ALSM_package::*;

interface UC_fdi_if #(
    parameter int P_NC       = 32,
    parameter int DATA_PATH  = 512,
    parameter int DLLP       = 32
)(
    input logic i_clk
);

    //----------------------------------------------------------
    // SB FDI Signals (Sideband)
    //----------------------------------------------------------
    // LP → PL (Protocol Layer to Adapter)
    logic [P_NC-1:0]    lp_cfg;            // FDI packet chunks from Protocol Layer
    logic               lp_cfg_vld;        // Valid indicator for FDI data
    logic               lp_cfg_crd;        // Credit return from Protocol Layer

    // PL → LP (Adapter to Protocol Layer)
    logic [P_NC-1:0]    pl_cfg;            // FDI packet chunks to Protocol Layer
    logic               pl_cfg_vld;        // Valid indicator for FDI packet sent
    logic               pl_cfg_crd;        // Credit return from Adapter to Protocol Layer
    logic [3:0]         pl_protocol;       // Negotiated protocol
    logic [3:0]         pl_flit_fmt;       // Negotiated flit format
    logic               pl_valid;          // FDI valid

    //----------------------------------------------------------
    // MB FDI TX Signals (Mainband TX: Protocol → Adapter)
    //----------------------------------------------------------
    logic               lp_irdy;           // Protocol layer ready to send
    logic               lp_valid;          // TX data valid
    logic [DATA_PATH-1:0] lp_data;         // TX payload
    logic [DLLP-1:0]    lp_dllp;           // DLLP info
    logic               lp_dllp_valid;     // DLLP valid
    logic               lp_dllp_ofc;       // DLLP OFC flag
    logic [7:0]         lp_stream;         // {SID, PID}
    logic               pl_trdy;           // Packer ready to receive from FDI

    //----------------------------------------------------------
    // MB FDI RX Signals (Mainband RX: Adapter → Protocol)
    //----------------------------------------------------------
    logic [DATA_PATH-1:0] pl_data;         // RX payload forwarded to FDI
    logic               pl_valid_mb;       // RX payload valid (MB)
    logic [7:0]         pl_stream;         // {SID, PID} extracted
    logic [DLLP-1:0]    pl_dllp;           // Extracted DLLP
    logic               pl_dllp_valid;     // Extracted DLLP valid
    logic               pl_dllp_ofc;       // Extracted DLLP OFC
    logic               flit_cancel;       // Cancel forwarded flit

    //----------------------------------------------------------
    // ALSM FDI Signals
    //----------------------------------------------------------
    // LP → PL (Protocol → Adapter)
    state_req           lp_state_req;      // Protocol state request
    logic               lp_linkerror;      // Link error from protocol
    logic               lp_rx_active_sts;  // Protocol RX path status
    logic               lp_stall_ack;      // Protocol response to stall
    logic               lp_clk_ack;        // Protocol response to ungating
    logic               lp_wake_req;       // Protocol request to ungate adapter

    // PL → LP (Adapter → Protocol)
    logic               pl_stallreq;       // Adapter request to stall protocol
    logic               pl_phyinrecenter;  // PHY train/retrain indicator
    logic               pl_phyinl1;        // PHY in L1 PM
    logic               pl_phyinl2;        // PHY in L2 PM
    logic [2:0]         pl_speedmode;      // PHY speed mode
    logic               pl_max_speedmode;  // Max speed mode (>32 Gb/s)
    logic [2:0]         pl_lnk_cfg;        // PHY link configuration
    ll_state            pl_state_sts;      // Adapter state
    logic               pl_inband_pres;    // Adapter capable of receiving state req
    logic               pl_rx_active_req;  // Adapter request to activate protocol RX
    logic               pl_clk_req;        // Adapter request to ungate protocol
    logic               pl_wake_ack;       // Adapter response to protocol ungating

    //----------------------------------------------------------
    // RegFile FDI Signals
    //----------------------------------------------------------
    logic               lp_linkerror_rf;   // FDI link error (to RegFile)
    logic               pl_cerror;         // Logged correctable error
    logic               pl_nferror;        // Logged non-fatal error
    logic               pl_trainerror;     // Any internal training error

    //----------------------------------------------------------
    // Modports
    //----------------------------------------------------------

    // SB Top modport
    modport sb_top (
        // Inputs from Protocol Layer
        input  lp_cfg,
        input  lp_cfg_vld,
        input  lp_cfg_crd,
        // Outputs to Protocol Layer
        output pl_cfg,
        output pl_cfg_vld,
        output pl_cfg_crd,
        output pl_protocol,
        output pl_flit_fmt,
        output pl_valid
    );

    // Mainband modport
    modport mb (
        // TX inputs from Protocol Layer
        input  lp_irdy,
        input  lp_valid,
        input  lp_data,
        input  lp_dllp,
        input  lp_dllp_valid,
        input  lp_dllp_ofc,
        input  lp_stream,
        // TX output to Protocol Layer
        output pl_trdy,
        // RX outputs to Protocol Layer
        output pl_data,
        output pl_valid_mb,
        output pl_stream,
        output pl_dllp,
        output pl_dllp_valid,
        output pl_dllp_ofc,
        output flit_cancel
    );

    // ALSM modport
    modport alsm (
        // Inputs from Protocol Layer
        input  lp_state_req,
        input  lp_linkerror,
        input  lp_rx_active_sts,
        input  lp_stall_ack,
        input  lp_clk_ack,
        input  lp_wake_req,
        // Outputs to Protocol Layer
        output pl_stallreq,
        output pl_phyinrecenter,
        output pl_phyinl1,
        output pl_phyinl2,
        output pl_speedmode,
        output pl_max_speedmode,
        output pl_lnk_cfg,
        output pl_state_sts,
        output pl_inband_pres,
        output pl_rx_active_req,
        output pl_clk_req,
        output pl_wake_ack
    );

    // RegFile modport
    modport regfile (
        input  lp_linkerror_rf,
        output pl_cerror,
        output pl_nferror,
        output pl_trainerror
    );

endinterface : UC_fdi_if
// `endif // UC_FDI_IF