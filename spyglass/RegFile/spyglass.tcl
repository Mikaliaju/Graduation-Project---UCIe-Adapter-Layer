read_file -type verilog UC_regfile.sv
set_option top UC_regfile
set_option enableSV yes
set_option mthresh 40000
current_goal Design_Read -top UC_regfile

current_goal lint/lint_rtl -top UC_regfile
run_goal

quit
