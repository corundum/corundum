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

# DDR4 A refclk
set_property -dict {LOC BA34 IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr4_a_refclk_p]
set_property -dict {LOC BB34 IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr4_a_refclk_n]
#create_clock -period 3.750 -name clk_ddr4_a_refclk [get_ports clk_ddr4_a_refclk_p]

# DDR4 B refclk
set_property -dict {LOC C36  IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr4_b_refclk_p]
set_property -dict {LOC C37  IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr4_b_refclk_n]
#create_clock -period 3.750 -name clk_ddr4_b_refclk [get_ports clk_ddr4_b_refclk_p]

# SODIMM A refclk
set_property -dict {LOC AV27 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports clk_sodimm_a_refclk_p]
set_property -dict {LOC AV28 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports clk_sodimm_a_refclk_n]
#create_clock -period 3.750 -name clk_sodimm_a_refclk [get_ports clk_sodimm_a_refclk_p]

# SODIMM B refclk
set_property -dict {LOC H19  IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_sodimm_b_refclk_p]
set_property -dict {LOC H18  IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_sodimm_b_refclk_n]
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

# BMC interface
set_property -dict {LOC AW28 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 4} [get_ports bmc_clk]
set_property -dict {LOC AY27 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 4} [get_ports bmc_nss]
set_property -dict {LOC AY28 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 4} [get_ports bmc_mosi]
set_property -dict {LOC AY26 IOSTANDARD LVCMOS18} [get_ports bmc_miso]

set_false_path -to [get_ports {bmc_clk bmc_nss bmc_mosi}]
set_output_delay 0 [get_ports {bmc_clk bmc_nss bmc_mosi}]
set_false_path -from [get_ports {bmc_miso}]
set_input_delay 0 [get_ports {bmc_miso}]

# QSFP28 Interfaces
set_property -dict {LOC AP43} [get_ports {qsfp_0_rx_p[0]}] ;# MGTYRXP3_121 GTYE4_CHANNEL_X0Y11 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AP44} [get_ports {qsfp_0_rx_n[0]}] ;# MGTYRXN3_121 GTYE4_CHANNEL_X0Y11 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AP38} [get_ports {qsfp_0_tx_p[0]}] ;# MGTYTXP3_121 GTYE4_CHANNEL_X0Y11 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AP39} [get_ports {qsfp_0_tx_n[0]}] ;# MGTYTXN3_121 GTYE4_CHANNEL_X0Y11 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AT43} [get_ports {qsfp_0_rx_p[1]}] ;# MGTYRXP1_121 GTYE4_CHANNEL_X0Y9 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AT44} [get_ports {qsfp_0_rx_n[1]}] ;# MGTYRXN1_121 GTYE4_CHANNEL_X0Y9 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AT38} [get_ports {qsfp_0_tx_p[1]}] ;# MGTYTXP1_121 GTYE4_CHANNEL_X0Y9 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AT39} [get_ports {qsfp_0_tx_n[1]}] ;# MGTYTXN1_121 GTYE4_CHANNEL_X0Y9 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AR45} [get_ports {qsfp_0_rx_p[2]}] ;# MGTYRXP2_121 GTYE4_CHANNEL_X0Y10 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AR46} [get_ports {qsfp_0_rx_n[2]}] ;# MGTYRXN2_121 GTYE4_CHANNEL_X0Y10 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AR40} [get_ports {qsfp_0_tx_p[2]}] ;# MGTYTXP2_121 GTYE4_CHANNEL_X0Y10 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AR41} [get_ports {qsfp_0_tx_n[2]}] ;# MGTYTXN2_121 GTYE4_CHANNEL_X0Y10 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AU45} [get_ports {qsfp_0_rx_p[3]}] ;# MGTYRXP0_121 GTYE4_CHANNEL_X0Y8 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AU46} [get_ports {qsfp_0_rx_n[3]}] ;# MGTYRXN0_121 GTYE4_CHANNEL_X0Y8 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AU40} [get_ports {qsfp_0_tx_p[3]}] ;# MGTYTXP0_121 GTYE4_CHANNEL_X0Y8 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AU41} [get_ports {qsfp_0_tx_n[3]}] ;# MGTYTXN0_121 GTYE4_CHANNEL_X0Y8 / GTYE4_COMMON_X0Y2
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

