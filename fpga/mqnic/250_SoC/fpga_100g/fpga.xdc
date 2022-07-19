# XDC constraints for the BittWare 250-SoC board
# part: xczu19eg-ffvd1760-2-e

# General configuration
set_property BITSTREAM.GENERAL.COMPRESS true           [current_design]

# System clocks
# 200 MHz (DDR 0)
set_property -dict {LOC J19 IOSTANDARD DIFF_SSTL12} [get_ports clk_200mhz_p]
set_property -dict {LOC J18 IOSTANDARD DIFF_SSTL12} [get_ports clk_200mhz_n]
create_clock -period 5 -name clk_200mhz [get_ports clk_200mhz_p]

# LEDs
set_property -dict {LOC B12 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports {led[0]}]
set_property -dict {LOC B13 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports {led[1]}]
set_property -dict {LOC B10 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports {led[2]}]
set_property -dict {LOC B11 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports {led[3]}]

set_false_path -to [get_ports {led[*]}]
set_output_delay 0 [get_ports {led[*]}]

# QSFP28 Interfaces
set_property -dict {LOC H41 } [get_ports qsfp0_rx1_p] ;# MGTYRXP0_133 GTYE4_CHANNEL_X0Y24 / GTYE4_COMMON_X0Y6
set_property -dict {LOC H42 } [get_ports qsfp0_rx1_n] ;# MGTYRXN0_133 GTYE4_CHANNEL_X0Y24 / GTYE4_COMMON_X0Y6
set_property -dict {LOC H36 } [get_ports qsfp0_tx1_p] ;# MGTYTXP0_133 GTYE4_CHANNEL_X0Y24 / GTYE4_COMMON_X0Y6
set_property -dict {LOC H37 } [get_ports qsfp0_tx1_n] ;# MGTYTXN0_133 GTYE4_CHANNEL_X0Y24 / GTYE4_COMMON_X0Y6
set_property -dict {LOC G39 } [get_ports qsfp0_rx2_p] ;# MGTYRXP1_133 GTYE4_CHANNEL_X0Y25 / GTYE4_COMMON_X0Y6
set_property -dict {LOC G40 } [get_ports qsfp0_rx2_n] ;# MGTYRXN1_133 GTYE4_CHANNEL_X0Y25 / GTYE4_COMMON_X0Y6
set_property -dict {LOC G34 } [get_ports qsfp0_tx2_p] ;# MGTYTXP1_133 GTYE4_CHANNEL_X0Y25 / GTYE4_COMMON_X0Y6
set_property -dict {LOC G35 } [get_ports qsfp0_tx2_n] ;# MGTYTXN1_133 GTYE4_CHANNEL_X0Y25 / GTYE4_COMMON_X0Y6
set_property -dict {LOC F41 } [get_ports qsfp0_rx3_p] ;# MGTYRXP2_133 GTYE4_CHANNEL_X0Y26 / GTYE4_COMMON_X0Y6
set_property -dict {LOC F42 } [get_ports qsfp0_rx3_n] ;# MGTYRXN2_133 GTYE4_CHANNEL_X0Y26 / GTYE4_COMMON_X0Y6
set_property -dict {LOC F36 } [get_ports qsfp0_tx3_p] ;# MGTYTXP2_133 GTYE4_CHANNEL_X0Y26 / GTYE4_COMMON_X0Y6
set_property -dict {LOC F37 } [get_ports qsfp0_tx3_n] ;# MGTYTXN2_133 GTYE4_CHANNEL_X0Y26 / GTYE4_COMMON_X0Y6
set_property -dict {LOC E39 } [get_ports qsfp0_rx4_p] ;# MGTYRXP3_133 GTYE4_CHANNEL_X0Y27 / GTYE4_COMMON_X0Y6
set_property -dict {LOC E40 } [get_ports qsfp0_rx4_n] ;# MGTYRXN3_133 GTYE4_CHANNEL_X0Y27 / GTYE4_COMMON_X0Y6
set_property -dict {LOC E34 } [get_ports qsfp0_tx4_p] ;# MGTYTXP3_133 GTYE4_CHANNEL_X0Y27 / GTYE4_COMMON_X0Y6
set_property -dict {LOC E35 } [get_ports qsfp0_tx4_n] ;# MGTYTXN3_133 GTYE4_CHANNEL_X0Y27 / GTYE4_COMMON_X0Y6
set_property -dict {LOC H32 } [get_ports qsfp0_mgt_refclk_p] ;# MGTREFCLK0P_133 from Y4
set_property -dict {LOC H33 } [get_ports qsfp0_mgt_refclk_n] ;# MGTREFCLK0N_133 from Y4
set_property -dict {LOC L13  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports qsfp0_resetl]
set_property -dict {LOC J15  IOSTANDARD LVCMOS33 PULLUP true} [get_ports qsfp0_modprsl]
set_property -dict {LOC K15  IOSTANDARD LVCMOS33 PULLUP true} [get_ports qsfp0_intl]
set_property -dict {LOC L12  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports qsfp0_lpmode]

