module UC_sb_FDI_Packer #(
    parameter int P_NC           = 32,
    parameter int P_FIFO_WEDITH  = 128
) (
    // A. Inputs
    input  logic                            i_clk,
    input  logic                            i_rst_n,
    input  logic                            i_init_n,

    // From FDI
    input  logic [P_NC - 1 : 0]            i_lp_cfg,
    input  logic                            i_lp_cfg_vld,

    // From FDI FIFO
    input  logic                            i_fdi_fifo_full,

    // From Opcode Decoder
    input  logic                            i_request_type,   // 0 = 64b / 2 phases, 1 = 128b / 4 phases
    input  logic                            i_opcode_error,

    // To Opcode Decoder
    output logic [4:0]                      o_opcode,

    // To LSM
    output logic                            o_fdi_overflow,

    // To RegFile and Interrupt
    output logic                            o_fdi_fifo_cntrl_error,

    // To FDI FIFO
    output logic [P_FIFO_WEDITH-1 : 0]     o_fdi_fifo_data_in,
    output logic                            o_fdi_fifo_wr_en
);

    // =======================================================================================
    // Local parameters
    // =======================================================================================

    localparam int LP_TX_MAX_WRITES  = P_FIFO_WEDITH / P_NC;       // 128 / 32 = 4
    localparam int LP_TX_HALF_WRITES = LP_TX_MAX_WRITES / 2;        // 4 / 2   = 2

    // =======================================================================================
    // State Encoding
    // =======================================================================================

    typedef enum logic [1:0] {
        FIFO_READY   = 2'b00,
        FIFO_COLLECT = 2'b01,
        FIFO_ERROR   = 2'b10
    } fdi_fifo_cntrl_state_t;

    fdi_fifo_cntrl_state_t r_current_state;
    fdi_fifo_cntrl_state_t r_next_state;

    // =======================================================================================
    // Internal Signals
    // =======================================================================================

    logic [$clog2(LP_TX_MAX_WRITES)-1:0]    r_phases_counter;
    logic                                   s_inc_counter;
    logic [LP_TX_MAX_WRITES-2:0][P_NC-1:0] s_phase_data;
    logic                                   s_reg_cfg;
    logic [P_FIFO_WEDITH-1 : 0]            s_fifo_req_in;
    logic                                   s_reach_max;
    logic                                   s_reach_half;

    // Opcode latch
    logic [4:0]                             r_opcode;

    // =======================================================================================
    // State Register
    // =======================================================================================

    always_ff @(posedge i_clk or negedge i_rst_n) begin : reg_next_state_proc
        if (~i_rst_n) begin
            r_current_state <= FIFO_READY;
        end
        else if (~i_init_n) begin
            r_current_state <= FIFO_READY;
        end
        else begin
            r_current_state <= r_next_state;
        end
    end

    // =======================================================================================
    // Next State and Output Logic
    // =======================================================================================

    always_comb begin : next_state_and_output_logic_proc

        r_next_state             = r_current_state;
        s_inc_counter            = 1'b0;
        s_reg_cfg                = 1'b0;
        o_fdi_fifo_wr_en         = 1'b0;
        o_fdi_fifo_cntrl_error   = 1'b0;

        case (r_current_state)

            FIFO_READY : begin
                if (!i_fdi_fifo_full && i_lp_cfg_vld) begin
                    s_inc_counter          = 1'b1;
                    s_reg_cfg              = 1'b1;
                    r_next_state           = FIFO_COLLECT;
                end
                else begin
                    r_next_state           = FIFO_READY;
                end
            end

            FIFO_COLLECT : begin

                if (!i_opcode_error) begin

                    if ((s_reach_max && i_request_type) ||
                        (s_reach_half && !i_request_type)) begin

                        r_next_state           = FIFO_READY;
                        s_inc_counter          = 1'b0;
                        s_reg_cfg              = 1'b0;
                        o_fdi_fifo_wr_en       = 1'b1;
                        o_fdi_fifo_cntrl_error = 1'b0;

                    end
                    else if (!i_lp_cfg_vld) begin

                        r_next_state           = FIFO_READY;
                        s_inc_counter          = 1'b0;
                        s_reg_cfg              = 1'b0;
                        o_fdi_fifo_wr_en       = 1'b0;
                        o_fdi_fifo_cntrl_error = 1'b1;

                    end
                    else begin

                        r_next_state           = FIFO_COLLECT;
                        s_inc_counter          = 1'b1;
                        s_reg_cfg              = 1'b1;
                        o_fdi_fifo_wr_en       = 1'b0;
                        o_fdi_fifo_cntrl_error = 1'b0;

                    end

                end
                else begin

                    r_next_state             = FIFO_ERROR;
                    s_inc_counter            = 1'b0;
                    s_reg_cfg                = 1'b0;
                    o_fdi_fifo_wr_en         = 1'b0;
                    o_fdi_fifo_cntrl_error   = 1'b0;

                end
            end

            FIFO_ERROR : begin

                if (!i_lp_cfg_vld) begin
                    r_next_state = FIFO_READY;
                end
                else begin
                    r_next_state = FIFO_ERROR;
                end

                s_inc_counter            = 1'b0;
                s_reg_cfg                = 1'b0;
                o_fdi_fifo_wr_en         = 1'b0;
                o_fdi_fifo_cntrl_error   = 1'b1;

            end

            default : begin
                r_next_state             = FIFO_READY;
                s_inc_counter            = 1'b0;
                s_reg_cfg                = 1'b0;
                o_fdi_fifo_wr_en         = 1'b0;
                o_fdi_fifo_cntrl_error   = 1'b0;
            end

        endcase
    end

    // =======================================================================================
    // Register FDI Phases
    // =======================================================================================

    always_ff @(posedge i_clk or negedge i_rst_n) begin : register_cfg_proc
        if (~i_rst_n) begin
            foreach (s_phase_data[i]) begin
                s_phase_data[i] <= '0;
            end
        end
        else if (~i_init_n) begin
            foreach (s_phase_data[i]) begin
                s_phase_data[i] <= '0;
            end
        end
        else if (s_reg_cfg) begin
            s_phase_data[r_phases_counter] <= i_lp_cfg;
        end
    end

    // =======================================================================================
    // Opcode Latch
    // =======================================================================================


  always_ff @(posedge i_clk or negedge i_rst_n) begin : opcode_latch_proc
    if (~i_rst_n) begin
        r_opcode <= 5'd0;
    end
    else if (~i_init_n) begin
        r_opcode <= 5'd0;
    end
    else if (s_reg_cfg && (r_phases_counter == 0)) begin
        r_opcode <= i_lp_cfg[4:0];
    end
