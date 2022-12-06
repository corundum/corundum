# XDC constraints for the Xilinx VCU1525 board
# part: xcvu9p-flgb2104-2-e

# General configuration
set_property CFGBVS GND                                [current_design]
set_property CONFIG_VOLTAGE 1.8                        [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true           [current_design]
set_property BITSTREAM.CONFIG.CONFIGFALLBACK ENABLE    [current_design]
set_property BITSTREAM.CONFIG.EXTMASTERCCLK_EN DISABLE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 85.0          [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR YES       [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4           [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES        [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLUP         [current_design]
set_property BITSTREAM.CONFIG.OVERTEMPSHUTDOWN Enable  [current_design]

# System clocks
# 48 MHz system clock
set_property -dict {LOC AV23 IOSTANDARD LVCMOS18} [get_ports clk_48mhz]
create_clock -period 20.833 -name clk_48mhz [get_ports clk_48mhz]

# 322.265625 MHz clock from Si5338 B ch 1
#set_property -dict {LOC AY23 IOSTANDARD DIFF_SSTL18_I} [get_ports clk_b1_p]
#set_property -dict {LOC BA23 IOSTANDARD DIFF_SSTL18_I} [get_ports clk_b1_n]
#create_clock -period 3.103 -name clk_b1 [get_ports clk_b1_p]

# 322.265625 MHz clock from Si5338 B ch 2
#set_property -dict {LOC BB9  IOSTANDARD DIFF_SSTL15_DCI ODT RTT_48} [get_ports clk_b2_p]
#set_property -dict {LOC BC9  IOSTANDARD DIFF_SSTL15_DCI ODT RTT_48} [get_ports clk_b2_n]
#create_clock -period 3.103 -name clk_b2 [get_ports clk_b2_p]

# 100 MHz DDR4 module 1 clock from Si5338 A ch 0
set_property -dict {LOC AV18 IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_1_p]
set_property -dict {LOC AW18 IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_1_n]
#create_clock -period 10.000 -name clk_ddr_1 [get_ports clk_ddr_1_p]

# 100 MHz DDR4 module 2 clock from Si5338 A ch 1
set_property -dict {LOC BB36 IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_2_p]
set_property -dict {LOC BC36 IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_2_n]
#create_clock -period 10.000 -name clk_ddr_2 [get_ports clk_ddr_2_p]

# 100 MHz DDR4 module 3 clock from Si5338 A ch 2
set_property -dict {LOC E38  IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_3_p]
set_property -dict {LOC D38  IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_3_n]
#create_clock -period 10.000 -name clk_ddr_3 [get_ports clk_ddr_3_p]

# 100 MHz DDR4 module 4 clock from Si5338 A ch 3
set_property -dict {LOC K18  IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_4_p]
set_property -dict {LOC J18  IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_4_n]
#create_clock -period 10.000 -name clk_ddr_4 [get_ports clk_ddr_4_p]

# LEDs
set_property -dict {LOC AR22 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[0]}]
set_property -dict {LOC AT22 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[1]}]
set_property -dict {LOC AR23 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[2]}]
set_property -dict {LOC AV22 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[3]}]

set_false_path -to [get_ports {led[*]}]
set_output_delay 0 [get_ports {led[*]}]

# Reset
#set_property -dict {LOC  IOSTANDARD LVCMOS12} [get_ports reset]

#set_false_path -from [get_ports {reset}]
#set_input_delay 0 [get_ports {reset}]

# UART
#set_property -dict {LOC AL24 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports uart_txd]
#set_property -dict {LOC AM24 IOSTANDARD LVCMOS18} [get_ports uart_rxd]

#set_false_path -to [get_ports {uart_txd}]
#set_output_delay 0 [get_ports {uart_txd}]
#set_false_path -from [get_ports {uart_rxd}]
#set_input_delay 0 [get_ports {uart_rxd}]

# EEPROM I2C interface
set_property -dict {LOC AN24 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports eeprom_i2c_scl]
set_property -dict {LOC AP23 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports eeprom_i2c_sda]

set_false_path -to [get_ports {eeprom_i2c_sda eeprom_i2c_scl}]
set_output_delay 0 [get_ports {eeprom_i2c_sda eeprom_i2c_scl}]
set_false_path -from [get_ports {eeprom_i2c_sda eeprom_i2c_scl}]
set_input_delay 0 [get_ports {eeprom_i2c_sda eeprom_i2c_scl}]

# I2C-related signals
set_property -dict {LOC AT24 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports fpga_i2c_master_l]
set_property -dict {LOC AN23 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports qsfp_ctl_en]

set_false_path -to [get_ports {fpga_i2c_master_l qsfp_ctl_en}]
set_output_delay 0 [get_ports {fpga_i2c_master_l qsfp_ctl_en}]

# QSFP28 Interfaces
set_property -dict {LOC BC45} [get_ports qsfp0_rx1_p] ;# MGTYRXP0_120 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BC46} [get_ports qsfp0_rx1_n] ;# MGTYRXN0_120 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BF42} [get_ports qsfp0_tx1_p] ;# MGTYTXP0_120 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BF43} [get_ports qsfp0_tx1_n] ;# MGTYTXN0_120 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BA45} [get_ports qsfp0_rx2_p] ;# MGTYRXP1_120 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BA46} [get_ports qsfp0_rx2_n] ;# MGTYRXN1_120 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BD42} [get_ports qsfp0_tx2_p] ;# MGTYTXP1_120 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BD43} [get_ports qsfp0_tx2_n] ;# MGTYTXN1_120 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC AW45} [get_ports qsfp0_rx3_p] ;# MGTYRXP2_120 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC AW46} [get_ports qsfp0_rx3_n] ;# MGTYRXN2_120 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BB42} [get_ports qsfp0_tx3_p] ;# MGTYTXP2_120 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BB43} [get_ports qsfp0_tx3_n] ;# MGTYTXN2_120 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC AV43} [get_ports qsfp0_rx4_p] ;# MGTYRXP3_120 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC AV44} [get_ports qsfp0_rx4_n] ;# MGTYRXN3_120 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC AW40} [get_ports qsfp0_tx4_p] ;# MGTYTXP3_120 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC AW41} [get_ports qsfp0_tx4_n] ;# MGTYTXN3_120 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BA40} [get_ports qsfp0_mgt_refclk_b0_p] ;# MGTREFCLK0P_120 from Si5338 B ch 0
set_property -dict {LOC BA41} [get_ports qsfp0_mgt_refclk_b0_n] ;# MGTREFCLK0N_120 from Si5338 B ch 0
#set_property -dict {LOC AY38} [get_ports qsfp0_mgt_refclk_b1_p] ;# MGTREFCLK1P_120 from Si5338 B ch 1
#set_property -dict {LOC AY39} [get_ports qsfp0_mgt_refclk_b1_n] ;# MGTREFCLK1N_120 from Si5338 B ch 1
#set_property -dict {LOC AU36} [get_ports qsfp0_mgt_refclk_c0_p] ;# MGTREFCLK0P_121 from Si5338 C ch 0
#set_property -dict {LOC AU37} [get_ports qsfp0_mgt_refclk_c0_n] ;# MGTREFCLK0N_121 from Si5338 C ch 0
#set_property -dict {LOC AV38} [get_ports qsfp0_mgt_refclk_c1_p] ;# MGTREFCLK1P_121 from Si5338 C ch 1
#set_property -dict {LOC AV39} [get_ports qsfp0_mgt_refclk_c1_n] ;# MGTREFCLK1N_121 from Si5338 C ch 1
set_property -dict {LOC BD24 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports qsfp0_resetl]
set_property -dict {LOC BD23 IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp0_modprsl]
set_property -dict {LOC BE23 IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp0_intl]
set_property -dict {LOC BC24 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports qsfp0_lpmode]
set_property -dict {LOC BF24 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8 PULLUP true} [get_ports qsfp0_i2c_scl]
set_property -dict {LOC BF23 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8 PULLUP true} [get_ports qsfp0_i2c_sda]

# 322.265625 MHz MGT reference clock (from Si5338 B ch 0)
create_clock -period 3.103 -name qsfp0_mgt_refclk_b0 [get_ports qsfp0_mgt_refclk_b0_p]

# 322.265625 MHz MGT reference clock (from Si5338 B ch 1)
#create_clock -period 3.103 -name qsfp0_mgt_refclk_b1 [get_ports qsfp0_mgt_refclk_b1_p]

# 322.265625 MHz MGT reference clock (from Si5338 C ch 0)
#create_clock -period 3.103 -name qsfp0_mgt_refclk_c0 [get_ports qsfp0_mgt_refclk_c0_p]

# 322.265625 MHz MGT reference clock (from Si5338 C ch 1)
#create_clock -period 3.103 -name qsfp0_mgt_refclk_c1 [get_ports qsfp0_mgt_refclk_c1_p]

set_false_path -to [get_ports {qsfp0_resetl qsfp0_lpmode}]
set_output_delay 0 [get_ports {qsfp0_resetl qsfp0_lpmode}]
set_false_path -from [get_ports {qsfp0_modprsl qsfp0_intl}]
set_input_delay 0 [get_ports {qsfp0_modprsl qsfp0_intl}]

set_false_path -to [get_ports {qsfp0_i2c_scl qsfp0_i2c_sda}]
set_output_delay 0 [get_ports {qsfp0_i2c_scl qsfp0_i2c_sda}]
set_false_path -from [get_ports {qsfp0_i2c_scl qsfp0_i2c_sda}]
set_input_delay 0 [get_ports {qsfp0_i2c_scl qsfp0_i2c_sda}]

set_property -dict {LOC AN45} [get_ports qsfp1_rx1_p] ;# MGTYRXP0_122 GTYE4_CHANNEL_X0Y12 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AN46} [get_ports qsfp1_rx1_n] ;# MGTYRXN0_122 GTYE4_CHANNEL_X0Y12 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AN40} [get_ports qsfp1_tx1_p] ;# MGTYTXP0_122 GTYE4_CHANNEL_X0Y12 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AN41} [get_ports qsfp1_tx1_n] ;# MGTYTXN0_122 GTYE4_CHANNEL_X0Y12 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AM43} [get_ports qsfp1_rx2_p] ;# MGTYRXP1_122 GTYE4_CHANNEL_X0Y13 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AM44} [get_ports qsfp1_rx2_n] ;# MGTYRXN1_122 GTYE4_CHANNEL_X0Y13 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AM38} [get_ports qsfp1_tx2_p] ;# MGTYTXP1_122 GTYE4_CHANNEL_X0Y13 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AM39} [get_ports qsfp1_tx2_n] ;# MGTYTXN1_122 GTYE4_CHANNEL_X0Y13 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AL45} [get_ports qsfp1_rx3_p] ;# MGTYRXP2_122 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AL46} [get_ports qsfp1_rx3_n] ;# MGTYRXN2_122 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AL40} [get_ports qsfp1_tx3_p] ;# MGTYTXP2_122 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AL41} [get_ports qsfp1_tx3_n] ;# MGTYTXN2_122 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AK43} [get_ports qsfp1_rx4_p] ;# MGTYRXP3_122 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AK44} [get_ports qsfp1_rx4_n] ;# MGTYRXN3_122 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AK38} [get_ports qsfp1_tx4_p] ;# MGTYTXP3_122 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AK39} [get_ports qsfp1_tx4_n] ;# MGTYTXN3_122 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AR36} [get_ports qsfp1_mgt_refclk_b0_p] ;# MGTREFCLK0P_122 from Si5338 B ch 0
set_property -dict {LOC AR37} [get_ports qsfp1_mgt_refclk_b0_n] ;# MGTREFCLK0N_122 from Si5338 B ch 0
#set_property -dict {LOC AN36} [get_ports qsfp1_mgt_refclk_b1_p] ;# MGTREFCLK1P_122 from Si5338 B ch 1
#set_property -dict {LOC AN37} [get_ports qsfp1_mgt_refclk_b1_n] ;# MGTREFCLK1N_122 from Si5338 B ch 1
#set_property -dict {LOC AL36} [get_ports qsfp1_mgt_refclk_c2_p] ;# MGTREFCLK0P_123 from Si5338 C ch 2
#set_property -dict {LOC AL37} [get_ports qsfp1_mgt_refclk_c2_n] ;# MGTREFCLK0N_123 from Si5338 C ch 2
#set_property -dict {LOC AJ36} [get_ports qsfp1_mgt_refclk_c3_p] ;# MGTREFCLK1P_123 from Si5338 C ch 3
#set_property -dict {LOC AJ37} [get_ports qsfp1_mgt_refclk_c3_n] ;# MGTREFCLK1N_123 from Si5338 C ch 3
set_property -dict {LOC BE20 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports qsfp1_resetl]
set_property -dict {LOC BD21 IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp1_modprsl]
set_property -dict {LOC BE21 IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp1_intl]
set_property -dict {LOC BD20 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports qsfp1_lpmode]
set_property -dict {LOC BE22 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8 PULLUP true} [get_ports qsfp1_i2c_scl]
set_property -dict {LOC BF22 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8 PULLUP true} [get_ports qsfp1_i2c_sda]

# 322.265625 MHz MGT reference clock (from Si5338 B ch 0)
create_clock -period 3.103 -name qsfp1_mgt_refclk_b0 [get_ports qsfp1_mgt_refclk_b0_p]

# 322.265625 MHz MGT reference clock (from Si5338 B ch 1)
#create_clock -period 3.103 -name qsfp1_mgt_refclk_b1 [get_ports qsfp1_mgt_refclk_b1_p]

# 322.265625 MHz MGT reference clock (from Si5338 C ch 2)
#create_clock -period 3.103 -name qsfp1_mgt_refclk_c2 [get_ports qsfp1_mgt_refclk_c2_p]

# 322.265625 MHz MGT reference clock (from Si5338 C ch 3)
#create_clock -period 3.103 -name qsfp1_mgt_refclk_c3 [get_ports qsfp1_mgt_refclk_c3_p]

set_false_path -to [get_ports {qsfp1_resetl qsfp1_lpmode}]
set_output_delay 0 [get_ports {qsfp1_resetl qsfp1_lpmode}]
set_false_path -from [get_ports {qsfp1_modprsl qsfp1_intl}]
set_input_delay 0 [get_ports {qsfp1_modprsl qsfp1_intl}]

set_false_path -to [get_ports {qsfp1_i2c_scl qsfp1_i2c_sda}]
set_output_delay 0 [get_ports {qsfp1_i2c_scl qsfp1_i2c_sda}]
set_false_path -from [get_ports {qsfp1_i2c_scl qsfp1_i2c_sda}]
set_input_delay 0 [get_ports {qsfp1_i2c_scl qsfp1_i2c_sda}]

set_property -dict {LOC AA45} [get_ports qsfp2_rx1_p] ;# MGTYRXP0_125 GTYE4_CHANNEL_X0Y24 / GTYE4_COMMON_X0Y6
set_property -dict {LOC AA46} [get_ports qsfp2_rx1_n] ;# MGTYRXN0_125 GTYE4_CHANNEL_X0Y24 / GTYE4_COMMON_X0Y6
set_property -dict {LOC AA40} [get_ports qsfp2_tx1_p] ;# MGTYTXP0_125 GTYE4_CHANNEL_X0Y24 / GTYE4_COMMON_X0Y6
set_property -dict {LOC AA41} [get_ports qsfp2_tx1_n] ;# MGTYTXN0_125 GTYE4_CHANNEL_X0Y24 / GTYE4_COMMON_X0Y6
set_property -dict {LOC Y43 } [get_ports qsfp2_rx2_p] ;# MGTYRXP1_125 GTYE4_CHANNEL_X0Y25 / GTYE4_COMMON_X0Y6
set_property -dict {LOC Y44 } [get_ports qsfp2_rx2_n] ;# MGTYRXN1_125 GTYE4_CHANNEL_X0Y25 / GTYE4_COMMON_X0Y6
set_property -dict {LOC Y38 } [get_ports qsfp2_tx2_p] ;# MGTYTXP1_125 GTYE4_CHANNEL_X0Y25 / GTYE4_COMMON_X0Y6
set_property -dict {LOC Y39 } [get_ports qsfp2_tx2_n] ;# MGTYTXN1_125 GTYE4_CHANNEL_X0Y25 / GTYE4_COMMON_X0Y6
set_property -dict {LOC W45 } [get_ports qsfp2_rx3_p] ;# MGTYRXP2_125 GTYE4_CHANNEL_X0Y26 / GTYE4_COMMON_X0Y6
set_property -dict {LOC W46 } [get_ports qsfp2_rx3_n] ;# MGTYRXN2_125 GTYE4_CHANNEL_X0Y26 / GTYE4_COMMON_X0Y6
set_property -dict {LOC W40 } [get_ports qsfp2_tx3_p] ;# MGTYTXP2_125 GTYE4_CHANNEL_X0Y26 / GTYE4_COMMON_X0Y6
set_property -dict {LOC W41 } [get_ports qsfp2_tx3_n] ;# MGTYTXN2_125 GTYE4_CHANNEL_X0Y26 / GTYE4_COMMON_X0Y6
set_property -dict {LOC V43 } [get_ports qsfp2_rx4_p] ;# MGTYRXP3_125 GTYE4_CHANNEL_X0Y27 / GTYE4_COMMON_X0Y6
set_property -dict {LOC V44 } [get_ports qsfp2_rx4_n] ;# MGTYRXN3_125 GTYE4_CHANNEL_X0Y27 / GTYE4_COMMON_X0Y6
set_property -dict {LOC V38 } [get_ports qsfp2_tx4_p] ;# MGTYTXP3_125 GTYE4_CHANNEL_X0Y27 / GTYE4_COMMON_X0Y6
set_property -dict {LOC V39 } [get_ports qsfp2_tx4_n] ;# MGTYTXN3_125 GTYE4_CHANNEL_X0Y27 / GTYE4_COMMON_X0Y6
set_property -dict {LOC AC36} [get_ports qsfp2_mgt_refclk_b0_p] ;# MGTREFCLK0P_125 from Si5338 B ch 0
set_property -dict {LOC AC37} [get_ports qsfp2_mgt_refclk_b0_n] ;# MGTREFCLK0N_125 from Si5338 B ch 0
#set_property -dict {LOC AA36} [get_ports qsfp2_mgt_refclk_b2_p] ;# MGTREFCLK1P_125 from Si5338 B ch 2
#set_property -dict {LOC AA37} [get_ports qsfp2_mgt_refclk_b2_n] ;# MGTREFCLK1N_125 from Si5338 B ch 2
#set_property -dict {LOC W36 } [get_ports qsfp2_mgt_refclk_d0_p] ;# MGTREFCLK0P_126 from Si5338 D ch 0
#set_property -dict {LOC W37 } [get_ports qsfp2_mgt_refclk_d0_n] ;# MGTREFCLK0N_126 from Si5338 D ch 0
#set_property -dict {LOC U36 } [get_ports qsfp2_mgt_refclk_d1_p] ;# MGTREFCLK1P_126 from Si5338 D ch 1
#set_property -dict {LOC U37 } [get_ports qsfp2_mgt_refclk_d1_n] ;# MGTREFCLK1N_126 from Si5338 D ch 1
set_property -dict {LOC BB22 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports qsfp2_resetl]
set_property -dict {LOC BB20 IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp2_modprsl]
set_property -dict {LOC BB21 IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp2_intl]
set_property -dict {LOC BC21 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports qsfp2_lpmode]
set_property -dict {LOC BF20 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8 PULLUP true} [get_ports qsfp2_i2c_scl]
set_property -dict {LOC BA20 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8 PULLUP true} [get_ports qsfp2_i2c_sda]

# 322.265625 MHz MGT reference clock (from Si5338 B ch 0)
create_clock -period 3.103 -name qsfp2_mgt_refclk_b0 [get_ports qsfp2_mgt_refclk_b0_p]

# 322.265625 MHz MGT reference clock (from Si5338 B ch 2)
#create_clock -period 3.103 -name qsfp2_mgt_refclk_b2 [get_ports qsfp2_mgt_refclk_b2_p]

# 322.265625 MHz MGT reference clock (from Si5338 D ch 0)
#create_clock -period 3.103 -name qsfp2_mgt_refclk_d0 [get_ports qsfp2_mgt_refclk_d0_p]

# 322.265625 MHz MGT reference clock (from Si5338 D ch 1)
#create_clock -period 3.103 -name qsfp2_mgt_refclk_d1 [get_ports qsfp2_mgt_refclk_d1_p]

set_false_path -to [get_ports {qsfp2_resetl qsfp2_lpmode}]
set_output_delay 0 [get_ports {qsfp2_resetl qsfp2_lpmode}]
set_false_path -from [get_ports {qsfp2_modprsl qsfp2_intl}]
set_input_delay 0 [get_ports {qsfp2_modprsl qsfp2_intl}]

set_false_path -to [get_ports {qsfp2_i2c_scl qsfp2_i2c_sda}]
set_output_delay 0 [get_ports {qsfp2_i2c_scl qsfp2_i2c_sda}]
set_false_path -from [get_ports {qsfp2_i2c_scl qsfp2_i2c_sda}]
set_input_delay 0 [get_ports {qsfp2_i2c_scl qsfp2_i2c_sda}]

set_property -dict {LOC N45 } [get_ports qsfp3_rx1_p] ;# MGTYRXP0_127 GTYE4_CHANNEL_X0Y32 / GTYE4_COMMON_X0Y8
set_property -dict {LOC N46 } [get_ports qsfp3_rx1_n] ;# MGTYRXN0_127 GTYE4_CHANNEL_X0Y32 / GTYE4_COMMON_X0Y8
set_property -dict {LOC N40 } [get_ports qsfp3_tx1_p] ;# MGTYTXP0_127 GTYE4_CHANNEL_X0Y32 / GTYE4_COMMON_X0Y8
set_property -dict {LOC N41 } [get_ports qsfp3_tx1_n] ;# MGTYTXN0_127 GTYE4_CHANNEL_X0Y32 / GTYE4_COMMON_X0Y8
set_property -dict {LOC M43 } [get_ports qsfp3_rx2_p] ;# MGTYRXP1_127 GTYE4_CHANNEL_X0Y33 / GTYE4_COMMON_X0Y8
set_property -dict {LOC M44 } [get_ports qsfp3_rx2_n] ;# MGTYRXN1_127 GTYE4_CHANNEL_X0Y33 / GTYE4_COMMON_X0Y8
set_property -dict {LOC M38 } [get_ports qsfp3_tx2_p] ;# MGTYTXP1_127 GTYE4_CHANNEL_X0Y33 / GTYE4_COMMON_X0Y8
set_property -dict {LOC M39 } [get_ports qsfp3_tx2_n] ;# MGTYTXN1_127 GTYE4_CHANNEL_X0Y33 / GTYE4_COMMON_X0Y8
set_property -dict {LOC L45 } [get_ports qsfp3_rx3_p] ;# MGTYRXP2_127 GTYE4_CHANNEL_X0Y34 / GTYE4_COMMON_X0Y8
set_property -dict {LOC L46 } [get_ports qsfp3_rx3_n] ;# MGTYRXN2_127 GTYE4_CHANNEL_X0Y34 / GTYE4_COMMON_X0Y8
set_property -dict {LOC L40 } [get_ports qsfp3_tx3_p] ;# MGTYTXP2_127 GTYE4_CHANNEL_X0Y34 / GTYE4_COMMON_X0Y8
set_property -dict {LOC L41 } [get_ports qsfp3_tx3_n] ;# MGTYTXN2_127 GTYE4_CHANNEL_X0Y34 / GTYE4_COMMON_X0Y8
set_property -dict {LOC K43 } [get_ports qsfp3_rx4_p] ;# MGTYRXP3_127 GTYE4_CHANNEL_X0Y35 / GTYE4_COMMON_X0Y8
set_property -dict {LOC K44 } [get_ports qsfp3_rx4_n] ;# MGTYRXN3_127 GTYE4_CHANNEL_X0Y35 / GTYE4_COMMON_X0Y8
set_property -dict {LOC J40 } [get_ports qsfp3_tx4_p] ;# MGTYTXP3_127 GTYE4_CHANNEL_X0Y35 / GTYE4_COMMON_X0Y8
set_property -dict {LOC J41 } [get_ports qsfp3_tx4_n] ;# MGTYTXN3_127 GTYE4_CHANNEL_X0Y35 / GTYE4_COMMON_X0Y8
set_property -dict {LOC R36 } [get_ports qsfp3_mgt_refclk_b0_p] ;# MGTREFCLK0P_127 from Si5338 B ch 0
set_property -dict {LOC R37 } [get_ports qsfp3_mgt_refclk_b0_n] ;# MGTREFCLK0N_127 from Si5338 B ch 0
#set_property -dict {LOC N36 } [get_ports qsfp3_mgt_refclk_b3_p] ;# MGTREFCLK1P_127 from Si5338 B ch 3
#set_property -dict {LOC N37 } [get_ports qsfp3_mgt_refclk_b3_n] ;# MGTREFCLK1N_127 from Si5338 B ch 3
#set_property -dict {LOC L36 } [get_ports qsfp3_mgt_refclk_d2_p] ;# MGTREFCLK0P_128 from Si5338 D ch 2
#set_property -dict {LOC L37 } [get_ports qsfp3_mgt_refclk_d2_n] ;# MGTREFCLK0N_128 from Si5338 D ch 2
#set_property -dict {LOC K38 } [get_ports qsfp3_mgt_refclk_d3_p] ;# MGTREFCLK1P_128 from Si5338 D ch 3
#set_property -dict {LOC K39 } [get_ports qsfp3_mgt_refclk_d3_n] ;# MGTREFCLK1N_128 from Si5338 D ch 3
set_property -dict {LOC BC23 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports qsfp3_resetl]
set_property -dict {LOC BB24 IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp3_modprsl]
set_property -dict {LOC AY22 IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp3_intl]
set_property -dict {LOC BA22 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports qsfp3_lpmode]
set_property -dict {LOC BC22 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8 PULLUP true} [get_ports qsfp3_i2c_scl]
set_property -dict {LOC BA24 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8 PULLUP true} [get_ports qsfp3_i2c_sda]

# 322.265625 MHz MGT reference clock (from Si5338 B ch 0)
create_clock -period 3.103 -name qsfp3_mgt_refclk_b0 [get_ports qsfp3_mgt_refclk_b0_p]

# 322.265625 MHz MGT reference clock (from Si5338 B ch 2)
#create_clock -period 3.103 -name qsfp3_mgt_refclk_b3 [get_ports qsfp3_mgt_refclk_b3_p]

# 322.265625 MHz MGT reference clock (from Si5338 D ch 2)
#create_clock -period 3.103 -name qsfp3_mgt_refclk_d2 [get_ports qsfp3_mgt_refclk_d2_p]

# 322.265625 MHz MGT reference clock (from Si5338 D ch 3)
#create_clock -period 3.103 -name qsfp3_mgt_refclk_d3 [get_ports qsfp3_mgt_refclk_d3_p]

set_false_path -to [get_ports {qsfp3_resetl qsfp3_lpmode}]
set_output_delay 0 [get_ports {qsfp3_resetl qsfp3_lpmode}]
set_false_path -from [get_ports {qsfp3_modprsl qsfp3_intl}]
set_input_delay 0 [get_ports {qsfp3_modprsl qsfp3_intl}]

set_false_path -to [get_ports {qsfp3_i2c_scl qsfp3_i2c_sda}]
set_output_delay 0 [get_ports {qsfp3_i2c_scl qsfp3_i2c_sda}]
set_false_path -from [get_ports {qsfp3_i2c_scl qsfp3_i2c_sda}]
set_input_delay 0 [get_ports {qsfp3_i2c_scl qsfp3_i2c_sda}]

# PCIe Interface
set_property -dict {LOC AF2  } [get_ports {pcie_rx_p[0]}]  ;# MGTYRXP3_227 GTYE4_CHANNEL_X1Y35 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AF1  } [get_ports {pcie_rx_n[0]}]  ;# MGTYRXN3_227 GTYE4_CHANNEL_X1Y35 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AF7  } [get_ports {pcie_tx_p[0]}]  ;# MGTYTXP3_227 GTYE4_CHANNEL_X1Y35 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AF6  } [get_ports {pcie_tx_n[0]}]  ;# MGTYTXN3_227 GTYE4_CHANNEL_X1Y35 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AG4  } [get_ports {pcie_rx_p[1]}]  ;# MGTYRXP2_227 GTYE4_CHANNEL_X1Y34 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AG3  } [get_ports {pcie_rx_n[1]}]  ;# MGTYRXN2_227 GTYE4_CHANNEL_X1Y34 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AG9  } [get_ports {pcie_tx_p[1]}]  ;# MGTYTXP2_227 GTYE4_CHANNEL_X1Y34 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AG8  } [get_ports {pcie_tx_n[1]}]  ;# MGTYTXN2_227 GTYE4_CHANNEL_X1Y34 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AH2  } [get_ports {pcie_rx_p[2]}]  ;# MGTYRXP1_227 GTYE4_CHANNEL_X1Y33 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AH1  } [get_ports {pcie_rx_n[2]}]  ;# MGTYRXN1_227 GTYE4_CHANNEL_X1Y33 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AH7  } [get_ports {pcie_tx_p[2]}]  ;# MGTYTXP1_227 GTYE4_CHANNEL_X1Y33 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AH6  } [get_ports {pcie_tx_n[2]}]  ;# MGTYTXN1_227 GTYE4_CHANNEL_X1Y33 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AJ4  } [get_ports {pcie_rx_p[3]}]  ;# MGTYRXP0_227 GTYE4_CHANNEL_X1Y32 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AJ3  } [get_ports {pcie_rx_n[3]}]  ;# MGTYRXN0_227 GTYE4_CHANNEL_X1Y32 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AJ9  } [get_ports {pcie_tx_p[3]}]  ;# MGTYTXP0_227 GTYE4_CHANNEL_X1Y32 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AJ8  } [get_ports {pcie_tx_n[3]}]  ;# MGTYTXN0_227 GTYE4_CHANNEL_X1Y32 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AK2  } [get_ports {pcie_rx_p[4]}]  ;# MGTYRXP3_226 GTYE4_CHANNEL_X1Y31 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AK1  } [get_ports {pcie_rx_n[4]}]  ;# MGTYRXN3_226 GTYE4_CHANNEL_X1Y31 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AK7  } [get_ports {pcie_tx_p[4]}]  ;# MGTYTXP3_226 GTYE4_CHANNEL_X1Y31 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AK6  } [get_ports {pcie_tx_n[4]}]  ;# MGTYTXN3_226 GTYE4_CHANNEL_X1Y31 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AL4  } [get_ports {pcie_rx_p[5]}]  ;# MGTYRXP2_226 GTYE4_CHANNEL_X1Y30 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AL3  } [get_ports {pcie_rx_n[5]}]  ;# MGTYRXN2_226 GTYE4_CHANNEL_X1Y30 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AL9  } [get_ports {pcie_tx_p[5]}]  ;# MGTYTXP2_226 GTYE4_CHANNEL_X1Y30 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AL8  } [get_ports {pcie_tx_n[5]}]  ;# MGTYTXN2_226 GTYE4_CHANNEL_X1Y30 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AM2  } [get_ports {pcie_rx_p[6]}]  ;# MGTYRXP1_226 GTYE4_CHANNEL_X1Y29 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AM1  } [get_ports {pcie_rx_n[6]}]  ;# MGTYRXN1_226 GTYE4_CHANNEL_X1Y29 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AM7  } [get_ports {pcie_tx_p[6]}]  ;# MGTYTXP1_226 GTYE4_CHANNEL_X1Y29 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AM6  } [get_ports {pcie_tx_n[6]}]  ;# MGTYTXN1_226 GTYE4_CHANNEL_X1Y29 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AN4  } [get_ports {pcie_rx_p[7]}]  ;# MGTYRXP0_226 GTYE4_CHANNEL_X1Y28 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AN3  } [get_ports {pcie_rx_n[7]}]  ;# MGTYRXN0_226 GTYE4_CHANNEL_X1Y28 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AN9  } [get_ports {pcie_tx_p[7]}]  ;# MGTYTXP0_226 GTYE4_CHANNEL_X1Y28 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AN8  } [get_ports {pcie_tx_n[7]}]  ;# MGTYTXN0_226 GTYE4_CHANNEL_X1Y28 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AP2  } [get_ports {pcie_rx_p[8]}]  ;# MGTYRXP3_225 GTYE4_CHANNEL_X1Y27 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AP1  } [get_ports {pcie_rx_n[8]}]  ;# MGTYRXN3_225 GTYE4_CHANNEL_X1Y27 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AP7  } [get_ports {pcie_tx_p[8]}]  ;# MGTYTXP3_225 GTYE4_CHANNEL_X1Y27 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AP6  } [get_ports {pcie_tx_n[8]}]  ;# MGTYTXN3_225 GTYE4_CHANNEL_X1Y27 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AR4  } [get_ports {pcie_rx_p[9]}]  ;# MGTYRXP2_225 GTYE4_CHANNEL_X1Y26 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AR3  } [get_ports {pcie_rx_n[9]}]  ;# MGTYRXN2_225 GTYE4_CHANNEL_X1Y26 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AR9  } [get_ports {pcie_tx_p[9]}]  ;# MGTYTXP2_225 GTYE4_CHANNEL_X1Y26 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AR8  } [get_ports {pcie_tx_n[9]}]  ;# MGTYTXN2_225 GTYE4_CHANNEL_X1Y26 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AT2  } [get_ports {pcie_rx_p[10]}] ;# MGTYRXP1_225 GTYE4_CHANNEL_X1Y25 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AT1  } [get_ports {pcie_rx_n[10]}] ;# MGTYRXN1_225 GTYE4_CHANNEL_X1Y25 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AT7  } [get_ports {pcie_tx_p[10]}] ;# MGTYTXP1_225 GTYE4_CHANNEL_X1Y25 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AT6  } [get_ports {pcie_tx_n[10]}] ;# MGTYTXN1_225 GTYE4_CHANNEL_X1Y25 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AU4  } [get_ports {pcie_rx_p[11]}] ;# MGTYRXP0_225 GTYE4_CHANNEL_X1Y24 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AU3  } [get_ports {pcie_rx_n[11]}] ;# MGTYRXN0_225 GTYE4_CHANNEL_X1Y24 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AU9  } [get_ports {pcie_tx_p[11]}] ;# MGTYTXP0_225 GTYE4_CHANNEL_X1Y24 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AU8  } [get_ports {pcie_tx_n[11]}] ;# MGTYTXN0_225 GTYE4_CHANNEL_X1Y24 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AV2  } [get_ports {pcie_rx_p[12]}] ;# MGTYRXP3_224 GTYE4_CHANNEL_X1Y23 / GTYE4_COMMON_X1Y5
set_property -dict {LOC AV1  } [get_ports {pcie_rx_n[12]}] ;# MGTYRXN3_224 GTYE4_CHANNEL_X1Y23 / GTYE4_COMMON_X1Y5
set_property -dict {LOC AV7  } [get_ports {pcie_tx_p[12]}] ;# MGTYTXP3_224 GTYE4_CHANNEL_X1Y23 / GTYE4_COMMON_X1Y5
set_property -dict {LOC AV6  } [get_ports {pcie_tx_n[12]}] ;# MGTYTXN3_224 GTYE4_CHANNEL_X1Y23 / GTYE4_COMMON_X1Y5
set_property -dict {LOC AW4  } [get_ports {pcie_rx_p[13]}] ;# MGTYRXP2_224 GTYE4_CHANNEL_X1Y22 / GTYE4_COMMON_X1Y5
set_property -dict {LOC AW3  } [get_ports {pcie_rx_n[13]}] ;# MGTYRXN2_224 GTYE4_CHANNEL_X1Y22 / GTYE4_COMMON_X1Y5
set_property -dict {LOC BB5  } [get_ports {pcie_tx_p[13]}] ;# MGTYTXP2_224 GTYE4_CHANNEL_X1Y22 / GTYE4_COMMON_X1Y5
set_property -dict {LOC BB4  } [get_ports {pcie_tx_n[13]}] ;# MGTYTXN2_224 GTYE4_CHANNEL_X1Y22 / GTYE4_COMMON_X1Y5
set_property -dict {LOC BA2  } [get_ports {pcie_rx_p[14]}] ;# MGTYRXP1_224 GTYE4_CHANNEL_X1Y21 / GTYE4_COMMON_X1Y5
set_property -dict {LOC BA1  } [get_ports {pcie_rx_n[14]}] ;# MGTYRXN1_224 GTYE4_CHANNEL_X1Y21 / GTYE4_COMMON_X1Y5
set_property -dict {LOC BD5  } [get_ports {pcie_tx_p[14]}] ;# MGTYTXP1_224 GTYE4_CHANNEL_X1Y21 / GTYE4_COMMON_X1Y5
set_property -dict {LOC BD4  } [get_ports {pcie_tx_n[14]}] ;# MGTYTXN1_224 GTYE4_CHANNEL_X1Y21 / GTYE4_COMMON_X1Y5
set_property -dict {LOC BC2  } [get_ports {pcie_rx_p[15]}] ;# MGTYRXP0_224 GTYE4_CHANNEL_X1Y20 / GTYE4_COMMON_X1Y5
set_property -dict {LOC BC1  } [get_ports {pcie_rx_n[15]}] ;# MGTYRXN0_224 GTYE4_CHANNEL_X1Y20 / GTYE4_COMMON_X1Y5
set_property -dict {LOC BF5  } [get_ports {pcie_tx_p[15]}] ;# MGTYTXP0_224 GTYE4_CHANNEL_X1Y20 / GTYE4_COMMON_X1Y5
set_property -dict {LOC BF4  } [get_ports {pcie_tx_n[15]}] ;# MGTYTXN0_224 GTYE4_CHANNEL_X1Y20 / GTYE4_COMMON_X1Y5
set_property -dict {LOC AT11 } [get_ports pcie_refclk_0_p] ;# MGTREFCLK0P_225
set_property -dict {LOC AT10 } [get_ports pcie_refclk_0_n] ;# MGTREFCLK0N_225
# set_property -dict {LOC AM11 } [get_ports pcie_refclk_b1_p] ;# MGTREFCLK0P_226 from Si5338 B ch 1
# set_property -dict {LOC AM10 } [get_ports pcie_refclk_b1_n] ;# MGTREFCLK0N_226 from Si5338 B ch 1
# set_property -dict {LOC AH11 } [get_ports pcie_refclk_1_p] ;# MGTREFCLK0P_227
# set_property -dict {LOC AH10 } [get_ports pcie_refclk_1_n] ;# MGTREFCLK0N_227
set_property -dict {LOC AR26 IOSTANDARD LVCMOS12 PULLUP true} [get_ports pcie_reset_n]

# 100 MHz MGT reference clock
create_clock -period 10 -name pcie_mgt_refclk_0 [get_ports pcie_refclk_0_p]

set_false_path -from [get_ports {pcie_reset_n}]
set_input_delay 0 [get_ports {pcie_reset_n}]

# DDR4 C0
set_property -dict {LOC AT18 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_adr[0]}]
set_property -dict {LOC AU17 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_adr[1]}]
set_property -dict {LOC AP18 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_adr[2]}]
set_property -dict {LOC AR18 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_adr[3]}]
set_property -dict {LOC AP20 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_adr[4]}]
set_property -dict {LOC AR20 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_adr[5]}]
set_property -dict {LOC AU21 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_adr[6]}]
set_property -dict {LOC AN18 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_adr[7]}]
set_property -dict {LOC AN17 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_adr[8]}]
set_property -dict {LOC AN19 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_adr[9]}]
set_property -dict {LOC AP19 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_adr[10]}]
set_property -dict {LOC AM16 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_adr[11]}]
set_property -dict {LOC AN16 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_adr[12]}]
set_property -dict {LOC AL19 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_adr[13]}]
set_property -dict {LOC AM19 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_adr[14]}]
set_property -dict {LOC AL20 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_adr[15]}]
set_property -dict {LOC AM20 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_adr[16]}]
# set_property -dict {LOC AP16 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_adr[17]}]
set_property -dict {LOC AT19 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_ba[0]}]
set_property -dict {LOC AU19 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_ba[1]}]
set_property -dict {LOC AT20 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_bg[0]}]
set_property -dict {LOC AU20 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_bg[1]}]
set_property -dict {LOC AR17 IOSTANDARD DIFF_SSTL12_DCI } [get_ports {ddr4_c0_ck_t[0]}]
set_property -dict {LOC AT17 IOSTANDARD DIFF_SSTL12_DCI } [get_ports {ddr4_c0_ck_c[0]}]
set_property -dict {LOC AY20 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_cke[0]}]
# set_property -dict {LOC AV21 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_cke[1]}]
set_property -dict {LOC BA18 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_cs_n[0]}]
# set_property -dict {LOC AW20 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_cs_n[1]}]
# set_property -dict {LOC BA17 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_cs_n[2]}]
# set_property -dict {LOC AY18 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_cs_n[3]}]
# set_property -dict {LOC AM17 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_c[0]}]
# set_property -dict {LOC AU25 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_c[1]}]
# set_property -dict {LOC AT14 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_c[2]}]
set_property -dict {LOC AV17 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_act_n}]
set_property -dict {LOC AW21 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_odt[0]}]
# set_property -dict {LOC AV19 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_odt[1]}]
set_property -dict {LOC AW19 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c0_par}]
set_property -dict {LOC AY17 IOSTANDARD LVCMOS12 DRIVE 8} [get_ports {ddr4_c0_reset_n}]

