// ================================================================================================================================
//  FILENAME    : UC_remote_decoder.sv
//  MODULE      : UC_remote_decoder
//  PROJECT     : UCIe 3.0 Adapter Layer
//  AUTHOR      : Ashraf Sherif, Shahd Mohamed
// ================================================================================================================================
//  Description : Decoder decode address and opcode.
// ================================================================================================================================

module UC_remote_decoder #(
  parameter NC = 32,                  // Parameter for NC width
  parameter REGISTER_LOCATOR = 4'h0,  // Register locator (0h)
  parameter OFFSET_0 = 19'h66         // Parameterized offset for register 0
)(
  input  logic [23:0]                i_decoder_addr,          // Address for decoding
  input  logic [4:0]                 i_decoder_opcode,        // Opcode for operation
  
  output logic                       o_is_adapter,            // Signal indicating if the request is read
  output logic [4:0]                 o_comp_opcode,           // Completion opcode
  output logic                       o_write_operation,       // Signal indicating that the request is a write operation
  output logic                       o_operation_32bit,       // Signal indicating a 32-bit read/write operation
  output logic                       o_confg_req,             // Signal indicating that the request is for configuration
  output logic                       o_comp_type              // The completion type  1 > 128 , 0 > 64 bit
);

  // Internal signals
  logic [19:0] s_byte_offset;  // Byte offset in the address

  // Assign byte_offset from the address
  assign s_byte_offset = i_decoder_addr[19:0];

  always_comb begin : remote_address_decoser_proc
    // Default values
    o_is_adapter      = 0;
    o_comp_opcode     = 0;
    o_write_operation = 0;
    o_operation_32bit = 0;
    o_confg_req       = 0;
    o_comp_type       = 0;

    // Opcode decoding based on i_decoder_opcode
    case (i_decoder_opcode)
      
      // 32b Memory Read
      5'b00000 : begin 
         o_comp_opcode      = 5'b10001;
         
         // Using REGISTER_LOCATOR for address check
         if (s_byte_offset <= OFFSET_0) begin
            o_is_adapter = 1;
         end else begin
            o_is_adapter = 0;
         end
         
         o_write_operation = 0;
         o_operation_32bit = 1;
         o_confg_req       = 0;
         o_comp_type       = 1;
      end

      // 32b Memory Write
      5'b00001 : begin 
         o_comp_opcode      = 5'b10000;
         
         // Using REGISTER_LOCATOR for address check
         if (s_byte_offset <= OFFSET_0) begin
            o_is_adapter = 1;
         end else begin
            o_is_adapter = 0;
         end
         
         o_write_operation = 1;
         o_operation_32bit = 1;
         o_confg_req       = 0;
         o_comp_type       = 0;
      end
      
      // 32b Configuration Read
      5'b00100: begin
         o_comp_opcode      = 5'b10001;
         o_is_adapter      = 1;
         o_write_operation = 0;
         o_operation_32bit = 1;
         o_confg_req       = 1;
         o_comp_type       = 1;
      end

      // 32b Configuration Write
      5'b00101: begin 
         o_comp_opcode      = 5'b10000;
         o_is_adapter      = 1;
         o_write_operation = 1;
         o_operation_32bit = 1;
         o_confg_req       = 1;
         o_comp_type       = 0;
      end 
      
      // 64b Memory Read
      5'b01000: begin
        o_comp_opcode    = 5'b11001;
        
        // Using REGISTER_LOCATOR for address check
        if (s_byte_offset <= OFFSET_0) begin
          o_is_adapter = 1;
        end else begin
          o_is_adapter = 0;
        end  
        
        o_write_operation = 0;
        o_operation_32bit = 0;
        o_confg_req       = 0;
        o_comp_type       = 1;
      end

      // 64b Memory Write
      5'b01001: begin 
         o_comp_opcode      = 5'b10000;
         
         // Using REGISTER_LOCATOR for address check
         if (s_byte_offset <= OFFSET_0) begin
            o_is_adapter = 1;
         end else begin
            o_is_adapter = 0;
         end
         
         o_write_operation = 1;
         o_operation_32bit = 0;
         o_confg_req       = 0;
         o_comp_type       = 0;
      end  
      
      // 64b Configuration Read
      5'b01100: begin 
         o_comp_opcode    = 5'b11001;
         o_is_adapter      = 1;
         o_write_operation = 0;
         o_operation_32bit = 0;
         o_confg_req       = 1;
         o_comp_type       = 1;
      end

      // 64b Configuration Write   
      5'b01101: begin
         o_comp_opcode      = 5'b10000;
         o_is_adapter      = 1;
         o_write_operation = 1;
         o_operation_32bit = 0;
         o_confg_req       = 1;
         o_comp_type       = 0; 
      end  

    endcase
  end
    
endmodule