# Copyright (c) 2021 Alex Forencich
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

DUT      = pcie_s10_if
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)
VERILOG_SOURCES += ../../rtl/$(DUT).v
VERILOG_SOURCES += ../../rtl/$(DUT)_rx.v
VERILOG_SOURCES += ../../rtl/$(DUT)_tx.v
VERILOG_SOURCES += ../../rtl/pcie_s10_cfg.v
VERILOG_SOURCES += ../../rtl/pcie_s10_msi.v
VERILOG_SOURCES += ../../rtl/pcie_tlp_demux.v
VERILOG_SOURCES += ../../rtl/pcie_tlp_fc_count.v
VERILOG_SOURCES += ../../rtl/pcie_tlp_fifo.v
VERILOG_SOURCES += ../../rtl/pcie_tlp_fifo_raw.v
VERILOG_SOURCES += ../../rtl/pcie_tlp_fifo_mux.v
VERILOG_SOURCES += ../../rtl/arbiter.v
VERILOG_SOURCES += ../../rtl/priority_encoder.v

# module parameters
export PARAM_SEG_COUNT := 2
export PARAM_SEG_DATA_WIDTH := 256
export PARAM_SEG_EMPTY_WIDTH := $(shell python -c "print((($(PARAM_SEG_DATA_WIDTH)//32)-1).bit_length())" )
export PARAM_TLP_DATA_WIDTH := $(shell expr $(PARAM_SEG_COUNT) \* $(PARAM_SEG_DATA_WIDTH) )
export PARAM_TLP_STRB_WIDTH := $(shell expr $(PARAM_TLP_DATA_WIDTH) / 32 )
export PARAM_TLP_HDR_WIDTH := 128
export PARAM_TLP_SEG_COUNT := 1
export PARAM_TX_SEQ_NUM_WIDTH := 6
export PARAM_L_TILE := 0
export PARAM_PF_COUNT := 1
export PARAM_VF_COUNT := 0
export PARAM_F_COUNT := $(shell expr $(PARAM_PF_COUNT) + $(PARAM_VF_COUNT) )
export PARAM_IO_BAR_INDEX := 3
export PARAM_MSI_ENABLE := 1
export PARAM_MSI_COUNT := 32

ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	COMPILE_ARGS += $(foreach v,$(filter PARAM_%,$(.VARIABLES)),-P $(TOPLEVEL).$(subst PARAM_,,$(v))=$($(v)))

	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif
else ifeq ($(SIM), verilator)
	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH

	COMPILE_ARGS += $(foreach v,$(filter PARAM_%,$(.VARIABLES)),-G$(subst PARAM_,,$(v))=$($(v)))

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
