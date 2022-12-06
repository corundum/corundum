# XDC constraints for the DNPCIe_40G_KU_LL_2QSFP
# part: xcku040-ffva1156-2-e

# General configuration
set_property CFGBVS GND                                [current_design]
set_property CONFIG_VOLTAGE 1.8                        [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true           [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN Pullup         [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50            [current_design]
set_property BITSTREAM.CONFIG.BPI_SYNC_MODE Type2      [current_design]
set_property CONFIG_MODE BPI16                         [current_design]
set_property BITSTREAM.CONFIG.OVERTEMPSHUTDOWN Enable  [current_design]

# LEDs
set_property -dict {LOC H22  IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {user_led[0]}]
set_property -dict {LOC E20  IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {user_led[1]}]
set_property -dict {LOC F22  IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {user_led[2]}]
set_property -dict {LOC G22  IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {user_led[3]}]
set_property -dict {LOC F12  IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {user_led[4]}]
set_property -dict {LOC F10  IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {user_led[5]}]
set_property -dict {LOC D10  IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {user_led[6]}]
set_property -dict {LOC AK33 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {user_led[7]}]

set_property -dict {LOC AG14 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {qsfp0_leg_green}]
set_property -dict {LOC AP14 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {qsfp0_leg_red}]
set_property -dict {LOC AH29 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {qsfp1_leg_green}]
set_property -dict {LOC AL33 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {qsfp1_leg_red}]

set_false_path -to [get_ports {user_led[*] qsfp0_led[*] qsfp1_led[*]}]
set_output_delay 0 [get_ports {user_led[*] qsfp0_led[*] qsfp1_led[*]}]

# Reset button
#set_property -dict {LOC N21  IOSTANDARD LVCMOS12} [get_ports reset]

#set_false_path -from [get_ports {reset}]
#set_input_delay 0 [get_ports {reset}]

# GPIO

# DNCPU
#set_property -dict {LOC Y26  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[0]]  ;# J10.1
#set_property -dict {LOC AA22 IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[1]]  ;# J10.2
#set_property -dict {LOC Y27  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[2]]  ;# J10.3
#set_property -dict {LOC AB22 IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[3]]  ;# J10.4
#set_property -dict {LOC AD25 IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[4]]  ;# J10.5
#set_property -dict {LOC AC22 IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[5]]  ;# J10.6
#set_property -dict {LOC AD26 IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[6]]  ;# J10.7
#set_property -dict {LOC AC23 IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[7]]  ;# J10.8
#set_property -dict {LOC AB24 IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[8]]  ;# J10.9
#set_property -dict {LOC AA20 IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[9]]  ;# J10.10
#set_property -dict {LOC AC24 IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[10]] ;# J10.11
#set_property -dict {LOC AB20 IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[11]] ;# J10.12
#set_property -dict {LOC AC26 IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[12]] ;# J10.13
#set_property -dict {LOC AB21 IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[13]] ;# J10.14
#set_property -dict {LOC AC27 IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[14]] ;# J10.15
#set_property -dict {LOC AC21 IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[15]] ;# J10.16
#set_property -dict {LOC AA27 IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[16]] ;# J10.17
#set_property -dict {LOC Y23  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[17]] ;# J10.18
#set_property -dict {LOC AB27 IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[18]] ;# J10.19
#set_property -dict {LOC AA23 IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[19]] ;# J10.20
#set_property -dict {LOC AB25 IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[20]] ;# J10.21
#set_property -dict {LOC AA24 IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[21]] ;# J10.22
#set_property -dict {LOC AB26 IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[22]] ;# J10.23
#set_property -dict {LOC AA25 IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[23]] ;# J10.24
#set_property -dict {LOC AA28 IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[24]] ;# J10.25
#set_property -dict {LOC Y22  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[25]] ;# J10.26
#set_property -dict {LOC W23  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[26]] ;# J10.27
#set_property -dict {LOC V27  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[27]] ;# J10.28
#set_property -dict {LOC W24  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[28]] ;# J10.29
#set_property -dict {LOC V28  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[29]] ;# J10.30
#set_property -dict {LOC W25  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[30]] ;# J10.31
#set_property -dict {LOC U24  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[31]] ;# J10.32
#set_property -dict {LOC Y25  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[32]] ;# J10.33
#set_property -dict {LOC U25  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[33]] ;# J10.34
#set_property -dict {LOC U21  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[34]] ;# J10.35
#set_property -dict {LOC W28  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[35]] ;# J10.36
#set_property -dict {LOC U22  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[36]] ;# J10.37
#set_property -dict {LOC Y28  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[37]] ;# J10.38
#set_property -dict {LOC V22  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[38]] ;# J10.39
#set_property -dict {LOC U26  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[39]] ;# J10.40
#set_property -dict {LOC V23  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[40]] ;# J10.41
#set_property -dict {LOC U27  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[41]] ;# J10.42
#set_property -dict {LOC T22  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[42]] ;# J10.43
#set_property -dict {LOC V29  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[43]] ;# J10.44
#set_property -dict {LOC T23  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[44]] ;# J10.45
#set_property -dict {LOC W29  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[45]] ;# J10.46
#set_property -dict {LOC V21  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[46]] ;# J10.47
#set_property -dict {LOC V26  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[47]] ;# J10.48
#set_property -dict {LOC W21  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[48]] ;# J10.49
#set_property -dict {LOC W26  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[49]] ;# J10.50
#set_property -dict {LOC Y21  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[50]] ;# J10.51
#set_property -dict {LOC U29  IOSTANDARD LVCMOS12} [get_ports gpio_j10_a[51]] ;# J10.52

#set_property -dict {LOC AE27 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[0]]  ;# J10.121
#set_property -dict {LOC AG31 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[1]]  ;# J10.122
#set_property -dict {LOC AF27 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[2]]  ;# J10.123
#set_property -dict {LOC AG32 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[3]]  ;# J10.124
#set_property -dict {LOC AE28 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[4]]  ;# J10.125
#set_property -dict {LOC AF33 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[5]]  ;# J10.126
#set_property -dict {LOC AF28 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[6]]  ;# J10.127
#set_property -dict {LOC AG34 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[7]]  ;# J10.128
#set_property -dict {LOC AC28 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[8]]  ;# J10.129
#set_property -dict {LOC AE32 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[9]]  ;# J10.130
#set_property -dict {LOC AD28 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[10]] ;# J10.131
#set_property -dict {LOC AF32 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[11]] ;# J10.132
#set_property -dict {LOC AF29 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[12]] ;# J10.133
#set_property -dict {LOC AE33 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[13]] ;# J10.134
#set_property -dict {LOC AG29 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[14]] ;# J10.135
#set_property -dict {LOC AF34 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[15]] ;# J10.136
#set_property -dict {LOC AD29 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[16]] ;# J10.137
#set_property -dict {LOC AD30 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[17]] ;# J10.138
#set_property -dict {LOC AE30 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[18]] ;# J10.139
#set_property -dict {LOC AD31 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[19]] ;# J10.140
#set_property -dict {LOC AF30 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[20]] ;# J10.141
#set_property -dict {LOC AC31 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[21]] ;# J10.142
#set_property -dict {LOC AG30 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[22]] ;# J10.143
#set_property -dict {LOC AC32 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[23]] ;# J10.144
#set_property -dict {LOC AC29 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[24]] ;# J10.145
#set_property -dict {LOC AE31 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[25]] ;# J10.146
#set_property -dict {LOC AA32 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[26]] ;# J10.147
#set_property -dict {LOC W33  IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[27]] ;# J10.148
#set_property -dict {LOC AB32 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[28]] ;# J10.149
#set_property -dict {LOC Y33  IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[29]] ;# J10.150
#set_property -dict {LOC AB30 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[30]] ;# J10.151
#set_property -dict {LOC W30  IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[31]] ;# J10.152
#set_property -dict {LOC AB31 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[32]] ;# J10.153
#set_property -dict {LOC Y30  IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[33]] ;# J10.154
#set_property -dict {LOC AC34 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[34]] ;# J10.155
#set_property -dict {LOC V33  IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[35]] ;# J10.156
#set_property -dict {LOC AD34 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[36]] ;# J10.157
#set_property -dict {LOC W34  IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[37]] ;# J10.158
#set_property -dict {LOC AA29 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[38]] ;# J10.159
#set_property -dict {LOC Y31  IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[39]] ;# J10.160
#set_property -dict {LOC AB29 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[40]] ;# J10.161
#set_property -dict {LOC Y32  IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[41]] ;# J10.162
#set_property -dict {LOC AA34 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[42]] ;# J10.163
#set_property -dict {LOC U34  IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[43]] ;# J10.164
#set_property -dict {LOC AB34 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[44]] ;# J10.165
#set_property -dict {LOC V34  IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[45]] ;# J10.166
#set_property -dict {LOC AC33 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[46]] ;# J10.167
#set_property -dict {LOC V31  IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[47]] ;# J10.168
#set_property -dict {LOC AD33 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[48]] ;# J10.169
#set_property -dict {LOC W31  IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[49]] ;# J10.170
#set_property -dict {LOC AA33 IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[50]] ;# J10.171
#set_property -dict {LOC V32  IOSTANDARD LVCMOS12} [get_ports gpio_j10_b[51]] ;# J10.172

# UART
#set_property -dict {LOC F20 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports uart_txd]
#set_property -dict {LOC G20 IOSTANDARD LVCMOS12} [get_ports uart_rxd]

#set_false_path -to [get_ports {uart_txd}]
#set_output_delay 0 [get_ports {uart_txd}]
#set_false_path -from [get_ports {uart_rxd}]
#set_input_delay 0 [get_ports {uart_rxd}]

# QSFP Interfaces
set_property -dict {LOC Y2  } [get_ports qsfp0_rx1_p] ;# MGTHRXP0_226 GTHE3_CHANNEL_X1Y44 / GTHE3_COMMON_X1Y11
set_property -dict {LOC Y1  } [get_ports qsfp0_rx1_n] ;# MGTHRXN0_226 GTHE3_CHANNEL_X1Y44 / GTHE3_COMMON_X1Y11
set_property -dict {LOC AA4 } [get_ports qsfp0_tx1_p] ;# MGTHTXP0_226 GTHE3_CHANNEL_X1Y44 / GTHE3_COMMON_X1Y11
set_property -dict {LOC AA3 } [get_ports qsfp0_tx1_n] ;# MGTHTXN0_226 GTHE3_CHANNEL_X1Y44 / GTHE3_COMMON_X1Y11
set_property -dict {LOC V2  } [get_ports qsfp0_rx2_p] ;# MGTHRXP1_226 GTHE3_CHANNEL_X1Y45 / GTHE3_COMMON_X1Y11
set_property -dict {LOC V1  } [get_ports qsfp0_rx2_n] ;# MGTHRXN1_226 GTHE3_CHANNEL_X1Y45 / GTHE3_COMMON_X1Y11
set_property -dict {LOC W4  } [get_ports qsfp0_tx2_p] ;# MGTHTXP1_226 GTHE3_CHANNEL_X1Y45 / GTHE3_COMMON_X1Y11
set_property -dict {LOC W3  } [get_ports qsfp0_tx2_n] ;# MGTHTXN1_226 GTHE3_CHANNEL_X1Y45 / GTHE3_COMMON_X1Y11
set_property -dict {LOC T2  } [get_ports qsfp0_rx3_p] ;# MGTHRXP2_226 GTHE3_CHANNEL_X1Y46 / GTHE3_COMMON_X1Y11
set_property -dict {LOC T1  } [get_ports qsfp0_rx3_n] ;# MGTHRXN2_226 GTHE3_CHANNEL_X1Y46 / GTHE3_COMMON_X1Y11
set_property -dict {LOC U4  } [get_ports qsfp0_tx3_p] ;# MGTHTXP2_226 GTHE3_CHANNEL_X1Y46 / GTHE3_COMMON_X1Y11
set_property -dict {LOC U3  } [get_ports qsfp0_tx3_n] ;# MGTHTXN2_226 GTHE3_CHANNEL_X1Y46 / GTHE3_COMMON_X1Y11
set_property -dict {LOC P2  } [get_ports qsfp0_rx4_p] ;# MGTHRXP3_226 GTHE3_CHANNEL_X1Y47 / GTHE3_COMMON_X1Y11
set_property -dict {LOC P1  } [get_ports qsfp0_rx4_n] ;# MGTHRXN3_226 GTHE3_CHANNEL_X1Y47 / GTHE3_COMMON_X1Y11
set_property -dict {LOC R4  } [get_ports qsfp0_tx4_p] ;# MGTHTXP3_226 GTHE3_CHANNEL_X1Y47 / GTHE3_COMMON_X1Y11
set_property -dict {LOC R3  } [get_ports qsfp0_tx4_n] ;# MGTHTXN3_226 GTHE3_CHANNEL_X1Y47 / GTHE3_COMMON_X1Y11
set_property -dict {LOC V6  } [get_ports qsfp0_mgt_refclk_p] ;# MGTREFCLK0P_226 from Y5.4
set_property -dict {LOC V5  } [get_ports qsfp0_mgt_refclk_n] ;# MGTREFCLK0N_226 from Y5.5
set_property -dict {LOC AJ13 IOSTANDARD LVCMOS25 SLEW SLOW DRIVE 12} [get_ports qsfp0_modsell]
set_property -dict {LOC AE12 IOSTANDARD LVCMOS25 SLEW SLOW DRIVE 12} [get_ports qsfp0_resetl]
set_property -dict {LOC AE26 IOSTANDARD LVCMOS12 PULLUP true} [get_ports qsfp0_modprsl]
set_property -dict {LOC AE21 IOSTANDARD LVCMOS12 PULLUP true} [get_ports qsfp0_intl]
set_property -dict {LOC AF12 IOSTANDARD LVCMOS25 SLEW SLOW DRIVE 12} [get_ports qsfp0_lpmode]
set_property -dict {LOC AJ11 IOSTANDARD LVCMOS25 SLEW SLOW DRIVE 12} [get_ports {qsfp0_fs[0]}] ;# to Y5.8
set_property -dict {LOC AF10 IOSTANDARD LVCMOS25 SLEW SLOW DRIVE 12} [get_ports {qsfp0_fs[1]}] ;# to Y5.7
set_property -dict {LOC AD11 IOSTANDARD LVCMOS25 SLEW SLOW DRIVE 12 PULLUP true} [get_ports qsfp0_i2c_scl]
set_property -dict {LOC AE11 IOSTANDARD LVCMOS25 SLEW SLOW DRIVE 12 PULLUP true} [get_ports qsfp0_i2c_sda]

# 156.25 MHz MGT reference clock (from Y5 Si534 FB000184G, FS = 0b00)
create_clock -period 6.400 -name qsfp0_mgt_refclk [get_ports qsfp0_mgt_refclk_p]

# 200 MHz MGT reference clock (from Y5 Si534 FB000184G, FS = 0b01)
#create_clock -period 5.000 -name qsfp0_mgt_refclk [get_ports qsfp0_mgt_refclk_p]

# 250 MHz MGT reference clock (from Y5 Si534 FB000184G, FS = 0b10)
#create_clock -period 4.000 -name qsfp0_mgt_refclk [get_ports qsfp0_mgt_refclk_p]

# 312.5 MHz MGT reference clock (from Y5 Si534 FB000184G, FS = 0b11)
#create_clock -period 3.200 -name qsfp0_mgt_refclk [get_ports qsfp0_mgt_refclk_p]

set_false_path -to [get_ports {qsfp0_modsell qsfp0_resetl qsfp0_lpmode qsfp0_fs[*]}]
set_output_delay 0 [get_ports {qsfp0_modsell qsfp0_resetl qsfp0_lpmode qsfp0_fs[*]}]
set_false_path -from [get_ports {qsfp0_modprsl qsfp0_intl}]
set_input_delay 0 [get_ports {qsfp0_modprsl qsfp0_intl}]

set_false_path -to [get_ports {qsfp0_i2c_scl qsfp0_i2c_sda}]
set_output_delay 0 [get_ports {qsfp0_i2c_scl qsfp0_i2c_sda}]
set_false_path -from [get_ports {qsfp0_i2c_scl qsfp0_i2c_sda}]
set_input_delay 0 [get_ports {qsfp0_i2c_scl qsfp0_i2c_sda}]

set_property -dict {LOC M2  } [get_ports qsfp1_rx1_p] ;# MGTHRXP0_227 GTHE3_CHANNEL_X1Y40 / GTHE3_COMMON_X1Y2
set_property -dict {LOC M1  } [get_ports qsfp1_rx1_n] ;# MGTHRXN0_227 GTHE3_CHANNEL_X1Y40 / GTHE3_COMMON_X1Y2
set_property -dict {LOC N4  } [get_ports qsfp1_tx1_p] ;# MGTHTXP0_227 GTHE3_CHANNEL_X1Y40 / GTHE3_COMMON_X1Y2
set_property -dict {LOC N3  } [get_ports qsfp1_tx1_n] ;# MGTHTXN0_227 GTHE3_CHANNEL_X1Y40 / GTHE3_COMMON_X1Y2
set_property -dict {LOC K2  } [get_ports qsfp1_rx2_p] ;# MGTHRXP1_227 GTHE3_CHANNEL_X1Y41 / GTHE3_COMMON_X1Y2
set_property -dict {LOC K1  } [get_ports qsfp1_rx2_n] ;# MGTHRXN1_227 GTHE3_CHANNEL_X1Y41 / GTHE3_COMMON_X1Y2
set_property -dict {LOC L4  } [get_ports qsfp1_tx2_p] ;# MGTHTXP1_227 GTHE3_CHANNEL_X1Y41 / GTHE3_COMMON_X1Y2
set_property -dict {LOC L3  } [get_ports qsfp1_tx2_n] ;# MGTHTXN1_227 GTHE3_CHANNEL_X1Y41 / GTHE3_COMMON_X1Y2
set_property -dict {LOC H2  } [get_ports qsfp1_rx3_p] ;# MGTHRXP2_227 GTHE3_CHANNEL_X1Y42 / GTHE3_COMMON_X1Y2
set_property -dict {LOC H1  } [get_ports qsfp1_rx3_n] ;# MGTHRXN2_227 GTHE3_CHANNEL_X1Y42 / GTHE3_COMMON_X1Y2
set_property -dict {LOC J4  } [get_ports qsfp1_tx3_p] ;# MGTHTXP2_227 GTHE3_CHANNEL_X1Y42 / GTHE3_COMMON_X1Y2
set_property -dict {LOC J3  } [get_ports qsfp1_tx3_n] ;# MGTHTXN2_227 GTHE3_CHANNEL_X1Y42 / GTHE3_COMMON_X1Y2
set_property -dict {LOC F2  } [get_ports qsfp1_rx4_p] ;# MGTHRXP3_227 GTHE3_CHANNEL_X1Y43 / GTHE3_COMMON_X1Y2
set_property -dict {LOC F1  } [get_ports qsfp1_rx4_n] ;# MGTHRXN3_227 GTHE3_CHANNEL_X1Y43 / GTHE3_COMMON_X1Y2
set_property -dict {LOC G4  } [get_ports qsfp1_tx4_p] ;# MGTHTXP3_227 GTHE3_CHANNEL_X1Y43 / GTHE3_COMMON_X1Y2
set_property -dict {LOC G3  } [get_ports qsfp1_tx4_n] ;# MGTHTXN3_227 GTHE3_CHANNEL_X1Y43 / GTHE3_COMMON_X1Y2
set_property -dict {LOC P6  } [get_ports qsfp1_mgt_refclk_p] ;# MGTREFCLK0P_227 from Y4.4
set_property -dict {LOC P5  } [get_ports qsfp1_mgt_refclk_n] ;# MGTREFCLK0N_227 from Y4.5
set_property -dict {LOC AK13 IOSTANDARD LVCMOS25 SLEW SLOW DRIVE 12} [get_ports qsfp1_modsell]
set_property -dict {LOC AL13 IOSTANDARD LVCMOS25 SLEW SLOW DRIVE 12} [get_ports qsfp1_resetl]
set_property -dict {LOC AM9  IOSTANDARD LVCMOS25 PULLUP true} [get_ports qsfp1_modprsl]
set_property -dict {LOC AH13 IOSTANDARD LVCMOS25 PULLUP true} [get_ports qsfp1_intl]
set_property -dict {LOC AK11 IOSTANDARD LVCMOS25 SLEW SLOW DRIVE 12} [get_ports qsfp1_lpmode]
set_property -dict {LOC AG11 IOSTANDARD LVCMOS25 SLEW SLOW DRIVE 12} [get_ports {qsfp1_fs[0]}] ;# to Y4.8
set_property -dict {LOC AH11 IOSTANDARD LVCMOS25 SLEW SLOW DRIVE 12} [get_ports {qsfp1_fs[1]}] ;# to Y4.7
set_property -dict {LOC AE13 IOSTANDARD LVCMOS25 SLEW SLOW DRIVE 12 PULLUP true} [get_ports qsfp1_i2c_scl]
set_property -dict {LOC AF13 IOSTANDARD LVCMOS25 SLEW SLOW DRIVE 12 PULLUP true} [get_ports qsfp1_i2c_sda]

# 156.25 MHz MGT reference clock (from Y4 Si534 FB000184G, FS = 0b00)
create_clock -period 6.400 -name qsfp1_mgt_refclk [get_ports qsfp1_mgt_refclk_p]

# 200 MHz MGT reference clock (from Y4 Si534 FB000184G, FS = 0b01)
#create_clock -period 5.000 -name qsfp1_mgt_refclk [get_ports qsfp1_mgt_refclk_p]

# 250 MHz MGT reference clock (from Y4 Si534 FB000184G, FS = 0b10)
#create_clock -period 4.000 -name qsfp1_mgt_refclk [get_ports qsfp1_mgt_refclk_p]

# 312.5 MHz MGT reference clock (from Y4 Si534 FB000184G, FS = 0b11)
#create_clock -period 3.200 -name qsfp1_mgt_refclk [get_ports qsfp1_mgt_refclk_p]

set_false_path -to [get_ports {qsfp1_modsell qsfp1_resetl qsfp1_lpmode qsfp1_fs[*]}]
set_output_delay 0 [get_ports {qsfp1_modsell qsfp1_resetl qsfp1_lpmode qsfp1_fs[*]}]
set_false_path -from [get_ports {qsfp1_modprsl qsfp1_intl}]
set_input_delay 0 [get_ports {qsfp1_modprsl qsfp1_intl}]

set_false_path -to [get_ports {qsfp1_i2c_scl qsfp1_i2c_sda}]
set_output_delay 0 [get_ports {qsfp1_i2c_scl qsfp1_i2c_sda}]
set_false_path -from [get_ports {qsfp1_i2c_scl qsfp1_i2c_sda}]
set_input_delay 0 [get_ports {qsfp1_i2c_scl qsfp1_i2c_sda}]

# I2C EEPROM
set_property -dict {LOC AG9  IOSTANDARD LVCMOS25 SLEW SLOW DRIVE 12 PULLUP true} [get_ports eeprom_i2c_scl]
set_property -dict {LOC AE8  IOSTANDARD LVCMOS25 SLEW SLOW DRIVE 12 PULLUP true} [get_ports eeprom_i2c_sda]

set_false_path -to [get_ports {eeprom_i2c_sda eeprom_i2c_scl}]
set_output_delay 0 [get_ports {eeprom_i2c_sda eeprom_i2c_scl}]
set_false_path -from [get_ports {eeprom_i2c_sda eeprom_i2c_scl}]
set_input_delay 0 [get_ports {eeprom_i2c_sda eeprom_i2c_scl}]

# QSPI flash
#set_property -dict {LOC AF8  IOSTANDARD LVCMOS25 DRIVE 12 PULLUP true} [get_ports {qspi_clk}]
#set_property -dict {LOC AD10 IOSTANDARD LVCMOS25 DRIVE 12 PULLUP true} [get_ports {qspi_dq[0]}]
#set_property -dict {LOC AH8  IOSTANDARD LVCMOS25 DRIVE 12 PULLUP true} [get_ports {qspi_dq[1]}]
#set_property -dict {LOC AE10 IOSTANDARD LVCMOS25 DRIVE 12 PULLUP true} [get_ports {qspi_dq[2]}]
#set_property -dict {LOC AD9  IOSTANDARD LVCMOS25 DRIVE 12 PULLUP true} [get_ports {qspi_dq[3]}]
#set_property -dict {LOC AH9  IOSTANDARD LVCMOS25 DRIVE 12 PULLUP true} [get_ports {qspi_cs}]
#set_property -dict {LOC AD8  IOSTANDARD LVCMOS25 DRIVE 12 PULLUP true} [get_ports {qspi_reset}]

# PCIe Interface
set_property -dict {LOC AB2  } [get_ports {pcie_rx_p[0]}] ;# MGTHRXP3_225 GTHE3_CHANNEL_X0Y7 / GTHE3_COMMON_X0Y1
set_property -dict {LOC AB1  } [get_ports {pcie_rx_n[0]}] ;# MGTHRXN3_225 GTHE3_CHANNEL_X0Y7 / GTHE3_COMMON_X0Y1
set_property -dict {LOC AC4  } [get_ports {pcie_tx_p[0]}] ;# MGTHTXP3_225 GTHE3_CHANNEL_X0Y7 / GTHE3_COMMON_X0Y1
set_property -dict {LOC AC3  } [get_ports {pcie_tx_n[0]}] ;# MGTHTXN3_225 GTHE3_CHANNEL_X0Y7 / GTHE3_COMMON_X0Y1
set_property -dict {LOC AD2  } [get_ports {pcie_rx_p[1]}] ;# MGTHRXP2_225 GTHE3_CHANNEL_X0Y6 / GTHE3_COMMON_X0Y1
set_property -dict {LOC AD1  } [get_ports {pcie_rx_n[1]}] ;# MGTHRXN2_225 GTHE3_CHANNEL_X0Y6 / GTHE3_COMMON_X0Y1
set_property -dict {LOC AE4  } [get_ports {pcie_tx_p[1]}] ;# MGTHTXP2_225 GTHE3_CHANNEL_X0Y6 / GTHE3_COMMON_X0Y1
set_property -dict {LOC AE3  } [get_ports {pcie_tx_n[1]}] ;# MGTHTXN2_225 GTHE3_CHANNEL_X0Y6 / GTHE3_COMMON_X0Y1
set_property -dict {LOC AF2  } [get_ports {pcie_rx_p[2]}] ;# MGTHRXP1_225 GTHE3_CHANNEL_X0Y5 / GTHE3_COMMON_X0Y1
set_property -dict {LOC AF1  } [get_ports {pcie_rx_n[2]}] ;# MGTHRXN1_225 GTHE3_CHANNEL_X0Y5 / GTHE3_COMMON_X0Y1
set_property -dict {LOC AG4  } [get_ports {pcie_tx_p[2]}] ;# MGTHTXP1_225 GTHE3_CHANNEL_X0Y5 / GTHE3_COMMON_X0Y1
set_property -dict {LOC AG3  } [get_ports {pcie_tx_n[2]}] ;# MGTHTXN1_225 GTHE3_CHANNEL_X0Y5 / GTHE3_COMMON_X0Y1
set_property -dict {LOC AH2  } [get_ports {pcie_rx_p[3]}] ;# MGTHRXP0_225 GTHE3_CHANNEL_X0Y4 / GTHE3_COMMON_X0Y1
set_property -dict {LOC AH1  } [get_ports {pcie_rx_n[3]}] ;# MGTHRXN0_225 GTHE3_CHANNEL_X0Y4 / GTHE3_COMMON_X0Y1
set_property -dict {LOC AH6  } [get_ports {pcie_tx_p[3]}] ;# MGTHTXP0_225 GTHE3_CHANNEL_X0Y4 / GTHE3_COMMON_X0Y1
set_property -dict {LOC AH5  } [get_ports {pcie_tx_n[3]}] ;# MGTHTXN0_225 GTHE3_CHANNEL_X0Y4 / GTHE3_COMMON_X0Y1
set_property -dict {LOC AJ4  } [get_ports {pcie_rx_p[4]}] ;# MGTHRXP3_224 GTHE3_CHANNEL_X0Y3 / GTHE3_COMMON_X0Y0
set_property -dict {LOC AJ3  } [get_ports {pcie_rx_n[4]}] ;# MGTHRXN3_224 GTHE3_CHANNEL_X0Y3 / GTHE3_COMMON_X0Y0
set_property -dict {LOC AK6  } [get_ports {pcie_tx_p[4]}] ;# MGTHTXP3_224 GTHE3_CHANNEL_X0Y3 / GTHE3_COMMON_X0Y0
set_property -dict {LOC AK5  } [get_ports {pcie_tx_n[4]}] ;# MGTHTXN3_224 GTHE3_CHANNEL_X0Y3 / GTHE3_COMMON_X0Y0
set_property -dict {LOC AK2  } [get_ports {pcie_rx_p[5]}] ;# MGTHRXP2_224 GTHE3_CHANNEL_X0Y2 / GTHE3_COMMON_X0Y0
set_property -dict {LOC AK1  } [get_ports {pcie_rx_n[5]}] ;# MGTHRXN2_224 GTHE3_CHANNEL_X0Y2 / GTHE3_COMMON_X0Y0
set_property -dict {LOC AL4  } [get_ports {pcie_tx_p[5]}] ;# MGTHTXP2_224 GTHE3_CHANNEL_X0Y2 / GTHE3_COMMON_X0Y0
set_property -dict {LOC AL3  } [get_ports {pcie_tx_n[5]}] ;# MGTHTXN2_224 GTHE3_CHANNEL_X0Y2 / GTHE3_COMMON_X0Y0
set_property -dict {LOC AM2  } [get_ports {pcie_rx_p[6]}] ;# MGTHRXP1_224 GTHE3_CHANNEL_X0Y1 / GTHE3_COMMON_X0Y0
set_property -dict {LOC AM1  } [get_ports {pcie_rx_n[6]}] ;# MGTHRXN1_224 GTHE3_CHANNEL_X0Y1 / GTHE3_COMMON_X0Y0
set_property -dict {LOC AM6  } [get_ports {pcie_tx_p[6]}] ;# MGTHTXP1_224 GTHE3_CHANNEL_X0Y1 / GTHE3_COMMON_X0Y0
set_property -dict {LOC AM5  } [get_ports {pcie_tx_n[6]}] ;# MGTHTXN1_224 GTHE3_CHANNEL_X0Y1 / GTHE3_COMMON_X0Y0
set_property -dict {LOC AP2  } [get_ports {pcie_rx_p[7]}] ;# MGTHRXP0_224 GTHE3_CHANNEL_X0Y0 / GTHE3_COMMON_X0Y0
set_property -dict {LOC AP1  } [get_ports {pcie_rx_n[7]}] ;# MGTHRXN0_224 GTHE3_CHANNEL_X0Y0 / GTHE3_COMMON_X0Y0
set_property -dict {LOC AN4  } [get_ports {pcie_tx_p[7]}] ;# MGTHTXP0_224 GTHE3_CHANNEL_X0Y0 / GTHE3_COMMON_X0Y0
set_property -dict {LOC AN3  } [get_ports {pcie_tx_n[7]}] ;# MGTHTXN0_224 GTHE3_CHANNEL_X0Y0 / GTHE3_COMMON_X0Y0
set_property -dict {LOC AF6  } [get_ports pcie_mgt_refclk_p] ;# MGTREFCLK0P_224 from U80 ICS 1S1022EL
set_property -dict {LOC AF5  } [get_ports pcie_mgt_refclk_n] ;# MGTREFCLK0N_224 from U80 ICS 1S1022EL
set_property -dict {LOC K22  IOSTANDARD LVCMOS18 PULLUP true} [get_ports pcie_reset_n]

# 100 MHz MGT reference clock
create_clock -period 10 -name pcie_mgt_refclk [get_ports pcie_mgt_refclk_p]

set_false_path -from [get_ports {pcie_reset_n}]
set_input_delay 0 [get_ports {pcie_reset_n}]

# DDR4
# 9x MT40A512M8RH-083E
# Control
set_property -dict {LOC AG17 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[0]}]     ;# IO_L15P_T2L_N4_AD11P_45
set_property -dict {LOC AH16 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[1]}]     ;# IO_L14P_T2L_N2_GC_45
set_property -dict {LOC AF15 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[2]}]     ;# IO_L20P_T3L_N2_AD1P_45
set_property -dict {LOC AJ16 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[3]}]     ;# IO_L14N_T2L_N3_GC_45
set_property -dict {LOC AH19 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[4]}]     ;# IO_L17N_T2U_N9_AD10N_45
set_property -dict {LOC AJ15 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[5]}]     ;# IO_L16P_T2U_N6_QBC_AD3P_45
set_property -dict {LOC AE18 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[6]}]     ;# IO_L21P_T3L_N4_AD8P_45
set_property -dict {LOC AG15 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[7]}]     ;# IO_L18P_T2U_N10_AD2P_45
set_property -dict {LOC AD18 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[8]}]     ;# IO_L19N_T3L_N1_DBC_AD9N_45
set_property -dict {LOC AF14 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[9]}]     ;# IO_L20N_T3L_N3_AD1N_45
set_property -dict {LOC AJ18 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[10]}]    ;# IO_L11P_T1U_N8_GC_45
set_property -dict {LOC AD19 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[11]}]    ;# IO_L19P_T3L_N0_DBC_AD9P_45
set_property -dict {LOC AK16 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[12]}]    ;# IO_L12N_T1U_N11_GC_45
set_property -dict {LOC AG16 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[13]}]    ;# IO_L15N_T2L_N5_AD11N_45
set_property -dict {LOC AJ19 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[14]}]    ;# IO_T1U_N12_45
set_property -dict {LOC AL17 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[15]}]    ;# IO_L10N_T1U_N7_QBC_AD4N_45
set_property -dict {LOC AL14 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[16]}]    ;# IO_L7P_T1L_N0_QBC_AD13P_45
set_property -dict {LOC AF18 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_ba[0]}]      ;# IO_L21N_T3L_N5_AD8N_45
set_property -dict {LOC AJ14 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_ba[1]}]      ;# IO_L16N_T2U_N7_QBC_AD3N_45
set_property -dict {LOC AG19 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_bg[0]}]      ;# IO_L17P_T2U_N8_AD10P_45
set_property -dict {LOC AK15 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_bg[1]}]      ;# IO_L9P_T1L_N4_AD12P_45
set_property -dict {LOC AE17 IOSTANDARD DIFF_SSTL12_DCI} [get_ports {ddr4_ck_t}]       ;# IO_L23P_T3U_N8_45
set_property -dict {LOC AF17 IOSTANDARD DIFF_SSTL12_DCI} [get_ports {ddr4_ck_c}]       ;# IO_L23N_T3U_N9_45
set_property -dict {LOC AL18 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_cke}]        ;# IO_L10P_T1U_N6_QBC_AD4P_45
set_property -dict {LOC AL15 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_cs_n}]       ;# IO_L9N_T1L_N5_AD12N_45
set_property -dict {LOC AK17 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_act_n}]      ;# IO_L12P_T1U_N10_GC_45
set_property -dict {LOC AM19 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_odt}]        ;# IO_L8N_T1L_N3_AD5N_45
set_property -dict {LOC AE16 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_par}]        ;# IO_L22P_T3U_N6_DBC_AD0P_45
set_property -dict {LOC AD16 IOSTANDARD LVCMOS12       } [get_ports {ddr4_reset_n}]    ;# IO_L24P_T3U_N10_45
set_property -dict {LOC AD15 IOSTANDARD LVCMOS12       } [get_ports {ddr4_alert_n}]    ;# IO_L24N_T3U_N11_45
set_property -dict {LOC AD14 IOSTANDARD LVCMOS12       } [get_ports {ddr4_ten}]        ;# IO_T3U_N12_45
# U30
set_property -dict {LOC AD21 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[0]}] ;# IO_L1P_T0L_N0_DBC_44 to U30.DM_DBI_n
set_property -dict {LOC AF20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[0]}]       ;# IO_L2P_T0L_N2_44 to U30.DQ[7:0]
set_property -dict {LOC AG20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[1]}]       ;# IO_L2N_T0L_N3_44 to U30.DQ[7:0]
set_property -dict {LOC AD20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[2]}]       ;# IO_L3P_T0L_N4_AD15P_44 to U30.DQ[7:0]
set_property -dict {LOC AE20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[3]}]       ;# IO_L3N_T0L_N5_AD15N_44 to U30.DQ[7:0]
set_property -dict {LOC AG21 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[0]}]    ;# IO_L4P_T0U_N6_DBC_AD7P_44 to U30.DQS_t
set_property -dict {LOC AH21 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[0]}]    ;# IO_L4N_T0U_N7_DBC_AD7N_44 to U30.DQS_c
set_property -dict {LOC AE22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[4]}]       ;# IO_L5P_T0U_N8_AD14P_44 to U30.DQ[7:0]
set_property -dict {LOC AE23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[5]}]       ;# IO_L5N_T0U_N9_AD14N_44 to U30.DQ[7:0]
set_property -dict {LOC AF22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[6]}]       ;# IO_L6P_T0U_N10_AD6P_44 to U30.DQ[7:0]
set_property -dict {LOC AG22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[7]}]       ;# IO_L6N_T0U_N11_AD6N_44 to U30.DQ[7:0]
# U31
set_property -dict {LOC AJ21 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[1]}] ;# IO_L13P_T2L_N0_GC_QBC_44 to U31.DM_DBI_n
set_property -dict {LOC AK22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[8]}]       ;# IO_L14P_T2L_N2_GC_44 to U31.DQ[7:0]
set_property -dict {LOC AK23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[9]}]       ;# IO_L14N_T2L_N3_GC_44 to U31.DQ[7:0]
set_property -dict {LOC AL20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[10]}]      ;# IO_L15P_T2L_N4_AD11P_44 to U31.DQ[7:0]
set_property -dict {LOC AM20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[11]}]      ;# IO_L15N_T2L_N5_AD11N_44 to U31.DQ[7:0]
set_property -dict {LOC AJ20 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[1]}]    ;# IO_L16P_T2U_N6_QBC_AD3P_44 to U31.DQS_t
set_property -dict {LOC AK20 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[1]}]    ;# IO_L16N_T2U_N7_QBC_AD3N_44 to U31.DQS_c
set_property -dict {LOC AL22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[12]}]      ;# IO_L17P_T2U_N8_AD10P_44 to U31.DQ[7:0]
set_property -dict {LOC AL23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[13]}]      ;# IO_L17N_T2U_N9_AD10N_44 to U31.DQ[7:0]
set_property -dict {LOC AL24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[14]}]      ;# IO_L18P_T2U_N10_AD2P_44 to U31.DQ[7:0]
set_property -dict {LOC AL25 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[15]}]      ;# IO_L18N_T2U_N11_AD2N_44 to U31.DQ[7:0]
# U32
set_property -dict {LOC AH26 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[2]}] ;# IO_L1P_T0L_N0_DBC_46 to U32.DM_DBI_n
set_property -dict {LOC AM26 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[16]}]      ;# IO_L2P_T0L_N2_46 to U32.DQ[7:0]
set_property -dict {LOC AM27 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[17]}]      ;# IO_L2N_T0L_N3_46 to U32.DQ[7:0]
set_property -dict {LOC AK26 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[18]}]      ;# IO_L3P_T0L_N4_AD15P_46 to U32.DQ[7:0]
set_property -dict {LOC AK27 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[19]}]      ;# IO_L3N_T0L_N5_AD15N_46 to U32.DQ[7:0]
set_property -dict {LOC AL27 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[2]}]    ;# IO_L4P_T0U_N6_DBC_AD7P_46 to U32.DQS_t
set_property -dict {LOC AL28 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[2]}]    ;# IO_L4N_T0U_N7_DBC_AD7N_46 to U32.DQS_c
set_property -dict {LOC AH27 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[20]}]      ;# IO_L5P_T0U_N8_AD14P_46 to U32.DQ[7:0]
set_property -dict {LOC AH28 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[21]}]      ;# IO_L5N_T0U_N9_AD14N_46 to U32.DQ[7:0]
set_property -dict {LOC AJ28 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[22]}]      ;# IO_L6P_T0U_N10_AD6P_46 to U32.DQ[7:0]
set_property -dict {LOC AK28 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[23]}]      ;# IO_L6N_T0U_N11_AD6N_46 to U32.DQ[7:0]
# U33
set_property -dict {LOC AN26 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[3]}] ;# IO_L7P_T1L_N0_QBC_AD13P_46 to U33.DM_DBI_n
set_property -dict {LOC AP28 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[24]}]      ;# IO_L8P_T1L_N2_AD5P_46 to U33.DQ[7:0]
set_property -dict {LOC AP29 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[25]}]      ;# IO_L8N_T1L_N3_AD5N_46 to U33.DQ[7:0]
set_property -dict {LOC AN27 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[26]}]      ;# IO_L9P_T1L_N4_AD12P_46 to U33.DQ[7:0]
set_property -dict {LOC AN28 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[27]}]      ;# IO_L9N_T1L_N5_AD12N_46 to U33.DQ[7:0]
set_property -dict {LOC AN29 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[3]}]    ;# IO_L10P_T1U_N6_QBC_AD4P_46 to U33.DQS_t
set_property -dict {LOC AP30 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[3]}]    ;# IO_L10N_T1U_N7_QBC_AD4N_46 to U33.DQS_c
set_property -dict {LOC AL29 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[28]}]      ;# IO_L11P_T1U_N8_GC_46 to U33.DQ[7:0]
set_property -dict {LOC AM29 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[29]}]      ;# IO_L11N_T1U_N9_GC_46 to U33.DQ[7:0]
set_property -dict {LOC AL30 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[30]}]      ;# IO_L12P_T1U_N10_GC_46 to U33.DQ[7:0]
set_property -dict {LOC AM30 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[31]}]      ;# IO_L12N_T1U_N11_GC_46 to U33.DQ[7:0]
# U83
set_property -dict {LOC AN14 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[4]}] ;# IO_L1P_T0L_N0_DBC_45 to U83.DM_DBI_n
set_property -dict {LOC AN19 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[32]}]      ;# IO_L2P_T0L_N2_45 to U83.DQ[7:0]
set_property -dict {LOC AP18 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[33]}]      ;# IO_L2N_T0L_N3_45 to U83.DQ[7:0]
set_property -dict {LOC AM17 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[34]}]      ;# IO_L3P_T0L_N4_AD15P_45 to U83.DQ[7:0]
set_property -dict {LOC AN16 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[35]}]      ;# IO_L3N_T0L_N5_AD15N_45 to U83.DQ[7:0]
set_property -dict {LOC AN18 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[4]}]    ;# IO_L4P_T0U_N6_DBC_AD7P_45 to U83.DQS_t
set_property -dict {LOC AN17 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[4]}]    ;# IO_L4N_T0U_N7_DBC_AD7N_45 to U83.DQS_c
set_property -dict {LOC AM16 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[36]}]      ;# IO_L5P_T0U_N8_AD14P_45 to U83.DQ[7:0]
set_property -dict {LOC AM15 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[37]}]      ;# IO_L5N_T0U_N9_AD14N_45 to U83.DQ[7:0]
set_property -dict {LOC AP16 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[38]}]      ;# IO_L6P_T0U_N10_AD6P_45 to U83.DQ[7:0]
set_property -dict {LOC AP15 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[39]}]      ;# IO_L6N_T0U_N11_AD6N_45 to U83.DQ[7:0]
# U86
set_property -dict {LOC AM21 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[5]}] ;# IO_L19P_T3L_N0_DBC_AD9P_44 to U86.DM_DBI_n
set_property -dict {LOC AM22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[40]}]      ;# IO_L20P_T3L_N2_AD1P_44 to U86.DQ[7:0]
set_property -dict {LOC AN22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[41]}]      ;# IO_L20N_T3L_N3_AD1N_44 to U86.DQ[7:0]
set_property -dict {LOC AM24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[42]}]      ;# IO_L21P_T3L_N4_AD8P_44 to U86.DQ[7:0]
set_property -dict {LOC AN24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[43]}]      ;# IO_L21N_T3L_N5_AD8N_44 to U86.DQ[7:0]
set_property -dict {LOC AP20 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[5]}]    ;# IO_L22P_T3U_N6_DBC_AD0P_44 to U86.DQS_t
set_property -dict {LOC AP21 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[5]}]    ;# IO_L22N_T3U_N7_DBC_AD0N_44 to U86.DQS_c
set_property -dict {LOC AP24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[44]}]      ;# IO_L23P_T3U_N8_44 to U86.DQ[7:0]
set_property -dict {LOC AP25 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[45]}]      ;# IO_L23N_T3U_N9_44 to U86.DQ[7:0]
set_property -dict {LOC AN23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[46]}]      ;# IO_L24P_T3U_N10_44 to U86.DQ[7:0]
set_property -dict {LOC AP23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[47]}]      ;# IO_L24N_T3U_N11_44 to U86.DQ[7:0]
# U87
set_property -dict {LOC AE25 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[6]}] ;# IO_L7P_T1L_N0_QBC_AD13P_44 to U87.DM_DBI_n
set_property -dict {LOC AF23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[48]}]      ;# IO_L8P_T1L_N2_AD5P_44 to U87.DQ[7:0]
set_property -dict {LOC AF24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[49]}]      ;# IO_L8N_T1L_N3_AD5N_44 to U87.DQ[7:0]
set_property -dict {LOC AG24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[50]}]      ;# IO_L9P_T1L_N4_AD12P_44 to U87.DQ[7:0]
set_property -dict {LOC AG25 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[51]}]      ;# IO_L9N_T1L_N5_AD12N_44 to U87.DQ[7:0]
set_property -dict {LOC AH24 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[6]}]    ;# IO_L10P_T1U_N6_QBC_AD4P_44 to U87.DQS_t
set_property -dict {LOC AJ25 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[6]}]    ;# IO_L10N_T1U_N7_QBC_AD4N_44 to U87.DQS_c
set_property -dict {LOC AJ23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[52]}]      ;# IO_L11P_T1U_N8_GC_44 to U87.DQ[7:0]
set_property -dict {LOC AJ24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[53]}]      ;# IO_L11N_T1U_N9_GC_44 to U87.DQ[7:0]
set_property -dict {LOC AH22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[54]}]      ;# IO_L12P_T1U_N10_GC_44 to U87.DQ[7:0]
set_property -dict {LOC AH23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[55]}]      ;# IO_L12N_T1U_N11_GC_44 to U87.DQ[7:0]
# U88
set_property -dict {LOC AJ29 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[7]}] ;# IO_L13P_T2L_N0_GC_QBC_46 to U88.DM_DBI_n
set_property -dict {LOC AK31 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[56]}]      ;# IO_L14P_T2L_N2_GC_46 to U88.DQ[7:0]
set_property -dict {LOC AK32 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[57]}]      ;# IO_L14N_T2L_N3_GC_46 to U88.DQ[7:0]
set_property -dict {LOC AJ30 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[58]}]      ;# IO_L15P_T2L_N4_AD11P_46 to U88.DQ[7:0]
set_property -dict {LOC AJ31 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[59]}]      ;# IO_L15N_T2L_N5_AD11N_46 to U88.DQ[7:0]
set_property -dict {LOC AH33 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[7]}]    ;# IO_L16P_T2U_N6_QBC_AD3P_46 to U88.DQS_t
set_property -dict {LOC AJ33 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[7]}]    ;# IO_L16N_T2U_N7_QBC_AD3N_46 to U88.DQS_c
set_property -dict {LOC AH31 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[60]}]      ;# IO_L17P_T2U_N8_AD10P_46 to U88.DQ[7:0]
set_property -dict {LOC AH32 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[61]}]      ;# IO_L17N_T2U_N9_AD10N_46 to U88.DQ[7:0]
set_property -dict {LOC AH34 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[62]}]      ;# IO_L18P_T2U_N10_AD2P_46 to U88.DQ[7:0]
set_property -dict {LOC AJ34 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[63]}]      ;# IO_L18N_T2U_N11_AD2N_46 to U88.DQ[7:0]
# U89
set_property -dict {LOC AL32 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[8]}] ;# IO_L19P_T3L_N0_DBC_AD9P_46 to U89.DM_DBI_n
set_property -dict {LOC AN33 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[64]}]      ;# IO_L20P_T3L_N2_AD1P_46 to U89.DQ[7:0]
set_property -dict {LOC AP33 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[65]}]      ;# IO_L20N_T3L_N3_AD1N_46 to U89.DQ[7:0]
set_property -dict {LOC AN31 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[66]}]      ;# IO_L21P_T3L_N4_AD8P_46 to U89.DQ[7:0]
set_property -dict {LOC AP31 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[67]}]      ;# IO_L21N_T3L_N5_AD8N_46 to U89.DQ[7:0]
set_property -dict {LOC AN34 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[8]}]    ;# IO_L22P_T3U_N6_DBC_AD0P_46 to U89.DQS_t
set_property -dict {LOC AP34 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[8]}]    ;# IO_L22N_T3U_N7_DBC_AD0N_46 to U89.DQS_c
set_property -dict {LOC AM32 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[68]}]      ;# IO_L23P_T3U_N8_46 to U89.DQ[7:0]
set_property -dict {LOC AN32 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[69]}]      ;# IO_L23N_T3U_N9_46 to U89.DQ[7:0]
set_property -dict {LOC AL34 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[70]}]      ;# IO_L24P_T3U_N10_46 to U89.DQ[7:0]
set_property -dict {LOC AM34 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[71]}]      ;# IO_L24N_T3U_N11_46 to U89.DQ[7:0]

