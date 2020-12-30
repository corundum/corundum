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

TOPLEVEL_LANG = verilog

SIM ?= icarus
WAVES ?= 0

COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps

export PARAM_S_COUNT ?= 4
export PARAM_M_COUNT ?= 4

DUT      = axi_crossbar
WRAPPER  = $(DUT)_wrap_$(PARAM_S_COUNT)x$(PARAM_M_COUNT)
TOPLEVEL = $(WRAPPER)
MODULE   = test_$(DUT)
VERILOG_SOURCES += $(WRAPPER).v
VERILOG_SOURCES += ../../rtl/$(DUT).v
VERILOG_SOURCES += ../../rtl/$(DUT)_addr.v
VERILOG_SOURCES += ../../rtl/$(DUT)_rd.v
VERILOG_SOURCES += ../../rtl/$(DUT)_wr.v
VERILOG_SOURCES += ../../rtl/axi_register_rd.v
VERILOG_SOURCES += ../../rtl/axi_register_wr.v
VERILOG_SOURCES += ../../rtl/arbiter.v
VERILOG_SOURCES += ../../rtl/priority_encoder.v

# module parameters
export PARAM_DATA_WIDTH ?= 32
export PARAM_ADDR_WIDTH ?= 32
export PARAM_STRB_WIDTH ?= $(shell expr $(PARAM_DATA_WIDTH) / 8 )
export PARAM_S_ID_WIDTH ?= 8
export PARAM_M_ID_WIDTH ?= $(shell expr $(PARAM_S_ID_WIDTH) + 2 )
export PARAM_AWUSER_ENABLE ?= 0
export PARAM_AWUSER_WIDTH ?= 1
export PARAM_WUSER_ENABLE ?= 0
export PARAM_WUSER_WIDTH ?= 1
export PARAM_BUSER_ENABLE ?= 0
export PARAM_BUSER_WIDTH ?= 1
export PARAM_ARUSER_ENABLE ?= 0
export PARAM_ARUSER_WIDTH ?= 1
export PARAM_RUSER_ENABLE ?= 0
export PARAM_RUSER_WIDTH ?= 1
export PARAM_M_REGIONS ?= 1

ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	COMPILE_ARGS += -P $(TOPLEVEL).DATA_WIDTH=$(PARAM_DATA_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).ADDR_WIDTH=$(PARAM_ADDR_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).STRB_WIDTH=$(PARAM_STRB_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).S_ID_WIDTH=$(PARAM_S_ID_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).M_ID_WIDTH=$(PARAM_M_ID_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AWUSER_ENABLE=$(PARAM_AWUSER_ENABLE)
	COMPILE_ARGS += -P $(TOPLEVEL).AWUSER_WIDTH=$(PARAM_AWUSER_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).WUSER_ENABLE=$(PARAM_WUSER_ENABLE)
	COMPILE_ARGS += -P $(TOPLEVEL).WUSER_WIDTH=$(PARAM_WUSER_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).BUSER_ENABLE=$(PARAM_BUSER_ENABLE)
	COMPILE_ARGS += -P $(TOPLEVEL).BUSER_WIDTH=$(PARAM_BUSER_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).ARUSER_ENABLE=$(PARAM_ARUSER_ENABLE)
	COMPILE_ARGS += -P $(TOPLEVEL).ARUSER_WIDTH=$(PARAM_ARUSER_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).RUSER_ENABLE=$(PARAM_RUSER_ENABLE)
	COMPILE_ARGS += -P $(TOPLEVEL).RUSER_WIDTH=$(PARAM_RUSER_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).M_REGIONS=$(PARAM_M_REGIONS)

	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif
else ifeq ($(SIM), verilator)
	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH

	COMPILE_ARGS += -GDATA_WIDTH=$(PARAM_DATA_WIDTH)
	COMPILE_ARGS += -GADDR_WIDTH=$(PARAM_ADDR_WIDTH)
	COMPILE_ARGS += -GSTRB_WIDTH=$(PARAM_STRB_WIDTH)
	COMPILE_ARGS += -GS_ID_WIDTH=$(PARAM_S_ID_WIDTH)
	COMPILE_ARGS += -GM_ID_WIDTH=$(PARAM_M_ID_WIDTH)
	COMPILE_ARGS += -GAWUSER_ENABLE=$(PARAM_AWUSER_ENABLE)
	COMPILE_ARGS += -GAWUSER_WIDTH=$(PARAM_AWUSER_WIDTH)
	COMPILE_ARGS += -GWUSER_ENABLE=$(PARAM_WUSER_ENABLE)
	COMPILE_ARGS += -GWUSER_WIDTH=$(PARAM_WUSER_WIDTH)
	COMPILE_ARGS += -GBUSER_ENABLE=$(PARAM_BUSER_ENABLE)
	COMPILE_ARGS += -GBUSER_WIDTH=$(PARAM_BUSER_WIDTH)
	COMPILE_ARGS += -GARUSER_ENABLE=$(PARAM_ARUSER_ENABLE)
	COMPILE_ARGS += -GARUSER_WIDTH=$(PARAM_ARUSER_WIDTH)
	COMPILE_ARGS += -GRUSER_ENABLE=$(PARAM_RUSER_ENABLE)
	COMPILE_ARGS += -GRUSER_WIDTH=$(PARAM_RUSER_WIDTH)
	COMPILE_ARGS += -GM_REGIONS=$(PARAM_M_REGIONS)

	ifeq ($(WAVES), 1)
		COMPILE_ARGS += --trace-fst
	endif
endif

include $(shell cocotb-config --makefiles)/Makefile.sim

$(WRAPPER).v: ../../rtl/$(DUT)_wrap.py
	$< -p $(PARAM_S_COUNT) $(PARAM_M_COUNT)

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
	@rm -rf *_wrap_*.v
