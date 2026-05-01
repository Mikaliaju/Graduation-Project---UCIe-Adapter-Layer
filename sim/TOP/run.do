vlib work
vlog -f sources.list
vsim -voptargs=+acc work.UC_TOP_tb
add wave *
run -all