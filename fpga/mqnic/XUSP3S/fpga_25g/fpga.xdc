# XDC constraints for the BittWare XUSP3S board
# part: xcvu095-ffvb2104-2-e

# General configuration
set_property CFGBVS VCCO                               [current_design]
set_property CONFIG_VOLTAGE 3.3                        [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true           [current_design]
set_property BITSTREAM.CONFIG.EXTMASTERCCLK_EN DISABLE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 90            [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR YES       [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4           [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES        [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLUP         [current_design]
set_property BITSTREAM.CONFIG.OVERTEMPSHUTDOWN Enable  [current_design]

# System clocks
# 48 MHz system clock
set_property -dict {LOC AV23 IOSTANDARD LVCMOS33} [get_ports clk_48mhz]
create_clock -period 20.833 -name clk_48mhz [get_ports clk_48mhz]

# 322.265625 MHz clock from Si5338 B ch 1
#set_property -dict {LOC AY23 IOSTANDARD LVPECL} [get_ports clk_b1_p]
#set_property -dict {LOC BA23 IOSTANDARD LVPECL} [get_ports clk_b1_n]
#create_clock -period 3.103 -name clk_b1 [get_ports clk_b1_p]

# 322.265625 MHz clock from Si5338 B ch 2
#set_property -dict {LOC BB9  IOSTANDARD DIFF_SSTL15_DCI ODT RTT_48} [get_ports clk_b2_p]
#set_property -dict {LOC BC9  IOSTANDARD DIFF_SSTL15_DCI ODT RTT_48} [get_ports clk_b2_n]
#create_clock -period 3.103 -name clk_b2 [get_ports clk_b2_p]

# 100 MHz DDR4 SODIMM 1 clock from Si5338 A ch 0
set_property -dict {LOC AV18 IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_sodimm1_p]
set_property -dict {LOC AW18 IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_sodimm1_n]
#create_clock -period 10.000 -name clk_ddr_sodimm1 [get_ports clk_ddr_sodimm1_p]

# 100 MHz DDR4 A clock from Si5338 A ch 1
set_property -dict {LOC BB36 IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_a_p]
set_property -dict {LOC BC36 IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_a_n]
#create_clock -period 10.000 -name clk_ddr_a [get_ports clk_ddr_a_p]

# 100 MHz DDR4 B clock from Si5338 A ch 2
set_property -dict {LOC E38  IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_b_p]
set_property -dict {LOC D38  IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_b_n]
#create_clock -period 10.000 -name clk_ddr_b [get_ports clk_ddr_b_p]

# 100 MHz DDR4 SODIMM 2 clock from Si5338 A ch 3
set_property -dict {LOC K18  IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_sodimm2_p]
set_property -dict {LOC J18  IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_sodimm2_n]
#create_clock -period 10.000 -name clk_ddr_sodimm2 [get_ports clk_ddr_sodimm2_p]

# LEDs
set_property -dict {LOC AR22 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports {led[0]}]
set_property -dict {LOC AT22 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports {led[1]}]
set_property -dict {LOC AR23 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports {led[2]}]
set_property -dict {LOC AV22 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports {led[3]}]

set_false_path -to [get_ports {led[*]}]
set_output_delay 0 [get_ports {led[*]}]

# Timing
set_property -dict {LOC AU22 IOSTANDARD LVCMOS33} [get_ports ext_pps_in] ;# from J1
set_property -dict {LOC AV24 IOSTANDARD LVCMOS33} [get_ports ext_clk_in] ;# from J2

create_clock -period 100.000 -name ext_clk_in [get_ports ext_clk_in]

set_false_path -from [get_ports {ext_pps_in ext_clk_in}]
set_input_delay 0 [get_ports {ext_pps_in ext_clk_in}]

# Reset
#set_property -dict {LOC AT23 IOSTANDARD LVCMOS33} [get_ports sys_rst_l]

#set_false_path -from [get_ports {sys_rst_l}]
#set_input_delay 0 [get_ports {sys_rst_l}]

# UART
#set_property -dict {LOC AM24 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports uart_txd]
#set_property -dict {LOC AL24 IOSTANDARD LVCMOS33} [get_ports uart_rxd]

#set_false_path -to [get_ports {uart_txd}]
#set_output_delay 0 [get_ports {uart_txd}]
#set_false_path -from [get_ports {uart_rxd}]
#set_input_delay 0 [get_ports {uart_rxd}]

# EEPROM I2C interface
set_property -dict {LOC AN24 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports eeprom_i2c_scl]
set_property -dict {LOC AP23 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports eeprom_i2c_sda]

set_false_path -to [get_ports {eeprom_i2c_sda eeprom_i2c_scl}]
set_output_delay 0 [get_ports {eeprom_i2c_sda eeprom_i2c_scl}]
set_false_path -from [get_ports {eeprom_i2c_sda eeprom_i2c_scl}]
set_input_delay 0 [get_ports {eeprom_i2c_sda eeprom_i2c_scl}]

# I2C-related signals
set_property -dict {LOC AT24 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports fpga_i2c_master_l]
set_property -dict {LOC AN23 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports qsfp_ctl_en]

set_false_path -to [get_ports {fpga_i2c_master_l qsfp_ctl_en}]
set_output_delay 0 [get_ports {fpga_i2c_master_l qsfp_ctl_en}]

# QSFP28 Interfaces
set_property -dict {LOC BC45} [get_ports {qsfp0_rx_p[0]}] ;# MGTHRXP0_124 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BC46} [get_ports {qsfp0_rx_n[0]}] ;# MGTHRXN0_124 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BF42} [get_ports {qsfp0_tx_p[0]}] ;# MGTHTXP0_124 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BF43} [get_ports {qsfp0_tx_n[0]}] ;# MGTHTXN0_124 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BA45} [get_ports {qsfp0_rx_p[1]}] ;# MGTHRXP1_124 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BA46} [get_ports {qsfp0_rx_n[1]}] ;# MGTHRXN1_124 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BD42} [get_ports {qsfp0_tx_p[1]}] ;# MGTHTXP1_124 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BD43} [get_ports {qsfp0_tx_n[1]}] ;# MGTHTXN1_124 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC AW45} [get_ports {qsfp0_rx_p[2]}] ;# MGTHRXP2_124 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC AW46} [get_ports {qsfp0_rx_n[2]}] ;# MGTHRXN2_124 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BB42} [get_ports {qsfp0_tx_p[2]}] ;# MGTHTXP2_124 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BB43} [get_ports {qsfp0_tx_n[2]}] ;# MGTHTXN2_124 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC AV43} [get_ports {qsfp0_rx_p[3]}] ;# MGTHRXP3_124 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC AV44} [get_ports {qsfp0_rx_n[3]}] ;# MGTHRXN3_124 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC AW40} [get_ports {qsfp0_tx_p[3]}] ;# MGTHTXP3_124 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC AW41} [get_ports {qsfp0_tx_n[3]}] ;# MGTHTXN3_124 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BA40} [get_ports qsfp0_mgt_refclk_b0_p] ;# MGTREFCLK0P_124 from Si5338 B ch 0
set_property -dict {LOC BA41} [get_ports qsfp0_mgt_refclk_b0_n] ;# MGTREFCLK0N_124 from Si5338 B ch 0
#set_property -dict {LOC AY38} [get_ports qsfp0_mgt_refclk_b1_p] ;# MGTREFCLK1P_124 from Si5338 B ch 1
#set_property -dict {LOC AY39} [get_ports qsfp0_mgt_refclk_b1_n] ;# MGTREFCLK1N_124 from Si5338 B ch 1
set_property -dict {LOC BD24 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports qsfp0_resetl]
set_property -dict {LOC BD23 IOSTANDARD LVCMOS33 PULLUP true} [get_ports qsfp0_modprsl]
set_property -dict {LOC BE23 IOSTANDARD LVCMOS33 PULLUP true} [get_ports qsfp0_intl]
set_property -dict {LOC BC24 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports qsfp0_lpmode]
set_property -dict {LOC BF24 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8 PULLUP true} [get_ports qsfp0_i2c_scl]
set_property -dict {LOC BF23 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8 PULLUP true} [get_ports qsfp0_i2c_sda]

# 322.265625 MHz MGT reference clock (from Si5338 B ch 0)
create_clock -period 3.103 -name qsfp0_mgt_refclk_b0 [get_ports qsfp0_mgt_refclk_b0_p]

# 322.265625 MHz MGT reference clock (from Si5338 B ch 1)
#create_clock -period 3.103 -name qsfp0_mgt_refclk_b1 [get_ports qsfp0_mgt_refclk_b1_p]

set_false_path -to [get_ports {qsfp0_resetl qsfp0_lpmode}]
set_output_delay 0 [get_ports {qsfp0_resetl qsfp0_lpmode}]
set_false_path -from [get_ports {qsfp0_modprsl qsfp0_intl}]
set_input_delay 0 [get_ports {qsfp0_modprsl qsfp0_intl}]

set_false_path -to [get_ports {qsfp0_i2c_scl qsfp0_i2c_sda}]
set_output_delay 0 [get_ports {qsfp0_i2c_scl qsfp0_i2c_sda}]
set_false_path -from [get_ports {qsfp0_i2c_scl qsfp0_i2c_sda}]
set_input_delay 0 [get_ports {qsfp0_i2c_scl qsfp0_i2c_sda}]

set_property -dict {LOC AN45} [get_ports {qsfp1_rx_p[0]}] ;# MGTHRXP0_126 GTYE4_CHANNEL_X0Y12 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AN46} [get_ports {qsfp1_rx_n[0]}] ;# MGTHRXN0_126 GTYE4_CHANNEL_X0Y12 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AN40} [get_ports {qsfp1_tx_p[0]}] ;# MGTHTXP0_126 GTYE4_CHANNEL_X0Y12 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AN41} [get_ports {qsfp1_tx_n[0]}] ;# MGTHTXN0_126 GTYE4_CHANNEL_X0Y12 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AM43} [get_ports {qsfp1_rx_p[1]}] ;# MGTHRXP1_126 GTYE4_CHANNEL_X0Y13 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AM44} [get_ports {qsfp1_rx_n[1]}] ;# MGTHRXN1_126 GTYE4_CHANNEL_X0Y13 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AM38} [get_ports {qsfp1_tx_p[1]}] ;# MGTHTXP1_126 GTYE4_CHANNEL_X0Y13 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AM39} [get_ports {qsfp1_tx_n[1]}] ;# MGTHTXN1_126 GTYE4_CHANNEL_X0Y13 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AL45} [get_ports {qsfp1_rx_p[2]}] ;# MGTHRXP2_126 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AL46} [get_ports {qsfp1_rx_n[2]}] ;# MGTHRXN2_126 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AL40} [get_ports {qsfp1_tx_p[2]}] ;# MGTHTXP2_126 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AL41} [get_ports {qsfp1_tx_n[2]}] ;# MGTHTXN2_126 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AK43} [get_ports {qsfp1_rx_p[3]}] ;# MGTHRXP3_126 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AK44} [get_ports {qsfp1_rx_n[3]}] ;# MGTHRXN3_126 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AK38} [get_ports {qsfp1_tx_p[3]}] ;# MGTHTXP3_126 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AK39} [get_ports {qsfp1_tx_n[3]}] ;# MGTHTXN3_126 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AR36} [get_ports qsfp1_mgt_refclk_b0_p] ;# MGTREFCLK0P_126 from Si5338 B ch 0
set_property -dict {LOC AR37} [get_ports qsfp1_mgt_refclk_b0_n] ;# MGTREFCLK0N_126 from Si5338 B ch 0
#set_property -dict {LOC AN36} [get_ports qsfp1_mgt_refclk_b1_p] ;# MGTREFCLK1P_126 from Si5338 B ch 1
#set_property -dict {LOC AN37} [get_ports qsfp1_mgt_refclk_b1_n] ;# MGTREFCLK1N_126 from Si5338 B ch 1
set_property -dict {LOC BE20 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports qsfp1_resetl]
set_property -dict {LOC BD21 IOSTANDARD LVCMOS33 PULLUP true} [get_ports qsfp1_modprsl]
set_property -dict {LOC BE21 IOSTANDARD LVCMOS33 PULLUP true} [get_ports qsfp1_intl]
set_property -dict {LOC BD20 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports qsfp1_lpmode]
set_property -dict {LOC BE22 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8 PULLUP true} [get_ports qsfp1_i2c_scl]
set_property -dict {LOC BF22 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8 PULLUP true} [get_ports qsfp1_i2c_sda]

# 322.265625 MHz MGT reference clock (from Si5338 B ch 0)
create_clock -period 3.103 -name qsfp1_mgt_refclk_b0 [get_ports qsfp1_mgt_refclk_b0_p]

# 322.265625 MHz MGT reference clock (from Si5338 B ch 1)
#create_clock -period 3.103 -name qsfp1_mgt_refclk_b1 [get_ports qsfp1_mgt_refclk_b1_p]

set_false_path -to [get_ports {qsfp1_resetl qsfp1_lpmode}]
set_output_delay 0 [get_ports {qsfp1_resetl qsfp1_lpmode}]
set_false_path -from [get_ports {qsfp1_modprsl qsfp1_intl}]
set_input_delay 0 [get_ports {qsfp1_modprsl qsfp1_intl}]

set_false_path -to [get_ports {qsfp1_i2c_scl qsfp1_i2c_sda}]
set_output_delay 0 [get_ports {qsfp1_i2c_scl qsfp1_i2c_sda}]
set_false_path -from [get_ports {qsfp1_i2c_scl qsfp1_i2c_sda}]
set_input_delay 0 [get_ports {qsfp1_i2c_scl qsfp1_i2c_sda}]

set_property -dict {LOC AA45} [get_ports {qsfp2_rx_p[0]}] ;# MGTHRXP0_129 GTYE4_CHANNEL_X0Y24 / GTYE4_COMMON_X0Y6
set_property -dict {LOC AA46} [get_ports {qsfp2_rx_n[0]}] ;# MGTHRXN0_129 GTYE4_CHANNEL_X0Y24 / GTYE4_COMMON_X0Y6
set_property -dict {LOC AA40} [get_ports {qsfp2_tx_p[0]}] ;# MGTHTXP0_129 GTYE4_CHANNEL_X0Y24 / GTYE4_COMMON_X0Y6
set_property -dict {LOC AA41} [get_ports {qsfp2_tx_n[0]}] ;# MGTHTXN0_129 GTYE4_CHANNEL_X0Y24 / GTYE4_COMMON_X0Y6
set_property -dict {LOC Y43 } [get_ports {qsfp2_rx_p[1]}] ;# MGTHRXP1_129 GTYE4_CHANNEL_X0Y25 / GTYE4_COMMON_X0Y6
set_property -dict {LOC Y44 } [get_ports {qsfp2_rx_n[1]}] ;# MGTHRXN1_129 GTYE4_CHANNEL_X0Y25 / GTYE4_COMMON_X0Y6
set_property -dict {LOC Y38 } [get_ports {qsfp2_tx_p[1]}] ;# MGTHTXP1_129 GTYE4_CHANNEL_X0Y25 / GTYE4_COMMON_X0Y6
set_property -dict {LOC Y39 } [get_ports {qsfp2_tx_n[1]}] ;# MGTHTXN1_129 GTYE4_CHANNEL_X0Y25 / GTYE4_COMMON_X0Y6
set_property -dict {LOC W45 } [get_ports {qsfp2_rx_p[2]}] ;# MGTHRXP2_129 GTYE4_CHANNEL_X0Y26 / GTYE4_COMMON_X0Y6
set_property -dict {LOC W46 } [get_ports {qsfp2_rx_n[2]}] ;# MGTHRXN2_129 GTYE4_CHANNEL_X0Y26 / GTYE4_COMMON_X0Y6
set_property -dict {LOC W40 } [get_ports {qsfp2_tx_p[2]}] ;# MGTHTXP2_129 GTYE4_CHANNEL_X0Y26 / GTYE4_COMMON_X0Y6
set_property -dict {LOC W41 } [get_ports {qsfp2_tx_n[2]}] ;# MGTHTXN2_129 GTYE4_CHANNEL_X0Y26 / GTYE4_COMMON_X0Y6
set_property -dict {LOC V43 } [get_ports {qsfp2_rx_p[3]}] ;# MGTHRXP3_129 GTYE4_CHANNEL_X0Y27 / GTYE4_COMMON_X0Y6
set_property -dict {LOC V44 } [get_ports {qsfp2_rx_n[3]}] ;# MGTHRXN3_129 GTYE4_CHANNEL_X0Y27 / GTYE4_COMMON_X0Y6
set_property -dict {LOC V38 } [get_ports {qsfp2_tx_p[3]}] ;# MGTHTXP3_129 GTYE4_CHANNEL_X0Y27 / GTYE4_COMMON_X0Y6
set_property -dict {LOC V39 } [get_ports {qsfp2_tx_n[3]}] ;# MGTHTXN3_129 GTYE4_CHANNEL_X0Y27 / GTYE4_COMMON_X0Y6
set_property -dict {LOC AC36} [get_ports qsfp2_mgt_refclk_b0_p] ;# MGTREFCLK0P_129 from Si5338 B ch 0
set_property -dict {LOC AC37} [get_ports qsfp2_mgt_refclk_b0_n] ;# MGTREFCLK0N_129 from Si5338 B ch 0
#set_property -dict {LOC AA36} [get_ports qsfp2_mgt_refclk_b2_p] ;# MGTREFCLK1P_129 from Si5338 B ch 2
#set_property -dict {LOC AA37} [get_ports qsfp2_mgt_refclk_b2_n] ;# MGTREFCLK1N_129 from Si5338 B ch 2
set_property -dict {LOC BB22 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports qsfp2_resetl]
set_property -dict {LOC BB20 IOSTANDARD LVCMOS33 PULLUP true} [get_ports qsfp2_modprsl]
set_property -dict {LOC BB21 IOSTANDARD LVCMOS33 PULLUP true} [get_ports qsfp2_intl]
set_property -dict {LOC BC21 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports qsfp2_lpmode]
set_property -dict {LOC BF20 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8 PULLUP true} [get_ports qsfp2_i2c_scl]
set_property -dict {LOC BA20 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8 PULLUP true} [get_ports qsfp2_i2c_sda]

# 322.265625 MHz MGT reference clock (from Si5338 B ch 0)
create_clock -period 3.103 -name qsfp2_mgt_refclk_b0 [get_ports qsfp2_mgt_refclk_b0_p]

# 322.265625 MHz MGT reference clock (from Si5338 B ch 2)
#create_clock -period 3.103 -name qsfp2_mgt_refclk_b2 [get_ports qsfp2_mgt_refclk_b2_p]

set_false_path -to [get_ports {qsfp2_resetl qsfp2_lpmode}]
set_output_delay 0 [get_ports {qsfp2_resetl qsfp2_lpmode}]
set_false_path -from [get_ports {qsfp2_modprsl qsfp2_intl}]
set_input_delay 0 [get_ports {qsfp2_modprsl qsfp2_intl}]

set_false_path -to [get_ports {qsfp2_i2c_scl qsfp2_i2c_sda}]
set_output_delay 0 [get_ports {qsfp2_i2c_scl qsfp2_i2c_sda}]
set_false_path -from [get_ports {qsfp2_i2c_scl qsfp2_i2c_sda}]
set_input_delay 0 [get_ports {qsfp2_i2c_scl qsfp2_i2c_sda}]

set_property -dict {LOC N45 } [get_ports {qsfp3_rx_p[0]}] ;# MGTHRXP0_131 GTYE4_CHANNEL_X0Y32 / GTYE4_COMMON_X0Y8
set_property -dict {LOC N46 } [get_ports {qsfp3_rx_n[0]}] ;# MGTHRXN0_131 GTYE4_CHANNEL_X0Y32 / GTYE4_COMMON_X0Y8
set_property -dict {LOC N40 } [get_ports {qsfp3_tx_p[0]}] ;# MGTHTXP0_131 GTYE4_CHANNEL_X0Y32 / GTYE4_COMMON_X0Y8
set_property -dict {LOC N41 } [get_ports {qsfp3_tx_n[0]}] ;# MGTHTXN0_131 GTYE4_CHANNEL_X0Y32 / GTYE4_COMMON_X0Y8
set_property -dict {LOC M43 } [get_ports {qsfp3_rx_p[1]}] ;# MGTHRXP1_131 GTYE4_CHANNEL_X0Y33 / GTYE4_COMMON_X0Y8
set_property -dict {LOC M44 } [get_ports {qsfp3_rx_n[1]}] ;# MGTHRXN1_131 GTYE4_CHANNEL_X0Y33 / GTYE4_COMMON_X0Y8
set_property -dict {LOC M38 } [get_ports {qsfp3_tx_p[1]}] ;# MGTHTXP1_131 GTYE4_CHANNEL_X0Y33 / GTYE4_COMMON_X0Y8
set_property -dict {LOC M39 } [get_ports {qsfp3_tx_n[1]}] ;# MGTHTXN1_131 GTYE4_CHANNEL_X0Y33 / GTYE4_COMMON_X0Y8
set_property -dict {LOC L45 } [get_ports {qsfp3_rx_p[2]}] ;# MGTHRXP2_131 GTYE4_CHANNEL_X0Y34 / GTYE4_COMMON_X0Y8
set_property -dict {LOC L46 } [get_ports {qsfp3_rx_n[2]}] ;# MGTHRXN2_131 GTYE4_CHANNEL_X0Y34 / GTYE4_COMMON_X0Y8
set_property -dict {LOC L40 } [get_ports {qsfp3_tx_p[2]}] ;# MGTHTXP2_131 GTYE4_CHANNEL_X0Y34 / GTYE4_COMMON_X0Y8
set_property -dict {LOC L41 } [get_ports {qsfp3_tx_n[2]}] ;# MGTHTXN2_131 GTYE4_CHANNEL_X0Y34 / GTYE4_COMMON_X0Y8
set_property -dict {LOC K43 } [get_ports {qsfp3_rx_p[3]}] ;# MGTHRXP3_131 GTYE4_CHANNEL_X0Y35 / GTYE4_COMMON_X0Y8
set_property -dict {LOC K44 } [get_ports {qsfp3_rx_n[3]}] ;# MGTHRXN3_131 GTYE4_CHANNEL_X0Y35 / GTYE4_COMMON_X0Y8
set_property -dict {LOC J40 } [get_ports {qsfp3_tx_p[3]}] ;# MGTHTXP3_131 GTYE4_CHANNEL_X0Y35 / GTYE4_COMMON_X0Y8
set_property -dict {LOC J41 } [get_ports {qsfp3_tx_n[3]}] ;# MGTHTXN3_131 GTYE4_CHANNEL_X0Y35 / GTYE4_COMMON_X0Y8
set_property -dict {LOC R36 } [get_ports qsfp3_mgt_refclk_b0_p] ;# MGTREFCLK0P_131 from Si5338 B ch 0
set_property -dict {LOC R37 } [get_ports qsfp3_mgt_refclk_b0_n] ;# MGTREFCLK0N_131 from Si5338 B ch 0
#set_property -dict {LOC N36 } [get_ports qsfp3_mgt_refclk_b3_p] ;# MGTREFCLK1P_131 from Si5338 B ch 3
#set_property -dict {LOC N37 } [get_ports qsfp3_mgt_refclk_b3_n] ;# MGTREFCLK1N_131 from Si5338 B ch 3
set_property -dict {LOC BC23 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports qsfp3_resetl]
set_property -dict {LOC BB24 IOSTANDARD LVCMOS33 PULLUP true} [get_ports qsfp3_modprsl]
set_property -dict {LOC AY22 IOSTANDARD LVCMOS33 PULLUP true} [get_ports qsfp3_intl]
set_property -dict {LOC BA22 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports qsfp3_lpmode]
set_property -dict {LOC BC22 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8 PULLUP true} [get_ports qsfp3_i2c_scl]
set_property -dict {LOC BA24 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8 PULLUP true} [get_ports qsfp3_i2c_sda]

# 322.265625 MHz MGT reference clock (from Si5338 B ch 0)
create_clock -period 3.103 -name qsfp3_mgt_refclk_b0 [get_ports qsfp3_mgt_refclk_b0_p]

# 322.265625 MHz MGT reference clock (from Si5338 B ch 2)
#create_clock -period 3.103 -name qsfp3_mgt_refclk_b3 [get_ports qsfp3_mgt_refclk_b3_p]

set_false_path -to [get_ports {qsfp3_resetl qsfp3_lpmode}]
set_output_delay 0 [get_ports {qsfp3_resetl qsfp3_lpmode}]
set_false_path -from [get_ports {qsfp3_modprsl qsfp3_intl}]
set_input_delay 0 [get_ports {qsfp3_modprsl qsfp3_intl}]

set_false_path -to [get_ports {qsfp3_i2c_scl qsfp3_i2c_sda}]
set_output_delay 0 [get_ports {qsfp3_i2c_scl qsfp3_i2c_sda}]
set_false_path -from [get_ports {qsfp3_i2c_scl qsfp3_i2c_sda}]
set_input_delay 0 [get_ports {qsfp3_i2c_scl qsfp3_i2c_sda}]

# PCIe Interface
set_property -dict {LOC AF2  } [get_ports {pcie_rx_p[0]}]  ;# MGTHRXP3_227 GTYE4_CHANNEL_X1Y35 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AF1  } [get_ports {pcie_rx_n[0]}]  ;# MGTHRXN3_227 GTYE4_CHANNEL_X1Y35 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AF7  } [get_ports {pcie_tx_p[0]}]  ;# MGTHTXP3_227 GTYE4_CHANNEL_X1Y35 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AF6  } [get_ports {pcie_tx_n[0]}]  ;# MGTHTXN3_227 GTYE4_CHANNEL_X1Y35 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AG4  } [get_ports {pcie_rx_p[1]}]  ;# MGTHRXP2_227 GTYE4_CHANNEL_X1Y34 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AG3  } [get_ports {pcie_rx_n[1]}]  ;# MGTHRXN2_227 GTYE4_CHANNEL_X1Y34 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AG9  } [get_ports {pcie_tx_p[1]}]  ;# MGTHTXP2_227 GTYE4_CHANNEL_X1Y34 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AG8  } [get_ports {pcie_tx_n[1]}]  ;# MGTHTXN2_227 GTYE4_CHANNEL_X1Y34 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AH2  } [get_ports {pcie_rx_p[2]}]  ;# MGTHRXP1_227 GTYE4_CHANNEL_X1Y33 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AH1  } [get_ports {pcie_rx_n[2]}]  ;# MGTHRXN1_227 GTYE4_CHANNEL_X1Y33 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AH7  } [get_ports {pcie_tx_p[2]}]  ;# MGTHTXP1_227 GTYE4_CHANNEL_X1Y33 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AH6  } [get_ports {pcie_tx_n[2]}]  ;# MGTHTXN1_227 GTYE4_CHANNEL_X1Y33 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AJ4  } [get_ports {pcie_rx_p[3]}]  ;# MGTHRXP0_227 GTYE4_CHANNEL_X1Y32 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AJ3  } [get_ports {pcie_rx_n[3]}]  ;# MGTHRXN0_227 GTYE4_CHANNEL_X1Y32 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AJ9  } [get_ports {pcie_tx_p[3]}]  ;# MGTHTXP0_227 GTYE4_CHANNEL_X1Y32 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AJ8  } [get_ports {pcie_tx_n[3]}]  ;# MGTHTXN0_227 GTYE4_CHANNEL_X1Y32 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AK2  } [get_ports {pcie_rx_p[4]}]  ;# MGTHRXP3_226 GTYE4_CHANNEL_X1Y31 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AK1  } [get_ports {pcie_rx_n[4]}]  ;# MGTHRXN3_226 GTYE4_CHANNEL_X1Y31 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AK7  } [get_ports {pcie_tx_p[4]}]  ;# MGTHTXP3_226 GTYE4_CHANNEL_X1Y31 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AK6  } [get_ports {pcie_tx_n[4]}]  ;# MGTHTXN3_226 GTYE4_CHANNEL_X1Y31 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AL4  } [get_ports {pcie_rx_p[5]}]  ;# MGTHRXP2_226 GTYE4_CHANNEL_X1Y30 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AL3  } [get_ports {pcie_rx_n[5]}]  ;# MGTHRXN2_226 GTYE4_CHANNEL_X1Y30 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AL9  } [get_ports {pcie_tx_p[5]}]  ;# MGTHTXP2_226 GTYE4_CHANNEL_X1Y30 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AL8  } [get_ports {pcie_tx_n[5]}]  ;# MGTHTXN2_226 GTYE4_CHANNEL_X1Y30 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AM2  } [get_ports {pcie_rx_p[6]}]  ;# MGTHRXP1_226 GTYE4_CHANNEL_X1Y29 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AM1  } [get_ports {pcie_rx_n[6]}]  ;# MGTHRXN1_226 GTYE4_CHANNEL_X1Y29 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AM7  } [get_ports {pcie_tx_p[6]}]  ;# MGTHTXP1_226 GTYE4_CHANNEL_X1Y29 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AM6  } [get_ports {pcie_tx_n[6]}]  ;# MGTHTXN1_226 GTYE4_CHANNEL_X1Y29 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AN4  } [get_ports {pcie_rx_p[7]}]  ;# MGTHRXP0_226 GTYE4_CHANNEL_X1Y28 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AN3  } [get_ports {pcie_rx_n[7]}]  ;# MGTHRXN0_226 GTYE4_CHANNEL_X1Y28 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AN9  } [get_ports {pcie_tx_p[7]}]  ;# MGTHTXP0_226 GTYE4_CHANNEL_X1Y28 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AN8  } [get_ports {pcie_tx_n[7]}]  ;# MGTHTXN0_226 GTYE4_CHANNEL_X1Y28 / GTYE4_COMMON_X1Y7
#set_property -dict {LOC AP2  } [get_ports {pcie_rx_p[8]}]  ;# MGTHRXP3_225 GTYE4_CHANNEL_X1Y27 / GTYE4_COMMON_X1Y6
#set_property -dict {LOC AP1  } [get_ports {pcie_rx_n[8]}]  ;# MGTHRXN3_225 GTYE4_CHANNEL_X1Y27 / GTYE4_COMMON_X1Y6
#set_property -dict {LOC AP7  } [get_ports {pcie_tx_p[8]}]  ;# MGTHTXP3_225 GTYE4_CHANNEL_X1Y27 / GTYE4_COMMON_X1Y6
#set_property -dict {LOC AP6  } [get_ports {pcie_tx_n[8]}]  ;# MGTHTXN3_225 GTYE4_CHANNEL_X1Y27 / GTYE4_COMMON_X1Y6
#set_property -dict {LOC AR4  } [get_ports {pcie_rx_p[9]}]  ;# MGTHRXP2_225 GTYE4_CHANNEL_X1Y26 / GTYE4_COMMON_X1Y6
#set_property -dict {LOC AR3  } [get_ports {pcie_rx_n[9]}]  ;# MGTHRXN2_225 GTYE4_CHANNEL_X1Y26 / GTYE4_COMMON_X1Y6
#set_property -dict {LOC AR9  } [get_ports {pcie_tx_p[9]}]  ;# MGTHTXP2_225 GTYE4_CHANNEL_X1Y26 / GTYE4_COMMON_X1Y6
#set_property -dict {LOC AR8  } [get_ports {pcie_tx_n[9]}]  ;# MGTHTXN2_225 GTYE4_CHANNEL_X1Y26 / GTYE4_COMMON_X1Y6
#set_property -dict {LOC AT2  } [get_ports {pcie_rx_p[10]}] ;# MGTHRXP1_225 GTYE4_CHANNEL_X1Y25 / GTYE4_COMMON_X1Y6
#set_property -dict {LOC AT1  } [get_ports {pcie_rx_n[10]}] ;# MGTHRXN1_225 GTYE4_CHANNEL_X1Y25 / GTYE4_COMMON_X1Y6
#set_property -dict {LOC AT7  } [get_ports {pcie_tx_p[10]}] ;# MGTHTXP1_225 GTYE4_CHANNEL_X1Y25 / GTYE4_COMMON_X1Y6
#set_property -dict {LOC AT6  } [get_ports {pcie_tx_n[10]}] ;# MGTHTXN1_225 GTYE4_CHANNEL_X1Y25 / GTYE4_COMMON_X1Y6
#set_property -dict {LOC AU4  } [get_ports {pcie_rx_p[11]}] ;# MGTHRXP0_225 GTYE4_CHANNEL_X1Y24 / GTYE4_COMMON_X1Y6
#set_property -dict {LOC AU3  } [get_ports {pcie_rx_n[11]}] ;# MGTHRXN0_225 GTYE4_CHANNEL_X1Y24 / GTYE4_COMMON_X1Y6
#set_property -dict {LOC AU9  } [get_ports {pcie_tx_p[11]}] ;# MGTHTXP0_225 GTYE4_CHANNEL_X1Y24 / GTYE4_COMMON_X1Y6
#set_property -dict {LOC AU8  } [get_ports {pcie_tx_n[11]}] ;# MGTHTXN0_225 GTYE4_CHANNEL_X1Y24 / GTYE4_COMMON_X1Y6
#set_property -dict {LOC AV2  } [get_ports {pcie_rx_p[12]}] ;# MGTHRXP3_224 GTYE4_CHANNEL_X1Y23 / GTYE4_COMMON_X1Y5
#set_property -dict {LOC AV1  } [get_ports {pcie_rx_n[12]}] ;# MGTHRXN3_224 GTYE4_CHANNEL_X1Y23 / GTYE4_COMMON_X1Y5
#set_property -dict {LOC AV7  } [get_ports {pcie_tx_p[12]}] ;# MGTHTXP3_224 GTYE4_CHANNEL_X1Y23 / GTYE4_COMMON_X1Y5
#set_property -dict {LOC AV6  } [get_ports {pcie_tx_n[12]}] ;# MGTHTXN3_224 GTYE4_CHANNEL_X1Y23 / GTYE4_COMMON_X1Y5
#set_property -dict {LOC AW4  } [get_ports {pcie_rx_p[13]}] ;# MGTHRXP2_224 GTYE4_CHANNEL_X1Y22 / GTYE4_COMMON_X1Y5
#set_property -dict {LOC AW3  } [get_ports {pcie_rx_n[13]}] ;# MGTHRXN2_224 GTYE4_CHANNEL_X1Y22 / GTYE4_COMMON_X1Y5
#set_property -dict {LOC BB5  } [get_ports {pcie_tx_p[13]}] ;# MGTHTXP2_224 GTYE4_CHANNEL_X1Y22 / GTYE4_COMMON_X1Y5
#set_property -dict {LOC BB4  } [get_ports {pcie_tx_n[13]}] ;# MGTHTXN2_224 GTYE4_CHANNEL_X1Y22 / GTYE4_COMMON_X1Y5
#set_property -dict {LOC BA2  } [get_ports {pcie_rx_p[14]}] ;# MGTHRXP1_224 GTYE4_CHANNEL_X1Y21 / GTYE4_COMMON_X1Y5
#set_property -dict {LOC BA1  } [get_ports {pcie_rx_n[14]}] ;# MGTHRXN1_224 GTYE4_CHANNEL_X1Y21 / GTYE4_COMMON_X1Y5
#set_property -dict {LOC BD5  } [get_ports {pcie_tx_p[14]}] ;# MGTHTXP1_224 GTYE4_CHANNEL_X1Y21 / GTYE4_COMMON_X1Y5
#set_property -dict {LOC BD4  } [get_ports {pcie_tx_n[14]}] ;# MGTHTXN1_224 GTYE4_CHANNEL_X1Y21 / GTYE4_COMMON_X1Y5
#set_property -dict {LOC BC2  } [get_ports {pcie_rx_p[15]}] ;# MGTHRXP0_224 GTYE4_CHANNEL_X1Y20 / GTYE4_COMMON_X1Y5
#set_property -dict {LOC BC1  } [get_ports {pcie_rx_n[15]}] ;# MGTHRXN0_224 GTYE4_CHANNEL_X1Y20 / GTYE4_COMMON_X1Y5
#set_property -dict {LOC BF5  } [get_ports {pcie_tx_p[15]}] ;# MGTHTXP0_224 GTYE4_CHANNEL_X1Y20 / GTYE4_COMMON_X1Y5
#set_property -dict {LOC BF4  } [get_ports {pcie_tx_n[15]}] ;# MGTHTXN0_224 GTYE4_CHANNEL_X1Y20 / GTYE4_COMMON_X1Y5
set_property -dict {LOC AT11 } [get_ports pcie_refclk_0_p] ;# MGTREFCLK0P_225
set_property -dict {LOC AT10 } [get_ports pcie_refclk_0_n] ;# MGTREFCLK0N_225
#set_property -dict {LOC AM11 } [get_ports pcie_refclk_b1_p] ;# MGTREFCLK0P_226 from Si5338 B ch 1
#set_property -dict {LOC AM10 } [get_ports pcie_refclk_b1_n] ;# MGTREFCLK0N_226 from Si5338 B ch 1
#set_property -dict {LOC AH11 } [get_ports pcie_refclk_1_p] ;# MGTREFCLK0P_227
#set_property -dict {LOC AH10 } [get_ports pcie_refclk_1_n] ;# MGTREFCLK0N_227
set_property -dict {LOC AR26 IOSTANDARD LVCMOS12 PULLUP true} [get_ports pcie_reset_n]

# 100 MHz MGT reference clock
create_clock -period 10 -name pcie_mgt_refclk_0 [get_ports pcie_refclk_0_p]
#create_clock -period 10 -name pcie_mgt_refclk_b1 [get_ports pcie_refclk_b1_p]
#create_clock -period 10 -name pcie_mgt_refclk_1 [get_ports pcie_refclk_1_p]

set_false_path -from [get_ports {pcie_reset_n}]
set_input_delay 0 [get_ports {pcie_reset_n}]

# DDR4 A (U5, U6, U7, U8, U9, U32, U33, U34, U35)
# 9x MT40A512M8RH-083E
set_property -dict {LOC AY33 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[0]}]
set_property -dict {LOC BA33 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[1]}]
set_property -dict {LOC AV34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[2]}]
set_property -dict {LOC AW34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[3]}]
set_property -dict {LOC AV33 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[4]}]
set_property -dict {LOC AW33 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[5]}]
set_property -dict {LOC AU34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[6]}]
set_property -dict {LOC AT33 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[7]}]
set_property -dict {LOC AT34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[8]}]
set_property -dict {LOC AP33 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[9]}]
set_property -dict {LOC AR33 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[10]}]
set_property -dict {LOC AN34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[11]}]
set_property -dict {LOC AP34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[12]}]
set_property -dict {LOC AL32 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[13]}]
set_property -dict {LOC AM32 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[14]}]
set_property -dict {LOC AL34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[15]}]
set_property -dict {LOC AM34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[16]}]
set_property -dict {LOC BA34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_ba[0]}]
set_property -dict {LOC BB34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_ba[1]}]
set_property -dict {LOC AY35 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_bg[0]}]
set_property -dict {LOC AY36 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_bg[1]}]
set_property -dict {LOC AW35 IOSTANDARD DIFF_SSTL12_DCI } [get_ports {ddr4_a_ck_t[0]}]
set_property -dict {LOC AW36 IOSTANDARD DIFF_SSTL12_DCI } [get_ports {ddr4_a_ck_c[0]}]
set_property -dict {LOC BE36 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_cke[0]}]
set_property -dict {LOC BE35 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_cs_n[0]}]
set_property -dict {LOC BF35 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_act_n}]
set_property -dict {LOC BC37 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_odt[0]}]
set_property -dict {LOC BB35 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_par}]
set_property -dict {LOC BC34 IOSTANDARD LVCMOS12 DRIVE 8} [get_ports {ddr4_a_reset_n}]

