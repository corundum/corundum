# SPDX-License-Identifier: BSD-2-Clause-Views
# Copyright (c) 2020-2023 The Regents of the University of California

TOPLEVEL_LANG = verilog

SIM ?= icarus
WAVES ?= 0

COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps

DUT      = queue_manager
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)
VERILOG_SOURCES += ../../rtl/$(DUT).v

# module parameters
export PARAM_ADDR_WIDTH := 64
export PARAM_REQ_TAG_WIDTH := 8
export PARAM_OP_TABLE_SIZE := 16
export PARAM_OP_TAG_WIDTH := 8
export PARAM_QUEUE_INDEX_WIDTH := 8
export PARAM_CPL_INDEX_WIDTH := 8
export PARAM_QUEUE_PTR_WIDTH := 16
export PARAM_LOG_QUEUE_SIZE_WIDTH := 4
export PARAM_DESC_SIZE := 16
export PARAM_LOG_BLOCK_SIZE_WIDTH := 2
export PARAM_PIPELINE := 2
export PARAM_AXIL_DATA_WIDTH := 32
export PARAM_AXIL_ADDR_WIDTH := $(shell expr $(PARAM_QUEUE_INDEX_WIDTH) + 5 )
export PARAM_AXIL_STRB_WIDTH := $(shell expr $(PARAM_AXIL_DATA_WIDTH) / 8 )

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
