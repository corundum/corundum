
# FPGA settings
FPGA_TOP = fpga
FPGA_FAMILY = "Agilex"
FPGA_DEVICE = AGFB014R24B2E2V

# Files for synthesis
SYN_FILES = rtl/fpga.v
SYN_FILES += rtl/fpga_core.v
SYN_FILES += rtl/sync_reset.v
SYN_FILES += rtl/sync_signal.v
SYN_FILES += rtl/common/example_core_pcie_ptile.v
SYN_FILES += rtl/common/example_core_pcie.v
SYN_FILES += rtl/common/example_core.v
SYN_FILES += rtl/common/axi_ram.v
SYN_FILES += lib/pcie/rtl/pcie_ptile_if.v
SYN_FILES += lib/pcie/rtl/pcie_ptile_if_rx.v
SYN_FILES += lib/pcie/rtl/pcie_ptile_if_tx.v
SYN_FILES += lib/pcie/rtl/pcie_ptile_cfg.v
SYN_FILES += lib/pcie/rtl/pcie_ptile_fc_counter.v
SYN_FILES += lib/pcie/rtl/pcie_axil_master.v
SYN_FILES += lib/pcie/rtl/pcie_axi_master.v
SYN_FILES += lib/pcie/rtl/pcie_axi_master_rd.v
SYN_FILES += lib/pcie/rtl/pcie_axi_master_wr.v
SYN_FILES += lib/pcie/rtl/pcie_tlp_demux_bar.v
SYN_FILES += lib/pcie/rtl/pcie_tlp_demux.v
SYN_FILES += lib/pcie/rtl/pcie_tlp_mux.v
SYN_FILES += lib/pcie/rtl/pcie_tlp_fc_count.v
SYN_FILES += lib/pcie/rtl/pcie_tlp_fifo.v
SYN_FILES += lib/pcie/rtl/pcie_tlp_fifo_raw.v
SYN_FILES += lib/pcie/rtl/pcie_tlp_fifo_mux.v
SYN_FILES += lib/pcie/rtl/pcie_msix.v
SYN_FILES += lib/pcie/rtl/dma_if_pcie.v
SYN_FILES += lib/pcie/rtl/dma_if_pcie_rd.v
SYN_FILES += lib/pcie/rtl/dma_if_pcie_wr.v
SYN_FILES += lib/pcie/rtl/dma_psdpram.v
SYN_FILES += lib/pcie/rtl/priority_encoder.v
SYN_FILES += lib/pcie/rtl/pulse_merge.v

# IP files
IP_TCL_FILES += ip/reset_release.tcl
IP_TCL_FILES += ip/pcie.tcl

# QSF files
QSF_FILES = fpga.qsf

# SDC files
SDC_FILES = fpga.sdc

include ../common/quartus_pro.mk

program: fpga
	quartus_pgm --no_banner --mode=jtag -o "P;$(FPGA_TOP).sof@1"