set_property -dict {LOC AF43} [get_ports {qsfp_1_rx_p[0]}] ;# MGTYRXP3_123 GTYE4_CHANNEL_X0Y19 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AF44} [get_ports {qsfp_1_rx_n[0]}] ;# MGTYRXN3_123 GTYE4_CHANNEL_X0Y19 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AF38} [get_ports {qsfp_1_tx_p[0]}] ;# MGTYTXP3_123 GTYE4_CHANNEL_X0Y19 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AF39} [get_ports {qsfp_1_tx_n[0]}] ;# MGTYTXN3_123 GTYE4_CHANNEL_X0Y19 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AH43} [get_ports {qsfp_1_rx_p[1]}] ;# MGTYRXP1_123 GTYE4_CHANNEL_X0Y17 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AH44} [get_ports {qsfp_1_rx_n[1]}] ;# MGTYRXN1_123 GTYE4_CHANNEL_X0Y17 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AH38} [get_ports {qsfp_1_tx_p[1]}] ;# MGTYTXP1_123 GTYE4_CHANNEL_X0Y17 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AH39} [get_ports {qsfp_1_tx_n[1]}] ;# MGTYTXN1_123 GTYE4_CHANNEL_X0Y17 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AG45} [get_ports {qsfp_1_rx_p[2]}] ;# MGTYRXP2_123 GTYE4_CHANNEL_X0Y18 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AG46} [get_ports {qsfp_1_rx_n[2]}] ;# MGTYRXN2_123 GTYE4_CHANNEL_X0Y18 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AG40} [get_ports {qsfp_1_tx_p[2]}] ;# MGTYTXP2_123 GTYE4_CHANNEL_X0Y18 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AG41} [get_ports {qsfp_1_tx_n[2]}] ;# MGTYTXN2_123 GTYE4_CHANNEL_X0Y18 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AJ45} [get_ports {qsfp_1_rx_p[3]}] ;# MGTYRXP0_123 GTYE4_CHANNEL_X0Y16 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AJ46} [get_ports {qsfp_1_rx_n[3]}] ;# MGTYRXN0_123 GTYE4_CHANNEL_X0Y16 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AJ40} [get_ports {qsfp_1_tx_p[3]}] ;# MGTYTXP0_123 GTYE4_CHANNEL_X0Y16 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AJ41} [get_ports {qsfp_1_tx_n[3]}] ;# MGTYTXN0_123 GTYE4_CHANNEL_X0Y16 / GTYE4_COMMON_X0Y4
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

set_property -dict {LOC V43 } [get_ports {qsfp_2_rx_p[0]}] ;# MGTYRXP3_125 GTYE4_CHANNEL_X0Y27 / GTYE4_COMMON_X0Y6
set_property -dict {LOC V44 } [get_ports {qsfp_2_rx_n[0]}] ;# MGTYRXN3_125 GTYE4_CHANNEL_X0Y27 / GTYE4_COMMON_X0Y6
set_property -dict {LOC V38 } [get_ports {qsfp_2_tx_p[0]}] ;# MGTYTXP3_125 GTYE4_CHANNEL_X0Y27 / GTYE4_COMMON_X0Y6
set_property -dict {LOC V39 } [get_ports {qsfp_2_tx_n[0]}] ;# MGTYTXN3_125 GTYE4_CHANNEL_X0Y27 / GTYE4_COMMON_X0Y6
set_property -dict {LOC Y43 } [get_ports {qsfp_2_rx_p[1]}] ;# MGTYRXP1_125 GTYE4_CHANNEL_X0Y25 / GTYE4_COMMON_X0Y6
set_property -dict {LOC Y44 } [get_ports {qsfp_2_rx_n[1]}] ;# MGTYRXN1_125 GTYE4_CHANNEL_X0Y25 / GTYE4_COMMON_X0Y6
set_property -dict {LOC Y38 } [get_ports {qsfp_2_tx_p[1]}] ;# MGTYTXP1_125 GTYE4_CHANNEL_X0Y25 / GTYE4_COMMON_X0Y6
set_property -dict {LOC Y39 } [get_ports {qsfp_2_tx_n[1]}] ;# MGTYTXN1_125 GTYE4_CHANNEL_X0Y25 / GTYE4_COMMON_X0Y6
set_property -dict {LOC W45 } [get_ports {qsfp_2_rx_p[2]}] ;# MGTYRXP2_125 GTYE4_CHANNEL_X0Y26 / GTYE4_COMMON_X0Y6
set_property -dict {LOC W46 } [get_ports {qsfp_2_rx_n[2]}] ;# MGTYRXN2_125 GTYE4_CHANNEL_X0Y26 / GTYE4_COMMON_X0Y6
set_property -dict {LOC W40 } [get_ports {qsfp_2_tx_p[2]}] ;# MGTYTXP2_125 GTYE4_CHANNEL_X0Y26 / GTYE4_COMMON_X0Y6
set_property -dict {LOC W41 } [get_ports {qsfp_2_tx_n[2]}] ;# MGTYTXN2_125 GTYE4_CHANNEL_X0Y26 / GTYE4_COMMON_X0Y6
set_property -dict {LOC AA45} [get_ports {qsfp_2_rx_p[3]}] ;# MGTYRXP0_125 GTYE4_CHANNEL_X0Y24 / GTYE4_COMMON_X0Y6
set_property -dict {LOC AA46} [get_ports {qsfp_2_rx_n[3]}] ;# MGTYRXN0_125 GTYE4_CHANNEL_X0Y24 / GTYE4_COMMON_X0Y6
set_property -dict {LOC AA40} [get_ports {qsfp_2_tx_p[3]}] ;# MGTYTXP0_125 GTYE4_CHANNEL_X0Y24 / GTYE4_COMMON_X0Y6
set_property -dict {LOC AA41} [get_ports {qsfp_2_tx_n[3]}] ;# MGTYTXN0_125 GTYE4_CHANNEL_X0Y24 / GTYE4_COMMON_X0Y6
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