set_property -dict {LOC W34  IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[0]}]
set_property -dict {LOC W33  IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[1]}]
set_property -dict {LOC Y33  IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[2]}]
set_property -dict {LOC Y32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[3]}]
set_property -dict {LOC Y30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[4]}]
set_property -dict {LOC W30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[5]}]
set_property -dict {LOC AB34 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[6]}]
set_property -dict {LOC AA34 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[7]}]
set_property -dict {LOC AD34 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[8]}]
set_property -dict {LOC AC34 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[9]}]
set_property -dict {LOC AC33 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[10]}]
set_property -dict {LOC AC32 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[11]}]
set_property -dict {LOC AF30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[12]}]
set_property -dict {LOC AE30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[13]}]
set_property -dict {LOC AE33 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[14]}]
set_property -dict {LOC AD33 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[15]}]
set_property -dict {LOC AF33 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[16]}]
set_property -dict {LOC AF32 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[17]}]
set_property -dict {LOC AG32 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[18]}]
set_property -dict {LOC AG31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[19]}]
set_property -dict {LOC AG34 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[20]}]
set_property -dict {LOC AF34 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[21]}]
set_property -dict {LOC AJ33 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[22]}]
set_property -dict {LOC AH33 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[23]}]
set_property -dict {LOC AK31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[24]}]
set_property -dict {LOC AJ31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[25]}]
set_property -dict {LOC AG30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[26]}]
set_property -dict {LOC AG29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[27]}]
set_property -dict {LOC AJ30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[28]}]
set_property -dict {LOC AJ29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[29]}]
set_property -dict {LOC AK28 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[30]}]
set_property -dict {LOC AJ28 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[31]}]
set_property -dict {LOC AL30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[32]}]
set_property -dict {LOC AL29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[33]}]
set_property -dict {LOC AN31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[34]}]
set_property -dict {LOC AM31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[35]}]
set_property -dict {LOC AP29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[36]}]
set_property -dict {LOC AN29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[37]}]
set_property -dict {LOC AR30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[38]}]
set_property -dict {LOC AP30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[39]}]
set_property -dict {LOC AT30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[40]}]
set_property -dict {LOC AT29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[41]}]
set_property -dict {LOC AU31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[42]}]
set_property -dict {LOC AU30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[43]}]
set_property -dict {LOC AV32 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[44]}]
set_property -dict {LOC AU32 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[45]}]
set_property -dict {LOC AW31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[46]}]
set_property -dict {LOC AV31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[47]}]
set_property -dict {LOC AY32 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[48]}]
set_property -dict {LOC AY31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[49]}]
set_property -dict {LOC BA30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[50]}]
set_property -dict {LOC AY30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[51]}]
set_property -dict {LOC BB29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[52]}]
set_property -dict {LOC BA29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[53]}]
set_property -dict {LOC BB31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[54]}]
set_property -dict {LOC BB30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[55]}]
set_property -dict {LOC BD29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[56]}]
set_property -dict {LOC BC29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[57]}]
set_property -dict {LOC BE33 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[58]}]
set_property -dict {LOC BD33 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[59]}]
set_property -dict {LOC BF30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[60]}]
set_property -dict {LOC BE30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[61]}]
set_property -dict {LOC BE32 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[62]}]
set_property -dict {LOC BE31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[63]}]
set_property -dict {LOC BC38 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[64]}]
set_property -dict {LOC BB38 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[65]}]
set_property -dict {LOC BD39 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[66]}]
set_property -dict {LOC BC39 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[67]}]
set_property -dict {LOC BF37 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[68]}]
set_property -dict {LOC BE37 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[69]}]
set_property -dict {LOC BF38 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[70]}]
set_property -dict {LOC BE38 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[71]}]
set_property -dict {LOC W31  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_a_dqs_t[0]}]
set_property -dict {LOC Y31  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_a_dqs_c[0]}]
set_property -dict {LOC AC31 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_a_dqs_t[1]}]
set_property -dict {LOC AD31 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_a_dqs_c[1]}]
set_property -dict {LOC AH31 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_a_dqs_t[2]}]
set_property -dict {LOC AH32 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_a_dqs_c[2]}]
set_property -dict {LOC AH28 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_a_dqs_t[3]}]
set_property -dict {LOC AH29 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_a_dqs_c[3]}]
set_property -dict {LOC AM29 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_a_dqs_t[4]}]
set_property -dict {LOC AM30 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_a_dqs_c[4]}]
set_property -dict {LOC AU29 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_a_dqs_t[5]}]
set_property -dict {LOC AV29 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_a_dqs_c[5]}]
set_property -dict {LOC BA32 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_a_dqs_t[6]}]
set_property -dict {LOC BB32 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_a_dqs_c[6]}]
set_property -dict {LOC BD30 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_a_dqs_t[7]}]
set_property -dict {LOC BD31 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_a_dqs_c[7]}]
set_property -dict {LOC BD40 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_a_dqs_t[8]}]
set_property -dict {LOC BE40 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_a_dqs_c[8]}]
set_property -dict {LOC AA32 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dm_dbi_n[0]}]
set_property -dict {LOC AE31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dm_dbi_n[1]}]
set_property -dict {LOC AH34 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dm_dbi_n[2]}]
set_property -dict {LOC AJ27 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dm_dbi_n[3]}]
set_property -dict {LOC AP31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dm_dbi_n[4]}]
set_property -dict {LOC AW29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dm_dbi_n[5]}]
set_property -dict {LOC BC31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dm_dbi_n[6]}]
set_property -dict {LOC BF32 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dm_dbi_n[7]}]
set_property -dict {LOC BF39 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dm_dbi_n[8]}]

