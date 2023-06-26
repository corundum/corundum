# SPDX-License-Identifier: BSD-2-Clause-Views
# Copyright (c) 2022-2023 The Regents of the University of California

# create block design
create_bd_design "zynq_ps"

# Create blocks

# Zynq PS
set zynq_ultra_ps [ create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e zynq_ultra_ps ]
set_property -dict [list \
    CONFIG.PSU__PRESET_APPLIED {1} \
    CONFIG.PSU_BANK_0_IO_STANDARD {LVCMOS18} \
    CONFIG.PSU_BANK_1_IO_STANDARD {LVCMOS18} \
    CONFIG.PSU_BANK_2_IO_STANDARD {LVCMOS18} \
    CONFIG.PSU_BANK_3_IO_STANDARD {LVCMOS18} \
    CONFIG.PSU__GPIO0_MIO__IO {MIO 0 .. 25} \
    CONFIG.PSU__GPIO0_MIO__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__GPIO1_MIO__IO {MIO 26 .. 51} \
    CONFIG.PSU__GPIO1_MIO__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__QSPI__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__QSPI__PERIPHERAL__DATA_MODE {x4} \
    CONFIG.PSU__QSPI__PERIPHERAL__IO {MIO 0 .. 5} \
    CONFIG.PSU__QSPI__PERIPHERAL__MODE {Single} \
    CONFIG.PSU__QSPI__GRP_FBCLK__ENABLE {0} \
    CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__FREQMHZ {125} \
    CONFIG.PSU__SPI1__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__SPI1__GRP_SS1__ENABLE {0} \
    CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__FREQMHZ {200} \
    CONFIG.PSU__DISPLAYPORT__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__DPAUX__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__DPAUX__PERIPHERAL__IO {MIO 27 .. 30} \
    CONFIG.PSU__DP__LANE_SEL {None} \
    CONFIG.PSU__DP__REF_CLK_SEL {Ref Clk1} \
    CONFIG.PSU__DP__REF_CLK_FREQ {27} \
    CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__SRCSEL {VPLL} \
    CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__FREQMHZ {300} \
    CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__FREQMHZ {25} \
    CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__FREQMHZ {27} \
    CONFIG.PSU__USE__IRQ0 {1} \
    CONFIG.PSU__USE__M_AXI_GP0 {1} \
    CONFIG.PSU__USE__M_AXI_GP1 {1} \
    CONFIG.PSU__USE__M_AXI_GP2 {0} \
    CONFIG.PSU__PMU__GPO0__ENABLE {0} \
    CONFIG.PSU__PMU__GPO1__ENABLE {0} \
    CONFIG.PSU__PMU__GPO2__ENABLE {0} \
    CONFIG.PSU__PMU__GPO3__ENABLE {1} \
    CONFIG.PSU__PMU__GPO4__ENABLE {0} \
    CONFIG.PSU__PMU__GPO5__ENABLE {0} \
    CONFIG.PSU__PMU__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__PMU__GPI0__ENABLE {1} \
    CONFIG.PSU__PMU__GPI1__ENABLE {0} \
    CONFIG.PSU__PMU__GPI2__ENABLE {0} \
    CONFIG.PSU__PMU__GPI3__ENABLE {0} \
    CONFIG.PSU__PMU__GPI4__ENABLE {0} \
    CONFIG.PSU__PMU__GPI5__ENABLE {1} \
    CONFIG.PSU_MIO_34_DIRECTION {inout} \
    CONFIG.PSU_MIO_43_DIRECTION {inout} \
    CONFIG.PSU_MIO_44_DIRECTION {inout} \
    CONFIG.PSU__DDRC__VREF {1} \
    CONFIG.PSU__DDRC__ECC {Disabled} \
    CONFIG.PSU__DDRC__BUS_WIDTH {64 Bit} \
    CONFIG.PSU__DDRC__DRAM_WIDTH {16 Bits} \
    CONFIG.PSU__DDRC__MEMORY_TYPE {DDR 4} \
    CONFIG.PSU__DDRC__COMPONENTS {Components} \
    CONFIG.PSU__DDRC__SPEED_BIN {DDR4_2400R} \
    CONFIG.PSU__DDRC__DEVICE_CAPACITY {8192 MBits} \
    CONFIG.PSU__DDRC__RANK_ADDR_COUNT {0} \
    CONFIG.PSU__DDRC__BG_ADDR_COUNT {1} \
    CONFIG.PSU__DDRC__BANK_ADDR_COUNT {2} \
    CONFIG.PSU__DDRC__ROW_ADDR_COUNT {16} \
    CONFIG.PSU__DDRC__COL_ADDR_COUNT {10} \
    CONFIG.PSU__DDRC__CL {16} \
    CONFIG.PSU__DDRC__CWL {14} \
    CONFIG.PSU__DDRC__T_RCD {16} \
    CONFIG.PSU__DDRC__T_RP {16} \
    CONFIG.PSU__DDRC__T_RC {47.06} \
    CONFIG.PSU__DDRC__T_RAS_MIN {33} \
    CONFIG.PSU__DDRC__T_FAW {30.0} \
    CONFIG.PSU__DDRC__DDR4_T_REF_MODE {0} \
    CONFIG.PSU__DDRC__DDR4_T_REF_RANGE {Normal (0-85)} \
    CONFIG.PSU__DDRC__PHY_DBI_MODE {0} \
    CONFIG.PSU__DDRC__PARITY_ENABLE {0} \
    CONFIG.PSU__DDRC__CLOCK_STOP_EN {0} \
    CONFIG.PSU__DDRC__DDR4_CAL_MODE_ENABLE {0} \
    CONFIG.PSU__DDRC__DDR4_CRC_CONTROL {0} \
    CONFIG.PSU__DDRC__TRAIN_DATA_EYE {1} \
    CONFIG.PSU__DDRC__TRAIN_READ_GATE {1} \
    CONFIG.PSU__DDRC__TRAIN_WRITE_LEVEL {1} \
    CONFIG.PSU__DDRC__DDR4_ADDR_MAPPING {0} \
    CONFIG.PSU__DDRC__BRC_MAPPING {ROW_BANK_COL} \
    CONFIG.PSU__DDRC__DM_DBI {DM_NO_DBI} \
    CONFIG.PSU__DDRC__PER_BANK_REFRESH {0} \
    CONFIG.PSU__DDRC__FGRM {1X} \
    CONFIG.PSU__DDRC__LP_ASR {manual normal} \
    CONFIG.PSU__DDRC__DIMM_ADDR_MIRROR {0} \
    CONFIG.PSU__DDRC__STATIC_RD_MODE {0} \
    CONFIG.PSU__DDRC__SELF_REF_ABORT {0} \
    CONFIG.PSU__PSS_REF_CLK__FREQMHZ {33.333} \
    CONFIG.PSU__OVERRIDE__BASIC_CLOCK {0} \
    CONFIG.PSU__CRF_APB__APLL_CTRL__SRCSEL {PSS_REF_CLK} \
    CONFIG.PSU__CRF_APB__DPLL_CTRL__SRCSEL {PSS_REF_CLK} \
    CONFIG.PSU__CRF_APB__VPLL_CTRL__SRCSEL {PSS_REF_CLK} \
    CONFIG.PSU__CRL_APB__IOPLL_CTRL__SRCSEL {PSS_REF_CLK} \
    CONFIG.PSU__CRL_APB__RPLL_CTRL__SRCSEL {PSS_REF_CLK} \
    CONFIG.PSU__CRF_APB__DDR_CTRL__SRCSEL {DPLL} \
    CONFIG.PSU__CRF_APB__DDR_CTRL__FREQMHZ {1200} \
    CONFIG.PSU__CRL_APB__CPU_R5_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRL_APB__CPU_R5_CTRL__FREQMHZ {533.333} \
    CONFIG.PSU__CRF_APB__ACPU_CTRL__SRCSEL {APLL} \
    CONFIG.PSU__CRF_APB__ACPU__FRAC_ENABLED {1} \
    CONFIG.PSU__CRF_APB__ACPU_CTRL__FREQMHZ {1333.333} \
    CONFIG.PSU__CRF_APB__GPU_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__GPU_REF_CTRL__FREQMHZ {600} \
    CONFIG.PSU__SWDT0__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__SWDT1__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__TTC0__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC0_SEL {APB} \
    CONFIG.PSU__TTC1__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC1_SEL {APB} \
    CONFIG.PSU__TTC2__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC2_SEL {APB} \
    CONFIG.PSU__TTC3__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC3_SEL {APB} \
    CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRF_APB__DBG_TRACE_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__DBG_TRACE_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRF_APB__DBG_TSTMP_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__DBG_TSTMP_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__FREQMHZ {500} \
    CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__PCAP_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__PCAP_CTRL__FREQMHZ {200} \
    CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__FREQMHZ {500} \
    CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__SRCSEL {APLL} \
    CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__FREQMHZ {600} \
    CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__SRCSEL {DPLL} \
    CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__FREQMHZ {600} \
    CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__SRCSEL {DPLL} \
    CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__FREQMHZ {533.33} \
    CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__FREQMHZ {100} \
    CONFIG.PSU__I2C1__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__I2C1__PERIPHERAL__IO {MIO 24 .. 25} \
    CONFIG.PSU__CRL_APB__I2C1_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__I2C1_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__UART1__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__UART1__PERIPHERAL__IO {MIO 36 .. 37} \
    CONFIG.PSU__CRL_APB__UART1_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__UART1_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__ENET1__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__ENET1__PERIPHERAL__IO {MIO 38 .. 49} \
    CONFIG.PSU__ENET1__GRP_MDIO__ENABLE {1} \
    CONFIG.PSU__ENET1__GRP_MDIO__IO {MIO 50 .. 51} \
    CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__FREQMHZ {125} \
    CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__FREQMHZ {250} \
    CONFIG.PSU_MIO_45_PULLUPDOWN {disable} \
    CONFIG.PSU_MIO_47_PULLUPDOWN {disable} \
    CONFIG.PSU_MIO_49_PULLUPDOWN {disable} \
    CONFIG.PSU__ENET0__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__ENET0__PERIPHERAL__IO {GT Lane0} \
    CONFIG.PSU__GEM0__REF_CLK_SEL {Ref Clk0} \
    CONFIG.PSU__GEM0__REF_CLK_FREQ {125} \
    CONFIG.PSU__CRL_APB__GEM0_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__GEM0_REF_CTRL__FREQMHZ {125} \
    CONFIG.PSU__DISPLAYPORT__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__DPAUX__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__DPAUX__PERIPHERAL__IO {MIO 27 .. 30} \
    CONFIG.PSU__DP__LANE_SEL {Single Lower} \
    CONFIG.PSU__DISPLAYPORT__LANE0__ENABLE {1} \
    CONFIG.PSU__DISPLAYPORT__LANE0__IO {GT Lane1} \
    CONFIG.PSU__DP__REF_CLK_SEL {Ref Clk1} \
    CONFIG.PSU__DP__REF_CLK_FREQ {27} \
    CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__SRCSEL {VPLL} \
    CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__FREQMHZ {300} \
    CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__FREQMHZ {25} \
    CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__FREQMHZ {27} \
    CONFIG.PSU__USB0__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__USB0__PERIPHERAL__IO {MIO 52 .. 63} \
    CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__FREQMHZ {250} \
    CONFIG.PSU__USB3_0__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__USB3_0__PERIPHERAL__IO {GT Lane2} \
    CONFIG.PSU__USB0__REF_CLK_SEL {Ref Clk2} \
    CONFIG.PSU__USB0__REF_CLK_FREQ {26} \
    CONFIG.PSU__USB1__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__USB1__PERIPHERAL__IO {MIO 64 .. 75} \
    CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__FREQMHZ {250} \
    CONFIG.PSU__USB1__RESET__ENABLE {1} \
    CONFIG.PSU__USB1__RESET__IO {MIO 77} \
    CONFIG.PSU__USB3_1__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__USB3_1__PERIPHERAL__IO {GT Lane3} \
    CONFIG.PSU__USB1__REF_CLK_SEL {Ref Clk2} \
    CONFIG.PSU__USB1__REF_CLK_FREQ {26} \
    CONFIG.PSU__USB__RESET__MODE {Separate MIO Pin} \
    CONFIG.PSU__USB0__RESET__ENABLE {1} \
    CONFIG.PSU__USB0__RESET__IO {MIO 76} \
    CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__FREQMHZ {20} \
    CONFIG.PSU__USE__M_AXI_GP0 {1} \
    CONFIG.PSU__MAXIGP0__DATA_WIDTH {32} \
    CONFIG.PSU__USE__M_AXI_GP1 {0} \
    CONFIG.PSU__USE__M_AXI_GP2 {0} \
    CONFIG.PSU__USE__S_AXI_GP0 {1} \
    CONFIG.PSU__USE__IRQ0 {1} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__SRCSEL {IOPLL}
] $zynq_ultra_ps

