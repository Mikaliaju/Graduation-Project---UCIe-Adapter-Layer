// ============================================================
// File: UC_rdi_if.sv
// Description: RDI (Raw D2D Interface) Interface
// ============================================================
// `ifndef UC_RDI_IF
// `define UC_RDI_IF
import UC_ALSM_package::*;

interface UC_rdi_if #(
    parameter int P_NC      = 32,
    parameter int DATA_PATH = 512
)(
    input logic i_clk
);

    //----------------------------------------------------------
    // SB RDI Signals (Sideband)
    //----------------------------------------------------------
    // PL → LP (PHY to Adapter)
    logic [P_NC-1:0]    pl_cfg;            // RDI packet chunks from PHY
    logic               pl_cfg_vld;        // Valid indicator for RDI data
    logic               pl_cfg_crd;        // Credit return from PHY

    // LP → PL (Adapter to PHY)
    logic [P_NC-1:0]    lp_cfg;            // RDI packet chunks to PHY
    logic               lp_cfg_vld;        // Valid indicator for RDI packet sent
    logic               lp_cfg_crd;        // Credit return from Adapter to PHY

    //----------------------------------------------------------
    // MB RDI TX Signals (Mainband TX: Adapter → PHY)
    //----------------------------------------------------------
    logic               pl_trdy;           // PHY ready to accept flit
    logic [DATA_PATH-1:0] lp_data;         // TX flit to RDI
    logic               lp_valid;          // TX flit valid
    logic               lp_irdy;           // Packer ready to transmit

    //----------------------------------------------------------
    // MB RDI RX Signals (Mainband RX: PHY → Adapter)
    //----------------------------------------------------------
    logic [DATA_PATH-1:0] pl_data;         // RX flit from RDI
    logic               pl_valid;          // RX flit valid

    //----------------------------------------------------------
    // ALSM RDI Signals
    //----------------------------------------------------------
    // PL → LP (PHY to Adapter)
    logic               pl_inband_pres;    // PHY ready to receive state req
    logic               pl_phyinrecenter;  // PHY in train/retrain
    logic [2:0]         pl_speedmode;      // PHY speed mode
    logic [2:0]         pl_lnk_cfg;        // PHY link configuration
    ll_state            pl_state_sts;      // PHY state
    logic               pl_clk_req;        // PHY request to ungate adapter
    logic               pl_wake_ack;       // PHY response to ungating request
    logic               pl_stall_req;      // PHY requests adapter to stall
    logic               pl_error;          // PHY indication of error
    logic               pl_trdy_alsm;      // PHY data path backpressure

    // LP → PL (Adapter to PHY)
    logic               lp_clk_ack;        // Adapter response to ungating
    logic               lp_wake_req;       // Adapter request to ungate PHY
    logic               lp_linkerror;      // Link error from adapter to PHY
    state_req           lp_state_req;      // Adapter state request
    logic               lp_stall_ack;      // Adapter confirmation of stalling

    //----------------------------------------------------------
    // RegFile RDI Signals
    //----------------------------------------------------------
    logic               pl_trainerror;     // PHY training error
    logic               pl_error_rf;       // Recoverable error (retrain)
    logic               pl_cerror;         // Logged correctable error
    logic               pl_nferror;        // Logged non-fatal error
    logic               pl_phyinrecenter_rf; // PHY train/retrain (to RegFile)
    logic [2:0]         pl_speedmode_rf;   // Speed mode (to RegFile)
    logic [2:0]         pl_lnk_cfg_rf;     // Link config (to RegFile)

    //----------------------------------------------------------
    // Modports
    //----------------------------------------------------------

    // SB Top modport
    modport sb_top (
        // Inputs from PHY
        input  pl_cfg,
        input  pl_cfg_vld,
        input  pl_cfg_crd,
        // Outputs to PHY
        output lp_cfg,
        output lp_cfg_vld,
        output lp_cfg_crd
    );

    // Mainband modport
    modport mb (
        // TX
        input  pl_trdy,
        output lp_data,
        output lp_valid,
        output lp_irdy,
        // RX
        input  pl_data,
        input  pl_valid
    );

    // ALSM modport
    modport alsm (
        // Inputs from PHY
        input  pl_inband_pres,
        input  pl_phyinrecenter,
        input  pl_speedmode,
        input  pl_lnk_cfg,
        input  pl_state_sts,
        input  pl_clk_req,
        input  pl_wake_ack,
        input  pl_stall_req,
        input  pl_error,
        input  pl_trdy_alsm,
        // Outputs to PHY
        output lp_clk_ack,
        output lp_wake_req,
        output lp_linkerror,
        output lp_state_req,
        output lp_stall_ack
    );

    // RegFile modport
    modport regfile (
        input  pl_trainerror,
        input  pl_error_rf,
        input  pl_cerror,
        input  pl_nferror,
        input  pl_phyinrecenter_rf,
        input  pl_speedmode_rf,
        input  pl_lnk_cfg_rf
    );

endinterface : UC_rdi_if
// `endif // UC_RDI_IF