package UC_sb_block_pkg ;
 //start Side band FDI packer//
  // FSM states
  typedef enum logic [1:0] {S_IDLE, S_COLLECT, S_PUSH} fdi_state_e;

  // Decode results
  typedef struct packed {
    logic       valid;
    logic       is_read;
    logic       is_conf;
    logic [6:0] data_bits;          // 0/32/64 (payload bits)
    logic [4:0] completion_opcode;
  } fdi_dec_t;

  // Opcode encoding
  localparam logic [4:0] FDI_OP_MEM_RD_32    = 5'b00000;
  localparam logic [4:0] FDI_OP_MEM_WR_32    = 5'b00001;

  localparam logic [4:0] FDI_OP_CFG_RD_32    = 5'b00100;
  localparam logic [4:0] FDI_OP_CFG_WR_32    = 5'b00101;

  localparam logic [4:0] FDI_OP_MEM_RD_64    = 5'b01000;
  localparam logic [4:0] FDI_OP_MEM_WR_64    = 5'b01001;
  
  localparam logic [4:0] FDI_OP_CFG_RD_64    = 5'b01100;
  localparam logic [4:0] FDI_OP_CFG_WR_64    = 5'b01101;

  localparam logic [4:0] FDI_OP_COMP_NO_DATA = 5'b10000;
  localparam logic [4:0] FDI_OP_COMP_32_DATA = 5'b10001;
  localparam logic [4:0] FDI_OP_COMP_64_DATA = 5'b11001;

  function automatic fdi_dec_t fdi_decode_opcode(input logic [4:0] op);
    fdi_dec_t decode_result;
    decode_result = '0;

    unique case (op)
      FDI_OP_MEM_RD_32, FDI_OP_CFG_RD_32: begin
        decode_result.valid             = 1'b1;
        decode_result.is_read           = 1'b1;
        decode_result.data_bits         = 7'd0;
        decode_result.completion_opcode = FDI_OP_COMP_32_DATA;
        decode_result.is_conf           = (op == FDI_OP_CFG_RD_32);
      end

      FDI_OP_MEM_RD_64, FDI_OP_CFG_RD_64: begin
        decode_result.valid             = 1'b1;
        decode_result.is_read           = 1'b1;
        decode_result.data_bits         = 7'd0;
        decode_result.completion_opcode = FDI_OP_COMP_64_DATA;
        decode_result.is_conf           = (op == FDI_OP_CFG_RD_64);
      end

      FDI_OP_MEM_WR_32, FDI_OP_CFG_WR_32: begin
        decode_result.valid             = 1'b1;
        decode_result.is_read           = 1'b0;
        decode_result.data_bits         = 7'd32;
        decode_result.completion_opcode = FDI_OP_COMP_NO_DATA;
        decode_result.is_conf           = (op == FDI_OP_CFG_WR_32);
      end

      FDI_OP_MEM_WR_64, FDI_OP_CFG_WR_64: begin
        decode_result.valid             = 1'b1;
        decode_result.is_read           = 1'b0;
        decode_result.data_bits         = 7'd64;
        decode_result.completion_opcode = FDI_OP_COMP_NO_DATA;
        decode_result.is_conf           = (op == FDI_OP_CFG_WR_64);
      end

      default: begin
        decode_result.valid = 1'b0;
      end
    endcase

    return decode_result;
  endfunction
endpackage