set_property -dict {LOC K43 } [get_ports {qsfp_3_rx_p[0]}] ;# MGTYRXP3_127 GTYE4_CHANNEL_X0Y35 / GTYE4_COMMON_X0Y8
set_property -dict {LOC K44 } [get_ports {qsfp_3_rx_n[0]}] ;# MGTYRXN3_127 GTYE4_CHANNEL_X0Y35 / GTYE4_COMMON_X0Y8
set_property -dict {LOC J40 } [get_ports {qsfp_3_tx_p[0]}] ;# MGTYTXP3_127 GTYE4_CHANNEL_X0Y35 / GTYE4_COMMON_X0Y8
set_property -dict {LOC J41 } [get_ports {qsfp_3_tx_n[0]}] ;# MGTYTXN3_127 GTYE4_CHANNEL_X0Y35 / GTYE4_COMMON_X0Y8
set_property -dict {LOC M43 } [get_ports {qsfp_3_rx_p[1]}] ;# MGTYRXP1_127 GTYE4_CHANNEL_X0Y33 / GTYE4_COMMON_X0Y8
set_property -dict {LOC M44 } [get_ports {qsfp_3_rx_n[1]}] ;# MGTYRXN1_127 GTYE4_CHANNEL_X0Y33 / GTYE4_COMMON_X0Y8
set_property -dict {LOC M38 } [get_ports {qsfp_3_tx_p[1]}] ;# MGTYTXP1_127 GTYE4_CHANNEL_X0Y33 / GTYE4_COMMON_X0Y8
set_property -dict {LOC M39 } [get_ports {qsfp_3_tx_n[1]}] ;# MGTYTXN1_127 GTYE4_CHANNEL_X0Y33 / GTYE4_COMMON_X0Y8
set_property -dict {LOC L45 } [get_ports {qsfp_3_rx_p[2]}] ;# MGTYRXP2_127 GTYE4_CHANNEL_X0Y34 / GTYE4_COMMON_X0Y8
set_property -dict {LOC L46 } [get_ports {qsfp_3_rx_n[2]}] ;# MGTYRXN2_127 GTYE4_CHANNEL_X0Y34 / GTYE4_COMMON_X0Y8
set_property -dict {LOC L40 } [get_ports {qsfp_3_tx_p[2]}] ;# MGTYTXP2_127 GTYE4_CHANNEL_X0Y34 / GTYE4_COMMON_X0Y8
set_property -dict {LOC L41 } [get_ports {qsfp_3_tx_n[2]}] ;# MGTYTXN2_127 GTYE4_CHANNEL_X0Y34 / GTYE4_COMMON_X0Y8
set_property -dict {LOC N45 } [get_ports {qsfp_3_rx_p[3]}] ;# MGTYRXP0_127 GTYE4_CHANNEL_X0Y32 / GTYE4_COMMON_X0Y8
set_property -dict {LOC N46 } [get_ports {qsfp_3_rx_n[3]}] ;# MGTYRXN0_127 GTYE4_CHANNEL_X0Y32 / GTYE4_COMMON_X0Y8
set_property -dict {LOC N40 } [get_ports {qsfp_3_tx_p[3]}] ;# MGTYTXP0_127 GTYE4_CHANNEL_X0Y32 / GTYE4_COMMON_X0Y8
set_property -dict {LOC N41 } [get_ports {qsfp_3_tx_n[3]}] ;# MGTYTXN0_127 GTYE4_CHANNEL_X0Y32 / GTYE4_COMMON_X0Y8
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

# DDR4 A (U100, U101, U102, U103)
# 4x MT40A512M16JY-083E
set_property -dict {LOC BD34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[0]}]
set_property -dict {LOC AV33 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[1]}]
set_property -dict {LOC AM32 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[2]}]
set_property -dict {LOC AL34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[3]}]
set_property -dict {LOC BE35 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[4]}]
set_property -dict {LOC AY33 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[5]}]
set_property -dict {LOC AY35 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[6]}]
set_property -dict {LOC AW33 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[7]}]
set_property -dict {LOC AW34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[8]}]
set_property -dict {LOC AU34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[9]}]
set_property -dict {LOC AN34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[10]}]
set_property -dict {LOC BC34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[11]}]
set_property -dict {LOC BE36 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[12]}]
set_property -dict {LOC AL32 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[13]}]
set_property -dict {LOC BB37 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[14]}]
set_property -dict {LOC AM34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[15]}]
set_property -dict {LOC AP33 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_adr[16]}]
set_property -dict {LOC AY36 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_ba[0]}]
set_property -dict {LOC BA33 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_ba[1]}]
set_property -dict {LOC AW36 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_bg[0]}]
set_property -dict {LOC AR33 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_bg[1]}]
set_property -dict {LOC AN32 IOSTANDARD DIFF_SSTL12_DCI } [get_ports {ddr4_a_ck_t[0]}]
set_property -dict {LOC AN33 IOSTANDARD DIFF_SSTL12_DCI } [get_ports {ddr4_a_ck_c[0]}]
set_property -dict {LOC AV34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_cke[0]}]
set_property -dict {LOC AP34 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_cs_n[0]}]
set_property -dict {LOC AL33 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_act_n}]
set_property -dict {LOC BD35 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_a_odt[0]}]
set_property -dict {LOC AW35 IOSTANDARD LVCMOS12 DRIVE 8} [get_ports {ddr4_a_reset_n}]
set_property -dict {LOC BD36 IOSTANDARD LVCMOS12 DRIVE 8} [get_ports {ddr4_a_ten}]

