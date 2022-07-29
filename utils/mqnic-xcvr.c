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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include <mqnic/mqnic.h>
#include "xcvr_gtye4.h"

static void usage(char *name)
{
    fprintf(stderr,
        "usage: %s [options]\n"
        " -d name    device to open (/dev/mqnic0)\n"
        " -i number  GT channel index, default 0\n"
        " -m number  GT channel mask\n"
        " -p preset  Load channel preset\n"
        " -r         Read registers\n"
        " -t         Reset channels\n"
        " -c file    Run eye scan and write CSV\n",
        name);
}

int main(int argc, char *argv[])
{
    char *name;
    int opt;
    int ret = 0;

    char *device = NULL;
    struct mqnic *dev;
    int channel_mask = 1;
    int channel_preset = 0;
    char *channel_preset_str = "";
    int channel_read_regs = 0;
    int channel_reset = 0;

    char *csv_file_name = NULL;

    name = strrchr(argv[0], '/');
    name = name ? 1+name : argv[0];

    while ((opt = getopt(argc, argv, "d:i:m:p:rtc:h?")) != EOF)
    {
        switch (opt)
        {
        case 'd':
            device = optarg;
            break;
        case 'i':
            channel_mask = 1 << atoi(optarg);
            break;
        case 'm':
            channel_mask = strtol(optarg, 0, 0);
            break;
        case 'p':
            channel_preset_str = optarg;
            break;
        case 'r':
            channel_read_regs = 1;
            break;
        case 't':
            channel_reset = 1;
            break;
        case 'c':
            csv_file_name = optarg;
            break;
        case 'h':
        case '?':
            usage(name);
            return 0;
        default:
            usage(name);
            return -1;
        }
    }

    if (!device)
    {
        fprintf(stderr, "Device not specified\n");
        usage(name);
        return -1;
    }

    dev = mqnic_open(device);

    if (!dev)
    {
        fprintf(stderr, "Failed to open device\n");
        return -1;
    }

    if (dev->pci_device_path[0])
    {
        char *ptr = strrchr(dev->pci_device_path, '/');
        if (ptr)
            printf("PCIe ID: %s\n", ptr+1);
    }

    printf("Device-level register blocks:\n");
    for (struct mqnic_reg_block *rb = dev->rb_list; rb->type && rb->version; rb++)
        printf(" type 0x%08x (v %d.%d.%d.%d)\n", rb->type, rb->version >> 24, 
                (rb->version >> 16) & 0xff, (rb->version >> 8) & 0xff, rb->version & 0xff);

    mqnic_print_fw_id(dev);

    struct gt_ch *ch;
    struct gt_quad *quad;
    struct gt_quad *gt_quads[16];
    int num_quads = 0;

    printf("Enumerate transceivers\n");
    for (int k = 0; k < 16; k++)
    {
        struct mqnic_reg_block *rb;

        rb = mqnic_find_reg_block(dev->rb_list, 0x0000C150, 0x00000100, k);

        if (!rb)
            break;

        printf("Found DRP interface %d\n", k);

        quad = gt_create_quad_from_drp_rb(rb);

        if (!quad)
            continue;

        quad->index = num_quads;
        gt_quads[num_quads++] = quad;

        printf("Quad type: %s (0x%04x)\n", quad->type, quad->gt_type);
        printf("Channel count: %d\n", quad->ch_count);

        for (int n = 0; n < quad->ch_count; n++)
        {
            printf("%d: %s channel: quad %d channel %d\n", quad->index*4+n, quad->type, quad->index, n);
        }

        if (num_quads >= 16)
            break;
    }

    if (strlen(channel_preset_str))
    {
        if (strcmp("10g_dfe", channel_preset_str) == 0)
            channel_preset = GT_PRESET_10G_DFE;
        if (strcmp("10g_lpm", channel_preset_str) == 0)
            channel_preset = GT_PRESET_10G_LPM;
        if (strcmp("25g_dfe", channel_preset_str) == 0)
            channel_preset = GT_PRESET_25G_DFE;
        if (strcmp("25g_lpm", channel_preset_str) == 0)
            channel_preset = GT_PRESET_25G_LPM;

        if (!channel_preset)
        {
            fprintf(stderr, "Unknown preset\n");
            ret = -1;
            goto err;
        }
    }

    for (int qi = 0; qi < num_quads; qi++)
    {
        quad = gt_quads[qi];
        for (int ci = 0; ci < quad->ch_count; ci++)
        {
            int index = qi*4 + ci;
            const uint32_t *presets = {0};
            ch = &quad->ch[ci];

            if ((channel_mask & (1 << index)) == 0)
                continue;

            printf("Processing channel %d\n", index);

            if (gt_ch_get_available_presets(ch, &presets) == 0)
            {
                printf("Supported presets:");

                while (*presets)
                {
                    switch (*presets)
                    {
                        case GT_PRESET_10G_DFE:
                            printf(" 10g_dfe");
                            break;
                        case GT_PRESET_10G_LPM:
                            printf(" 10g_lpm");
                            break;
                        case GT_PRESET_25G_DFE:
                            printf(" 25g_dfe");
                            break;
                        case GT_PRESET_25G_LPM:
                            printf(" 25g_lpm");
                            break;
                    }
                    presets++;
                }

                printf("\n");
            }
            else
            {
                fprintf(stderr, "Failed to read presets\n");
            }

            if (channel_read_regs)
            {
                printf("PLL registers\n");

                for (int k = 0; k <= 0xB0; k++)
                {
                    uint32_t val;
                    gt_pll_reg_read(ch->pll, k, &val);
                    printf("0x%04x: 0x%04x\n", k, val);
                }

                printf("Channel registers\n");

                for (int k = 0; k <= 0x28C; k++)
                {
                    uint32_t val;
                    gt_ch_reg_read(ch, k, &val);
                    printf("0x%04x: 0x%04x\n", k, val);
                }
            }

            if (channel_preset)
            {
                printf("Loading preset %s on channel %d\n", channel_preset_str, index);
                gt_ch_load_preset(ch, channel_preset);
            }

            if (channel_reset)
            {
                printf("Resetting channel %d\n", index);
                gt_ch_rx_reset(ch);
                gt_ch_tx_reset(ch);
            }
        }
    }

    if (csv_file_name)
    {
        struct gt_eyescan_params params;
        struct gt_eyescan_point point;
        int done;
        char csv_base_name[PATH_MAX];
        char csv_name[PATH_MAX];
        FILE *csv_file;
        FILE *csv_files[16*4];
        char *ptr;

        uint32_t data_width;
        uint32_t int_data_width;

        time_t cur_time;
        struct tm *tm_info;
        char datestr[32];

        printf("Run eye scan\n");

        params.target_bit_count = 1ULL << 30;
        params.h_range = 0;
        params.h_start = -32;
        params.h_stop = 32;
        params.h_step = 2;
        params.v_range = 0;
        params.v_start = -120;
        params.v_stop = 120;
        params.v_step = 6;

        // strip .csv extension
        snprintf(csv_base_name, sizeof(csv_base_name), "%s", csv_file_name);
        ptr = strstr(csv_base_name, ".csv");

        if (ptr && ptr-csv_base_name == strlen(csv_base_name)-4)
            *ptr = 0;

        // time string
        time(&cur_time);
        tm_info = localtime(&cur_time);
        strftime(datestr, sizeof(datestr), "%F %T", tm_info);

        for (int qi = 0; qi < num_quads; qi++)
        {
            quad = gt_quads[qi];
            for (int ci = 0; ci < quad->ch_count; ci++)
            {
                int index = qi*4 + ci;
                ch = &quad->ch[ci];

                if ((channel_mask & (1 << index)) == 0)
                    continue;

                snprintf(csv_name, sizeof(csv_name), "%s_%d.csv", csv_base_name, index);

                printf("Measuring channel %d eye to '%s'\n", index, csv_name);

                ret = gt_ch_eyescan_start(ch, &params);
                if (ret < 0)
                {
                    fprintf(stderr, "Failed to start eye scan on channel %d\n", index);
                    goto err;
                }

                csv_file = fopen(csv_name, "w");

                if (!csv_file)
                {
                    fprintf(stderr, "Failed to open file\n");
                    ret = -1;
                    goto err;
                }

                csv_files[index] = csv_file;

                fprintf(csv_file, "#eyescan\n");
                fprintf(csv_file, "#date,'%s'\n", datestr);

                fprintf(csv_file, "#fpga_id,0x%08x\n", dev->fpga_id);
                fprintf(csv_file, "#fw_id,0x%08x\n", dev->fw_id);
                fprintf(csv_file, "#fw_version,'%d.%d.%d.%d'\n", dev->fw_ver >> 24,
                        (dev->fw_ver >> 16) & 0xff,
                        (dev->fw_ver >> 8) & 0xff,
                        dev->fw_ver & 0xff);
                fprintf(csv_file, "#board_id,0x%08x\n", dev->board_id);
                fprintf(csv_file, "#board_version,'%d.%d.%d.%d'\n", dev->board_ver >> 24,
                        (dev->board_ver >> 16) & 0xff,
                        (dev->board_ver >> 8) & 0xff,
                        dev->board_ver & 0xff);
                fprintf(csv_file, "#build_date,'%s UTC'\n", dev->build_date_str);
                fprintf(csv_file, "#git_hash,'%08x'\n", dev->git_hash);
                fprintf(csv_file, "#release_info,'%08x'\n", dev->rel_info);

                fprintf(csv_file, "#channel_index,%d\n", index);
                fprintf(csv_file, "#channel_type,%s\n", ch->quad->type);
                fprintf(csv_file, "#quad,%d\n", ch->quad->index);
                fprintf(csv_file, "#channel,%d\n", ch->index);

                gt_ch_get_rx_data_width(ch, &data_width);
                gt_ch_get_rx_int_data_width(ch, &int_data_width);

                fprintf(csv_file, "#data_width,%d\n", data_width);
                fprintf(csv_file, "#int_data_width,%d\n", int_data_width);
                fprintf(csv_file, "#target_bit_count,%lu\n", params.target_bit_count);
                fprintf(csv_file, "#h_range,%d\n", params.h_range);
                fprintf(csv_file, "#h_start,%d\n", params.h_start);
                fprintf(csv_file, "#h_stop,%d\n", params.h_stop);
                fprintf(csv_file, "#h_step,%d\n", params.h_step);
                fprintf(csv_file, "#v_range,%d\n", params.v_range);
                fprintf(csv_file, "#v_start,%d\n", params.v_start);
                fprintf(csv_file, "#v_stop,%d\n", params.v_stop);
                fprintf(csv_file, "#v_step,%d\n", params.v_step);
                fprintf(csv_file, "h_offset,v_offset,ut_sign,bit_count,error_count\n");

                fflush(csv_file);
            }
        }

        done = 0;
        while (!done)
        {
            done = 1;
            for (int qi = 0; qi < num_quads; qi++)
            {
                quad = gt_quads[qi];
                for (int ci = 0; ci < quad->ch_count; ci++)
                {
                    int index = qi*4 + ci;
                    ch = &quad->ch[ci];

                    if ((channel_mask & (1 << index)) == 0)
                        continue;

                    ret = gt_ch_eyescan_step(ch, &point);
                    if (ret < 0)
                    {
                        fprintf(stderr, "Eye scan failed on channel %d\n", index);
                        goto err;
                    }
                    if (ret == 1)
                    {
                        // new point
                        printf("Channel %d point x %d, y %d\n", index, point.x, point.y);

                        fprintf(csv_files[index], "%d,%d,%d,%lu,%lu\n", point.x, point.y, point.ut_sign, point.bit_count, point.error_count);
                        fflush(csv_files[index]);

                        done = 0;
                    }
                    if (ret == 2)
                    {
                        // acquiring
                        done = 0;
                    }
                }
            }
        }

        printf("Done\n");
    }

err:

    mqnic_close(dev);

    return ret;
}
