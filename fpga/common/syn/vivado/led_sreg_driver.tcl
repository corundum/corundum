# Copyright (c) 2020 Alex Forencich
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# Timing constraints for led_sreg_driver

foreach inst [get_cells -hier -filter {(ORIG_REF_NAME == led_sreg_driver || REF_NAME == led_sreg_driver)}] {
    puts "Inserting timing constraints for led_sreg_driver instance $inst"

    set select_ffs [get_cells "$inst/led_sync_reg_1_reg[*] $inst/led_sync_reg_2_reg[*]"]

    if {[llength $select_ffs]} {
        set_property ASYNC_REG TRUE $select_ffs
        set_false_path -to [get_pins "$inst/led_sync_reg_1_reg[*]/D"]
    }
}
