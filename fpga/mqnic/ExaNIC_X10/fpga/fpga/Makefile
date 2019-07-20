
# FPGA settings
FPGA_PART = xcku035-fbva676-2-e
FPGA_TOP = fpga
FPGA_ARCH = kintexu

# Files for synthesis
SYN_FILES = rtl/fpga.v
SYN_FILES += rtl/fpga_core.v
SYN_FILES += rtl/debounce_switch.v
SYN_FILES += rtl/sync_reset.v
SYN_FILES += rtl/sync_signal.v
SYN_FILES += rtl/common/interface.v
SYN_FILES += rtl/common/port.v
SYN_FILES += rtl/common/queue_manager.v
SYN_FILES += rtl/common/cpl_queue_manager.v
SYN_FILES += rtl/common/event_queue.v
SYN_FILES += rtl/common/event_mux.v
SYN_FILES += rtl/common/tx_scheduler_rr.v
SYN_FILES += rtl/common/tdma_scheduler.v
SYN_FILES += rtl/common/tx_engine.v
SYN_FILES += rtl/common/rx_engine.v
SYN_FILES += rtl/common/rx_checksum.v
SYN_FILES += lib/eth/rtl/eth_mac_10g.v
SYN_FILES += lib/eth/rtl/eth_mac_10g_fifo.v
SYN_FILES += lib/eth/rtl/axis_xgmii_rx_64.v
SYN_FILES += lib/eth/rtl/axis_xgmii_tx_64.v
SYN_FILES += lib/eth/rtl/eth_phy_10g.v
SYN_FILES += lib/eth/rtl/eth_phy_10g_rx.v
SYN_FILES += lib/eth/rtl/eth_phy_10g_rx_if.v
SYN_FILES += lib/eth/rtl/eth_phy_10g_rx_frame_sync.v
SYN_FILES += lib/eth/rtl/eth_phy_10g_rx_ber_mon.v
SYN_FILES += lib/eth/rtl/eth_phy_10g_tx.v
SYN_FILES += lib/eth/rtl/eth_phy_10g_tx_if.v
SYN_FILES += lib/eth/rtl/xgmii_baser_dec_64.v
SYN_FILES += lib/eth/rtl/xgmii_baser_enc_64.v
SYN_FILES += lib/eth/rtl/lfsr.v
SYN_FILES += lib/eth/rtl/ptp_clock.v
SYN_FILES += lib/eth/rtl/ptp_clock_cdc.v
SYN_FILES += lib/eth/rtl/ptp_perout.v
SYN_FILES += lib/eth/rtl/ptp_ts_extract.v
SYN_FILES += lib/axi/rtl/axi_crossbar.v
SYN_FILES += lib/axi/rtl/axi_crossbar_addr.v
SYN_FILES += lib/axi/rtl/axi_crossbar_rd.v
SYN_FILES += lib/axi/rtl/axi_crossbar_wr.v
SYN_FILES += lib/axi/rtl/axi_dma.v
SYN_FILES += lib/axi/rtl/axi_dma_rd.v
SYN_FILES += lib/axi/rtl/axi_dma_wr.v
SYN_FILES += lib/axi/rtl/axi_interconnect.v
SYN_FILES += lib/axi/rtl/axi_ram.v
SYN_FILES += lib/axi/rtl/axi_ram_rd_if.v
SYN_FILES += lib/axi/rtl/axi_ram_wr_if.v
SYN_FILES += lib/axi/rtl/axi_register_rd.v
SYN_FILES += lib/axi/rtl/axi_register_wr.v
SYN_FILES += lib/axi/rtl/axil_interconnect.v
SYN_FILES += lib/axi/rtl/arbiter.v
SYN_FILES += lib/axi/rtl/priority_encoder.v
SYN_FILES += lib/axis/rtl/axis_adapter.v
SYN_FILES += lib/axis/rtl/axis_async_fifo.v
SYN_FILES += lib/axis/rtl/axis_async_fifo_adapter.v
SYN_FILES += lib/axis/rtl/axis_arb_mux.v
SYN_FILES += lib/axis/rtl/axis_fifo.v
SYN_FILES += lib/axis/rtl/axis_register.v
SYN_FILES += lib/pcie/rtl/pcie_us_axil_master.v
SYN_FILES += lib/pcie/rtl/pcie_us_axi_master.v
SYN_FILES += lib/pcie/rtl/pcie_us_axi_master_rd.v
SYN_FILES += lib/pcie/rtl/pcie_us_axi_master_wr.v
SYN_FILES += lib/pcie/rtl/pcie_us_axi_dma.v
SYN_FILES += lib/pcie/rtl/pcie_us_axi_dma_rd.v
SYN_FILES += lib/pcie/rtl/pcie_us_axi_dma_wr.v
SYN_FILES += lib/pcie/rtl/pcie_us_axis_cq_demux.v
SYN_FILES += lib/pcie/rtl/pcie_us_cfg.v
SYN_FILES += lib/pcie/rtl/pcie_us_msi.v
SYN_FILES += lib/pcie/rtl/pcie_tag_manager.v
SYN_FILES += lib/pcie/rtl/pcie_axi_dma_desc_mux.v
SYN_FILES += lib/pcie/rtl/pulse_merge.v

