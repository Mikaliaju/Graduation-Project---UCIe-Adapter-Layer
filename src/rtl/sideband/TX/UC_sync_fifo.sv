// ================================================================================================================================
//  FILENAME    : UC_sync_fifo.sv
//  MODULE      : UC_sync_fifo
//  PROJECT     : UCIe 3.0 Adapter Layer
//  AUTHOR      : Ashraf Sherif, Shahd Mohamed
// ================================================================================================================================
//  Description : Sync Fifo
// ================================================================================================================================

module UC_sync_fifo #(
    parameter FIFO_DEPTH = 32,             // Depth of the FIFO (number of entries)
    parameter DATA_WIDTH = 32              // Width of each data entry in the FIFO
)(
    // A. Clocks & Reset:
    input clk,                             // Clock signal
    input rst_n,                           // Active-low hardware reset
    input init_n,                          // Active-low software reset
    // B. Inputs:
    input fifo_read_enable,                // FIFO read enable
    input [DATA_WIDTH-1 : 0] fifo_data_in, // Data input to the FIFO
    input fifo_write_enable,               // FIFO write enable
    // C. Outputs:
    output logic [DATA_WIDTH-1:0] fifo_data_out, // Data output from the FIFO
    output logic fifo_full,                // Flag indicating FIFO is full
    output logic fifo_empty                // Flag indicating FIFO is empty
);

// ============================================= Parameter ==============================================
  parameter POINTER_WIDTH = $clog2(FIFO_DEPTH); // Width of the pointer based on FIFO depth
// ============================================= Internal Signals ==============================================
  logic [POINTER_WIDTH:0] write_ptr, read_ptr;   // Write and read pointers
  logic [DATA_WIDTH-1:0] fifo_mem[FIFO_DEPTH];    // FIFO memory
  logic MSB_NOT_EQUAL;                        // Signal to check MSB for pointers
// ============================================== Output Logic=========================================
  // Write data into FIFO
  always_ff @(posedge clk, negedge rst_n) begin : write_fifo_logic
    if(~rst_n) begin 
      write_ptr <= 0;
      foreach (fifo_mem[i]) begin
        fifo_mem[i] <= 0;
      end
    end else if (~init_n) begin
      write_ptr <= 0;
      foreach (fifo_mem[i]) begin
        fifo_mem[i] <= 0;
      end
    end else if(fifo_write_enable & !fifo_full) begin
      fifo_mem[write_ptr[POINTER_WIDTH-1:0]] <= fifo_data_in; // Write data to FIFO
      write_ptr <= write_ptr + 1; // Increment write pointer
    end
  end
  // Read data from FIFO
  always_ff @(posedge clk or negedge rst_n) begin : read_fifo_logic
    if(~rst_n) begin 
      read_ptr <= 0;
    end else if (~init_n) begin
      read_ptr <= 0;
    end else if (fifo_read_enable & !fifo_empty) begin
      read_ptr <= read_ptr + 1; // Increment read pointer
    end
  end
  // MSB check for write and read pointers
  assign MSB_NOT_EQUAL = write_ptr[POINTER_WIDTH] ^ read_ptr[POINTER_WIDTH];  
  // FIFO Full condition: MSB of write and read pointers are different and remaining bits are same
  assign fifo_full = MSB_NOT_EQUAL & (write_ptr[POINTER_WIDTH-1:0] == read_ptr[POINTER_WIDTH-1:0]);
  // FIFO Empty condition: Write and read pointers are the same
  assign fifo_empty = (write_ptr == read_ptr);
  // FIFO data output
  assign fifo_data_out = fifo_mem[read_ptr[POINTER_WIDTH-1:0]]; // Read data from FIFO based on read pointer
endmodule