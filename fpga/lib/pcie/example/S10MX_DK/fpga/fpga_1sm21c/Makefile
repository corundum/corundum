
# FPGA settings
FPGA_TOP = fpga
FPGA_FAMILY = "Stratix 10 MX"
FPGA_DEVICE = 1SM21CHU1F53E1VG

# Files for synthesis
SYN_FILES = rtl/fpga.v
SYN_FILES += rtl/fpga_core.v
SYN_FILES += rtl/sync_reset.v
SYN_FILES += rtl/sync_signal.v
SYN_FILES += rtl/common/example_core_pcie_s10.v
SYN_FILES += rtl/common/example_core_pcie.v
SYN_FILES += rtl/common/example_core.v
SYN_FILES += rtl/common/axi_ram.v
SYN_FILES += lib/pcie/rtl/pcie_s10_if.v
SYN_FILES += lib/pcie/rtl/pcie_s10_if_rx.v
SYN_FILES += lib/pcie/rtl/pcie_s10_if_tx.v
SYN_FILES += lib/pcie/rtl/pcie_s10_cfg.v
SYN_FILES += lib/pcie/rtl/pcie_s10_msi.v
SYN_FILES += lib/pcie/rtl/pcie_axil_master.v
SYN_FILES += lib/pcie/rtl/pcie_axi_master.v
SYN_FILES += lib/pcie/rtl/pcie_axi_master_rd.v
SYN_FILES += lib/pcie/rtl/pcie_axi_master_wr.v
SYN_FILES += lib/pcie/rtl/pcie_tlp_demux_bar.v
SYN_FILES += lib/pcie/rtl/pcie_tlp_demux.v
SYN_FILES += lib/pcie/rtl/pcie_tlp_mux.v
SYN_FILES += lib/pcie/rtl/dma_if_pcie.v
SYN_FILES += lib/pcie/rtl/dma_if_pcie_rd.v
SYN_FILES += lib/pcie/rtl/dma_if_pcie_wr.v
SYN_FILES += lib/pcie/rtl/dma_psdpram.v
SYN_FILES += lib/pcie/rtl/arbiter.v
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
