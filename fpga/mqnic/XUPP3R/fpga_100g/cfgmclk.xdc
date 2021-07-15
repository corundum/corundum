# Timing constraints for cfgmclk

# Fcfgmclk is 50 MHz +/- 15%, rounding to 15 ns period
create_clock -period 15 -name cfgmclk [get_pins startupe3_inst/CFGMCLK]
