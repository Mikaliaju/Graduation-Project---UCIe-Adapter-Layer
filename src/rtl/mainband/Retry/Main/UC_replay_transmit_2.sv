//author : fatma fawzy
//module description : retransmits the flits that are stored in the tx retry buffer
//date : 10/3/2026
import common_pkg::*;
module replay_transmit_2 (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             init,
    input  logic             i_replay_scheduled,
    input  logic             i_replay_in_progress,
    input  data_rate_t       data_rate,
    input  logic       [2:0] i_flit_replay_num,
    output logic       [2:0] o_flit_replay_num,
    output logic             o_rdi_retrain_request,
    output logic             o_log_cie
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      o_flit_replay_num <= 3'b0;
      o_rdi_retrain_request <= 1'b0;
      o_log_cie <= 1'b0;
    end else if (!init) begin
      o_flit_replay_num <= 3'b0;
      o_rdi_retrain_request <= 1'b0;
      o_log_cie <= 1'b0;
    end else begin
      if (i_replay_scheduled && !i_replay_in_progress) begin
        if (data_rate <= GTs_32 && i_flit_replay_num >= 3'b110) begin
          o_flit_replay_num <= i_flit_replay_num + 2;
          o_rdi_retrain_request <= 1'b1;
          o_log_cie <= 1'b1;
        end
      end
    end
  end


endmodule
