
module UC_sb_FDI_Controller #(
    parameter int FIFO_WEDITH = 128  
)(
    input  logic                        i_clk,
    input  logic                        i_rst_n,
    input  logic                        i_init_n,

    input  logic [FIFO_WEDITH - 1 : 0]  i_fdi_fifo_out,
    input  logic                        i_fdi_fifo_empty,
    input  logic                        i_rdi_fifo_full,

    input  logic [4:0]                  i_comp_opcode,
    input  logic                        i_read_req,
    input  logic                        i_config_req,
    input  logic                        i_is_32b,
    input  logic                        i_rx_fifo_full,

    input  logic [2:0]                  i_Local_status,
    input  logic [63:0]                 i_Local_read_data,
    input  logic                        i_Local_arbiter_done,

    input  logic                        i_tag_correct,
    input  logic [4:0]                  i_tag_new,
   // input  logic                        i_tag_uncorrect,

    output logic [FIFO_WEDITH:0]     o_to_rdi_req,
    output logic                        o_to_rdi_req_vlaid,
    output logic                        o_fdi_fifo_r_en,

    output logic [63:0]                 o_Local_wr_data,
    output logic                        o_Local_wr_en,
    output logic                        o_Local_config_req,
    output logic                        o_Local_32_B,
    output logic [7:0]                  o_Local_BE,
    output logic [23:0]                 o_Local_address,
    output logic                        o_Local_valid,

    output logic                        o_Fdi_credit_release,

    output logic [FIFO_WEDITH - 1:0] o_rx_Comp_packet,
    output logic                        o_rx_Comp_packet_valid,

    output logic [4:0]                  o_req_opcode,

    output logic                        o_tag_valid,
    output logic [4:0]                  o_phy_tag,

    output logic                        o_lsm_parity_error
);

// =======================================================================================
//                              Internal Signals
// =======================================================================================

logic [FIFO_WEDITH-1:0] r_fdi_fifo_out;

logic                   s_control_parity;
logic                   s_data_parity;
logic                   s_control_parity_error;
logic                   s_data_parity_error;
logic                   s_parity_error;

logic                   s_ep_bit;
logic                   s_is_adapter;
logic                   s_is_phy;

logic                   s_fifo_r_en_from_idle;
logic                   s_fifo_r_en_from_rx;
logic                   s_fifo_r_en_from_rdi;

logic                   s_reg_ur_ca;
logic                   s_adapter_ur;

logic [4:0]             s_comp_opcode;
logic [2:0]             s_comp_status;
logic                   s_completion_control_parity;
logic                   s_completion_data_parity;
logic [61:0]            s_comp_header;
logic [63:0]            s_comp_data;

logic [63:0]            s_fdi_to_rdi_req_header;
logic                   s_old_tag_parity;
logic                   s_new_tag_parity;
logic                   s_new_parity;

// =======================================================================================
//                              State Encoding
// =======================================================================================

typedef enum logic [2:0] {
    FDI_CTRL_IDLE         = 3'b000,
    FDI_CTRL_CHK_PARITY   = 3'b001,
    FDI_CTRL_LOCAL_ACCESS = 3'b010,
    FDI_CTRL_SEND_COMP    = 3'b011,
    FDI_CTRL_SEND_PHY     = 3'b100
} fdi_ctrl_state_t;

fdi_ctrl_state_t r_current_state, s_next_state;

// =======================================================================================
//                              State Register
// =======================================================================================

always_ff @(posedge i_clk, negedge i_rst_n) begin : state_reg_proc
    if (~i_rst_n)
        r_current_state <= FDI_CTRL_IDLE;
    else if (~i_init_n)
        r_current_state <= FDI_CTRL_IDLE;
    else
        r_current_state <= s_next_state;
end

// =======================================================================================
//                              Next State Logic
// =======================================================================================

always_comb begin : next_state_proc
    s_next_state = r_current_state;

    case (r_current_state)

        FDI_CTRL_IDLE : begin
            if (!i_fdi_fifo_empty)
                s_next_state = FDI_CTRL_CHK_PARITY;
        end

        FDI_CTRL_CHK_PARITY : begin
            if (s_parity_error)
                s_next_state = FDI_CTRL_IDLE;
            else if (s_ep_bit)
                s_next_state = FDI_CTRL_SEND_COMP;
            else if (s_is_adapter)
                s_next_state = FDI_CTRL_LOCAL_ACCESS;
            else if (s_is_phy)
                s_next_state = FDI_CTRL_SEND_PHY;
            else
                s_next_state = FDI_CTRL_SEND_COMP;   // reserved dstid → UR
        end

        FDI_CTRL_LOCAL_ACCESS : begin
            if (i_Local_arbiter_done)
                s_next_state = FDI_CTRL_SEND_COMP;
            else
                s_next_state = FDI_CTRL_LOCAL_ACCESS;
        end

        FDI_CTRL_SEND_COMP : begin
            if (i_rx_fifo_full)
                s_next_state = FDI_CTRL_SEND_COMP;
            else begin
                if (!i_fdi_fifo_empty)
                    s_next_state = FDI_CTRL_CHK_PARITY;
                else
                    s_next_state = FDI_CTRL_IDLE;
            end
        end

        FDI_CTRL_SEND_PHY : begin
            if (i_rdi_fifo_full)
                s_next_state = FDI_CTRL_SEND_PHY;
            else begin
                if (!i_fdi_fifo_empty)
                    s_next_state = FDI_CTRL_CHK_PARITY;
                else
                    s_next_state = FDI_CTRL_IDLE;
            end
        end

        default: s_next_state = FDI_CTRL_IDLE;

    endcase
