###################################################################
# 
# Xilinx Vivado FPGA Makefile
# 
# Copyright (c) 2016 Alex Forencich
# 
###################################################################
# 
# Parameters:
# FPGA_TOP - Top module name
# FPGA_FAMILY - FPGA family (e.g. VirtexUltrascale)
# FPGA_DEVICE - FPGA device (e.g. xcvu095-ffva2104-2-e)
# SYN_FILES - space-separated list of source files
# INC_FILES - space-separated list of include files
# XDC_FILES - space-separated list of timing constraint files
# XCI_FILES - space-separated list of IP XCI files
# 
# Example:
# 
# FPGA_TOP = fpga
# FPGA_FAMILY = VirtexUltrascale
# FPGA_DEVICE = xcvu095-ffva2104-2-e
# SYN_FILES = rtl/fpga.v
# XDC_FILES = fpga.xdc
# XCI_FILES = ip/pcspma.xci
# include ../common/vivado.mk
# 
###################################################################

# phony targets
.PHONY: fpga vivado tmpclean clean distclean

# prevent make from deleting intermediate files and reports
.PRECIOUS: %.xpr %.bit %.mcs %.prm
.SECONDARY:

CONFIG ?= config.mk
-include ../$(CONFIG)

SYN_FILES_REL = $(patsubst %, ../%, $(filter-out /% ./%,$(SYN_FILES))) $(filter /% ./%,$(SYN_FILES))
INC_FILES_REL = $(patsubst %, ../%, $(filter-out /% ./%,$(INC_FILES))) $(filter /% ./%,$(INC_FILES))
XCI_FILES_REL = $(patsubst %, ../%, $(filter-out /% ./%,$(XCI_FILES))) $(filter /% ./%,$(XCI_FILES))
IP_TCL_FILES_REL = $(patsubst %, ../%, $(filter-out /% ./%,$(IP_TCL_FILES))) $(filter /% ./%,$(IP_TCL_FILES))
CONFIG_TCL_FILES_REL = $(patsubst %, ../%, $(filter-out /% ./%,$(CONFIG_TCL_FILES))) $(filter /% ./%,$(CONFIG_TCL_FILES))

ifdef XDC_FILES
  XDC_FILES_REL = $(patsubst %, ../%, $(filter-out /% ./%,$(XDC_FILES))) $(filter /% ./%,$(XDC_FILES))
else
  XDC_FILES_REL = $(FPGA_TOP).xdc
endif

###################################################################
# Main Targets
#
# all: build everything
# clean: remove output files and project files
###################################################################

all: fpga

fpga: $(FPGA_TOP).bit

vivado: $(FPGA_TOP).xpr
	vivado $(FPGA_TOP).xpr

tmpclean::
	-rm -rf *.log *.jou *.cache *.gen *.hbs *.hw *.ip_user_files *.runs *.xpr *.html *.xml *.sim *.srcs *.str .Xil defines.v
	-rm -rf create_project.tcl update_config.tcl run_synth.tcl run_impl.tcl generate_bit.tcl

clean:: tmpclean
	-rm -rf *.bit program.tcl generate_mcs.tcl *.mcs *.prm flash.tcl

distclean:: clean
	-rm -rf rev

###################################################################
# Target implementations
###################################################################

# Vivado project file
create_project.tcl: Makefile $(XCI_FILES_REL) $(IP_TCL_FILES_REL)
	rm -rf defines.v
	touch defines.v
	for x in $(DEFS); do echo '`define' $$x >> defines.v; done
	echo "create_project -force -part $(FPGA_PART) $(FPGA_TOP)" > $@
	echo "add_files -fileset sources_1 defines.v $(SYN_FILES_REL)" >> $@
	echo "add_files -fileset constrs_1 $(XDC_FILES_REL)" >> $@
	for x in $(XCI_FILES_REL); do echo "import_ip $$x" >> $@; done
	for x in $(IP_TCL_FILES_REL); do echo "source $$x" >> $@; done
	for x in $(CONFIG_TCL_FILES_REL); do echo "source $$x" >> $@; done

update_config.tcl: $(CONFIG_TCL_FILES_REL)
	echo "open_project -quiet $(FPGA_TOP).xpr" > $@
	for x in $(CONFIG_TCL_FILES_REL); do echo "source $$x" >> $@; done

$(FPGA_TOP).xpr: create_project.tcl update_config.tcl
	vivado -nojournal -nolog -mode batch $(foreach x,$?,-source $x)

# synthesis run
%.runs/synth_1/%.dcp: %.xpr $(SYN_FILES_REL) $(INC_FILES_REL) $(XDC_FILES_REL) $(CONFIG_TCL_FILES_REL)
	echo "open_project $*.xpr" > run_synth.tcl
	echo "reset_run synth_1" >> run_synth.tcl
	echo "launch_runs -jobs 4 synth_1" >> run_synth.tcl
	echo "wait_on_run synth_1" >> run_synth.tcl
	vivado -nojournal -nolog -mode batch -source run_synth.tcl

# implementation run
%.runs/impl_1/%_routed.dcp: %.runs/synth_1/%.dcp
	echo "open_project $*.xpr" > run_impl.tcl
	echo "reset_run impl_1" >> run_impl.tcl
	echo "launch_runs -jobs 4 impl_1" >> run_impl.tcl
	echo "wait_on_run impl_1" >> run_impl.tcl
	vivado -nojournal -nolog -mode batch -source run_impl.tcl

# bit file
%.bit: %.runs/impl_1/%_routed.dcp
	echo "open_project $*.xpr" > generate_bit.tcl
	echo "open_run impl_1" >> generate_bit.tcl
	echo "write_bitstream -force $*.bit" >> generate_bit.tcl
	vivado -nojournal -nolog -mode batch -source generate_bit.tcl
	mkdir -p rev
	EXT=bit; COUNT=100; \
	while [ -e rev/$*_rev$$COUNT.$$EXT ]; \
	do COUNT=$$((COUNT+1)); done; \
	cp $@ rev/$*_rev$$COUNT.$$EXT; \
	echo "Output: rev/$*_rev$$COUNT.$$EXT";
