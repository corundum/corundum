# XDC constraints for the Cisco Nexus K3P-Q
# part: xcku3p-ffvb676-2-e

# General configuration
set_property CFGBVS GND                                      [current_design]
set_property CONFIG_VOLTAGE 1.8                              [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true                 [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN Pullup               [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 72.9                [current_design]
set_property CONFIG_MODE SPIx4                               [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4                 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE Yes              [current_design]
set_property BITSTREAM.CONFIG.OVERTEMPSHUTDOWN Enable        [current_design]

# 10 MHz TXCO
#set_property -dict {LOC E13  IOSTANDARD LVCMOS33} [get_ports clk_10mhz]
#create_clock -period 100 -name clk_100mhz [get_ports clk_10mhz]

# LEDs
set_property -dict {LOC AB15 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {qsfp_0_led_green}]
set_property -dict {LOC AC14 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {qsfp_0_led_orange}]
set_property -dict {LOC AA15 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {qsfp_1_led_green}]
set_property -dict {LOC AB14 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {qsfp_1_led_orange}]
set_property -dict {LOC C12  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {sma_led_green}]
set_property -dict {LOC C13  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {sma_led_red}]

set_false_path -to [get_ports {qsfp_0_led_green qsfp_0_led_orange qsfp_1_led_green qsfp_1_led_orange sma_led_green sma_led_orange}]
set_output_delay 0 [get_ports {qsfp_0_led_green qsfp_0_led_orange qsfp_1_led_green qsfp_1_led_orange sma_led_green sma_led_orange}]

# GPIO
#set_property -dict {LOC   IOSTANDARD LVCMOS18} [get_ports gpio[0]]
#set_property -dict {LOC   IOSTANDARD LVCMOS18} [get_ports gpio[1]]
#set_property -dict {LOC   IOSTANDARD LVCMOS18} [get_ports gpio[2]]
#set_property -dict {LOC   IOSTANDARD LVCMOS18} [get_ports gpio[3]]
#set_property -dict {LOC   IOSTANDARD LVCMOS18} [get_ports gpio[4]]

# SMA
set_property -dict {LOC AD15 IOSTANDARD LVCMOS33} [get_ports sma_in]
set_property -dict {LOC AF14 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 12} [get_ports sma_out]
set_property -dict {LOC AD14 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports sma_out_en]
set_property -dict {LOC AB16 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports sma_term_en]

set_false_path -to [get_ports {sma_out sma_out_en sma_term_en}]
set_output_delay 0 [get_ports {sma_out sma_out_en sma_term_en}]
set_false_path -from [get_ports {sma_in}]
set_input_delay 0 [get_ports {sma_in}]

# Config
#set_property -dict {LOC C14  IOSTANDARD LVCMOS33} [get_ports ddr_npres]

# QSFP28 Interfaces
set_property -dict {LOC M2  } [get_ports qsfp_0_rx_0_p] ;# MGTYRXP0_226 GTYE4_CHANNEL_X0Y8 / GTYE4_COMMON_X0Y2
set_property -dict {LOC M1  } [get_ports qsfp_0_rx_0_n] ;# MGTYRXN0_226 GTYE4_CHANNEL_X0Y8 / GTYE4_COMMON_X0Y2
set_property -dict {LOC N5  } [get_ports qsfp_0_tx_0_p] ;# MGTYTXP0_226 GTYE4_CHANNEL_X0Y8 / GTYE4_COMMON_X0Y2
set_property -dict {LOC N4  } [get_ports qsfp_0_tx_0_n] ;# MGTYTXN0_226 GTYE4_CHANNEL_X0Y8 / GTYE4_COMMON_X0Y2
set_property -dict {LOC K2  } [get_ports qsfp_0_rx_1_p] ;# MGTYRXP1_226 GTYE4_CHANNEL_X0Y9 / GTYE4_COMMON_X0Y2
set_property -dict {LOC K1  } [get_ports qsfp_0_rx_1_n] ;# MGTYRXN1_226 GTYE4_CHANNEL_X0Y9 / GTYE4_COMMON_X0Y2
set_property -dict {LOC L5  } [get_ports qsfp_0_tx_1_p] ;# MGTYTXP1_226 GTYE4_CHANNEL_X0Y9 / GTYE4_COMMON_X0Y2
set_property -dict {LOC L4  } [get_ports qsfp_0_tx_1_n] ;# MGTYTXN1_226 GTYE4_CHANNEL_X0Y9 / GTYE4_COMMON_X0Y2
set_property -dict {LOC F2  } [get_ports qsfp_0_rx_2_p] ;# MGTYRXP3_226 GTYE4_CHANNEL_X0Y11 / GTYE4_COMMON_X0Y2
set_property -dict {LOC F1  } [get_ports qsfp_0_rx_2_n] ;# MGTYRXN3_226 GTYE4_CHANNEL_X0Y11 / GTYE4_COMMON_X0Y2
set_property -dict {LOC G5  } [get_ports qsfp_0_tx_2_p] ;# MGTYTXP3_226 GTYE4_CHANNEL_X0Y11 / GTYE4_COMMON_X0Y2
set_property -dict {LOC G4  } [get_ports qsfp_0_tx_2_n] ;# MGTYTXN3_226 GTYE4_CHANNEL_X0Y11 / GTYE4_COMMON_X0Y2
set_property -dict {LOC H2  } [get_ports qsfp_0_rx_3_p] ;# MGTYRXP2_226 GTYE4_CHANNEL_X0Y10 / GTYE4_COMMON_X0Y2
set_property -dict {LOC H1  } [get_ports qsfp_0_rx_3_n] ;# MGTYRXN2_226 GTYE4_CHANNEL_X0Y10 / GTYE4_COMMON_X0Y2
set_property -dict {LOC J5  } [get_ports qsfp_0_tx_3_p] ;# MGTYTXP2_226 GTYE4_CHANNEL_X0Y10 / GTYE4_COMMON_X0Y2
set_property -dict {LOC J4  } [get_ports qsfp_0_tx_3_n] ;# MGTYTXN2_226 GTYE4_CHANNEL_X0Y10 / GTYE4_COMMON_X0Y2
set_property -dict {LOC W16  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports qsfp_0_modsell]
set_property -dict {LOC Y15  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports qsfp_0_resetl]
set_property -dict {LOC W14  IOSTANDARD LVCMOS33 PULLUP true} [get_ports qsfp_0_modprsl]
set_property -dict {LOC W15  IOSTANDARD LVCMOS33 PULLUP true} [get_ports qsfp_0_intl]
set_property -dict {LOC Y13  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports qsfp_0_lpmode]
set_property -dict {LOC AC13 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12 PULLUP true} [get_ports qsfp_0_i2c_sda]
set_property -dict {LOC Y16  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12 PULLUP true} [get_ports qsfp_0_i2c_scl]

set_false_path -to [get_ports {qsfp_0_modsell qsfp_0_resetl qsfp_0_lpmode}]
set_output_delay 0 [get_ports {qsfp_0_modsell qsfp_0_resetl qsfp_0_lpmode}]
set_false_path -from [get_ports {qsfp_0_modprsl qsfp_0_intl}]
set_input_delay 0 [get_ports {qsfp_0_modprsl qsfp_0_intl}]

set_false_path -to [get_ports {qsfp_0_i2c_sda qsfp_0_i2c_scl}]
set_output_delay 0 [get_ports {qsfp_0_i2c_sda qsfp_0_i2c_scl}]
set_false_path -from [get_ports {qsfp_0_i2c_sda qsfp_0_i2c_scl}]
set_input_delay 0 [get_ports {qsfp_0_i2c_sda qsfp_0_i2c_scl}]

set_property -dict {LOC D2  } [get_ports qsfp_1_rx_0_p] ;# MGTYRXP0_227 GTYE4_CHANNEL_X0Y12 / GTYE4_COMMON_X0Y3
set_property -dict {LOC D1  } [get_ports qsfp_1_rx_0_n] ;# MGTYRXN0_227 GTYE4_CHANNEL_X0Y12 / GTYE4_COMMON_X0Y3
set_property -dict {LOC F7  } [get_ports qsfp_1_tx_0_p] ;# MGTYTXP0_227 GTYE4_CHANNEL_X0Y12 / GTYE4_COMMON_X0Y3
set_property -dict {LOC F6  } [get_ports qsfp_1_tx_0_n] ;# MGTYTXN0_227 GTYE4_CHANNEL_X0Y12 / GTYE4_COMMON_X0Y3
set_property -dict {LOC C4  } [get_ports qsfp_1_rx_1_p] ;# MGTYRXP1_227 GTYE4_CHANNEL_X0Y13 / GTYE4_COMMON_X0Y3
set_property -dict {LOC C3  } [get_ports qsfp_1_rx_1_n] ;# MGTYRXN1_227 GTYE4_CHANNEL_X0Y13 / GTYE4_COMMON_X0Y3
set_property -dict {LOC E5  } [get_ports qsfp_1_tx_1_p] ;# MGTYTXP1_227 GTYE4_CHANNEL_X0Y13 / GTYE4_COMMON_X0Y3
set_property -dict {LOC E4  } [get_ports qsfp_1_tx_1_n] ;# MGTYTXN1_227 GTYE4_CHANNEL_X0Y13 / GTYE4_COMMON_X0Y3
set_property -dict {LOC A4  } [get_ports qsfp_1_rx_2_p] ;# MGTYRXP3_227 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3
set_property -dict {LOC A3  } [get_ports qsfp_1_rx_2_n] ;# MGTYRXN3_227 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3
set_property -dict {LOC B7  } [get_ports qsfp_1_tx_2_p] ;# MGTYTXP3_227 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3
set_property -dict {LOC B6  } [get_ports qsfp_1_tx_2_n] ;# MGTYTXN3_227 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3
set_property -dict {LOC B2  } [get_ports qsfp_1_rx_3_p] ;# MGTYRXP2_227 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3
set_property -dict {LOC B1  } [get_ports qsfp_1_rx_3_n] ;# MGTYRXN2_227 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3
set_property -dict {LOC D7  } [get_ports qsfp_1_tx_3_p] ;# MGTYTXP2_227 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3
set_property -dict {LOC D6  } [get_ports qsfp_1_tx_3_n] ;# MGTYTXN2_227 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AA14 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports qsfp_1_modsell]
set_property -dict {LOC AE13 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports qsfp_1_resetl]
set_property -dict {LOC A13  IOSTANDARD LVCMOS33 PULLUP true} [get_ports qsfp_1_modprsl]
set_property -dict {LOC A14  IOSTANDARD LVCMOS33 PULLUP true} [get_ports qsfp_1_intl]
set_property -dict {LOC B14  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports qsfp_1_lpmode]
set_property -dict {LOC AD13 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12 PULLUP true} [get_ports qsfp_1_i2c_sda]
set_property -dict {LOC AF13 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12 PULLUP true} [get_ports qsfp_1_i2c_scl]

# 161.1328125 MHz MGT reference clock
set_property -dict {LOC K7  } [get_ports qsfp_mgt_refclk_p] ;# MGTREFCLK0P_227 from X2
set_property -dict {LOC K6  } [get_ports qsfp_mgt_refclk_n] ;# MGTREFCLK0N_227 from X2
create_clock -period 6.206 -name qsfp_mgt_refclk [get_ports qsfp_mgt_refclk_p]

set_false_path -to [get_ports {qsfp_1_modsell qsfp_1_resetl qsfp_1_lpmode}]
set_output_delay 0 [get_ports {qsfp_1_modsell qsfp_1_resetl qsfp_1_lpmode}]
set_false_path -from [get_ports {qsfp_1_modprsl qsfp_1_intl}]
set_input_delay 0 [get_ports {qsfp_1_modprsl qsfp_1_intl}]

set_false_path -to [get_ports {qsfp_1_i2c_sda qsfp_1_i2c_scl}]
set_output_delay 0 [get_ports {qsfp_1_i2c_sda qsfp_1_i2c_scl}]
set_false_path -from [get_ports {qsfp_1_i2c_sda qsfp_1_i2c_scl}]
set_input_delay 0 [get_ports {qsfp_1_i2c_sda qsfp_1_i2c_scl}]

# I2C interface
set_property -dict {LOC W12  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12 PULLUP true} [get_ports eeprom_i2c_scl]
set_property -dict {LOC W13  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12 PULLUP true} [get_ports eeprom_i2c_sda]

set_false_path -to [get_ports {eeprom_i2c_sda eeprom_i2c_scl}]
set_output_delay 0 [get_ports {eeprom_i2c_sda eeprom_i2c_scl}]
set_false_path -from [get_ports {eeprom_i2c_sda eeprom_i2c_scl}]
set_input_delay 0 [get_ports {eeprom_i2c_sda eeprom_i2c_scl}]

# PCIe Interface
set_property -dict {LOC P2  } [get_ports {pcie_rx_p[0]}] ;# MGTYRXP3_225 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC P1  } [get_ports {pcie_rx_n[0]}] ;# MGTYRXN3_225 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC R5  } [get_ports {pcie_tx_p[0]}] ;# MGTYTXP3_225 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC R4  } [get_ports {pcie_tx_n[0]}] ;# MGTYTXN3_225 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC T2  } [get_ports {pcie_rx_p[1]}] ;# MGTYRXP2_225 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC T1  } [get_ports {pcie_rx_n[1]}] ;# MGTYRXN2_225 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC U5  } [get_ports {pcie_tx_p[1]}] ;# MGTYTXP2_225 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC U4  } [get_ports {pcie_tx_n[1]}] ;# MGTYTXN2_225 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC V2  } [get_ports {pcie_rx_p[2]}] ;# MGTYRXP1_225 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC V1  } [get_ports {pcie_rx_n[2]}] ;# MGTYRXN1_225 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC W5  } [get_ports {pcie_tx_p[2]}] ;# MGTYTXP1_225 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC W4  } [get_ports {pcie_tx_n[2]}] ;# MGTYTXN1_225 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC Y2  } [get_ports {pcie_rx_p[3]}] ;# MGTYRXP0_225 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC Y1  } [get_ports {pcie_rx_n[3]}] ;# MGTYRXN0_225 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC AA5 } [get_ports {pcie_tx_p[3]}] ;# MGTYTXP0_225 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC AA4 } [get_ports {pcie_tx_n[3]}] ;# MGTYTXN0_225 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC AB2 } [get_ports {pcie_rx_p[4]}] ;# MGTYRXP3_224 GTYE4_CHANNEL_X0Y3 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AB1 } [get_ports {pcie_rx_n[4]}] ;# MGTYRXN3_224 GTYE4_CHANNEL_X0Y3 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AC5 } [get_ports {pcie_tx_p[4]}] ;# MGTYTXP3_224 GTYE4_CHANNEL_X0Y3 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AC4 } [get_ports {pcie_tx_n[4]}] ;# MGTYTXN3_224 GTYE4_CHANNEL_X0Y3 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AD2 } [get_ports {pcie_rx_p[5]}] ;# MGTYRXP2_224 GTYE4_CHANNEL_X0Y2 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AD1 } [get_ports {pcie_rx_n[5]}] ;# MGTYRXN2_224 GTYE4_CHANNEL_X0Y2 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AD7 } [get_ports {pcie_tx_p[5]}] ;# MGTYTXP2_224 GTYE4_CHANNEL_X0Y2 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AD6 } [get_ports {pcie_tx_n[5]}] ;# MGTYTXN2_224 GTYE4_CHANNEL_X0Y2 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AE4 } [get_ports {pcie_rx_p[6]}] ;# MGTYRXP1_224 GTYE4_CHANNEL_X0Y1 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AE3 } [get_ports {pcie_rx_n[6]}] ;# MGTYRXN1_224 GTYE4_CHANNEL_X0Y1 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AE9 } [get_ports {pcie_tx_p[6]}] ;# MGTYTXP1_224 GTYE4_CHANNEL_X0Y1 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AE8 } [get_ports {pcie_tx_n[6]}] ;# MGTYTXN1_224 GTYE4_CHANNEL_X0Y1 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AF2 } [get_ports {pcie_rx_p[7]}] ;# MGTYRXP0_224 GTYE4_CHANNEL_X0Y0 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AF1 } [get_ports {pcie_rx_n[7]}] ;# MGTYRXN0_224 GTYE4_CHANNEL_X0Y0 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AF7 } [get_ports {pcie_tx_p[7]}] ;# MGTYTXP0_224 GTYE4_CHANNEL_X0Y0 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AF6 } [get_ports {pcie_tx_n[7]}] ;# MGTYTXN0_224 GTYE4_CHANNEL_X0Y0 / GTYE4_COMMON_X0Y0
set_property -dict {LOC V7  } [get_ports pcie_refclk_p] ;# MGTREFCLK0P_225
set_property -dict {LOC V6  } [get_ports pcie_refclk_n] ;# MGTREFCLK0N_225
set_property -dict {LOC T19 IOSTANDARD LVCMOS18 PULLUP true} [get_ports pcie_reset_n]

set_false_path -from [get_ports {pcie_reset_n}]
set_input_delay 0 [get_ports {pcie_reset_n}]

# 100 MHz MGT reference clock
create_clock -period 10 -name pcie_mgt_refclk [get_ports pcie_refclk_p]

# QSPI flash
set_property -dict {LOC H11  IOSTANDARD LVCMOS18 DRIVE 12} [get_ports {qspi_clk}]
set_property -dict {LOC H9   IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {qspi_dq[0]}]
set_property -dict {LOC J9   IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {qspi_dq[1]}]
set_property -dict {LOC J10  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {qspi_dq[2]}]
set_property -dict {LOC J11  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {qspi_dq[3]}]
set_property -dict {LOC K9   IOSTANDARD LVCMOS18 DRIVE 12} [get_ports {qspi_0_cs}]
set_property -dict {LOC K10  IOSTANDARD LVCMOS18 DRIVE 12} [get_ports {qspi_1_cs}]

set_false_path -to [get_ports {qspi_clk qspi_dq[*] qspi_0_cs qspi_1_cs}]
set_output_delay 0 [get_ports {qspi_clk qspi_dq[*] qspi_0_cs qspi_1_cs}]
set_false_path -from [get_ports {qspi_dq[*]}]
set_input_delay 0 [get_ports {qspi_dq[*]}]