# DDR4 B (U22, U23, U24, U25, U26, U79, U80, U81, U82)
# 9x MT40A512M8RH-083E
set_property -dict {LOC A37  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[0]}]
set_property -dict {LOC A38  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[1]}]
set_property -dict {LOC B35  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[2]}]
set_property -dict {LOC A35  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[3]}]
set_property -dict {LOC E35  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[4]}]
set_property -dict {LOC D35  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[5]}]
set_property -dict {LOC E37  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[6]}]
set_property -dict {LOC B34  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[7]}]
set_property -dict {LOC A34  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[8]}]
set_property -dict {LOC D34  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[9]}]
set_property -dict {LOC C34  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[10]}]
set_property -dict {LOC D33  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[11]}]
set_property -dict {LOC C33  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[12]}]
set_property -dict {LOC C32  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[13]}]
set_property -dict {LOC B32  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[14]}]
set_property -dict {LOC D31  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[15]}]
set_property -dict {LOC C31  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[16]}]
set_property -dict {LOC C36  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_ba[0]}]
set_property -dict {LOC C37  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_ba[1]}]
set_property -dict {LOC E36  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_bg[0]}]
set_property -dict {LOC D36  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_bg[1]}]
set_property -dict {LOC B36  IOSTANDARD DIFF_SSTL12_DCI } [get_ports {ddr4_b_ck_t[0]}]
set_property -dict {LOC B37  IOSTANDARD DIFF_SSTL12_DCI } [get_ports {ddr4_b_ck_c[0]}]
set_property -dict {LOC A40  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_cke[0]}]
set_property -dict {LOC D39  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_cs_n[0]}]
set_property -dict {LOC F38  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_act_n}]
set_property -dict {LOC A39  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_odt[0]}]
set_property -dict {LOC C39  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_par}]
set_property -dict {LOC E40  IOSTANDARD LVCMOS12 DRIVE 8} [get_ports {ddr4_b_reset_n}]