# 200 MHz DDR4 clock (Si598 FCA000126G) (Y6)
set_property -dict {LOC AH18 IOSTANDARD LVDS} [get_ports clk_ddr4_p] ;# from Y6.4
set_property -dict {LOC AH17 IOSTANDARD LVDS} [get_ports clk_ddr4_n] ;# from Y6.5
#create_clock -period 5.000 -name clk_ddr4 [get_ports clk_ddr4_p]

#set_property -dict {LOC AG12 IOSTANDARD LVCMOS25 SLEW SLOW DRIVE 12 PULLUP true} [get_ports clk_ddr4_i2c_scl]
#set_property -dict {LOC AH12 IOSTANDARD LVCMOS25 SLEW SLOW DRIVE 12 PULLUP true} [get_ports clk_ddr4_i2c_sda]

# 200 MHz RLD3 clock (Si598 FCA000126G) (Y3)
#set_property -dict {LOC D23  IOSTANDARD LVDS} [get_ports clk_rld3_p] ;# from Y3.4
#set_property -dict {LOC C23  IOSTANDARD LVDS} [get_ports clk_rld3_n] ;# from Y3.5
#create_clock -period 5.000 -name clk_rld3 [get_ports clk_rld3_p]

#set_property -dict {LOC AG10 IOSTANDARD LVCMOS25 SLEW SLOW DRIVE 12 PULLUP true} [get_ports clk_rld3_i2c_scl]
#set_property -dict {LOC AF9  IOSTANDARD LVCMOS25 SLEW SLOW DRIVE 12 PULLUP true} [get_ports clk_rld3_i2c_sda]