set_property -dict {LOC Y33  IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[0]}]
set_property -dict {LOC W34  IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[1]}]
set_property -dict {LOC AA34 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[2]}]
set_property -dict {LOC Y32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[3]}]
set_property -dict {LOC W33  IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[4]}]
set_property -dict {LOC W30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[5]}]
set_property -dict {LOC AB34 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[6]}]
set_property -dict {LOC Y30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[7]}]
set_property -dict {LOC AD33 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[8]}]
set_property -dict {LOC AC34 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[9]}]
set_property -dict {LOC AE33 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[10]}]
set_property -dict {LOC AC33 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[11]}]
set_property -dict {LOC AF30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[12]}]
set_property -dict {LOC AC32 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[13]}]
set_property -dict {LOC AE30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[14]}]
set_property -dict {LOC AD34 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[15]}]
set_property -dict {LOC AF34 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[16]}]
set_property -dict {LOC AJ33 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[17]}]
set_property -dict {LOC AG34 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[18]}]
set_property -dict {LOC AG32 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[19]}]
set_property -dict {LOC AF33 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[20]}]
set_property -dict {LOC AG31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[21]}]
set_property -dict {LOC AF32 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[22]}]
set_property -dict {LOC AH33 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[23]}]
set_property -dict {LOC AK31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[24]}]
set_property -dict {LOC AK28 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[25]}]
set_property -dict {LOC AJ31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[26]}]
set_property -dict {LOC AJ29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[27]}]
set_property -dict {LOC AG29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[28]}]
set_property -dict {LOC AJ28 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[29]}]
set_property -dict {LOC AG30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[30]}]
set_property -dict {LOC AJ30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[31]}]
set_property -dict {LOC AP29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[32]}]
set_property -dict {LOC AM31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[33]}]
set_property -dict {LOC AN31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[34]}]
set_property -dict {LOC AL30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[35]}]
set_property -dict {LOC AP30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[36]}]
set_property -dict {LOC AL29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[37]}]
set_property -dict {LOC AR30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[38]}]
set_property -dict {LOC AN29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[39]}]
set_property -dict {LOC AW31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[40]}]
set_property -dict {LOC AV32 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[41]}]
set_property -dict {LOC AV31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[42]}]
set_property -dict {LOC AU31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[43]}]
set_property -dict {LOC AU30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[44]}]
set_property -dict {LOC AU32 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[45]}]
set_property -dict {LOC AT29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[46]}]
set_property -dict {LOC AT30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[47]}]
set_property -dict {LOC AY32 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[48]}]
set_property -dict {LOC BB29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[49]}]
set_property -dict {LOC AY30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[50]}]
set_property -dict {LOC BB31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[51]}]
set_property -dict {LOC BA30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[52]}]
set_property -dict {LOC BB30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[53]}]
set_property -dict {LOC AY31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[54]}]
set_property -dict {LOC BA29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[55]}]
set_property -dict {LOC BC29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[56]}]
set_property -dict {LOC BF30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[57]}]
set_property -dict {LOC BD33 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[58]}]
set_property -dict {LOC BE30 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[59]}]
set_property -dict {LOC BD29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[60]}]
set_property -dict {LOC BE31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[61]}]
set_property -dict {LOC BE33 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[62]}]
set_property -dict {LOC BE32 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dq[63]}]
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
set_property -dict {LOC AA32 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dm_dbi_n[0]}]
set_property -dict {LOC AE31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dm_dbi_n[1]}]
set_property -dict {LOC AH34 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dm_dbi_n[2]}]
set_property -dict {LOC AJ27 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dm_dbi_n[3]}]
set_property -dict {LOC AP31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dm_dbi_n[4]}]
set_property -dict {LOC AW29 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dm_dbi_n[5]}]
set_property -dict {LOC BC31 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dm_dbi_n[6]}]
set_property -dict {LOC BF32 IOSTANDARD POD12_DCI       } [get_ports {ddr4_a_dm_dbi_n[7]}]

# DDR4 B (U200, U201, U202, U203)
# 4x MT40A512M16JY-083E
set_property -dict {LOC E37  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[0]}]
set_property -dict {LOC D36  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[1]}]
set_property -dict {LOC E36  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[2]}]
set_property -dict {LOC B35  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[3]}]
set_property -dict {LOC D35  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[4]}]
set_property -dict {LOC C32  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[5]}]
set_property -dict {LOC D39  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[6]}]
set_property -dict {LOC D33  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[7]}]
set_property -dict {LOC E40  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[8]}]
set_property -dict {LOC E35  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[9]}]
set_property -dict {LOC A38  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[10]}]
set_property -dict {LOC E39  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[11]}]
set_property -dict {LOC B37  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[12]}]
set_property -dict {LOC D31  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[13]}]
set_property -dict {LOC B39  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[14]}]
set_property -dict {LOC C31  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[15]}]
set_property -dict {LOC B31  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_adr[16]}]
set_property -dict {LOC D40  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_ba[0]}]
set_property -dict {LOC B32  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_ba[1]}]
set_property -dict {LOC B40  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_bg[0]}]
set_property -dict {LOC B36  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_bg[1]}]
set_property -dict {LOC A32  IOSTANDARD DIFF_SSTL12_DCI } [get_ports {ddr4_b_ck_t[0]}]
set_property -dict {LOC A33  IOSTANDARD DIFF_SSTL12_DCI } [get_ports {ddr4_b_ck_c[0]}]
set_property -dict {LOC C33  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_cke[0]}]
set_property -dict {LOC A37  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_cs_n[0]}]
set_property -dict {LOC A40  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_act_n}]
set_property -dict {LOC C34  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_b_odt[0]}]
set_property -dict {LOC D34  IOSTANDARD LVCMOS12 DRIVE 8} [get_ports {ddr4_b_reset_n}]
set_property -dict {LOC A35  IOSTANDARD LVCMOS12 DRIVE 8} [get_ports {ddr4_b_ten}]

