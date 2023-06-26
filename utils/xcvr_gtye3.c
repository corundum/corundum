// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2022-2023 The Regents of the University of California
 */

#include <stdlib.h>
#include <stdio.h>
#include "xcvr_gtye3.h"

// signals
int gtye3_pll_qpll0_reset(struct gt_pll *pll)
{
    int ret = 0;

    ret = gtye3_pll_set_qpll0_reset(pll, 1);

    if (ret)
        return ret;

    return gtye3_pll_set_qpll0_reset(pll, 0);
}

int gtye3_pll_qpll1_reset(struct gt_pll *pll)
{
    int ret = 0;

    ret = gtye3_pll_set_qpll1_reset(pll, 1);

    if (ret)
        return ret;

    return gtye3_pll_set_qpll1_reset(pll, 0);
}

int gtye3_ch_tx_reset(struct gt_ch *ch)
{
    int ret = 0;

    ret = gtye3_ch_set_tx_reset(ch, 1);

    if (ret)
        return ret;

    return gtye3_ch_set_tx_reset(ch, 0);
}

int gtye3_ch_tx_pma_reset(struct gt_ch *ch)
{
    int ret = 0;

    ret = gtye3_ch_set_tx_pma_reset(ch, 1);

    if (ret)
        return ret;

    return gtye3_ch_set_tx_pma_reset(ch, 0);
}

int gtye3_ch_tx_pcs_reset(struct gt_ch *ch)
{
    int ret = 0;

    ret = gtye3_ch_set_tx_pcs_reset(ch, 1);

    if (ret)
        return ret;

    return gtye3_ch_set_tx_pcs_reset(ch, 0);
}

int gtye3_ch_rx_reset(struct gt_ch *ch)
{
    int ret = 0;

    ret = gtye3_ch_set_rx_reset(ch, 1);

    if (ret)
        return ret;

    return gtye3_ch_set_rx_reset(ch, 0);
}

int gtye3_ch_rx_pma_reset(struct gt_ch *ch)
{
    int ret = 0;

    ret = gtye3_ch_set_rx_pma_reset(ch, 1);

    if (ret)
        return ret;

    return gtye3_ch_set_rx_pma_reset(ch, 0);
}

int gtye3_ch_rx_pcs_reset(struct gt_ch *ch)
{
    int ret = 0;

    ret = gtye3_ch_set_rx_pcs_reset(ch, 1);

    if (ret)
        return ret;

    return gtye3_ch_set_rx_pcs_reset(ch, 0);
}

int gtye3_ch_rx_dfe_lpm_reset(struct gt_ch *ch)
{
    int ret = 0;

    ret = gtye3_ch_set_rx_dfe_lpm_reset(ch, 1);

    if (ret)
        return ret;

    return gtye3_ch_set_rx_dfe_lpm_reset(ch, 0);
}

int gtye3_ch_eyescan_reset(struct gt_ch *ch)
{
    int ret = 0;

    ret = gtye3_ch_set_eyescan_reset(ch, 1);

    if (ret)
        return ret;

    return gtye3_ch_set_eyescan_reset(ch, 0);
}

// RX
int gtye3_ch_get_rx_data_width(struct gt_ch *ch, uint32_t *val)
{
    int ret = 0;
    uint32_t dw;

    ret = gtye3_ch_get_rx_data_width_raw(ch, &dw);
    if (ret)
        return ret;

    *val = (8*(1 << (dw >> 1)) * (4 + (dw & 1))) >> 2;
    return 0;
}

int gtye3_ch_get_rx_int_data_width(struct gt_ch *ch, uint32_t *val)
{
    int ret = 0;
    uint32_t dw, idw;

    ret = gtye3_ch_get_rx_data_width_raw(ch, &dw);
    if (ret)
        return ret;

    ret = gtye3_ch_get_rx_int_data_width_raw(ch, &idw);
    if (ret)
        return ret;

    *val = (16*(1 << idw) * (4 + (dw & 1))) >> 2;
    return 0;
}

int gtye3_ch_set_es_qual_mask(struct gt_ch *ch, uint8_t *mask)
{
    int ret = 0;

    for (int k = 0; k < 5; k++)
    {
        ret = gt_ch_reg_write(ch, GTYE3_CH_ES_QUAL_MASK0_ADDR+k, mask[2*k+0] | (mask[2*k+1] << 8));
        if (ret)
            return ret;
        ret = gt_ch_reg_write(ch, GTYE3_CH_ES_QUAL_MASK5_ADDR+k, mask[2*k+10] | (mask[2*k+11] << 8));
        if (ret)
            return ret;
    }

    return 0;
}

