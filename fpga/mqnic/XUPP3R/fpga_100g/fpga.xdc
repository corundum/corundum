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
#set_property -dict {LOC AV18 IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_1_p]
#set_property -dict {LOC AW18 IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_1_n]
#create_clock -period 10.000 -name clk_ddr_1 [get_ports clk_ddr_1_p]

# 100 MHz DDR4 module 2 clock from Si5338 A ch 1
#set_property -dict {LOC BB36 IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_2_p]
#set_property -dict {LOC BC36 IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_2_n]
#create_clock -period 10.000 -name clk_ddr_2 [get_ports clk_ddr_2_p]

# 100 MHz DDR4 module 3 clock from Si5338 A ch 2
#set_property -dict {LOC E38  IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_3_p]
#set_property -dict {LOC D38  IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_3_n]
#create_clock -period 10.000 -name clk_ddr_3 [get_ports clk_ddr_3_p]

# 100 MHz DDR4 module 4 clock from Si5338 A ch 3
#set_property -dict {LOC K18  IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_4_p]
#set_property -dict {LOC J18  IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_4_n]
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
#create_clock -period 3.103 -name qsfp0_mgt_refclk_b0 [get_ports qsfp0_mgt_refclk_b0_p]

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
#create_clock -period 3.103 -name qsfp1_mgt_refclk_b0 [get_ports qsfp1_mgt_refclk_b0_p]

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
#create_clock -period 3.103 -name qsfp2_mgt_refclk_b0 [get_ports qsfp2_mgt_refclk_b0_p]

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
#create_clock -period 3.103 -name qsfp3_mgt_refclk_b0 [get_ports qsfp3_mgt_refclk_b0_p]

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
