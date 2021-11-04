package require -exact qsys 21.3

# create the system "pcie"
proc do_create_pcie {} {
	# create the system
	create_system pcie
	set_project_property DEVICE {1SM21CHU2F53E2VG}
	set_project_property DEVICE_FAMILY {Stratix 10}
	set_project_property HIDE_FROM_IP_CATALOG {true}
	set_use_testbench_naming_pattern 0 {}

	# add HDL parameters

	# add the components
	add_instance pcie_s10_hip_ast_0 altera_pcie_s10_hip_ast
	set_instance_parameter_value pcie_s10_hip_ast_0 {anlg_voltage} {1_1V}
	set_instance_parameter_value pcie_s10_hip_ast_0 {apps_type_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {bfm_drive_interface_clk_hwtcl} {1}
	set_instance_parameter_value pcie_s10_hip_ast_0 {bfm_drive_interface_control_hwtcl} {1}
	set_instance_parameter_value pcie_s10_hip_ast_0 {bfm_drive_interface_npor_hwtcl} {1}
	set_instance_parameter_value pcie_s10_hip_ast_0 {bfm_drive_interface_pipe_hwtcl} {1}
	set_instance_parameter_value pcie_s10_hip_ast_0 {ceb_extend_pcie_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {chosen_devkit_hwtcl} {Stratix 10 MX H-Tile Production FPGA Development Kit}
	set_instance_parameter_value pcie_s10_hip_ast_0 {cvp_user_id_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {design_environment} {NATIVE}
	set_instance_parameter_value pcie_s10_hip_ast_0 {device_ctrl_enable_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {disable_256_to_512_adapter_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {eios_workaround_enable_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {enable_avst_reset_hwtcl} {1}
	set_instance_parameter_value pcie_s10_hip_ast_0 {enable_example_design_qii_hwtcl} {1}
	set_instance_parameter_value pcie_s10_hip_ast_0 {enable_example_design_sim_hwtcl} {1}
	set_instance_parameter_value pcie_s10_hip_ast_0 {enable_example_design_sim_rp_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {enable_example_design_synth_hwtcl} {1}
	set_instance_parameter_value pcie_s10_hip_ast_0 {enable_example_design_synth_rp_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {enable_example_design_tb_hwtcl} {1}
	set_instance_parameter_value pcie_s10_hip_ast_0 {enable_multi_func_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {enable_pcie_cv_fix} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {enable_pipe32_phyip_ser_driver_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {enable_pld_warm_rst_rdy_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {enable_rx_buffer_limit_ports_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {enable_sriov_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {enable_test_out_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {hip_reconfig_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {hrc_rstctl_timer_g_delay_added_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {msi_info_enable_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pcie_link_inspector_avmm_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pcie_link_inspector_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_auto_lane_flip_ctrl_en_hwtcl} {enable}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_bar0_address_width_hwtcl} {24}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_bar0_type_hwtcl} {64-bit prefetchable memory}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_bar1_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_bar1_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_bar2_address_width_hwtcl} {24}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_bar2_type_hwtcl} {64-bit prefetchable memory}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_bar3_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_bar3_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_bar4_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_bar4_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_bar5_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_bar5_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_class_code_hwtcl} {16711680}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_eq_eieos_cnt_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_expansion_base_address_register_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_loopback_enable_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_pci_msi_multiple_msg_cap_hwtcl} {32}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_pci_msix_bir_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_pci_msix_pba_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_pci_msix_pba_offset_hwtcl} {0.0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_pci_msix_table_offset_hwtcl} {0.0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_pci_msix_table_size_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_pci_msix_table_size_vfcomm_cs2_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_pci_type0_device_id_hwtcl} {1}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_pci_type0_vendor_id_hwtcl} {4660}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_pcie_cap_ep_l0s_accpt_latency_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_pcie_cap_ep_l1_accpt_latency_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_pcie_cap_ext_tag_supp_hwtcl} {1}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_pcie_cap_flr_cap_user_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_pcie_cap_phy_slot_num_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_pcie_cap_port_num_hwtcl} {1}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_pcie_cap_sel_deemphasis_hwtcl} {6dB}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_pcie_cap_slot_clk_config_hwtcl} {1}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_pcie_cap_slot_power_limit_scale_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_pcie_cap_slot_power_limit_value_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_pcie_slot_imp_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_revision_id_hwtcl} {1}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_sriov_sup_page_size_user_hwtcl} {4KB, 8KB, 64KB, 256KB, 1MB, 4MB}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_sriov_vf_bar0_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_sriov_vf_bar0_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_sriov_vf_bar1_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_sriov_vf_bar1_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_sriov_vf_bar2_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_sriov_vf_bar2_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_sriov_vf_bar3_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_sriov_vf_bar3_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_sriov_vf_bar4_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_sriov_vf_bar4_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_sriov_vf_bar5_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_sriov_vf_bar5_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_sriov_vf_device_id_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_subsys_dev_id_hwtcl} {1313}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_subsys_vendor_id_hwtcl} {6538}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_tph_req_cap_st_table_loc_1_hwtcl} {ST table not present}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_tph_req_cap_st_table_loc_1_vfcomm_cs2_hwtcl} {ST table not present}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_tph_req_cap_st_table_size_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_tph_req_cap_st_table_size_vfcomm_cs2_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_tph_st_dev_spec_mode_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_tph_st_int_mode_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_vf_ats_cap_enable_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_vf_count_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_vf_tph_cap_enable_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_vf_tph_st_dev_spec_mode_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf0_vf_tph_st_int_mode_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_bar0_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_bar0_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_bar1_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_bar1_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_bar2_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_bar2_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_bar3_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_bar3_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_bar4_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_bar4_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_bar5_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_bar5_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_class_code_hwtcl} {16711680}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_expansion_base_address_register_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_pci_msi_multiple_msg_cap_hwtcl} {1}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_pci_msix_bir_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_pci_msix_pba_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_pci_msix_pba_offset_hwtcl} {0.0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_pci_msix_table_offset_hwtcl} {0.0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_pci_msix_table_size_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_pci_msix_table_size_vfcomm_cs2_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_pci_type0_device_id_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_pci_type0_vendor_id_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_revision_id_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_sriov_sup_page_size_user_hwtcl} {4KB, 8KB, 64KB, 256KB, 1MB, 4MB}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_sriov_vf_bar0_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_sriov_vf_bar0_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_sriov_vf_bar1_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_sriov_vf_bar1_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_sriov_vf_bar2_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_sriov_vf_bar2_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_sriov_vf_bar3_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_sriov_vf_bar3_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_sriov_vf_bar4_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_sriov_vf_bar4_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_sriov_vf_bar5_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_sriov_vf_bar5_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_sriov_vf_device_id_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_subsys_dev_id_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_subsys_vendor_id_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_tph_req_cap_st_table_loc_1_hwtcl} {ST table not present}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_tph_req_cap_st_table_loc_1_vfcomm_cs2_hwtcl} {ST table not present}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_tph_req_cap_st_table_size_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_tph_req_cap_st_table_size_vfcomm_cs2_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_tph_st_dev_spec_mode_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_tph_st_int_mode_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_vf_ats_cap_enable_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_vf_count_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_vf_tph_cap_enable_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_vf_tph_st_dev_spec_mode_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf1_vf_tph_st_int_mode_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_bar0_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_bar0_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_bar1_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_bar1_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_bar2_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_bar2_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_bar3_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_bar3_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_bar4_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_bar4_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_bar5_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_bar5_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_class_code_hwtcl} {16711680}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_expansion_base_address_register_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_pci_msi_multiple_msg_cap_hwtcl} {1}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_pci_msix_bir_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_pci_msix_pba_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_pci_msix_pba_offset_hwtcl} {0.0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_pci_msix_table_offset_hwtcl} {0.0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_pci_msix_table_size_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_pci_msix_table_size_vfcomm_cs2_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_pci_type0_device_id_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_pci_type0_vendor_id_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_revision_id_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_sriov_sup_page_size_user_hwtcl} {4KB, 8KB, 64KB, 256KB, 1MB, 4MB}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_sriov_vf_bar0_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_sriov_vf_bar0_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_sriov_vf_bar1_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_sriov_vf_bar1_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_sriov_vf_bar2_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_sriov_vf_bar2_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_sriov_vf_bar3_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_sriov_vf_bar3_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_sriov_vf_bar4_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_sriov_vf_bar4_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_sriov_vf_bar5_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_sriov_vf_bar5_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_sriov_vf_device_id_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_subsys_dev_id_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_subsys_vendor_id_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_tph_req_cap_st_table_loc_1_hwtcl} {ST table not present}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_tph_req_cap_st_table_loc_1_vfcomm_cs2_hwtcl} {ST table not present}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_tph_req_cap_st_table_size_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_tph_req_cap_st_table_size_vfcomm_cs2_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_tph_st_dev_spec_mode_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_tph_st_int_mode_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_vf_ats_cap_enable_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_vf_count_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_vf_tph_cap_enable_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_vf_tph_st_dev_spec_mode_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf2_vf_tph_st_int_mode_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_bar0_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_bar0_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_bar1_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_bar1_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_bar2_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_bar2_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_bar3_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_bar3_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_bar4_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_bar4_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_bar5_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_bar5_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_class_code_hwtcl} {16711680}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_expansion_base_address_register_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_pci_msi_multiple_msg_cap_hwtcl} {1}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_pci_msix_bir_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_pci_msix_pba_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_pci_msix_pba_offset_hwtcl} {0.0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_pci_msix_table_offset_hwtcl} {0.0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_pci_msix_table_size_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_pci_msix_table_size_vfcomm_cs2_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_pci_type0_device_id_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_pci_type0_vendor_id_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_revision_id_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_sriov_sup_page_size_user_hwtcl} {4KB, 8KB, 64KB, 256KB, 1MB, 4MB}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_sriov_vf_bar0_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_sriov_vf_bar0_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_sriov_vf_bar1_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_sriov_vf_bar1_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_sriov_vf_bar2_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_sriov_vf_bar2_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_sriov_vf_bar3_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_sriov_vf_bar3_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_sriov_vf_bar4_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_sriov_vf_bar4_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_sriov_vf_bar5_address_width_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_sriov_vf_bar5_type_hwtcl} {Disabled}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_sriov_vf_device_id_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_subsys_dev_id_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_subsys_vendor_id_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_tph_req_cap_st_table_loc_1_hwtcl} {ST table not present}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_tph_req_cap_st_table_loc_1_vfcomm_cs2_hwtcl} {ST table not present}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_tph_req_cap_st_table_size_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_tph_req_cap_st_table_size_vfcomm_cs2_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_tph_st_dev_spec_mode_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_tph_st_int_mode_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_vf_ats_cap_enable_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_vf_count_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_vf_tph_cap_enable_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_vf_tph_st_dev_spec_mode_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pf3_vf_tph_st_int_mode_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {pll_refclk_freq_hwtcl} {100 MHz}
	set_instance_parameter_value pcie_s10_hip_ast_0 {select_design_example_hwtcl} {PIO}
	set_instance_parameter_value pcie_s10_hip_ast_0 {select_design_example_rtl_lang_hwtcl} {Verilog}
	set_instance_parameter_value pcie_s10_hip_ast_0 {select_example_design_sim_BFM_hwtcl} {Intel FPGA BFM}
	set_instance_parameter_value pcie_s10_hip_ast_0 {serial_sim_hwtcl} {1}
	set_instance_parameter_value pcie_s10_hip_ast_0 {targeted_devkit_hwtcl} {NONE}
	set_instance_parameter_value pcie_s10_hip_ast_0 {total_pf_count_hwtcl} {1}
	set_instance_parameter_value pcie_s10_hip_ast_0 {use_ast_parity_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {use_pll_lock_hwtcl} {1}
	set_instance_parameter_value pcie_s10_hip_ast_0 {use_rpbfm_pro} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {virtual_ep_native_hwtcl} {Native}
	set_instance_parameter_value pcie_s10_hip_ast_0 {virtual_maxpayload_size_hwtcl} {1024}
	set_instance_parameter_value pcie_s10_hip_ast_0 {virtual_pf0_ats_cap_enable_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {virtual_pf0_msi_enable_hwtcl} {1}
	set_instance_parameter_value pcie_s10_hip_ast_0 {virtual_pf0_msix_enable_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {virtual_pf0_tph_cap_enable_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {virtual_pf1_ats_cap_enable_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {virtual_pf1_msi_enable_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {virtual_pf1_msix_enable_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {virtual_pf1_tph_cap_enable_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {virtual_pf2_ats_cap_enable_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {virtual_pf2_msi_enable_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {virtual_pf2_msix_enable_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {virtual_pf2_tph_cap_enable_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {virtual_pf3_ats_cap_enable_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {virtual_pf3_msi_enable_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {virtual_pf3_msix_enable_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {virtual_pf3_tph_cap_enable_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {virtual_rp_ep_mode_hwtcl} {Native Endpoint}
	set_instance_parameter_value pcie_s10_hip_ast_0 {wrala_hwtcl} {Gen3x8, Interface - 256 bit, 250 MHz}
	set_instance_parameter_value pcie_s10_hip_ast_0 {xcvr_adme_hwtcl} {0}
	set_instance_parameter_value pcie_s10_hip_ast_0 {xcvr_reconfig_hwtcl} {0}
	set_instance_property pcie_s10_hip_ast_0 AUTO_EXPORT true

	# add wirelevel expressions

	# preserve ports for debug

	# add the exports
	set_interface_property refclk EXPORT_OF pcie_s10_hip_ast_0.refclk
	set_interface_property coreclkout_hip EXPORT_OF pcie_s10_hip_ast_0.coreclkout_hip
	set_interface_property npor EXPORT_OF pcie_s10_hip_ast_0.npor
	set_interface_property hip_rst EXPORT_OF pcie_s10_hip_ast_0.hip_rst
	set_interface_property clr_st EXPORT_OF pcie_s10_hip_ast_0.clr_st
	set_interface_property ninit_done EXPORT_OF pcie_s10_hip_ast_0.ninit_done
	set_interface_property rx_st EXPORT_OF pcie_s10_hip_ast_0.rx_st
	set_interface_property tx_st EXPORT_OF pcie_s10_hip_ast_0.tx_st
	set_interface_property rx_bar EXPORT_OF pcie_s10_hip_ast_0.rx_bar
	set_interface_property tx_cred EXPORT_OF pcie_s10_hip_ast_0.tx_cred
	set_interface_property int_msi EXPORT_OF pcie_s10_hip_ast_0.int_msi
	set_interface_property hip_status EXPORT_OF pcie_s10_hip_ast_0.hip_status
	set_interface_property config_tl EXPORT_OF pcie_s10_hip_ast_0.config_tl
	set_interface_property hip_ctrl EXPORT_OF pcie_s10_hip_ast_0.hip_ctrl
	set_interface_property currentspeed EXPORT_OF pcie_s10_hip_ast_0.currentspeed
	set_interface_property hip_pipe EXPORT_OF pcie_s10_hip_ast_0.hip_pipe
	set_interface_property hip_serial EXPORT_OF pcie_s10_hip_ast_0.hip_serial
	set_interface_property power_mgnt EXPORT_OF pcie_s10_hip_ast_0.power_mgnt

	# set values for exposed HDL parameters

	# set the the module properties
	set_module_property BONUS_DATA {<?xml version="1.0" encoding="UTF-8"?>
<bonusData>
 <element __value="pcie_s10_hip_ast_0">
  <datum __value="_sortIndex" value="0" type="int" />
 </element>
</bonusData>
}
	set_module_property FILE {pcie.ip}
	set_module_property GENERATION_ID {0x00000000}
	set_module_property NAME {pcie}

	# save the system
	sync_sysinfo_parameters
	save_system pcie
}

proc do_set_exported_interface_sysinfo_parameters {} {
}

# create all the systems, from bottom up
do_create_pcie

# set system info parameters on exported interface, from bottom up
do_set_exported_interface_sysinfo_parameters