set_property -dict {LOC AL28 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[0]}]
set_property -dict {LOC AL27 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[1]}]
set_property -dict {LOC AN27 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[2]}]
set_property -dict {LOC AM27 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[3]}]
set_property -dict {LOC AM25 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[4]}]
set_property -dict {LOC AL25 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[5]}]
set_property -dict {LOC AP28 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[6]}]
set_property -dict {LOC AN28 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[7]}]
set_property -dict {LOC AT28 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[8]}]
set_property -dict {LOC AR28 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[9]}]
set_property -dict {LOC AT27 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[10]}]
set_property -dict {LOC AR27 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[11]}]
set_property -dict {LOC AU27 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[12]}]
set_property -dict {LOC AU26 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[13]}]
set_property -dict {LOC AV28 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[14]}]
set_property -dict {LOC AV27 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[15]}]
set_property -dict {LOC AY28 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[16]}]
set_property -dict {LOC AW28 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[17]}]
set_property -dict {LOC AY27 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[18]}]
set_property -dict {LOC AY26 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[19]}]
set_property -dict {LOC BA28 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[20]}]
set_property -dict {LOC BA27 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[21]}]
set_property -dict {LOC BB27 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[22]}]
set_property -dict {LOC BB26 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[23]}]
set_property -dict {LOC BC27 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[24]}]
set_property -dict {LOC BC26 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[25]}]
set_property -dict {LOC BF25 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[26]}]
set_property -dict {LOC BE25 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[27]}]
set_property -dict {LOC BE28 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[28]}]
set_property -dict {LOC BD28 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[29]}]
set_property -dict {LOC BF27 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[30]}]
set_property -dict {LOC BE27 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[31]}]
set_property -dict {LOC AM14 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[32]}]
set_property -dict {LOC AL14 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[33]}]
set_property -dict {LOC AM15 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[34]}]
set_property -dict {LOC AL15 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[35]}]
set_property -dict {LOC AN13 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[36]}]
set_property -dict {LOC AN14 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[37]}]
set_property -dict {LOC AP14 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[38]}]
set_property -dict {LOC AP15 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[39]}]
set_property -dict {LOC AV16 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[40]}]
set_property -dict {LOC AU16 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[41]}]
set_property -dict {LOC AU15 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[42]}]
set_property -dict {LOC AT15 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[43]}]
set_property -dict {LOC AV13 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[44]}]
set_property -dict {LOC AU13 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[45]}]
set_property -dict {LOC AW15 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[46]}]
set_property -dict {LOC AW16 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[47]}]
set_property -dict {LOC BA13 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[48]}]
set_property -dict {LOC AY13 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[49]}]
set_property -dict {LOC BA14 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[50]}]
set_property -dict {LOC BA15 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[51]}]
set_property -dict {LOC AY15 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[52]}]
set_property -dict {LOC AY16 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[53]}]
set_property -dict {LOC AY11 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[54]}]
set_property -dict {LOC AY12 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[55]}]
set_property -dict {LOC BC13 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[56]}]
set_property -dict {LOC BC14 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[57]}]
set_property -dict {LOC BD14 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[58]}]
set_property -dict {LOC BD15 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[59]}]
set_property -dict {LOC BE16 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[60]}]
set_property -dict {LOC BD16 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[61]}]
set_property -dict {LOC BF15 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[62]}]
set_property -dict {LOC BE15 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[63]}]
set_property -dict {LOC BC18 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[64]}]
set_property -dict {LOC BB19 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[65]}]
set_property -dict {LOC BC17 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[66]}]
set_property -dict {LOC BB17 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[67]}]
set_property -dict {LOC BE18 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[68]}]
set_property -dict {LOC BD18 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[69]}]
set_property -dict {LOC BF18 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[70]}]
set_property -dict {LOC BF19 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c0_dq[71]}]
set_property -dict {LOC AM26 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_t[0]}]
set_property -dict {LOC AN26 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_c[0]}]
set_property -dict {LOC AP25 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_t[1]}]
set_property -dict {LOC AP26 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_c[1]}]
set_property -dict {LOC AR25 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_t[2]}]
set_property -dict {LOC AT25 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_c[2]}]
set_property -dict {LOC AV26 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_t[3]}]
set_property -dict {LOC AW26 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_c[3]}]
set_property -dict {LOC AW25 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_t[4]}]
set_property -dict {LOC AY25 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_c[4]}]
set_property -dict {LOC BA25 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_t[5]}]
set_property -dict {LOC BB25 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_c[5]}]
set_property -dict {LOC BD26 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_t[6]}]
set_property -dict {LOC BE26 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_c[6]}]
set_property -dict {LOC BF28 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_t[7]}]
set_property -dict {LOC BF29 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_c[7]}]
set_property -dict {LOC AP13 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_t[8]}]
set_property -dict {LOC AR13 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_c[8]}]
set_property -dict {LOC AR16 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_t[9]}]
set_property -dict {LOC AR15 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_c[9]}]
set_property -dict {LOC AU14 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_t[10]}]
set_property -dict {LOC AV14 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_c[10]}]
set_property -dict {LOC AW14 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_t[11]}]
set_property -dict {LOC AW13 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_c[11]}]
set_property -dict {LOC BB15 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_t[12]}]
set_property -dict {LOC BB14 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_c[12]}]
set_property -dict {LOC BA12 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_t[13]}]
set_property -dict {LOC BB12 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_c[13]}]
set_property -dict {LOC BD13 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_t[14]}]
set_property -dict {LOC BE13 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_c[14]}]
set_property -dict {LOC BF14 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_t[15]}]
set_property -dict {LOC BF13 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_c[15]}]
set_property -dict {LOC BC19 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_t[16]}]
set_property -dict {LOC BD19 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_c[16]}]
set_property -dict {LOC BE17 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_t[17]}]
set_property -dict {LOC BF17 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c0_dqs_c[17]}]