set_property -dict {LOC E33  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[0]}]
set_property -dict {LOC F33  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[1]}]
set_property -dict {LOC E32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[2]}]
set_property -dict {LOC F32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[3]}]
set_property -dict {LOC G32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[4]}]
set_property -dict {LOC H32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[5]}]
set_property -dict {LOC G31  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[6]}]
set_property -dict {LOC H31  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[7]}]
set_property -dict {LOC K33  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[8]}]
set_property -dict {LOC L33  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[9]}]
set_property -dict {LOC J31  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[10]}]
set_property -dict {LOC K31  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[11]}]
set_property -dict {LOC L30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[12]}]
set_property -dict {LOC M30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[13]}]
set_property -dict {LOC K32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[14]}]
set_property -dict {LOC L32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[15]}]
set_property -dict {LOC N33  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[16]}]
set_property -dict {LOC N32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[17]}]
set_property -dict {LOC N31  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[18]}]
set_property -dict {LOC P31  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[19]}]
set_property -dict {LOC N34  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[20]}]
set_property -dict {LOC P34  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[21]}]
set_property -dict {LOC R32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[22]}]
set_property -dict {LOC R31  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[23]}]
set_property -dict {LOC T30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[24]}]
set_property -dict {LOC U30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[25]}]
set_property -dict {LOC U31  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[26]}]
set_property -dict {LOC V31  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[27]}]
set_property -dict {LOC T32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[28]}]
set_property -dict {LOC U32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[29]}]
set_property -dict {LOC R33  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[30]}]
set_property -dict {LOC T33  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[31]}]
set_property -dict {LOC A30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[32]}]
set_property -dict {LOC B30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[33]}]
set_property -dict {LOC A29  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[34]}]
set_property -dict {LOC B29  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[35]}]
set_property -dict {LOC D30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[36]}]
set_property -dict {LOC E30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[37]}]
set_property -dict {LOC C29  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[38]}]
set_property -dict {LOC D29  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[39]}]
set_property -dict {LOC D28  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[40]}]
set_property -dict {LOC E28  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[41]}]
set_property -dict {LOC E27  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[42]}]
set_property -dict {LOC F27  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[43]}]
set_property -dict {LOC G29  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[44]}]
set_property -dict {LOC H29  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[45]}]
set_property -dict {LOC G27  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[46]}]
set_property -dict {LOC G26  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[47]}]
set_property -dict {LOC J29  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[48]}]
set_property -dict {LOC J28  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[49]}]
set_property -dict {LOC H28  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[50]}]
set_property -dict {LOC H27  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[51]}]
set_property -dict {LOC L27  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[52]}]
set_property -dict {LOC M27  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[53]}]
set_property -dict {LOC K28  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[54]}]
set_property -dict {LOC L28  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[55]}]
set_property -dict {LOC N26  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[56]}]
set_property -dict {LOC P26  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[57]}]
set_property -dict {LOC N28  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[58]}]
set_property -dict {LOC P28  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[59]}]
set_property -dict {LOC R26  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[60]}]
set_property -dict {LOC T26  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[61]}]
set_property -dict {LOC R27  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[62]}]
set_property -dict {LOC T27  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[63]}]
set_property -dict {LOC F35  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[64]}]
set_property -dict {LOC F34  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[65]}]
set_property -dict {LOC G34  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[66]}]
set_property -dict {LOC H34  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[67]}]
set_property -dict {LOC J36  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[68]}]
set_property -dict {LOC J35  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[69]}]
set_property -dict {LOC F37  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[70]}]
set_property -dict {LOC G37  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[71]}]
set_property -dict {LOC J33  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_t[0]}]
set_property -dict {LOC H33  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_c[0]}]
set_property -dict {LOC K30  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_t[1]}]
set_property -dict {LOC J30  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_c[1]}]
set_property -dict {LOC M34  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_t[2]}]
set_property -dict {LOC L34  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_c[2]}]
set_property -dict {LOC V32  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_t[3]}]
set_property -dict {LOC V33  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_c[3]}]
set_property -dict {LOC A27  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_t[4]}]
set_property -dict {LOC A28  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_c[4]}]
set_property -dict {LOC F28  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_t[5]}]
set_property -dict {LOC F29  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_c[5]}]
set_property -dict {LOC K26  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_t[6]}]
set_property -dict {LOC K27  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_c[6]}]
set_property -dict {LOC P29  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_t[7]}]
set_property -dict {LOC N29  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_c[7]}]
set_property -dict {LOC H36  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_t[8]}]
set_property -dict {LOC G36  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_c[8]}]
set_property -dict {LOC G30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dm_dbi_n[0]}]
set_property -dict {LOC M31  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dm_dbi_n[1]}]
set_property -dict {LOC R30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dm_dbi_n[2]}]
set_property -dict {LOC U34  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dm_dbi_n[3]}]
set_property -dict {LOC C27  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dm_dbi_n[4]}]
set_property -dict {LOC J26  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dm_dbi_n[5]}]
set_property -dict {LOC M29  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dm_dbi_n[6]}]
set_property -dict {LOC T28  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dm_dbi_n[7]}]
set_property -dict {LOC H37  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dm_dbi_n[8]}]

