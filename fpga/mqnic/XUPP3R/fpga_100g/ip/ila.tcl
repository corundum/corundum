
create_ip -name ila -vendor xilinx.com -library ip -module_name ila_0

set_property -dict [list \
CONFIG.Component_Name {ila_0} \
CONFIG.C_DATA_DEPTH {1024} \
CONFIG.C_TRIGIN_EN {1} \
CONFIG.C_TRIGOUT_EN {1} \
CONFIG.EN_BRAM_DRC {false} \
CONFIG.C_NUM_OF_PROBES {6} \
CONFIG.C_PROBE0_WIDTH {512} \
CONFIG.C_PROBE1_WIDTH {16} \
CONFIG.C_PROBE2_WIDTH {16} \
CONFIG.C_PROBE3_WIDTH {16} \
CONFIG.C_PROBE4_WIDTH {256} \
CONFIG.C_PROBE5_WIDTH {16}] [get_ips ila_0]