# BPI flash
set_property -dict {LOC M20  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_dq[4]}]
set_property -dict {LOC L20  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_dq[5]}]
set_property -dict {LOC R21  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_dq[6]}]
set_property -dict {LOC R22  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_dq[7]}]
set_property -dict {LOC P20  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_dq[8]}]
set_property -dict {LOC P21  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_dq[9]}]
set_property -dict {LOC N22  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_dq[10]}]
set_property -dict {LOC M22  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_dq[11]}]
set_property -dict {LOC R23  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_dq[12]}]
set_property -dict {LOC P23  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_dq[13]}]
set_property -dict {LOC R25  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_dq[14]}]
set_property -dict {LOC R26  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_dq[15]}]
set_property -dict {LOC T24  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_addr[0]}]
set_property -dict {LOC T25  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_addr[1]}]
set_property -dict {LOC T27  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_addr[2]}]
set_property -dict {LOC R27  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_addr[3]}]
set_property -dict {LOC P24  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_addr[4]}]
set_property -dict {LOC P25  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_addr[5]}]
set_property -dict {LOC P26  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_addr[6]}]
set_property -dict {LOC N26  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_addr[7]}]
set_property -dict {LOC N24  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_addr[8]}]
set_property -dict {LOC M24  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_addr[9]}]
set_property -dict {LOC M25  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_addr[10]}]
set_property -dict {LOC M26  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_addr[11]}]
set_property -dict {LOC L22  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_addr[12]}]
set_property -dict {LOC K23  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_addr[13]}]
set_property -dict {LOC L25  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_addr[14]}]
set_property -dict {LOC K25  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_addr[15]}]
set_property -dict {LOC L23  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_addr[16]}]
set_property -dict {LOC L24  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_addr[17]}]
set_property -dict {LOC M27  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_addr[18]}]
set_property -dict {LOC L27  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_addr[19]}]
set_property -dict {LOC J23  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_addr[20]}]
set_property -dict {LOC H24  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_addr[21]}]
set_property -dict {LOC J26  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_addr[22]}]
set_property -dict {LOC H26  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_addr[23]}]
set_property -dict {LOC J24  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_addr[24]}]
set_property -dict {LOC J25  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_addr[25]}]
set_property -dict {LOC G25  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_oe_n}]
set_property -dict {LOC G26  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_we_n}]
set_property -dict {LOC N27  IOSTANDARD LVCMOS18 DRIVE 16} [get_ports {flash_adv_n}]

set_false_path -to [get_ports {flash_dq[*] flash_addr[*] flash_ce_n flash_oe_n flash_we_n flash_adv_n}]
set_output_delay 0 [get_ports {flash_dq[*] flash_addr[*] flash_ce_n flash_oe_n flash_we_n flash_adv_n}]
set_false_path -from [get_ports {flash_dq[*]}]
set_input_delay 0 [get_ports {flash_dq[*]}]
