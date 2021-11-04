/*

Copyright (c) 2018 Alex Forencich

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
 * FPGA core logic
 */
module fpga_core #
(
    parameter SEG_COUNT = 1,
    parameter SEG_DATA_WIDTH = 256,
    parameter SEG_EMPTY_WIDTH = $clog2(SEG_DATA_WIDTH/32),
    parameter TX_SEQ_NUM_WIDTH = 6,
    parameter PCIE_TAG_COUNT = 256,
    parameter BAR0_APERTURE = 24,
    parameter BAR2_APERTURE = 24
)
(
    input  wire                                  clk,
    input  wire                                  rst,

    /*
     * GPIO
     */
    output wire [1:0]                            led_user_grn,
    output wire [1:0]                            led_user_red,
    output wire [3:0]                            led_qsfp,

    /*
     * H-Tile interface
     */
    input  wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]   rx_st_data,
    input  wire [SEG_COUNT*SEG_EMPTY_WIDTH-1:0]  rx_st_empty,
    input  wire [SEG_COUNT-1:0]                  rx_st_sop,
    input  wire [SEG_COUNT-1:0]                  rx_st_eop,
    input  wire [SEG_COUNT-1:0]                  rx_st_valid,
    output wire                                  rx_st_ready,
    input  wire [SEG_COUNT-1:0]                  rx_st_vf_active,
    input  wire [SEG_COUNT*2-1:0]                rx_st_func_num,
    input  wire [SEG_COUNT*11-1:0]               rx_st_vf_num,
    input  wire [SEG_COUNT*3-1:0]                rx_st_bar_range,

    output wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]   tx_st_data,
    output wire [SEG_COUNT-1:0]                  tx_st_sop,
    output wire [SEG_COUNT-1:0]                  tx_st_eop,
    output wire [SEG_COUNT-1:0]                  tx_st_valid,
    input  wire                                  tx_st_ready,
    output wire [SEG_COUNT-1:0]                  tx_st_err,

    input  wire [7:0]                            tx_ph_cdts,
    input  wire [11:0]                           tx_pd_cdts,
    input  wire [7:0]                            tx_nph_cdts,
    input  wire [11:0]                           tx_npd_cdts,
    input  wire [7:0]                            tx_cplh_cdts,
    input  wire [11:0]                           tx_cpld_cdts,
    input  wire [SEG_COUNT-1:0]                  tx_hdr_cdts_consumed,
    input  wire [SEG_COUNT-1:0]                  tx_data_cdts_consumed,
    input  wire [SEG_COUNT*2-1:0]                tx_cdts_type,
    input  wire [SEG_COUNT*1-1:0]                tx_cdts_data_value,

    output wire                                  app_msi_req,
    input  wire                                  app_msi_ack,
    output wire [2:0]                            app_msi_tc,
    output wire [4:0]                            app_msi_num,
    output wire [1:0]                            app_msi_func_num,

    input  wire [31:0]                           tl_cfg_ctl,
    input  wire [4:0]                            tl_cfg_add,
    input  wire [1:0]                            tl_cfg_func
);

assign led_user_grn = 0;
assign led_user_red = 0;
assign led_qsfp = 0;

example_core_pcie_s10 #(
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_EMPTY_WIDTH(SEG_EMPTY_WIDTH),
    .TX_SEQ_NUM_WIDTH(TX_SEQ_NUM_WIDTH),
    .TX_SEQ_NUM_ENABLE(1),
    .L_TILE(0),
    .PCIE_TAG_COUNT(PCIE_TAG_COUNT),
    .READ_OP_TABLE_SIZE(PCIE_TAG_COUNT),
    .READ_TX_LIMIT(2**TX_SEQ_NUM_WIDTH),
    .READ_TX_FC_ENABLE(1),
    .WRITE_OP_TABLE_SIZE(2**TX_SEQ_NUM_WIDTH),
    .WRITE_TX_LIMIT(2**TX_SEQ_NUM_WIDTH),
    .WRITE_TX_FC_ENABLE(1),
    .BAR0_APERTURE(BAR0_APERTURE),
    .BAR2_APERTURE(BAR2_APERTURE)
)
example_core_pcie_s10_inst (
    .clk(clk),
    .rst(rst),

    /*
     * H-tile RX AVST interface
     */
    .rx_st_data(rx_st_data),
    .rx_st_empty(rx_st_empty),
    .rx_st_sop(rx_st_sop),
    .rx_st_eop(rx_st_eop),
    .rx_st_valid(rx_st_valid),
    .rx_st_ready(rx_st_ready),
    .rx_st_vf_active(rx_st_vf_active),
    .rx_st_func_num(rx_st_func_num),
    .rx_st_vf_num(rx_st_vf_num),
    .rx_st_bar_range(rx_st_bar_range),

    /*
     * H-tile TX AVST interface
     */
    .tx_st_data(tx_st_data),
    .tx_st_sop(tx_st_sop),
    .tx_st_eop(tx_st_eop),
    .tx_st_valid(tx_st_valid),
    .tx_st_ready(tx_st_ready),
    .tx_st_err(tx_st_err),

    /*
     * H-tile TX flow control
     */
    .tx_ph_cdts(tx_ph_cdts),
    .tx_pd_cdts(tx_pd_cdts),
    .tx_nph_cdts(tx_nph_cdts),
    .tx_npd_cdts(tx_npd_cdts),
    .tx_cplh_cdts(tx_cplh_cdts),
    .tx_cpld_cdts(tx_cpld_cdts),
    .tx_hdr_cdts_consumed(tx_hdr_cdts_consumed),
    .tx_data_cdts_consumed(tx_data_cdts_consumed),
    .tx_cdts_type(tx_cdts_type),
    .tx_cdts_data_value(tx_cdts_data_value),

    /*
     * H-tile MSI interrupt interface
     */
    .app_msi_req(app_msi_req),
    .app_msi_ack(app_msi_ack),
    .app_msi_tc(app_msi_tc),
    .app_msi_num(app_msi_num),
    .app_msi_func_num(app_msi_func_num),

    /*
     * H-tile configuration interface
     */
    .tl_cfg_ctl(tl_cfg_ctl),
    .tl_cfg_add(tl_cfg_add),
    .tl_cfg_func(tl_cfg_func)
);

endmodule

`resetall
