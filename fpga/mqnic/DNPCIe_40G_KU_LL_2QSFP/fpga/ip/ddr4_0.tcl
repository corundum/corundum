
create_ip -name ddr4 -vendor xilinx.com -library ip -module_name ddr4_0

set_property -dict [list \
    CONFIG.C0.DDR4_AxiSelection {true} \
    CONFIG.C0.DDR4_AxiDataWidth {512} \
    CONFIG.C0.DDR4_AxiIDWidth {8} \
    CONFIG.C0.DDR4_AxiArbitrationScheme {RD_PRI_REG} \
    CONFIG.C0.DDR4_TimePeriod {833} \
    CONFIG.C0.DDR4_InputClockPeriod {4998} \
    CONFIG.C0.DDR4_MemoryType {Components} \
    CONFIG.C0.DDR4_MemoryPart {MT40A512M8HX-083} \
    CONFIG.C0.DDR4_DataWidth {72} \
    CONFIG.C0.DDR4_DataMask {NO_DM_NO_DBI} \
    CONFIG.C0.DDR4_AUTO_AP_COL_A3 {true} \
    CONFIG.C0.DDR4_CasLatency {16} \
    CONFIG.C0.DDR4_CasWriteLatency {12} \
    CONFIG.C0.DDR4_Mem_Add_Map {ROW_COLUMN_BANK_INTLV}
] [get_ips ddr4_0]
