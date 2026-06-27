set_option incdir "../../src/rtl/common"
set_option enableSV yes
read_file -type verilog [exec cat sources.list]
set_option top UC_TOP

set_option mthresh 40000
current_goal Design_Read -top UC_TOP_EP

current_goal lint/lint_rtl -top UC_TOP_EP
run_goal

quit