int gtye3_ch_set_es_qual_mask_clear(struct gt_ch *ch)
{
    int ret = 0;

    for (int k = 0; k < 5; k++)
    {
        ret = gt_ch_reg_write(ch, GTYE3_CH_ES_QUAL_MASK0_ADDR+k, 0xffff);
        if (ret)
            return ret;
        ret = gt_ch_reg_write(ch, GTYE3_CH_ES_QUAL_MASK5_ADDR+k, 0xffff);
        if (ret)
            return ret;
    }

    return 0;
}

int gtye3_ch_set_es_sdata_mask(struct gt_ch *ch, uint8_t *mask)
{
    int ret = 0;

    for (int k = 0; k < 5; k++)
    {
        ret = gt_ch_reg_write(ch, GTYE3_CH_ES_SDATA_MASK0_ADDR+k, mask[2*k+0] | (mask[2*k+1] << 8));
        if (ret)
            return ret;
        ret = gt_ch_reg_write(ch, GTYE3_CH_ES_SDATA_MASK5_ADDR+k, mask[2*k+10] | (mask[2*k+11] << 8));
        if (ret)
            return ret;
    }

    return 0;
}

int gtye3_ch_set_es_sdata_mask_width(struct gt_ch *ch, int width)
{
    int ret = 0;

    for (int k = 0; k < 5; k++)
    {
        int shift = width - (80 - ((k+1)*16));
        uint32_t mask = 0xffff;

        if (shift < 0)
        {
            mask = 0xffff;
        }
        else if (shift > 16)
        {
            mask = 0x0000;
        }
        else
        {
            mask = 0xffff >> shift;
        }

        ret = gt_ch_reg_write(ch, GTYE3_CH_ES_SDATA_MASK0_ADDR+k, mask);
        if (ret)
            return ret;
        ret = gt_ch_reg_write(ch, GTYE3_CH_ES_SDATA_MASK5_ADDR+k, 0xffff);
        if (ret)
            return ret;
    }

    return 0;
}

int gtye3_ch_get_rx_prbs_error_count(struct gt_ch *ch, uint32_t *val)
{
    int ret = 0;
    uint32_t v1, v2;

    ret = gt_ch_reg_read(ch, GTYE3_CH_RX_PRBS_ERR_CNT_L_ADDR | (ch->index << 17), &v1);
    if (ret)
        return ret;

    ret = gt_ch_reg_read(ch, GTYE3_CH_RX_PRBS_ERR_CNT_H_ADDR | (ch->index << 17), &v2);
    if (ret)
        return ret;

    *val = v1 | (v2 << 16);
    return 0;
}

// TX
int gtye3_ch_get_tx_data_width(struct gt_ch *ch, uint32_t *val)
{
    int ret = 0;
    uint32_t dw;

    ret = gtye3_ch_get_tx_data_width_raw(ch, &dw);
    if (ret)
        return ret;

    *val = (8*(1 << (dw >> 1)) * (4 + (dw & 1))) >> 2;
    return 0;
}

int gtye3_ch_get_tx_int_data_width(struct gt_ch *ch, uint32_t *val)
{
    int ret = 0;
    uint32_t dw, idw;

    ret = gtye3_ch_get_tx_data_width_raw(ch, &dw);
    if (ret)
        return ret;

    ret = gtye3_ch_get_tx_int_data_width_raw(ch, &idw);
    if (ret)
        return ret;

    *val = (16*(1 << idw) * (4 + (dw & 1))) >> 2;
    return 0;
}

struct gtye3_quad_priv {
    int qpll0_25g;
};

struct gtye3_ch_priv {
    uint32_t tx_data_width;
    uint32_t tx_int_data_width;
    uint32_t rx_data_width;
    uint32_t rx_int_data_width;
    int dfe_en;

    int prescale;
    int h_start;
    int h_stop;
    int h_step;
    int v_range;
    int v_start;
    int v_stop;
    int v_step;

    int h_offset;
    int v_offset;
    int ut_sign;
    int eyescan_running;
};

