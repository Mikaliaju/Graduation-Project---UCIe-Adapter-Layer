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

add wave -position insertpoint  \
sim:/UC_TOP_tb/UC_TOP_RP_inst/UC_MB_Mainband_inst/U1_UC_MB_Packer/r_crc_payload
add wave -position insertpoint  \
sim:/UC_TOP_tb/UC_TOP_RP_inst/UC_MB_Mainband_inst/U1_UC_MB_Packer/r_crc_payload_valid
add wave -position insertpoint  \
sim:/UC_TOP_tb/UC_TOP_RP_inst/UC_MB_Mainband_inst/U1_UC_MB_Packer/w_crc_valid
add wave -position insertpoint  \
sim:/UC_TOP_tb/UC_TOP_RP_inst/UC_MB_Mainband_inst/U1_UC_MB_Packer/w_crc0_gen \
sim:/UC_TOP_tb/UC_TOP_RP_inst/UC_MB_Mainband_inst/U1_UC_MB_Packer/w_crc1_gen
add wave -position insertpoint  \
sim:/UC_TOP_tb/UC_TOP_RP_inst/UC_MB_Mainband_inst/U1_UC_MB_Packer/U1_UC_MB_crc_gen/r_state
add wave -position insertpoint  \
sim:/UC_TOP_tb/UC_TOP_RP_inst/UC_MB_Mainband_inst/U1_UC_MB_Packer/U1_UC_MB_crc_gen/r_crc_reg0 \
sim:/UC_TOP_tb/UC_TOP_RP_inst/UC_MB_Mainband_inst/U1_UC_MB_Packer/U1_UC_MB_crc_gen/r_crc_reg1 \
sim:/UC_TOP_tb/UC_TOP_RP_inst/UC_MB_Mainband_inst/U1_UC_MB_Packer/U1_UC_MB_crc_gen/r_crc_next

add wave -position insertpoint  \
sim:/UC_TOP_tb/UC_TOP_EP_inst/UC_MB_Mainband_inst/U2_UC_MB_Unpacker/r_crc_payload
add wave -position insertpoint  \
sim:/UC_TOP_tb/UC_TOP_EP_inst/UC_MB_Mainband_inst/U2_UC_MB_Unpacker/r_crc_payload_valid
add wave -position insertpoint  \
sim:/UC_TOP_tb/UC_TOP_EP_inst/UC_MB_Mainband_inst/U1_UC_MB_Packer/w_crc_valid
add wave -position insertpoint  \
sim:/UC_TOP_tb/UC_TOP_EP_inst/UC_MB_Mainband_inst/U2_UC_MB_Unpacker/w_crc0_gen \
sim:/UC_TOP_tb/UC_TOP_EP_inst/UC_MB_Mainband_inst/U2_UC_MB_Unpacker/w_crc1_gen
add wave -position insertpoint  \
sim:/UC_TOP_tb/UC_TOP_EP_inst/UC_MB_Mainband_inst/U2_UC_MB_Unpacker/r_crc0_ch \
sim:/UC_TOP_tb/UC_TOP_EP_inst/UC_MB_Mainband_inst/U2_UC_MB_Unpacker/r_crc1_ch
add wave -position insertpoint  \
sim:/UC_TOP_tb/UC_TOP_EP_inst/UC_MB_Mainband_inst/U2_UC_MB_Unpacker/U1_UC_MB_crc_gen/r_state
add wave -position insertpoint  \
sim:/UC_TOP_tb/UC_TOP_EP_inst/UC_MB_Mainband_inst/U2_UC_MB_Unpacker/U1_UC_MB_crc_gen/r_crc_reg0 \
sim:/UC_TOP_tb/UC_TOP_EP_inst/UC_MB_Mainband_inst/U2_UC_MB_Unpacker/U1_UC_MB_crc_gen/r_crc_reg1 \
sim:/UC_TOP_tb/UC_TOP_EP_inst/UC_MB_Mainband_inst/U2_UC_MB_Unpacker/U1_UC_MB_crc_gen/r_crc_next

run -all