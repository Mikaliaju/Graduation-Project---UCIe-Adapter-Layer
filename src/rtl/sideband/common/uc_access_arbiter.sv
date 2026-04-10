// =================================================================================================
//  FILENAME    : uc_access_arbiter.sv
//  MODULE      : uc_access_arbiter
//  PROJECT     : UCIe 3.0 Adapter Layer
//  AUTHORS     : Ashraf Sherif, Shahd Mohamed
// =================================================================================================
//  DESCRIPTION : Arbitrates register-file access between local and remote requesters.
//                Remote access has higher priority than local access.
// =================================================================================================
module uc_access_arbiter (
    input  logic         i_clk,
    input  logic         i_rstn,
    input  logic         i_init_n,
 /*Interface with Fdi Ctrl */
    input  logic         i_Local_valid,
    input  logic [63:0]  i_Local_wr_data,
    input  logic         i_Local_wr_en,
    input  logic         i_Local_cofig_req,
    input  logic [23:0]  i_Local_address,
    input  logic [7:0]   i_Local_BE,
    input  logic         i_Local_32_B,
    output logic         o_Local_done,
    output logic [2:0]   o_Local_status,
    output logic [63:0]  o_Local_R_data,
 /*Interface with remote die ctrl */
    input  logic         i_remote_valid,
    input  logic [63:0]  i_remote_wr_data,
    input  logic         i_remote_wr_en,
    input  logic [23:0]  i_remote_address,
    input  logic [7:0]   i_remote_BE,
    input  logic         i_remote_cofig_req,
    input  logic         i_remote_32_B,
    output logic         o_remote_done,
    output logic [2:0]   o_remote_status,
    output logic [63:0]  o_remote_R_data,
 /*Interface with Reg file */
    input  logic [63:0]  i_R_data,
    input  logic [2:0]   i_Status,
    output logic [63:0]  o_wr_data,
    output logic         o_wr_en,
    output logic [23:0]  o_address,
    output logic [7:0]   o_BE,
    output logic         o_cofig_req,
    output logic         o_32_B,
    output logic         o_register_valid  
);
    always_ff @(posedge i_clk, negedge i_rstn) begin
        if (~i_rstn) begin
            o_Local_R_data   <= 0;
            o_Local_status   <= 0;
            o_remote_R_data  <= 0;
            o_remote_status  <= 0;
        end else if (~i_init_n) begin
            o_Local_R_data   <= 0;
            o_Local_status   <= 0;
            o_remote_R_data  <= 0;
            o_remote_status  <= 0;
        end else begin
            if (o_remote_done) begin
                o_remote_R_data <= i_R_data;
                o_remote_status <= i_Status;
            end
            if (o_Local_done) begin
                o_Local_R_data <= i_R_data;
                o_Local_status <= i_Status;
            end
        end
    end
    always_comb begin 
        if (i_remote_valid) begin
            o_wr_data         = i_remote_wr_data;
            o_wr_en           = i_remote_wr_en;
            o_address         = i_remote_address;
            o_BE              = i_remote_BE;
            o_cofig_req       = i_remote_cofig_req;
            o_32_B            = i_remote_32_B;
            o_register_valid  = 1'b1;
            o_remote_done     = 1'b1;
            o_Local_done      = 1'b0;
        end else if (i_Local_valid) begin
            o_wr_data         = i_Local_wr_data;
            o_wr_en           = i_Local_wr_en;
            o_address         = i_Local_address;
            o_BE              = i_Local_BE;
            o_cofig_req       = i_Local_cofig_req;
            o_32_B            = i_Local_32_B;
            o_register_valid  = 1'b1;
            o_Local_done      = 1'b1;
            o_remote_done     = 1'b0;
        end else begin
            o_wr_data         = 0;
            o_wr_en           = 0;
            o_address         = 0;
            o_BE              = 0;
            o_cofig_req       = 0;
            o_32_B            = 0;
            o_register_valid  = 0;
            o_Local_done      = 0;
            o_remote_done     = 0;
        end
    end
endmodule