static const struct gt_reg_val gtye3_ch_preset_10g_baser_64_regs[] = {
    {GTYE3_CH_CH_HSPMUX_ADDR, GTYE3_CH_CH_HSPMUX_MASK, GTYE3_CH_CH_HSPMUX_LSB, 0x2424},
    {GTYE3_CH_CKCAL1_CFG_3_ADDR, GTYE3_CH_CKCAL1_CFG_3_MASK, GTYE3_CH_CKCAL1_CFG_3_LSB, 0x0000},
    {GTYE3_CH_CKCAL2_CFG_0_ADDR, GTYE3_CH_CKCAL2_CFG_0_MASK, GTYE3_CH_CKCAL2_CFG_0_LSB, 0xC0C0},
    {GTYE3_CH_CKCAL2_CFG_1_ADDR, GTYE3_CH_CKCAL2_CFG_1_MASK, GTYE3_CH_CKCAL2_CFG_1_LSB, 0x80C0},
    {GTYE3_CH_CKCAL_RSVD1_ADDR, GTYE3_CH_CKCAL_RSVD1_MASK, GTYE3_CH_CKCAL_RSVD1_LSB, 0x0400},
    {GTYE3_CH_PMA_RSV0_ADDR, GTYE3_CH_PMA_RSV0_MASK, GTYE3_CH_PMA_RSV0_LSB, 0x2104},
    {GTYE3_CH_PMA_RSV1_ADDR, GTYE3_CH_PMA_RSV1_MASK, GTYE3_CH_PMA_RSV1_LSB, 0x505A},
    {GTYE3_CH_PREIQ_FREQ_BST_ADDR, GTYE3_CH_PREIQ_FREQ_BST_MASK, GTYE3_CH_PREIQ_FREQ_BST_LSB, 0x0000},
    {GTYE3_CH_RXCDR_CFG2_GEN3_ADDR, GTYE3_CH_RXCDR_CFG2_GEN3_MASK, GTYE3_CH_RXCDR_CFG2_GEN3_LSB, 0x0265},
    {GTYE3_CH_RXCDR_CFG2_ADDR, GTYE3_CH_RXCDR_CFG2_MASK, GTYE3_CH_RXCDR_CFG2_LSB, 0x0265},
    {GTYE3_CH_RXPI_CFG_ADDR, GTYE3_CH_RXPI_CFG_MASK, GTYE3_CH_RXPI_CFG_LSB, 0x0202},
    {GTYE3_CH_RX_DFE_KL_LPM_KH_CFG0_ADDR, GTYE3_CH_RX_DFE_KL_LPM_KH_CFG0_MASK, GTYE3_CH_RX_DFE_KL_LPM_KH_CFG0_LSB, 0x0003},
    {GTYE3_CH_RX_DFE_KL_LPM_KL_CFG0_ADDR, GTYE3_CH_RX_DFE_KL_LPM_KL_CFG0_MASK, GTYE3_CH_RX_DFE_KL_LPM_KL_CFG0_LSB, 0x0003},
    {GTYE3_CH_RX_PROGDIV_CFG_ADDR, GTYE3_CH_RX_PROGDIV_CFG_MASK, GTYE3_CH_RX_PROGDIV_CFG_LSB, GTYE3_CH_RX_PROGDIV_CFG_33},
    {GTYE3_CH_RX_PROGDIV_RATE_ADDR, GTYE3_CH_RX_PROGDIV_RATE_MASK, GTYE3_CH_RX_PROGDIV_RATE_LSB, GTYE3_CH_RX_PROGDIV_RATE_FULL},
    {GTYE3_CH_RX_WIDEMODE_CDR_ADDR, GTYE3_CH_RX_WIDEMODE_CDR_MASK, GTYE3_CH_RX_WIDEMODE_CDR_LSB, 0x0002},
    {GTYE3_CH_RX_XMODE_SEL_ADDR, GTYE3_CH_RX_XMODE_SEL_MASK, GTYE3_CH_RX_XMODE_SEL_LSB, 0x0001},
    {GTYE3_CH_TXPI_CFG3_ADDR, GTYE3_CH_TXPI_CFG3_MASK, GTYE3_CH_TXPI_CFG3_LSB, 0x0001},
    {GTYE3_CH_TXPI_CFG4_ADDR, GTYE3_CH_TXPI_CFG4_MASK, GTYE3_CH_TXPI_CFG4_LSB, 0x0001},
    {GTYE3_CH_TX_PI_BIASSET_ADDR, GTYE3_CH_TX_PI_BIASSET_MASK, GTYE3_CH_TX_PI_BIASSET_LSB, 0x0001},
    {GTYE3_CH_TX_PROGDIV_CFG_ADDR, GTYE3_CH_TX_PROGDIV_CFG_MASK, GTYE3_CH_TX_PROGDIV_CFG_LSB, GTYE3_CH_TX_PROGDIV_CFG_33},
    {GTYE3_CH_TX_PROGDIV_RATE_ADDR, GTYE3_CH_TX_PROGDIV_RATE_MASK, GTYE3_CH_TX_PROGDIV_RATE_LSB, GTYE3_CH_TX_PROGDIV_RATE_FULL},
    {0, 0, 0, 0}
};