# control AXI interconnect
set axi_interconnect_ctrl [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect axi_interconnect_ctrl ]

# reset
set proc_sys_reset [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset proc_sys_reset ]

# Create connections

# Clock
set pl_clk0 [get_bd_pins $zynq_ultra_ps/pl_clk0]
make_bd_pins_external $pl_clk0
set_property name pl_clk0 [get_bd_ports -of_objects [get_bd_nets -of_objects $pl_clk0]]
set pl_clk0_port [get_bd_ports -of_objects [get_bd_nets -of_objects $pl_clk0]]

connect_bd_net $pl_clk0 [get_bd_pins $zynq_ultra_ps/maxihpm0_fpd_aclk]
connect_bd_net $pl_clk0 [get_bd_pins $zynq_ultra_ps/saxihpc0_fpd_aclk]
connect_bd_net $pl_clk0 [get_bd_pins $proc_sys_reset/slowest_sync_clk]
connect_bd_net $pl_clk0 [get_bd_pins $axi_interconnect_ctrl/ACLK]
connect_bd_net $pl_clk0 [get_bd_pins $axi_interconnect_ctrl/S00_ACLK]
connect_bd_net $pl_clk0 [get_bd_pins $axi_interconnect_ctrl/M00_ACLK]
connect_bd_net $pl_clk0 [get_bd_pins $axi_interconnect_ctrl/M01_ACLK]