# 322.265625 MHz MGT reference clock (from Y4)
#create_clock -period 3.103 -name qsfp0_mgt_refclk [get_ports qsfp0_mgt_refclk_p]

set_false_path -to [get_ports {qsfp0_resetl qsfp0_lpmode}]
set_output_delay 0 [get_ports {qsfp0_resetl qsfp0_lpmode}]
set_false_path -from [get_ports {qsfp0_modprsl qsfp0_intl}]
set_input_delay 0 [get_ports {qsfp0_modprsl qsfp0_intl}]

set_property -dict {LOC D41 } [get_ports qsfp1_rx1_p] ;# MGTYRXP0_134 GTYE4_CHANNEL_X0Y28 / GTYE4_COMMON_X10Y7
set_property -dict {LOC D42 } [get_ports qsfp1_rx1_n] ;# MGTYRXN0_134 GTYE4_CHANNEL_X0Y28 / GTYE4_COMMON_X10Y7
set_property -dict {LOC D36 } [get_ports qsfp1_tx1_p] ;# MGTYTXP0_134 GTYE4_CHANNEL_X0Y28 / GTYE4_COMMON_X10Y7
set_property -dict {LOC D37 } [get_ports qsfp1_tx1_n] ;# MGTYTXN0_134 GTYE4_CHANNEL_X0Y28 / GTYE4_COMMON_X10Y7
set_property -dict {LOC C39 } [get_ports qsfp1_rx2_p] ;# MGTYRXP1_134 GTYE4_CHANNEL_X0Y29 / GTYE4_COMMON_X10Y7
set_property -dict {LOC C40 } [get_ports qsfp1_rx2_n] ;# MGTYRXN1_134 GTYE4_CHANNEL_X0Y29 / GTYE4_COMMON_X10Y7
set_property -dict {LOC C34 } [get_ports qsfp1_tx2_p] ;# MGTYTXP1_134 GTYE4_CHANNEL_X0Y29 / GTYE4_COMMON_X10Y7
set_property -dict {LOC C35 } [get_ports qsfp1_tx2_n] ;# MGTYTXN1_134 GTYE4_CHANNEL_X0Y29 / GTYE4_COMMON_X10Y7
set_property -dict {LOC B41 } [get_ports qsfp1_rx3_p] ;# MGTYRXP2_134 GTYE4_CHANNEL_X0Y30 / GTYE4_COMMON_X10Y7
set_property -dict {LOC B42 } [get_ports qsfp1_rx3_n] ;# MGTYRXN2_134 GTYE4_CHANNEL_X0Y30 / GTYE4_COMMON_X10Y7
set_property -dict {LOC B36 } [get_ports qsfp1_tx3_p] ;# MGTYTXP2_134 GTYE4_CHANNEL_X0Y30 / GTYE4_COMMON_X10Y7
set_property -dict {LOC B37 } [get_ports qsfp1_tx3_n] ;# MGTYTXN2_134 GTYE4_CHANNEL_X0Y30 / GTYE4_COMMON_X10Y7
set_property -dict {LOC A39 } [get_ports qsfp1_rx4_p] ;# MGTYRXP3_134 GTYE4_CHANNEL_X0Y31 / GTYE4_COMMON_X10Y7
set_property -dict {LOC A40 } [get_ports qsfp1_rx4_n] ;# MGTYRXN3_134 GTYE4_CHANNEL_X0Y31 / GTYE4_COMMON_X10Y7
set_property -dict {LOC A34 } [get_ports qsfp1_tx4_p] ;# MGTYTXP3_134 GTYE4_CHANNEL_X0Y31 / GTYE4_COMMON_X10Y7
set_property -dict {LOC A35 } [get_ports qsfp1_tx4_n] ;# MGTYTXN3_134 GTYE4_CHANNEL_X0Y31 / GTYE4_COMMON_X10Y7
set_property -dict {LOC D32 } [get_ports qsfp1_mgt_refclk_p] ;# MGTREFCLK0P_134 from Y5
set_property -dict {LOC D33 } [get_ports qsfp1_mgt_refclk_n] ;# MGTREFCLK0N_134 from Y5
set_property -dict {LOC K13  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports qsfp1_resetl]
set_property -dict {LOC J13  IOSTANDARD LVCMOS33 PULLUP true} [get_ports qsfp1_modprsl]
set_property -dict {LOC J14  IOSTANDARD LVCMOS33 PULLUP true} [get_ports qsfp1_intl]
set_property -dict {LOC K12  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports qsfp1_lpmode]

