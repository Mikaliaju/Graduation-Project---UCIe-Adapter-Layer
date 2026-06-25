set_option enableSV yes
read_file -type verilog [exec cat sources.list]

set_option top UC_MB_retry_top

current_goal Design_Read -top UC_MB_retry_top

current_goal lint/lint_rtl -top UC_MB_retry_top
run_goal

quit
