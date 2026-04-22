// ================================================================================================================================
//  FILENAME    : UC_rx_sync_fifo.sv
//  MODULE      : UC_rx_sync_fifo
//  PROJECT     : UCIe 3.0 Adapter Layer
//  AUTHOR      : Ashraf Sherif, Shahd Mohamed
// ================================================================================================================================
//  Description : Sync Fifo with Overflow Signal
// ================================================================================================================================
module UC_rx_sync_fifo #(
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
    output logic fifo_empty,               // Flag indicating FIFO is empty
    output logic fifo_overflow             // Overflow flag
);

// ============================================= Parameter ==============================================
  parameter POINTER_WIDTH = $clog2(FIFO_DEPTH); // Width of the pointer based on FIFO depth

// =============================================== Internal Logic ==============================================

logic [DATA_WIDTH-1:0] r_mem [FIFO_DEPTH-1:0];  // Memory array to store FIFO data
logic [POINTER_WIDTH-1:0] r_wr_ptr, r_rd_ptr;    // Write and read pointers
logic [POINTER_WIDTH:0]   r_fifo_elements_counter; // Counter to track the number of elements in the FIFO

// =============================================== Writing Operation ==============================================

always_ff @(posedge clk or negedge rst_n) begin : writing_operation_proc
    if (!rst_n) begin
        // Reset the FIFO memory, write pointer and overflow flag
        for (int i = 0; i < FIFO_DEPTH; i = i + 1) begin
            r_mem[i] <= 'b0; 
        end
        r_wr_ptr <= 0;
        fifo_overflow <= 0;
    end
    else if (!init_n) begin
        for (int i = 0; i < FIFO_DEPTH; i = i + 1) begin
            r_mem[i] <= 'b0; 
        end
        r_wr_ptr <= 0;
        fifo_overflow <= 0;
    end
    else if (fifo_write_enable && r_fifo_elements_counter < FIFO_DEPTH) begin
        // Write data into the FIFO if not full
        r_mem[r_wr_ptr] <= fifo_data_in;
        r_wr_ptr <= r_wr_ptr + 1;
        fifo_overflow <= 0; 
    end
    else begin 
        // Set overflow flag if FIFO is full and a write is attempted
        if (fifo_full && fifo_write_enable)
            fifo_overflow <= 1;
        else
            fifo_overflow <= 0;
    end
end

// =============================================== Reading Operation ==============================================

always_ff @(posedge clk or negedge rst_n) begin : reading_operation_proc
    if (!rst_n) begin
        // Reset the read pointer and output data
        r_rd_ptr <= 0;
        fifo_data_out <= 0;
    end
    else if (!init_n) begin
        r_rd_ptr <= 0;
        fifo_data_out <= 0;
    end
    else if (fifo_read_enable && r_fifo_elements_counter != 0) begin
        // Read data from the FIFO if not empty
        fifo_data_out <= r_mem[r_rd_ptr];
        r_rd_ptr <= r_rd_ptr + 1;
    end
end

// =============================================== FIFO Elements Counter Handler ==============================================

always_ff @(posedge clk or negedge rst_n) begin : fifo_elements_counter_proc
    if (!rst_n) begin
        // Reset the counter
        r_fifo_elements_counter <= 0;
    end
    else if (!init_n) begin
        r_fifo_elements_counter <= 0;
    end
    else begin
        // Update the counter based on write and read operations
        if      (({fifo_write_enable, fifo_read_enable} == 2'b10) && !fifo_full) 
            r_fifo_elements_counter <= r_fifo_elements_counter + 1;  // Increment on write
        else if (({fifo_write_enable, fifo_read_enable} == 2'b01) && !fifo_empty)
            r_fifo_elements_counter <= r_fifo_elements_counter - 1;  // Decrement on read
        else if (({fifo_write_enable, fifo_read_enable} == 2'b11) && fifo_empty) 
            r_fifo_elements_counter <= r_fifo_elements_counter + 1;  // Increment on simultaneous write and read (empty case)
        else if (({fifo_write_enable, fifo_read_enable} == 2'b11) && fifo_full)
            r_fifo_elements_counter <= r_fifo_elements_counter - 1;  // Decrement on simultaneous write and read (full case)
    end
end

// =============================================== Full and Empty Flags ==============================================

assign fifo_full = (r_fifo_elements_counter == FIFO_DEPTH) ? 1 : 0;  // Set full flag if FIFO is full
assign fifo_empty = (r_fifo_elements_counter == 0) ? 1 : 0;             // Set empty flag if FIFO is empty

endmodule