# DDR4 SODIMM 1
set_property -dict {LOC AT18 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_adr[0]}]
set_property -dict {LOC AU17 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_adr[1]}]
set_property -dict {LOC AP18 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_adr[2]}]
set_property -dict {LOC AR18 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_adr[3]}]
set_property -dict {LOC AP20 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_adr[4]}]
set_property -dict {LOC AR20 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_adr[5]}]
set_property -dict {LOC AU21 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_adr[6]}]
set_property -dict {LOC AN18 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_adr[7]}]
set_property -dict {LOC AN17 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_adr[8]}]
set_property -dict {LOC AN19 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_adr[9]}]
set_property -dict {LOC AP19 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_adr[10]}]
set_property -dict {LOC AM16 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_adr[11]}]
set_property -dict {LOC AN16 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_adr[12]}]
set_property -dict {LOC AL19 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_adr[13]}]
set_property -dict {LOC AM19 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_adr[14]}]
set_property -dict {LOC AL20 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_adr[15]}]
set_property -dict {LOC AM20 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_adr[16]}]
set_property -dict {LOC AT19 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_ba[0]}]
set_property -dict {LOC AU19 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_ba[1]}]
set_property -dict {LOC AT20 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_bg[0]}]
set_property -dict {LOC AU20 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_bg[1]}]
set_property -dict {LOC AR17 IOSTANDARD DIFF_SSTL12_DCI } [get_ports {ddr4_sodimm1_ck_t[0]}]
set_property -dict {LOC AT17 IOSTANDARD DIFF_SSTL12_DCI } [get_ports {ddr4_sodimm1_ck_c[0]}]
#set_property -dict {LOC AM17 IOSTANDARD DIFF_SSTL12_DCI } [get_ports {ddr4_sodimm1_ck_t[1]}]
#set_property -dict {LOC AL17 IOSTANDARD DIFF_SSTL12_DCI } [get_ports {ddr4_sodimm1_ck_c[1]}]
set_property -dict {LOC AY20 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_cke[0]}]
#set_property -dict {LOC AV21 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_cke[1]}]
set_property -dict {LOC BA18 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_cs_n[0]}]
#set_property -dict {LOC AW20 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_cs_n[1]}]
#set_property -dict {LOC AP16 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_cs_n[2]}]
#set_property -dict {LOC AY17 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_cs_n[3]}]
set_property -dict {LOC AV17 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_act_n}]
set_property -dict {LOC AW21 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_odt[0]}]
#set_property -dict {LOC AV19 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_odt[1]}]
set_property -dict {LOC AW19 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm1_par}]
set_property -dict {LOC BA17 IOSTANDARD LVCMOS12 DRIVE 8} [get_ports {ddr4_sodimm1_reset_n}]
set_property -dict {LOC AY18 IOSTANDARD LVCMOS12        } [get_ports {ddr4_sodimm1_alert_n}]