static const struct gt_reg_val gtye3_ch_preset_10g_dfe_regs[] = {
    {GTYE3_CH_RXDFELPM_KL_CFG1_ADDR, GTYE3_CH_RXDFELPM_KL_CFG1_MASK, GTYE3_CH_RXDFELPM_KL_CFG1_LSB, 0x0002},
    {GTYE3_CH_RXPI_CFG_ADDR, GTYE3_CH_RXPI_CFG_MASK, GTYE3_CH_RXPI_CFG_LSB, 0x0202},
    {GTYE3_CH_RX_DFE_AGC_CFG1_ADDR, GTYE3_CH_RX_DFE_AGC_CFG1_MASK, GTYE3_CH_RX_DFE_AGC_CFG1_LSB, 0x0004},
    {GTYE3_CH_TXPI_CFG0_ADDR, GTYE3_CH_TXPI_CFG0_MASK, GTYE3_CH_TXPI_CFG0_LSB, 0x0000},
    {GTYE3_CH_TXPI_CFG1_ADDR, GTYE3_CH_TXPI_CFG1_MASK, GTYE3_CH_TXPI_CFG1_LSB, 0x0000},
    {GTYE3_CH_TXPI_CFG2_ADDR, GTYE3_CH_TXPI_CFG2_MASK, GTYE3_CH_TXPI_CFG2_LSB, 0x0000},
    {GTYE3_CH_TXPI_CFG5_ADDR, GTYE3_CH_TXPI_CFG5_MASK, GTYE3_CH_TXPI_CFG5_LSB, 0x0000},
    {GTYE3_CH_TX_PI_CFG0_ADDR, GTYE3_CH_TX_PI_CFG0_MASK, GTYE3_CH_TX_PI_CFG0_LSB, 0x0000},
    {0, 0, 0, 0}
};

static const struct gt_reg_val gtye3_ch_preset_10g_lpm_regs[] = {
    {GTYE3_CH_RXDFELPM_KL_CFG1_ADDR, GTYE3_CH_RXDFELPM_KL_CFG1_MASK, GTYE3_CH_RXDFELPM_KL_CFG1_LSB, 0x00E2},
    {GTYE3_CH_RXPI_CFG_ADDR, GTYE3_CH_RXPI_CFG_MASK, GTYE3_CH_RXPI_CFG_LSB, 0x566A},
    {GTYE3_CH_RX_DFE_AGC_CFG1_ADDR, GTYE3_CH_RX_DFE_AGC_CFG1_MASK, GTYE3_CH_RX_DFE_AGC_CFG1_LSB, 0x0002},
    {GTYE3_CH_TXPI_CFG0_ADDR, GTYE3_CH_TXPI_CFG0_MASK, GTYE3_CH_TXPI_CFG0_LSB, 0x0001},
    {GTYE3_CH_TXPI_CFG1_ADDR, GTYE3_CH_TXPI_CFG1_MASK, GTYE3_CH_TXPI_CFG1_LSB, 0x0001},
    {GTYE3_CH_TXPI_CFG2_ADDR, GTYE3_CH_TXPI_CFG2_MASK, GTYE3_CH_TXPI_CFG2_LSB, 0x0001},
    {GTYE3_CH_TXPI_CFG5_ADDR, GTYE3_CH_TXPI_CFG5_MASK, GTYE3_CH_TXPI_CFG5_LSB, 0x0003},
    {GTYE3_CH_TX_PI_CFG0_ADDR, GTYE3_CH_TX_PI_CFG0_MASK, GTYE3_CH_TX_PI_CFG0_LSB, 0x0002},
    {0, 0, 0, 0}
};

