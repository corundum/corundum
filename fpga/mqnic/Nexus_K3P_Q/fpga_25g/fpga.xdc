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
set_property -dict {LOC E13  IOSTANDARD LVCMOS33} [get_ports clk_10mhz]
create_clock -period 100.000 -name clk_10mhz [get_ports clk_10mhz]

# E13 cannot directly drive MMCM, so need to set CLOCK_DEDICATED_ROUTE to satisfy DRC
set_property CLOCK_DEDICATED_ROUTE ANY_CMT_COLUMN [get_nets clk_10mhz_bufg]

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
set_property -dict {LOC T19 IOSTANDARD LVCMOS12 PULLUP true} [get_ports pcie_reset_n]

set_false_path -from [get_ports {pcie_reset_n}]
set_input_delay 0 [get_ports {pcie_reset_n}]

# 100 MHz MGT reference clock
create_clock -period 10 -name pcie_mgt_refclk [get_ports pcie_refclk_p]

# DDR4
# 9x MT40A1G8SA-075
set_property -dict {LOC W24  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[0]}]
set_property -dict {LOC U24  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[1]}]
set_property -dict {LOC AA24 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[2]}]
set_property -dict {LOC T24  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[3]}]
set_property -dict {LOC Y22  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[4]}]
set_property -dict {LOC V23  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[5]}]
set_property -dict {LOC Y25  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[6]}]
set_property -dict {LOC V24  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[7]}]
set_property -dict {LOC W23  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[8]}]
set_property -dict {LOC Y26  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[9]}]
set_property -dict {LOC V21  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[10]}]
set_property -dict {LOC W25  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[11]}]
set_property -dict {LOC AA23 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[12]}]
set_property -dict {LOC W26  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[13]}]
set_property -dict {LOC U21  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[14]}]
set_property -dict {LOC T22  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[15]}]
set_property -dict {LOC T20  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[16]}]
set_property -dict {LOC V22  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_ba[0]}]
set_property -dict {LOC T23  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_ba[1]}]
set_property -dict {LOC Y23  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_bg[0]}]
set_property -dict {LOC P24  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_bg[1]}]
set_property -dict {LOC U19  IOSTANDARD DIFF_SSTL12_DCI} [get_ports {ddr4_ck_t}]
set_property -dict {LOC V19  IOSTANDARD DIFF_SSTL12_DCI} [get_ports {ddr4_ck_c}]
set_property -dict {LOC W19  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_cke}]
set_property -dict {LOC N24  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_cs_n}]
set_property -dict {LOC W20  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_act_n}]
set_property -dict {LOC U20  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_odt}]
set_property -dict {LOC R25  IOSTANDARD LVCMOS12       } [get_ports {ddr4_reset_n}]

