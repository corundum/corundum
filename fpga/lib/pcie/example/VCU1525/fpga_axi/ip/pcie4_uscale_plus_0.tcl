
create_ip -name pcie4_uscale_plus -vendor xilinx.com -library ip -module_name pcie4_uscale_plus_0

set_property -dict [list \
    CONFIG.PL_LINK_CAP_MAX_LINK_SPEED {8.0_GT/s} \
    CONFIG.PL_LINK_CAP_MAX_LINK_WIDTH {X16} \
    CONFIG.AXISTEN_IF_EXT_512_RQ_STRADDLE {false} \
    CONFIG.axisten_if_enable_client_tag {true} \
    CONFIG.axisten_if_width {512_bit} \
    CONFIG.axisten_freq {250} \
    CONFIG.PF0_CLASS_CODE {058000} \
    CONFIG.PF0_DEVICE_ID {0001} \
    CONFIG.PF0_MSI_CAP_MULTIMSGCAP {32_vectors} \
    CONFIG.PF0_SUBSYSTEM_ID {95f5} \
    CONFIG.PF0_SUBSYSTEM_VENDOR_ID {10ee} \
    CONFIG.pf0_bar0_64bit {true} \
    CONFIG.pf0_bar0_prefetchable {true} \
    CONFIG.pf0_bar0_scale {Megabytes} \
    CONFIG.pf0_bar0_size {16} \
    CONFIG.pf0_bar2_64bit {true} \
    CONFIG.pf0_bar2_prefetchable {true} \
    CONFIG.pf0_bar2_enabled {true} \
    CONFIG.pf0_bar2_type {Memory} \
    CONFIG.pf0_bar2_scale {Megabytes} \
    CONFIG.pf0_bar2_size {16} \
    CONFIG.vendor_id {1234} \
    CONFIG.en_msi_per_vec_masking {true} \
] [get_ips pcie4_uscale_plus_0]
