import UC_retry_pkg::*;

module UC_MB_retry_snh_condition_checker (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             init,
    input  logic             i_flit_sent,
    input  replay_command_t  i_replay_command,
    input  logic [7:0]       i_flit_seq_num,
    input  logic [7:0]       i_tx_acknak_flit_seq_num,
    output logic             o_snh_done,
    output logic             o_snh_timeout
);

    logic        remote_sent_nonzero_fsn;
    logic [3:0]  tx_ack_flit_count;
    logic [3:0]  tx_explicit_fsn_count;
    logic [7:0]  snh_flit_counter;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            remote_sent_nonzero_fsn <= 1'b0;
        else if(!init) begin
            remote_sent_nonzero_fsn <= 1'b0;
        end
        else if (i_tx_acknak_flit_seq_num != 8'h00)
            remote_sent_nonzero_fsn <= 1'b1;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            tx_ack_flit_count <= 4'h0;
        else if(!init) begin
            tx_ack_flit_count <= 4'h0;
        end
        else if (i_flit_sent                     &&
                 i_replay_command == ack          &&
                 i_flit_seq_num   != 8'h00       &&
                 remote_sent_nonzero_fsn          &&
                 tx_ack_flit_count < 4'hF)
            tx_ack_flit_count <= tx_ack_flit_count + 4'h1;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            tx_explicit_fsn_count <= 4'h0;
        else if(!init) begin
            tx_explicit_fsn_count <= 4'h0;
        end
        else if (i_flit_sent                        &&
                 i_replay_command == explicit        &&
                 i_flit_seq_num   != 8'h00          &&
                 tx_explicit_fsn_count < 4'hF)
            tx_explicit_fsn_count <= tx_explicit_fsn_count + 4'h1;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            snh_flit_counter <= 8'h00;
        else if(!init) begin
            snh_flit_counter <= 8'h00;
        end
        else if (i_flit_sent && snh_flit_counter < 8'hFF)
            snh_flit_counter <= snh_flit_counter + 8'h01;
    end

    function automatic logic SNH_condition_met(
        input logic [3:0] ack_cnt,
        input logic [3:0] expl_cnt
    );
        return (ack_cnt >= 4'd3) && (expl_cnt >= 4'd9);
    endfunction

    assign o_snh_done    = SNH_condition_met(tx_ack_flit_count, tx_explicit_fsn_count);
    assign o_snh_timeout = (snh_flit_counter >= 8'd128) && !o_snh_done;

endmodule