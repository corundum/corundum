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

DUT      = example_core_pcie
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)
VERILOG_SOURCES += ../../rtl/$(DUT).v
VERILOG_SOURCES += ../../rtl/example_core.v
VERILOG_SOURCES += ../../rtl/axi_ram.v
VERILOG_SOURCES += ../../../../rtl/pcie_axil_master.v
VERILOG_SOURCES += ../../../../rtl/pcie_axi_master.v
VERILOG_SOURCES += ../../../../rtl/pcie_axi_master_rd.v
VERILOG_SOURCES += ../../../../rtl/pcie_axi_master_wr.v
VERILOG_SOURCES += ../../../../rtl/pcie_tlp_demux_bar.v
VERILOG_SOURCES += ../../../../rtl/pcie_tlp_demux.v
VERILOG_SOURCES += ../../../../rtl/pcie_tlp_mux.v
VERILOG_SOURCES += ../../../../rtl/pcie_msix.v
VERILOG_SOURCES += ../../../../rtl/dma_if_pcie.v
VERILOG_SOURCES += ../../../../rtl/dma_if_pcie_rd.v
VERILOG_SOURCES += ../../../../rtl/dma_if_pcie_wr.v
VERILOG_SOURCES += ../../../../rtl/dma_psdpram.v
VERILOG_SOURCES += ../../../../rtl/priority_encoder.v
VERILOG_SOURCES += ../../../../rtl/pulse_merge.v

# module parameters
export PARAM_TLP_DATA_WIDTH := 512
export PARAM_TLP_STRB_WIDTH := $(shell expr $(PARAM_TLP_DATA_WIDTH) / 32 )
export PARAM_TLP_HDR_WIDTH := 128
export PARAM_TLP_SEG_COUNT := 1
export PARAM_TX_SEQ_NUM_COUNT := 1
export PARAM_TX_SEQ_NUM_WIDTH := 6
export PARAM_TX_SEQ_NUM_ENABLE := 1
export PARAM_PCIE_TAG_COUNT := 256
export PARAM_IMM_ENABLE := 1
export PARAM_IMM_WIDTH := 32
export PARAM_READ_OP_TABLE_SIZE := $(PARAM_PCIE_TAG_COUNT)
export PARAM_READ_TX_LIMIT := $(shell echo "$$(( 1 << $(PARAM_TX_SEQ_NUM_WIDTH) ))" )
export PARAM_READ_CPLH_FC_LIMIT := 0
export PARAM_READ_CPLD_FC_LIMIT := $(shell expr $(PARAM_READ_CPLH_FC_LIMIT) \* 4 )
export PARAM_WRITE_OP_TABLE_SIZE := $(shell echo "$$(( 1 << $(PARAM_TX_SEQ_NUM_WIDTH) ))" )
export PARAM_WRITE_TX_LIMIT := $(shell echo "$$(( 1 << $(PARAM_TX_SEQ_NUM_WIDTH) ))" )
export PARAM_TLP_FORCE_64_BIT_ADDR := 0
export PARAM_CHECK_BUS_NUMBER := 1
export PARAM_BAR0_APERTURE := 24
export PARAM_BAR2_APERTURE := 24
export PARAM_BAR4_APERTURE := 16

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
