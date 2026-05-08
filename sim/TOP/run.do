vlib work
vlog -f sources.list
vsim -voptargs=+acc work.UC_TOP_tb
add wave /UC_TOP_tb/i_rst_n
add wave /UC_TOP_tb/i_init
add wave /UC_TOP_tb/i_clk
add wave -group "RP_inputs" /UC_TOP_tb/RP_i_*
add wave -group "RP_outputs" /UC_TOP_tb/RP_o_*

add wave -group "EP_inputs" /UC_TOP_tb/EP_i_*
add wave -group "EP_outputs" /UC_TOP_tb/EP_o_*
run -all