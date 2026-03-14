vlib work
vlog -f sources.list
vsim -voptargs=+acc work.UC_ALSM_tb

add wave *
add wave -position insertpoint /UC_ALSM_tb/U0_ALSM_UP/s_cs   \
                               /UC_ALSM_tb/U1_ALSM_DP/s_cs

run -all