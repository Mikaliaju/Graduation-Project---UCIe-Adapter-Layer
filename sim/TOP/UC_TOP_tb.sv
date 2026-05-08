import UC_ALSM_package::*;
import UC_sb_pkg::*;
import UC_MB_Mainband_pkg::*;
import UC_regfile_package::*;

`include "../../src/rtl/common/UC_all_defs.svh"

class Request_Pkt;
    // Header fields
    logic [2:0]  srcid;         // Source ID: fixed as 000b
    logic [4:0]  tag;           // 5-bit Tag field
    logic [7:0]  byte_en;       // 8-bit Byte Enable field
    logic [4:0] opcode;   // 5-bit opcode field
    logic [2:0]  dstid;         // 3-bit Destination ID
    logic [23:0] addr;          // 24-bit address
    logic        header_parity;
    logic        data_parity;

    // Data field
    logic [63:0] data;
    bit has_data;

    // Packet phases
    logic [31:0] phase1, phase2, phase3, phase4;
    logic [127:0] constructed_pkt;

    // Opcode definitions
    localparam logic [4:0] MEM_RD32 = 5'b00000;
    localparam logic [4:0] MEM_WR32 = 5'b00001;
    localparam logic [4:0] CFG_RD32 = 5'b00100;
    localparam logic [4:0] CFG_WR32 = 5'b00101;
    localparam logic [4:0] MEM_RD64 = 5'b01000;
    localparam logic [4:0] MEM_WR64 = 5'b01001;
    localparam logic [4:0] CFG_RD64 = 5'b01100;
    localparam logic [4:0] CFG_WR64 = 5'b01101;

    // constraint c_opcode {
    //     opcode inside {MEM_RD32, MEM_WR32, CFG_RD32, CFG_WR32,
    //                    MEM_RD64, MEM_WR64, CFG_RD64, CFG_WR64};
    // }

    function new(input logic [4:0] tag,
                 input logic [7:0] byte_en,
                 input logic [2:0] dstid,
                 input logic [23:0] addr = 24'd0,
                 input logic [63:0] data,
                 input logic [4:0] opcode
                 );
        this.srcid   = 3'b000;
        this.tag     = tag;
        this.byte_en = byte_en;
        this.data    = data;
        this.opcode  = opcode;
        // if (!this.randomize()) begin
        //     $display("Randomization failed");
        //     $finish;
        // end
        this.addr  = addr;
        this.dstid = dstid;

        // Determine if packet has data
        if ((opcode == MEM_WR32) || (opcode == CFG_WR32) ||
            (opcode == MEM_WR64) || (opcode == CFG_WR64))
            has_data = 1;
        else
            has_data = 0;

        build_packet();
    endfunction

    function void build_packet();
        // Phase 1
        phase1 = {srcid, 2'b00, tag, byte_en, 9'b0, opcode};

        // Header parity
        header_parity = ^({phase1, 3'b000, dstid, addr});

        // Data phases
        if (has_data) begin
            phase3 = data[31:0];
            if ((opcode == MEM_WR32) || (opcode == CFG_WR32))
                phase4 = 32'd0;
            else
                phase4 = data[63:32];
        end else begin
            phase3 = 32'd0;
            phase4 = 32'd0;
        end

        data_parity = ^({phase4, phase3});
        phase2 = {data_parity, header_parity, 3'b000, dstid, addr};
        constructed_pkt = {phase4, phase3, phase2, phase1};
    endfunction
endclass
module UC_TOP_tb;

  // Parameters

  //Ports
  logic                  i_clk;
  logic                  i_rst_n;
  logic                  i_init;


  // ======================== RP Ports ========================
  logic [`P_NC-1:0]      RP_i_rdi_pl_cfg;
  logic                  RP_i_rdi_pl_cfg_vld;
  logic                  RP_i_rdi_pl_cfg_crd;
  logic [`P_NC-1:0]      RP_o_rdi_lp_cfg;
  logic                  RP_o_rdi_lp_cfg_vld;
  logic                  RP_o_rdi_lp_cfg_crd;
  logic                  RP_i_rdi_pl_trdy;
  logic [DATA_PATH-1:0]  RP_o_rdi_lp_data;
  logic                  RP_o_rdi_lp_valid;
  logic                  RP_o_rdi_lp_irdy;
  logic [DATA_PATH-1:0]  RP_i_rdi_pl_data;
  logic                  RP_i_rdi_pl_valid;
  logic                  RP_i_rdi_pl_inband_pres;
  logic                  RP_i_rdi_pl_phyinrecenter;
  logic [2:0]            RP_i_rdi_pl_speedmode;
  logic [2:0]            RP_i_rdi_pl_lnk_cfg;
  logic                  RP_o_fdi_pl_protocol_valid;
  ll_state               RP_i_rdi_pl_state_sts;
  logic                  RP_i_rdi_pl_clk_req;
  logic                  RP_i_rdi_pl_wake_ack;
  logic                  RP_i_rdi_pl_stall_req;
  logic                  RP_i_rdi_pl_error;
  logic                  RP_i_rdi_pl_trdy_alsm;
  logic                  RP_o_rdi_lp_clk_ack;
  logic                  RP_o_rdi_lp_wake_req;
  logic                  RP_o_rdi_lp_linkerror;
  state_req              RP_o_rdi_lp_state_req;
  logic                  RP_o_rdi_lp_stall_ack;
  logic                  RP_i_rdi_pl_trainerror;
  logic                  RP_i_rdi_pl_error_rf;
  logic                  RP_i_rdi_pl_cerror;
  logic                  RP_i_rdi_pl_nferror;
  logic [`P_NC-1:0]      RP_i_fdi_lp_cfg;
  logic                  RP_i_fdi_lp_cfg_vld;
  logic                  RP_i_fdi_lp_cfg_crd;
  logic [`P_NC-1:0]      RP_o_fdi_pl_cfg;
  logic                  RP_o_fdi_pl_cfg_vld;
  logic                  RP_o_fdi_pl_cfg_crd;
  logic [3:0]            RP_o_fdi_pl_protocol;
  logic [3:0]            RP_o_fdi_pl_flit_fmt;
  logic                  RP_o_fdi_pl_valid;
  logic                  RP_i_fdi_lp_irdy;
  logic                  RP_i_fdi_lp_valid;
  logic [DATA_PATH-1:0]  RP_i_fdi_lp_data;
  logic [DLLP-1:0]       RP_i_fdi_lp_dllp;
  logic                  RP_i_fdi_lp_dllp_valid;
  logic                  RP_i_fdi_lp_dllp_ofc;
  logic [7:0]            RP_i_fdi_lp_stream;
  logic                  RP_o_fdi_pl_trdy;
  logic [DATA_PATH-1:0]  RP_o_fdi_pl_data;
  logic [7:0]            RP_o_fdi_pl_stream;
  logic [DLLP-1:0]       RP_o_fdi_pl_dllp;
  logic                  RP_o_fdi_pl_dllp_valid;
  logic                  RP_o_fdi_pl_dllp_ofc;
  logic                  RP_o_fdi_flit_cancel;
  state_req              RP_i_fdi_lp_state_req;
  logic                  RP_i_fdi_lp_linkerror;
  logic                  RP_i_fdi_lp_rx_active_sts;
  logic                  RP_i_fdi_lp_stall_ack;
  logic                  RP_i_fdi_lp_clk_ack;
  logic                  RP_i_fdi_lp_wake_req;
  logic                  RP_o_fdi_pl_stallreq;
  logic                  RP_o_fdi_pl_phyinrecenter;
  logic                  RP_o_fdi_pl_phyinl1;
  logic                  RP_o_fdi_pl_phyinl2;
  logic [2:0]            RP_o_fdi_pl_speedmode;
  logic                  RP_o_fdi_pl_max_speedmode;
  logic [2:0]            RP_o_fdi_pl_lnk_cfg;
  ll_state               RP_o_fdi_pl_state_sts;
  logic                  RP_o_fdi_pl_inband_pres;
  logic                  RP_o_fdi_pl_rx_active_req;
  logic                  RP_o_fdi_pl_clk_req;
  logic                  RP_o_fdi_pl_wake_ack;
  logic                  RP_o_uncorrectable_error_IRQ;
  logic                  RP_o_correctable_error_IRQ;
  logic                  RP_o_fdi_pl_cerror;
  logic                  RP_o_fdi_pl_nferror;
  logic                  RP_o_fdi_pl_trainerror;

  // ======================== EP Ports ========================
  logic [`P_NC-1:0]      EP_i_rdi_pl_cfg;
  logic                  EP_i_rdi_pl_cfg_vld;
  logic                  EP_i_rdi_pl_cfg_crd;
  logic [`P_NC-1:0]      EP_o_rdi_lp_cfg;
  logic                  EP_o_rdi_lp_cfg_vld;
  logic                  EP_o_rdi_lp_cfg_crd;
  logic                  EP_i_rdi_pl_trdy;
  logic [DATA_PATH-1:0]  EP_o_rdi_lp_data;
  logic                  EP_o_rdi_lp_valid;
  logic                  EP_o_rdi_lp_irdy;
  logic [DATA_PATH-1:0]  EP_i_rdi_pl_data;
  logic                  EP_i_rdi_pl_valid;
  logic                  EP_i_rdi_pl_inband_pres;
  logic                  EP_i_rdi_pl_phyinrecenter;
  logic [2:0]            EP_i_rdi_pl_speedmode;
  logic [2:0]            EP_i_rdi_pl_lnk_cfg;
  logic                  EP_o_fdi_pl_protocol_valid;
  ll_state               EP_i_rdi_pl_state_sts;
  logic                  EP_i_rdi_pl_clk_req;
  logic                  EP_i_rdi_pl_wake_ack;
  logic                  EP_i_rdi_pl_stall_req;
  logic                  EP_i_rdi_pl_error;
  logic                  EP_i_rdi_pl_trdy_alsm;
  logic                  EP_o_rdi_lp_clk_ack;
  logic                  EP_o_rdi_lp_wake_req;
  logic                  EP_o_rdi_lp_linkerror;
  state_req              EP_o_rdi_lp_state_req;
  logic                  EP_o_rdi_lp_stall_ack;
  logic                  EP_i_rdi_pl_trainerror;
  logic                  EP_i_rdi_pl_error_rf;
  logic                  EP_i_rdi_pl_cerror;
  logic                  EP_i_rdi_pl_nferror;
  logic [`P_NC-1:0]      EP_i_fdi_lp_cfg;
  logic                  EP_i_fdi_lp_cfg_vld;
  logic                  EP_i_fdi_lp_cfg_crd;
  logic [`P_NC-1:0]      EP_o_fdi_pl_cfg;
  logic                  EP_o_fdi_pl_cfg_vld;
  logic                  EP_o_fdi_pl_cfg_crd;
  logic [3:0]            EP_o_fdi_pl_protocol;
  logic [3:0]            EP_o_fdi_pl_flit_fmt;
  logic                  EP_o_fdi_pl_valid;
  logic                  EP_i_fdi_lp_irdy;
  logic                  EP_i_fdi_lp_valid;
  logic [DATA_PATH-1:0]  EP_i_fdi_lp_data;
  logic [DLLP-1:0]       EP_i_fdi_lp_dllp;
  logic                  EP_i_fdi_lp_dllp_valid;
  logic                  EP_i_fdi_lp_dllp_ofc;
  logic [7:0]            EP_i_fdi_lp_stream;
  logic                  EP_o_fdi_pl_trdy;
  logic [DATA_PATH-1:0]  EP_o_fdi_pl_data;
  logic [7:0]            EP_o_fdi_pl_stream;
  logic [DLLP-1:0]       EP_o_fdi_pl_dllp;
  logic                  EP_o_fdi_pl_dllp_valid;
  logic                  EP_o_fdi_pl_dllp_ofc;
  logic                  EP_o_fdi_flit_cancel;
  state_req              EP_i_fdi_lp_state_req;
  logic                  EP_i_fdi_lp_linkerror;
  logic                  EP_i_fdi_lp_rx_active_sts;
  logic                  EP_i_fdi_lp_stall_ack;
  logic                  EP_i_fdi_lp_clk_ack;
  logic                  EP_i_fdi_lp_wake_req;
  logic                  EP_o_fdi_pl_stallreq;
  logic                  EP_o_fdi_pl_phyinrecenter;
  logic                  EP_o_fdi_pl_phyinl1;
  logic                  EP_o_fdi_pl_phyinl2;
  logic [2:0]            EP_o_fdi_pl_speedmode;
  logic                  EP_o_fdi_pl_max_speedmode;
  logic [2:0]            EP_o_fdi_pl_lnk_cfg;
  ll_state               EP_o_fdi_pl_state_sts;
  logic                  EP_o_fdi_pl_inband_pres;
  logic                  EP_o_fdi_pl_rx_active_req;
  logic                  EP_o_fdi_pl_clk_req;
  logic                  EP_o_fdi_pl_wake_ack;
  logic                  EP_o_uncorrectable_error_IRQ;
  logic                  EP_o_correctable_error_IRQ;
  logic                  EP_o_fdi_pl_cerror;
  logic                  EP_o_fdi_pl_nferror;
  logic                  EP_o_fdi_pl_trainerror;

  // ======================== internal signals ========================
  UC_TOP_RP  UC_TOP_RP_inst (
    .i_clk                         (i_clk                         ),
    .i_rst_n                       (i_rst_n                       ),
    .i_init                        (i_init                        ),
    .i_rdi_pl_cfg                  (RP_i_rdi_pl_cfg               ),
    .i_rdi_pl_cfg_vld              (RP_i_rdi_pl_cfg_vld           ),
    .i_rdi_pl_cfg_crd              (RP_i_rdi_pl_cfg_crd           ),
    .i_rdi_pl_trdy                 (RP_i_rdi_pl_trdy              ),
    .i_rdi_pl_data                 (RP_i_rdi_pl_data              ),
    .i_rdi_pl_valid                (RP_i_rdi_pl_valid             ),
    .i_rdi_pl_inband_pres          (RP_i_rdi_pl_inband_pres       ),
    .i_rdi_pl_phyinrecenter        (RP_i_rdi_pl_phyinrecenter     ),
    .i_rdi_pl_speedmode            (RP_i_rdi_pl_speedmode         ),
    .i_rdi_pl_lnk_cfg              (RP_i_rdi_pl_lnk_cfg           ),
    .i_rdi_pl_state_sts            (RP_i_rdi_pl_state_sts         ),
    .i_rdi_pl_clk_req              (RP_i_rdi_pl_clk_req           ),
    .i_rdi_pl_wake_ack             (RP_i_rdi_pl_wake_ack          ),
    .i_rdi_pl_stall_req            (RP_i_rdi_pl_stall_req         ),
    .i_rdi_pl_error                (RP_i_rdi_pl_error             ),
    .i_rdi_pl_trdy_alsm            (RP_i_rdi_pl_trdy_alsm         ),
    .i_rdi_pl_trainerror           (RP_i_rdi_pl_trainerror        ),
    .i_rdi_pl_cerror               (RP_i_rdi_pl_cerror            ),
    .i_rdi_pl_nferror              (RP_i_rdi_pl_nferror           ),
    .o_rdi_lp_cfg                  (RP_o_rdi_lp_cfg               ),
    .o_rdi_lp_cfg_vld              (RP_o_rdi_lp_cfg_vld           ),
    .o_rdi_lp_cfg_crd              (RP_o_rdi_lp_cfg_crd           ),
    .o_rdi_lp_data                 (RP_o_rdi_lp_data              ),
    .o_rdi_lp_valid                (RP_o_rdi_lp_valid             ),
    .o_rdi_lp_irdy                 (RP_o_rdi_lp_irdy              ),
    .o_rdi_lp_clk_ack              (RP_o_rdi_lp_clk_ack           ),
    .o_rdi_lp_wake_req             (RP_o_rdi_lp_wake_req          ),
    .o_rdi_lp_linkerror            (RP_o_rdi_lp_linkerror         ),
    .o_rdi_lp_state_req            (RP_o_rdi_lp_state_req         ),
    .o_rdi_lp_stall_ack            (RP_o_rdi_lp_stall_ack         ),
    .i_fdi_lp_cfg                  (RP_i_fdi_lp_cfg               ),
    .i_fdi_lp_cfg_vld              (RP_i_fdi_lp_cfg_vld           ),
    .i_fdi_lp_cfg_crd              (RP_i_fdi_lp_cfg_crd           ),
    .i_fdi_lp_irdy                 (RP_i_fdi_lp_irdy              ),
    .i_fdi_lp_valid                (RP_i_fdi_lp_valid             ),
    .i_fdi_lp_data                 (RP_i_fdi_lp_data              ),
    .i_fdi_lp_dllp                 (RP_i_fdi_lp_dllp              ),
    .i_fdi_lp_dllp_valid           (RP_i_fdi_lp_dllp_valid        ),
    .i_fdi_lp_dllp_ofc             (RP_i_fdi_lp_dllp_ofc          ),
    .i_fdi_lp_stream               (RP_i_fdi_lp_stream            ),
    .i_fdi_lp_state_req            (RP_i_fdi_lp_state_req         ),
    .i_fdi_lp_linkerror            (RP_i_fdi_lp_linkerror         ),
    .i_fdi_lp_rx_active_sts        (RP_i_fdi_lp_rx_active_sts     ),
    .i_fdi_lp_stall_ack            (RP_i_fdi_lp_stall_ack         ),
    .i_fdi_lp_clk_ack              (RP_i_fdi_lp_clk_ack           ),
    .i_fdi_lp_wake_req             (RP_i_fdi_lp_wake_req          ),
    .o_fdi_pl_cfg                  (RP_o_fdi_pl_cfg               ),
    .o_fdi_pl_cfg_vld              (RP_o_fdi_pl_cfg_vld           ),
    .o_fdi_pl_cfg_crd              (RP_o_fdi_pl_cfg_crd           ),
    .o_fdi_pl_protocol             (RP_o_fdi_pl_protocol          ),
    .o_fdi_pl_flit_fmt             (RP_o_fdi_pl_flit_fmt          ),
    .o_fdi_pl_valid                (RP_o_fdi_pl_valid             ),
    .o_fdi_pl_protocol_valid       (RP_o_fdi_pl_protocol_valid    ),
    .o_fdi_pl_trdy                 (RP_o_fdi_pl_trdy              ),
    .o_fdi_pl_data                 (RP_o_fdi_pl_data              ),
    .o_fdi_pl_stream               (RP_o_fdi_pl_stream            ),
    .o_fdi_pl_dllp                 (RP_o_fdi_pl_dllp              ),
    .o_fdi_pl_dllp_valid           (RP_o_fdi_pl_dllp_valid        ),
    .o_fdi_pl_dllp_ofc             (RP_o_fdi_pl_dllp_ofc          ),
    .o_fdi_flit_cancel             (RP_o_fdi_flit_cancel          ),
    .o_fdi_pl_stallreq             (RP_o_fdi_pl_stallreq          ),
    .o_fdi_pl_phyinrecenter        (RP_o_fdi_pl_phyinrecenter     ),
    .o_fdi_pl_phyinl1              (RP_o_fdi_pl_phyinl1           ),
    .o_fdi_pl_phyinl2              (RP_o_fdi_pl_phyinl2           ),
    .o_fdi_pl_speedmode            (RP_o_fdi_pl_speedmode         ),
    .o_fdi_pl_max_speedmode        (RP_o_fdi_pl_max_speedmode     ),
    .o_fdi_pl_lnk_cfg              (RP_o_fdi_pl_lnk_cfg           ),
    .o_fdi_pl_state_sts            (RP_o_fdi_pl_state_sts         ),
    .o_fdi_pl_inband_pres          (RP_o_fdi_pl_inband_pres       ),
    .o_fdi_pl_rx_active_req        (RP_o_fdi_pl_rx_active_req     ),
    .o_fdi_pl_clk_req              (RP_o_fdi_pl_clk_req           ),
    .o_fdi_pl_wake_ack             (RP_o_fdi_pl_wake_ack          ),
    .o_fdi_pl_cerror               (RP_o_fdi_pl_cerror            ),
    .o_fdi_pl_nferror              (RP_o_fdi_pl_nferror           ),
    .o_fdi_pl_trainerror           (RP_o_fdi_pl_trainerror        ),
    .o_uncorrectable_error_IRQ     (RP_o_uncorrectable_error_IRQ  ),
    .o_correctable_error_IRQ       (RP_o_correctable_error_IRQ    )
  );

  UC_TOP_EP  UC_TOP_EP_inst (
    .i_clk                         (i_clk                         ),
    .i_rst_n                       (i_rst_n                       ),
    .i_init                        (i_init                        ),
    .i_rdi_pl_cfg                  (EP_i_rdi_pl_cfg               ),
    .i_rdi_pl_cfg_vld              (EP_i_rdi_pl_cfg_vld           ),
    .i_rdi_pl_cfg_crd              (EP_i_rdi_pl_cfg_crd           ),
    .i_rdi_pl_trdy                 (EP_i_rdi_pl_trdy              ),
    .i_rdi_pl_data                 (EP_i_rdi_pl_data              ),
    .i_rdi_pl_valid                (EP_i_rdi_pl_valid             ),
    .i_rdi_pl_inband_pres          (EP_i_rdi_pl_inband_pres       ),
    .i_rdi_pl_phyinrecenter        (EP_i_rdi_pl_phyinrecenter     ),
    .i_rdi_pl_speedmode            (EP_i_rdi_pl_speedmode         ),
    .i_rdi_pl_lnk_cfg              (EP_i_rdi_pl_lnk_cfg           ),
    .i_rdi_pl_state_sts            (EP_i_rdi_pl_state_sts         ),
    .i_rdi_pl_clk_req              (EP_i_rdi_pl_clk_req           ),
    .i_rdi_pl_wake_ack             (EP_i_rdi_pl_wake_ack          ),
    .i_rdi_pl_stall_req            (EP_i_rdi_pl_stall_req         ),
    .i_rdi_pl_error                (EP_i_rdi_pl_error             ),
    .i_rdi_pl_trdy_alsm            (EP_i_rdi_pl_trdy_alsm         ),
    .i_rdi_pl_trainerror           (EP_i_rdi_pl_trainerror        ),
    .i_rdi_pl_cerror               (EP_i_rdi_pl_cerror            ),
    .i_rdi_pl_nferror              (EP_i_rdi_pl_nferror           ),
    .o_rdi_lp_cfg                  (EP_o_rdi_lp_cfg               ),
    .o_rdi_lp_cfg_vld              (EP_o_rdi_lp_cfg_vld           ),
    .o_rdi_lp_cfg_crd              (EP_o_rdi_lp_cfg_crd           ),
    .o_rdi_lp_data                 (EP_o_rdi_lp_data              ),
    .o_rdi_lp_valid                (EP_o_rdi_lp_valid             ),
    .o_rdi_lp_irdy                 (EP_o_rdi_lp_irdy              ),
    .o_rdi_lp_clk_ack              (EP_o_rdi_lp_clk_ack           ),
    .o_rdi_lp_wake_req             (EP_o_rdi_lp_wake_req          ),
    .o_rdi_lp_linkerror            (EP_o_rdi_lp_linkerror         ),
    .o_rdi_lp_state_req            (EP_o_rdi_lp_state_req         ),
    .o_rdi_lp_stall_ack            (EP_o_rdi_lp_stall_ack         ),
    .i_fdi_lp_cfg                  (EP_i_fdi_lp_cfg               ),
    .i_fdi_lp_cfg_vld              (EP_i_fdi_lp_cfg_vld           ),
    .i_fdi_lp_cfg_crd              (EP_i_fdi_lp_cfg_crd           ),
    .i_fdi_lp_irdy                 (EP_i_fdi_lp_irdy              ),
    .i_fdi_lp_valid                (EP_i_fdi_lp_valid             ),
    .i_fdi_lp_data                 (EP_i_fdi_lp_data              ),
    .i_fdi_lp_dllp                 (EP_i_fdi_lp_dllp              ),
    .i_fdi_lp_dllp_valid           (EP_i_fdi_lp_dllp_valid        ),
    .i_fdi_lp_dllp_ofc             (EP_i_fdi_lp_dllp_ofc          ),
    .i_fdi_lp_stream               (EP_i_fdi_lp_stream            ),
    .i_fdi_lp_state_req            (EP_i_fdi_lp_state_req         ),
    .i_fdi_lp_linkerror            (EP_i_fdi_lp_linkerror         ),
    .i_fdi_lp_rx_active_sts        (EP_i_fdi_lp_rx_active_sts     ),
    .i_fdi_lp_stall_ack            (EP_i_fdi_lp_stall_ack         ),
    .i_fdi_lp_clk_ack              (EP_i_fdi_lp_clk_ack           ),
    .i_fdi_lp_wake_req             (EP_i_fdi_lp_wake_req          ),
    .o_fdi_pl_cfg                  (EP_o_fdi_pl_cfg               ),
    .o_fdi_pl_cfg_vld              (EP_o_fdi_pl_cfg_vld           ),
    .o_fdi_pl_cfg_crd              (EP_o_fdi_pl_cfg_crd           ),
    .o_fdi_pl_protocol             (EP_o_fdi_pl_protocol          ),
    .o_fdi_pl_flit_fmt             (EP_o_fdi_pl_flit_fmt          ),
    .o_fdi_pl_valid                (EP_o_fdi_pl_valid             ),
    .o_fdi_pl_protocol_valid       (EP_o_fdi_pl_protocol_valid    ),
    .o_fdi_pl_trdy                 (EP_o_fdi_pl_trdy              ),
    .o_fdi_pl_data                 (EP_o_fdi_pl_data              ),
    .o_fdi_pl_stream               (EP_o_fdi_pl_stream            ),
    .o_fdi_pl_dllp                 (EP_o_fdi_pl_dllp              ),
    .o_fdi_pl_dllp_valid           (EP_o_fdi_pl_dllp_valid        ),
    .o_fdi_pl_dllp_ofc             (EP_o_fdi_pl_dllp_ofc          ),
    .o_fdi_flit_cancel             (EP_o_fdi_flit_cancel          ),
    .o_fdi_pl_stallreq             (EP_o_fdi_pl_stallreq          ),
    .o_fdi_pl_phyinrecenter        (EP_o_fdi_pl_phyinrecenter     ),
    .o_fdi_pl_phyinl1              (EP_o_fdi_pl_phyinl1           ),
    .o_fdi_pl_phyinl2              (EP_o_fdi_pl_phyinl2           ),
    .o_fdi_pl_speedmode            (EP_o_fdi_pl_speedmode         ),
    .o_fdi_pl_max_speedmode        (EP_o_fdi_pl_max_speedmode     ),
    .o_fdi_pl_lnk_cfg              (EP_o_fdi_pl_lnk_cfg           ),
    .o_fdi_pl_state_sts            (EP_o_fdi_pl_state_sts         ),
    .o_fdi_pl_inband_pres          (EP_o_fdi_pl_inband_pres       ),
    .o_fdi_pl_rx_active_req        (EP_o_fdi_pl_rx_active_req     ),
    .o_fdi_pl_clk_req              (EP_o_fdi_pl_clk_req           ),
    .o_fdi_pl_wake_ack             (EP_o_fdi_pl_wake_ack          ),
    .o_fdi_pl_cerror               (EP_o_fdi_pl_cerror            ),
    .o_fdi_pl_nferror              (EP_o_fdi_pl_nferror           ),
    .o_fdi_pl_trainerror           (EP_o_fdi_pl_trainerror        ),
    .o_uncorrectable_error_IRQ     (EP_o_uncorrectable_error_IRQ  ),
    .o_correctable_error_IRQ       (EP_o_correctable_error_IRQ    )
  );

localparam CLK_PERIOD = 10;
initial begin
  i_clk = '0;
  forever begin
    #(CLK_PERIOD/2);
    i_clk = ~i_clk;
  end
end

always_ff @(posedge i_clk or negedge i_rst_n) begin
  if (~i_rst_n || ~i_init) begin
    RP_i_rdi_pl_wake_ack           <= 'b0;
    RP_i_fdi_lp_clk_ack            <= 'b0;
    RP_i_fdi_lp_rx_active_sts      <= 'b0;
    EP_i_rdi_pl_wake_ack           <= 'b0;
    EP_i_fdi_lp_clk_ack            <= 'b0;
    EP_i_fdi_lp_rx_active_sts      <= 'b0;
  end
  else begin
    RP_i_rdi_pl_wake_ack           <= RP_o_rdi_lp_wake_req;
    RP_i_fdi_lp_clk_ack            <= RP_o_fdi_pl_clk_req;
    RP_i_fdi_lp_rx_active_sts      <= RP_o_fdi_pl_rx_active_req;
    EP_i_rdi_pl_wake_ack           <= EP_o_rdi_lp_wake_req;
    EP_i_fdi_lp_clk_ack            <= EP_o_fdi_pl_clk_req;
    EP_i_fdi_lp_rx_active_sts      <= EP_o_fdi_pl_rx_active_req;
  end
end

assign RP_i_fdi_lp_wake_req        = 'b1;
assign RP_i_rdi_pl_clk_req         = 'b1;

assign EP_i_fdi_lp_wake_req        = 'b1;
assign EP_i_rdi_pl_clk_req         = 'b1;

assign EP_i_rdi_pl_cfg     = RP_o_rdi_lp_cfg;
assign EP_i_rdi_pl_cfg_vld = RP_o_rdi_lp_cfg_vld;

assign RP_i_rdi_pl_cfg     = EP_o_rdi_lp_cfg;
assign RP_i_rdi_pl_cfg_vld = EP_o_rdi_lp_cfg_vld;

assign RP_i_rdi_pl_data    = EP_o_rdi_lp_data;
assign EP_i_rdi_pl_data    = RP_o_rdi_lp_data;

assign RP_i_rdi_pl_valid   = EP_o_rdi_lp_valid;
assign EP_i_rdi_pl_valid   = RP_o_rdi_lp_valid;

Request_Pkt req_pkt;

initial begin : main
  reset_values();
  go_active();
  @(negedge i_clk);
  RP_i_rdi_pl_trdy = 'b1;
  EP_i_rdi_pl_trdy = 'b1;

  RP_i_fdi_lp_irdy        = 1'b1;
  RP_i_fdi_lp_data        = {64{8'h11}};
  RP_i_fdi_lp_valid       = 1'b1;
  RP_i_fdi_lp_dllp        = 32'hAABBCCDD;
  RP_i_fdi_lp_dllp_valid  = 1'b1;
  RP_i_fdi_lp_dllp_ofc    = 1'b1;
  RP_i_fdi_lp_stream      = 8'b1010_0000;
  @(negedge i_clk);
  RP_i_fdi_lp_data        = {64{8'h22}};
  @(negedge i_clk);
  RP_i_fdi_lp_data        = {64{8'h33}};
  @(negedge i_clk);
  RP_i_fdi_lp_data[351:0]   = {44{8'hAA}};
  RP_i_fdi_lp_data[511:352] = 160'h0;

  repeat(20) begin
    @(negedge i_clk);
  end
  $stop();
  $finish();
end

always_ff @(posedge i_clk or negedge i_rst_n) begin : registered_interface_signals_block
  if (~i_rst_n || ~i_init) begin
    RP_i_rdi_pl_wake_ack              <= 'b0;
    RP_i_fdi_lp_clk_ack               <= 'b0;
    RP_i_fdi_lp_rx_active_sts         <= 'b0;

    EP_i_rdi_pl_wake_ack              <= 'b0;
    EP_i_fdi_lp_clk_ack               <= 'b0;
    EP_i_fdi_lp_rx_active_sts         <= 'b0;
  end
  else begin
    RP_i_rdi_pl_wake_ack              <= RP_o_rdi_lp_wake_req;
    RP_i_fdi_lp_clk_ack               <= RP_o_fdi_pl_clk_req;
    RP_i_fdi_lp_rx_active_sts         <= RP_o_fdi_pl_rx_active_req;

    EP_i_rdi_pl_wake_ack              <= EP_o_rdi_lp_wake_req;
    EP_i_fdi_lp_clk_ack               <= EP_o_fdi_pl_clk_req;
    EP_i_fdi_lp_rx_active_sts         <= EP_o_fdi_pl_rx_active_req;
  end
end

task go_active();
  @(negedge i_clk);
  @(negedge i_clk);
  @(negedge i_clk);
  req_pkt = new('0, 8'hFF, 3'b001, 'h54, 64'h0_0100_00aa, 5'b01001);
  receive_fdi_full_packet_RP(req_pkt.constructed_pkt);
  receive_fdi_full_packet_EP(req_pkt.constructed_pkt);
  repeat(20) begin
    @(negedge i_clk);
  end

  RP_i_rdi_pl_inband_pres = 'b1;
  EP_i_rdi_pl_inband_pres = 'b1;
  RP_i_rdi_pl_state_sts = LL_Active;
  EP_i_rdi_pl_state_sts = LL_Active;
  repeat(100) begin
    @(negedge i_clk);
  end
  RP_i_fdi_lp_state_req = Req_Active;
  repeat(20) begin
    @(negedge i_clk);
  end
  EP_i_fdi_lp_state_req = Req_Active;
  repeat(20) begin
    @(negedge i_clk);
  end
endtask

task reset_values();
  i_rst_n                          = '0;
  i_init                           = '0;
  // RP reset
  RP_i_rdi_pl_cfg_crd              = 'b1;
  RP_i_rdi_pl_trdy                 = '0;
  RP_i_rdi_pl_inband_pres          = '0;
  RP_i_rdi_pl_phyinrecenter        = '0;
  RP_i_rdi_pl_speedmode            = '0;
  RP_i_rdi_pl_lnk_cfg             = '0;
  RP_i_rdi_pl_state_sts            = LL_Reset;
  RP_i_rdi_pl_stall_req            = '0;
  RP_i_rdi_pl_error                = '0;
  RP_i_rdi_pl_trdy_alsm            = '0;
  RP_i_rdi_pl_trainerror           = '0;
  RP_i_rdi_pl_error_rf             = '0;
  RP_i_rdi_pl_cerror               = '0;
  RP_i_rdi_pl_nferror              = '0;
  RP_i_fdi_lp_cfg                  = '0;
  RP_i_fdi_lp_cfg_vld              = '0;
  RP_i_fdi_lp_cfg_crd              = 'b1;
  RP_i_fdi_lp_irdy                 = '0;
  RP_i_fdi_lp_valid                = '0;
  RP_i_fdi_lp_data                 = '0;
  RP_i_fdi_lp_dllp                 = '0;
  RP_i_fdi_lp_dllp_valid           = '0;
  RP_i_fdi_lp_dllp_ofc             = '0;
  RP_i_fdi_lp_stream               = '0;
  RP_i_fdi_lp_state_req            = Req_NOP;
  RP_i_fdi_lp_linkerror            = '0;
  RP_i_fdi_lp_stall_ack            = '0;
  // EP reset
  EP_i_rdi_pl_cfg_crd              = '0;
  EP_i_rdi_pl_trdy                 = '0;
  EP_i_rdi_pl_inband_pres          = '0;
  EP_i_rdi_pl_phyinrecenter        = '0;
  EP_i_rdi_pl_speedmode            = '0;
  EP_i_rdi_pl_lnk_cfg             = '0;
  EP_i_rdi_pl_state_sts            = LL_Reset;
  EP_i_rdi_pl_stall_req            = '0;
  EP_i_rdi_pl_error                = '0;
  EP_i_rdi_pl_trdy_alsm            = '0;
  EP_i_rdi_pl_trainerror           = '0;
  EP_i_rdi_pl_error_rf             = '0;
  EP_i_rdi_pl_cerror               = '0;
  EP_i_rdi_pl_nferror              = '0;
  EP_i_fdi_lp_cfg                  = '0;
  EP_i_fdi_lp_cfg_vld              = '0;
  EP_i_fdi_lp_cfg_crd              = '0;
  EP_i_fdi_lp_irdy                 = '0;
  EP_i_fdi_lp_valid                = '0;
  EP_i_fdi_lp_data                 = '0;
  EP_i_fdi_lp_dllp                 = '0;
  EP_i_fdi_lp_dllp_valid           = '0;
  EP_i_fdi_lp_dllp_ofc             = '0;
  EP_i_fdi_lp_stream               = '0;
  EP_i_fdi_lp_state_req            = Req_NOP;
  EP_i_fdi_lp_linkerror            = '0;
  EP_i_fdi_lp_stall_ack            = '0;

  @(negedge i_clk);
  @(negedge i_clk);
  i_rst_n = 'b1;
  i_init  = 'b1;
endtask

task receive_fdi_full_packet_EP(logic [127:0] full_packet);
    for (int chunk = 0; chunk < 128/`P_NC; chunk++) begin
        @(negedge i_clk);
        EP_i_fdi_lp_cfg = (full_packet >> (chunk * `P_NC));
        EP_i_fdi_lp_cfg_vld = 1;
    end
    @(negedge i_clk);
    EP_i_fdi_lp_cfg_vld = 0;
endtask

task receive_fdi_full_packet_RP(logic [127:0] full_packet);
    for (int chunk = 0; chunk < 128/`P_NC; chunk++) begin
        @(negedge i_clk);
        RP_i_fdi_lp_cfg = (full_packet >> (chunk * `P_NC));
        RP_i_fdi_lp_cfg_vld = 1;
    end
    @(negedge i_clk);
    RP_i_fdi_lp_cfg_vld = 0;
endtask
endmodule