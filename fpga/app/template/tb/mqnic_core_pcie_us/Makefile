# SPDX-License-Identifier: BSD-2-Clause-Views
# Copyright (c) 2021-2023 The Regents of the University of California

TOPLEVEL_LANG = verilog

SIM ?= icarus
WAVES ?= 0

COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps

DUT      = mqnic_core_pcie_us
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)
VERILOG_SOURCES += ../../rtl/common/$(DUT).v
VERILOG_SOURCES += ../../rtl/common/mqnic_core_pcie.v
VERILOG_SOURCES += ../../rtl/common/mqnic_core.v
VERILOG_SOURCES += ../../rtl/common/mqnic_dram_if.v
VERILOG_SOURCES += ../../rtl/common/mqnic_interface.v
VERILOG_SOURCES += ../../rtl/common/mqnic_interface_tx.v
VERILOG_SOURCES += ../../rtl/common/mqnic_interface_rx.v
VERILOG_SOURCES += ../../rtl/common/mqnic_port.v
VERILOG_SOURCES += ../../rtl/common/mqnic_port_tx.v
VERILOG_SOURCES += ../../rtl/common/mqnic_port_rx.v
VERILOG_SOURCES += ../../rtl/common/mqnic_egress.v
VERILOG_SOURCES += ../../rtl/common/mqnic_ingress.v
VERILOG_SOURCES += ../../rtl/common/mqnic_l2_egress.v
VERILOG_SOURCES += ../../rtl/common/mqnic_l2_ingress.v
VERILOG_SOURCES += ../../rtl/common/mqnic_rx_queue_map.v
VERILOG_SOURCES += ../../rtl/common/mqnic_ptp.v
VERILOG_SOURCES += ../../rtl/common/mqnic_ptp_clock.v
VERILOG_SOURCES += ../../rtl/common/mqnic_ptp_perout.v
VERILOG_SOURCES += ../../rtl/common/mqnic_rb_clk_info.v
VERILOG_SOURCES += ../../rtl/common/cpl_write.v
VERILOG_SOURCES += ../../rtl/common/cpl_op_mux.v
VERILOG_SOURCES += ../../rtl/common/desc_fetch.v
VERILOG_SOURCES += ../../rtl/common/desc_op_mux.v
VERILOG_SOURCES += ../../rtl/common/queue_manager.v
VERILOG_SOURCES += ../../rtl/common/cpl_queue_manager.v
VERILOG_SOURCES += ../../rtl/common/tx_fifo.v
VERILOG_SOURCES += ../../rtl/common/rx_fifo.v
VERILOG_SOURCES += ../../rtl/common/tx_req_mux.v
VERILOG_SOURCES += ../../rtl/common/tx_engine.v
VERILOG_SOURCES += ../../rtl/common/rx_engine.v
VERILOG_SOURCES += ../../rtl/common/tx_checksum.v
VERILOG_SOURCES += ../../rtl/common/rx_hash.v
VERILOG_SOURCES += ../../rtl/common/rx_checksum.v
VERILOG_SOURCES += ../../rtl/common/stats_counter.v
VERILOG_SOURCES += ../../rtl/common/stats_collect.v
VERILOG_SOURCES += ../../rtl/common/stats_pcie_if.v
VERILOG_SOURCES += ../../rtl/common/stats_pcie_tlp.v
VERILOG_SOURCES += ../../rtl/common/stats_dma_if_pcie.v
VERILOG_SOURCES += ../../rtl/common/stats_dma_latency.v
VERILOG_SOURCES += ../../rtl/common/mqnic_tx_scheduler_block_rr.v
VERILOG_SOURCES += ../../rtl/common/tx_scheduler_rr.v
VERILOG_SOURCES += ../../rtl/mqnic_app_block.v
VERILOG_SOURCES += ../../lib/eth/rtl/mac_ctrl_rx.v
VERILOG_SOURCES += ../../lib/eth/rtl/mac_ctrl_tx.v
VERILOG_SOURCES += ../../lib/eth/rtl/mac_pause_ctrl_rx.v
VERILOG_SOURCES += ../../lib/eth/rtl/mac_pause_ctrl_tx.v
VERILOG_SOURCES += ../../lib/eth/rtl/ptp_td_phc.v
VERILOG_SOURCES += ../../lib/eth/rtl/ptp_td_leaf.v
VERILOG_SOURCES += ../../lib/eth/rtl/ptp_perout.v
VERILOG_SOURCES += ../../lib/axi/rtl/axil_crossbar.v
VERILOG_SOURCES += ../../lib/axi/rtl/axil_crossbar_addr.v
VERILOG_SOURCES += ../../lib/axi/rtl/axil_crossbar_rd.v
VERILOG_SOURCES += ../../lib/axi/rtl/axil_crossbar_wr.v
VERILOG_SOURCES += ../../lib/axi/rtl/axil_ram.v
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
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_axil_master.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_tlp_demux.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_tlp_demux_bar.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_tlp_mux.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_tlp_fifo.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_tlp_fifo_raw.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_msix.v
VERILOG_SOURCES += ../../lib/pcie/rtl/irq_rate_limit.v
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
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_us_if.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_us_if_rc.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_us_if_rq.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_us_if_cc.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_us_if_cq.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pcie_us_cfg.v
VERILOG_SOURCES += ../../lib/pcie/rtl/pulse_merge.v