# DDR4 C1
set_property -dict {LOC AY33 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_adr[0]}]
set_property -dict {LOC BA33 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_adr[1]}]
set_property -dict {LOC AV34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_adr[2]}]
set_property -dict {LOC AW34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_adr[3]}]
set_property -dict {LOC AV33 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_adr[4]}]
set_property -dict {LOC AW33 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_adr[5]}]
set_property -dict {LOC AU34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_adr[6]}]
set_property -dict {LOC AT33 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_adr[7]}]
set_property -dict {LOC AT34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_adr[8]}]
set_property -dict {LOC AP33 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_adr[9]}]
set_property -dict {LOC AR33 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_adr[10]}]
set_property -dict {LOC AN34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_adr[11]}]
set_property -dict {LOC AP34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_adr[12]}]
set_property -dict {LOC AL32 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_adr[13]}]
set_property -dict {LOC AM32 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_adr[14]}]
set_property -dict {LOC AL34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_adr[15]}]
set_property -dict {LOC AM34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_adr[16]}]
# set_property -dict {LOC AL33 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_adr[17]}]
set_property -dict {LOC BA34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_ba[0]}]
set_property -dict {LOC BB34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_ba[1]}]
set_property -dict {LOC AY35 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_bg[0]}]
set_property -dict {LOC AY36 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_bg[1]}]
set_property -dict {LOC AW35 IOSTANDARD DIFF_SSTL12_DCI } [get_ports {ddr4_c1_ck_t[0]}]
set_property -dict {LOC AW36 IOSTANDARD DIFF_SSTL12_DCI } [get_ports {ddr4_c1_ck_c[0]}]
set_property -dict {LOC BE36 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_cke[0]}]
# set_property -dict {LOC BB37 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_cke[1]}]
set_property -dict {LOC BE35 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_cs_n[0]}]
# set_property -dict {LOC BD36 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_cs_n[1]}]
# set_property -dict {LOC BD34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_cs_n[2]}]
# set_property -dict {LOC BD35 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_cs_n[3]}]
# set_property -dict {LOC AN33 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_c[0]}]
# set_property -dict {LOC AD30 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_c[1]}]
# set_property -dict {LOC AT32 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_c[2]}]
set_property -dict {LOC BF35 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_act_n}]
set_property -dict {LOC BC37 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_odt[0]}]
# set_property -dict {LOC BA35 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_odt[1]}]
set_property -dict {LOC BB35 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c1_par}]
set_property -dict {LOC BC34 IOSTANDARD LVCMOS12 DRIVE 8} [get_ports {ddr4_c1_reset_n}]