set_property -dict {LOC L20  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[0]}]
set_property -dict {LOC M20  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[1]}]
set_property -dict {LOC J21  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[2]}]
set_property -dict {LOC M21  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[3]}]
set_property -dict {LOC K21  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[4]}]
set_property -dict {LOC J19  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[5]}]
set_property -dict {LOC K20  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[6]}]
set_property -dict {LOC J20  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[7]}]
set_property -dict {LOC K23  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[8]}]
set_property -dict {LOC J24  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[9]}]
set_property -dict {LOC M25  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[10]}]
set_property -dict {LOC K26  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[11]}]
set_property -dict {LOC J23  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[12]}]
set_property -dict {LOC K22  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[13]}]
set_property -dict {LOC M26  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[14]}]
set_property -dict {LOC K25  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[15]}]
set_property -dict {LOC H23  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[16]}]
set_property -dict {LOC G26  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[17]}]
set_property -dict {LOC J26  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[18]}]
set_property -dict {LOC H24  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[19]}]
set_property -dict {LOC H21  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[20]}]
set_property -dict {LOC H22  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[21]}]
set_property -dict {LOC J25  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[22]}]
set_property -dict {LOC H26  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[23]}]
set_property -dict {LOC E23  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[24]}]
set_property -dict {LOC D24  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[25]}]
set_property -dict {LOC D25  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[26]}]
set_property -dict {LOC B25  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[27]}]
set_property -dict {LOC D26  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[28]}]
set_property -dict {LOC F23  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[29]}]
set_property -dict {LOC C26  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[30]}]
set_property -dict {LOC B26  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[31]}]
set_property -dict {LOC AF25 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[32]}]
set_property -dict {LOC AC24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[33]}]
set_property -dict {LOC AD25 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[34]}]
set_property -dict {LOC AD24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[35]}]
set_property -dict {LOC AF24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[36]}]
set_property -dict {LOC AB25 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[37]}]
set_property -dict {LOC AB24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[38]}]
set_property -dict {LOC AB26 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[39]}]
set_property -dict {LOC AD21 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[40]}]
set_property -dict {LOC AD23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[41]}]
set_property -dict {LOC AC21 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[42]}]
set_property -dict {LOC AC23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[43]}]
set_property -dict {LOC AE21 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[44]}]
set_property -dict {LOC AB21 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[45]}]
set_property -dict {LOC AC22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[46]}]
set_property -dict {LOC AE23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[47]}]
set_property -dict {LOC AD16 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[48]}]
set_property -dict {LOC AD19 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[49]}]
set_property -dict {LOC AF17 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[50]}]
set_property -dict {LOC AF19 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[51]}]
set_property -dict {LOC AE16 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[52]}]
set_property -dict {LOC AC19 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[53]}]
set_property -dict {LOC AE17 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[54]}]
set_property -dict {LOC AF18 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[55]}]
set_property -dict {LOC AA19 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[56]}]
set_property -dict {LOC Y17  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[57]}]
set_property -dict {LOC AA20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[58]}]
set_property -dict {LOC AA17 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[59]}]
set_property -dict {LOC AB19 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[60]}]
set_property -dict {LOC Y18  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[61]}]
set_property -dict {LOC AB20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[62]}]
set_property -dict {LOC AA18 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[63]}]
set_property -dict {LOC H16  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[64]}]
set_property -dict {LOC E15  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[65]}]
set_property -dict {LOC C16  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[66]}]
set_property -dict {LOC D16  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[67]}]
set_property -dict {LOC H17  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[68]}]
set_property -dict {LOC G16  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[69]}]
set_property -dict {LOC G17  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[70]}]
set_property -dict {LOC D15  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[71]}]
set_property -dict {LOC M19  IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[0]}]
set_property -dict {LOC L19  IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[0]}]
set_property -dict {LOC L24  IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[1]}]
set_property -dict {LOC L25  IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[1]}]
set_property -dict {LOC F24  IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[2]}]
set_property -dict {LOC F25  IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[2]}]
set_property -dict {LOC D23  IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[3]}]
set_property -dict {LOC C24  IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[3]}]
set_property -dict {LOC AC26 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[4]}]
set_property -dict {LOC AD26 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[4]}]
set_property -dict {LOC AA22 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[5]}]
set_property -dict {LOC AB22 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[5]}]
set_property -dict {LOC AC18 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[6]}]
set_property -dict {LOC AD18 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[6]}]
set_property -dict {LOC AB17 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[7]}]
set_property -dict {LOC AC17 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[7]}]
set_property -dict {LOC E16  IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[8]}]
set_property -dict {LOC E17  IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[8]}]
set_property -dict {LOC L18  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[0]}]
set_property -dict {LOC L22  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[1]}]
set_property -dict {LOC G24  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[2]}]
set_property -dict {LOC E25  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[3]}]
set_property -dict {LOC AE25 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[4]}]
set_property -dict {LOC AE22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[5]}]
set_property -dict {LOC AD20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[6]}]
set_property -dict {LOC Y20  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[7]}]
set_property -dict {LOC G15  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[8]}]

# 161.1328125 MHz DDR4 clock
set_property -dict {LOC T25 IOSTANDARD DIFF_SSTL12_DCI} [get_ports clk_ddr4_p]
set_property -dict {LOC U25 IOSTANDARD DIFF_SSTL12_DCI} [get_ports clk_ddr4_n]
#create_clock -period 6.206 -name clk_ddr4 [get_ports clk_ddr4_p]

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
