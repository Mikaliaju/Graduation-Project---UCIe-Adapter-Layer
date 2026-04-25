// ============================================================
// File: UC_MB_Mainband_wrap.sv
// Description: Wrapper binding interfaces to UC_MB_Mainband
// ============================================================
// `include "UC_rdi_if.sv"
// `include "UC_fdi_if.sv"
// `include "UC_regfile_if.sv"

module UC_MB_Mainband_wrap #(
    parameter int DATA_PATH = 512,
    parameter int DLLP      = 32
)(
    input  logic        i_clk,
    input  logic        i_rst_n,
    input  logic        i_init,

    UC_fdi_if.mb           fdi,
    UC_rdi_if.mb           rdi,

    // LSM Packer Interface
    input  logic        i_packer_en,
    input  logic        i_flit_boundary,
    input  logic        i_flush,
    input  logic        i_drain,
    output logic        o_flit_boundary_done,
    output logic        o_flush_done,
    output logic        o_drain_done,

    // LSM Unpacker Interface
    input  logic        i_unpacker_en,
    input  logic        i_stop_stream
);

    //----------------------------------------------------------
    // Internal wires
    //----------------------------------------------------------

    // FDI TX
    logic               w_lp_irdy_fdi;
    logic               w_lp_valid_fdi;
    logic [DATA_PATH-1:0] w_lp_data_fdi;
    logic [DLLP-1:0]    w_lp_dllp;
    logic               w_lp_dllp_valid;
    logic               w_lp_dllp_ofc;
    logic [7:0]         w_lp_stream;
    logic               w_pl_trdy_fdi;

    // FDI RX
    logic [DATA_PATH-1:0] w_pl_data_fdi;
    logic               w_pl_valid_fdi;
    logic [7:0]         w_pl_stream;
    logic [DLLP-1:0]    w_pl_dllp;
    logic               w_pl_dllp_valid;
    logic               w_pl_dllp_ofc;
    logic               w_flit_cancel;

    // RDI TX
    logic               w_pl_trdy;
    logic [DATA_PATH-1:0] w_lp_data_rdi;
    logic               w_lp_valid_rdi;
    logic               w_lp_irdy_rdi;

    // RDI RX
    logic [DATA_PATH-1:0] w_pl_data_rdi;
    logic               w_pl_valid_rdi;

    //----------------------------------------------------------
    // Interface → wire (inputs)
    //----------------------------------------------------------
    assign w_lp_irdy_fdi    = fdi.lp_irdy;
    assign w_lp_valid_fdi   = fdi.lp_valid;
    assign w_lp_data_fdi    = fdi.lp_data;
    assign w_lp_dllp        = fdi.lp_dllp;
    assign w_lp_dllp_valid  = fdi.lp_dllp_valid;
    assign w_lp_dllp_ofc    = fdi.lp_dllp_ofc;
    assign w_lp_stream      = fdi.lp_stream;

    assign w_pl_trdy        = rdi.pl_trdy;
    assign w_pl_data_rdi    = rdi.pl_data;
    assign w_pl_valid_rdi   = rdi.pl_valid;

    //----------------------------------------------------------
    // Wire → interface (outputs)
    //----------------------------------------------------------
    assign fdi.pl_trdy      = w_pl_trdy_fdi;
    assign fdi.pl_data      = w_pl_data_fdi;
    assign fdi.pl_valid_mb  = w_pl_valid_fdi;
    assign fdi.pl_stream    = w_pl_stream;
    assign fdi.pl_dllp      = w_pl_dllp;
    assign fdi.pl_dllp_valid= w_pl_dllp_valid;
    assign fdi.pl_dllp_ofc  = w_pl_dllp_ofc;
    assign fdi.flit_cancel  = w_flit_cancel;

    assign rdi.lp_data      = w_lp_data_rdi;
    assign rdi.lp_valid     = w_lp_valid_rdi;
    assign rdi.lp_irdy      = w_lp_irdy_rdi;

    //----------------------------------------------------------
    // DUT Instantiation
    //----------------------------------------------------------
    /* UC_MB_Mainband #(
        .DATA_PATH ( DATA_PATH ),
        .DLLP      ( DLLP )
    ) */
      UC_MB_Mainband u_UC_MB_Mainband (
        .i_clk                  ( i_clk ),
        .i_rst_n                ( i_rst_n ),
        .i_init                 ( i_init ),

        // FDI TX
        .i_lp_irdy_fdi          ( w_lp_irdy_fdi ),
        .i_lp_valid_fdi         ( w_lp_valid_fdi ),
        .i_lp_data_fdi          ( w_lp_data_fdi ),
        .i_lp_dllp              ( w_lp_dllp ),
        .i_lp_dllp_valid        ( w_lp_dllp_valid ),
        .i_lp_dllp_ofc          ( w_lp_dllp_ofc ),
        .i_lp_stream            ( w_lp_stream ),
        .o_pl_trdy_fdi          ( w_pl_trdy_fdi ),

        // FDI RX
        .o_pl_data_fdi          ( w_pl_data_fdi ),
        .o_pl_valid_fdi         ( w_pl_valid_fdi ),
        .o_pl_stream            ( w_pl_stream ),
        .o_pl_dllp              ( w_pl_dllp ),
        .o_pl_dllp_valid        ( w_pl_dllp_valid ),
        .o_pl_dllp_ofc          ( w_pl_dllp_ofc ),
        .o_flit_cancel          ( w_flit_cancel ),

        // RDI TX
        .i_pl_trdy              ( w_pl_trdy ),
        .o_lp_data_rdi          ( w_lp_data_rdi ),
        .o_lp_valid_rdi         ( w_lp_valid_rdi ),
        .o_lp_irdy_rdi          ( w_lp_irdy_rdi ),

        // RDI RX
        .i_pl_data_rdi          ( w_pl_data_rdi ),
        .i_pl_valid_rdi         ( w_pl_valid_rdi ),

        // LSM Packer
        .i_packer_en            ( i_packer_en ),
        .i_flit_boundary        ( i_flit_boundary ),
        .i_flush                ( i_flush ),
        .i_drain                ( i_drain ),
        .o_flit_boundary_done   ( o_flit_boundary_done ),
        .o_flush_done           ( o_flush_done ),
        .o_drain_done           ( o_drain_done ),

        // LSM Unpacker
        .i_unpacker_en          ( i_unpacker_en ),
        .i_stop_stream          ( i_stop_stream )
    );

endmodule : UC_MB_Mainband_wrap
