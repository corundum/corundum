
create_ip -name cmac_usplus -vendor xilinx.com -library ip -module_name cmac_usplus

set_property -dict [list \
    CONFIG.CMAC_CAUI4_MODE {1} \
    CONFIG.NUM_LANES {4x25} \
    CONFIG.USER_INTERFACE {AXIS} \
    CONFIG.GT_DRP_CLK {125} \
    CONFIG.GT_LOCATION {0} \
    CONFIG.TX_FLOW_CONTROL {0} \
    CONFIG.RX_FLOW_CONTROL {0} \
    CONFIG.INCLUDE_RS_FEC {1} \
    CONFIG.ENABLE_TIME_STAMPING {1}
] [get_ips cmac_usplus]

# disable LOC constraint
set_property generate_synth_checkpoint false [get_files [get_property IP_FILE [get_ips cmac_usplus]]]
generate_target synthesis [get_files [get_property IP_FILE [get_ips cmac_usplus]]]
set_property is_enabled false [get_files -of_objects [get_files [get_property IP_FILE [get_ips cmac_usplus]]] cmac_usplus.xdc]
