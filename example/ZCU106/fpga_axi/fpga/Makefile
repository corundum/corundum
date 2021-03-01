
# FPGA settings
FPGA_PART = xczu7ev-ffvc1156-2-e
FPGA_TOP = fpga
FPGA_ARCH = zynquplus

# Files for synthesis
SYN_FILES = rtl/fpga.v
SYN_FILES += rtl/fpga_core.v
SYN_FILES += rtl/debounce_switch.v
SYN_FILES += rtl/sync_reset.v
SYN_FILES += rtl/sync_signal.v
SYN_FILES += rtl/axi_ram.v
SYN_FILES += rtl/axis_register.v
SYN_FILES += lib/pcie/rtl/axis_arb_mux.v
SYN_FILES += lib/pcie/rtl/pcie_us_axil_master.v
SYN_FILES += lib/pcie/rtl/pcie_us_axi_dma.v
SYN_FILES += lib/pcie/rtl/pcie_us_axi_dma_rd.v
SYN_FILES += lib/pcie/rtl/pcie_us_axi_dma_wr.v
SYN_FILES += lib/pcie/rtl/pcie_us_axi_master.v
SYN_FILES += lib/pcie/rtl/pcie_us_axi_master_rd.v
SYN_FILES += lib/pcie/rtl/pcie_us_axi_master_wr.v
SYN_FILES += lib/pcie/rtl/pcie_us_axis_cq_demux.v
SYN_FILES += lib/pcie/rtl/pcie_us_cfg.v
SYN_FILES += lib/pcie/rtl/pcie_us_msi.v
SYN_FILES += lib/pcie/rtl/arbiter.v
SYN_FILES += lib/pcie/rtl/priority_encoder.v
SYN_FILES += lib/pcie/rtl/pulse_merge.v

# XDC files
XDC_FILES = fpga.xdc

# IP
IP_TCL_FILES = ip/pcie4_uscale_plus_0.tcl

include ../common/vivado.mk

program: $(FPGA_TOP).bit
	echo "open_hw" > program.tcl
	echo "connect_hw_server" >> program.tcl
	echo "open_hw_target" >> program.tcl
	echo "current_hw_device [lindex [get_hw_devices] 0]" >> program.tcl
	echo "refresh_hw_device -update_hw_probes false [current_hw_device]" >> program.tcl
	echo "set_property PROGRAM.FILE {$(FPGA_TOP).bit} [current_hw_device]" >> program.tcl
	echo "program_hw_devices [current_hw_device]" >> program.tcl
	echo "exit" >> program.tcl
	vivado -nojournal -nolog -mode batch -source program.tcl