# XDC files
XDC_FILES = fpga.xdc
XDC_FILES += lib/axis/syn/axis_async_fifo.tcl
XDC_FILES += lib/eth/syn/ptp_clock_cdc.tcl

# IP
XCI_FILES = ip/pcie3_ultrascale_0.xci
XCI_FILES += ip/gtwizard_ultrascale_0.xci

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

%.mcs %.prm: %.bit
	echo "write_cfgmem -force -format mcs -size 32 -interface BPIx16 -loadbit {up 0x0000000 $*.bit} -checksum -file $*.mcs" > generate_mcs.tcl
	echo "exit" >> generate_mcs.tcl
	vivado -nojournal -nolog -mode batch -source generate_mcs.tcl
	mkdir -p rev
	COUNT=100; \
	while [ -e rev/$*_rev$$COUNT.bit ]; \
	do COUNT=$$((COUNT+1)); done; \
	COUNT=$$((COUNT-1)); \
	for x in .mcs .prm; \
	do cp $*$$x rev/$*_rev$$COUNT$$x; \
	echo "Output: rev/$*_rev$$COUNT$$x"; done;

flash: $(FPGA_TOP).mcs $(FPGA_TOP).prm
	echo "open_hw" > flash.tcl
	echo "connect_hw_server" >> flash.tcl
	echo "open_hw_target" >> flash.tcl
	echo "current_hw_device [lindex [get_hw_devices] 0]" >> flash.tcl
	echo "refresh_hw_device -update_hw_probes false [current_hw_device]" >> flash.tcl
	echo "create_hw_cfgmem -hw_device [current_hw_device] [lindex [get_cfgmem_parts {28f256p30t-bpi-x16}] 0]" >> flash.tcl
	echo "current_hw_cfgmem -hw_device [current_hw_device] [get_property PROGRAM.HW_CFGMEM [current_hw_device]]" >> flash.tcl
	echo "set_property PROGRAM.FILES [list \"$(FPGA_TOP).mcs\"] [current_hw_cfgmem]" >> flash.tcl
	echo "set_property PROGRAM.PRM_FILES [list \"$(FPGA_TOP).prm\"] [current_hw_cfgmem]" >> flash.tcl
	echo "set_property PROGRAM.ERASE 1 [current_hw_cfgmem]" >> flash.tcl
	echo "set_property PROGRAM.CFG_PROGRAM 1 [current_hw_cfgmem]" >> flash.tcl
	echo "set_property PROGRAM.VERIFY 1 [current_hw_cfgmem]" >> flash.tcl
	echo "set_property PROGRAM.CHECKSUM 0 [current_hw_cfgmem]" >> flash.tcl
	echo "set_property PROGRAM.ADDRESS_RANGE {use_file} [current_hw_cfgmem]" >> flash.tcl
	echo "set_property PROGRAM.BPI_RS_PINS {none} [current_hw_cfgmem]" >> flash.tcl
	echo "set_property PROGRAM.UNUSED_PIN_TERMINATION {pull-none} [current_hw_cfgmem]" >> flash.tcl
	echo "create_hw_bitstream -hw_device [current_hw_device] [get_property PROGRAM.HW_CFGMEM_BITFILE [current_hw_device]]" >> flash.tcl
	echo "program_hw_devices [current_hw_device]" >> flash.tcl
	echo "refresh_hw_device [current_hw_device]" >> flash.tcl
	echo "program_hw_cfgmem -hw_cfgmem [current_hw_cfgmem]" >> flash.tcl
	echo "boot_hw_device [current_hw_device]" >> flash.tcl
	echo "exit" >> flash.tcl
	vivado -nojournal -nolog -mode batch -source flash.tcl

