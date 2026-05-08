vlib work
vlog UC_MB_CRC_Generator.sv UC_MB_Unpacker_tb.sv UC_MB_Unpacker.sv UC_MB_Mainband_pkg.sv  +cover -covercells
vsim -voptargs=+acc work.UC_MB_Unpacker_tb -cover
add wave *
add wave -position 4  sim:/UC_MB_Unpacker_tb/DUT/r_pipe_data
add wave -position 5  sim:/UC_MB_Unpacker_tb/DUT/r_pipe_valid
add wave -position 6  sim:/UC_MB_Unpacker_tb/DUT/w_crc_valid
add wave -position 7  sim:/UC_MB_Unpacker_tb/DUT/r_crc_payload
add wave -position 2  sim:/UC_MB_Unpacker_tb/DUT/r_state
coverage save UC_MB_Unpacker_tb.ucdb -onexit
run -all