static const struct gt_reg_val gtye3_ch_preset_25g_baser_64_regs[] = {
    {GTYE3_CH_CH_HSPMUX_ADDR, GTYE3_CH_CH_HSPMUX_MASK, GTYE3_CH_CH_HSPMUX_LSB, 0xB6B6},
    {GTYE3_CH_CKCAL1_CFG_3_ADDR, GTYE3_CH_CKCAL1_CFG_3_MASK, GTYE3_CH_CKCAL1_CFG_3_LSB, 0x0007},
    {GTYE3_CH_CKCAL2_CFG_0_ADDR, GTYE3_CH_CKCAL2_CFG_0_MASK, GTYE3_CH_CKCAL2_CFG_0_LSB, 0x4040},
    {GTYE3_CH_CKCAL2_CFG_1_ADDR, GTYE3_CH_CKCAL2_CFG_1_MASK, GTYE3_CH_CKCAL2_CFG_1_LSB, 0x0040},
    {GTYE3_CH_CKCAL_RSVD1_ADDR, GTYE3_CH_CKCAL_RSVD1_MASK, GTYE3_CH_CKCAL_RSVD1_LSB, 0x0000},
    {GTYE3_CH_PMA_RSV0_ADDR, GTYE3_CH_PMA_RSV0_MASK, GTYE3_CH_PMA_RSV0_LSB, 0x2116},
    {GTYE3_CH_PMA_RSV1_ADDR, GTYE3_CH_PMA_RSV1_MASK, GTYE3_CH_PMA_RSV1_LSB, 0x504A},
    {GTYE3_CH_PREIQ_FREQ_BST_ADDR, GTYE3_CH_PREIQ_FREQ_BST_MASK, GTYE3_CH_PREIQ_FREQ_BST_LSB, 0x0002},
    {GTYE3_CH_RXCDR_CFG2_GEN3_ADDR, GTYE3_CH_RXCDR_CFG2_GEN3_MASK, GTYE3_CH_RXCDR_CFG2_GEN3_LSB, 0x01E9},
    {GTYE3_CH_RXCDR_CFG2_ADDR, GTYE3_CH_RXCDR_CFG2_MASK, GTYE3_CH_RXCDR_CFG2_LSB, 0x01E9},
    {GTYE3_CH_RXPI_CFG_ADDR, GTYE3_CH_RXPI_CFG_MASK, GTYE3_CH_RXPI_CFG_LSB, 0x0006},
    {GTYE3_CH_RX_DFE_KL_LPM_KH_CFG0_ADDR, GTYE3_CH_RX_DFE_KL_LPM_KH_CFG0_MASK, GTYE3_CH_RX_DFE_KL_LPM_KH_CFG0_LSB, 0x0001},
    {GTYE3_CH_RX_DFE_KL_LPM_KL_CFG0_ADDR, GTYE3_CH_RX_DFE_KL_LPM_KL_CFG0_MASK, GTYE3_CH_RX_DFE_KL_LPM_KL_CFG0_LSB, 0x0001},
    {GTYE3_CH_RX_PROGDIV_CFG_ADDR, GTYE3_CH_RX_PROGDIV_CFG_MASK, GTYE3_CH_RX_PROGDIV_CFG_LSB, GTYE3_CH_RX_PROGDIV_CFG_16P5},
    {GTYE3_CH_RX_PROGDIV_RATE_ADDR, GTYE3_CH_RX_PROGDIV_RATE_MASK, GTYE3_CH_RX_PROGDIV_RATE_LSB, GTYE3_CH_RX_PROGDIV_RATE_HALF},
    {GTYE3_CH_RX_WIDEMODE_CDR_ADDR, GTYE3_CH_RX_WIDEMODE_CDR_MASK, GTYE3_CH_RX_WIDEMODE_CDR_LSB, 0x0000},
    {GTYE3_CH_RX_XMODE_SEL_ADDR, GTYE3_CH_RX_XMODE_SEL_MASK, GTYE3_CH_RX_XMODE_SEL_LSB, 0x0000},
    {GTYE3_CH_TXPI_CFG3_ADDR, GTYE3_CH_TXPI_CFG3_MASK, GTYE3_CH_TXPI_CFG3_LSB, 0x0000},
    {GTYE3_CH_TXPI_CFG4_ADDR, GTYE3_CH_TXPI_CFG4_MASK, GTYE3_CH_TXPI_CFG4_LSB, 0x0000},
    {GTYE3_CH_TX_PI_BIASSET_ADDR, GTYE3_CH_TX_PI_BIASSET_MASK, GTYE3_CH_TX_PI_BIASSET_LSB, 0x0000},
    {GTYE3_CH_TX_PROGDIV_CFG_ADDR, GTYE3_CH_TX_PROGDIV_CFG_MASK, GTYE3_CH_TX_PROGDIV_CFG_LSB, GTYE3_CH_TX_PROGDIV_CFG_16P5},
    {GTYE3_CH_TX_PROGDIV_RATE_ADDR, GTYE3_CH_TX_PROGDIV_RATE_MASK, GTYE3_CH_TX_PROGDIV_RATE_LSB, GTYE3_CH_TX_PROGDIV_RATE_HALF},
    {0, 0, 0, 0}
};

static const struct gt_reg_val gtye3_ch_preset_25g_dfe_regs[] = {
    {GTYE3_CH_RXDFELPM_KL_CFG1_ADDR, GTYE3_CH_RXDFELPM_KL_CFG1_MASK, GTYE3_CH_RXDFELPM_KL_CFG1_LSB, 0x0002},
    {GTYE3_CH_RX_DFE_AGC_CFG1_ADDR, GTYE3_CH_RX_DFE_AGC_CFG1_MASK, GTYE3_CH_RX_DFE_AGC_CFG1_LSB, 0x0004},
    {GTYE3_CH_TXPI_CFG0_ADDR, GTYE3_CH_TXPI_CFG0_MASK, GTYE3_CH_TXPI_CFG0_LSB, 0x0000},
    {GTYE3_CH_TXPI_CFG1_ADDR, GTYE3_CH_TXPI_CFG1_MASK, GTYE3_CH_TXPI_CFG1_LSB, 0x0000},
    {GTYE3_CH_TXPI_CFG2_ADDR, GTYE3_CH_TXPI_CFG2_MASK, GTYE3_CH_TXPI_CFG2_LSB, 0x0000},
    {GTYE3_CH_TXPI_CFG5_ADDR, GTYE3_CH_TXPI_CFG5_MASK, GTYE3_CH_TXPI_CFG5_LSB, 0x0000},
    {GTYE3_CH_TX_PI_CFG0_ADDR, GTYE3_CH_TX_PI_CFG0_MASK, GTYE3_CH_TX_PI_CFG0_LSB, 0x0000},
    {0, 0, 0, 0}
};

