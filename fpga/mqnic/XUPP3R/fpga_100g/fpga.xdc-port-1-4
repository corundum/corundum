# XDC constraints for the Bittxware XUPP3R board
# part: xcvu9p-flgb2104-1-e

# set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
# set_property SEVERITY {Warning} [get_drc_checks UCIO-1]

# General configuration
# set_property CFGBVS GND [current_design]
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]

set_property BITSTREAM.CONFIG.USR_ACCESS TIMESTAMP [current_design]
# Bitstream configuration settings

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR YES [current_design]
# Must set to "NO" if loading from backup flash partition

set_property BITSTREAM.CONFIG.CONFIGRATE 85.0 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]

# set_property BITSTREAM.CONFIG.CONFIGFALLBACK ENABLE [current_design]
# set_property BITSTREAM.CONFIG.EXTMASTERCCLK_EN DISABLE [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLUP [current_design]

## LEDs
set_property -dict {LOC AT32 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[0]}]
set_property -dict {LOC AV34 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[1]}]
set_property -dict {LOC AY30 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[2]}]

# UART
#set_property -dict {LOC AM24 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports uart_txd]
#set_property -dict {LOC AL24 IOSTANDARD LVCMOS18} [get_ports uart_rxd]

#set_false_path -to [get_ports {uart_txd}]
#set_output_delay 0 [get_ports {uart_txd}]
#set_false_path -from [get_ports {uart_rxd}]
#set_input_delay 0 [get_ports {uart_rxd}]

# Misc QSFP signals
# Enables qsfp
set_property -dict {LOC AN23 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports qsfp_ctl_en]
# makes fpga the master of the i2c bus instead of the bcm
set_property -dict {LOC AT24 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports fpga_i2c_master_l]

#######################################################
# QSFP0
#######################################################

# QSFP28 Interfaces GTY Bank 120 - first qsfp port
#--------------------------------------------------------------------
set_property -dict {LOC BC45 } [get_ports qsfp0_rx1_p]
set_property -dict {LOC BC46 } [get_ports qsfp0_rx1_n]
set_property -dict {LOC BF42 } [get_ports qsfp0_tx1_p]
set_property -dict {LOC BF43 } [get_ports qsfp0_tx1_n]
set_property -dict {LOC BA45 } [get_ports qsfp0_rx2_p]
set_property -dict {LOC BA46 } [get_ports qsfp0_rx2_n]
set_property -dict {LOC BD42 } [get_ports qsfp0_tx2_p]
set_property -dict {LOC BD43 } [get_ports qsfp0_tx2_n]
set_property -dict {LOC AW45 } [get_ports qsfp0_rx3_p]
set_property -dict {LOC AW46 } [get_ports qsfp0_rx3_n]
set_property -dict {LOC BB42 } [get_ports qsfp0_tx3_p]
set_property -dict {LOC BB43 } [get_ports qsfp0_tx3_n]
set_property -dict {LOC AV43 } [get_ports qsfp0_rx4_p]
set_property -dict {LOC AV44 } [get_ports qsfp0_rx4_n]
set_property -dict {LOC AW40 } [get_ports qsfp0_tx4_p]
set_property -dict {LOC AW41 } [get_ports qsfp0_tx4_n]

# GTY Bank 120 OSC 0
set_property -dict {LOC BA40 } [get_ports qsfp0_mgt_refclk_0_p]
set_property -dict {LOC BA41 } [get_ports qsfp0_mgt_refclk_0_n]
# GTY Bank 120 Prog Clk B1 3
# set_property -dict {LOC AY38 } [get_ports qsfp0_mgt_refclk_1_p]
# set_property -dict {LOC AY39 } [get_ports qsfp0_mgt_refclk_1_n]

set_property -dict {LOC BD24 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports qsfp0_resetl]
set_property -dict {LOC BD23 IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp0_modprsl] 
set_property -dict {LOC BE23 IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp0_intl]
set_property -dict {LOC BC24 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports qsfp0_lpmode]

set_property -dict {LOC BF24 IOSTANDARD LVCMOS18 } [get_ports qsfp0_i2c_scl]
set_property -dict {LOC BF23 IOSTANDARD LVCMOS18 } [get_ports qsfp0_i2c_sda]

#set_false_path -from [get_ports {qsfp0_modprsl qsfp0_intl}]
#set_input_delay 0 [get_ports {qsfp0_modprsl qsfp0_intl}]