set_property -dict {LOC W34  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[0]}]
set_property -dict {LOC W33  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[1]}]
set_property -dict {LOC Y33  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[2]}]
set_property -dict {LOC Y32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[3]}]
set_property -dict {LOC Y30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[4]}]
set_property -dict {LOC W30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[5]}]
set_property -dict {LOC AB34 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[6]}]
set_property -dict {LOC AA34 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[7]}]
set_property -dict {LOC AD34 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[8]}]
set_property -dict {LOC AC34 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[9]}]
set_property -dict {LOC AC33 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[10]}]
set_property -dict {LOC AC32 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[11]}]
set_property -dict {LOC AF30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[12]}]
set_property -dict {LOC AE30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[13]}]
set_property -dict {LOC AE33 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[14]}]
set_property -dict {LOC AD33 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[15]}]
set_property -dict {LOC AF33 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[16]}]
set_property -dict {LOC AF32 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[17]}]
set_property -dict {LOC AG32 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[18]}]
set_property -dict {LOC AG31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[19]}]
set_property -dict {LOC AG34 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[20]}]
set_property -dict {LOC AF34 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[21]}]
set_property -dict {LOC AJ33 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[22]}]
set_property -dict {LOC AH33 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[23]}]
set_property -dict {LOC AK31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[24]}]
set_property -dict {LOC AJ31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[25]}]
set_property -dict {LOC AG30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[26]}]
set_property -dict {LOC AG29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[27]}]
set_property -dict {LOC AJ30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[28]}]
set_property -dict {LOC AJ29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[29]}]
set_property -dict {LOC AK28 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[30]}]
set_property -dict {LOC AJ28 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[31]}]
set_property -dict {LOC AL30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[32]}]
set_property -dict {LOC AL29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[33]}]
set_property -dict {LOC AN31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[34]}]
set_property -dict {LOC AM31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[35]}]
set_property -dict {LOC AP29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[36]}]
set_property -dict {LOC AN29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[37]}]
set_property -dict {LOC AR30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[38]}]
set_property -dict {LOC AP30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[39]}]
set_property -dict {LOC AT30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[40]}]
set_property -dict {LOC AT29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[41]}]
set_property -dict {LOC AU31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[42]}]
set_property -dict {LOC AU30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[43]}]
set_property -dict {LOC AV32 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[44]}]
set_property -dict {LOC AU32 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[45]}]
set_property -dict {LOC AW31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[46]}]
set_property -dict {LOC AV31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[47]}]
set_property -dict {LOC AY32 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[48]}]
set_property -dict {LOC AY31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[49]}]
set_property -dict {LOC BA30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[50]}]
set_property -dict {LOC AY30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[51]}]
set_property -dict {LOC BB29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[52]}]
set_property -dict {LOC BA29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[53]}]
set_property -dict {LOC BB31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[54]}]
set_property -dict {LOC BB30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[55]}]
set_property -dict {LOC BD29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[56]}]
set_property -dict {LOC BC29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[57]}]
set_property -dict {LOC BE33 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[58]}]
set_property -dict {LOC BD33 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[59]}]
set_property -dict {LOC BF30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[60]}]
set_property -dict {LOC BE30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[61]}]
set_property -dict {LOC BE32 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[62]}]
set_property -dict {LOC BE31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[63]}]
set_property -dict {LOC BC38 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[64]}]
set_property -dict {LOC BB38 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[65]}]
set_property -dict {LOC BD39 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[66]}]
set_property -dict {LOC BC39 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[67]}]
set_property -dict {LOC BF37 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[68]}]
set_property -dict {LOC BE37 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[69]}]
set_property -dict {LOC BF38 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[70]}]
set_property -dict {LOC BE38 IOSTANDARD POD12_DCI       } [get_ports {ddr4_c1_dq[71]}]
set_property -dict {LOC W31  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_t[0]}]
set_property -dict {LOC Y31  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_c[0]}]
set_property -dict {LOC AA32 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_t[1]}]
set_property -dict {LOC AA33 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_c[1]}]
set_property -dict {LOC AC31 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_t[2]}]
set_property -dict {LOC AD31 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_c[2]}]
set_property -dict {LOC AE31 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_t[3]}]
set_property -dict {LOC AE32 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_c[3]}]
set_property -dict {LOC AH31 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_t[4]}]
set_property -dict {LOC AH32 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_c[4]}]
set_property -dict {LOC AH34 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_t[5]}]
set_property -dict {LOC AJ34 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_c[5]}]
set_property -dict {LOC AH28 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_t[6]}]
set_property -dict {LOC AH29 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_c[6]}]
set_property -dict {LOC AJ27 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_t[7]}]
set_property -dict {LOC AK27 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_c[7]}]
set_property -dict {LOC AM29 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_t[8]}]
set_property -dict {LOC AM30 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_c[8]}]
set_property -dict {LOC AP31 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_t[9]}]
set_property -dict {LOC AR31 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_c[9]}]
set_property -dict {LOC AU29 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_t[10]}]
set_property -dict {LOC AV29 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_c[10]}]
set_property -dict {LOC AW29 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_t[11]}]
set_property -dict {LOC AW30 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_c[11]}]
set_property -dict {LOC BA32 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_t[12]}]
set_property -dict {LOC BB32 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_c[12]}]
set_property -dict {LOC BC31 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_t[13]}]
set_property -dict {LOC BC32 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_c[13]}]
set_property -dict {LOC BD30 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_t[14]}]
set_property -dict {LOC BD31 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_c[14]}]
set_property -dict {LOC BF32 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_t[15]}]
set_property -dict {LOC BF33 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_c[15]}]
set_property -dict {LOC BD40 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_t[16]}]
set_property -dict {LOC BE40 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_c[16]}]
set_property -dict {LOC BF39 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_t[17]}]
set_property -dict {LOC BF40 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c1_dqs_c[17]}]

