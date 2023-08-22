
create_ip -name ddr4 -vendor xilinx.com -library ip -module_name ddr4_sodimm_0

set_property -dict [list \
    CONFIG.C0.DDR4_AxiSelection {true} \
    CONFIG.C0.DDR4_AxiDataWidth {512} \
    CONFIG.C0.DDR4_AxiIDWidth {8} \
    CONFIG.C0.DDR4_AxiArbitrationScheme {RD_PRI_REG} \
    CONFIG.C0.DDR4_TimePeriod {1072} \
    CONFIG.C0.DDR4_InputClockPeriod {10004} \
    CONFIG.C0.DDR4_MemoryType {SODIMMs} \
    CONFIG.C0.DDR4_MemoryPart {MTA8ATF1G64HZ-2G3} \
    CONFIG.C0.DDR4_DataWidth {64} \
    CONFIG.C0.DDR4_AUTO_AP_COL_A3 {true} \
    CONFIG.C0.DDR4_CasLatency {13} \
    CONFIG.C0.DDR4_CasWriteLatency {10} \
    CONFIG.C0.DDR4_Mem_Add_Map {ROW_COLUMN_BANK_INTLV}
] [get_ips ddr4_sodimm_0]
