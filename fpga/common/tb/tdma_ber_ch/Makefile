# Copyright 2020, The Regents of the University of California.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#    1. Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#
#    2. Redistributions in binary form must reproduce the above copyright notice,
#       this list of conditions and the following disclaimer in the documentation
#       and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE REGENTS OF THE UNIVERSITY OF CALIFORNIA ''AS
# IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE REGENTS OF THE UNIVERSITY OF CALIFORNIA OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
# IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
# OF SUCH DAMAGE.
#
# The views and conclusions contained in the software and documentation are those
# of the authors and should not be interpreted as representing official policies,
# either expressed or implied, of The Regents of the University of California.

TOPLEVEL_LANG = verilog

SIM ?= icarus
WAVES ?= 0

COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps

DUT      = tdma_ber_ch
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)
VERILOG_SOURCES += ../../rtl/$(DUT).v

# module parameters
export PARAM_INDEX_WIDTH = 6
export PARAM_SLICE_WIDTH = 5
export PARAM_AXIL_DATA_WIDTH = 32
export PARAM_AXIL_ADDR_WIDTH = $(shell expr $(PARAM_INDEX_WIDTH) + 4 )
export PARAM_AXIL_STRB_WIDTH = $(shell expr $(PARAM_AXIL_DATA_WIDTH) / 8 )

ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	COMPILE_ARGS += -P $(TOPLEVEL).INDEX_WIDTH=$(PARAM_INDEX_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).SLICE_WIDTH=$(PARAM_SLICE_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIL_DATA_WIDTH=$(PARAM_AXIL_DATA_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIL_ADDR_WIDTH=$(PARAM_AXIL_ADDR_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIL_STRB_WIDTH=$(PARAM_AXIL_STRB_WIDTH)

	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif
else ifeq ($(SIM), verilator)
	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH

	COMPILE_ARGS += -GINDEX_WIDTH=$(PARAM_INDEX_WIDTH)
	COMPILE_ARGS += -GSLICE_WIDTH=$(PARAM_SLICE_WIDTH)
	COMPILE_ARGS += -GAXIL_DATA_WIDTH=$(PARAM_AXIL_DATA_WIDTH)
	COMPILE_ARGS += -GAXIL_ADDR_WIDTH=$(PARAM_AXIL_ADDR_WIDTH)
	COMPILE_ARGS += -GAXIL_STRB_WIDTH=$(PARAM_AXIL_STRB_WIDTH)

	ifeq ($(WAVES), 1)
		COMPILE_ARGS += --trace-fst
	endif
endif

include $(shell cocotb-config --makefiles)/Makefile.sim

iverilog_dump.v:
	echo 'module iverilog_dump();' > $@
	echo 'initial begin' >> $@
	echo '    $$dumpfile("$(TOPLEVEL).fst");' >> $@
	echo '    $$dumpvars(0, $(TOPLEVEL));' >> $@
	echo 'end' >> $@
	echo 'endmodule' >> $@

clean::
	@rm -rf iverilog_dump.v
	@rm -rf dump.fst $(TOPLEVEL).fst
