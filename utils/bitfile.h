// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2020-2023 The Regents of the University of California
 */

#ifndef BITFILE_H
#define BITFILE_H

struct bitfile {
    char *header;
    char *name;
    char *part;
    char *date;
    char *time;

    size_t data_len;
    char *data;
};

struct bitfile *bitfile_create_from_file(const char *bit_file_name);

struct bitfile *bitfile_create_from_buffer(char *buffer, size_t len);

int bitfile_parse(struct bitfile *bf, char *buffer, size_t len);

void bitfile_close(struct bitfile *bf);

#endif // BITFILE_H
