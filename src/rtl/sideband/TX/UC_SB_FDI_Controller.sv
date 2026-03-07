/*
Authour: Shahd Mohamed, Ashraf sherif

Module_name: SB_FDI_Controller

Description: The FDI Controller Block is responsible for managing the routing and 
execution of local register access requests, determining whether each 
request targets the PHY or the Adapter and if the request targets the Adapter layer then the
FDI Controller responsible to make it's complition
*/
module SB_FDI_Controller #(
 parameter int P_DATA_W = 64 // 32 or 64
)
(
 //--------------------------- inputs ----------------------------//
 input logic                i_clk,          //clock 
 input logic                i_rst_n,        //reset
 input logic [127:0]        i_Data_out,     // SB local request packet
 input logic                i_empty,        // empty flag from FDI FIFO
 input logic                i_Full,         // full flag from RDI FIFO
 input logic [4:0]          i_comp_opcode,  // completion opcode
 input logic                i_read_req,     // 1 mean the request is read request , 0 mean it's a write request
 input logic                i_config,       // 1 mean the request is configuration request , 0 mean it's a memory request
 input logic [2:0]          i_Local_status, // 000b Successful Completion, 001b Unsupported Request, 100b Completer Abort, 111b Stall
 input logic [P_DATA_W-1:0] i_Local_R_data, // data for the read request
 input logic                i_Local_done,   // from access Arbiter
 input logic                i_is_32b,       // indicate if data=32b or 64b

 //--------------------------outputs--------------------------//
 output logic [127:0]        o_Data_in,                      // SB local request packet that it's dst is the physical layer
 output logic                o_Wr_en,                       // write enable for RDI FIFO
 output logic                o_Rd_en,                      // read enable for FDI FIFO
 output logic [P_DATA_W-1:0] o_Local_wr_data,             // data of the write request for the access arbiter
 output logic                o_Local_wr_en,              // write or read request send to access arbiter
 output logic                o_Local_config_req,        // configuration or memory request
 output logic                o_Local_32_B,             // 32 or 64 data request
 output logic [7:0]          o_Local_BE,              //Byte enable of the local request 
 output logic [23:0]         o_Local_address,        // address of the local request 
 output logic                o_Local_valid,         // 1 mean there is local request want to access a register , 0 if not
 output logic                o_Fdi_credit_release, // Enables Protocol to send a new local request 
 output logic [127:0]        o_Comp_packet,        //response to local Protocol request (where dst of request is adapter) 
 output logic                o_Valid,              // the valid signal for comp_packet
 output logic [4:0]          o_req_opcode         // opcode of the local request
);
//---------------------------------------------IOS finish------------------------------------//
 typedef enum logic [3:0] {
    S_IDLE,
    S_POP,        // assert rd_en
    S_POP_WAIT,   // wait 1 cycle for data_out to become valid
    S_PARSE,
    S_SEND_PHY,
    S_ISSUE_LOCAL,
    S_WAIT_LOCAL,
    S_BUILD_COMP,
    S_PUSH_COMP
  } state_t;

  state_t       r_state;
  logic [127:0] r_req;
  logic [127:0] r_comp;

  // phases
  logic [31:0] p0, p1, p2, p3;
  assign p0 = r_req[31:0];
  assign p1 = r_req[63:32];
  assign p2 = r_req[95:64];
  assign p3 = r_req[127:96];

  // fields
  logic [4:0]  opcode;
  logic [7:0]  be;
  logic        dp, cp;
  logic [2:0]  dstid;
  logic [23:0] addr;
  logic [63:0] data64;

  assign opcode = p0[4:0];
  assign be     = p0[21:14];

  assign dp     = p1[31];
  assign cp     = p1[30];
  assign dstid  = p1[26:24];
  assign addr   = p1[23:0];

  assign data64 = {p3[31:0], p2[31:0]};

  // opcode to packer
  assign o_req_opcode = opcode;

  // parity
  logic exp_dp, exp_cp;
  logic cp_ok, dp_ok;

  assign exp_dp = ^data64;
  // CP = parity of all header bits excluding DP (DP is p1[31])
  assign exp_cp = ^{ p1[30:0], p0[31:0] };

  assign cp_ok  = (cp == exp_cp);
  assign dp_ok  = (dp == exp_dp);

  // outputs
  always_comb begin
    o_Data_in            = r_req;
    o_Wr_en              = 1'b0 ;     
    o_Rd_en              = 1'b0;
    o_Local_wr_data      = '0;
    o_Local_wr_en        = 1'b0;
    o_Local_config_req   = 1'b0;
    o_Local_32_B         = 1'b0;
    o_Local_BE           = '0;
    o_Local_address      = '0;
    o_Local_valid        = 1'b0;
    o_Fdi_credit_release = i_empty;
    o_Comp_packet        = r_comp;
    o_Valid              = 1'b0;

     case (r_state)
      S_POP: begin
        if (!i_empty) begin
          o_Rd_en = 1'b1;
        end
      end

      S_SEND_PHY: begin
        if (!i_Full) begin
          o_Data_in = r_req;
          o_Wr_en   = 1'b1;
        end
      end

      S_ISSUE_LOCAL, // S_ISSUE_LOCAL starts the request, while S_WAIT_LOCAL holds the same request signals stable until i_Local_done is asserted.
      S_WAIT_LOCAL: begin
        o_Local_address    = addr;
        o_Local_BE         = be;
        o_Local_config_req = i_config;
        o_Local_wr_en      = ~i_read_req;
        o_Local_32_B       = i_is_32b;

        if (i_is_32b) begin
          o_Local_wr_data = {{(P_DATA_W-32){1'b0}}, data64[31:0]};
        end
        else begin
          o_Local_wr_data = data64[P_DATA_W-1:0];
        end

        o_Local_valid = 1'b1;
      end

      S_PUSH_COMP: begin
        o_Comp_packet = r_comp;
        o_Valid       = 1'b1;
      end

      default: begin
      end
    endcase
  end

  // FSM
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      r_state <= S_IDLE;
      r_req   <= '0;
      r_comp  <= '0;
    end
    else begin
      case (r_state)
        S_IDLE: begin
          if (!i_empty) begin
            r_state <= S_POP;
          end
        end

        S_POP: begin
          if (!i_empty) begin
            r_state <= S_POP_WAIT;
          end
          else begin
            r_state <= S_IDLE;
          end
        end

        S_POP_WAIT: begin
          r_req   <= i_Data_out;
          r_state <= S_PARSE;
        end

        S_PARSE: begin
          if (!cp_ok || !dp_ok) begin
            r_state <= S_IDLE;
          end
          else if (dstid == 3'b010) begin
            r_state <= S_SEND_PHY;
          end
          else if (dstid ==3'b001) begin
            r_state <= S_ISSUE_LOCAL;
          end
          else begin
            r_state <= S_IDLE;
          end
        end

        S_SEND_PHY: begin
          if (!i_Full) begin
            r_state <= S_IDLE;
          end
        end

        S_ISSUE_LOCAL: begin
          r_state <= S_WAIT_LOCAL;
        end

        S_WAIT_LOCAL: begin
          if (i_Local_done) begin
            r_state <= S_BUILD_COMP;
          end
        end

        S_BUILD_COMP: begin
          logic [127:0] comp_pkt;

          comp_pkt = r_req;

          // completion opcode
          comp_pkt[4:0] = i_comp_opcode;

          // completion status
          comp_pkt[34:32] = i_Local_status;

          // completion data
          if (i_read_req) begin
            if (i_is_32b) begin
              comp_pkt[95:64]  = i_Local_R_data[31:0];
              comp_pkt[127:96] = 32'h0;
            end
            else begin
              comp_pkt[95:64]  = i_Local_R_data[31:0];
              comp_pkt[127:96] = i_Local_R_data[63:32];
            end
          end
          else begin
            comp_pkt[127:64] = 64'h0;
          end

          // compute parity for completion packet
          comp_pkt[63] = ^comp_pkt[127:64];               // dp = p1[31]
          comp_pkt[62] = ^{comp_pkt[61:32], comp_pkt[31:0]}; // cp = p1[30]

          r_comp  <= comp_pkt;
          r_state <= S_PUSH_COMP;
        end

        S_PUSH_COMP: begin
          r_state <= S_IDLE;
        end

        default: begin
          r_state <= S_IDLE;
        end
      endcase
    end
  end

endmodule
    