end

assign o_opcode = (i_lp_cfg_vld && (r_current_state == FIFO_READY))
                  ? i_lp_cfg[4:0]
                  : r_opcode;
   

    // =======================================================================================
    // Counter
    // =======================================================================================

    always_ff @(posedge i_clk or negedge i_rst_n) begin : Counter_proc
        if (~i_rst_n) begin
            r_phases_counter <= '0;
        end
        else if (~i_init_n) begin
            r_phases_counter <= '0;
        end
        else if (o_fdi_fifo_wr_en) begin
            r_phases_counter <= '0;
        end
        else if (r_current_state == FIFO_ERROR) begin
            r_phases_counter <= '0;
        end
        else if (s_inc_counter) begin
            r_phases_counter <= r_phases_counter + 1'b1;
        end
    end

    // =======================================================================================
    // Reach Conditions
    // =======================================================================================

    assign s_reach_max  = (r_phases_counter == LP_TX_MAX_WRITES  - 1);
    assign s_reach_half = (r_phases_counter == LP_TX_HALF_WRITES - 1);

    // =======================================================================================
    // FIFO Data Packing
    // =======================================================================================

    assign s_fifo_req_in = (s_reach_max) ?
                           {i_lp_cfg, s_phase_data} :
                           {64'b0, i_lp_cfg, s_phase_data[LP_TX_HALF_WRITES - 2 : 0]};

    assign o_fdi_fifo_data_in = s_fifo_req_in;

    // =======================================================================================
    // Overflow Condition
    // =======================================================================================

    assign o_fdi_overflow = (r_current_state == FIFO_READY) &&
                            i_lp_cfg_vld &&
                            i_fdi_fifo_full;

endmodule