# module parameters

# Structural configuration
export PARAM_IF_COUNT := 1
export PARAM_PORTS_PER_IF := 1
export PARAM_SCHED_PER_IF := $(PARAM_PORTS_PER_IF)

# Clock configuration
export PARAM_CLK_PERIOD_NS_NUM := 4
export PARAM_CLK_PERIOD_NS_DENOM := 1

# PTP configuration
export PARAM_PTP_CLK_PERIOD_NS_NUM := 32
export PARAM_PTP_CLK_PERIOD_NS_DENOM := 5
export PARAM_PTP_CLOCK_PIPELINE := 0
export PARAM_PTP_CLOCK_CDC_PIPELINE := 0
export PARAM_PTP_SEPARATE_TX_CLOCK := 0
export PARAM_PTP_SEPARATE_RX_CLOCK := 0
export PARAM_PTP_PORT_CDC_PIPELINE := 0
export PARAM_PTP_PEROUT_ENABLE := 0
export PARAM_PTP_PEROUT_COUNT := 1

# Queue manager configuration
export PARAM_EVENT_QUEUE_OP_TABLE_SIZE := 32
export PARAM_TX_QUEUE_OP_TABLE_SIZE := 32
export PARAM_RX_QUEUE_OP_TABLE_SIZE := 32
export PARAM_CQ_OP_TABLE_SIZE := 32
export PARAM_EQN_WIDTH := 6
export PARAM_TX_QUEUE_INDEX_WIDTH := 13
export PARAM_RX_QUEUE_INDEX_WIDTH := 8
export PARAM_CQN_WIDTH := $(shell python -c "print(max($(PARAM_TX_QUEUE_INDEX_WIDTH), $(PARAM_RX_QUEUE_INDEX_WIDTH)) + 1)")
export PARAM_EQ_PIPELINE := 3
export PARAM_TX_QUEUE_PIPELINE := $(shell python -c "print(3 + max($(PARAM_TX_QUEUE_INDEX_WIDTH)-12, 0))")
export PARAM_RX_QUEUE_PIPELINE := $(shell python -c "print(3 + max($(PARAM_RX_QUEUE_INDEX_WIDTH)-12, 0))")
export PARAM_CQ_PIPELINE := $(shell python -c "print(3 + max($(PARAM_CQN_WIDTH)-12, 0))")

# TX and RX engine configuration
export PARAM_TX_DESC_TABLE_SIZE := 32
export PARAM_RX_DESC_TABLE_SIZE := 32
export PARAM_RX_INDIR_TBL_ADDR_WIDTH := $(shell python -c "print(min($(PARAM_RX_QUEUE_INDEX_WIDTH), 8))")

# Scheduler configuration
export PARAM_TX_SCHEDULER_OP_TABLE_SIZE := $(PARAM_TX_DESC_TABLE_SIZE)
export PARAM_TX_SCHEDULER_PIPELINE := $(PARAM_TX_QUEUE_PIPELINE)
export PARAM_TDMA_INDEX_WIDTH := 6