set_property -dict {LOC B30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[0]}]
set_property -dict {LOC C29  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[1]}]
set_property -dict {LOC B29  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[2]}]
set_property -dict {LOC A29  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[3]}]
set_property -dict {LOC A30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[4]}]
set_property -dict {LOC D29  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[5]}]
set_property -dict {LOC E30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[6]}]
set_property -dict {LOC D30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[7]}]
set_property -dict {LOC H29  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[8]}]
set_property -dict {LOC E28  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[9]}]
set_property -dict {LOC G29  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[10]}]
set_property -dict {LOC G27  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[11]}]
set_property -dict {LOC E27  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[12]}]
set_property -dict {LOC D28  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[13]}]
set_property -dict {LOC G26  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[14]}]
set_property -dict {LOC F27  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[15]}]
set_property -dict {LOC J28  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[16]}]
set_property -dict {LOC L28  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[17]}]
set_property -dict {LOC J29  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[18]}]
set_property -dict {LOC L27  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[19]}]
set_property -dict {LOC H28  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[20]}]
set_property -dict {LOC M27  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[21]}]
set_property -dict {LOC H27  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[22]}]
set_property -dict {LOC K28  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[23]}]
set_property -dict {LOC N28  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[24]}]
set_property -dict {LOC R27  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[25]}]
set_property -dict {LOC P28  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[26]}]
set_property -dict {LOC T27  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[27]}]
set_property -dict {LOC P26  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[28]}]
set_property -dict {LOC R26  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[29]}]
set_property -dict {LOC N26  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[30]}]
set_property -dict {LOC T26  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[31]}]
set_property -dict {LOC F33  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[32]}]
set_property -dict {LOC G32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[33]}]
set_property -dict {LOC H32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[34]}]
set_property -dict {LOC E32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[35]}]
set_property -dict {LOC F32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[36]}]
set_property -dict {LOC G31  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[37]}]
set_property -dict {LOC E33  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[38]}]
set_property -dict {LOC H31  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[39]}]
set_property -dict {LOC L33  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[40]}]
set_property -dict {LOC J31  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[41]}]
set_property -dict {LOC L32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[42]}]
set_property -dict {LOC K33  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[43]}]
set_property -dict {LOC M30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[44]}]
set_property -dict {LOC K32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[45]}]
set_property -dict {LOC L30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[46]}]
set_property -dict {LOC K31  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[47]}]
set_property -dict {LOC N33  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[48]}]
set_property -dict {LOC R31  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[49]}]
set_property -dict {LOC N34  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[50]}]
set_property -dict {LOC P34  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[51]}]
set_property -dict {LOC N32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[52]}]
set_property -dict {LOC R32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[53]}]
set_property -dict {LOC N31  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[54]}]
set_property -dict {LOC P31  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[55]}]
set_property -dict {LOC U31  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[56]}]
set_property -dict {LOC U30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[57]}]
set_property -dict {LOC T32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[58]}]
set_property -dict {LOC V31  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[59]}]
set_property -dict {LOC T30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[60]}]
set_property -dict {LOC T33  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[61]}]
set_property -dict {LOC R33  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[62]}]
set_property -dict {LOC U32  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dq[63]}]
set_property -dict {LOC A27  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_t[0]}]
set_property -dict {LOC A28  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_c[0]}]
set_property -dict {LOC F28  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_t[1]}]
set_property -dict {LOC F29  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_c[1]}]
set_property -dict {LOC K26  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_t[2]}]
set_property -dict {LOC K27  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_c[2]}]
set_property -dict {LOC P29  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_t[3]}]
set_property -dict {LOC N29  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_c[3]}]
set_property -dict {LOC J33  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_t[4]}]
set_property -dict {LOC H33  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_c[4]}]
set_property -dict {LOC K30  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_t[5]}]
set_property -dict {LOC J30  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_c[5]}]
set_property -dict {LOC M34  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_t[6]}]
set_property -dict {LOC L34  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_c[6]}]
set_property -dict {LOC V32  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_t[7]}]
set_property -dict {LOC V33  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_b_dqs_c[7]}]
set_property -dict {LOC C27  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dm_dbi_n[0]}]
set_property -dict {LOC J26  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dm_dbi_n[1]}]
set_property -dict {LOC M29  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dm_dbi_n[2]}]
set_property -dict {LOC T28  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dm_dbi_n[3]}]
set_property -dict {LOC G30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dm_dbi_n[4]}]
set_property -dict {LOC M31  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dm_dbi_n[5]}]
set_property -dict {LOC R30  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dm_dbi_n[6]}]
set_property -dict {LOC U34  IOSTANDARD POD12_DCI       } [get_ports {ddr4_b_dm_dbi_n[7]}]

