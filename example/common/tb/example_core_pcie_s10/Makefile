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

DUT      = example_core_pcie_s10
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)
VERILOG_SOURCES += ../../rtl/$(DUT).v
VERILOG_SOURCES += ../../rtl/example_core_pcie.v
VERILOG_SOURCES += ../../rtl/example_core.v
VERILOG_SOURCES += ../../rtl/axi_ram.v
VERILOG_SOURCES += ../../../../rtl/pcie_s10_if.v
VERILOG_SOURCES += ../../../../rtl/pcie_s10_if_rx.v
VERILOG_SOURCES += ../../../../rtl/pcie_s10_if_tx.v
VERILOG_SOURCES += ../../../../rtl/pcie_s10_cfg.v
VERILOG_SOURCES += ../../../../rtl/pcie_s10_msi.v
VERILOG_SOURCES += ../../../../rtl/pcie_axil_master.v
VERILOG_SOURCES += ../../../../rtl/pcie_axi_master.v
VERILOG_SOURCES += ../../../../rtl/pcie_axi_master_rd.v
VERILOG_SOURCES += ../../../../rtl/pcie_axi_master_wr.v
VERILOG_SOURCES += ../../../../rtl/pcie_tlp_demux_bar.v
VERILOG_SOURCES += ../../../../rtl/pcie_tlp_demux.v
VERILOG_SOURCES += ../../../../rtl/pcie_tlp_mux.v
VERILOG_SOURCES += ../../../../rtl/dma_if_pcie.v
VERILOG_SOURCES += ../../../../rtl/dma_if_pcie_rd.v
VERILOG_SOURCES += ../../../../rtl/dma_if_pcie_wr.v
VERILOG_SOURCES += ../../../../rtl/dma_psdpram.v
VERILOG_SOURCES += ../../../../rtl/arbiter.v
VERILOG_SOURCES += ../../../../rtl/priority_encoder.v
VERILOG_SOURCES += ../../../../rtl/pulse_merge.v

# module parameters
export PARAM_SEG_COUNT ?= 1
export PARAM_SEG_DATA_WIDTH ?= 256
export PARAM_SEG_EMPTY_WIDTH ?= $(shell python -c "print((($(PARAM_SEG_DATA_WIDTH)//32)-1).bit_length())" )
export PARAM_TX_SEQ_NUM_WIDTH ?= 6
export PARAM_TX_SEQ_NUM_ENABLE ?= 1
export PARAM_L_TILE ?= 0
export PARAM_PCIE_TAG_COUNT ?= 256
export PARAM_READ_OP_TABLE_SIZE ?= $(PARAM_PCIE_TAG_COUNT)
export PARAM_READ_TX_LIMIT ?= $(shell echo "$$(( 1 << $(PARAM_TX_SEQ_NUM_WIDTH) ))" )
export PARAM_READ_TX_FC_ENABLE ?= 1
export PARAM_WRITE_OP_TABLE_SIZE ?= $(shell echo "$$(( 1 << $(PARAM_TX_SEQ_NUM_WIDTH) ))" )
export PARAM_WRITE_TX_LIMIT ?= $(shell echo "$$(( 1 << $(PARAM_TX_SEQ_NUM_WIDTH) ))" )
export PARAM_WRITE_TX_FC_ENABLE ?= 1
export PARAM_BAR0_APERTURE ?= 24
export PARAM_BAR2_APERTURE ?= 24

ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	COMPILE_ARGS += -P $(TOPLEVEL).SEG_COUNT=$(PARAM_SEG_COUNT)
	COMPILE_ARGS += -P $(TOPLEVEL).SEG_DATA_WIDTH=$(PARAM_SEG_DATA_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).SEG_EMPTY_WIDTH=$(PARAM_SEG_EMPTY_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).TX_SEQ_NUM_WIDTH=$(PARAM_TX_SEQ_NUM_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).TX_SEQ_NUM_ENABLE=$(PARAM_TX_SEQ_NUM_ENABLE)
	COMPILE_ARGS += -P $(TOPLEVEL).L_TILE=$(PARAM_L_TILE)
	COMPILE_ARGS += -P $(TOPLEVEL).PCIE_TAG_COUNT=$(PARAM_PCIE_TAG_COUNT)
	COMPILE_ARGS += -P $(TOPLEVEL).READ_OP_TABLE_SIZE=$(PARAM_READ_OP_TABLE_SIZE)
	COMPILE_ARGS += -P $(TOPLEVEL).READ_TX_LIMIT=$(PARAM_READ_TX_LIMIT)
	COMPILE_ARGS += -P $(TOPLEVEL).READ_TX_FC_ENABLE=$(PARAM_READ_TX_FC_ENABLE)
	COMPILE_ARGS += -P $(TOPLEVEL).WRITE_OP_TABLE_SIZE=$(PARAM_WRITE_OP_TABLE_SIZE)
	COMPILE_ARGS += -P $(TOPLEVEL).WRITE_TX_LIMIT=$(PARAM_WRITE_TX_LIMIT)
	COMPILE_ARGS += -P $(TOPLEVEL).WRITE_TX_FC_ENABLE=$(PARAM_WRITE_TX_FC_ENABLE)
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
	COMPILE_ARGS += -GTX_SEQ_NUM_ENABLE=$(PARAM_TX_SEQ_NUM_ENABLE)
	COMPILE_ARGS += -GL_TILE=$(PARAM_L_TILE)
	COMPILE_ARGS += -GPCIE_TAG_COUNT=$(PARAM_PCIE_TAG_COUNT)
	COMPILE_ARGS += -GREAD_OP_TABLE_SIZE=$(PARAM_READ_OP_TABLE_SIZE)
	COMPILE_ARGS += -GREAD_TX_LIMIT=$(PARAM_READ_TX_LIMIT)
	COMPILE_ARGS += -GREAD_TX_FC_ENABLE=$(PARAM_READ_TX_FC_ENABLE)
	COMPILE_ARGS += -GWRITE_OP_TABLE_SIZE=$(PARAM_WRITE_OP_TABLE_SIZE)
	COMPILE_ARGS += -GWRITE_TX_LIMIT=$(PARAM_WRITE_TX_LIMIT)
	COMPILE_ARGS += -GWRITE_TX_FC_ENABLE=$(PARAM_WRITE_TX_FC_ENABLE)
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