set pl_clk0_busif [list]

# Reset
set pl_resetn0 [get_bd_pins $zynq_ultra_ps/pl_resetn0]
connect_bd_net $pl_resetn0 [get_bd_pins $proc_sys_reset/ext_reset_in]

set pl_reset [get_bd_pins $proc_sys_reset/peripheral_reset]
make_bd_pins_external $pl_reset
set_property name pl_reset [get_bd_ports -of_objects [get_bd_nets -of_objects $pl_reset]]

set interconnect_aresetn [get_bd_pins $proc_sys_reset/interconnect_aresetn]
connect_bd_net $interconnect_aresetn [get_bd_pins $axi_interconnect_ctrl/ARESETN]
connect_bd_net $interconnect_aresetn [get_bd_pins $axi_interconnect_ctrl/S00_ARESETN]
connect_bd_net $interconnect_aresetn [get_bd_pins $axi_interconnect_ctrl/M00_ARESETN]
connect_bd_net $interconnect_aresetn [get_bd_pins $axi_interconnect_ctrl/M01_ARESETN]

# MMIO
connect_bd_intf_net [get_bd_intf_pins $zynq_ultra_ps/M_AXI_HPM0_FPD] [get_bd_intf_pins $axi_interconnect_ctrl/S00_AXI]