set_property -dict {LOC AM14 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[0]}]
set_property -dict {LOC AL14 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[1]}]
set_property -dict {LOC AM15 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[2]}]
set_property -dict {LOC AL15 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[3]}]
set_property -dict {LOC AN13 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[4]}]
set_property -dict {LOC AN14 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[5]}]
set_property -dict {LOC AP14 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[6]}]
set_property -dict {LOC AP15 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[7]}]
set_property -dict {LOC AV16 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[8]}]
set_property -dict {LOC AU16 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[9]}]
set_property -dict {LOC AU15 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[10]}]
set_property -dict {LOC AT15 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[11]}]
set_property -dict {LOC AV13 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[12]}]
set_property -dict {LOC AU13 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[13]}]
set_property -dict {LOC AW15 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[14]}]
set_property -dict {LOC AW16 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[15]}]
set_property -dict {LOC BA13 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[16]}]
set_property -dict {LOC AY13 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[17]}]
set_property -dict {LOC BA14 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[18]}]
set_property -dict {LOC BA15 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[19]}]
set_property -dict {LOC AY15 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[20]}]
set_property -dict {LOC AY16 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[21]}]
set_property -dict {LOC AY11 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[22]}]
set_property -dict {LOC AY12 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[23]}]
set_property -dict {LOC BC13 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[24]}]
set_property -dict {LOC BC14 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[25]}]
set_property -dict {LOC BD14 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[26]}]
set_property -dict {LOC BD15 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[27]}]
set_property -dict {LOC BE16 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[28]}]
set_property -dict {LOC BD16 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[29]}]
set_property -dict {LOC BF15 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[30]}]
set_property -dict {LOC BE15 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[31]}]
set_property -dict {LOC AL28 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[32]}]
set_property -dict {LOC AL27 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[33]}]
set_property -dict {LOC AN27 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[34]}]
set_property -dict {LOC AM27 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[35]}]
set_property -dict {LOC AM25 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[36]}]
set_property -dict {LOC AL25 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[37]}]
set_property -dict {LOC AP28 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[38]}]
set_property -dict {LOC AN28 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[39]}]
set_property -dict {LOC AT28 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[40]}]
set_property -dict {LOC AR28 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[41]}]
set_property -dict {LOC AT27 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[42]}]
set_property -dict {LOC AR27 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[43]}]
set_property -dict {LOC AU27 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[44]}]
set_property -dict {LOC AU26 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[45]}]
set_property -dict {LOC AV28 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[46]}]
set_property -dict {LOC AV27 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[47]}]
set_property -dict {LOC AY28 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[48]}]
set_property -dict {LOC AW28 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[49]}]
set_property -dict {LOC AY27 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[50]}]
set_property -dict {LOC AY26 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[51]}]
set_property -dict {LOC BA28 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[52]}]
set_property -dict {LOC BA27 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[53]}]
set_property -dict {LOC BB27 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[54]}]
set_property -dict {LOC BB26 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[55]}]
set_property -dict {LOC BC27 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[56]}]
set_property -dict {LOC BC26 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[57]}]
set_property -dict {LOC BF25 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[58]}]
set_property -dict {LOC BE25 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[59]}]
set_property -dict {LOC BE28 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[60]}]
set_property -dict {LOC BD28 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[61]}]
set_property -dict {LOC BF27 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[62]}]
set_property -dict {LOC BE27 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[63]}]
#set_property -dict {LOC BC18 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[64]}]
#set_property -dict {LOC BB19 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[65]}]
#set_property -dict {LOC BC17 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[66]}]
#set_property -dict {LOC BB17 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[67]}]
#set_property -dict {LOC BE18 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[68]}]
#set_property -dict {LOC BD18 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[69]}]
#set_property -dict {LOC BF18 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[70]}]
#set_property -dict {LOC BF19 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dq[71]}]
set_property -dict {LOC AP13 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm1_dqs_t[0]}]
set_property -dict {LOC AR13 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm1_dqs_c[0]}]
set_property -dict {LOC AU14 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm1_dqs_t[1]}]
set_property -dict {LOC AV14 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm1_dqs_c[1]}]
set_property -dict {LOC BB15 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm1_dqs_t[2]}]
set_property -dict {LOC BB14 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm1_dqs_c[2]}]
set_property -dict {LOC BD13 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm1_dqs_t[3]}]
set_property -dict {LOC BE13 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm1_dqs_c[3]}]
set_property -dict {LOC AM26 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm1_dqs_t[4]}]
set_property -dict {LOC AN26 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm1_dqs_c[4]}]
set_property -dict {LOC AR25 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm1_dqs_t[5]}]
set_property -dict {LOC AT25 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm1_dqs_c[5]}]
set_property -dict {LOC AW25 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm1_dqs_t[6]}]
set_property -dict {LOC AY25 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm1_dqs_c[6]}]
set_property -dict {LOC BD26 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm1_dqs_t[7]}]
set_property -dict {LOC BE26 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm1_dqs_c[7]}]
#set_property -dict {LOC BC19 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm1_dqs_t[8]}]
#set_property -dict {LOC BD19 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm1_dqs_c[8]}]
set_property -dict {LOC AR16 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dm_dbi_n[0]}]
set_property -dict {LOC AW14 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dm_dbi_n[1]}]
set_property -dict {LOC BA12 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dm_dbi_n[2]}]
set_property -dict {LOC BF14 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dm_dbi_n[3]}]
set_property -dict {LOC AP25 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dm_dbi_n[4]}]
set_property -dict {LOC AV26 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dm_dbi_n[5]}]
set_property -dict {LOC BA25 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dm_dbi_n[6]}]
set_property -dict {LOC BF28 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dm_dbi_n[7]}]
#set_property -dict {LOC BE17 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm1_dm_dbi_n[8]}]

