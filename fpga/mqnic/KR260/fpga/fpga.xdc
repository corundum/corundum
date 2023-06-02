# XDC constraints for the Xilinx KR260 board
# part: xck26-sfvc784-2LV-c

# General configuration
set_property BITSTREAM.GENERAL.COMPRESS true           [current_design]

# LEDs
set_property -dict {LOC F8   IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[0]}] ;# HPA14P som240_1_d13
set_property -dict {LOC E8   IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[1]}] ;# HPA14N som240_1_d14

set_property -dict {LOC G8   IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {sfp_led[0]}] ;# HPA13P som240_1_a12
set_property -dict {LOC F7   IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {sfp_led[1]}] ;# HPA13N som240_1_a13

set_false_path -to [get_ports {led[*] sfp_led[*]}]
set_output_delay 0 [get_ports {led[*] sfp_led[*]}]

# SFP+ Interface
set_property -dict {LOC T2  } [get_ports sfp_rx_p] ;# MGTHRXP2_224 GTHE4_CHANNEL_X1Y12 / GTHE4_COMMON_X1Y3
set_property -dict {LOC T1  } [get_ports sfp_rx_n] ;# MGTHRXN2_224 GTHE4_CHANNEL_X1Y12 / GTHE4_COMMON_X1Y3
set_property -dict {LOC R4  } [get_ports sfp_tx_p] ;# MGTHTXP2_224 GTHE4_CHANNEL_X1Y12 / GTHE4_COMMON_X1Y3
set_property -dict {LOC R3  } [get_ports sfp_tx_n] ;# MGTHTXN2_224 GTHE4_CHANNEL_X1Y12 / GTHE4_COMMON_X1Y3
set_property -dict {LOC Y6  } [get_ports sfp_mgt_refclk_p] ;# MGTREFCLK0P_224 from U90
set_property -dict {LOC Y5  } [get_ports sfp_mgt_refclk_n] ;# MGTREFCLK0N_224 from U90
set_property -dict {LOC Y10  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports sfp_tx_disable] ;# HDB19 som240_2_a47
set_property -dict {LOC A10  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports sfp_tx_fault]   ;# HDA19 som240_1_c23
set_property -dict {LOC J12  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports sfp_rx_los]     ;# HDA10 som240_1_a16
set_property -dict {LOC W10  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports sfp_mod_abs]    ;# HDB18 som240_2_a46
set_property -dict {LOC AB11 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports sfp_i2c_scl]    ;# HDB16 som240_2_b49
set_property -dict {LOC AC11 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports sfp_i2c_sda]    ;# HDB17 som240_2_b50

# 156.25 MHz MGT reference clock
create_clock -period 6.400 -name sfp_mgt_refclk [get_ports sfp_mgt_refclk_p]

set_false_path -to [get_ports {sfp_tx_disable}]
set_output_delay 0 [get_ports {sfp_tx_disable}]
set_false_path -from [get_ports {sfp_tx_fault sfp_rx_los sfp_mod_abs}]
set_input_delay 0 [get_ports {sfp_tx_fault sfp_rx_los sfp_mod_abs}]

set_false_path -to [get_ports {sfp_i2c_sda sfp_i2c_scl}]
set_output_delay 0 [get_ports {sfp_i2c_sda sfp_i2c_scl}]
set_false_path -from [get_ports {sfp_i2c_sda sfp_i2c_scl}]
set_input_delay 0 [get_ports {sfp_i2c_sda sfp_i2c_scl}]
