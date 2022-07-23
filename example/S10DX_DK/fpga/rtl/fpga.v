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
 * FPGA top-level module
 */
module fpga (
    /*
     * Clock: 50 MHz, 100 MHz
     * Reset: Push button, active low
     */
    // input  wire       clk2_fpga_50m,
    // input  wire       clk2_100m_fpga_2i_p,
    // input  wire       cpu_resetn,

    /*
     * GPIO
     */
    input  wire         user_pb,
    output wire [3:0]   user_led_g,

    /*
     * PCIe: gen 4 x16
     */
    output wire [15:0]  pcie_tx_p,
    output wire [15:0]  pcie_tx_n,
    input  wire [15:0]  pcie_rx_p,
    input  wire [15:0]  pcie_rx_n,
    input  wire         clk_100m_pcie_0_p,
    input  wire         clk_100m_pcie_1_p,
    input  wire         pcie_rst_n,

    /*
     * Ethernet: QSFP28
     */
    // output wire [3:0] qsfp1_tx_p,
    // output wire [3:0] qsfp1_tx_n,
    // input  wire [3:0] qsfp1_rx_p,
    // input  wire [3:0] qsfp1_rx_n,
    // output wire [3:0] qsfp2_tx_p,
    // output wire [3:0] qsfp2_tx_n,
    // input  wire [3:0] qsfp2_rx_p,
    // input  wire [3:0] qsfp2_rx_n,
    input  wire clk_156p25m_qsfp0_p
    // input  wire clk_156p25m_qsfp1_p,
    // input  wire clk_312p5m_qsfp0_p,
    // input  wire clk_312p5m_qsfp1_p,
    // input  wire clk_312p5m_qsfp2_p
);

parameter SEG_COUNT = 2;
parameter SEG_DATA_WIDTH = 256;
parameter SEG_EMPTY_WIDTH = $clog2(SEG_DATA_WIDTH/32);
parameter SEG_HDR_WIDTH = 128;
parameter SEG_PRFX_WIDTH = 32;

parameter TX_SEQ_NUM_WIDTH = 6;

parameter PCIE_TAG_COUNT = 256;
parameter BAR0_APERTURE = 24;
parameter BAR2_APERTURE = 24;
parameter BAR4_APERTURE = 16;

// Clock and reset

wire ninit_done;

reset_release reset_release_inst (
    .ninit_done (ninit_done)
);

// wire clk_100mhz = clk_sys_100m_p;
// wire rst_100mhz;

// sync_reset #(
//     .N(20)
// )
// sync_reset_100mhz_inst (
//     .clk(clk_100mhz),
//     .rst(!cpu_resetn || ninit_done),
//     .out(rst_100mhz)
// );

wire coreclkout_hip;
wire reset_status_n;

wire                                  clk = coreclkout_hip;
wire                                  rst = !reset_status_n;

wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]   rx_st_data;
wire [SEG_COUNT*SEG_EMPTY_WIDTH-1:0]  rx_st_empty;
wire [SEG_COUNT-1:0]                  rx_st_sop;
wire [SEG_COUNT-1:0]                  rx_st_eop;
wire [SEG_COUNT-1:0]                  rx_st_valid;
wire                                  rx_st_ready;
wire [SEG_COUNT*SEG_HDR_WIDTH-1:0]    rx_st_hdr;
wire [SEG_COUNT*SEG_PRFX_WIDTH-1:0]   rx_st_tlp_prfx;
wire [SEG_COUNT-1:0]                  rx_st_vf_active = 0;
wire [SEG_COUNT*3-1:0]                rx_st_func_num = 0;
wire [SEG_COUNT*11-1:0]               rx_st_vf_num = 0;
wire [SEG_COUNT*3-1:0]                rx_st_bar_range;
wire [SEG_COUNT-1:0]                  rx_st_tlp_abort;

wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]   tx_st_data;
wire [SEG_COUNT-1:0]                  tx_st_sop;
wire [SEG_COUNT-1:0]                  tx_st_eop;
wire [SEG_COUNT-1:0]                  tx_st_valid;
wire                                  tx_st_ready;
wire [SEG_COUNT-1:0]                  tx_st_err;
wire [SEG_COUNT*SEG_HDR_WIDTH-1:0]    tx_st_hdr;
wire [SEG_COUNT*SEG_PRFX_WIDTH-1:0]   tx_st_tlp_prfx;