## QSFP28 Interfaces GTY Bank 125 - third qsfp port
##----------------------------------------------------------------------------------
#set_property -dict {LOC AA45 } [get_ports qsfp0_rx1_p]
#set_property -dict {LOC AA46 } [get_ports qsfp0_rx1_n]
#set_property -dict {LOC AA40 } [get_ports qsfp0_tx1_p]
#set_property -dict {LOC AA41 } [get_ports qsfp0_tx1_n]
#set_property -dict {LOC Y43 } [get_ports qsfp0_rx2_p]
#set_property -dict {LOC Y44 } [get_ports qsfp0_rx2_n]
#set_property -dict {LOC Y38 } [get_ports qsfp0_tx2_p]
#set_property -dict {LOC Y39 } [get_ports qsfp0_tx2_n]
#set_property -dict {LOC W45 } [get_ports qsfp0_rx3_p]
#set_property -dict {LOC W46 } [get_ports qsfp0_rx3_n]
#set_property -dict {LOC W40 } [get_ports qsfp0_tx3_p]
#set_property -dict {LOC W41 } [get_ports qsfp0_tx3_n]
#set_property -dict {LOC V43 } [get_ports qsfp0_rx4_p]
#set_property -dict {LOC V44 } [get_ports qsfp0_rx4_n]
#set_property -dict {LOC V38 } [get_ports qsfp0_tx4_p]
#set_property -dict {LOC V39 } [get_ports qsfp0_tx4_n]

## GTY Bank 125 OSC 2
#set_property -dict {LOC AC36 } [get_ports qsfp0_mgt_refclk_0_p] ;# MGTREFCLK0P_230 from U14.4 via U43.15
#set_property -dict {LOC AC37 } [get_ports qsfp0_mgt_refclk_0_n] ;# MGTREFCLK0N_230 from U14.5 via U43.16
## GTY Bank 125 Prog Clk B2 0
## set_property -dict {LOC AA36 } [get_ports qsfp0_mgt_refclk_1_p] ;# MGTREFCLK1P_230 from U12.18
## set_property -dict {LOC AA37 } [get_ports qsfp0_mgt_refclk_1_n] ;# MGTREFCLK1N_230 from U12.17

#set_property -dict {LOC BB22 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports qsfp0_resetl]
#set_property -dict {LOC BB20 IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp0_modprsl]
#set_property -dict {LOC BB21 IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp0_intl]
#set_property -dict {LOC BC21 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports qsfp0_lpmode]

#set_property -dict {LOC BF20 IOSTANDARD LVCMOS18 } [get_ports qsfp0_i2c_scl]
#set_property -dict {LOC BA20 IOSTANDARD LVCMOS18 } [get_ports qsfp0_i2c_sda]

##set_false_path -from [get_ports {qsfp0_modprsl qsfp0_intl}]
##set_input_delay 0 [get_ports {qsfp0_modprsl qsfp0_intl}]


#######################################################
# QSFP1
#######################################################

## QSFP28 Interfaces GTY Bank 122 - second qsfp port
##------------------------------------------------------------------------
set_property -dict {LOC AN45 } [get_ports qsfp1_rx1_p]
set_property -dict {LOC AN46 } [get_ports qsfp1_rx1_n]
set_property -dict {LOC AN40 } [get_ports qsfp1_tx1_p]
set_property -dict {LOC AN41 } [get_ports qsfp1_tx1_n]
set_property -dict {LOC AM43 } [get_ports qsfp1_rx2_p]
set_property -dict {LOC AM44 } [get_ports qsfp1_rx2_n]
set_property -dict {LOC AM38 } [get_ports qsfp1_tx2_p]
set_property -dict {LOC AM39 } [get_ports qsfp1_tx2_n]
set_property -dict {LOC AL45 } [get_ports qsfp1_rx3_p]
set_property -dict {LOC AL46 } [get_ports qsfp1_rx3_n]
set_property -dict {LOC AL40 } [get_ports qsfp1_tx3_p]
set_property -dict {LOC AL41 } [get_ports qsfp1_tx3_n]
set_property -dict {LOC AK43 } [get_ports qsfp1_rx4_p]
set_property -dict {LOC AK44 } [get_ports qsfp1_rx4_n]
set_property -dict {LOC AK38 } [get_ports qsfp1_tx4_p]
set_property -dict {LOC AK39 } [get_ports qsfp1_tx4_n]

## GTY Bank 122 OSC 1
set_property -dict {LOC AR36 } [get_ports qsfp1_mgt_refclk_1_p]
set_property -dict {LOC AR37 } [get_ports qsfp1_mgt_refclk_1_n]
## GTY Bank 122 Prog Clk B1 0
## set_property -dict {LOC AN36 } [get_ports qsfp1_mgt_refclk_1_p]
## set_property -dict {LOC AN37 } [get_ports qsfp1_mgt_refclk_1_n]

set_property -dict {LOC BE20 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports qsfp1_resetl]
set_property -dict {LOC BD21 IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp1_modprsl]
set_property -dict {LOC BE21 IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp1_intl]
set_property -dict {LOC BD20 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports qsfp1_lpmode]

