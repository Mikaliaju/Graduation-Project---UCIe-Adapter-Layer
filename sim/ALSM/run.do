vlib work
vlog -f sources.list
vsim -voptargs=+acc work.ALSM_tb

add wave *
add wave -position insertpoint /ALSM_tb/ALSM_inst/s_cs

run -all