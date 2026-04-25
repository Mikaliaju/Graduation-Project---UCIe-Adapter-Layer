vlib work
vlog -f sources.list
<<<<<<< Updated upstream
vsim -voptargs=+acc work.UC_ALSM_tb

add wave *
add wave -position insertpoint /UC_ALSM_tb/U0_ALSM_UP/s_cs   \
                               /UC_ALSM_tb/U1_ALSM_DP/s_cs
=======
vsim -voptargs=+acc work.ALSM_tb

add wave *
add wave -position insertpoint /ALSM_tb/ALSM_inst/s_cs
>>>>>>> Stashed changes

run -all