vlib work
vlog -f sources.list  +cover -covercells
vsim -voptargs=+acc work.UC_MB_Packer_tb -cover

add wave *
add wave -position 8  sim:/UC_MB_Packer_tb/DUT/r_state
add wave -position 9  sim:/UC_MB_Packer_tb/DUT/r_collect_cnt
add wave -position 10  sim:/UC_MB_Packer_tb/DUT/w_nxt_collect_cnt
add wave -position 13  sim:/UC_MB_Packer_tb/DUT/w_crc_valid
add wave -position 14  sim:/UC_MB_Packer_tb/DUT/r_crc_payload
coverage save UC_MB_Packer_tb.ucdb -onexit

run -all
