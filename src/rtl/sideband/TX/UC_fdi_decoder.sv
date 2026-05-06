

module UC_fdi_decoder (
    input [4:0]                      i_opcode,                

    output logic                     o_write_operation,       
    output logic                     o_operation_32bit,       
    output logic                     o_request_type,          
    output logic                     o_confg_req,            
    output logic [4:0]               o_comp_opcode,         
    output logic                     o_opcode_error           
);

always_comb begin : fdi_opcode_decoder_proc
    o_write_operation  = 0;
    o_operation_32bit  = 0;
    o_request_type     = 1;
    o_comp_opcode      = 0;
    o_confg_req        = 0;
    o_opcode_error     = 1;
    case (i_opcode)
      5'b00000 : begin 
        o_operation_32bit  = 1;
        o_request_type     = 0;
        o_comp_opcode      = 5'b10001;
        o_opcode_error     = 0;
      end
      5'b00001 : begin 
        o_write_operation  = 1;  // 32b Memory Write 
        o_operation_32bit  = 1;
        o_comp_opcode      = 5'b10000;
        o_opcode_error     = 0;
        end
      
      5'b00100: begin
        o_operation_32bit  = 1;
        o_comp_opcode      = 5'b10001;
        o_confg_req        = 1;
        o_opcode_error     = 0;
        o_request_type     = 0;
      end
      5'b00101: begin 
        o_write_operation  = 1;  // 32b Configuration Write
        o_operation_32bit  = 1;
        o_comp_opcode      = 5'b10000;
        o_confg_req        = 1;
        o_opcode_error     = 0;
      end 
      5'b01000: begin
        o_request_type     = 0;
        o_comp_opcode      = 5'b11001;
        o_opcode_error     = 0;

      end
      5'b01001: begin 
        o_write_operation  = 1;  // 64b Memory Write
        o_comp_opcode      = 5'b10000;
        o_opcode_error     = 0;
      end  
      5'b01100: begin 
        o_comp_opcode      = 5'b11001;
        o_confg_req        = 1;
        o_opcode_error     = 0;
        o_request_type     = 0;
      end
      5'b01101: begin
        o_write_operation  = 1;   // 64b Configuration Write   
        o_comp_opcode      = 5'b10000;
        o_confg_req        = 1;
        o_opcode_error     = 0;
 
      end  
    endcase
  end
    
endmodule