# Control interface
set m_axil_ctrl_pin [get_bd_intf_pins $axi_interconnect_ctrl/M00_AXI]
make_bd_intf_pins_external $m_axil_ctrl_pin
set_property name m_axil_ctrl [get_bd_intf_ports -of_objects [get_bd_intf_nets -of_objects $m_axil_ctrl_pin]]
set m_axil_ctrl_port [get_bd_intf_ports -of_objects [get_bd_intf_nets -of_objects $m_axil_ctrl_pin]]
set_property -dict [list \
    CONFIG.PROTOCOL AXI4LITE \
    CONFIG.DATA_WIDTH 32 \
    CONFIG.ADDR_WIDTH 24 \
] $m_axil_ctrl_port
lappend pl_clk0_busif $m_axil_ctrl_port

# Application control interface
set m_axil_app_ctrl_pin [get_bd_intf_pins $axi_interconnect_ctrl/M01_AXI]
make_bd_intf_pins_external $m_axil_app_ctrl_pin
set_property name m_axil_app_ctrl [get_bd_intf_ports -of_objects [get_bd_intf_nets -of_objects $m_axil_app_ctrl_pin]]
set m_axil_app_ctrl_port [get_bd_intf_ports -of_objects [get_bd_intf_nets -of_objects $m_axil_app_ctrl_pin]]
set_property -dict [list \
    CONFIG.PROTOCOL AXI4LITE \
    CONFIG.DATA_WIDTH 32 \
    CONFIG.ADDR_WIDTH 24 \
] $m_axil_app_ctrl_port
lappend pl_clk0_busif $m_axil_app_ctrl_port

