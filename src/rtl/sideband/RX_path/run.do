# ================================================================================================================================
#  FILENAME    : run_UC_rx_top.do
#  PROJECT     : UCIe 3.0 Adapter Layer - RX Top Testbench
#  AUTHOR      : Ashraf Sherif, Shahd Mohamed
# ================================================================================================================================

# ================================================================
# Clean up previous compilation
# ================================================================
puts "Cleaning up previous compilation..."
if {[file exists work]} {
    vdel -lib work -all
}

# ================================================================
# Create work library
# ================================================================
puts "Creating work library..."
vlib work
vmap work work

# ================================================================
# Compilation
# ================================================================
puts "Compiling design files..."


# Compile the Verilog files
vlog UC_sb_rx_pkg.sv
vlog UC_rx_sync_fifo.sv
vlog UC_rx_controller_decoder.sv
vlog UC_rx_completions_controller.sv
vlog UC_rx_msgs_ctrl.sv
vlog UC_sb_rx_top.sv
vlog UC_rx_top_tb.sv

# Elaborate the testbench top module 
vsim work.UC_rx_top_tb

# ================================================================
# Start simulation
# ================================================================
puts "Starting simulation..."
vsim -voptargs=+acc work.UC_rx_top_tb

# ================================================================
# Waveform Configuration
# ================================================================
puts "Configuring waveform display..."

# ================================================================
# TESTBENCH LEVEL
# ================================================================
add wave -noupdate -divider -height 30 "TESTBENCH CONTROLS"
add wave -noupdate -radix binary     /UC_rx_top_tb/i_clk
add wave -noupdate -radix binary     /UC_rx_top_tb/i_rst_n
add wave -noupdate -radix binary     /UC_rx_top_tb/i_init_n

# ================================================================
# RDI Interface
# ================================================================
add wave -noupdate -divider -height 30 "RDI INTERFACE"
add wave -noupdate -radix hexadecimal /UC_rx_top_tb/i_rdi_pl_cfg
add wave -noupdate -radix binary      /UC_rx_top_tb/i_rdi_pl_cfg_vld

# ================================================================
# FDI Interface
# ================================================================
add wave -noupdate -divider -height 30 "FDI INTERFACE"
add wave -noupdate -radix hexadecimal /UC_rx_top_tb/o_fdi_pl_cfg
add wave -noupdate -radix binary      /UC_rx_top_tb/o_fdi_pl_cfg_vld

# ================================================================
# LSM Interface
# ================================================================
add wave -noupdate -divider -height 30 "LSM INTERFACE"
add wave -noupdate -radix symbolic    /UC_rx_top_tb/o_sb_state_msg_rx
catch {add wave -noupdate -radix symbolic /UC_rx_top_tb/o_sb_err_msg_rx}

# ================================================================
# Error Flags
# ================================================================
add wave -noupdate -divider -height 30 "ERROR FLAGS"
add wave -noupdate -radix binary      /UC_rx_top_tb/o_sb_rdi_overflow
add wave -noupdate -radix binary      /UC_rx_top_tb/o_sb_rx_parity_error
add wave -noupdate -radix binary      /UC_rx_top_tb/o_sb_rx_opid_err

# ================================================================
# Credit Loop
# ================================================================
add wave -noupdate -divider -height 30 "CREDIT LOOP"
add wave -noupdate -radix binary      /UC_rx_top_tb/o_rdi_crd_release

# ================================================================
# Tag Manager Interface
# ================================================================
add wave -noupdate -divider -height 30 "TAG MANAGER"
add wave -noupdate -radix binary      /UC_rx_top_tb/o_rx_chk_tag
add wave -noupdate -radix hexadecimal /UC_rx_top_tb/o_rx_current_tag
add wave -noupdate -radix hexadecimal /UC_rx_top_tb/i_rx_orig_tag
add wave -noupdate -radix binary      /UC_rx_top_tb/i_rx_tag_notfound

# ================================================================
# TX Controller Interface
# ================================================================
add wave -noupdate -divider -height 30 "TX REGISTER CONTROLLER"
add wave -noupdate -radix hexadecimal /UC_rx_top_tb/i_tx_comp_pkt
add wave -noupdate -radix binary      /UC_rx_top_tb/i_tx_comp_pkt_vld
add wave -noupdate -radix binary      /UC_rx_top_tb/o_tx_comp_pkt_done

# ================================================================
# Remote / Mailbox Interface
# ================================================================
add wave -noupdate -divider -height 30 "REMOTE / MAILBOX"
catch {add wave -noupdate -radix hexadecimal /UC_rx_top_tb/o_remote_req_pkt}
catch {add wave -noupdate -radix binary      /UC_rx_top_tb/o_remote_req_vld}
catch {add wave -noupdate -radix binary      /UC_rx_top_tb/o_e2e_crds_return_vld}
add wave -noupdate -radix hexadecimal /UC_rx_top_tb/o_rx_remote_comp_pkt
add wave -noupdate -radix binary      /UC_rx_top_tb/o_rx_remote_comp_vld
add wave -noupdate -radix binary      /UC_rx_top_tb/o_rx_remote_comp_length

# ================================================================
# Parameter Exchange
# ================================================================
add wave -noupdate -divider -height 30 "PARAMETER EXCHANGE"
add wave -noupdate -radix hexadecimal /UC_rx_top_tb/o_rx_msg
add wave -noupdate -radix binary      /UC_rx_top_tb/o_rx_msg_vld

