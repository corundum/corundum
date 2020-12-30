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

DUT      = tx_checksum
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)
VERILOG_SOURCES += ../../rtl/$(DUT).v
VERILOG_SOURCES += ../../lib/axis/rtl/axis_fifo.v

# module parameters
export PARAM_DATA_WIDTH ?= 64
export PARAM_KEEP_WIDTH ?= $(shell expr $(PARAM_DATA_WIDTH) / 8 )
export PARAM_ID_ENABLE = 0
export PARAM_ID_WIDTH = 8
export PARAM_DEST_ENABLE = 0
export PARAM_DEST_WIDTH = 8
export PARAM_USER_ENABLE = 1
export PARAM_USER_WIDTH = 1
export PARAM_USE_INIT_VALUE = 1
export PARAM_DATA_FIFO_DEPTH = 16384
export PARAM_CHECKSUM_FIFO_DEPTH = 4

ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	COMPILE_ARGS += -P $(TOPLEVEL).DATA_WIDTH=$(PARAM_DATA_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).KEEP_WIDTH=$(PARAM_KEEP_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).ID_ENABLE=$(PARAM_ID_ENABLE)
	COMPILE_ARGS += -P $(TOPLEVEL).ID_WIDTH=$(PARAM_ID_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).DEST_ENABLE=$(PARAM_DEST_ENABLE)
	COMPILE_ARGS += -P $(TOPLEVEL).DEST_WIDTH=$(PARAM_DEST_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).USER_ENABLE=$(PARAM_USER_ENABLE)
	COMPILE_ARGS += -P $(TOPLEVEL).USER_WIDTH=$(PARAM_USER_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).USE_INIT_VALUE=$(PARAM_USE_INIT_VALUE)
	COMPILE_ARGS += -P $(TOPLEVEL).DATA_FIFO_DEPTH=$(PARAM_DATA_FIFO_DEPTH)
	COMPILE_ARGS += -P $(TOPLEVEL).CHECKSUM_FIFO_DEPTH=$(PARAM_CHECKSUM_FIFO_DEPTH)

	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif
else ifeq ($(SIM), verilator)
	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH

	COMPILE_ARGS += -GDATA_WIDTH=$(PARAM_DATA_WIDTH)
	COMPILE_ARGS += -GKEEP_WIDTH=$(PARAM_KEEP_WIDTH)
	COMPILE_ARGS += -GID_ENABLE=$(PARAM_ID_ENABLE)
	COMPILE_ARGS += -GID_WIDTH=$(PARAM_ID_WIDTH)
	COMPILE_ARGS += -GDEST_ENABLE=$(PARAM_DEST_ENABLE)
	COMPILE_ARGS += -GDEST_WIDTH=$(PARAM_DEST_WIDTH)
	COMPILE_ARGS += -GUSER_ENABLE=$(PARAM_USER_ENABLE)
	COMPILE_ARGS += -GUSER_WIDTH=$(PARAM_USER_WIDTH)
	COMPILE_ARGS += -GUSE_INIT_VALUE=$(PARAM_USE_INIT_VALUE)
	COMPILE_ARGS += -GDATA_FIFO_DEPTH=$(PARAM_DATA_FIFO_DEPTH)
	COMPILE_ARGS += -GCHECKSUM_FIFO_DEPTH=$(PARAM_CHECKSUM_FIFO_DEPTH)

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