set_property -dict {LOC BE22 IOSTANDARD LVCMOS18 } [get_ports qsfp1_i2c_scl]
set_property -dict {LOC BF22 IOSTANDARD LVCMOS18 } [get_ports qsfp1_i2c_sda]

#set_false_path -from [get_ports {qsfp1_modprsl qsfp1_intl}]
#set_input_delay 0 [get_ports {qsfp1_modprsl qsfp1_intl}]


## QSFP28 Interfaces GTY Bank 127 - fourth qsfp port
#-----------------------------------------------------------------------------------
#set_property -dict {LOC N45 } [get_ports qsfp1_rx1_p]
#set_property -dict {LOC N46 } [get_ports qsfp1_rx1_n]
#set_property -dict {LOC N40 } [get_ports qsfp1_tx1_p]
#set_property -dict {LOC N41 } [get_ports qsfp1_tx1_n]
#set_property -dict {LOC M43 } [get_ports qsfp1_rx2_p]
#set_property -dict {LOC M44 } [get_ports qsfp1_rx2_n]
#set_property -dict {LOC M38 } [get_ports qsfp1_tx2_p]
#set_property -dict {LOC M39 } [get_ports qsfp1_tx2_n]
#set_property -dict {LOC L45 } [get_ports qsfp1_rx3_p]
#set_property -dict {LOC L46 } [get_ports qsfp1_rx3_n]
#set_property -dict {LOC L40 } [get_ports qsfp1_tx3_p]
#set_property -dict {LOC L41 } [get_ports qsfp1_tx3_n]
#set_property -dict {LOC K43 } [get_ports qsfp1_rx4_p]
#set_property -dict {LOC K44 } [get_ports qsfp1_rx4_n]
#set_property -dict {LOC J40 } [get_ports qsfp1_tx4_p]
#set_property -dict {LOC J41 } [get_ports qsfp1_tx4_n]

# GTY Bank 127 OSC 3
## set_property -dict {LOC R36 } [get_ports qsfp1_mgt_refclk_0_p] ;# MGTREFCLK0P_230 from U14.4 via U43.15
## set_property -dict {LOC R37 } [get_ports qsfp1_mgt_refclk_0_n] ;# MGTREFCLK0N_230 from U14.5 via U43.16
# GTY Bank 127 Prog Clk B3
#set_property -dict {LOC N36 } [get_ports qsfp1_mgt_refclk_1_p] ;# MGTREFCLK1P_230 from U12.18
#set_property -dict {LOC N37 } [get_ports qsfp1_mgt_refclk_1_n] ;# MGTREFCLK1N_230 from U12.17

#set_property -dict {LOC BC23 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports qsfp1_resetl]
#set_property -dict {LOC BB24 IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp1_modprsl]
#set_property -dict {LOC AY22 IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp1_intl]
#set_property -dict {LOC BA22 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports qsfp1_lpmode]

#set_property -dict {LOC BC22 IOSTANDARD LVCMOS18 } [get_ports qsfp1_i2c_scl]
#set_property -dict {LOC BA24 IOSTANDARD LVCMOS18 } [get_ports qsfp1_i2c_sda]

##set_false_path -from [get_ports {qsfp1_modprsl qsfp1_intl}]
##set_input_delay 0 [get_ports {qsfp1_modprsl qsfp1_intl}]