static const struct gt_reg_val gtye3_ch_preset_25g_lpm_regs[] = {
    {GTYE3_CH_RXDFELPM_KL_CFG1_ADDR, GTYE3_CH_RXDFELPM_KL_CFG1_MASK, GTYE3_CH_RXDFELPM_KL_CFG1_LSB, 0x00E2},
    {GTYE3_CH_RX_DFE_AGC_CFG1_ADDR, GTYE3_CH_RX_DFE_AGC_CFG1_MASK, GTYE3_CH_RX_DFE_AGC_CFG1_LSB, 0x0002},
    {GTYE3_CH_TXPI_CFG0_ADDR, GTYE3_CH_TXPI_CFG0_MASK, GTYE3_CH_TXPI_CFG0_LSB, 0x0000},
    {GTYE3_CH_TXPI_CFG1_ADDR, GTYE3_CH_TXPI_CFG1_MASK, GTYE3_CH_TXPI_CFG1_LSB, 0x0000},
    {GTYE3_CH_TXPI_CFG2_ADDR, GTYE3_CH_TXPI_CFG2_MASK, GTYE3_CH_TXPI_CFG2_LSB, 0x0000},
    {GTYE3_CH_TXPI_CFG5_ADDR, GTYE3_CH_TXPI_CFG5_MASK, GTYE3_CH_TXPI_CFG5_LSB, 0x0000},
    {GTYE3_CH_TX_PI_CFG0_ADDR, GTYE3_CH_TX_PI_CFG0_MASK, GTYE3_CH_TX_PI_CFG0_LSB, 0x0000},
    {0, 0, 0, 0}
};

static const uint32_t gtye3_ch_presets[] = {
    GT_PRESET_10G_DFE,
    GT_PRESET_10G_LPM,
    GT_PRESET_25G_DFE,
    GT_PRESET_25G_LPM,
    0
};

static int gtye3_ch_get_available_presets(struct gt_ch *ch, const uint32_t **presets)
{
    *presets = gtye3_ch_presets;
    return 0;
}

int gtye3_ch_load_preset(struct gt_ch *ch, uint32_t preset)
{
    struct gtye3_quad_priv *priv = ch->quad->priv;

    if (preset == GT_PRESET_10G_DFE || preset == GT_PRESET_10G_LPM)
    {
        if (priv->qpll0_25g)
            gtye3_pll_set_qpll1_pd(ch->pll, 0);

        gtye3_ch_set_tx_reset(ch, 1);
        gtye3_ch_set_rx_reset(ch, 1);

        if (priv->qpll0_25g) 
        {
            gtye3_ch_set_tx_qpll_sel(ch, 1);
            gtye3_ch_set_rx_qpll_sel(ch, 1);
        }

        gt_ch_reg_write_multiple(ch, gtye3_ch_preset_10g_baser_64_regs);

        if (preset == GT_PRESET_10G_DFE)
        {
            gt_ch_reg_write_multiple(ch, gtye3_ch_preset_10g_dfe_regs);
            gtye3_ch_set_rx_lpm_en(ch, 0);
        }
        else
        {
            gt_ch_reg_write_multiple(ch, gtye3_ch_preset_10g_lpm_regs);
            gtye3_ch_set_rx_lpm_en(ch, 1);
        }

        gtye3_ch_set_tx_reset(ch, 0);
        gtye3_ch_set_rx_reset(ch, 0);

        return 0;
    }

    if ((preset == GT_PRESET_25G_DFE || preset == GT_PRESET_25G_LPM) && priv->qpll0_25g)
    {
        gtye3_ch_set_tx_reset(ch, 1);
        gtye3_ch_set_rx_reset(ch, 1);

        gtye3_ch_set_tx_qpll_sel(ch, 0);
        gtye3_ch_set_rx_qpll_sel(ch, 0);

        gt_ch_reg_write_multiple(ch, gtye3_ch_preset_25g_baser_64_regs);

        if (preset == GT_PRESET_25G_DFE)
        {
            gt_ch_reg_write_multiple(ch, gtye3_ch_preset_25g_dfe_regs);
            gtye3_ch_set_rx_lpm_en(ch, 0);
        }
        else
        {
            gt_ch_reg_write_multiple(ch, gtye3_ch_preset_25g_lpm_regs);
            gtye3_ch_set_rx_lpm_en(ch, 1);
        }

        gtye3_ch_set_tx_reset(ch, 0);
        gtye3_ch_set_rx_reset(ch, 0);

        return 0;
    }

    return -1;
}

