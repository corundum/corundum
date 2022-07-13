/*

Copyright (c) 2022 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * P-Tile PCIe configuration interface
 */
module pcie_ptile_cfg #
(
    // Number of physical functions
    parameter PF_COUNT = 1
)
(
    input  wire                    clk,
    input  wire                    rst,

    /*
     * Configuration input from P-Tile
     */
    input  wire [15:0]             tl_cfg_ctl,
    input  wire [4:0]              tl_cfg_add,
    input  wire [2:0]              tl_cfg_func,

    /*
     * Configuration output
     */
    output reg  [PF_COUNT-1:0]     cfg_memory_space_en,
    output reg  [PF_COUNT-1:0]     cfg_ido_cpl_en,
    output reg  [PF_COUNT-1:0]     cfg_perr_en,
    output reg  [PF_COUNT-1:0]     cfg_serr_en,
    output reg  [PF_COUNT-1:0]     cfg_fatal_err_rpt_en,
    output reg  [PF_COUNT-1:0]     cfg_nonfatal_err_rpt_en,
    output reg  [PF_COUNT-1:0]     cfg_corr_err_rpt_en,
    output reg  [PF_COUNT-1:0]     cfg_unsupported_req_rpt_en,
    output reg  [PF_COUNT-1:0]     cfg_bus_master_en,
    output reg  [PF_COUNT-1:0]     cfg_ext_tag_en,
    output reg  [PF_COUNT*3-1:0]   cfg_max_read_request_size,
    output reg  [PF_COUNT*3-1:0]   cfg_max_payload_size,
    output reg  [PF_COUNT-1:0]     cfg_ido_request_en,
    output reg  [PF_COUNT-1:0]     cfg_no_snoop_en,
    output reg  [PF_COUNT-1:0]     cfg_relaxed_ordering_en,
    output reg  [PF_COUNT*5-1:0]   cfg_device_num,
    output reg  [PF_COUNT*8-1:0]   cfg_bus_num,
    output reg  [PF_COUNT-1:0]     cfg_pm_no_soft_rst,
    output reg  [PF_COUNT-1:0]     cfg_rcb_ctrl,
    output reg  [PF_COUNT-1:0]     cfg_irq_disable,
    output reg  [PF_COUNT*5-1:0]   cfg_pcie_cap_irq_msg_num,
    output reg  [PF_COUNT-1:0]     cfg_sys_pwr_ctrl,
    output reg  [PF_COUNT*2-1:0]   cfg_sys_atten_ind_ctrl,
    output reg  [PF_COUNT*2-1:0]   cfg_sys_pwr_ind_ctrl,
    output reg  [PF_COUNT*16-1:0]  cfg_num_vf,
    output reg  [PF_COUNT-1:0]     cfg_atomic_egress_block,
    output reg  [PF_COUNT*5-1:0]   cfg_ats_stu,
    output reg  [PF_COUNT-1:0]     cfg_ats_cache_en,
    output reg  [PF_COUNT-1:0]     cfg_ari_forward_en,
    output reg  [PF_COUNT-1:0]     cfg_atomic_request_en,
    output reg  [PF_COUNT*3-1:0]   cfg_tph_st_mode,
    output reg  [PF_COUNT*2-1:0]   cfg_tph_en,
    output reg  [PF_COUNT-1:0]     cfg_vf_en,
    output reg  [PF_COUNT*4-1:0]   cfg_an_link_speed,
    output reg  [PF_COUNT*11-1:0]  cfg_start_vf_index,
    output reg  [PF_COUNT*64-1:0]  cfg_msi_address,
    output reg  [PF_COUNT*32-1:0]  cfg_msi_mask,
    output reg  [PF_COUNT-1:0]     cfg_send_f_err,
    output reg  [PF_COUNT-1:0]     cfg_send_nf_err,
    output reg  [PF_COUNT-1:0]     cfg_send_cor_err,
    output reg  [PF_COUNT*5-1:0]   cfg_aer_irq_msg_num,
    output reg  [PF_COUNT-1:0]     cfg_msi_ext_data_en,
    output reg  [PF_COUNT-1:0]     cfg_msix_func_mask,
    output reg  [PF_COUNT-1:0]     cfg_msix_enable,
    output reg  [PF_COUNT*3-1:0]   cfg_multiple_msi_enable,
    output reg  [PF_COUNT-1:0]     cfg_64bit_msi,
    output reg  [PF_COUNT-1:0]     cfg_msi_enable,
    output reg  [PF_COUNT*32-1:0]  cfg_msi_data,
    output reg  [PF_COUNT*32-1:0]  cfg_aer_uncor_err_mask,
    output reg  [PF_COUNT*32-1:0]  cfg_aer_corr_err_mask,
    output reg  [PF_COUNT*32-1:0]  cfg_aer_uncor_err_severity,
    output reg  [PF_COUNT*8-1:0]   cfg_acs_egress_ctrl_vec,
    output reg  [PF_COUNT-1:0]     cfg_acs_func_grp_en,
    output reg  [PF_COUNT-1:0]     cfg_acs_p2p_direct_tranl_en,
    output reg  [PF_COUNT-1:0]     cfg_acs_egress_ctrl_en,
    output reg  [PF_COUNT-1:0]     cfg_acs_up_forward_en,
    output reg  [PF_COUNT-1:0]     cfg_acs_p2p_compl_redirect_en,
    output reg  [PF_COUNT-1:0]     cfg_acs_p2p_req_redirect_en,
    output reg  [PF_COUNT-1:0]     cfg_acs_at_blocking_en,
    output reg  [PF_COUNT-1:0]     cfg_acs_validation_en,
    output reg  [PF_COUNT-1:0]     cfg_10b_tag_req_en,
    output reg  [PF_COUNT-1:0]     cfg_vf_10b_tag_req_en,
    output reg  [PF_COUNT-1:0]     cfg_prs_response_failure,
    output reg  [PF_COUNT-1:0]     cfg_prs_uprgi,
    output reg  [PF_COUNT-1:0]     cfg_prs_stopped,
    output reg  [PF_COUNT-1:0]     cfg_prs_reset,
    output reg  [PF_COUNT-1:0]     cfg_prs_enable,
    output reg  [PF_COUNT*3-1:0]   cfg_ari_func_grp,
    output reg  [PF_COUNT*32-1:0]  cfg_prs_outstanding_allocation,
    output reg  [PF_COUNT-1:0]     cfg_disable_ltr_clr_msg,
    output reg  [PF_COUNT-1:0]     cfg_ltr_m_en,
    output reg  [PF_COUNT-1:0]     cfg_fc_ph_cdts_inf,
    output reg  [PF_COUNT-1:0]     cfg_fc_pd_cdts_inf,
    output reg  [PF_COUNT-1:0]     cfg_fc_ch_cdts_inf,
    output reg  [PF_COUNT-1:0]     cfg_fc_cd_cdts_inf,
    output reg  [PF_COUNT-1:0]     cfg_end2end_tlp_pfx_blck,
    output reg  [PF_COUNT-1:0]     cfg_pf_pasid_en,
    output reg  [PF_COUNT-1:0]     cfg_pf_pasid_execute_perm_en,
    output reg  [PF_COUNT-1:0]     cfg_pf_pasid_priv_mode_en,
    output reg  [PF_COUNT-1:0]     cfg_atten_button_pressed_en,
    output reg  [PF_COUNT-1:0]     cfg_cfg_pwr_fault_det_en,
    output reg  [PF_COUNT-1:0]     cfg_mrl_sensor_chged_en,
    output reg  [PF_COUNT-1:0]     cfg_pre_det_chged_en,
    output reg  [PF_COUNT-1:0]     cfg_hp_int_en,
    output reg  [PF_COUNT-1:0]     cfg_cmd_cpled_int_en,
    output reg  [PF_COUNT-1:0]     cfg_dll_state_change_en,
    output reg  [PF_COUNT-1:0]     cfg_hp_slot_ctrl_access,
    output reg  [PF_COUNT-1:0]     cfg_br_ctrl_serren,
    output reg  [PF_COUNT*32-1:0]  cfg_ltr_max_latency,
    output reg  [PF_COUNT*8-1:0]   cfg_tc_enable,
    output reg  [PF_COUNT*6-1:0]   cfg_an_link_width
);

