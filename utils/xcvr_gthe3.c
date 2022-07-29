/*

Copyright 2022, The Regents of the University of California.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

   1. Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.

   2. Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE REGENTS OF THE UNIVERSITY OF CALIFORNIA ''AS
IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE REGENTS OF THE UNIVERSITY OF CALIFORNIA OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of The Regents of the University of California.

*/

#include <stdlib.h>
#include <stdio.h>
#include "xcvr_gthe3.h"

// signals
int gthe3_pll_qpll0_reset(struct gt_pll *pll)
{
    int ret = 0;

    ret = gthe3_pll_set_qpll0_reset(pll, 1);

    if (ret)
        return ret;

    return gthe3_pll_set_qpll0_reset(pll, 0);
}

int gthe3_pll_qpll1_reset(struct gt_pll *pll)
{
    int ret = 0;

    ret = gthe3_pll_set_qpll1_reset(pll, 1);

    if (ret)
        return ret;

    return gthe3_pll_set_qpll1_reset(pll, 0);
}

int gthe3_ch_tx_reset(struct gt_ch *ch)
{
    int ret = 0;

    ret = gthe3_ch_set_tx_reset(ch, 1);

    if (ret)
        return ret;

    return gthe3_ch_set_tx_reset(ch, 0);
}

int gthe3_ch_tx_pma_reset(struct gt_ch *ch)
{
    int ret = 0;

    ret = gthe3_ch_set_tx_pma_reset(ch, 1);

    if (ret)
        return ret;

    return gthe3_ch_set_tx_pma_reset(ch, 0);
}

int gthe3_ch_tx_pcs_reset(struct gt_ch *ch)
{
    int ret = 0;

    ret = gthe3_ch_set_tx_pcs_reset(ch, 1);

    if (ret)
        return ret;

    return gthe3_ch_set_tx_pcs_reset(ch, 0);
}

int gthe3_ch_rx_reset(struct gt_ch *ch)
{
    int ret = 0;

    ret = gthe3_ch_set_rx_reset(ch, 1);

    if (ret)
        return ret;

    return gthe3_ch_set_rx_reset(ch, 0);
}

int gthe3_ch_rx_pma_reset(struct gt_ch *ch)
{
    int ret = 0;

    ret = gthe3_ch_set_rx_pma_reset(ch, 1);

    if (ret)
        return ret;

    return gthe3_ch_set_rx_pma_reset(ch, 0);
}

int gthe3_ch_rx_pcs_reset(struct gt_ch *ch)
{
    int ret = 0;

    ret = gthe3_ch_set_rx_pcs_reset(ch, 1);

    if (ret)
        return ret;

    return gthe3_ch_set_rx_pcs_reset(ch, 0);
}

int gthe3_ch_rx_dfe_lpm_reset(struct gt_ch *ch)
{
    int ret = 0;

    ret = gthe3_ch_set_rx_dfe_lpm_reset(ch, 1);

    if (ret)
        return ret;

    return gthe3_ch_set_rx_dfe_lpm_reset(ch, 0);
}

int gthe3_ch_eyescan_reset(struct gt_ch *ch)
{
    int ret = 0;

    ret = gthe3_ch_set_eyescan_reset(ch, 1);

    if (ret)
        return ret;

    return gthe3_ch_set_eyescan_reset(ch, 0);
}

// RX
int gthe3_ch_get_rx_data_width(struct gt_ch *ch, uint32_t *val)
{
    int ret = 0;
    uint32_t dw;

    ret = gthe3_ch_get_rx_data_width_raw(ch, &dw);
    if (ret)
        return ret;

    *val = (8*(1 << (dw >> 1)) * (4 + (dw & 1))) >> 2;
    return 0;
}