static int gtye3_ch_eyescan_start(struct gt_ch *ch, struct gt_eyescan_params *params)
{
    struct gtye3_ch_priv *priv = ch->priv;
    uint32_t val;

    uint32_t error_count;
    uint32_t sample_count;
    uint64_t bit_count;
    float ber;

    priv->eyescan_running = 0;

    gtye3_ch_get_rx_lpm_en(ch, &val);
    priv->dfe_en = !val;

    gtye3_ch_get_rx_data_width(ch, &priv->rx_data_width);
    gtye3_ch_get_rx_int_data_width(ch, &priv->rx_int_data_width);

    priv->prescale = 0;

    for (priv->prescale = 0; priv->prescale < 32; priv->prescale++)
    {
        if (((uint64_t)0xffff * (uint64_t)priv->rx_int_data_width) << (1+priv->prescale) >= params->target_bit_count)
            break;
    }

    params->target_bit_count = ((uint64_t)0xffff * (uint64_t)priv->rx_int_data_width) << (1+priv->prescale);
    params->h_range = 0;

    priv->h_start = params->h_start;
    priv->h_stop = params->h_stop;
    priv->h_step = params->h_step;
    priv->v_range = params->v_range;
    priv->v_start = params->v_start;
    priv->v_stop = params->v_stop;
    priv->v_step = params->v_step;

    gtye3_ch_set_es_control(ch, 0x00);

    gtye3_ch_set_es_prescale(ch, 4);
    gtye3_ch_set_es_errdet_en(ch, 1);

    gtye3_ch_set_es_qual_mask_clear(ch);
    gtye3_ch_set_es_sdata_mask_width(ch, priv->rx_int_data_width);

    gtye3_ch_set_rx_eyescan_vs_range(ch, priv->v_range);

    gtye3_ch_set_es_horz_offset(ch, 0x800);
    gtye3_ch_set_rx_eyescan_vs_neg_dir(ch, 0);
    gtye3_ch_set_rx_eyescan_vs_code(ch, 0);
    gtye3_ch_set_rx_eyescan_vs_ut_sign(ch, 0);

    gtye3_ch_set_es_eye_scan_en(ch, 1);

    gtye3_ch_rx_pma_reset(ch);

    for (int ber_tries = 0; ber_tries < 10; ber_tries++)
    {
        for (int reset_tries = 0; reset_tries < 30; reset_tries++)
        {
            gtye3_ch_get_rx_reset_done(ch, &val);
            if (val)
                break;
            usleep(100000);
        }

        if (!val)
        {
            fprintf(stderr, "Error: channel stuck in reset\n");
            return -1;
        }

        usleep(100000);

        // check for lock
        gtye3_ch_set_es_control(ch, 0x01);

        for (int wait_tries = 0; wait_tries < 30; wait_tries++)
        {
            gtye3_ch_get_es_control_status(ch, &val);
            if (val & 1)
                break;
            usleep(100000);
        }

        if (!(val & 1))
        {
            fprintf(stderr, "Error: eye scan did not finish (%d)\n", val);
            return -1;
        }

        gtye3_ch_set_es_control(ch, 0x00);

        gtye3_ch_get_es_error_count(ch, &error_count);
        gtye3_ch_get_es_sample_count(ch, &sample_count);
        bit_count = ((uint64_t)sample_count * (uint64_t)priv->rx_int_data_width) << (1+4);

        ber = (float)error_count / (float)bit_count;

        if (ber < 0.01)
            break;

        printf("High BER (%02f), resetting eye scan logic\n", ber);

        gtye3_ch_set_es_horz_offset(ch, 0x880);
        gtye3_ch_set_eyescan_reset(ch, 1);
        gtye3_ch_set_es_horz_offset(ch, 0x800);
        gtye3_ch_set_eyescan_reset(ch, 0);
    }

    if (ber > 0.01)
    {
        fprintf(stderr, "Error: High BER, alignment failed\n");
        return -1;
    }

    // set up for measurement
    priv->h_offset = priv->h_start;
    priv->v_offset = priv->v_start;
    priv->ut_sign = 0;

    gtye3_ch_set_es_control(ch, 0x00);
    gtye3_ch_set_es_prescale(ch, priv->prescale);
    gtye3_ch_set_es_errdet_en(ch, 1);
    gtye3_ch_set_es_horz_offset(ch, (priv->h_offset & 0x7ff) | 0x800);
    gtye3_ch_set_rx_eyescan_vs_neg_dir(ch, (priv->v_offset < 0));
    gtye3_ch_set_rx_eyescan_vs_code(ch, priv->v_offset < 0 ? -priv->v_offset : priv->v_offset);
    gtye3_ch_set_rx_eyescan_vs_ut_sign(ch, priv->ut_sign);

    // start measurement
    gtye3_ch_set_es_control(ch, 0x01);

    priv->eyescan_running = 1;

    return 0;
}

