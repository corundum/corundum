/*

Copyright 2020, The Regents of the University of California.
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

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "bitfile.h"

struct bitfile *bitfile_create_from_file(const char *bit_file_name)
{
    struct bitfile *bf;
    FILE *fp;
    char *buffer;
    char *data;
    size_t len;

    fp = fopen(bit_file_name, "rb");

    if (!fp)
    {
        fprintf(stderr, "Failed to open file\n");
        return 0;
    }

    fseek(fp, 0, SEEK_END);
    len = ftell(fp);
    rewind(fp);

    buffer = calloc(len + sizeof(struct bitfile), 1);

    if (!buffer)
    {
        fprintf(stderr, "Failed to allocate memory\n");
        goto fail_file;
    }

    bf = (struct bitfile *)buffer;
    data = buffer + sizeof(struct bitfile);

    if (fread(data, 1, len, fp) < len)
    {
        fprintf(stderr, "Error reading file\n");
        goto fail_buffer;
    }

    fclose(fp);

    if (bitfile_parse(bf, data, len))
    {
        fprintf(stderr, "Failed to parse bitfile\n");
        goto fail_buffer;
    }

    return bf;

fail_buffer:
    free(buffer);
fail_file:
    fclose(fp);
    return 0;
}

struct bitfile *bitfile_create_from_buffer(char *buffer, size_t len)
{
    struct bitfile *bf;

    bf = calloc(1, sizeof(struct bitfile));

    if (!bf)
    {
        fprintf(stderr, "Failed to allocate memory\n");
        return 0;
    }

    if (bitfile_parse(bf, buffer, len))
    {
        fprintf(stderr, "Failed to parse bitfile\n");
        free(bf);
        return 0;
    }

    return bf;
}

int bitfile_parse(struct bitfile *bf, char *buffer, size_t len)
{
    char *ptr;
    size_t l;

    ptr = buffer;

    bf->header = ptr;

    // drop unknown field
    l = be16toh(*((uint16_t *)ptr));
    ptr += 2+l;

    // drop unknown field
    ptr += 2;

    while (1)
    {
        int field_type = *ptr;
        ptr += 1;

        if (field_type == 'e')
        {
            l = be32toh(*((uint32_t *)ptr));
            bf->data_len = l;
            bf->data = ptr+4;
            return 0;
        }
        else
        {
            l = be16toh(*((uint16_t *)ptr));
            ptr += 2;
        }

        switch (field_type)
        {
            case 'a':
                bf->name = ptr;
                break;
            case 'b':
                bf->part = ptr;
                break;
            case 'c':
                bf->date = ptr;
                break;
            case 'd':
                bf->time = ptr;
                break;
            default:
                fprintf(stderr, "Unknown field type 0x%02x\n", field_type);
                goto fail;
        }

        ptr += l;
    }

fail:
    return -1;
}

void bitfile_close(struct bitfile *bf)
{
    if (bf)
    {
        free(bf);
    }
}