# PCIe Interface
set_property -dict {LOC AF2 } [get_ports {pcie_rx_p[0]}]
set_property -dict {LOC AF1 } [get_ports {pcie_rx_n[0]}]
set_property -dict {LOC AF7 } [get_ports {pcie_tx_p[0]}]
set_property -dict {LOC AF6 } [get_ports {pcie_tx_n[0]}]
set_property -dict {LOC AG4 } [get_ports {pcie_rx_p[1]}]
set_property -dict {LOC AG3 } [get_ports {pcie_rx_n[1]}]
set_property -dict {LOC AG9 } [get_ports {pcie_tx_p[1]}]
set_property -dict {LOC AG8 } [get_ports {pcie_tx_n[1]}]
set_property -dict {LOC AH2 } [get_ports {pcie_rx_p[2]}]
set_property -dict {LOC AH1 } [get_ports {pcie_rx_n[2]}]
set_property -dict {LOC AH7 } [get_ports {pcie_tx_p[2]}]
set_property -dict {LOC AH6 } [get_ports {pcie_tx_n[2]}]
set_property -dict {LOC AJ4 } [get_ports {pcie_rx_p[3]}]
set_property -dict {LOC AJ3 } [get_ports {pcie_rx_n[3]}]
set_property -dict {LOC AJ9 } [get_ports {pcie_tx_p[3]}]
set_property -dict {LOC AJ8 } [get_ports {pcie_tx_n[3]}]
set_property -dict {LOC AK2 } [get_ports {pcie_rx_p[4]}]
set_property -dict {LOC AK1 } [get_ports {pcie_rx_n[4]}]
set_property -dict {LOC AK7 } [get_ports {pcie_tx_p[4]}]
set_property -dict {LOC AK6 } [get_ports {pcie_tx_n[4]}]
set_property -dict {LOC AL4 } [get_ports {pcie_rx_p[5]}]
set_property -dict {LOC AL3 } [get_ports {pcie_rx_n[5]}]
set_property -dict {LOC AL9 } [get_ports {pcie_tx_p[5]}]
set_property -dict {LOC AL8 } [get_ports {pcie_tx_n[5]}]
set_property -dict {LOC AM2 } [get_ports {pcie_rx_p[6]}]
set_property -dict {LOC AM1 } [get_ports {pcie_rx_n[6]}]
set_property -dict {LOC AM7 } [get_ports {pcie_tx_p[6]}]
set_property -dict {LOC AM6 } [get_ports {pcie_tx_n[6]}]
set_property -dict {LOC AN4 } [get_ports {pcie_rx_p[7]}]
set_property -dict {LOC AN3 } [get_ports {pcie_rx_n[7]}]
set_property -dict {LOC AN9 } [get_ports {pcie_tx_p[7]}]
set_property -dict {LOC AN8 } [get_ports {pcie_tx_n[7]}]
set_property -dict {LOC AP2 } [get_ports {pcie_rx_p[8]}]
set_property -dict {LOC AP1 } [get_ports {pcie_rx_n[8]}]
set_property -dict {LOC AP7 } [get_ports {pcie_tx_p[8]}]
set_property -dict {LOC AP6 } [get_ports {pcie_tx_n[8]}]
set_property -dict {LOC AR4 } [get_ports {pcie_rx_p[9]}]
set_property -dict {LOC AR3 } [get_ports {pcie_rx_n[9]}]
set_property -dict {LOC AR9 } [get_ports {pcie_tx_p[9]}]
set_property -dict {LOC AR8 } [get_ports {pcie_tx_n[9]}]
set_property -dict {LOC AT2 } [get_ports {pcie_rx_p[10]}]
set_property -dict {LOC AT1 } [get_ports {pcie_rx_n[10]}]
set_property -dict {LOC AT7 } [get_ports {pcie_tx_p[10]}]
set_property -dict {LOC AT6 } [get_ports {pcie_tx_n[10]}]
set_property -dict {LOC AU4 } [get_ports {pcie_rx_p[11]}]
set_property -dict {LOC AU3 } [get_ports {pcie_rx_n[11]}]
set_property -dict {LOC AU9 } [get_ports {pcie_tx_p[11]}]
set_property -dict {LOC AU8 } [get_ports {pcie_tx_n[11]}]
set_property -dict {LOC AV2 } [get_ports {pcie_rx_p[12]}]
set_property -dict {LOC AV1 } [get_ports {pcie_rx_n[12]}]
set_property -dict {LOC AV7 } [get_ports {pcie_tx_p[12]}]
set_property -dict {LOC AV6 } [get_ports {pcie_tx_n[12]}]
set_property -dict {LOC AW4 } [get_ports {pcie_rx_p[13]}]
set_property -dict {LOC AW3 } [get_ports {pcie_rx_n[13]}]
set_property -dict {LOC BB5 } [get_ports {pcie_tx_p[13]}]
set_property -dict {LOC BB4 } [get_ports {pcie_tx_n[13]}]
set_property -dict {LOC BA2 } [get_ports {pcie_rx_p[14]}]
set_property -dict {LOC BA1 } [get_ports {pcie_rx_n[14]}]
set_property -dict {LOC BD5 } [get_ports {pcie_tx_p[14]}]
set_property -dict {LOC BD4 } [get_ports {pcie_tx_n[14]}]
set_property -dict {LOC BC2 } [get_ports {pcie_rx_p[15]}]
set_property -dict {LOC BC1 } [get_ports {pcie_rx_n[15]}]
set_property -dict {LOC BF5 } [get_ports {pcie_tx_p[15]}]
set_property -dict {LOC BF4 } [get_ports {pcie_tx_n[15]}]
set_property -dict {LOC AT11 } [get_ports pcie_refclk_p]
set_property -dict {LOC AT10 } [get_ports pcie_refclk_n]
set_property -dict {LOC AR26 IOSTANDARD LVCMOS12 PULLUP true} [get_ports pcie_reset_n]

# 100 MHz MGT reference clock
create_clock -period 10 -name pcie_mgt_refclk_1 [get_ports pcie_refclk_p]

set_false_path -from [get_ports {pcie_reset_n}]
set_input_delay 0 [get_ports {pcie_reset_n}]