# DDR4 SODIMM A
set_property -dict {LOC BE15 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_a_adr[0]}]
set_property -dict {LOC BF15 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_a_adr[1]}]
set_property -dict {LOC BD16 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_a_adr[2]}]
set_property -dict {LOC BD15 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_a_adr[3]}]
set_property -dict {LOC BE16 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_a_adr[4]}]
set_property -dict {LOC BD14 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_a_adr[5]}]
set_property -dict {LOC BC14 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_a_adr[6]}]
set_property -dict {LOC BC13 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_a_adr[7]}]
set_property -dict {LOC AT14 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_a_adr[8]}]
set_property -dict {LOC AR16 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_a_adr[9]}]
set_property -dict {LOC AR15 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_a_adr[10]}]
set_property -dict {LOC AP15 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_a_adr[11]}]
set_property -dict {LOC AP14 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_a_adr[12]}]
set_property -dict {LOC AM15 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_a_adr[13]}]
set_property -dict {LOC AN13 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_a_adr[14]}]
set_property -dict {LOC AP13 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_a_adr[15]}]
set_property -dict {LOC AR13 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_a_adr[16]}]
set_property -dict {LOC AL15 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_a_ba[0]}]
set_property -dict {LOC AN14 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_a_ba[1]}]
set_property -dict {LOC AL14 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_a_bg[0]}]
set_property -dict {LOC AM14 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_a_bg[1]}]
set_property -dict {LOC BD13 IOSTANDARD DIFF_SSTL12_DCI } [get_ports {ddr4_sodimm_a_ck_t[0]}]
set_property -dict {LOC BE13 IOSTANDARD DIFF_SSTL12_DCI } [get_ports {ddr4_sodimm_a_ck_c[0]}]
set_property -dict {LOC AT13 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_a_cke[0]}]
set_property -dict {LOC BB12 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_a_cs_n[0]}]
#set_property -dict {LOC BA17 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_a_cs_n[2]}]
#set_property -dict {LOC AU21 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_a_cs_n[3]}]
set_property -dict {LOC BF14 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_a_act_n}]
set_property -dict {LOC BF13 IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_a_odt[0]}]
set_property -dict {LOC BC11 IOSTANDARD LVCMOS12 DRIVE 8} [get_ports {ddr4_sodimm_a_reset_n}]
set_property -dict {LOC AU19 IOSTANDARD LVCMOS12        } [get_ports {ddr4_sodimm_a_alert_n}]
set_property -dict {LOC AV17 IOSTANDARD LVCMOS12        } [get_ports {ddr4_sodimm_a_event_n}]

set_property -dict {LOC BE8  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[0]}]
set_property -dict {LOC BE12 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[1]}]
set_property -dict {LOC BF10 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[2]}]
set_property -dict {LOC BD8  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[3]}]
set_property -dict {LOC BD9  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[4]}]
set_property -dict {LOC BF12 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[5]}]
set_property -dict {LOC BF8  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[6]}]
set_property -dict {LOC BF9  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[7]}]
set_property -dict {LOC BB11 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[8]}]
set_property -dict {LOC BA9  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[9]}]
set_property -dict {LOC BC8  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[10]}]
set_property -dict {LOC BC9  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[11]}]
set_property -dict {LOC BB10 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[12]}]
set_property -dict {LOC BA8  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[13]}]
set_property -dict {LOC BB9  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[14]}]
set_property -dict {LOC BC7  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[15]}]
set_property -dict {LOC AY11 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[16]}]
set_property -dict {LOC BA15 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[17]}]
set_property -dict {LOC BA14 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[18]}]
set_property -dict {LOC AY13 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[19]}]
set_property -dict {LOC AY12 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[20]}]
set_property -dict {LOC BA13 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[21]}]
set_property -dict {LOC AY16 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[22]}]
set_property -dict {LOC AY15 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[23]}]
set_property -dict {LOC AW15 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[24]}]
set_property -dict {LOC AW16 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[25]}]
set_property -dict {LOC AU16 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[26]}]
set_property -dict {LOC AV13 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[27]}]
set_property -dict {LOC AU13 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[28]}]
set_property -dict {LOC AT15 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[29]}]
set_property -dict {LOC AV16 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[30]}]
set_property -dict {LOC AU15 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[31]}]
set_property -dict {LOC AN16 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[32]}]
set_property -dict {LOC AM20 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[33]}]
set_property -dict {LOC AM19 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[34]}]
set_property -dict {LOC AN19 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[35]}]
set_property -dict {LOC AM16 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[36]}]
set_property -dict {LOC AL20 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[37]}]
set_property -dict {LOC AL19 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[38]}]
set_property -dict {LOC AP19 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[39]}]
set_property -dict {LOC AP20 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[40]}]
set_property -dict {LOC AR18 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[41]}]
set_property -dict {LOC AP18 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[42]}]
set_property -dict {LOC AT20 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[43]}]
set_property -dict {LOC AU20 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[44]}]
set_property -dict {LOC AU17 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[45]}]
set_property -dict {LOC AR20 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[46]}]
set_property -dict {LOC AT18 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[47]}]
set_property -dict {LOC AW20 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[48]}]
set_property -dict {LOC AW19 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[49]}]
set_property -dict {LOC AW18 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[50]}]
set_property -dict {LOC AV19 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[51]}]
set_property -dict {LOC AY18 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[52]}]
set_property -dict {LOC AY20 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[53]}]
set_property -dict {LOC AV18 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[54]}]
set_property -dict {LOC BA18 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[55]}]
set_property -dict {LOC BE18 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[56]}]
set_property -dict {LOC BB17 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[57]}]
set_property -dict {LOC BC18 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[58]}]
set_property -dict {LOC BD18 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[59]}]
set_property -dict {LOC BC17 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[60]}]
set_property -dict {LOC BF19 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[61]}]
set_property -dict {LOC BB19 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[62]}]
set_property -dict {LOC BF18 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[63]}]
#set_property -dict {LOC AP16 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[64]}]
#set_property -dict {LOC BF17 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[65]}]
#set_property -dict {LOC BB16 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[66]}]
#set_property -dict {LOC AW13 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[67]}]
#set_property -dict {LOC BF7  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[68]}]
#set_property -dict {LOC BD11 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[69]}]
#set_property -dict {LOC AN17 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dq[70]}]
set_property -dict {LOC BE11 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_a_dqs_t[0]}]
set_property -dict {LOC BE10 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_a_dqs_c[0]}]
set_property -dict {LOC BA7  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_a_dqs_t[1]}]
set_property -dict {LOC BB7  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_a_dqs_c[1]}]
set_property -dict {LOC BB15 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_a_dqs_t[2]}]
set_property -dict {LOC BB14 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_a_dqs_c[2]}]
set_property -dict {LOC AU14 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_a_dqs_t[3]}]
set_property -dict {LOC AV14 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_a_dqs_c[3]}]
set_property -dict {LOC AL17 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_a_dqs_t[4]}]
set_property -dict {LOC AM17 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_a_dqs_c[4]}]
set_property -dict {LOC AR17 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_a_dqs_t[5]}]
set_property -dict {LOC AT17 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_a_dqs_c[5]}]
set_property -dict {LOC AV21 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_a_dqs_t[6]}]
set_property -dict {LOC AW21 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_a_dqs_c[6]}]
set_property -dict {LOC BC19 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_a_dqs_t[7]}]
set_property -dict {LOC BD19 IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_a_dqs_c[7]}]
set_property -dict {LOC BE7  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dm_dbi_n[0]}]
set_property -dict {LOC BC12 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dm_dbi_n[1]}]
set_property -dict {LOC BA12 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dm_dbi_n[2]}]
set_property -dict {LOC AW14 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dm_dbi_n[3]}]
set_property -dict {LOC AN18 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dm_dbi_n[4]}]
set_property -dict {LOC AT19 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dm_dbi_n[5]}]
set_property -dict {LOC AY17 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dm_dbi_n[6]}]
set_property -dict {LOC BE17 IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_a_dm_dbi_n[7]}]

