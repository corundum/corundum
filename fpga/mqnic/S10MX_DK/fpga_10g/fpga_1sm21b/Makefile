
# FPGA settings
FPGA_TOP = fpga
FPGA_FAMILY = "Stratix 10 MX"
FPGA_DEVICE = 1SM21BHU2F53E1VG

# Files for synthesis
SYN_FILES = rtl/fpga.v
SYN_FILES += rtl/fpga_core.v
SYN_FILES += rtl/sync_signal.v
SYN_FILES += rtl/eth_xcvr_phy_wrapper.v
SYN_FILES += rtl/eth_xcvr_phy_quad_wrapper.v
SYN_FILES += rtl/common/mqnic_core_pcie_s10.v
SYN_FILES += rtl/common/mqnic_core_pcie.v
SYN_FILES += rtl/common/mqnic_core.v
SYN_FILES += rtl/common/mqnic_interface.v
SYN_FILES += rtl/common/mqnic_port.v
SYN_FILES += rtl/common/mqnic_ptp.v
SYN_FILES += rtl/common/mqnic_ptp_clock.v
SYN_FILES += rtl/common/mqnic_ptp_perout.v
SYN_FILES += rtl/common/cpl_write.v
SYN_FILES += rtl/common/cpl_op_mux.v
SYN_FILES += rtl/common/desc_fetch.v
SYN_FILES += rtl/common/desc_op_mux.v
SYN_FILES += rtl/common/event_mux.v
SYN_FILES += rtl/common/queue_manager.v
SYN_FILES += rtl/common/cpl_queue_manager.v
SYN_FILES += rtl/common/tx_engine.v
SYN_FILES += rtl/common/rx_engine.v
SYN_FILES += rtl/common/tx_checksum.v
SYN_FILES += rtl/common/rx_hash.v
SYN_FILES += rtl/common/rx_checksum.v
SYN_FILES += rtl/common/stats_counter.v
SYN_FILES += rtl/common/stats_collect.v
SYN_FILES += rtl/common/stats_pcie_if.v
SYN_FILES += rtl/common/stats_pcie_tlp.v
SYN_FILES += rtl/common/stats_dma_if_pcie.v
SYN_FILES += rtl/common/stats_dma_latency.v
SYN_FILES += rtl/common/mqnic_tx_scheduler_block_rr.v
SYN_FILES += rtl/common/tx_scheduler_rr.v
SYN_FILES += rtl/common/tdma_scheduler.v
SYN_FILES += rtl/common/tdma_ber.v
SYN_FILES += rtl/common/tdma_ber_ch.v
SYN_FILES += lib/eth/rtl/eth_mac_10g.v
SYN_FILES += lib/eth/rtl/axis_xgmii_rx_64.v
SYN_FILES += lib/eth/rtl/axis_xgmii_tx_64.v
SYN_FILES += lib/eth/rtl/eth_phy_10g.v
SYN_FILES += lib/eth/rtl/eth_phy_10g_rx.v
SYN_FILES += lib/eth/rtl/eth_phy_10g_rx_if.v
SYN_FILES += lib/eth/rtl/eth_phy_10g_rx_frame_sync.v
SYN_FILES += lib/eth/rtl/eth_phy_10g_rx_ber_mon.v
SYN_FILES += lib/eth/rtl/eth_phy_10g_rx_watchdog.v
SYN_FILES += lib/eth/rtl/eth_phy_10g_tx.v
SYN_FILES += lib/eth/rtl/eth_phy_10g_tx_if.v
SYN_FILES += lib/eth/rtl/xgmii_baser_dec_64.v
SYN_FILES += lib/eth/rtl/xgmii_baser_enc_64.v
SYN_FILES += lib/eth/rtl/lfsr.v
SYN_FILES += lib/eth/rtl/ptp_clock.v
SYN_FILES += lib/eth/rtl/ptp_clock_cdc.v
SYN_FILES += lib/eth/rtl/ptp_perout.v
SYN_FILES += lib/eth/rtl/ptp_ts_extract.v
SYN_FILES += lib/axi/rtl/axil_interconnect.v
SYN_FILES += lib/axi/rtl/axil_crossbar.v
SYN_FILES += lib/axi/rtl/axil_crossbar_addr.v
SYN_FILES += lib/axi/rtl/axil_crossbar_rd.v
SYN_FILES += lib/axi/rtl/axil_crossbar_wr.v
SYN_FILES += lib/axi/rtl/axil_reg_if.v
SYN_FILES += lib/axi/rtl/axil_reg_if_rd.v
SYN_FILES += lib/axi/rtl/axil_reg_if_wr.v
SYN_FILES += lib/axi/rtl/axil_register_rd.v
SYN_FILES += lib/axi/rtl/axil_register_wr.v
SYN_FILES += lib/axi/rtl/arbiter.v
SYN_FILES += lib/axi/rtl/priority_encoder.v
SYN_FILES += lib/axis/rtl/axis_adapter.v
SYN_FILES += lib/axis/rtl/axis_arb_mux.v
SYN_FILES += lib/axis/rtl/axis_async_fifo.v
SYN_FILES += lib/axis/rtl/axis_async_fifo_adapter.v
SYN_FILES += lib/axis/rtl/axis_arb_mux.v
SYN_FILES += lib/axis/rtl/axis_fifo.v
SYN_FILES += lib/axis/rtl/axis_pipeline_fifo.v
SYN_FILES += lib/axis/rtl/axis_register.v
SYN_FILES += lib/axis/rtl/sync_reset.v
SYN_FILES += lib/pcie/rtl/pcie_axil_master.v
SYN_FILES += lib/pcie/rtl/pcie_tlp_demux.v
SYN_FILES += lib/pcie/rtl/pcie_tlp_demux_bar.v
SYN_FILES += lib/pcie/rtl/pcie_tlp_mux.v
SYN_FILES += lib/pcie/rtl/dma_if_pcie.v
SYN_FILES += lib/pcie/rtl/dma_if_pcie_rd.v
SYN_FILES += lib/pcie/rtl/dma_if_pcie_wr.v
SYN_FILES += lib/pcie/rtl/dma_if_mux.v
SYN_FILES += lib/pcie/rtl/dma_if_mux_rd.v
SYN_FILES += lib/pcie/rtl/dma_if_mux_wr.v
SYN_FILES += lib/pcie/rtl/dma_if_desc_mux.v
SYN_FILES += lib/pcie/rtl/dma_ram_demux_rd.v
SYN_FILES += lib/pcie/rtl/dma_ram_demux_wr.v
SYN_FILES += lib/pcie/rtl/dma_psdpram.v
SYN_FILES += lib/pcie/rtl/dma_client_axis_sink.v
SYN_FILES += lib/pcie/rtl/dma_client_axis_source.v
SYN_FILES += lib/pcie/rtl/pcie_s10_if.v
SYN_FILES += lib/pcie/rtl/pcie_s10_if_rx.v
SYN_FILES += lib/pcie/rtl/pcie_s10_if_tx.v
SYN_FILES += lib/pcie/rtl/pcie_s10_cfg.v
SYN_FILES += lib/pcie/rtl/pcie_s10_msi.v
SYN_FILES += lib/pcie/rtl/pulse_merge.v

# IP files
IP_TCL_FILES += ip/reset_release.tcl
IP_TCL_FILES += ip/pcie.tcl
IP_TCL_FILES += ip/eth_xcvr.tcl
IP_TCL_FILES += ip/eth_xcvr_pll.tcl
IP_TCL_FILES += ip/eth_xcvr_reset.tcl

# QSF files
QSF_FILES = fpga.qsf

# SDC files
SDC_FILES = fpga.sdc

# Configuration
CONFIG_TCL_FILES = ./config.tcl

include ../common/quartus_pro.mk

program: fpga
	quartus_pgm --no_banner --mode=jtag -o "P;$(FPGA_TOP).sof@1"
