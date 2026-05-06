/*
Author: Shahd Mohamed, Ashraf Sherif

Module_name: UC_sb_credit_loop

Description: The Sideband Credit Loop manages credit exchange between the adapter,
protocol layer, and PHY for sideband traffic over the FDI and RDI
interfaces.
 Credits are decremented when sideband buffers are consumed and
incremented when credit return signals are received.
 The controller generates a stall indication to prevent transmission
when the PHY credit pool is exhausted.
 Protocol-side credits and stall are removed -- completions sent over
FDI do not consume protocol credits.
*/

module UC_sb_credit_loop #(
    parameter     MAX_CREDITS = 32,
    parameter     CREDIT_W    = $clog2(MAX_CREDITS + 1)
)(
    input  logic                i_clk,
    input  logic                i_rst_n,
    input  logic                i_init,

    input  logic                i_rdi_credit_release,   // Adapter released a location from its RDI FIFO -> forward to PHY
    input  logic                i_fdi_credit_release,   // Adapter released a location from its FDI FIFO -> forward to protocol layer

    input  logic                i_lp_cfg_crd,           // Credit return from protocol layer to adapter
    input  logic                i_pl_cfg_crd,           // Credit return from PHY to adapter

    input  logic                i_decrease_counter,     // Indicates PHY credit consumption (packet sent to PHY)

    output logic                o_stall,                // Stall TX when no PHY credits are available
    output logic                o_pl_cfg_crd,           // Credit return forwarded from adapter to protocol layer
    output logic                o_lp_cfg_crd            // Credit return forwarded from adapter to PHY
);

// ======================================================================= //
//  Internal Signals
// ======================================================================= //

    logic [CREDIT_W-1:0] r_phy_credits;    // PHY credit counter

// ======================================================================= //
//  Credit Return Forwarding (combinational pass-through)
// ======================================================================= //

    // RDI release -> forward back to PHY
    assign o_lp_cfg_crd = i_rdi_credit_release;

    // FDI release -> forward back to protocol layer
    assign o_pl_cfg_crd = i_fdi_credit_release;

// ======================================================================= //
//  PHY Credit Counter
//  - Initialised to MAX_CREDITS - 1 on reset  (matches ua_sb_creditloop_ctrl)
//  - Incremented when PHY returns a credit    (i_pl_cfg_crd)
//  - Decremented when a packet is sent to PHY (i_decrease_counter)
//  - Inc + Dec in the same cycle cancel out   (no net change)
//  - Overflow and underflow are both guarded
// ======================================================================= //

    always_ff @(posedge i_clk or negedge i_rst_n) begin : phy_credits_proc
        if (!i_rst_n) begin
            r_phy_credits <= (MAX_CREDITS - 1);
        end
        else if (!i_init) begin
            r_phy_credits <= (MAX_CREDITS - 1);
        end
        else begin
            if (i_pl_cfg_crd && i_decrease_counter) begin
                // Inc and Dec in the same cycle -- no net change
            end
            else if (i_pl_cfg_crd && !i_decrease_counter) begin
                // Increment: guard against overflow above MAX_CREDITS - 1
                if (r_phy_credits != (MAX_CREDITS - 1))
                    r_phy_credits <= r_phy_credits + 1'b1;
            end
            else if (!i_pl_cfg_crd && i_decrease_counter) begin
                // Decrement: guard against underflow below 0
                if (!o_stall)
                    r_phy_credits <= r_phy_credits - 1'b1;
            end
        end
    end

// ======================================================================= //
//  Stall Output
// ======================================================================= //

    assign o_stall = (r_phy_credits == 0);

endmodule