# DDR4 SODIMM 2 (J10)
set_property -dict {LOC F20  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_adr[0]}]
set_property -dict {LOC F19  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_adr[1]}]
set_property -dict {LOC E21  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_adr[2]}]
set_property -dict {LOC E20  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_adr[3]}]
set_property -dict {LOC F18  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_adr[4]}]
set_property -dict {LOC F17  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_adr[5]}]
set_property -dict {LOC G21  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_adr[6]}]
set_property -dict {LOC D19  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_adr[7]}]
set_property -dict {LOC C19  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_adr[8]}]
set_property -dict {LOC D21  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_adr[9]}]
set_property -dict {LOC D20  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_adr[10]}]
set_property -dict {LOC C21  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_adr[11]}]
set_property -dict {LOC B21  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_adr[12]}]
set_property -dict {LOC B19  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_adr[13]}]
set_property -dict {LOC A19  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_adr[14]}]
set_property -dict {LOC B20  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_adr[15]}]
set_property -dict {LOC A20  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_adr[16]}]
set_property -dict {LOC H19  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_ba[0]}]
set_property -dict {LOC H18  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_ba[1]}]
set_property -dict {LOC G20  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_bg[0]}]
set_property -dict {LOC G19  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_bg[1]}]
set_property -dict {LOC E18  IOSTANDARD DIFF_SSTL12_DCI } [get_ports {ddr4_sodimm2_ck_t[0]}]
set_property -dict {LOC E17  IOSTANDARD DIFF_SSTL12_DCI } [get_ports {ddr4_sodimm2_ck_c[0]}]
#set_property -dict {LOC C18  IOSTANDARD DIFF_SSTL12_DCI } [get_ports {ddr4_sodimm2_ck_t[1]}]
#set_property -dict {LOC D18  IOSTANDARD DIFF_SSTL12_DCI } [get_ports {ddr4_sodimm2_ck_c[1]}]
set_property -dict {LOC K20  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_cke[0]}]
#set_property -dict {LOC J21  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_cke[1]}]
set_property -dict {LOC L18  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_cs_n[0]}]
#set_property -dict {LOC L20  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_cs_n[1]}]
#set_property -dict {LOC A18  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_cs_n[2]}]
#set_property -dict {LOC L17  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_cs_n[3]}]
set_property -dict {LOC K21  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_act_n}]
set_property -dict {LOC H21  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_odt[0]}]
#set_property -dict {LOC J20  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_odt[1]}]
set_property -dict {LOC J19  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm2_par}]
set_property -dict {LOC K17  IOSTANDARD LVCMOS12 DRIVE 8} [get_ports {ddr4_sodimm2_reset_n}]
set_property -dict {LOC L19  IOSTANDARD LVCMOS12        } [get_ports {ddr4_sodimm2_alert_n}]