wire [11:0]                           rx_buffer_limit;
wire [1:0]                            rx_buffer_limit_tdm_idx;

wire [15:0]                           tx_cdts_limit;
wire [2:0]                            tx_cdts_limit_tdm_idx;

wire [15:0]                           tl_cfg_ctl;
wire [4:0]                            tl_cfg_add;
wire [2:0]                            tl_cfg_func;

pcie pcie_hip_inst (
    .p0_rx_st_ready_i(rx_st_ready),
    .p0_rx_st_sop_o(rx_st_sop),
    .p0_rx_st_eop_o(rx_st_eop),
    .p0_rx_st_data_o(rx_st_data),
    .p0_rx_st_valid_o(rx_st_valid),
    .p0_rx_st_empty_o(rx_st_empty),
    .p0_rx_st_hdr_o(rx_st_hdr),
    .p0_rx_st_tlp_prfx_o(rx_st_tlp_prfx),
    .p0_rx_st_bar_range_o(rx_st_bar_range),
    .p0_rx_st_tlp_abort_o(rx_st_tlp_abort),
    .p0_rx_par_err_o(),
    .p0_tx_st_sop_i(tx_st_sop),
    .p0_tx_st_eop_i(tx_st_eop),
    .p0_tx_st_data_i(tx_st_data),
    .p0_tx_st_valid_i(tx_st_valid),
    .p0_tx_st_err_i(tx_st_err),
    .p0_tx_st_ready_o(tx_st_ready),
    .p0_tx_st_hdr_i(tx_st_hdr),
    .p0_tx_st_tlp_prfx_i(tx_st_tlp_prfx),
    .p0_tx_par_err_o(),
    .p0_tx_cdts_limit_o(tx_cdts_limit),
    .p0_tx_cdts_limit_tdm_idx_o(tx_cdts_limit_tdm_idx),
    .p0_tl_cfg_func_o(tl_cfg_func),
    .p0_tl_cfg_add_o(tl_cfg_add),
    .p0_tl_cfg_ctl_o(tl_cfg_ctl),
    .p0_dl_timer_update_o(),
    .p0_reset_status_n(reset_status_n),
    .p0_pin_perst_n(),
    .p0_link_up_o(),
    .p0_dl_up_o(),
    .p0_surprise_down_err_o(),
    .p0_ltssm_state_o(),
    .rx_n_in0(pcie_rx_n[0]),
    .rx_n_in1(pcie_rx_n[1]),
    .rx_n_in2(pcie_rx_n[2]),
    .rx_n_in3(pcie_rx_n[3]),
    .rx_n_in4(pcie_rx_n[4]),
    .rx_n_in5(pcie_rx_n[5]),
    .rx_n_in6(pcie_rx_n[6]),
    .rx_n_in7(pcie_rx_n[7]),
    .rx_n_in8(pcie_rx_n[8]),
    .rx_n_in9(pcie_rx_n[9]),
    .rx_n_in10(pcie_rx_n[10]),
    .rx_n_in11(pcie_rx_n[11]),
    .rx_n_in12(pcie_rx_n[12]),
    .rx_n_in13(pcie_rx_n[13]),
    .rx_n_in14(pcie_rx_n[14]),
    .rx_n_in15(pcie_rx_n[15]),
    .rx_p_in0(pcie_rx_p[0]),
    .rx_p_in1(pcie_rx_p[1]),
    .rx_p_in2(pcie_rx_p[2]),
    .rx_p_in3(pcie_rx_p[3]),
    .rx_p_in4(pcie_rx_p[4]),
    .rx_p_in5(pcie_rx_p[5]),
    .rx_p_in6(pcie_rx_p[6]),
    .rx_p_in7(pcie_rx_p[7]),
    .rx_p_in8(pcie_rx_p[8]),
    .rx_p_in9(pcie_rx_p[9]),
    .rx_p_in10(pcie_rx_p[10]),
    .rx_p_in11(pcie_rx_p[11]),
    .rx_p_in12(pcie_rx_p[12]),
    .rx_p_in13(pcie_rx_p[13]),
    .rx_p_in14(pcie_rx_p[14]),
    .rx_p_in15(pcie_rx_p[15]),
    .tx_n_out0(pcie_tx_n[0]),
    .tx_n_out1(pcie_tx_n[1]),
    .tx_n_out2(pcie_tx_n[2]),
    .tx_n_out3(pcie_tx_n[3]),
    .tx_n_out4(pcie_tx_n[4]),
    .tx_n_out5(pcie_tx_n[5]),
    .tx_n_out6(pcie_tx_n[6]),
    .tx_n_out7(pcie_tx_n[7]),
    .tx_n_out8(pcie_tx_n[8]),
    .tx_n_out9(pcie_tx_n[9]),
    .tx_n_out10(pcie_tx_n[10]),
    .tx_n_out11(pcie_tx_n[11]),
    .tx_n_out12(pcie_tx_n[12]),
    .tx_n_out13(pcie_tx_n[13]),
    .tx_n_out14(pcie_tx_n[14]),
    .tx_n_out15(pcie_tx_n[15]),
    .tx_p_out0(pcie_tx_p[0]),
    .tx_p_out1(pcie_tx_p[1]),
    .tx_p_out2(pcie_tx_p[2]),
    .tx_p_out3(pcie_tx_p[3]),
    .tx_p_out4(pcie_tx_p[4]),
    .tx_p_out5(pcie_tx_p[5]),
    .tx_p_out6(pcie_tx_p[6]),
    .tx_p_out7(pcie_tx_p[7]),
    .tx_p_out8(pcie_tx_p[8]),
    .tx_p_out9(pcie_tx_p[9]),
    .tx_p_out10(pcie_tx_p[10]),
    .tx_p_out11(pcie_tx_p[11]),
    .tx_p_out12(pcie_tx_p[12]),
    .tx_p_out13(pcie_tx_p[13]),
    .tx_p_out14(pcie_tx_p[14]),
    .tx_p_out15(pcie_tx_p[15]),
    .coreclkout_hip(coreclkout_hip),
    .refclk0(clk_100m_pcie_0_p),
    .refclk1(clk_100m_pcie_1_p),
    .pin_perst_n(pcie_rst_n),
    .ninit_done(ninit_done)
);