int gthe3_ch_get_rx_int_data_width(struct gt_ch *ch, uint32_t *val)
{
    int ret = 0;
    uint32_t dw, idw;

    ret = gthe3_ch_get_rx_data_width_raw(ch, &dw);
    if (ret)
        return ret;

    ret = gthe3_ch_get_rx_int_data_width_raw(ch, &idw);
    if (ret)
        return ret;

    *val = (16*(1 << idw) * (4 + (dw & 1))) >> 2;
    return 0;
}

int gthe3_ch_set_es_qual_mask(struct gt_ch *ch, uint8_t *mask)
{
    int ret = 0;

    for (int k = 0; k < 5; k++)
    {
        ret = gt_ch_reg_write(ch, GTHE3_CH_ES_QUAL_MASK0_ADDR+k, mask[2*k+0] | (mask[2*k+1] << 8));
        if (ret)
            return ret;
    }

    return 0;
}

int gthe3_ch_set_es_qual_mask_clear(struct gt_ch *ch)
{
    int ret = 0;

    for (int k = 0; k < 5; k++)
    {
        ret = gt_ch_reg_write(ch, GTHE3_CH_ES_QUAL_MASK0_ADDR+k, 0xffff);
        if (ret)
            return ret;
    }

    return 0;
}

int gthe3_ch_set_es_sdata_mask(struct gt_ch *ch, uint8_t *mask)
{
    int ret = 0;

    for (int k = 0; k < 5; k++)
    {
        ret = gt_ch_reg_write(ch, GTHE3_CH_ES_SDATA_MASK0_ADDR+k, mask[2*k+0] | (mask[2*k+1] << 8));
        if (ret)
            return ret;
    }

    return 0;
}

int gthe3_ch_set_es_sdata_mask_width(struct gt_ch *ch, int width)
{
    int ret = 0;

    for (int k = 0; k < 5; k++)
    {
        int shift = width - (40 - ((k+1)*16));
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

        ret = gt_ch_reg_write(ch, GTHE3_CH_ES_SDATA_MASK0_ADDR+k, mask);
        if (ret)
            return ret;
    }

    return 0;
}

int gthe3_ch_get_rx_prbs_error_count(struct gt_ch *ch, uint32_t *val)
{
    int ret = 0;
    uint32_t v1, v2;

    ret = gt_ch_reg_read(ch, GTHE3_CH_RX_PRBS_ERR_CNT_L_ADDR | (ch->index << 17), &v1);
    if (ret)
        return ret;

    ret = gt_ch_reg_read(ch, GTHE3_CH_RX_PRBS_ERR_CNT_H_ADDR | (ch->index << 17), &v2);
    if (ret)
        return ret;

    *val = v1 | (v2 << 16);
    return 0;
}

// TX
int gthe3_ch_get_tx_data_width(struct gt_ch *ch, uint32_t *val)
{
    int ret = 0;
    uint32_t dw;

    ret = gthe3_ch_get_tx_data_width_raw(ch, &dw);
    if (ret)
        return ret;

    *val = (8*(1 << (dw >> 1)) * (4 + (dw & 1))) >> 2;
    return 0;
}

int gthe3_ch_get_tx_int_data_width(struct gt_ch *ch, uint32_t *val)
{
    int ret = 0;
    uint32_t dw, idw;

    ret = gthe3_ch_get_tx_data_width_raw(ch, &dw);
    if (ret)
        return ret;

    ret = gthe3_ch_get_tx_int_data_width_raw(ch, &idw);
    if (ret)
        return ret;

    *val = (16*(1 << idw) * (4 + (dw & 1))) >> 2;
    return 0;
}

