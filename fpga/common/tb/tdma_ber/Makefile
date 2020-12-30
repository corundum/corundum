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

DUT      = tdma_ber
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)
VERILOG_SOURCES += ../../rtl/$(DUT).v
VERILOG_SOURCES += ../../rtl/tdma_ber_ch.v
VERILOG_SOURCES += ../../rtl/tdma_scheduler.v
VERILOG_SOURCES += ../../lib/axi/rtl/axil_interconnect.v
VERILOG_SOURCES += ../../lib/axi/rtl/arbiter.v
VERILOG_SOURCES += ../../lib/axi/rtl/priority_encoder.v

# module parameters
export PARAM_COUNT = 2
export PARAM_INDEX_WIDTH = 6
export PARAM_SLICE_WIDTH = 5
export PARAM_AXIL_DATA_WIDTH = 32
export PARAM_AXIL_ADDR_WIDTH = $(shell python -c "print($(PARAM_INDEX_WIDTH)+4+1+($(PARAM_COUNT)-1).bit_length())")
export PARAM_AXIL_STRB_WIDTH = $(shell expr $(PARAM_AXIL_DATA_WIDTH) / 8 )
export PARAM_SCHEDULE_START_S = 0
export PARAM_SCHEDULE_START_NS = 0
export PARAM_SCHEDULE_PERIOD_S = 0
export PARAM_SCHEDULE_PERIOD_NS = 1000000
export PARAM_TIMESLOT_PERIOD_S = 0
export PARAM_TIMESLOT_PERIOD_NS = 100000
export PARAM_ACTIVE_PERIOD_S = 0
export PARAM_ACTIVE_PERIOD_NS = 100000

ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	COMPILE_ARGS += -P $(TOPLEVEL).COUNT=$(PARAM_COUNT)
	COMPILE_ARGS += -P $(TOPLEVEL).INDEX_WIDTH=$(PARAM_INDEX_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).SLICE_WIDTH=$(PARAM_SLICE_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIL_DATA_WIDTH=$(PARAM_AXIL_DATA_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIL_ADDR_WIDTH=$(PARAM_AXIL_ADDR_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIL_STRB_WIDTH=$(PARAM_AXIL_STRB_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).SCHEDULE_START_S=$(PARAM_SCHEDULE_START_S)
	COMPILE_ARGS += -P $(TOPLEVEL).SCHEDULE_START_NS=$(PARAM_SCHEDULE_START_NS)
	COMPILE_ARGS += -P $(TOPLEVEL).SCHEDULE_PERIOD_S=$(PARAM_SCHEDULE_PERIOD_S)
	COMPILE_ARGS += -P $(TOPLEVEL).SCHEDULE_PERIOD_NS=$(PARAM_SCHEDULE_PERIOD_NS)
	COMPILE_ARGS += -P $(TOPLEVEL).TIMESLOT_PERIOD_S=$(PARAM_TIMESLOT_PERIOD_S)
	COMPILE_ARGS += -P $(TOPLEVEL).TIMESLOT_PERIOD_NS=$(PARAM_TIMESLOT_PERIOD_NS)
	COMPILE_ARGS += -P $(TOPLEVEL).ACTIVE_PERIOD_S=$(PARAM_ACTIVE_PERIOD_S)
	COMPILE_ARGS += -P $(TOPLEVEL).ACTIVE_PERIOD_NS=$(PARAM_ACTIVE_PERIOD_NS)

	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif
else ifeq ($(SIM), verilator)
	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH

	COMPILE_ARGS += -GCOUNT=$(PARAM_COUNT)
	COMPILE_ARGS += -GINDEX_WIDTH=$(PARAM_INDEX_WIDTH)
	COMPILE_ARGS += -GSLICE_WIDTH=$(PARAM_SLICE_WIDTH)
	COMPILE_ARGS += -GAXIL_DATA_WIDTH=$(PARAM_AXIL_DATA_WIDTH)
	COMPILE_ARGS += -GAXIL_ADDR_WIDTH=$(PARAM_AXIL_ADDR_WIDTH)
	COMPILE_ARGS += -GAXIL_STRB_WIDTH=$(PARAM_AXIL_STRB_WIDTH)
	COMPILE_ARGS += -GSCHEDULE_START_S=$(PARAM_SCHEDULE_START_S)
	COMPILE_ARGS += -GSCHEDULE_START_NS=$(PARAM_SCHEDULE_START_NS)
	COMPILE_ARGS += -GSCHEDULE_PERIOD_S=$(PARAM_SCHEDULE_PERIOD_S)
	COMPILE_ARGS += -GSCHEDULE_PERIOD_NS=$(PARAM_SCHEDULE_PERIOD_NS)
	COMPILE_ARGS += -GTIMESLOT_PERIOD_S=$(PARAM_TIMESLOT_PERIOD_S)
	COMPILE_ARGS += -GTIMESLOT_PERIOD_NS=$(PARAM_TIMESLOT_PERIOD_NS)
	COMPILE_ARGS += -GACTIVE_PERIOD_S=$(PARAM_ACTIVE_PERIOD_S)
	COMPILE_ARGS += -GACTIVE_PERIOD_NS=$(PARAM_ACTIVE_PERIOD_NS)

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