# 322.265625 MHz MGT reference clock (from Y5)
#create_clock -period 3.103 -name qsfp1_mgt_refclk [get_ports qsfp1_mgt_refclk_p]

set_false_path -to [get_ports {qsfp1_resetl qsfp1_lpmode}]
set_output_delay 0 [get_ports {qsfp1_resetl qsfp1_lpmode}]
set_false_path -from [get_ports {qsfp1_modprsl qsfp1_intl}]
set_input_delay 0 [get_ports {qsfp1_modprsl qsfp1_intl}]

# I2C interface
set_property -dict {LOC H12 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports fpga_ucd_scl]
set_property -dict {LOC J12 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports fpga_ucd_sda]
set_property -dict {LOC H14 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports fpga_i2c_scl]
set_property -dict {LOC H15 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports fpga_i2c_sda]
set_property -dict {LOC G12 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports fpga_smbus_scl]
set_property -dict {LOC G13 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports fpga_smbus_sda]
set_property -dict {LOC R15 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports fpga_smbus_en_n]

set_false_path -to [get_ports {fpga_ucd_sda fpga_ucd_scl}]
set_output_delay 0 [get_ports {fpga_ucd_sda fpga_ucd_scl}]
set_false_path -from [get_ports {fpga_ucd_sda fpga_ucd_scl}]
set_input_delay 0 [get_ports {fpga_ucd_sda fpga_ucd_scl}]

set_false_path -to [get_ports {fpga_i2c_sda fpga_i2c_scl}]
set_output_delay 0 [get_ports {fpga_i2c_sda fpga_i2c_scl}]
set_false_path -from [get_ports {fpga_i2c_sda fpga_i2c_scl}]
set_input_delay 0 [get_ports {fpga_i2c_sda fpga_i2c_scl}]

set_false_path -to [get_ports {fpga_smbus_sda fpga_smbus_scl}]
set_output_delay 0 [get_ports {fpga_smbus_sda fpga_smbus_scl}]
set_false_path -from [get_ports {fpga_smbus_sda fpga_smbus_scl fpga_smbus_en_n}]
set_input_delay 0 [get_ports {fpga_smbus_sda fpga_smbus_scl fpga_smbus_en_n}]