set_property -dict {LOC A25  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[0]}]
set_property -dict {LOC B25  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[1]}]
set_property -dict {LOC A24  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[2]}]
set_property -dict {LOC B24  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[3]}]
set_property -dict {LOC B26  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[4]}]
set_property -dict {LOC C26  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[5]}]
set_property -dict {LOC C23  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[6]}]
set_property -dict {LOC C24  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[7]}]
set_property -dict {LOC D25  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[8]}]
set_property -dict {LOC E25  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[9]}]
set_property -dict {LOC D23  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[10]}]
set_property -dict {LOC D24  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[11]}]
set_property -dict {LOC F22  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[12]}]
set_property -dict {LOC G22  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[13]}]
set_property -dict {LOC F23  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[14]}]
set_property -dict {LOC F24  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[15]}]
set_property -dict {LOC H24  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[16]}]
set_property -dict {LOC J24  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[17]}]
set_property -dict {LOC H23  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[18]}]
set_property -dict {LOC J23  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[19]}]
set_property -dict {LOC K23  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[20]}]
set_property -dict {LOC L23  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[21]}]
set_property -dict {LOC K22  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[22]}]
set_property -dict {LOC L22  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[23]}]
set_property -dict {LOC P25  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[24]}]
set_property -dict {LOC R25  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[25]}]
set_property -dict {LOC M24  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[26]}]
set_property -dict {LOC M25  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[27]}]
set_property -dict {LOC N23  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[28]}]
set_property -dict {LOC P23  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[29]}]
set_property -dict {LOC M22  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[30]}]
set_property -dict {LOC N22  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[31]}]
set_property -dict {LOC A17  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[32]}]
set_property -dict {LOC B17  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[33]}]
set_property -dict {LOC B16  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[34]}]
set_property -dict {LOC C16  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[35]}]
set_property -dict {LOC A13  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[36]}]
set_property -dict {LOC A14  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[37]}]
set_property -dict {LOC B14  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[38]}]
set_property -dict {LOC C14  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[39]}]
set_property -dict {LOC D16  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[40]}]
set_property -dict {LOC E16  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[41]}]
set_property -dict {LOC D15  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[42]}]
set_property -dict {LOC E15  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[43]}]
set_property -dict {LOC E13  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[44]}]
set_property -dict {LOC F13  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[45]}]
set_property -dict {LOC F15  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[46]}]
set_property -dict {LOC G15  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[47]}]
set_property -dict {LOC J15  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[48]}]
set_property -dict {LOC J16  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[49]}]
set_property -dict {LOC H14  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[50]}]
set_property -dict {LOC J14  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[51]}]
set_property -dict {LOC H13  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[52]}]
set_property -dict {LOC J13  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[53]}]
set_property -dict {LOC K15  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[54]}]
set_property -dict {LOC K16  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[55]}]
set_property -dict {LOC M16  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[56]}]
set_property -dict {LOC N16  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[57]}]
set_property -dict {LOC L14  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[58]}]
set_property -dict {LOC M14  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[59]}]
set_property -dict {LOC P15  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[60]}]
set_property -dict {LOC R15  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[61]}]
set_property -dict {LOC N14  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[62]}]
set_property -dict {LOC P14  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[63]}]
#set_property -dict {LOC M21  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[64]}]
#set_property -dict {LOC N21  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[65]}]
#set_property -dict {LOC P20  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[66]}]
#set_property -dict {LOC R20  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[67]}]
#set_property -dict {LOC M19  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[68]}]
#set_property -dict {LOC M20  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[69]}]
#set_property -dict {LOC N18  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[70]}]
#set_property -dict {LOC P18  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dq[71]}]
set_property -dict {LOC A23  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm2_dqs_t[0]}]
set_property -dict {LOC A22  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm2_dqs_c[0]}]
set_property -dict {LOC E23  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm2_dqs_t[1]}]
set_property -dict {LOC E22  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm2_dqs_c[1]}]
set_property -dict {LOC K25  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm2_dqs_t[2]}]
set_property -dict {LOC J25  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm2_dqs_c[2]}]
set_property -dict {LOC P24  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm2_dqs_t[3]}]
set_property -dict {LOC N24  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm2_dqs_c[3]}]
set_property -dict {LOC B15  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm2_dqs_t[4]}]
set_property -dict {LOC A15  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm2_dqs_c[4]}]
set_property -dict {LOC G17  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm2_dqs_t[5]}]
set_property -dict {LOC G16  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm2_dqs_c[5]}]
set_property -dict {LOC H17  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm2_dqs_t[6]}]
set_property -dict {LOC H16  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm2_dqs_c[6]}]
set_property -dict {LOC R16  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm2_dqs_t[7]}]
set_property -dict {LOC P16  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm2_dqs_c[7]}]
#set_property -dict {LOC P19  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm2_dqs_t[8]}]
#set_property -dict {LOC N19  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm2_dqs_c[8]}]
set_property -dict {LOC C22  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dm_dbi_n[0]}]
set_property -dict {LOC G25  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dm_dbi_n[1]}]
set_property -dict {LOC L25  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dm_dbi_n[2]}]
set_property -dict {LOC R21  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dm_dbi_n[3]}]
set_property -dict {LOC D13  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dm_dbi_n[4]}]
set_property -dict {LOC G14  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dm_dbi_n[5]}]
set_property -dict {LOC L13  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dm_dbi_n[6]}]
set_property -dict {LOC P13  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dm_dbi_n[7]}]
#set_property -dict {LOC N17  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm2_dm_dbi_n[8]}]