# ================================================================
# DUT Top-Level Internal Signals
# ================================================================
add wave -noupdate -divider -height 30 "DUT INTERNAL - FIFO STATUS"
add wave -noupdate -radix binary      /UC_rx_top_tb/dut/s_comp_fifo_full_flag
add wave -noupdate -radix binary      /UC_rx_top_tb/dut/s_comp_fifo_empty_flag
add wave -noupdate -radix binary      /UC_rx_top_tb/dut/s_comp_fifo_overflow_flag
add wave -noupdate -radix binary      /UC_rx_top_tb/dut/s_comp_fifo_write_enable
add wave -noupdate -radix binary      /UC_rx_top_tb/dut/s_comp_fifo_read_enable
add wave -noupdate -radix hexadecimal /UC_rx_top_tb/dut/s_comp_fifo_write_data
add wave -noupdate -radix hexadecimal /UC_rx_top_tb/dut/s_comp_fifo_read_data

add wave -noupdate -radix binary      /UC_rx_top_tb/dut/s_msg_fifo_full_flag
add wave -noupdate -radix binary      /UC_rx_top_tb/dut/s_msg_fifo_empty_flag
add wave -noupdate -radix binary      /UC_rx_top_tb/dut/s_msg_fifo_overflow_flag
add wave -noupdate -radix binary      /UC_rx_top_tb/dut/s_msg_fifo_write_enable
add wave -noupdate -radix binary      /UC_rx_top_tb/dut/s_msg_fifo_read_enable
add wave -noupdate -radix hexadecimal /UC_rx_top_tb/dut/s_msg_fifo_write_data
add wave -noupdate -radix hexadecimal /UC_rx_top_tb/dut/s_msg_fifo_read_data

add wave -noupdate -divider -height 30 "DUT INTERNAL - ERROR SIGNALS"
add wave -noupdate -radix binary      /UC_rx_top_tb/dut/s_comp_ctrl_parity_error
add wave -noupdate -radix binary      /UC_rx_top_tb/dut/s_msg_ctrl_parity_error
add wave -noupdate -radix binary      /UC_rx_top_tb/dut/s_msg_ctrl_invalid_id_error
add wave -noupdate -radix binary      /UC_rx_top_tb/dut/s_decoder_reserved_opcode_err
catch {add wave -noupdate -radix binary /UC_rx_top_tb/dut/s_decoder_request_parity_err}

# ================================================================
# COMPLETIONS FIFO - All Internal Signals
# ================================================================
add wave -noupdate -divider -height 30 "COMPLETIONS FIFO (u_comp_fifo)"
add wave -noupdate -radix hexadecimal /UC_rx_top_tb/dut/u_comp_fifo/*

# ================================================================
# MESSAGES FIFO - All Internal Signals
# ================================================================
add wave -noupdate -divider -height 30 "MESSAGES FIFO (u_msg_fifo)"
add wave -noupdate -radix hexadecimal /UC_rx_top_tb/dut/u_msg_fifo/*

# ================================================================
# RX DECODER - All Internal Signals
# ================================================================
add wave -noupdate -divider -height 30 "RX DECODER (u_decoder)"
add wave -noupdate -radix symbolic    /UC_rx_top_tb/dut/u_decoder/rxd_state
add wave -noupdate -radix symbolic    /UC_rx_top_tb/dut/u_decoder/rxd_nextstate
add wave -noupdate -radix hexadecimal /UC_rx_top_tb/dut/u_decoder/r_chunk_counter
catch {add wave -noupdate -radix hexadecimal /UC_rx_top_tb/dut/u_decoder/r_req_pkt}

# ================================================================
# COMPLETIONS CONTROLLER - All Internal Signals
# ================================================================
add wave -noupdate -divider -height 30 "COMPLETIONS CONTROLLER (u_comp_ctrl)"
add wave -noupdate -radix symbolic    /UC_rx_top_tb/dut/u_comp_ctrl/completions_ctrl_state
add wave -noupdate -radix symbolic    /UC_rx_top_tb/dut/u_comp_ctrl/completions_ctrl_nextstate
add wave -noupdate -radix hexadecimal /UC_rx_top_tb/dut/u_comp_ctrl/r_comp_pkt
add wave -noupdate -radix hexadecimal /UC_rx_top_tb/dut/u_comp_ctrl/r_rx_chunk_idx
add wave -noupdate -radix hexadecimal /UC_rx_top_tb/dut/u_comp_ctrl/r_fdi_chunk_idx
add wave -noupdate -radix hexadecimal /UC_rx_top_tb/dut/u_comp_ctrl/r_tx_chunk_idx

# ================================================================
# MESSAGES CONTROLLER - All Internal Signals
# ================================================================
add wave -noupdate -divider -height 30 "MESSAGES CONTROLLER (u_msgs_ctrl)"
add wave -noupdate -radix symbolic    /UC_rx_top_tb/dut/u_msgs_ctrl/r_state
add wave -noupdate -radix symbolic    /UC_rx_top_tb/dut/u_msgs_ctrl/w_next_state
add wave -noupdate -radix hexadecimal /UC_rx_top_tb/dut/u_msgs_ctrl/r_packet_buf
add wave -noupdate -radix hexadecimal /UC_rx_top_tb/dut/u_msgs_ctrl/r_phase_count

# ================================================================
# Configure waveform appearance
# ================================================================
configure wave -namecolwidth 300
configure wave -valuecolwidth 120
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns

# ================================================================
# Run Simulation
# ================================================================
puts "Running simulation..."
run 15us

puts "Simulation complete. Use 'run -continue' to continue or 'wave zoom full' to view entire waveform."

# Auto-zoom to full waveform
wave zoom full