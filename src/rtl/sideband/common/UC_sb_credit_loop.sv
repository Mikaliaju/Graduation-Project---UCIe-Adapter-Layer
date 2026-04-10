/*
Authour: Shahd Mohamed , Ashraf sherif 

Module_name: UC_sb_credit_loop

Description: The Sideband Credit Loop manages credit exchange between the adapter, 
protocol layer, and PHY for sideband traffic over the FDI and RDI 
interfaces.  
 Credits are decremented when sideband buffers are consumed and 
incremented when credit return signals are received. 
 The controller generates stall indications to prevent transmission or 
reception when the corresponding credit pool is exhausted
*/
module UC_sb_credit_loop #(
    parameter int MAX_CREDITS = 32,
    parameter int CREDIT_W    = $clog2(MAX_CREDITS + 1)
)(
    input  logic                i_clk,
    input  logic                i_rst_n,
    input  logic                i_init,

    input  logic                i_rdi_credit_release,   // Indicates that the adapter has released a location from its RDI FIFO.
    input  logic                i_fdi_credit_release,   // Indicates that the adapter has released a location from its FDI FIFO.
    input  logic                i_decrease_counter,     // Indicates credit consumption

    input  logic                i_lp_cfg_crd,           // Credit return from protocol layer to adapter.
    input  logic                i_pl_cfg_crd,           // Credit return from PHY to adapter.

    output logic                o_stall,                // Stall indication when no credits are available and stop transmission
    output logic                o_pl_cfg_crd,           // Credit return forwarded from adapter to protocol layer
    output logic                o_lp_cfg_crd            // Credit return forwarded from adapter to PHY
);

    logic [CREDIT_W-1:0] credit_count;

    // Forward credit release pulses
    assign o_pl_cfg_crd = i_fdi_credit_release;
    assign o_lp_cfg_crd = i_rdi_credit_release;

    // Credit counter
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            credit_count <= MAX_CREDITS[CREDIT_W-1:0];
        end
        else if (!i_init) begin
            credit_count <= MAX_CREDITS[CREDIT_W-1:0];
        end
        else begin
            // increment and decrement in same cycle => no net change
            if (i_pl_cfg_crd && !i_decrease_counter) begin
                if (credit_count < MAX_CREDITS[CREDIT_W-1:0])
                    credit_count <= credit_count + 1'b1;
            end
            else if (!i_pl_cfg_crd && i_decrease_counter) begin
                if (credit_count > 0)
                    credit_count <= credit_count - 1'b1;
            end
        end
    end

    assign o_stall = (credit_count == 0);

endmodule