# DDR4 C2
set_property -dict {LOC A37  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_adr[0]}]
set_property -dict {LOC A38  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_adr[1]}]
set_property -dict {LOC B35  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_adr[2]}]
set_property -dict {LOC A35  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_adr[3]}]
set_property -dict {LOC E35  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_adr[4]}]
set_property -dict {LOC D35  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_adr[5]}]
set_property -dict {LOC E37  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_adr[6]}]
set_property -dict {LOC B34  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_adr[7]}]
set_property -dict {LOC A34  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_adr[8]}]
set_property -dict {LOC D34  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_adr[9]}]
set_property -dict {LOC C34  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_adr[10]}]
set_property -dict {LOC D33  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_adr[11]}]
set_property -dict {LOC C33  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_adr[12]}]
set_property -dict {LOC C32  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_adr[13]}]
set_property -dict {LOC B32  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_adr[14]}]
set_property -dict {LOC D31  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_adr[15]}]
set_property -dict {LOC C31  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_adr[16]}]
# set_property -dict {LOC B31  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_adr[17]}]
set_property -dict {LOC C36  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_ba[0]}]
set_property -dict {LOC C37  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_ba[1]}]
set_property -dict {LOC E36  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_bg[0]}]
set_property -dict {LOC D36  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_bg[1]}]
set_property -dict {LOC B36  IOSTANDARD DIFF_SSTL12_DCI } [get_ports {ddr4_c2_ck_t[0]}]
set_property -dict {LOC B37  IOSTANDARD DIFF_SSTL12_DCI } [get_ports {ddr4_c2_ck_c[0]}]
set_property -dict {LOC A40  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_cke[0]}]
# set_property -dict {LOC B39  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_cke[1]}]
set_property -dict {LOC D39  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_cs_n[0]}]
# set_property -dict {LOC B40  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_cs_n[1]}]
# set_property -dict {LOC D40  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_cs_n[2]}]
# set_property -dict {LOC E39  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_cs_n[3]}]
# set_property -dict {LOC A33  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_c[0]}]
# set_property -dict {LOC K34  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_c[1]}]
# set_property -dict {LOC E26  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_c[2]}]
set_property -dict {LOC F38  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_act_n}]
set_property -dict {LOC A39  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_odt[0]}]
# set_property -dict {LOC C38  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_odt[1]}]
set_property -dict {LOC C39  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c2_par}]
set_property -dict {LOC E40  IOSTANDARD LVCMOS12 DRIVE 8} [get_ports {ddr4_c2_reset_n}]

