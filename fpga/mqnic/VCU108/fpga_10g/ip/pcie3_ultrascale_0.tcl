
create_ip -name pcie3_ultrascale -vendor xilinx.com -library ip -module_name pcie3_ultrascale_0

set_property -dict [list \
    CONFIG.PL_LINK_CAP_MAX_LINK_SPEED {8.0_GT/s} \
    CONFIG.PL_LINK_CAP_MAX_LINK_WIDTH {X8} \
    CONFIG.AXISTEN_IF_RC_STRADDLE {false} \
    CONFIG.axisten_if_width {256_bit} \
    CONFIG.extended_tag_field {true} \
    CONFIG.axisten_freq {250} \
    CONFIG.PF0_CLASS_CODE {020000} \
    CONFIG.PF0_DEVICE_ID {1001} \
    CONFIG.PF0_MSI_CAP_MULTIMSGCAP {32_vectors} \
    CONFIG.PF0_SUBSYSTEM_ID {806c} \
    CONFIG.PF0_SUBSYSTEM_VENDOR_ID {10ee} \
    CONFIG.pf0_bar0_64bit {true} \
    CONFIG.pf0_bar0_prefetchable {true} \
    CONFIG.pf0_bar0_scale {Megabytes} \
    CONFIG.pf0_bar0_size {16} \
    CONFIG.PF0_INTERRUPT_PIN {NONE} \
    CONFIG.PF0_MSIX_CAP_TABLE_BIR {BAR_0} \
    CONFIG.PF0_MSIX_CAP_PBA_BIR {BAR_0} \
    CONFIG.vendor_id {1234} \
    CONFIG.en_msi_per_vec_masking {true} \
] [get_ips pcie3_ultrascale_0]