# DDR4 SODIMM B
set_property -dict {LOC G20  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_b_adr[0]}]
set_property -dict {LOC G19  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_b_adr[1]}]
set_property -dict {LOC F20  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_b_adr[2]}]
set_property -dict {LOC E21  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_b_adr[3]}]
set_property -dict {LOC F19  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_b_adr[4]}]
set_property -dict {LOC E20  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_b_adr[5]}]
set_property -dict {LOC F18  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_b_adr[6]}]
set_property -dict {LOC F17  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_b_adr[7]}]
set_property -dict {LOC G21  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_b_adr[8]}]
set_property -dict {LOC D19  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_b_adr[9]}]
set_property -dict {LOC C19  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_b_adr[10]}]
set_property -dict {LOC D21  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_b_adr[11]}]
set_property -dict {LOC D20  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_b_adr[12]}]
set_property -dict {LOC A19  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_b_adr[13]}]
set_property -dict {LOC B21  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_b_adr[14]}]
set_property -dict {LOC D18  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_b_adr[15]}]
set_property -dict {LOC C18  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_b_adr[16]}]
set_property -dict {LOC B19  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_b_ba[0]}]
set_property -dict {LOC C21  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_b_ba[1]}]
set_property -dict {LOC B20  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_b_bg[0]}]
set_property -dict {LOC A20  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_b_bg[1]}]
set_property -dict {LOC E18  IOSTANDARD DIFF_SSTL12_DCI } [get_ports {ddr4_sodimm_b_ck_t[0]}]
set_property -dict {LOC E17  IOSTANDARD DIFF_SSTL12_DCI } [get_ports {ddr4_sodimm_b_ck_c[0]}]
set_property -dict {LOC A18  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_b_cke[0]}]
set_property -dict {LOC H21  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_b_cs_n[0]}]
#set_property -dict {LOC K13  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_b_cs_n[2]}]
#set_property -dict {LOC D14  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_b_cs_n[3]}]
set_property -dict {LOC L18  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_b_act_n}]
set_property -dict {LOC L19  IOSTANDARD SSTL12_DCI      } [get_ports {ddr4_sodimm_b_odt[0]}]
set_property -dict {LOC L20  IOSTANDARD LVCMOS12 DRIVE 8} [get_ports {ddr4_sodimm_b_reset_n}]
set_property -dict {LOC C17  IOSTANDARD LVCMOS12        } [get_ports {ddr4_sodimm_b_alert_n}]
set_property -dict {LOC F14  IOSTANDARD LVCMOS12        } [get_ports {ddr4_sodimm_b_event_n}]