set_property -dict {LOC E33  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[0]}]
set_property -dict {LOC F33  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[1]}]
set_property -dict {LOC E32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[2]}]
set_property -dict {LOC F32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[3]}]
set_property -dict {LOC G32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[4]}]
set_property -dict {LOC H32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[5]}]
set_property -dict {LOC G31  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[6]}]
set_property -dict {LOC H31  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[7]}]
set_property -dict {LOC K33  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[8]}]
set_property -dict {LOC L33  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[9]}]
set_property -dict {LOC J31  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[10]}]
set_property -dict {LOC K31  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[11]}]
set_property -dict {LOC L30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[12]}]
set_property -dict {LOC M30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[13]}]
set_property -dict {LOC K32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[14]}]
set_property -dict {LOC L32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[15]}]
set_property -dict {LOC N33  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[16]}]
set_property -dict {LOC N32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[17]}]
set_property -dict {LOC N31  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[18]}]
set_property -dict {LOC P31  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[19]}]
set_property -dict {LOC N34  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[20]}]
set_property -dict {LOC P34  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[21]}]
set_property -dict {LOC R32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[22]}]
set_property -dict {LOC R31  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[23]}]
set_property -dict {LOC T30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[24]}]
set_property -dict {LOC U30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[25]}]
set_property -dict {LOC U31  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[26]}]
set_property -dict {LOC V31  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[27]}]
set_property -dict {LOC T32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[28]}]
set_property -dict {LOC U32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[29]}]
set_property -dict {LOC R33  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[30]}]
set_property -dict {LOC T33  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[31]}]
set_property -dict {LOC A30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[32]}]
set_property -dict {LOC B30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[33]}]
set_property -dict {LOC A29  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[34]}]
set_property -dict {LOC B29  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[35]}]
set_property -dict {LOC D30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[36]}]
set_property -dict {LOC E30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[37]}]
set_property -dict {LOC C29  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[38]}]
set_property -dict {LOC D29  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[39]}]
set_property -dict {LOC D28  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[40]}]
set_property -dict {LOC E28  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[41]}]
set_property -dict {LOC E27  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[42]}]
set_property -dict {LOC F27  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[43]}]
set_property -dict {LOC G29  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[44]}]
set_property -dict {LOC H29  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[45]}]
set_property -dict {LOC G27  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[46]}]
set_property -dict {LOC G26  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[47]}]
set_property -dict {LOC J29  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[48]}]
set_property -dict {LOC J28  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[49]}]
set_property -dict {LOC H28  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[50]}]
set_property -dict {LOC H27  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[51]}]
set_property -dict {LOC L27  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[52]}]
set_property -dict {LOC M27  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[53]}]
set_property -dict {LOC K28  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[54]}]
set_property -dict {LOC L28  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[55]}]
set_property -dict {LOC N26  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[56]}]
set_property -dict {LOC P26  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[57]}]
set_property -dict {LOC N28  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[58]}]
set_property -dict {LOC P28  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[59]}]
set_property -dict {LOC R26  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[60]}]
set_property -dict {LOC T26  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[61]}]
set_property -dict {LOC R27  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[62]}]
set_property -dict {LOC T27  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[63]}]
set_property -dict {LOC F35  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[64]}]
set_property -dict {LOC F34  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[65]}]
set_property -dict {LOC G34  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[66]}]
set_property -dict {LOC H34  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[67]}]
set_property -dict {LOC J36  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[68]}]
set_property -dict {LOC J35  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[69]}]
set_property -dict {LOC F37  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[70]}]
set_property -dict {LOC G37  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c2_dq[71]}]
set_property -dict {LOC J33  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_t[0]}]
set_property -dict {LOC H33  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_c[0]}]
set_property -dict {LOC G30  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_t[1]}]
set_property -dict {LOC F30  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_c[1]}]
set_property -dict {LOC K30  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_t[2]}]
set_property -dict {LOC J30  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_c[2]}]
set_property -dict {LOC M31  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_t[3]}]
set_property -dict {LOC M32  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_c[3]}]
set_property -dict {LOC M34  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_t[4]}]
set_property -dict {LOC L34  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_c[4]}]
set_property -dict {LOC R30  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_t[5]}]
set_property -dict {LOC P30  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_c[5]}]
set_property -dict {LOC V32  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_t[6]}]
set_property -dict {LOC V33  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_c[6]}]
set_property -dict {LOC U34  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_t[7]}]
set_property -dict {LOC T34  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_c[7]}]
set_property -dict {LOC A27  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_t[8]}]
set_property -dict {LOC A28  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_c[8]}]
set_property -dict {LOC C27  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_t[9]}]
set_property -dict {LOC B27  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_c[9]}]
set_property -dict {LOC F28  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_t[10]}]
set_property -dict {LOC F29  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_c[10]}]
set_property -dict {LOC J26  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_t[11]}]
set_property -dict {LOC H26  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_c[11]}]
set_property -dict {LOC K26  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_t[12]}]
set_property -dict {LOC K27  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_c[12]}]
set_property -dict {LOC M29  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_t[13]}]
set_property -dict {LOC L29  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_c[13]}]
set_property -dict {LOC P29  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_t[14]}]
set_property -dict {LOC N29  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_c[14]}]
set_property -dict {LOC T28  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_t[15]}]
set_property -dict {LOC R28  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_c[15]}]
set_property -dict {LOC H36  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_t[16]}]
set_property -dict {LOC G36  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_c[16]}]
set_property -dict {LOC H37  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_t[17]}]
set_property -dict {LOC H38  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c2_dqs_c[17]}]

