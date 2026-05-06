// ================================================================================================================================
//  FILENAME    : UC_rx_msgs_ctrl.sv
//  MODULE      : UC_rx_msgs_ctrl
//  PROJECT     : UCIe 3.0 Adapter Layer
//  AUTHOR      : Ashraf Sherif, Shahd Mohamed
// ================================================================================================================================
//  Description : It handles the received messages over RDI and decodes
//               the messages without data, while messages with data are
//               collected, parity checked, then forwarded to their dedicated
//               handling block.
// ================================================================================================================================
import UC_sb_rx_pkg::*;
module UC_rx_msgs_ctrl #(parameter NC = 32) (

    input  logic               i_clk,
    input  logic               i_rstn,
    input  logic               i_init_n,

    /* Messages FIFO */
    input  logic               i_msgs_fifo_empty,
    input  logic  [NC-1:0]     i_msg_phase,
    output logic               o_read_msg_fifo,

    /* Msgs with data CTRL */
    output logic  [127:0]      o_rx_msg,
    output logic               o_rx_msg_vld,

    `ifndef END_POINT
    /* Remote Reqs CTRL */
    output logic               o_e2e_crds_return_vld,
    `endif

    /* Credit Loop CTRL */
    output logic               o_rdi_crd_release,

    /* LSM */
    `ifndef END_POINT
    output sb_error_msg_encoding  o_sb_err_msg_rx,
    `endif
    output sb_state_msg_encoding  o_sb_state_msg_rx,
    output logic               o_msg_parity_err,
    output logic               o_msg_invld_id_err
);
// ================================================== Internal Signals ==================================================
    msgc_sts  r_state, w_next_state;

    logic [CHUNK_COUNTER_WIDTH-1:0] r_phase_count;
    logic [127:0]                   r_packet_buf;

    logic        w_is_msg_no_data;
    logic        w_collect_done;
    logic        w_parity_check_en;
    logic        w_ctrl_parity_calc;
    logic        w_data_parity_calc;
    logic        w_parity_error;
    logic        w_invalid_ids;

    logic [7:0]  w_msg_code;
    logic [7:0]  w_msg_subcode;
    logic [15:0] w_msg_info;
    logic [2:0]  w_msg_srcid;
    logic [2:0]  w_msg_dstid;

// ================================================== Packet Field Decode ==================================================
    assign w_is_msg_no_data = (r_packet_buf[4:0] == 5'b10010);

    assign w_collect_done =
           ((r_phase_count == (64/NC  - 1)) &&  w_is_msg_no_data) ||
            (r_phase_count == (128/NC - 1));

    assign w_parity_check_en   = (r_state == MSGC_PARITY_CHK);
    assign w_ctrl_parity_calc  = w_parity_check_en ? ^r_packet_buf[61:0]   : 1'b0;
    assign w_data_parity_calc  = w_parity_check_en ? ^r_packet_buf[127:64] : 1'b0;

    assign w_parity_error =
           (w_ctrl_parity_calc != r_packet_buf[62]) ||
           (w_data_parity_calc != r_packet_buf[63]);

    assign w_msg_code    = ((r_state == MSGC_PARITY_CHK) && w_is_msg_no_data) ? r_packet_buf[21:14] : 8'b0;
    assign w_msg_subcode = ((r_state == MSGC_PARITY_CHK) && w_is_msg_no_data) ? r_packet_buf[39:32] : 8'b0;
    assign w_msg_info    = ((r_state == MSGC_PARITY_CHK) && w_is_msg_no_data) ? r_packet_buf[55:40] : 16'b0;
    assign w_msg_srcid   =  (r_state == MSGC_PARITY_CHK) ? r_packet_buf[31:29] : 3'b0;
    assign w_msg_dstid   =  (r_state == MSGC_PARITY_CHK) ? r_packet_buf[58:56] : 3'b0;

    assign w_invalid_ids = (w_msg_srcid != 3'b001) || (w_msg_dstid != 3'b101);

// ================================================== State Register ==================================================
    always_ff @(posedge i_clk or negedge i_rstn) begin : state_ff
        if (!i_rstn) begin
            r_state <= MSGC_IDLE;
        end
        else if (!i_init_n) begin
            r_state <= MSGC_IDLE;
        end
        else begin
            r_state <= w_next_state;
        end
    end
// ================================================== Packet Buffer + Counter ==================================================
    always_ff @(posedge i_clk or negedge i_rstn) begin : packet_storage_ff
        if (!i_rstn) begin
            r_packet_buf <= '0;
            r_phase_count <= '0;
        end
        else if (!i_init_n) begin
            r_packet_buf <= '0;
            r_phase_count <= '0;
        end
        else begin
            case (r_state)
                MSGC_COLLECT_PKT: begin
                    if (r_phase_count == '0) begin
                        r_packet_buf <= 128'(i_msg_phase);
                    end
                    else begin
                        r_packet_buf <= 128'(r_packet_buf | (128'(i_msg_phase) << (r_phase_count * NC)));
                    end

                    if (w_is_msg_no_data && (r_phase_count == (64/NC - 1))) begin
                        r_phase_count <= '0;
                    end
                    else begin
                        r_phase_count <= r_phase_count + 1'b1;
                    end
                end

                default: begin
                    // hold value
                end
            endcase
        end
    end