struct gthe3_ch_priv {
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

static const struct gt_reg_val gthe3_ch_preset_10g_dfe_regs[] = {
    {GTHE3_CH_CPLL_CFG2_ADDR, GTHE3_CH_CPLL_CFG2_MASK, GTHE3_CH_CPLL_CFG2_LSB, 0x5007},
    {GTHE3_CH_RXDFELPM_KL_CFG1_ADDR, GTHE3_CH_RXDFELPM_KL_CFG1_MASK, GTHE3_CH_RXDFELPM_KL_CFG1_LSB, 0x0002},
    {GTHE3_CH_RXPI_CFG0_ADDR, GTHE3_CH_RXPI_CFG0_MASK, GTHE3_CH_RXPI_CFG0_LSB, 0x0000},
    {GTHE3_CH_RXPI_CFG1_ADDR, GTHE3_CH_RXPI_CFG1_MASK, GTHE3_CH_RXPI_CFG1_LSB, 0x0000},
    {GTHE3_CH_RXPI_CFG2_ADDR, GTHE3_CH_RXPI_CFG2_MASK, GTHE3_CH_RXPI_CFG2_LSB, 0x0000},
    {GTHE3_CH_RXPI_CFG3_ADDR, GTHE3_CH_RXPI_CFG3_MASK, GTHE3_CH_RXPI_CFG3_LSB, 0x0000},
    {GTHE3_CH_RXPI_CFG6_ADDR, GTHE3_CH_RXPI_CFG6_MASK, GTHE3_CH_RXPI_CFG6_LSB, 0x0000},
    {GTHE3_CH_RX_DFE_AGC_CFG1_ADDR, GTHE3_CH_RX_DFE_AGC_CFG1_MASK, GTHE3_CH_RX_DFE_AGC_CFG1_LSB, 0x0004},
    {GTHE3_CH_RX_DFE_KL_LPM_KH_CFG1_ADDR, GTHE3_CH_RX_DFE_KL_LPM_KH_CFG1_MASK, GTHE3_CH_RX_DFE_KL_LPM_KH_CFG1_LSB, 0x0004},
    {GTHE3_CH_RX_DFE_KL_LPM_KL_CFG1_ADDR, GTHE3_CH_RX_DFE_KL_LPM_KL_CFG1_MASK, GTHE3_CH_RX_DFE_KL_LPM_KL_CFG1_LSB, 0x0004},
    {GTHE3_CH_RX_SUM_IREF_TUNE_ADDR, GTHE3_CH_RX_SUM_IREF_TUNE_MASK, GTHE3_CH_RX_SUM_IREF_TUNE_LSB, 0x0000},
    {GTHE3_CH_RX_SUM_RES_CTRL_ADDR, GTHE3_CH_RX_SUM_RES_CTRL_MASK, GTHE3_CH_RX_SUM_RES_CTRL_LSB, 0x0000},
    {GTHE3_CH_TXPI_CFG0_ADDR, GTHE3_CH_TXPI_CFG0_MASK, GTHE3_CH_TXPI_CFG0_LSB, 0x0000},
    {GTHE3_CH_TXPI_CFG1_ADDR, GTHE3_CH_TXPI_CFG1_MASK, GTHE3_CH_TXPI_CFG1_LSB, 0x0000},
    {GTHE3_CH_TXPI_CFG2_ADDR, GTHE3_CH_TXPI_CFG2_MASK, GTHE3_CH_TXPI_CFG2_LSB, 0x0000},
    {GTHE3_CH_TXPI_CFG3_ADDR, GTHE3_CH_TXPI_CFG3_MASK, GTHE3_CH_TXPI_CFG3_LSB, 0x0001},
    {GTHE3_CH_TXPI_CFG5_ADDR, GTHE3_CH_TXPI_CFG5_MASK, GTHE3_CH_TXPI_CFG5_LSB, 0x0000},
    {0, 0, 0, 0}
};

static const struct gt_reg_val gthe3_ch_preset_10g_lpm_regs[] = {
    {GTHE3_CH_CPLL_CFG2_ADDR, GTHE3_CH_CPLL_CFG2_MASK, GTHE3_CH_CPLL_CFG2_LSB, 0x0007},
    {GTHE3_CH_RXDFELPM_KL_CFG1_ADDR, GTHE3_CH_RXDFELPM_KL_CFG1_MASK, GTHE3_CH_RXDFELPM_KL_CFG1_LSB, 0x0032},
    {GTHE3_CH_RXPI_CFG0_ADDR, GTHE3_CH_RXPI_CFG0_MASK, GTHE3_CH_RXPI_CFG0_LSB, 0x0001},
    {GTHE3_CH_RXPI_CFG1_ADDR, GTHE3_CH_RXPI_CFG1_MASK, GTHE3_CH_RXPI_CFG1_LSB, 0x0001},
    {GTHE3_CH_RXPI_CFG2_ADDR, GTHE3_CH_RXPI_CFG2_MASK, GTHE3_CH_RXPI_CFG2_LSB, 0x0001},
    {GTHE3_CH_RXPI_CFG3_ADDR, GTHE3_CH_RXPI_CFG3_MASK, GTHE3_CH_RXPI_CFG3_LSB, 0x0001},
    {GTHE3_CH_RXPI_CFG6_ADDR, GTHE3_CH_RXPI_CFG6_MASK, GTHE3_CH_RXPI_CFG6_LSB, 0x0003},
    {GTHE3_CH_RX_DFE_AGC_CFG1_ADDR, GTHE3_CH_RX_DFE_AGC_CFG1_MASK, GTHE3_CH_RX_DFE_AGC_CFG1_LSB, 0x0000},
    {GTHE3_CH_RX_DFE_KL_LPM_KH_CFG1_ADDR, GTHE3_CH_RX_DFE_KL_LPM_KH_CFG1_MASK, GTHE3_CH_RX_DFE_KL_LPM_KH_CFG1_LSB, 0x0000},
    {GTHE3_CH_RX_DFE_KL_LPM_KL_CFG1_ADDR, GTHE3_CH_RX_DFE_KL_LPM_KL_CFG1_MASK, GTHE3_CH_RX_DFE_KL_LPM_KL_CFG1_LSB, 0x0000},
    {GTHE3_CH_RX_SUM_IREF_TUNE_ADDR, GTHE3_CH_RX_SUM_IREF_TUNE_MASK, GTHE3_CH_RX_SUM_IREF_TUNE_LSB, 0x000C},
    {GTHE3_CH_RX_SUM_RES_CTRL_ADDR, GTHE3_CH_RX_SUM_RES_CTRL_MASK, GTHE3_CH_RX_SUM_RES_CTRL_LSB, 0x0003},
    {GTHE3_CH_TXPI_CFG0_ADDR, GTHE3_CH_TXPI_CFG0_MASK, GTHE3_CH_TXPI_CFG0_LSB, 0x0001},
    {GTHE3_CH_TXPI_CFG1_ADDR, GTHE3_CH_TXPI_CFG1_MASK, GTHE3_CH_TXPI_CFG1_LSB, 0x0001},
    {GTHE3_CH_TXPI_CFG2_ADDR, GTHE3_CH_TXPI_CFG2_MASK, GTHE3_CH_TXPI_CFG2_LSB, 0x0001},
    {GTHE3_CH_TXPI_CFG3_ADDR, GTHE3_CH_TXPI_CFG3_MASK, GTHE3_CH_TXPI_CFG3_LSB, 0x0000},
    {GTHE3_CH_TXPI_CFG5_ADDR, GTHE3_CH_TXPI_CFG5_MASK, GTHE3_CH_TXPI_CFG5_LSB, 0x0003},
    {0, 0, 0, 0}
};

static const uint32_t gthe3_ch_presets[] = {
    GT_PRESET_10G_DFE,
    GT_PRESET_10G_LPM,
    0
};

static int gthe3_ch_get_available_presets(struct gt_ch *ch, const uint32_t **presets)
{
    *presets = gthe3_ch_presets;
    return 0;
}

int gthe3_ch_load_preset(struct gt_ch *ch, uint32_t preset)
{
    if (preset == GT_PRESET_10G_DFE || preset == GT_PRESET_10G_LPM)
    {
        gthe3_ch_set_tx_reset(ch, 1);
        gthe3_ch_set_rx_reset(ch, 1);

        if (preset == GT_PRESET_10G_DFE)
        {
            gt_ch_reg_write_multiple(ch, gthe3_ch_preset_10g_dfe_regs);
            gthe3_ch_set_rx_lpm_en(ch, 0);
        }
        else
        {
            gt_ch_reg_write_multiple(ch, gthe3_ch_preset_10g_lpm_regs);
            gthe3_ch_set_rx_lpm_en(ch, 1);
        }

        gthe3_ch_set_tx_reset(ch, 0);
        gthe3_ch_set_rx_reset(ch, 0);

        return 0;
    }

    return -1;
}

static int gthe3_ch_eyescan_start(struct gt_ch *ch, struct gt_eyescan_params *params)
{
    struct gthe3_ch_priv *priv = ch->priv;
    uint32_t val;

    uint32_t error_count;
    uint32_t sample_count;
    uint64_t bit_count;
    float ber;

    priv->eyescan_running = 0;

    gthe3_ch_get_rx_lpm_en(ch, &val);
    priv->dfe_en = !val;

    gthe3_ch_get_rx_data_width(ch, &priv->rx_data_width);
    gthe3_ch_get_rx_int_data_width(ch, &priv->rx_int_data_width);

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

    gthe3_ch_set_es_control(ch, 0x00);

    gthe3_ch_set_es_prescale(ch, 4);
    gthe3_ch_set_es_errdet_en(ch, 1);

    gthe3_ch_set_es_qual_mask_clear(ch);
    gthe3_ch_set_es_sdata_mask_width(ch, priv->rx_int_data_width);

    gthe3_ch_set_rx_eyescan_vs_range(ch, priv->v_range);

    gthe3_ch_set_es_horz_offset(ch, 0x000);
    gthe3_ch_set_rx_eyescan_vs_neg_dir(ch, 0);
    gthe3_ch_set_rx_eyescan_vs_code(ch, 0);
    gthe3_ch_set_rx_eyescan_vs_ut_sign(ch, 0);

    gthe3_ch_set_es_eye_scan_en(ch, 1);

    gthe3_ch_rx_pma_reset(ch);

    for (int ber_tries = 0; ber_tries < 10; ber_tries++)
    {
        for (int reset_tries = 0; reset_tries < 30; reset_tries++)
        {
            gthe3_ch_get_rx_reset_done(ch, &val);
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
        gthe3_ch_set_es_control(ch, 0x01);

        for (int wait_tries = 0; wait_tries < 30; wait_tries++)
        {
            gthe3_ch_get_es_control_status(ch, &val);
            if (val & 1)
                break;
            usleep(100000);
        }

        if (!(val & 1))
        {
            fprintf(stderr, "Error: eye scan did not finish (%d)\n", val);
            return -1;
        }

        gthe3_ch_set_es_control(ch, 0x00);

        gthe3_ch_get_es_error_count(ch, &error_count);
        gthe3_ch_get_es_sample_count(ch, &sample_count);
        bit_count = ((uint64_t)sample_count * (uint64_t)priv->rx_int_data_width) << (1+4);

        ber = (float)error_count / (float)bit_count;

        if (ber < 0.01)
            break;

        printf("High BER (%02f), resetting eye scan logic\n", ber);

        gthe3_ch_set_es_horz_offset(ch, 0x880);
        gthe3_ch_set_eyescan_reset(ch, 1);
        gthe3_ch_set_es_horz_offset(ch, 0x800);
        gthe3_ch_set_eyescan_reset(ch, 0);
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

    gthe3_ch_set_es_control(ch, 0x00);
    gthe3_ch_set_es_prescale(ch, priv->prescale);
    gthe3_ch_set_es_errdet_en(ch, 1);
    gthe3_ch_set_es_horz_offset(ch, (priv->h_offset & 0x7ff) | (priv->h_offset < 0 ? 0x800 : 0x000));
    gthe3_ch_set_rx_eyescan_vs_neg_dir(ch, (priv->v_offset < 0));
    gthe3_ch_set_rx_eyescan_vs_code(ch, priv->v_offset < 0 ? -priv->v_offset : priv->v_offset);
    gthe3_ch_set_rx_eyescan_vs_ut_sign(ch, priv->ut_sign);

    // start measurement
    gthe3_ch_set_es_control(ch, 0x01);

    priv->eyescan_running = 1;

    return 0;
}

static int gthe3_ch_eyescan_step(struct gt_ch *ch, struct gt_eyescan_point *point)
{
    struct gthe3_ch_priv *priv = ch->priv;
    uint32_t val;

    uint32_t error_count;
    uint32_t sample_count;
    uint64_t bit_count;

    int restart = 0;

    if (!priv->eyescan_running)
        return 0;

    gthe3_ch_get_es_control_status(ch, &val);
    if (!(val & 1))
        return 2;

    gthe3_ch_set_es_control(ch, 0x00);

    gthe3_ch_get_es_error_count(ch, &error_count);
    gthe3_ch_get_es_sample_count(ch, &sample_count);
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

    gthe3_ch_set_rx_eyescan_vs_ut_sign(ch, priv->ut_sign);

    if (restart)
    {
        gthe3_ch_set_es_control(ch, 0x01);
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

    gthe3_ch_set_rx_eyescan_vs_neg_dir(ch, (priv->v_offset < 0));
    gthe3_ch_set_rx_eyescan_vs_code(ch, priv->v_offset < 0 ? -priv->v_offset : priv->v_offset);

    if (restart)
    {
        gthe3_ch_set_es_control(ch, 0x01);
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

    gthe3_ch_set_es_horz_offset(ch, (priv->h_offset & 0x7ff) | (priv->h_offset < 0 ? 0x800 : 0x000));

    if (restart)
    {
        gthe3_ch_set_es_control(ch, 0x01);
        return 1;
    }

    priv->eyescan_running = 0;
    return 0;
}

const struct gt_ch_ops gthe3_gt_ch_ops = {
    .get_tx_reset = gthe3_ch_get_tx_reset,
    .set_tx_reset = gthe3_ch_set_tx_reset,
    .tx_reset = gthe3_ch_tx_reset,
    .get_rx_reset = gthe3_ch_get_rx_reset,
    .set_rx_reset = gthe3_ch_set_rx_reset,
    .rx_reset = gthe3_ch_rx_reset,
    .get_tx_data_width = gthe3_ch_get_tx_data_width,
    .get_tx_int_data_width = gthe3_ch_get_tx_int_data_width,
    .get_rx_data_width = gthe3_ch_get_rx_data_width,
    .get_rx_int_data_width = gthe3_ch_get_rx_int_data_width,
    .get_available_presets = gthe3_ch_get_available_presets,
    .load_preset = gthe3_ch_load_preset,
    .eyescan_start = gthe3_ch_eyescan_start,
    .eyescan_step = gthe3_ch_eyescan_step
};

static int gthe3_ch_init(struct gt_ch *ch)
{
    struct gthe3_ch_priv *priv = calloc(1, sizeof(struct gthe3_ch_priv));
    if (!priv)
        return -1;

    ch->priv = priv;

    return 0;
}

int gthe3_quad_init(struct gt_quad *quad)
{
    quad->type = "GTHE3";

    for (int n = 0; n < quad->ch_count; n++)
    {
        quad->ch[n].quad = quad;
        quad->ch[n].pll = &quad->pll;
        quad->ch[n].ops = &gthe3_gt_ch_ops;
        quad->ch[n].index = n;

        gthe3_ch_init(&quad->ch[n]);
    }

    return 0;
}

const struct gt_quad_ops gthe3_gt_quad_ops = {
    .init = gthe3_quad_init
};
