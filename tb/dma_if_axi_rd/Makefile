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

DUT      = dma_if_axi_rd
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)
VERILOG_SOURCES += ../../rtl/$(DUT).v

# module parameters
export PARAM_AXI_DATA_WIDTH ?= 64
export PARAM_AXI_ADDR_WIDTH ?= 16
export PARAM_AXI_STRB_WIDTH ?= $(shell expr $(PARAM_AXI_DATA_WIDTH) / 8 )
export PARAM_AXI_ID_WIDTH ?= 8
export PARAM_RAM_SEG_COUNT ?= 2
export PARAM_RAM_SEG_DATA_WIDTH ?= $(shell expr $(PARAM_AXI_DATA_WIDTH) \* 2 / $(PARAM_RAM_SEG_COUNT) )
export PARAM_RAM_SEG_ADDR_WIDTH ?= 12
export PARAM_RAM_SEG_BE_WIDTH ?= $(shell expr $(PARAM_RAM_SEG_DATA_WIDTH) / 8 )
export PARAM_RAM_SEL_WIDTH ?= 2
export PARAM_RAM_ADDR_WIDTH ?= $(shell python -c "print($(PARAM_RAM_SEG_ADDR_WIDTH) + ($(PARAM_RAM_SEG_COUNT)*$(PARAM_RAM_SEG_BE_WIDTH)-1).bit_length())")
export PARAM_LEN_WIDTH ?= 16
export PARAM_TAG_WIDTH ?= 8
export PARAM_OP_TABLE_SIZE ?= $(shell python -c "print(2**$(PARAM_AXI_ID_WIDTH))")

ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	COMPILE_ARGS += -P $(TOPLEVEL).AXI_DATA_WIDTH=$(PARAM_AXI_DATA_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXI_ADDR_WIDTH=$(PARAM_AXI_ADDR_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXI_STRB_WIDTH=$(PARAM_AXI_STRB_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXI_ID_WIDTH=$(PARAM_AXI_ID_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).RAM_SEG_COUNT=$(PARAM_RAM_SEG_COUNT)
	COMPILE_ARGS += -P $(TOPLEVEL).RAM_SEG_DATA_WIDTH=$(PARAM_RAM_SEG_DATA_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).RAM_SEG_ADDR_WIDTH=$(PARAM_RAM_SEG_ADDR_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).RAM_SEG_BE_WIDTH=$(PARAM_RAM_SEG_BE_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).RAM_SEL_WIDTH=$(PARAM_RAM_SEL_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).RAM_ADDR_WIDTH=$(PARAM_RAM_ADDR_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).LEN_WIDTH=$(PARAM_LEN_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).TAG_WIDTH=$(PARAM_TAG_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).OP_TABLE_SIZE=$(PARAM_OP_TABLE_SIZE)

	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif
else ifeq ($(SIM), verilator)
	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH

	COMPILE_ARGS += -GAXI_DATA_WIDTH=$(PARAM_AXI_DATA_WIDTH)
	COMPILE_ARGS += -GAXI_ADDR_WIDTH=$(PARAM_AXI_ADDR_WIDTH)
	COMPILE_ARGS += -GAXI_STRB_WIDTH=$(PARAM_AXI_STRB_WIDTH)
	COMPILE_ARGS += -GAXI_ID_WIDTH=$(PARAM_AXI_ID_WIDTH)
	COMPILE_ARGS += -GRAM_SEG_COUNT=$(PARAM_RAM_SEG_COUNT)
	COMPILE_ARGS += -GRAM_SEG_DATA_WIDTH=$(PARAM_RAM_SEG_DATA_WIDTH)
	COMPILE_ARGS += -GRAM_SEG_ADDR_WIDTH=$(PARAM_RAM_SEG_ADDR_WIDTH)
	COMPILE_ARGS += -GRAM_SEG_BE_WIDTH=$(PARAM_RAM_SEG_BE_WIDTH)
	COMPILE_ARGS += -GRAM_SEL_WIDTH=$(PARAM_RAM_SEL_WIDTH)
	COMPILE_ARGS += -GRAM_ADDR_WIDTH=$(PARAM_RAM_ADDR_WIDTH)
	COMPILE_ARGS += -GLEN_WIDTH=$(PARAM_LEN_WIDTH)
	COMPILE_ARGS += -GTAG_WIDTH=$(PARAM_TAG_WIDTH)
	COMPILE_ARGS += -GOP_TABLE_SIZE=$(PARAM_OP_TABLE_SIZE)

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
