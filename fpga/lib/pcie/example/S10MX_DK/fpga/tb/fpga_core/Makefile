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

DUT      = fpga_core
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)
VERILOG_SOURCES += ../../rtl/$(DUT).v
VERILOG_SOURCES += ../../rtl/common/example_core_pcie_s10.v
VERILOG_SOURCES += ../../rtl/common/example_core_pcie.v
VERILOG_SOURCES += ../../rtl/common/example_core.v
VERILOG_SOURCES += ../../rtl/common/axi_ram.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_s10_if.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_s10_if_rx.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_s10_if_tx.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_s10_cfg.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_s10_msi.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_axil_master.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_axi_master.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_axi_master_rd.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_axi_master_wr.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_tlp_demux_bar.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_tlp_demux.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_tlp_mux.v
VERILOG_SOURCES += ../../lib/pcie/rtl/dma_if_pcie.v
VERILOG_SOURCES += ../../lib/pcie/rtl/dma_if_pcie_rd.v
VERILOG_SOURCES += ../../lib/pcie/rtl/dma_if_pcie_wr.v
VERILOG_SOURCES += ../../lib/pcie/rtl/dma_psdpram.v
VERILOG_SOURCES += ../../lib/pcie/rtl/arbiter.v
VERILOG_SOURCES += ../../lib/pcie/rtl/priority_encoder.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pulse_merge.v

# module parameters
export PARAM_SEG_COUNT ?= 1
export PARAM_SEG_DATA_WIDTH ?= 256
export PARAM_SEG_EMPTY_WIDTH ?= $(shell python -c "print((($(PARAM_SEG_DATA_WIDTH)//32)-1).bit_length())" )
export PARAM_TX_SEQ_NUM_WIDTH ?= 6
export PARAM_PCIE_TAG_COUNT ?= 64
export PARAM_BAR0_APERTURE ?= 24
export PARAM_BAR2_APERTURE ?= 24

ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	COMPILE_ARGS += -P $(TOPLEVEL).SEG_COUNT=$(PARAM_SEG_COUNT)
	COMPILE_ARGS += -P $(TOPLEVEL).SEG_DATA_WIDTH=$(PARAM_SEG_DATA_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).SEG_EMPTY_WIDTH=$(PARAM_SEG_EMPTY_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).TX_SEQ_NUM_WIDTH=$(PARAM_TX_SEQ_NUM_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).PCIE_TAG_COUNT=$(PARAM_PCIE_TAG_COUNT)
	COMPILE_ARGS += -P $(TOPLEVEL).BAR0_APERTURE=$(PARAM_BAR0_APERTURE)
	COMPILE_ARGS += -P $(TOPLEVEL).BAR2_APERTURE=$(PARAM_BAR2_APERTURE)

	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif
else ifeq ($(SIM), verilator)
	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH

	COMPILE_ARGS += -GSEG_COUNT=$(PARAM_SEG_COUNT)
	COMPILE_ARGS += -GSEG_DATA_WIDTH=$(PARAM_SEG_DATA_WIDTH)
	COMPILE_ARGS += -GSEG_EMPTY_WIDTH=$(PARAM_SEG_EMPTY_WIDTH)
	COMPILE_ARGS += -GTX_SEQ_NUM_WIDTH=$(PARAM_TX_SEQ_NUM_WIDTH)
	COMPILE_ARGS += -GPCIE_TAG_COUNT=$(PARAM_PCIE_TAG_COUNT)
	COMPILE_ARGS += -GBAR0_APERTURE=$(PARAM_BAR0_APERTURE)
	COMPILE_ARGS += -GBAR2_APERTURE=$(PARAM_BAR2_APERTURE)

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