set_property -dict {LOC N22  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[0]}]
set_property -dict {LOC M25  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[1]}]
set_property -dict {LOC P23  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[2]}]
set_property -dict {LOC P25  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[3]}]
set_property -dict {LOC R25  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[4]}]
set_property -dict {LOC M24  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[5]}]
set_property -dict {LOC M22  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[6]}]
set_property -dict {LOC N23  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[7]}]
set_property -dict {LOC C24  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[8]}]
set_property -dict {LOC B25  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[9]}]
set_property -dict {LOC C26  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[10]}]
set_property -dict {LOC A24  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[11]}]
set_property -dict {LOC C23  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[12]}]
set_property -dict {LOC A25  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[13]}]
set_property -dict {LOC B24  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[14]}]
set_property -dict {LOC B26  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[15]}]
set_property -dict {LOC K22  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[16]}]
set_property -dict {LOC J23  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[17]}]
set_property -dict {LOC H23  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[18]}]
set_property -dict {LOC J24  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[19]}]
set_property -dict {LOC L22  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[20]}]
set_property -dict {LOC H24  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[21]}]
set_property -dict {LOC L23  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[22]}]
set_property -dict {LOC K23  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[23]}]
set_property -dict {LOC F23  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[24]}]
set_property -dict {LOC F24  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[25]}]
set_property -dict {LOC E25  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[26]}]
set_property -dict {LOC F22  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[27]}]
set_property -dict {LOC G22  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[28]}]
set_property -dict {LOC D24  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[29]}]
set_property -dict {LOC D25  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[30]}]
set_property -dict {LOC D23  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[31]}]
set_property -dict {LOC A13  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[32]}]
set_property -dict {LOC A17  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[33]}]
set_property -dict {LOC B16  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[34]}]
set_property -dict {LOC C14  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[35]}]
set_property -dict {LOC A14  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[36]}]
set_property -dict {LOC B17  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[37]}]
set_property -dict {LOC C16  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[38]}]
set_property -dict {LOC B14  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[39]}]
set_property -dict {LOC E16  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[40]}]
set_property -dict {LOC D15  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[41]}]
set_property -dict {LOC E15  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[42]}]
set_property -dict {LOC G15  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[43]}]
set_property -dict {LOC F15  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[44]}]
set_property -dict {LOC E13  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[45]}]
set_property -dict {LOC D16  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[46]}]
set_property -dict {LOC F13  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[47]}]
set_property -dict {LOC J13  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[48]}]
set_property -dict {LOC J15  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[49]}]
set_property -dict {LOC H14  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[50]}]
set_property -dict {LOC J16  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[51]}]
set_property -dict {LOC K16  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[52]}]
set_property -dict {LOC H13  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[53]}]
set_property -dict {LOC J14  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[54]}]
set_property -dict {LOC K15  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[55]}]
set_property -dict {LOC P15  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[56]}]
set_property -dict {LOC M14  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[57]}]
set_property -dict {LOC M16  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[58]}]
set_property -dict {LOC R15  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[59]}]
set_property -dict {LOC L14  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[60]}]
set_property -dict {LOC P14  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[61]}]
set_property -dict {LOC N16  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[62]}]
set_property -dict {LOC N14  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[63]}]
#set_property -dict {LOC J19  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[64]}]
#set_property -dict {LOC K21  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[65]}]
#set_property -dict {LOC H22  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[66]}]
#set_property -dict {LOC G24  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[67]}]
#set_property -dict {LOC P21  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[68]}]
#set_property -dict {LOC D26  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[69]}]
#set_property -dict {LOC C13  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dq[70]}]
set_property -dict {LOC P24  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_b_dqs_t[0]}]
set_property -dict {LOC N24  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_b_dqs_c[0]}]
set_property -dict {LOC A23  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_b_dqs_t[1]}]
set_property -dict {LOC A22  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_b_dqs_c[1]}]
set_property -dict {LOC K25  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_b_dqs_t[2]}]
set_property -dict {LOC J25  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_b_dqs_c[2]}]
set_property -dict {LOC E23  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_b_dqs_t[3]}]
set_property -dict {LOC E22  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_b_dqs_c[3]}]
set_property -dict {LOC B15  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_b_dqs_t[4]}]
set_property -dict {LOC A15  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_b_dqs_c[4]}]
set_property -dict {LOC G17  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_b_dqs_t[5]}]
set_property -dict {LOC G16  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_b_dqs_c[5]}]
set_property -dict {LOC H17  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_b_dqs_t[6]}]
set_property -dict {LOC H16  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_b_dqs_c[6]}]
set_property -dict {LOC R16  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_b_dqs_t[7]}]
set_property -dict {LOC P16  IOSTANDARD DIFF_POD12_DCI  } [get_ports {ddr4_sodimm_b_dqs_c[7]}]
set_property -dict {LOC R21  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dm_dbi_n[0]}]
set_property -dict {LOC C22  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dm_dbi_n[1]}]
set_property -dict {LOC L25  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dm_dbi_n[2]}]
set_property -dict {LOC G25  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dm_dbi_n[3]}]
set_property -dict {LOC D13  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dm_dbi_n[4]}]
set_property -dict {LOC G14  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dm_dbi_n[5]}]
set_property -dict {LOC L13  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dm_dbi_n[6]}]
set_property -dict {LOC P13  IOSTANDARD POD12_DCI       } [get_ports {ddr4_sodimm_b_dm_dbi_n[7]}]