# DMA interface
set s_axi_dma_pin [get_bd_intf_pins $zynq_ultra_ps/S_AXI_HPC0_FPD]
make_bd_intf_pins_external $s_axi_dma_pin
set_property name s_axi_dma [get_bd_intf_ports -of_objects [get_bd_intf_nets -of_objects $s_axi_dma_pin]]
set s_axi_dma_port [get_bd_intf_ports -of_objects [get_bd_intf_nets -of_objects $s_axi_dma_pin]]
lappend pl_clk0_busif $s_axi_dma_port

# IRQ
set pl_ps_irq0 [get_bd_pins $zynq_ultra_ps/pl_ps_irq0]
make_bd_pins_external $pl_ps_irq0
set_property name pl_ps_irq0 [get_bd_ports -of_objects [get_bd_nets -of_objects $pl_ps_irq0]]
set pl_ps_irq0_port [get_bd_ports -of_objects [get_bd_nets -of_objects $pl_ps_irq0]]
set_property -dict [list \
    CONFIG.PortWidth 8 \
] $pl_ps_irq0_port

# Port clock associations
set lst [list]
foreach port $pl_clk0_busif {
    lappend lst [get_property name $port]
}
set_property CONFIG.ASSOCIATED_BUSIF [join $lst ":"] $pl_clk0_port

# Assign addresses
assign_bd_address -target_address_space /s_axi_dma [get_bd_addr_segs $zynq_ultra_ps/SAXIGP0/HPC0_DDR_HIGH] -force
assign_bd_address -target_address_space /s_axi_dma [get_bd_addr_segs $zynq_ultra_ps/SAXIGP0/HPC0_QSPI] -force
assign_bd_address -target_address_space /s_axi_dma [get_bd_addr_segs $zynq_ultra_ps/SAXIGP0/HPC0_DDR_LOW] -force
assign_bd_address -target_address_space /s_axi_dma [get_bd_addr_segs $zynq_ultra_ps/SAXIGP0/HPC0_LPS_OCM] -force

assign_bd_address -offset 0xA000_0000 -range 16M -target_address_space $zynq_ultra_ps/Data [get_bd_addr_segs $m_axil_ctrl_port/Reg] -force
assign_bd_address -offset 0xA800_0000 -range 16M -target_address_space $zynq_ultra_ps/Data [get_bd_addr_segs $m_axil_app_ctrl_port/Reg] -force

validate_bd_design

# Save block design
save_bd_design [current_bd_design]
close_bd_design [current_bd_design]
