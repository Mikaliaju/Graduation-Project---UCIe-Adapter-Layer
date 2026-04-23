vlib work
vlog -f sources.list
vsim -voptargs=+acc work.UC_regfile_tb

add wave *

add wave -position insertpoint  \
sim:/UC_regfile_tb/UC_regfile_inst/mem_block \
sim:/UC_regfile_tb/UC_regfile_inst/dvsec

run -all