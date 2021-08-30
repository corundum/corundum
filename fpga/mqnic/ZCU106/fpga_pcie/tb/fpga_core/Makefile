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

DUT      = fpga_core
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)
VERILOG_SOURCES += ../../rtl/$(DUT).v
VERILOG_SOURCES += ../../rtl/common/mqnic_interface.v
VERILOG_SOURCES += ../../rtl/common/mqnic_port.v
VERILOG_SOURCES += ../../rtl/common/cpl_write.v
VERILOG_SOURCES += ../../rtl/common/cpl_op_mux.v
VERILOG_SOURCES += ../../rtl/common/desc_fetch.v
VERILOG_SOURCES += ../../rtl/common/desc_op_mux.v
VERILOG_SOURCES += ../../rtl/common/queue_manager.v
VERILOG_SOURCES += ../../rtl/common/cpl_queue_manager.v
VERILOG_SOURCES += ../../rtl/common/tx_engine.v
VERILOG_SOURCES += ../../rtl/common/rx_engine.v
VERILOG_SOURCES += ../../rtl/common/tx_checksum.v
VERILOG_SOURCES += ../../rtl/common/rx_hash.v
VERILOG_SOURCES += ../../rtl/common/rx_checksum.v
VERILOG_SOURCES += ../../rtl/common/mqnic_tx_scheduler_block_rr.v
VERILOG_SOURCES += ../../rtl/common/tx_scheduler_rr.v
VERILOG_SOURCES += ../../rtl/common/event_mux.v
VERILOG_SOURCES += ../../rtl/common/tdma_scheduler.v
VERILOG_SOURCES += ../../rtl/common/tdma_ber.v
VERILOG_SOURCES += ../../rtl/common/tdma_ber_ch.v
VERILOG_SOURCES += ../../lib/eth/rtl/eth_mac_10g_fifo.v
VERILOG_SOURCES += ../../lib/eth/rtl/eth_mac_10g.v
VERILOG_SOURCES += ../../lib/eth/rtl/axis_xgmii_rx_64.v
VERILOG_SOURCES += ../../lib/eth/rtl/axis_xgmii_tx_64.v
VERILOG_SOURCES += ../../lib/eth/rtl/lfsr.v
VERILOG_SOURCES += ../../lib/eth/rtl/ptp_clock.v
VERILOG_SOURCES += ../../lib/eth/rtl/ptp_clock_cdc.v
VERILOG_SOURCES += ../../lib/eth/rtl/ptp_perout.v
VERILOG_SOURCES += ../../lib/eth/rtl/ptp_ts_extract.v
VERILOG_SOURCES += ../../lib/axi/rtl/axil_interconnect.v
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
VERILOG_SOURCES += ../../lib/axis/rtl/axis_fifo.v
VERILOG_SOURCES += ../../lib/axis/rtl/axis_register.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_us_if.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_us_if_rc.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_us_if_rq.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_us_if_cc.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_us_if_cq.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_axil_master.v
VERILOG_SOURCES += ../../lib/pcie/rtl/dma_if_pcie.v
VERILOG_SOURCES += ../../lib/pcie/rtl/dma_if_pcie_rd.v
VERILOG_SOURCES += ../../lib/pcie/rtl/dma_if_pcie_wr.v
VERILOG_SOURCES += ../../lib/pcie/rtl/dma_if_mux.v
VERILOG_SOURCES += ../../lib/pcie/rtl/dma_if_mux_rd.v
VERILOG_SOURCES += ../../lib/pcie/rtl/dma_if_mux_wr.v
VERILOG_SOURCES += ../../lib/pcie/rtl/dma_if_desc_mux.v
VERILOG_SOURCES += ../../lib/pcie/rtl/dma_ram_demux_rd.v
VERILOG_SOURCES += ../../lib/pcie/rtl/dma_ram_demux_wr.v
VERILOG_SOURCES += ../../lib/pcie/rtl/dma_psdpram.v
VERILOG_SOURCES += ../../lib/pcie/rtl/dma_client_axis_sink.v
VERILOG_SOURCES += ../../lib/pcie/rtl/dma_client_axis_source.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_us_cfg.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_us_msi.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pulse_merge.v

# module parameters
export PARAM_AXIS_PCIE_DATA_WIDTH ?= 128
export PARAM_AXIS_PCIE_KEEP_WIDTH ?= $(shell expr $(PARAM_AXIS_PCIE_DATA_WIDTH) / 32 )
export PARAM_AXIS_PCIE_RQ_USER_WIDTH ?= $(if $(filter-out 512,$(PARAM_AXIS_PCIE_DATA_WIDTH)),62,137)
export PARAM_AXIS_PCIE_RC_USER_WIDTH ?= $(if $(filter-out 512,$(PARAM_AXIS_PCIE_DATA_WIDTH)),75,161)
export PARAM_AXIS_PCIE_CQ_USER_WIDTH ?= $(if $(filter-out 512,$(PARAM_AXIS_PCIE_DATA_WIDTH)),88,183)
export PARAM_AXIS_PCIE_CC_USER_WIDTH ?= $(if $(filter-out 512,$(PARAM_AXIS_PCIE_DATA_WIDTH)),33,81)
export PARAM_RQ_SEQ_NUM_WIDTH ?= 6
export PARAM_BAR0_APERTURE ?= 24

ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	COMPILE_ARGS += -P $(TOPLEVEL).AXIS_PCIE_DATA_WIDTH=$(PARAM_AXIS_PCIE_DATA_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIS_PCIE_KEEP_WIDTH=$(PARAM_AXIS_PCIE_KEEP_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIS_PCIE_RQ_USER_WIDTH=$(PARAM_AXIS_PCIE_RQ_USER_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIS_PCIE_RC_USER_WIDTH=$(PARAM_AXIS_PCIE_RC_USER_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIS_PCIE_CQ_USER_WIDTH=$(PARAM_AXIS_PCIE_CQ_USER_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIS_PCIE_CC_USER_WIDTH=$(PARAM_AXIS_PCIE_CC_USER_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).RQ_SEQ_NUM_WIDTH=$(PARAM_RQ_SEQ_NUM_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).BAR0_APERTURE=$(PARAM_BAR0_APERTURE)

	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif
else ifeq ($(SIM), verilator)
	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH

	COMPILE_ARGS += -GAXIS_PCIE_DATA_WIDTH=$(PARAM_AXIS_PCIE_DATA_WIDTH)
	COMPILE_ARGS += -GAXIS_PCIE_KEEP_WIDTH=$(PARAM_AXIS_PCIE_KEEP_WIDTH)
	COMPILE_ARGS += -GAXIS_PCIE_RQ_USER_WIDTH=$(PARAM_AXIS_PCIE_RQ_USER_WIDTH)
	COMPILE_ARGS += -GAXIS_PCIE_RC_USER_WIDTH=$(PARAM_AXIS_PCIE_RC_USER_WIDTH)
	COMPILE_ARGS += -GAXIS_PCIE_CQ_USER_WIDTH=$(PARAM_AXIS_PCIE_CQ_USER_WIDTH)
	COMPILE_ARGS += -GAXIS_PCIE_CC_USER_WIDTH=$(PARAM_AXIS_PCIE_CC_USER_WIDTH)
	COMPILE_ARGS += -GRQ_SEQ_NUM_WIDTH=$(PARAM_RQ_SEQ_NUM_WIDTH)
	COMPILE_ARGS += -GBAR0_APERTURE=$(PARAM_BAR0_APERTURE)

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