end

// =======================================================================================
//                              Capture FDI FIFO Output
// =======================================================================================

always_ff @(posedge i_clk, negedge i_rst_n) begin : reg_fdi_fifo_out
    if (~i_rst_n)
        r_fdi_fifo_out <= '0;
    else if (~i_init_n)
        r_fdi_fifo_out <= '0;
    else if (o_fdi_fifo_r_en)
        r_fdi_fifo_out <= i_fdi_fifo_out;
end

assign s_fifo_r_en_from_idle = (r_current_state == FDI_CTRL_IDLE)      && (!i_fdi_fifo_empty);
assign s_fifo_r_en_from_rx   = (r_current_state == FDI_CTRL_SEND_COMP) && (!i_fdi_fifo_empty);
assign s_fifo_r_en_from_rdi  = (r_current_state == FDI_CTRL_SEND_PHY)  && (!i_fdi_fifo_empty);

assign o_fdi_fifo_r_en = s_fifo_r_en_from_idle |
                         s_fifo_r_en_from_rx   |
                         s_fifo_r_en_from_rdi;

// =======================================================================================
//                              Parity Check
// =======================================================================================

assign s_control_parity       = ^r_fdi_fifo_out[61:0];
assign s_data_parity          = ^r_fdi_fifo_out[127:64];

assign s_control_parity_error = (s_control_parity != r_fdi_fifo_out[62]);
assign s_data_parity_error    = (s_data_parity    != r_fdi_fifo_out[63]);

assign s_parity_error         = (r_current_state == FDI_CTRL_CHK_PARITY)
                                && (s_control_parity_error || s_data_parity_error);

assign o_lsm_parity_error     = s_parity_error;

// =======================================================================================
//                              Destination Decode
// =======================================================================================

assign s_ep_bit      =  r_fdi_fifo_out[5];
assign s_is_adapter  = (r_fdi_fifo_out[58:56] == 3'b001);
assign s_is_phy      = (r_fdi_fifo_out[58:56] == 3'b010);

// =======================================================================================
//                              Completion Construction
// =======================================================================================

assign s_reg_ur_ca   = (i_Local_status != 3'b000);
assign s_adapter_ur  =  s_ep_bit || (!s_is_adapter && !s_is_phy);

assign s_comp_status = (s_adapter_ur || s_reg_ur_ca) ? 3'b001        : i_Local_status;
assign s_comp_opcode = (s_adapter_ur || s_reg_ur_ca) ? 5'b11001      : i_comp_opcode;

assign s_comp_header = {1'b0,
                        r_fdi_fifo_out[60:35],
                        s_comp_status,
                        r_fdi_fifo_out[31:5],
                        s_comp_opcode};

assign s_completion_control_parity = ^s_comp_header;

assign s_comp_data = (s_adapter_ur || s_reg_ur_ca) ? r_fdi_fifo_out[63:0]
                                                    : i_Local_read_data;

assign s_completion_data_parity = ^s_comp_data;

assign o_rx_Comp_packet       = {s_comp_data,
                                  s_completion_data_parity,
                                  s_completion_control_parity,
                                  s_comp_header};

assign o_rx_Comp_packet_valid = (r_current_state == FDI_CTRL_SEND_COMP) && !i_rx_fifo_full;

// =======================================================================================
//                              Local (Register File) Interface
// =======================================================================================

assign o_Local_wr_data    = r_fdi_fifo_out[127:64];
assign o_Local_address    = r_fdi_fifo_out[55:32];
assign o_Local_BE         = i_is_32b ? {4'b0000, r_fdi_fifo_out[17:14]}
                                     : r_fdi_fifo_out[21:14];
assign o_Local_wr_en      = !i_read_req;
assign o_Local_config_req = i_config_req;
assign o_Local_32_B       = i_is_32b;
assign o_Local_valid      = (r_current_state == FDI_CTRL_LOCAL_ACCESS);

// =======================================================================================
//                              Tag Manager Interface + PHY Forwarding
// =======================================================================================

assign o_tag_valid = ((r_current_state == FDI_CTRL_CHK_PARITY) &&
                       s_is_phy &&
                      !(s_parity_error && i_rdi_fifo_full))
                   ||((r_current_state == FDI_CTRL_SEND_PHY) &&
                       !i_tag_correct &&
                       !i_rdi_fifo_full);

assign o_phy_tag = r_fdi_fifo_out[26:22];

assign s_old_tag_parity = ^r_fdi_fifo_out[26:22];
assign s_new_tag_parity = ^i_tag_new;
assign s_new_parity     =  s_old_tag_parity ^ s_new_tag_parity;

assign s_fdi_to_rdi_req_header = i_tag_correct
    ? r_fdi_fifo_out[63:0]
    : {r_fdi_fifo_out[63],
       s_new_parity,
       r_fdi_fifo_out[61:27],
       i_tag_new,
       r_fdi_fifo_out[21:0]};

assign o_to_rdi_req       = {i_read_req,r_fdi_fifo_out[127:64], s_fdi_to_rdi_req_header};

assign o_to_rdi_req_vlaid = (r_current_state == FDI_CTRL_SEND_PHY) ;

// =======================================================================================
//                              Credit Release + Opcode
// =======================================================================================

assign o_Fdi_credit_release = o_fdi_fifo_r_en;
assign o_req_opcode         = r_fdi_fifo_out[4:0];

endmodule