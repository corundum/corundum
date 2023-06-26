# SPDX-License-Identifier: BSD-2-Clause-Views
# Copyright (c) 2023 The Regents of the University of California

TOPLEVEL_LANG = verilog

SIM ?= icarus
WAVES ?= 0

COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps

DUT      = dram_test_ch
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)
VERILOG_SOURCES += ../../rtl/$(DUT).v
VERILOG_SOURCES += ../../lib/eth/rtl/lfsr.v
VERILOG_SOURCES += ../../lib/axi/rtl/axi_vfifo_raw.v
VERILOG_SOURCES += ../../lib/axi/rtl/axi_vfifo_raw_rd.v
VERILOG_SOURCES += ../../lib/axi/rtl/axi_vfifo_raw_wr.v
VERILOG_SOURCES += ../../lib/axi/rtl/axil_crossbar.v
VERILOG_SOURCES += ../../lib/axi/rtl/axil_crossbar_addr.v
VERILOG_SOURCES += ../../lib/axi/rtl/axil_crossbar_rd.v
VERILOG_SOURCES += ../../lib/axi/rtl/axil_crossbar_wr.v
VERILOG_SOURCES += ../../lib/axi/rtl/axil_reg_if.v
VERILOG_SOURCES += ../../lib/axi/rtl/axil_reg_if_rd.v
VERILOG_SOURCES += ../../lib/axi/rtl/axil_reg_if_wr.v
VERILOG_SOURCES += ../../lib/axi/rtl/axil_register_rd.v
VERILOG_SOURCES += ../../lib/axi/rtl/axil_register_wr.v
VERILOG_SOURCES += ../../lib/axi/rtl/arbiter.v
VERILOG_SOURCES += ../../lib/axi/rtl/priority_encoder.v
VERILOG_SOURCES += ../../lib/axis/rtl/axis_adapter.v
VERILOG_SOURCES += ../../lib/axis/rtl/axis_arb_mux.v
VERILOG_SOURCES += ../../lib/axis/rtl/axis_async_fifo.v
VERILOG_SOURCES += ../../lib/axis/rtl/axis_async_fifo_adapter.v
VERILOG_SOURCES += ../../lib/axis/rtl/axis_demux.v
VERILOG_SOURCES += ../../lib/axis/rtl/axis_fifo.v
VERILOG_SOURCES += ../../lib/axis/rtl/axis_fifo_adapter.v
VERILOG_SOURCES += ../../lib/axis/rtl/axis_pipeline_fifo.v
VERILOG_SOURCES += ../../lib/axis/rtl/axis_register.v

# module parameters

# AXI configuration
export PARAM_AXI_DATA_WIDTH ?= 256
export PARAM_AXI_ADDR_WIDTH ?= 32
export PARAM_AXI_ID_WIDTH ?= 8
export PARAM_AXI_MAX_BURST_LEN ?= 256

# Register interface
export PARAM_REG_ADDR_WIDTH ?= 7
export PARAM_REG_DATA_WIDTH ?= 32
export PARAM_RB_BASE_ADDR ?= 0
export PARAM_RB_NEXT_PTR ?= 0

ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	COMPILE_ARGS += -P $(TOPLEVEL).AXI_DATA_WIDTH=$(PARAM_AXI_DATA_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXI_ADDR_WIDTH=$(PARAM_AXI_ADDR_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXI_ID_WIDTH=$(PARAM_AXI_ID_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXI_MAX_BURST_LEN=$(PARAM_AXI_MAX_BURST_LEN)
	COMPILE_ARGS += -P $(TOPLEVEL).REG_ADDR_WIDTH=$(PARAM_REG_ADDR_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).REG_DATA_WIDTH=$(PARAM_REG_DATA_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).RB_BASE_ADDR=$(PARAM_RB_BASE_ADDR)
	COMPILE_ARGS += -P $(TOPLEVEL).RB_NEXT_PTR=$(PARAM_RB_NEXT_PTR)

	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif
else ifeq ($(SIM), verilator)
	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH

	COMPILE_ARGS += -GAXI_DATA_WIDTH=$(PARAM_AXI_DATA_WIDTH)
	COMPILE_ARGS += -GAXI_ADDR_WIDTH=$(PARAM_AXI_ADDR_WIDTH)
	COMPILE_ARGS += -GAXI_ID_WIDTH=$(PARAM_AXI_ID_WIDTH)
	COMPILE_ARGS += -GAXI_MAX_BURST_LEN=$(PARAM_AXI_MAX_BURST_LEN)
	COMPILE_ARGS += -GREG_ADDR_WIDTH=$(PARAM_REG_ADDR_WIDTH)
	COMPILE_ARGS += -GREG_DATA_WIDTH=$(PARAM_REG_DATA_WIDTH)
	COMPILE_ARGS += -GRB_BASE_ADDR=$(PARAM_RB_BASE_ADDR)
	COMPILE_ARGS += -GRB_NEXT_PTR=$(PARAM_RB_NEXT_PTR)

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