# DDR4 C3
set_property -dict {LOC F20  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_adr[0]}]
set_property -dict {LOC F19  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_adr[1]}]
set_property -dict {LOC E21  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_adr[2]}]
set_property -dict {LOC E20  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_adr[3]}]
set_property -dict {LOC F18  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_adr[4]}]
set_property -dict {LOC F17  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_adr[5]}]
set_property -dict {LOC G21  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_adr[6]}]
set_property -dict {LOC D19  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_adr[7]}]
set_property -dict {LOC C19  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_adr[8]}]
set_property -dict {LOC D21  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_adr[9]}]
set_property -dict {LOC D20  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_adr[10]}]
set_property -dict {LOC C21  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_adr[11]}]
set_property -dict {LOC B21  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_adr[12]}]
set_property -dict {LOC B19  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_adr[13]}]
set_property -dict {LOC A19  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_adr[14]}]
set_property -dict {LOC B20  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_adr[15]}]
set_property -dict {LOC A20  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_adr[16]}]
# set_property -dict {LOC A18  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_adr[17]}]
set_property -dict {LOC H19  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_ba[0]}]
set_property -dict {LOC H18  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_ba[1]}]
set_property -dict {LOC G20  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_bg[0]}]
set_property -dict {LOC G19  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_bg[1]}]
set_property -dict {LOC E18  IOSTANDARD DIFF_SSTL12_DCI } [get_ports {ddr4_c3_ck_t[0]}]
set_property -dict {LOC E17  IOSTANDARD DIFF_SSTL12_DCI } [get_ports {ddr4_c3_ck_c[0]}]
set_property -dict {LOC K20  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_cke[0]}]
# set_property -dict {LOC J21  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_cke[1]}]
set_property -dict {LOC L18  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_cs_n[0]}]
# set_property -dict {LOC L20  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_cs_n[1]}]
# set_property -dict {LOC K17  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_cs_n[2]}]
# set_property -dict {LOC L19  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_cs_n[3]}]
# set_property -dict {LOC C18  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_c[0]}]
# set_property -dict {LOC F25  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_c[1]}]
# set_property -dict {LOC D14  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_c[2]}]
set_property -dict {LOC K21  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_act_n}]
set_property -dict {LOC H21  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_odt[0]}]
# set_property -dict {LOC J20  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_odt[1]}]
set_property -dict {LOC J19  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_c3_par}]
set_property -dict {LOC L17  IOSTANDARD LVCMOS12 DRIVE 8} [get_ports {ddr4_c3_reset_n}]