always @(posedge clk) begin
    if (tl_cfg_func < PF_COUNT) begin
        case (tl_cfg_add)
            5'h00: begin
                cfg_memory_space_en[tl_cfg_func +: 1] <= tl_cfg_ctl[15];
                cfg_ido_cpl_en[tl_cfg_func +: 1] <= tl_cfg_ctl[14];
                cfg_perr_en[tl_cfg_func +: 1] <= tl_cfg_ctl[13];
                cfg_serr_en[tl_cfg_func +: 1] <= tl_cfg_ctl[12];
                cfg_fatal_err_rpt_en[tl_cfg_func +: 1] <= tl_cfg_ctl[11];
                cfg_nonfatal_err_rpt_en[tl_cfg_func +: 1] <= tl_cfg_ctl[10];
                cfg_corr_err_rpt_en[tl_cfg_func +: 1] <= tl_cfg_ctl[9];
                cfg_unsupported_req_rpt_en[tl_cfg_func +: 1] <= tl_cfg_ctl[8];
                cfg_bus_master_en[tl_cfg_func +: 1] <= tl_cfg_ctl[7];
                cfg_ext_tag_en[tl_cfg_func +: 1] <= tl_cfg_ctl[6];
                cfg_max_read_request_size[tl_cfg_func*3 +: 3] <= tl_cfg_ctl[5:3];
                cfg_max_payload_size[tl_cfg_func*3 +: 3] <= tl_cfg_ctl[2:0];
            end
            5'h01: begin
                cfg_ido_request_en[tl_cfg_func +: 1] <= tl_cfg_ctl[15];
                cfg_no_snoop_en[tl_cfg_func +: 1] <= tl_cfg_ctl[14];
                cfg_relaxed_ordering_en[tl_cfg_func +: 1] <= tl_cfg_ctl[13];
                cfg_device_num[tl_cfg_func*5 +: 5] <= tl_cfg_ctl[12:8];
                cfg_bus_num[tl_cfg_func*8 +: 8] <= tl_cfg_ctl[7:0];
            end
            5'h02: begin
                cfg_pm_no_soft_rst[tl_cfg_func +: 1] <= tl_cfg_ctl[15];
                cfg_rcb_ctrl[tl_cfg_func +: 1] <= tl_cfg_ctl[14];
                cfg_irq_disable[tl_cfg_func +: 1] <= tl_cfg_ctl[13];
                cfg_pcie_cap_irq_msg_num[tl_cfg_func*5 +: 5] <= tl_cfg_ctl[12:8];
                cfg_sys_pwr_ctrl[tl_cfg_func +: 1] <= tl_cfg_ctl[4];
                cfg_sys_atten_ind_ctrl[tl_cfg_func*2 +: 2] <= tl_cfg_ctl[3:2];
                cfg_sys_pwr_ind_ctrl[tl_cfg_func*2 +: 2] <= tl_cfg_ctl[1:0];
            end
            5'h03: begin
                cfg_num_vf[tl_cfg_func*16 +: 16] <= tl_cfg_ctl;
            end
            5'h04: begin
                cfg_atomic_egress_block[tl_cfg_func +: 1] <= tl_cfg_ctl[14];
                cfg_ats_stu[tl_cfg_func*5 +: 5] <= tl_cfg_ctl[13:9];
                cfg_ats_cache_en[tl_cfg_func +: 1] <= tl_cfg_ctl[8];
                cfg_ari_forward_en[tl_cfg_func +: 1] <= tl_cfg_ctl[7];
                cfg_atomic_request_en[tl_cfg_func +: 1] <= tl_cfg_ctl[6];
                cfg_tph_st_mode[tl_cfg_func*3 +: 3] <= tl_cfg_ctl[5:3];
                cfg_tph_en[tl_cfg_func*2 +: 2] <= tl_cfg_ctl[2:1];
                cfg_vf_en[tl_cfg_func +: 1] <= tl_cfg_ctl[0];
            end
            5'h05: begin
                cfg_an_link_speed[tl_cfg_func*4 +: 4] <= tl_cfg_ctl[15:12];
                cfg_start_vf_index[tl_cfg_func*11 +: 11] <= tl_cfg_ctl[11:1];
            end
            5'h06: begin
                cfg_msi_address[tl_cfg_func*64+0 +: 16] <= tl_cfg_ctl;
            end
            5'h07: begin
                cfg_msi_address[tl_cfg_func*64+16 +: 16] <= tl_cfg_ctl;
            end
            5'h08: begin
                cfg_msi_address[tl_cfg_func*64+32 +: 16] <= tl_cfg_ctl;
            end
            5'h09: begin
                cfg_msi_address[tl_cfg_func*64+48 +: 16] <= tl_cfg_ctl;
            end
            5'h0A: begin
                cfg_msi_mask[tl_cfg_func*32+0 +: 16] <= tl_cfg_ctl;
            end
            5'h0B: begin
                cfg_msi_mask[tl_cfg_func*32+16 +: 16] <= tl_cfg_ctl;
            end
            5'h0C: begin
                cfg_send_f_err[tl_cfg_func +: 1] <= tl_cfg_ctl[15];
                cfg_send_nf_err[tl_cfg_func +: 1] <= tl_cfg_ctl[14];
                cfg_send_cor_err[tl_cfg_func +: 1] <= tl_cfg_ctl[13];
                cfg_aer_irq_msg_num[tl_cfg_func*5 +: 5] <= tl_cfg_ctl[12:8];
                cfg_msi_ext_data_en[tl_cfg_func +: 1] <= tl_cfg_ctl[7];
                cfg_msix_func_mask[tl_cfg_func +: 1] <= tl_cfg_ctl[6];
                cfg_msix_enable[tl_cfg_func +: 1] <= tl_cfg_ctl[5];
                cfg_multiple_msi_enable[tl_cfg_func*3 +: 3] <= tl_cfg_ctl[4:2];
                cfg_64bit_msi[tl_cfg_func +: 1] <= tl_cfg_ctl[1];
                cfg_msi_enable[tl_cfg_func +: 1] <= tl_cfg_ctl[0];
            end
            5'h0D: begin
                cfg_msi_data[tl_cfg_func*32+0 +: 16] <= tl_cfg_ctl;
            end
            5'h0E: begin
                cfg_aer_uncor_err_mask[tl_cfg_func*32+0 +: 16] <= tl_cfg_ctl;
            end
            5'h0F: begin
                cfg_aer_uncor_err_mask[tl_cfg_func*32+32 +: 16] <= tl_cfg_ctl;
            end
            5'h10: begin
                cfg_aer_corr_err_mask[tl_cfg_func*32+0 +: 16] <= tl_cfg_ctl;
            end
            5'h11: begin
                cfg_aer_corr_err_mask[tl_cfg_func*32+32 +: 16] <= tl_cfg_ctl;
            end
            5'h12: begin
                cfg_aer_uncor_err_severity[tl_cfg_func*32+0 +: 16] <= tl_cfg_ctl;
            end
            5'h13: begin
                cfg_aer_uncor_err_severity[tl_cfg_func*32+32 +: 16] <= tl_cfg_ctl;
            end
            5'h14: begin
                cfg_acs_egress_ctrl_vec[tl_cfg_func*8 +: 8] <= tl_cfg_ctl[15:8];
                cfg_acs_func_grp_en[tl_cfg_func +: 1] <= tl_cfg_ctl[7];
                cfg_acs_p2p_direct_tranl_en[tl_cfg_func +: 1] <= tl_cfg_ctl[6];
                cfg_acs_egress_ctrl_en[tl_cfg_func +: 1] <= tl_cfg_ctl[5];
                cfg_acs_up_forward_en[tl_cfg_func +: 1] <= tl_cfg_ctl[4];
                cfg_acs_p2p_compl_redirect_en[tl_cfg_func +: 1] <= tl_cfg_ctl[3];
                cfg_acs_p2p_req_redirect_en[tl_cfg_func +: 1] <= tl_cfg_ctl[2];
                cfg_acs_at_blocking_en[tl_cfg_func +: 1] <= tl_cfg_ctl[1];
                cfg_acs_validation_en[tl_cfg_func +: 1] <= tl_cfg_ctl[0];
            end
            5'h15: begin
                cfg_10b_tag_req_en[tl_cfg_func +: 1] <= tl_cfg_ctl[14];
                cfg_vf_10b_tag_req_en[tl_cfg_func +: 1] <= tl_cfg_ctl[13];
                cfg_prs_response_failure[tl_cfg_func +: 1] <= tl_cfg_ctl[12];
                cfg_prs_uprgi[tl_cfg_func +: 1] <= tl_cfg_ctl[11];
                cfg_prs_stopped[tl_cfg_func +: 1] <= tl_cfg_ctl[10];
                cfg_prs_reset[tl_cfg_func +: 1] <= tl_cfg_ctl[9];
                cfg_prs_enable[tl_cfg_func +: 1] <= tl_cfg_ctl[8];
                cfg_ari_func_grp[tl_cfg_func*3 +: 3] <= tl_cfg_ctl[2:0];
            end
            5'h16: begin
                cfg_prs_outstanding_allocation[tl_cfg_func*32+0 +: 16] <= tl_cfg_ctl;
            end
            5'h17: begin
                cfg_prs_outstanding_allocation[tl_cfg_func*32+16 +: 16] <= tl_cfg_ctl;
            end
            5'h18: begin
                cfg_disable_ltr_clr_msg[tl_cfg_func +: 1] <= tl_cfg_ctl[9];
                cfg_ltr_m_en[tl_cfg_func +: 1] <= tl_cfg_ctl[8];
                cfg_fc_ph_cdts_inf[tl_cfg_func +: 1] <= tl_cfg_ctl[7];
                cfg_fc_pd_cdts_inf[tl_cfg_func +: 1] <= tl_cfg_ctl[6];
                cfg_fc_ch_cdts_inf[tl_cfg_func +: 1] <= tl_cfg_ctl[5];
                cfg_fc_cd_cdts_inf[tl_cfg_func +: 1] <= tl_cfg_ctl[4];
                cfg_end2end_tlp_pfx_blck[tl_cfg_func +: 1] <= tl_cfg_ctl[3];
                cfg_pf_pasid_en[tl_cfg_func +: 1] <= tl_cfg_ctl[2];
                cfg_pf_pasid_execute_perm_en[tl_cfg_func +: 1] <= tl_cfg_ctl[1];
                cfg_pf_pasid_priv_mode_en[tl_cfg_func +: 1] <= tl_cfg_ctl[0];
            end
            5'h19: begin
                cfg_atten_button_pressed_en[tl_cfg_func +: 1] <= tl_cfg_ctl[8];
                cfg_cfg_pwr_fault_det_en[tl_cfg_func +: 1] <= tl_cfg_ctl[7];
                cfg_mrl_sensor_chged_en[tl_cfg_func +: 1] <= tl_cfg_ctl[6];
                cfg_pre_det_chged_en[tl_cfg_func +: 1] <= tl_cfg_ctl[5];
                cfg_hp_int_en[tl_cfg_func +: 1] <= tl_cfg_ctl[4];
                cfg_cmd_cpled_int_en[tl_cfg_func +: 1] <= tl_cfg_ctl[3];
                cfg_dll_state_change_en[tl_cfg_func +: 1] <= tl_cfg_ctl[2];
                cfg_hp_slot_ctrl_access[tl_cfg_func +: 1] <= tl_cfg_ctl[1];
                cfg_br_ctrl_serren[tl_cfg_func +: 1] <= tl_cfg_ctl[0];
            end
            5'h1A: begin
                cfg_ltr_max_latency[tl_cfg_func*32+0 +: 16] <= tl_cfg_ctl;
            end
            5'h1B: begin
                cfg_ltr_max_latency[tl_cfg_func*32+16 +: 16] <= tl_cfg_ctl;
            end
            5'h1C: begin
                cfg_tc_enable[tl_cfg_func*8 +: 8] <= tl_cfg_ctl[15:8];
                cfg_an_link_width[tl_cfg_func*6 +: 6] <= tl_cfg_ctl[5:0];
            end
            5'h1D: begin
                cfg_msi_data[tl_cfg_func*32+16 +: 16] <= tl_cfg_ctl;
            end
            5'h1E: begin
                
            end
            5'h1F: begin
                
            end
        endcase
    end

    if (rst) begin
        cfg_memory_space_en <= 0;
        cfg_ido_cpl_en <= 0;
        cfg_perr_en <= 0;
        cfg_serr_en <= 0;
        cfg_fatal_err_rpt_en <= 0;
        cfg_nonfatal_err_rpt_en <= 0;
        cfg_corr_err_rpt_en <= 0;
        cfg_unsupported_req_rpt_en <= 0;
        cfg_bus_master_en <= 0;
        cfg_ext_tag_en <= 0;
        cfg_max_read_request_size <= 0;
        cfg_max_payload_size <= 0;
        cfg_ido_request_en <= 0;
        cfg_no_snoop_en <= 0;
        cfg_relaxed_ordering_en <= 0;
        cfg_device_num <= 0;
        cfg_bus_num <= 0;
        cfg_pm_no_soft_rst <= 0;
        cfg_rcb_ctrl <= 0;
        cfg_irq_disable <= 0;
        cfg_pcie_cap_irq_msg_num <= 0;
        cfg_sys_pwr_ctrl <= 0;
        cfg_sys_atten_ind_ctrl <= 0;
        cfg_sys_pwr_ind_ctrl <= 0;
        cfg_num_vf <= 0;
        cfg_atomic_egress_block <= 0;
        cfg_ats_stu <= 0;
        cfg_ats_cache_en <= 0;
        cfg_ari_forward_en <= 0;
        cfg_atomic_request_en <= 0;
        cfg_tph_st_mode <= 0;
        cfg_tph_en <= 0;
        cfg_vf_en <= 0;
        cfg_an_link_speed <= 0;
        cfg_start_vf_index <= 0;
        cfg_msi_address <= 0;
        cfg_msi_mask <= 0;
        cfg_send_f_err <= 0;
        cfg_send_nf_err <= 0;
        cfg_send_cor_err <= 0;
        cfg_aer_irq_msg_num <= 0;
        cfg_msi_ext_data_en <= 0;
        cfg_msix_func_mask <= 0;
        cfg_msix_enable <= 0;
        cfg_multiple_msi_enable <= 0;
        cfg_64bit_msi <= 0;
        cfg_msi_enable <= 0;
        cfg_msi_data <= 0;
        cfg_aer_uncor_err_mask <= 0;
        cfg_aer_corr_err_mask <= 0;
        cfg_aer_uncor_err_severity <= 0;
        cfg_acs_egress_ctrl_vec <= 0;
        cfg_acs_func_grp_en <= 0;
        cfg_acs_p2p_direct_tranl_en <= 0;
        cfg_acs_egress_ctrl_en <= 0;
        cfg_acs_up_forward_en <= 0;
        cfg_acs_p2p_compl_redirect_en <= 0;
        cfg_acs_p2p_req_redirect_en <= 0;
        cfg_acs_at_blocking_en <= 0;
        cfg_acs_validation_en <= 0;
        cfg_10b_tag_req_en <= 0;
        cfg_vf_10b_tag_req_en <= 0;
        cfg_prs_response_failure <= 0;
        cfg_prs_uprgi <= 0;
        cfg_prs_stopped <= 0;
        cfg_prs_reset <= 0;
        cfg_prs_enable <= 0;
        cfg_ari_func_grp <= 0;
        cfg_prs_outstanding_allocation <= 0;
        cfg_disable_ltr_clr_msg <= 0;
        cfg_ltr_m_en <= 0;
        cfg_fc_ph_cdts_inf <= 0;
        cfg_fc_pd_cdts_inf <= 0;
        cfg_fc_ch_cdts_inf <= 0;
        cfg_fc_cd_cdts_inf <= 0;
        cfg_end2end_tlp_pfx_blck <= 0;
        cfg_pf_pasid_en <= 0;
        cfg_pf_pasid_execute_perm_en <= 0;
        cfg_pf_pasid_priv_mode_en <= 0;
        cfg_atten_button_pressed_en <= 0;
        cfg_cfg_pwr_fault_det_en <= 0;
        cfg_mrl_sensor_chged_en <= 0;
        cfg_pre_det_chged_en <= 0;
        cfg_hp_int_en <= 0;
        cfg_cmd_cpled_int_en <= 0;
        cfg_dll_state_change_en <= 0;
        cfg_hp_slot_ctrl_access <= 0;
        cfg_br_ctrl_serren <= 0;
        cfg_ltr_max_latency <= 0;
        cfg_tc_enable <= 0;
        cfg_an_link_width <= 0;
    end
end

endmodule

`resetall
