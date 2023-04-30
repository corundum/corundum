# XDC constraints for the fb4CGg3@VU09P
# part: xcvu9p-flgb2104-2-e

# General configuration
set_property CFGBVS GND                                [current_design]
set_property CONFIG_VOLTAGE 1.8                        [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true           [current_design]
set_property CONFIG_MODE S_SELECTMAP16                 [current_design]
set_property BITSTREAM.CONFIG.OVERTEMPSHUTDOWN Enable  [current_design]

# System clocks
# init clock 50 MHz
set_property -dict {LOC AV26 IOSTANDARD LVCMOS18} [get_ports init_clk]
create_clock -period 20.000 -name init_clk [get_ports init_clk]

# DDR4 refclk1
#set_property -dict {LOC BA34 IOSTANDARD DIFF_SSTL12} [get_ports clk_ddr4_refclk1_p]
#set_property -dict {LOC BB34 IOSTANDARD DIFF_SSTL12} [get_ports clk_ddr4_refclk1_n]
#create_clock -period 3.750 -name clk_ddr4_refclk1 [get_ports clk_ddr4_refclk1_p]

# DDR4 refclk2
#set_property -dict {LOC C36  IOSTANDARD DIFF_SSTL12} [get_ports clk_ddr4_refclk2_p]
#set_property -dict {LOC C37  IOSTANDARD DIFF_SSTL12} [get_ports clk_ddr4_refclk2_n]
#create_clock -period 3.750 -name clk_ddr4_refclk2 [get_ports clk_ddr4_refclk2_p]

# SODIMM A refclk
#set_property -dict {LOC AV27 IOSTANDARD DIFF_SSTL12} [get_ports clk_sodimm_a_refclk_p]
#set_property -dict {LOC AV28 IOSTANDARD DIFF_SSTL12} [get_ports clk_sodimm_a_refclk_n]
#create_clock -period 3.750 -name clk_sodimm_a_refclk [get_ports clk_sodimm_a_refclk_p]

# SODIMM B refclk
#set_property -dict {LOC H19  IOSTANDARD DIFF_SSTL12} [get_ports clk_sodimm_b_refclk_p]
#set_property -dict {LOC H18  IOSTANDARD DIFF_SSTL12} [get_ports clk_sodimm_b_refclk_n]
#create_clock -period 3.750 -name clk_sodimm_b_refclk [get_ports clk_sodimm_b_refclk_p]

# LEDs
set_property -dict {LOC AN22 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 4} [get_ports led_sreg_d]
set_property -dict {LOC AN23 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 4} [get_ports led_sreg_ld]
set_property -dict {LOC AN21 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 4} [get_ports led_sreg_clk]
set_property -dict {LOC AM24 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {led_bmc_red[0]}]
set_property -dict {LOC AP24 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {led_bmc_red[1]}]
set_property -dict {LOC AL24 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {led_bmc_green[0]}]
set_property -dict {LOC AN24 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {led_bmc_green[1]}]

set_false_path -to [get_ports {led_sreg_d led_sreg_ld led_sreg_clk led_bmc[*]}]
set_output_delay 0 [get_ports {led_sreg_d led_sreg_ld led_sreg_clk led_bmc[*]}]

# GPIO
set_property -dict {LOC AU22 IOSTANDARD LVCMOS18} [get_ports pps_in] ;# from u.FL J760
set_property -dict {LOC AV22 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 4} [get_ports pps_out] ;# to u.FL J761 via U760 and U761
#set_property -dict {LOC AV23 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 4} [get_ports ref_clk] ;# to u.FL J050

set_false_path -to [get_ports {pps_out}]
set_output_delay 0 [get_ports {pps_out}]
set_false_path -from [get_ports {pps_in}]
set_input_delay 0 [get_ports {pps_in}]

# QSFP28 Interfaces
set_property -dict {LOC AP43} [get_ports qsfp_0_rx_0_p] ;# MGTYRXP3_121 GTYE4_CHANNEL_X0Y11 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AP44} [get_ports qsfp_0_rx_0_n] ;# MGTYRXN3_121 GTYE4_CHANNEL_X0Y11 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AP38} [get_ports qsfp_0_tx_0_p] ;# MGTYTXP3_121 GTYE4_CHANNEL_X0Y11 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AP39} [get_ports qsfp_0_tx_0_n] ;# MGTYTXN3_121 GTYE4_CHANNEL_X0Y11 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AT43} [get_ports qsfp_0_rx_1_p] ;# MGTYRXP1_121 GTYE4_CHANNEL_X0Y9 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AT44} [get_ports qsfp_0_rx_1_n] ;# MGTYRXN1_121 GTYE4_CHANNEL_X0Y9 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AT38} [get_ports qsfp_0_tx_1_p] ;# MGTYTXP1_121 GTYE4_CHANNEL_X0Y9 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AT39} [get_ports qsfp_0_tx_1_n] ;# MGTYTXN1_121 GTYE4_CHANNEL_X0Y9 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AR45} [get_ports qsfp_0_rx_2_p] ;# MGTYRXP2_121 GTYE4_CHANNEL_X0Y10 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AR46} [get_ports qsfp_0_rx_2_n] ;# MGTYRXN2_121 GTYE4_CHANNEL_X0Y10 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AR40} [get_ports qsfp_0_tx_2_p] ;# MGTYTXP2_121 GTYE4_CHANNEL_X0Y10 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AR41} [get_ports qsfp_0_tx_2_n] ;# MGTYTXN2_121 GTYE4_CHANNEL_X0Y10 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AU45} [get_ports qsfp_0_rx_3_p] ;# MGTYRXP0_121 GTYE4_CHANNEL_X0Y8 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AU46} [get_ports qsfp_0_rx_3_n] ;# MGTYRXN0_121 GTYE4_CHANNEL_X0Y8 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AU40} [get_ports qsfp_0_tx_3_p] ;# MGTYTXP0_121 GTYE4_CHANNEL_X0Y8 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AU41} [get_ports qsfp_0_tx_3_n] ;# MGTYTXN0_121 GTYE4_CHANNEL_X0Y8 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AU36} [get_ports qsfp_0_mgt_refclk_p] ;# MGTREFCLK1P_121 from U770
set_property -dict {LOC AU37} [get_ports qsfp_0_mgt_refclk_n] ;# MGTREFCLK1N_121 from U770
set_property -dict {LOC BA24 IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp_0_mod_prsnt_n]
set_property -dict {LOC BB22 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 4} [get_ports qsfp_0_reset_n]
set_property -dict {LOC BC22 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 4} [get_ports qsfp_0_lp_mode]
set_property -dict {LOC BC21 IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp_0_intr_n]
set_property -dict {LOC BB21 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 4} [get_ports qsfp_0_i2c_scl]
set_property -dict {LOC BB20 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 4} [get_ports qsfp_0_i2c_sda]

# 161.1328125 MHz MGT reference clock
create_clock -period 6.206 -name qsfp_0_mgt_refclk [get_ports qsfp_0_mgt_refclk_p]

set_false_path -to [get_ports {qsfp_0_reset_n qsfp_0_lp_mode}]
set_output_delay 0 [get_ports {qsfp_0_reset_n qsfp_0_lp_mode}]
set_false_path -from [get_ports {qsfp_0_mod_prsnt_n qsfp_0_intr_n}]
set_input_delay 0 [get_ports {qsfp_0_mod_prsnt_n qsfp_0_intr_n}]

set_false_path -to [get_ports {qsfp_0_i2c_scl qsfp_0_i2c_sda}]
set_output_delay 0 [get_ports {qsfp_0_i2c_scl qsfp_0_i2c_sda}]
set_false_path -from [get_ports {qsfp_0_i2c_scl qsfp_0_i2c_sda}]
set_input_delay 0 [get_ports {qsfp_0_i2c_scl qsfp_0_i2c_sda}]

set_property -dict {LOC AF43} [get_ports qsfp_1_rx_0_p] ;# MGTYRXP3_123 GTYE4_CHANNEL_X0Y19 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AF44} [get_ports qsfp_1_rx_0_n] ;# MGTYRXN3_123 GTYE4_CHANNEL_X0Y19 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AF38} [get_ports qsfp_1_tx_0_p] ;# MGTYTXP3_123 GTYE4_CHANNEL_X0Y19 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AF39} [get_ports qsfp_1_tx_0_n] ;# MGTYTXN3_123 GTYE4_CHANNEL_X0Y19 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AH43} [get_ports qsfp_1_rx_1_p] ;# MGTYRXP1_123 GTYE4_CHANNEL_X0Y17 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AH44} [get_ports qsfp_1_rx_1_n] ;# MGTYRXN1_123 GTYE4_CHANNEL_X0Y17 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AH38} [get_ports qsfp_1_tx_1_p] ;# MGTYTXP1_123 GTYE4_CHANNEL_X0Y17 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AH39} [get_ports qsfp_1_tx_1_n] ;# MGTYTXN1_123 GTYE4_CHANNEL_X0Y17 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AG45} [get_ports qsfp_1_rx_2_p] ;# MGTYRXP2_123 GTYE4_CHANNEL_X0Y18 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AG46} [get_ports qsfp_1_rx_2_n] ;# MGTYRXN2_123 GTYE4_CHANNEL_X0Y18 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AG40} [get_ports qsfp_1_tx_2_p] ;# MGTYTXP2_123 GTYE4_CHANNEL_X0Y18 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AG41} [get_ports qsfp_1_tx_2_n] ;# MGTYTXN2_123 GTYE4_CHANNEL_X0Y18 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AJ45} [get_ports qsfp_1_rx_3_p] ;# MGTYRXP0_123 GTYE4_CHANNEL_X0Y16 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AJ46} [get_ports qsfp_1_rx_3_n] ;# MGTYRXN0_123 GTYE4_CHANNEL_X0Y16 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AJ40} [get_ports qsfp_1_tx_3_p] ;# MGTYTXP0_123 GTYE4_CHANNEL_X0Y16 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AJ41} [get_ports qsfp_1_tx_3_n] ;# MGTYTXN0_123 GTYE4_CHANNEL_X0Y16 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AL36} [get_ports qsfp_1_mgt_refclk_p] ;# MGTREFCLK0P_123 from U770
set_property -dict {LOC AL37} [get_ports qsfp_1_mgt_refclk_n] ;# MGTREFCLK0N_123 from U770
set_property -dict {LOC BE23 IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp_1_mod_prsnt_n]
set_property -dict {LOC BF23 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 4} [get_ports qsfp_1_reset_n]
set_property -dict {LOC BD23 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 4} [get_ports qsfp_1_lp_mode]
set_property -dict {LOC BF24 IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp_1_intr_n]
set_property -dict {LOC BC23 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 4} [get_ports qsfp_1_i2c_scl]
set_property -dict {LOC BA23 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 4} [get_ports qsfp_1_i2c_sda]

# 161.1328125 MHz MGT reference clock
create_clock -period 6.206 -name qsfp_1_mgt_refclk [get_ports qsfp_1_mgt_refclk_p]

set_false_path -to [get_ports {qsfp_1_reset_n qsfp_1_lp_mode}]
set_output_delay 0 [get_ports {qsfp_1_reset_n qsfp_1_lp_mode}]
set_false_path -from [get_ports {qsfp_1_mod_prsnt_n qsfp_1_intr_n}]
set_input_delay 0 [get_ports {qsfp_1_mod_prsnt_n qsfp_1_intr_n}]

set_false_path -to [get_ports {qsfp_1_i2c_scl qsfp_1_i2c_sda}]
set_output_delay 0 [get_ports {qsfp_1_i2c_scl qsfp_1_i2c_sda}]
set_false_path -from [get_ports {qsfp_1_i2c_scl qsfp_1_i2c_sda}]
set_input_delay 0 [get_ports {qsfp_1_i2c_scl qsfp_1_i2c_sda}]

set_property -dict {LOC V43 } [get_ports qsfp_2_rx_0_p] ;# MGTYRXP3_125 GTYE4_CHANNEL_X0Y27 / GTYE4_COMMON_X0Y6
set_property -dict {LOC V44 } [get_ports qsfp_2_rx_0_n] ;# MGTYRXN3_125 GTYE4_CHANNEL_X0Y27 / GTYE4_COMMON_X0Y6
set_property -dict {LOC V38 } [get_ports qsfp_2_tx_0_p] ;# MGTYTXP3_125 GTYE4_CHANNEL_X0Y27 / GTYE4_COMMON_X0Y6
set_property -dict {LOC V39 } [get_ports qsfp_2_tx_0_n] ;# MGTYTXN3_125 GTYE4_CHANNEL_X0Y27 / GTYE4_COMMON_X0Y6
set_property -dict {LOC Y43 } [get_ports qsfp_2_rx_1_p] ;# MGTYRXP1_125 GTYE4_CHANNEL_X0Y25 / GTYE4_COMMON_X0Y6
set_property -dict {LOC Y44 } [get_ports qsfp_2_rx_1_n] ;# MGTYRXN1_125 GTYE4_CHANNEL_X0Y25 / GTYE4_COMMON_X0Y6
set_property -dict {LOC Y38 } [get_ports qsfp_2_tx_1_p] ;# MGTYTXP1_125 GTYE4_CHANNEL_X0Y25 / GTYE4_COMMON_X0Y6
set_property -dict {LOC Y39 } [get_ports qsfp_2_tx_1_n] ;# MGTYTXN1_125 GTYE4_CHANNEL_X0Y25 / GTYE4_COMMON_X0Y6
set_property -dict {LOC W45 } [get_ports qsfp_2_rx_2_p] ;# MGTYRXP2_125 GTYE4_CHANNEL_X0Y26 / GTYE4_COMMON_X0Y6
set_property -dict {LOC W46 } [get_ports qsfp_2_rx_2_n] ;# MGTYRXN2_125 GTYE4_CHANNEL_X0Y26 / GTYE4_COMMON_X0Y6
set_property -dict {LOC W40 } [get_ports qsfp_2_tx_2_p] ;# MGTYTXP2_125 GTYE4_CHANNEL_X0Y26 / GTYE4_COMMON_X0Y6
set_property -dict {LOC W41 } [get_ports qsfp_2_tx_2_n] ;# MGTYTXN2_125 GTYE4_CHANNEL_X0Y26 / GTYE4_COMMON_X0Y6
set_property -dict {LOC AA45} [get_ports qsfp_2_rx_3_p] ;# MGTYRXP0_125 GTYE4_CHANNEL_X0Y24 / GTYE4_COMMON_X0Y6
set_property -dict {LOC AA46} [get_ports qsfp_2_rx_3_n] ;# MGTYRXN0_125 GTYE4_CHANNEL_X0Y24 / GTYE4_COMMON_X0Y6
set_property -dict {LOC AA40} [get_ports qsfp_2_tx_3_p] ;# MGTYTXP0_125 GTYE4_CHANNEL_X0Y24 / GTYE4_COMMON_X0Y6
set_property -dict {LOC AA41} [get_ports qsfp_2_tx_3_n] ;# MGTYTXN0_125 GTYE4_CHANNEL_X0Y24 / GTYE4_COMMON_X0Y6
set_property -dict {LOC AC36} [get_ports qsfp_2_mgt_refclk_p] ;# MGTREFCLK0P_125 from U770
set_property -dict {LOC AC37} [get_ports qsfp_2_mgt_refclk_n] ;# MGTREFCLK0N_125 from U770
set_property -dict {LOC BE20 IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp_2_mod_prsnt_n]
set_property -dict {LOC BE21 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 4} [get_ports qsfp_2_reset_n]
set_property -dict {LOC BD20 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 4} [get_ports qsfp_2_lp_mode]
set_property -dict {LOC BD21 IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp_2_intr_n]
set_property -dict {LOC BF22 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 4} [get_ports qsfp_2_i2c_scl]
set_property -dict {LOC BE22 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 4} [get_ports qsfp_2_i2c_sda]

# 161.1328125 MHz MGT reference clock
create_clock -period 6.206 -name qsfp_2_mgt_refclk [get_ports qsfp_2_mgt_refclk_p]

set_false_path -to [get_ports {qsfp_2_reset_n qsfp_2_lp_mode}]
set_output_delay 0 [get_ports {qsfp_2_reset_n qsfp_2_lp_mode}]
set_false_path -from [get_ports {qsfp_2_mod_prsnt_n qsfp_2_intr_n}]
set_input_delay 0 [get_ports {qsfp_2_mod_prsnt_n qsfp_2_intr_n}]

set_false_path -to [get_ports {qsfp_2_i2c_scl qsfp_2_i2c_sda}]
set_output_delay 0 [get_ports {qsfp_2_i2c_scl qsfp_2_i2c_sda}]
set_false_path -from [get_ports {qsfp_2_i2c_scl qsfp_2_i2c_sda}]
set_input_delay 0 [get_ports {qsfp_2_i2c_scl qsfp_2_i2c_sda}]

set_property -dict {LOC K43 } [get_ports qsfp_3_rx_0_p] ;# MGTYRXP3_127 GTYE4_CHANNEL_X0Y35 / GTYE4_COMMON_X0Y8
set_property -dict {LOC K44 } [get_ports qsfp_3_rx_0_n] ;# MGTYRXN3_127 GTYE4_CHANNEL_X0Y35 / GTYE4_COMMON_X0Y8
set_property -dict {LOC J40 } [get_ports qsfp_3_tx_0_p] ;# MGTYTXP3_127 GTYE4_CHANNEL_X0Y35 / GTYE4_COMMON_X0Y8
set_property -dict {LOC J41 } [get_ports qsfp_3_tx_0_n] ;# MGTYTXN3_127 GTYE4_CHANNEL_X0Y35 / GTYE4_COMMON_X0Y8
set_property -dict {LOC M43 } [get_ports qsfp_3_rx_1_p] ;# MGTYRXP1_127 GTYE4_CHANNEL_X0Y33 / GTYE4_COMMON_X0Y8
set_property -dict {LOC M44 } [get_ports qsfp_3_rx_1_n] ;# MGTYRXN1_127 GTYE4_CHANNEL_X0Y33 / GTYE4_COMMON_X0Y8
set_property -dict {LOC M38 } [get_ports qsfp_3_tx_1_p] ;# MGTYTXP1_127 GTYE4_CHANNEL_X0Y33 / GTYE4_COMMON_X0Y8
set_property -dict {LOC M39 } [get_ports qsfp_3_tx_1_n] ;# MGTYTXN1_127 GTYE4_CHANNEL_X0Y33 / GTYE4_COMMON_X0Y8
set_property -dict {LOC L45 } [get_ports qsfp_3_rx_2_p] ;# MGTYRXP2_127 GTYE4_CHANNEL_X0Y34 / GTYE4_COMMON_X0Y8
set_property -dict {LOC L46 } [get_ports qsfp_3_rx_2_n] ;# MGTYRXN2_127 GTYE4_CHANNEL_X0Y34 / GTYE4_COMMON_X0Y8
set_property -dict {LOC L40 } [get_ports qsfp_3_tx_2_p] ;# MGTYTXP2_127 GTYE4_CHANNEL_X0Y34 / GTYE4_COMMON_X0Y8
set_property -dict {LOC L41 } [get_ports qsfp_3_tx_2_n] ;# MGTYTXN2_127 GTYE4_CHANNEL_X0Y34 / GTYE4_COMMON_X0Y8
set_property -dict {LOC N45 } [get_ports qsfp_3_rx_3_p] ;# MGTYRXP0_127 GTYE4_CHANNEL_X0Y32 / GTYE4_COMMON_X0Y8
set_property -dict {LOC N46 } [get_ports qsfp_3_rx_3_n] ;# MGTYRXN0_127 GTYE4_CHANNEL_X0Y32 / GTYE4_COMMON_X0Y8
set_property -dict {LOC N40 } [get_ports qsfp_3_tx_3_p] ;# MGTYTXP0_127 GTYE4_CHANNEL_X0Y32 / GTYE4_COMMON_X0Y8
set_property -dict {LOC N41 } [get_ports qsfp_3_tx_3_n] ;# MGTYTXN0_127 GTYE4_CHANNEL_X0Y32 / GTYE4_COMMON_X0Y8
set_property -dict {LOC R36 } [get_ports qsfp_3_mgt_refclk_p] ;# MGTREFCLK0P_127 from U770
set_property -dict {LOC R37 } [get_ports qsfp_3_mgt_refclk_n] ;# MGTREFCLK0N_127 from U770
set_property -dict {LOC AR21 IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp_3_mod_prsnt_n]
set_property -dict {LOC AT24 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 4} [get_ports qsfp_3_reset_n]
set_property -dict {LOC AU24 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 4} [get_ports qsfp_3_lp_mode]
set_property -dict {LOC AT23 IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp_3_intr_n]
set_property -dict {LOC AR23 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 4} [get_ports qsfp_3_i2c_scl]
set_property -dict {LOC AT22 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 4} [get_ports qsfp_3_i2c_sda]

# 161.1328125 MHz MGT reference clock
create_clock -period 6.206 -name qsfp_3_mgt_refclk [get_ports qsfp_3_mgt_refclk_p]

set_false_path -to [get_ports {qsfp_3_reset_n qsfp_3_lp_mode}]
set_output_delay 0 [get_ports {qsfp_3_reset_n qsfp_3_lp_mode}]
set_false_path -from [get_ports {qsfp_3_mod_prsnt_n qsfp_3_intr_n}]
set_input_delay 0 [get_ports {qsfp_3_mod_prsnt_n qsfp_3_intr_n}]

set_false_path -to [get_ports {qsfp_3_i2c_scl qsfp_3_i2c_sda}]
set_output_delay 0 [get_ports {qsfp_3_i2c_scl qsfp_3_i2c_sda}]
set_false_path -from [get_ports {qsfp_3_i2c_scl qsfp_3_i2c_sda}]
set_input_delay 0 [get_ports {qsfp_3_i2c_scl qsfp_3_i2c_sda}]

# PCIe Interface
set_property -dict {LOC AF2 } [get_ports {pcie_rx_p[0]}]  ;# MGTYRXP3_227 GTYE4_CHANNEL_X1Y35 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AF1 } [get_ports {pcie_rx_n[0]}]  ;# MGTYRXN3_227 GTYE4_CHANNEL_X1Y35 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AF7 } [get_ports {pcie_tx_p[0]}]  ;# MGTYTXP3_227 GTYE4_CHANNEL_X1Y35 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AF6 } [get_ports {pcie_tx_n[0]}]  ;# MGTYTXN3_227 GTYE4_CHANNEL_X1Y35 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AG4 } [get_ports {pcie_rx_p[1]}]  ;# MGTYRXP2_227 GTYE4_CHANNEL_X1Y34 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AG3 } [get_ports {pcie_rx_n[1]}]  ;# MGTYRXN2_227 GTYE4_CHANNEL_X1Y34 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AG9 } [get_ports {pcie_tx_p[1]}]  ;# MGTYTXP2_227 GTYE4_CHANNEL_X1Y34 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AG8 } [get_ports {pcie_tx_n[1]}]  ;# MGTYTXN2_227 GTYE4_CHANNEL_X1Y34 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AH2 } [get_ports {pcie_rx_p[2]}]  ;# MGTYRXP1_227 GTYE4_CHANNEL_X1Y33 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AH1 } [get_ports {pcie_rx_n[2]}]  ;# MGTYRXN1_227 GTYE4_CHANNEL_X1Y33 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AH7 } [get_ports {pcie_tx_p[2]}]  ;# MGTYTXP1_227 GTYE4_CHANNEL_X1Y33 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AH6 } [get_ports {pcie_tx_n[2]}]  ;# MGTYTXN1_227 GTYE4_CHANNEL_X1Y33 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AJ4 } [get_ports {pcie_rx_p[3]}]  ;# MGTYRXP0_227 GTYE4_CHANNEL_X1Y32 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AJ3 } [get_ports {pcie_rx_n[3]}]  ;# MGTYRXN0_227 GTYE4_CHANNEL_X1Y32 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AJ9 } [get_ports {pcie_tx_p[3]}]  ;# MGTYTXP0_227 GTYE4_CHANNEL_X1Y32 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AJ8 } [get_ports {pcie_tx_n[3]}]  ;# MGTYTXN0_227 GTYE4_CHANNEL_X1Y32 / GTYE4_COMMON_X1Y8
set_property -dict {LOC AK2 } [get_ports {pcie_rx_p[4]}]  ;# MGTYRXP3_226 GTYE4_CHANNEL_X1Y31 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AK1 } [get_ports {pcie_rx_n[4]}]  ;# MGTYRXN3_226 GTYE4_CHANNEL_X1Y31 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AK7 } [get_ports {pcie_tx_p[4]}]  ;# MGTYTXP3_226 GTYE4_CHANNEL_X1Y31 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AK6 } [get_ports {pcie_tx_n[4]}]  ;# MGTYTXN3_226 GTYE4_CHANNEL_X1Y31 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AL4 } [get_ports {pcie_rx_p[5]}]  ;# MGTYRXP2_226 GTYE4_CHANNEL_X1Y30 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AL3 } [get_ports {pcie_rx_n[5]}]  ;# MGTYRXN2_226 GTYE4_CHANNEL_X1Y30 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AL9 } [get_ports {pcie_tx_p[5]}]  ;# MGTYTXP2_226 GTYE4_CHANNEL_X1Y30 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AL8 } [get_ports {pcie_tx_n[5]}]  ;# MGTYTXN2_226 GTYE4_CHANNEL_X1Y30 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AM2 } [get_ports {pcie_rx_p[6]}]  ;# MGTYRXP1_226 GTYE4_CHANNEL_X1Y29 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AM1 } [get_ports {pcie_rx_n[6]}]  ;# MGTYRXN1_226 GTYE4_CHANNEL_X1Y29 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AM7 } [get_ports {pcie_tx_p[6]}]  ;# MGTYTXP1_226 GTYE4_CHANNEL_X1Y29 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AM6 } [get_ports {pcie_tx_n[6]}]  ;# MGTYTXN1_226 GTYE4_CHANNEL_X1Y29 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AN4 } [get_ports {pcie_rx_p[7]}]  ;# MGTYRXP0_226 GTYE4_CHANNEL_X1Y28 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AN3 } [get_ports {pcie_rx_n[7]}]  ;# MGTYRXN0_226 GTYE4_CHANNEL_X1Y28 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AN9 } [get_ports {pcie_tx_p[7]}]  ;# MGTYTXP0_226 GTYE4_CHANNEL_X1Y28 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AN8 } [get_ports {pcie_tx_n[7]}]  ;# MGTYTXN0_226 GTYE4_CHANNEL_X1Y28 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AP2 } [get_ports {pcie_rx_p[8]}]  ;# MGTYRXP3_225 GTYE4_CHANNEL_X1Y27 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AP1 } [get_ports {pcie_rx_n[8]}]  ;# MGTYRXN3_225 GTYE4_CHANNEL_X1Y27 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AP7 } [get_ports {pcie_tx_p[8]}]  ;# MGTYTXP3_225 GTYE4_CHANNEL_X1Y27 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AP6 } [get_ports {pcie_tx_n[8]}]  ;# MGTYTXN3_225 GTYE4_CHANNEL_X1Y27 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AR4 } [get_ports {pcie_rx_p[9]}]  ;# MGTYRXP2_225 GTYE4_CHANNEL_X1Y26 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AR3 } [get_ports {pcie_rx_n[9]}]  ;# MGTYRXN2_225 GTYE4_CHANNEL_X1Y26 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AR9 } [get_ports {pcie_tx_p[9]}]  ;# MGTYTXP2_225 GTYE4_CHANNEL_X1Y26 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AR8 } [get_ports {pcie_tx_n[9]}]  ;# MGTYTXN2_225 GTYE4_CHANNEL_X1Y26 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AT2 } [get_ports {pcie_rx_p[10]}] ;# MGTYRXP1_225 GTYE4_CHANNEL_X1Y25 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AT1 } [get_ports {pcie_rx_n[10]}] ;# MGTYRXN1_225 GTYE4_CHANNEL_X1Y25 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AT7 } [get_ports {pcie_tx_p[10]}] ;# MGTYTXP1_225 GTYE4_CHANNEL_X1Y25 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AT6 } [get_ports {pcie_tx_n[10]}] ;# MGTYTXN1_225 GTYE4_CHANNEL_X1Y25 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AU4 } [get_ports {pcie_rx_p[11]}] ;# MGTYRXP0_225 GTYE4_CHANNEL_X1Y24 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AU3 } [get_ports {pcie_rx_n[11]}] ;# MGTYRXN0_225 GTYE4_CHANNEL_X1Y24 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AU9 } [get_ports {pcie_tx_p[11]}] ;# MGTYTXP0_225 GTYE4_CHANNEL_X1Y24 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AU8 } [get_ports {pcie_tx_n[11]}] ;# MGTYTXN0_225 GTYE4_CHANNEL_X1Y24 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AV2 } [get_ports {pcie_rx_p[12]}] ;# MGTYRXP3_224 GTYE4_CHANNEL_X1Y23 / GTYE4_COMMON_X1Y5
set_property -dict {LOC AV1 } [get_ports {pcie_rx_n[12]}] ;# MGTYRXN3_224 GTYE4_CHANNEL_X1Y23 / GTYE4_COMMON_X1Y5
set_property -dict {LOC AV7 } [get_ports {pcie_tx_p[12]}] ;# MGTYTXP3_224 GTYE4_CHANNEL_X1Y23 / GTYE4_COMMON_X1Y5
set_property -dict {LOC AV6 } [get_ports {pcie_tx_n[12]}] ;# MGTYTXN3_224 GTYE4_CHANNEL_X1Y23 / GTYE4_COMMON_X1Y5
set_property -dict {LOC AW4 } [get_ports {pcie_rx_p[13]}] ;# MGTYRXP2_224 GTYE4_CHANNEL_X1Y22 / GTYE4_COMMON_X1Y5
set_property -dict {LOC AW3 } [get_ports {pcie_rx_n[13]}] ;# MGTYRXN2_224 GTYE4_CHANNEL_X1Y22 / GTYE4_COMMON_X1Y5
set_property -dict {LOC BB5 } [get_ports {pcie_tx_p[13]}] ;# MGTYTXP2_224 GTYE4_CHANNEL_X1Y22 / GTYE4_COMMON_X1Y5
set_property -dict {LOC BB4 } [get_ports {pcie_tx_n[13]}] ;# MGTYTXN2_224 GTYE4_CHANNEL_X1Y22 / GTYE4_COMMON_X1Y5
set_property -dict {LOC BA2 } [get_ports {pcie_rx_p[14]}] ;# MGTYRXP1_224 GTYE4_CHANNEL_X1Y21 / GTYE4_COMMON_X1Y5
set_property -dict {LOC BA1 } [get_ports {pcie_rx_n[14]}] ;# MGTYRXN1_224 GTYE4_CHANNEL_X1Y21 / GTYE4_COMMON_X1Y5
set_property -dict {LOC BD5 } [get_ports {pcie_tx_p[14]}] ;# MGTYTXP1_224 GTYE4_CHANNEL_X1Y21 / GTYE4_COMMON_X1Y5
set_property -dict {LOC BD4 } [get_ports {pcie_tx_n[14]}] ;# MGTYTXN1_224 GTYE4_CHANNEL_X1Y21 / GTYE4_COMMON_X1Y5
set_property -dict {LOC BC2 } [get_ports {pcie_rx_p[15]}] ;# MGTYRXP0_224 GTYE4_CHANNEL_X1Y20 / GTYE4_COMMON_X1Y5
set_property -dict {LOC BC1 } [get_ports {pcie_rx_n[15]}] ;# MGTYRXN0_224 GTYE4_CHANNEL_X1Y20 / GTYE4_COMMON_X1Y5
set_property -dict {LOC BF5 } [get_ports {pcie_tx_p[15]}] ;# MGTYTXP0_224 GTYE4_CHANNEL_X1Y20 / GTYE4_COMMON_X1Y5
set_property -dict {LOC BF4 } [get_ports {pcie_tx_n[15]}] ;# MGTYTXN0_224 GTYE4_CHANNEL_X1Y20 / GTYE4_COMMON_X1Y5
set_property -dict {LOC AT11} [get_ports pcie_refclk_0_p] ;# MGTREFCLK0P_225
set_property -dict {LOC AT10} [get_ports pcie_refclk_0_n] ;# MGTREFCLK0N_225
#set_property -dict {LOC AH11} [get_ports pcie_refclk_1_p] ;# MGTREFCLK0P_227
#set_property -dict {LOC AH10} [get_ports pcie_refclk_1_n] ;# MGTREFCLK0N_227
set_property -dict {LOC AR26 IOSTANDARD LVCMOS18 PULLUP true} [get_ports pcie_rst_n]

# 100 MHz MGT reference clock
create_clock -period 10 -name pcie_mgt_refclk [get_ports pcie_refclk_0_p]
#create_clock -period 10 -name pcie_mgt_refclk [get_ports pcie_refclk_1_p]

set_false_path -from [get_ports {pcie_rst_n}]
set_input_delay 0 [get_ports {pcie_rst_n}]