//=================================================== Next State Logic ==================================================
    always_comb begin : next_state_comb
        w_next_state = r_state;

        case (r_state)
            MSGC_IDLE: begin
                if (i_msgs_fifo_empty) begin
                    w_next_state = MSGC_IDLE;
                end
                else begin
                    w_next_state = MSGC_COLLECT_PKT;
                end
            end

            MSGC_COLLECT_PKT: begin
                if (w_collect_done) begin
                    w_next_state = MSGC_PARITY_CHK;
                end
                else begin
                    w_next_state = MSGC_COLLECT_PKT;
                end
            end

            MSGC_PARITY_CHK: begin
                if (w_parity_error) begin
                    w_next_state = MSGC_PARITY_ERR;
                end
                else if (w_invalid_ids) begin
                    w_next_state = MSGC_INVLD_ID_ERR;
                end
                else if (i_msgs_fifo_empty) begin
                    w_next_state = MSGC_IDLE;
                end
                else begin
                    w_next_state = MSGC_COLLECT_PKT;
                end
            end

            MSGC_PARITY_ERR: begin
                w_next_state = MSGC_PARITY_ERR;
            end

            MSGC_INVLD_ID_ERR: begin
                w_next_state = MSGC_INVLD_ID_ERR;
            end

            default: begin
                w_next_state = MSGC_IDLE;
            end
        endcase
    end
//===================================================== Output Logic ===========================================   
    always_comb begin : outputs_comb
        o_read_msg_fifo       = 1'b0;
        o_rx_msg              = '0;
        o_rx_msg_vld          = 1'b0;
        o_rdi_crd_release     = 1'b0;
        o_msg_parity_err      = 1'b0;
        o_msg_invld_id_err    = 1'b0;
        o_sb_state_msg_rx     = NONE;

        `ifndef END_POINT
        o_e2e_crds_return_vld = 1'b0;
        o_sb_err_msg_rx       = NONE_ERR;
        `endif
        case (r_state)
            MSGC_IDLE: begin
                if (!i_msgs_fifo_empty) begin
                    o_read_msg_fifo = 1'b1;
                end
            end
            MSGC_COLLECT_PKT: begin
                o_read_msg_fifo = 1'b1;

                if (w_collect_done) begin
                    o_read_msg_fifo   = 1'b0;
                    o_rdi_crd_release = 1'b1;
                end
            end

            MSGC_PARITY_CHK: begin
                if (w_parity_error) begin
                    o_msg_parity_err = 1'b1;
                end
                else if (w_invalid_ids) begin
                    o_msg_invld_id_err = 1'b1;
                end
                else if (w_is_msg_no_data) begin
                    if ((w_msg_code == 8'h03) && (w_msg_info == 16'h0)) begin
                        case (w_msg_subcode)
                            8'h01: o_sb_state_msg_rx = ACTIVE_REQ;
                            8'h04: o_sb_state_msg_rx = L1_REQ;
                            8'h08: o_sb_state_msg_rx = L2_REQ;
                            8'h09: o_sb_state_msg_rx = LINKRESET_REQ;
                            8'h0C: o_sb_state_msg_rx = DISABLED_REQ;
                            default: o_sb_state_msg_rx = NONE;
                        endcase
                    end
                    else if ((w_msg_code == 8'h04) && (w_msg_info == 16'h0)) begin
                        case (w_msg_subcode)
                            8'h01: o_sb_state_msg_rx = ACTIVE_RESP;
                            8'h02: o_sb_state_msg_rx = PMNAK_RESP;
                            8'h04: o_sb_state_msg_rx = L1_RESP;
                            8'h08: o_sb_state_msg_rx = L2_RESP;
                            8'h09: o_sb_state_msg_rx = LINKRESET_RESP;
                            8'h0C: o_sb_state_msg_rx = DISABLED_RESP;
                            default: o_sb_state_msg_rx = NONE;
                        endcase
                    end

                    `ifndef END_POINT
                    else if ((w_msg_code == 8'h00) && (w_msg_subcode == 8'h00)) begin
                        case (w_msg_info)
                            16'h0001,
                            16'h0002,
                            16'h0003,
                            16'h0004: o_e2e_crds_return_vld = 1'b1;
                            default : o_e2e_crds_return_vld = 1'b0;
                        endcase
                    end
                    else if (w_msg_code == 8'h09) begin
                        case (w_msg_subcode)
                            8'h00: o_sb_err_msg_rx = Correctable_Err;
                            8'h01: o_sb_err_msg_rx = NON_FATAL_Err;
                            8'h02: o_sb_err_msg_rx = FATAL_Err;
                            default: o_sb_err_msg_rx = NONE_ERR;
                        endcase
                    end
                    `endif

                    if (!i_msgs_fifo_empty) begin
                        o_read_msg_fifo = 1'b1;
                    end
                end
                else begin
                    o_rx_msg     = r_packet_buf;
                    o_rx_msg_vld = 1'b1;

                    if (!i_msgs_fifo_empty) begin
                        o_read_msg_fifo = 1'b1;
                    end
                end
            end

            MSGC_PARITY_ERR: begin
                o_msg_parity_err = 1'b1;
            end

            MSGC_INVLD_ID_ERR: begin
                o_msg_invld_id_err = 1'b1;
            end
            default: begin
            
            end
        endcase
    end

endmodule