# Interface configuration
export PARAM_PTP_TS_ENABLE := 1
export PARAM_TX_CPL_ENABLE := $(PARAM_PTP_TS_ENABLE)
export PARAM_TX_CPL_FIFO_DEPTH := 32
export PARAM_TX_TAG_WIDTH := 16
export PARAM_TX_CHECKSUM_ENABLE := 1
export PARAM_RX_HASH_ENABLE := 1
export PARAM_RX_CHECKSUM_ENABLE := 1
export PARAM_LFC_ENABLE := 1
export PARAM_PFC_ENABLE := $(PARAM_LFC_ENABLE)
export PARAM_MAC_CTRL_ENABLE := 1
export PARAM_TX_FIFO_DEPTH := 32768
export PARAM_RX_FIFO_DEPTH := 131072
export PARAM_MAX_TX_SIZE := 9214
export PARAM_MAX_RX_SIZE := 9214
export PARAM_TX_RAM_SIZE := 131072
export PARAM_RX_RAM_SIZE := 131072

# RAM configuration
export PARAM_DDR_CH := 1
export PARAM_DDR_ENABLE := 0
export PARAM_DDR_GROUP_SIZE := 1
export PARAM_AXI_DDR_DATA_WIDTH := 256
export PARAM_AXI_DDR_ADDR_WIDTH := 32
export PARAM_AXI_DDR_ID_WIDTH := 8
export PARAM_AXI_DDR_MAX_BURST_LEN := 256
export PARAM_HBM_CH := 1
export PARAM_HBM_ENABLE := 0
export PARAM_HBM_GROUP_SIZE := $(PARAM_HBM_CH)
export PARAM_AXI_HBM_DATA_WIDTH := 256
export PARAM_AXI_HBM_ADDR_WIDTH := 32
export PARAM_AXI_HBM_ID_WIDTH := 6
export PARAM_AXI_HBM_MAX_BURST_LEN := 16

# Application block configuration
export PARAM_APP_ID := $(shell echo $$((0x12340001)) )
export PARAM_APP_ENABLE := 1
export PARAM_APP_CTRL_ENABLE := 1
export PARAM_APP_DMA_ENABLE := 1
export PARAM_APP_AXIS_DIRECT_ENABLE := 1
export PARAM_APP_AXIS_SYNC_ENABLE := 1
export PARAM_APP_AXIS_IF_ENABLE := 1
export PARAM_APP_STAT_ENABLE := 1

# DMA interface configuration
export PARAM_DMA_IMM_ENABLE := 0
export PARAM_DMA_IMM_WIDTH := 32
export PARAM_DMA_LEN_WIDTH := 16
export PARAM_DMA_TAG_WIDTH := 16
export PARAM_RAM_ADDR_WIDTH := $(shell python -c "print((max($(PARAM_TX_RAM_SIZE), $(PARAM_RX_RAM_SIZE))-1).bit_length())")
export PARAM_RAM_PIPELINE := 2

# PCIe interface configuration
export PARAM_AXIS_PCIE_DATA_WIDTH := 512
export PARAM_PF_COUNT := 1
export PARAM_VF_COUNT := 0

# Interrupt configuration
export PARAM_IRQ_INDEX_WIDTH := $(PARAM_EQN_WIDTH)

# AXI lite interface configuration (control)
export PARAM_AXIL_CTRL_DATA_WIDTH := 32
export PARAM_AXIL_CTRL_ADDR_WIDTH := 24
export PARAM_AXIL_CSR_PASSTHROUGH_ENABLE := 0

# AXI lite interface configuration (application control)
export PARAM_AXIL_APP_CTRL_DATA_WIDTH := $(PARAM_AXIL_CTRL_DATA_WIDTH)
export PARAM_AXIL_APP_CTRL_ADDR_WIDTH := 24

# Ethernet interface configuration
export PARAM_AXIS_ETH_DATA_WIDTH := 512
export PARAM_AXIS_ETH_SYNC_DATA_WIDTH := $(PARAM_AXIS_ETH_DATA_WIDTH)
export PARAM_AXIS_ETH_RX_USE_READY := 0
export PARAM_AXIS_ETH_TX_PIPELINE := 0
export PARAM_AXIS_ETH_TX_FIFO_PIPELINE := 2
export PARAM_AXIS_ETH_TX_TS_PIPELINE := 0
export PARAM_AXIS_ETH_RX_PIPELINE := 0
export PARAM_AXIS_ETH_RX_FIFO_PIPELINE := 2

# Statistics counter subsystem
export PARAM_STAT_ENABLE := 1
export PARAM_STAT_DMA_ENABLE := 1
export PARAM_STAT_PCIE_ENABLE := 1
export PARAM_STAT_INC_WIDTH := 24
export PARAM_STAT_ID_WIDTH := 12

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