static int gtye3_ch_eyescan_step(struct gt_ch *ch, struct gt_eyescan_point *point)
{
    struct gtye3_ch_priv *priv = ch->priv;
    uint32_t val;

    uint32_t error_count;
    uint32_t sample_count;
    uint64_t bit_count;

    int restart = 0;

    if (!priv->eyescan_running)
        return 0;

    gtye3_ch_get_es_control_status(ch, &val);
    if (!(val & 1))
        return 2;

    gtye3_ch_set_es_control(ch, 0x00);

    gtye3_ch_get_es_error_count(ch, &error_count);
    gtye3_ch_get_es_sample_count(ch, &sample_count);
    bit_count = ((uint64_t)sample_count * (uint64_t)priv->rx_int_data_width) << (1+priv->prescale);

    point->error_count = error_count;
    point->bit_count = bit_count;
    point->x = priv->h_offset;
    point->y = priv->v_offset;
    point->ut_sign = priv->ut_sign;

    restart = 0;

    if (!priv->ut_sign && priv->dfe_en)
    {
        priv->ut_sign = 1;
        restart = 1;
    }
    else
    {
        priv->ut_sign = 0;
    }

    gtye3_ch_set_rx_eyescan_vs_ut_sign(ch, priv->ut_sign);

    if (restart)
    {
        gtye3_ch_set_es_control(ch, 0x01);
        return 1;
    }

    if (priv->v_offset < priv->v_stop)
    {
        priv->v_offset += priv->v_step;
        restart = 1;
    }
    else
    {
        priv->v_offset = priv->v_start;
    }

    gtye3_ch_set_rx_eyescan_vs_neg_dir(ch, (priv->v_offset < 0));
    gtye3_ch_set_rx_eyescan_vs_code(ch, priv->v_offset < 0 ? -priv->v_offset : priv->v_offset);

    if (restart)
    {
        gtye3_ch_set_es_control(ch, 0x01);
        return 1;
    }

    if (priv->h_offset < priv->h_stop)
    {
        priv->h_offset += priv->h_step;
        restart = 1;
    }
    else
    {
        // done
        priv->eyescan_running = 0;
        return 1;
    }

    gtye3_ch_set_es_horz_offset(ch, (priv->h_offset & 0x7ff) | 0x800);

    if (restart)
    {
        gtye3_ch_set_es_control(ch, 0x01);
        return 1;
    }

    priv->eyescan_running = 0;
    return 0;
}

const struct gt_ch_ops gtye3_gt_ch_ops = {
    .get_tx_reset = gtye3_ch_get_tx_reset,
    .set_tx_reset = gtye3_ch_set_tx_reset,
    .tx_reset = gtye3_ch_tx_reset,
    .get_rx_reset = gtye3_ch_get_rx_reset,
    .set_rx_reset = gtye3_ch_set_rx_reset,
    .rx_reset = gtye3_ch_rx_reset,
    .get_tx_data_width = gtye3_ch_get_tx_data_width,
    .get_tx_int_data_width = gtye3_ch_get_tx_int_data_width,
    .get_rx_data_width = gtye3_ch_get_rx_data_width,
    .get_rx_int_data_width = gtye3_ch_get_rx_int_data_width,
    .get_available_presets = gtye3_ch_get_available_presets,
    .load_preset = gtye3_ch_load_preset,
    .eyescan_start = gtye3_ch_eyescan_start,
    .eyescan_step = gtye3_ch_eyescan_step
};

static int gtye3_ch_init(struct gt_ch *ch)
{
    struct gtye3_ch_priv *priv = calloc(1, sizeof(struct gtye3_ch_priv));
    if (!priv)
        return -1;

    ch->priv = priv;

    return 0;
}

int gtye3_quad_init(struct gt_quad *quad)
{
    uint32_t val;
    struct gtye3_quad_priv *priv = calloc(1, sizeof(struct gtye3_quad_priv));
    if (!priv)
        return -1;

    quad->priv = priv;
    quad->type = "GTYE3";

    gtye3_pll_get_qpll0clkout_rate(&quad->pll, &val);
    priv->qpll0_25g = val == GTYE3_COM_QPLL0CLKOUT_RATE_FULL;

    for (int n = 0; n < quad->ch_count; n++)
    {
        quad->ch[n].quad = quad;
        quad->ch[n].pll = &quad->pll;
        quad->ch[n].ops = &gtye3_gt_ch_ops;
        quad->ch[n].index = n;

        gtye3_ch_init(&quad->ch[n]);
    }

    return 0;
}

const struct gt_quad_ops gtye3_gt_quad_ops = {
    .init = gtye3_quad_init
};