fpga_core #(
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_EMPTY_WIDTH(SEG_EMPTY_WIDTH),
    .SEG_HDR_WIDTH(SEG_HDR_WIDTH),
    .SEG_PRFX_WIDTH(SEG_PRFX_WIDTH),
    .TX_SEQ_NUM_WIDTH(TX_SEQ_NUM_WIDTH),
    .PCIE_TAG_COUNT(PCIE_TAG_COUNT),
    .BAR0_APERTURE(BAR0_APERTURE),
    .BAR2_APERTURE(BAR2_APERTURE),
    .BAR4_APERTURE(BAR4_APERTURE)
)
fpga_core_inst (
    .clk(clk),
    .rst(rst),

    /*
     * GPIO
     */
    .user_led_g(user_led_g),

    /*
     * P-Tile RX AVST interface
     */
    .rx_st_data(rx_st_data),
    .rx_st_empty(rx_st_empty),
    .rx_st_sop(rx_st_sop),
    .rx_st_eop(rx_st_eop),
    .rx_st_valid(rx_st_valid),
    .rx_st_ready(rx_st_ready),
    .rx_st_hdr(rx_st_hdr),
    .rx_st_tlp_prfx(rx_st_tlp_prfx),
    .rx_st_vf_active(rx_st_vf_active),
    .rx_st_func_num(rx_st_func_num),
    .rx_st_vf_num(rx_st_vf_num),
    .rx_st_bar_range(rx_st_bar_range),
    .rx_st_tlp_abort(rx_st_tlp_abort),

    .tx_st_data(tx_st_data),
    .tx_st_sop(tx_st_sop),
    .tx_st_eop(tx_st_eop),
    .tx_st_valid(tx_st_valid),
    .tx_st_ready(tx_st_ready),
    .tx_st_err(tx_st_err),
    .tx_st_hdr(tx_st_hdr),
    .tx_st_tlp_prfx(tx_st_tlp_prfx),

    .rx_buffer_limit(rx_buffer_limit),
    .rx_buffer_limit_tdm_idx(rx_buffer_limit_tdm_idx),

    .tx_cdts_limit(tx_cdts_limit),
    .tx_cdts_limit_tdm_idx(tx_cdts_limit_tdm_idx),

    .tl_cfg_ctl(tl_cfg_ctl),
    .tl_cfg_add(tl_cfg_add),
    .tl_cfg_func(tl_cfg_func)
);

endmodule

`resetall