# PCIe Interface
set_property -dict {LOC AH2 } [get_ports {pcie_rx_p[0]}]  ;# MGTHRXP3_227 GTHE4_CHANNEL_X1Y15 / GTHE4_COMMON_X1Y3
set_property -dict {LOC AH1 } [get_ports {pcie_rx_n[0]}]  ;# MGTHRXN3_227 GTHE4_CHANNEL_X1Y15 / GTHE4_COMMON_X1Y3
set_property -dict {LOC AG8 } [get_ports {pcie_tx_p[0]}]  ;# MGTHTXP3_227 GTHE4_CHANNEL_X1Y15 / GTHE4_COMMON_X1Y3
set_property -dict {LOC AG7 } [get_ports {pcie_tx_n[0]}]  ;# MGTHTXN3_227 GTHE4_CHANNEL_X1Y15 / GTHE4_COMMON_X1Y3
set_property -dict {LOC AJ4 } [get_ports {pcie_rx_p[1]}]  ;# MGTHRXP2_227 GTHE4_CHANNEL_X1Y14 / GTHE4_COMMON_X1Y3
set_property -dict {LOC AJ3 } [get_ports {pcie_rx_n[1]}]  ;# MGTHRXN2_227 GTHE4_CHANNEL_X1Y14 / GTHE4_COMMON_X1Y3
set_property -dict {LOC AH6 } [get_ports {pcie_tx_p[1]}]  ;# MGTHTXP2_227 GTHE4_CHANNEL_X1Y14 / GTHE4_COMMON_X1Y3
set_property -dict {LOC AH5 } [get_ports {pcie_tx_n[1]}]  ;# MGTHTXN2_227 GTHE4_CHANNEL_X1Y14 / GTHE4_COMMON_X1Y3
set_property -dict {LOC AK2 } [get_ports {pcie_rx_p[2]}]  ;# MGTHRXP1_227 GTHE4_CHANNEL_X1Y13 / GTHE4_COMMON_X1Y3
set_property -dict {LOC AK1 } [get_ports {pcie_rx_n[2]}]  ;# MGTHRXN1_227 GTHE4_CHANNEL_X1Y13 / GTHE4_COMMON_X1Y3
set_property -dict {LOC AJ8 } [get_ports {pcie_tx_p[2]}]  ;# MGTHTXP1_227 GTHE4_CHANNEL_X1Y13 / GTHE4_COMMON_X1Y3
set_property -dict {LOC AJ7 } [get_ports {pcie_tx_n[2]}]  ;# MGTHTXN1_227 GTHE4_CHANNEL_X1Y13 / GTHE4_COMMON_X1Y3
set_property -dict {LOC AL4 } [get_ports {pcie_rx_p[3]}]  ;# MGTHRXP0_227 GTHE4_CHANNEL_X1Y12 / GTHE4_COMMON_X1Y3
set_property -dict {LOC AL3 } [get_ports {pcie_rx_n[3]}]  ;# MGTHRXN0_227 GTHE4_CHANNEL_X1Y12 / GTHE4_COMMON_X1Y3
set_property -dict {LOC AK6 } [get_ports {pcie_tx_p[3]}]  ;# MGTHTXP0_227 GTHE4_CHANNEL_X1Y12 / GTHE4_COMMON_X1Y3
set_property -dict {LOC AK5 } [get_ports {pcie_tx_n[3]}]  ;# MGTHTXN0_227 GTHE4_CHANNEL_X1Y12 / GTHE4_COMMON_X1Y3
set_property -dict {LOC AM2 } [get_ports {pcie_rx_p[4]}]  ;# MGTHRXP3_226 GTHE4_CHANNEL_X1Y11 / GTHE4_COMMON_X1Y2
set_property -dict {LOC AM1 } [get_ports {pcie_rx_n[4]}]  ;# MGTHRXN3_226 GTHE4_CHANNEL_X1Y11 / GTHE4_COMMON_X1Y2
set_property -dict {LOC AL8 } [get_ports {pcie_tx_p[4]}]  ;# MGTHTXP3_226 GTHE4_CHANNEL_X1Y11 / GTHE4_COMMON_X1Y2
set_property -dict {LOC AL7 } [get_ports {pcie_tx_n[4]}]  ;# MGTHTXN3_226 GTHE4_CHANNEL_X1Y11 / GTHE4_COMMON_X1Y2
set_property -dict {LOC AN4 } [get_ports {pcie_rx_p[5]}]  ;# MGTHRXP2_226 GTHE4_CHANNEL_X1Y10 / GTHE4_COMMON_X1Y2
set_property -dict {LOC AN3 } [get_ports {pcie_rx_n[5]}]  ;# MGTHRXN2_226 GTHE4_CHANNEL_X1Y10 / GTHE4_COMMON_X1Y2
set_property -dict {LOC AM6 } [get_ports {pcie_tx_p[5]}]  ;# MGTHTXP2_226 GTHE4_CHANNEL_X1Y10 / GTHE4_COMMON_X1Y2
set_property -dict {LOC AM5 } [get_ports {pcie_tx_n[5]}]  ;# MGTHTXN2_226 GTHE4_CHANNEL_X1Y10 / GTHE4_COMMON_X1Y2
set_property -dict {LOC AP2 } [get_ports {pcie_rx_p[6]}]  ;# MGTHRXP1_226 GTHE4_CHANNEL_X1Y9 / GTHE4_COMMON_X1Y2
set_property -dict {LOC AP1 } [get_ports {pcie_rx_n[6]}]  ;# MGTHRXN1_226 GTHE4_CHANNEL_X1Y9 / GTHE4_COMMON_X1Y2
set_property -dict {LOC AN8 } [get_ports {pcie_tx_p[6]}]  ;# MGTHTXP1_226 GTHE4_CHANNEL_X1Y9 / GTHE4_COMMON_X1Y2
set_property -dict {LOC AN7 } [get_ports {pcie_tx_n[6]}]  ;# MGTHTXN1_226 GTHE4_CHANNEL_X1Y9 / GTHE4_COMMON_X1Y2
set_property -dict {LOC AR4 } [get_ports {pcie_rx_p[7]}]  ;# MGTHRXP0_226 GTHE4_CHANNEL_X1Y8 / GTHE4_COMMON_X1Y2
set_property -dict {LOC AR3 } [get_ports {pcie_rx_n[7]}]  ;# MGTHRXN0_226 GTHE4_CHANNEL_X1Y8 / GTHE4_COMMON_X1Y2
set_property -dict {LOC AP6 } [get_ports {pcie_tx_p[7]}]  ;# MGTHTXP0_226 GTHE4_CHANNEL_X1Y8 / GTHE4_COMMON_X1Y2
set_property -dict {LOC AP5 } [get_ports {pcie_tx_n[7]}]  ;# MGTHTXN0_226 GTHE4_CHANNEL_X1Y8 / GTHE4_COMMON_X1Y2
set_property -dict {LOC AT2 } [get_ports {pcie_rx_p[8]}]  ;# MGTHRXP3_225 GTHE4_CHANNEL_X1Y7 / GTHE4_COMMON_X1Y1
set_property -dict {LOC AT1 } [get_ports {pcie_rx_n[8]}]  ;# MGTHRXN3_225 GTHE4_CHANNEL_X1Y7 / GTHE4_COMMON_X1Y1
set_property -dict {LOC AP10} [get_ports {pcie_tx_p[8]}]  ;# MGTHTXP3_225 GTHE4_CHANNEL_X1Y7 / GTHE4_COMMON_X1Y1
set_property -dict {LOC AP9 } [get_ports {pcie_tx_n[8]}]  ;# MGTHTXN3_225 GTHE4_CHANNEL_X1Y7 / GTHE4_COMMON_X1Y1
set_property -dict {LOC AU4 } [get_ports {pcie_rx_p[9]}]  ;# MGTHRXP2_225 GTHE4_CHANNEL_X1Y6 / GTHE4_COMMON_X1Y1
set_property -dict {LOC AU3 } [get_ports {pcie_rx_n[9]}]  ;# MGTHRXN2_225 GTHE4_CHANNEL_X1Y6 / GTHE4_COMMON_X1Y1
set_property -dict {LOC AR8 } [get_ports {pcie_tx_p[9]}]  ;# MGTHTXP2_225 GTHE4_CHANNEL_X1Y6 / GTHE4_COMMON_X1Y1
set_property -dict {LOC AR7 } [get_ports {pcie_tx_n[9]}]  ;# MGTHTXN2_225 GTHE4_CHANNEL_X1Y6 / GTHE4_COMMON_X1Y1
set_property -dict {LOC AV2 } [get_ports {pcie_rx_p[10]}] ;# MGTHRXP1_225 GTHE4_CHANNEL_X1Y5 / GTHE4_COMMON_X1Y1
set_property -dict {LOC AV1 } [get_ports {pcie_rx_n[10]}] ;# MGTHRXN1_225 GTHE4_CHANNEL_X1Y5 / GTHE4_COMMON_X1Y1
set_property -dict {LOC AT6 } [get_ports {pcie_tx_p[10]}] ;# MGTHTXP1_225 GTHE4_CHANNEL_X1Y5 / GTHE4_COMMON_X1Y1
set_property -dict {LOC AT5 } [get_ports {pcie_tx_n[10]}] ;# MGTHTXN1_225 GTHE4_CHANNEL_X1Y5 / GTHE4_COMMON_X1Y1
set_property -dict {LOC AW4 } [get_ports {pcie_rx_p[11]}] ;# MGTHRXP0_225 GTHE4_CHANNEL_X1Y4 / GTHE4_COMMON_X1Y1
set_property -dict {LOC AW3 } [get_ports {pcie_rx_n[11]}] ;# MGTHRXN0_225 GTHE4_CHANNEL_X1Y4 / GTHE4_COMMON_X1Y1
set_property -dict {LOC AT10} [get_ports {pcie_tx_p[11]}] ;# MGTHTXP0_225 GTHE4_CHANNEL_X1Y4 / GTHE4_COMMON_X1Y1
set_property -dict {LOC AT9 } [get_ports {pcie_tx_n[11]}] ;# MGTHTXN0_225 GTHE4_CHANNEL_X1Y4 / GTHE4_COMMON_X1Y1
set_property -dict {LOC AY2 } [get_ports {pcie_rx_p[12]}] ;# MGTHRXP3_224 GTHE4_CHANNEL_X1Y3 / GTHE4_COMMON_X1Y0
set_property -dict {LOC AY1 } [get_ports {pcie_rx_n[12]}] ;# MGTHRXN3_224 GTHE4_CHANNEL_X1Y3 / GTHE4_COMMON_X1Y0
set_property -dict {LOC AU8 } [get_ports {pcie_tx_p[12]}] ;# MGTHTXP3_224 GTHE4_CHANNEL_X1Y3 / GTHE4_COMMON_X1Y0
set_property -dict {LOC AU7 } [get_ports {pcie_tx_n[12]}] ;# MGTHTXN3_224 GTHE4_CHANNEL_X1Y3 / GTHE4_COMMON_X1Y0
set_property -dict {LOC AY6 } [get_ports {pcie_rx_p[13]}] ;# MGTHRXP2_224 GTHE4_CHANNEL_X1Y2 / GTHE4_COMMON_X1Y0
set_property -dict {LOC AY5 } [get_ports {pcie_rx_n[13]}] ;# MGTHRXN2_224 GTHE4_CHANNEL_X1Y2 / GTHE4_COMMON_X1Y0
set_property -dict {LOC AV6 } [get_ports {pcie_tx_p[13]}] ;# MGTHTXP2_224 GTHE4_CHANNEL_X1Y2 / GTHE4_COMMON_X1Y0
set_property -dict {LOC AV5 } [get_ports {pcie_tx_n[13]}] ;# MGTHTXN2_224 GTHE4_CHANNEL_X1Y2 / GTHE4_COMMON_X1Y0
set_property -dict {LOC BA4 } [get_ports {pcie_rx_p[14]}] ;# MGTHRXP1_224 GTHE4_CHANNEL_X1Y1 / GTHE4_COMMON_X1Y0
set_property -dict {LOC BA3 } [get_ports {pcie_rx_n[14]}] ;# MGTHRXN1_224 GTHE4_CHANNEL_X1Y1 / GTHE4_COMMON_X1Y0
set_property -dict {LOC AW8 } [get_ports {pcie_tx_p[14]}] ;# MGTHTXP1_224 GTHE4_CHANNEL_X1Y1 / GTHE4_COMMON_X1Y0
set_property -dict {LOC AW7 } [get_ports {pcie_tx_n[14]}] ;# MGTHTXN1_224 GTHE4_CHANNEL_X1Y1 / GTHE4_COMMON_X1Y0
set_property -dict {LOC BB6 } [get_ports {pcie_rx_p[15]}] ;# MGTHRXP0_224 GTHE4_CHANNEL_X1Y0 / GTHE4_COMMON_X1Y0
set_property -dict {LOC BB5 } [get_ports {pcie_rx_n[15]}] ;# MGTHRXN0_224 GTHE4_CHANNEL_X1Y0 / GTHE4_COMMON_X1Y0
set_property -dict {LOC BA8 } [get_ports {pcie_tx_p[15]}] ;# MGTHTXP0_224 GTHE4_CHANNEL_X1Y0 / GTHE4_COMMON_X1Y0
set_property -dict {LOC BA7 } [get_ports {pcie_tx_n[15]}] ;# MGTHTXN0_224 GTHE4_CHANNEL_X1Y0 / GTHE4_COMMON_X1Y0
set_property -dict {LOC AH10} [get_ports pcie_refclk_0_p] ;# MGTREFCLK0P_226 from edge via U6 and U8
set_property -dict {LOC AH9 } [get_ports pcie_refclk_0_n] ;# MGTREFCLK0N_226 from edge via U6 and U8
#set_property -dict {LOC AM10} [get_ports pcie_refclk_1_p] ;# MGTREFCLK0P_224 from edge via U6 and U7
#set_property -dict {LOC AM9 } [get_ports pcie_refclk_1_n] ;# MGTREFCLK0N_224 from edge via U6 and U7
set_property -dict {LOC AM16 IOSTANDARD LVCMOS18 PULLUP true} [get_ports pcie_reset_n]

# 100 MHz MGT reference clock
create_clock -period 10 -name pcie_mgt_refclk_0 [get_ports pcie_refclk_0_p]
#create_clock -period 10 -name pcie_mgt_refclk_1 [get_ports pcie_refclk_1_p]

set_false_path -from [get_ports {pcie_reset_n}]
set_input_delay 0 [get_ports {pcie_reset_n}]