set_property -dict {LOC A25  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[0]}]
set_property -dict {LOC B25  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[1]}]
set_property -dict {LOC A24  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[2]}]
set_property -dict {LOC B24  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[3]}]
set_property -dict {LOC B26  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[4]}]
set_property -dict {LOC C26  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[5]}]
set_property -dict {LOC C23  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[6]}]
set_property -dict {LOC C24  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[7]}]
set_property -dict {LOC D25  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[8]}]
set_property -dict {LOC E25  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[9]}]
set_property -dict {LOC D23  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[10]}]
set_property -dict {LOC D24  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[11]}]
set_property -dict {LOC F22  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[12]}]
set_property -dict {LOC G22  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[13]}]
set_property -dict {LOC F23  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[14]}]
set_property -dict {LOC F24  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[15]}]
set_property -dict {LOC H24  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[16]}]
set_property -dict {LOC J24  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[17]}]
set_property -dict {LOC H23  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[18]}]
set_property -dict {LOC J23  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[19]}]
set_property -dict {LOC K23  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[20]}]
set_property -dict {LOC L23  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[21]}]
set_property -dict {LOC K22  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[22]}]
set_property -dict {LOC L22  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[23]}]
set_property -dict {LOC P25  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[24]}]
set_property -dict {LOC R25  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[25]}]
set_property -dict {LOC M24  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[26]}]
set_property -dict {LOC M25  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[27]}]
set_property -dict {LOC N23  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[28]}]
set_property -dict {LOC P23  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[29]}]
set_property -dict {LOC M22  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[30]}]
set_property -dict {LOC N22  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[31]}]
set_property -dict {LOC A17  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[32]}]
set_property -dict {LOC B17  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[33]}]
set_property -dict {LOC B16  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[34]}]
set_property -dict {LOC C16  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[35]}]
set_property -dict {LOC A13  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[36]}]
set_property -dict {LOC A14  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[37]}]
set_property -dict {LOC B14  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[38]}]
set_property -dict {LOC C14  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[39]}]
set_property -dict {LOC D16  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[40]}]
set_property -dict {LOC E16  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[41]}]
set_property -dict {LOC D15  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[42]}]
set_property -dict {LOC E15  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[43]}]
set_property -dict {LOC E13  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[44]}]
set_property -dict {LOC F13  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[45]}]
set_property -dict {LOC F15  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[46]}]
set_property -dict {LOC G15  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[47]}]
set_property -dict {LOC J15  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[48]}]
set_property -dict {LOC J16  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[49]}]
set_property -dict {LOC H14  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[50]}]
set_property -dict {LOC J14  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[51]}]
set_property -dict {LOC H13  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[52]}]
set_property -dict {LOC J13  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[53]}]
set_property -dict {LOC K15  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[54]}]
set_property -dict {LOC K16  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[55]}]
set_property -dict {LOC M16  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[56]}]
set_property -dict {LOC N16  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[57]}]
set_property -dict {LOC L14  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[58]}]
set_property -dict {LOC M14  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[59]}]
set_property -dict {LOC P15  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[60]}]
set_property -dict {LOC R15  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[61]}]
set_property -dict {LOC N14  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[62]}]
set_property -dict {LOC P14  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[63]}]
set_property -dict {LOC M21  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[64]}]
set_property -dict {LOC N21  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[65]}]
set_property -dict {LOC P20  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[66]}]
set_property -dict {LOC R20  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[67]}]
set_property -dict {LOC M19  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[68]}]
set_property -dict {LOC M20  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[69]}]
set_property -dict {LOC N18  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[70]}]
set_property -dict {LOC P18  IOSTANDARD POD12_DCI       } [get_ports {ddr4_c3_dq[71]}]
set_property -dict {LOC A23  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_t[0]}]
set_property -dict {LOC A22  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_c[0]}]
set_property -dict {LOC C22  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_t[1]}]
set_property -dict {LOC B22  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_c[1]}]
set_property -dict {LOC E23  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_t[2]}]
set_property -dict {LOC E22  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_c[2]}]
set_property -dict {LOC G25  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_t[3]}]
set_property -dict {LOC G24  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_c[3]}]
set_property -dict {LOC K25  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_t[4]}]
set_property -dict {LOC J25  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_c[4]}]
set_property -dict {LOC L25  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_t[5]}]
set_property -dict {LOC L24  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_c[5]}]
set_property -dict {LOC P24  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_t[6]}]
set_property -dict {LOC N24  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_c[6]}]
set_property -dict {LOC R21  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_t[7]}]
set_property -dict {LOC P21  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_c[7]}]
set_property -dict {LOC B15  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_t[8]}]
set_property -dict {LOC A15  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_c[8]}]
set_property -dict {LOC D13  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_t[9]}]
set_property -dict {LOC C13  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_c[9]}]
set_property -dict {LOC G17  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_t[10]}]
set_property -dict {LOC G16  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_c[10]}]
set_property -dict {LOC G14  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_t[11]}]
set_property -dict {LOC F14  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_c[11]}]
set_property -dict {LOC H17  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_t[12]}]
set_property -dict {LOC H16  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_c[12]}]
set_property -dict {LOC L13  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_t[13]}]
set_property -dict {LOC K13  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_c[13]}]
set_property -dict {LOC R16  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_t[14]}]
set_property -dict {LOC P16  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_c[14]}]
set_property -dict {LOC P13  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_t[15]}]
set_property -dict {LOC N13  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_c[15]}]
set_property -dict {LOC P19  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_t[16]}]
set_property -dict {LOC N19  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_c[16]}]
set_property -dict {LOC N17  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_t[17]}]
set_property -dict {LOC M17  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_c3_dqs_c[17]}]
