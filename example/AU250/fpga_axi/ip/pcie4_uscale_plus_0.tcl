
create_ip -name pcie4_uscale_plus -vendor xilinx.com -library ip -module_name pcie4_uscale_plus_0

set_property -dict [list \
    CONFIG.PL_LINK_CAP_MAX_LINK_SPEED {8.0_GT/s} \
    CONFIG.PL_LINK_CAP_MAX_LINK_WIDTH {X16} \
    CONFIG.AXISTEN_IF_EXT_512_RQ_STRADDLE {false} \
    CONFIG.axisten_if_enable_client_tag {true} \
    CONFIG.axisten_if_width {512_bit} \
    CONFIG.axisten_freq {250} \
    CONFIG.PF0_CLASS_CODE {020000} \
    CONFIG.PF0_DEVICE_ID {0001} \
    CONFIG.PF0_MSI_CAP_MULTIMSGCAP {32_vectors} \
    CONFIG.PF0_SUBSYSTEM_ID {0001} \
    CONFIG.PF0_SUBSYSTEM_VENDOR_ID {1234} \
    CONFIG.PF0_Use_Class_Code_Lookup_Assistant {true} \
    CONFIG.pf0_class_code_sub {00} \
    CONFIG.pf0_base_class_menu {Network_controller} \
    CONFIG.pf0_sub_class_interface_menu {Ethernet_controller} \
    CONFIG.pf0_bar0_scale {Megabytes} \
    CONFIG.pf0_bar0_size {16} \
    CONFIG.pf0_bar1_enabled {true} \
    CONFIG.pf0_bar1_type {Memory} \
    CONFIG.pf0_bar1_scale {Megabytes} \
    CONFIG.pf0_bar1_size {16} \
    CONFIG.vendor_id {1234} \
    CONFIG.en_msi_per_vec_masking {true} \
] [get_ips pcie4_uscale_plus_0]
