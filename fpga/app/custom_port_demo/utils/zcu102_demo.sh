#!/bin/sh
# SPDX-License-Identifier: BSD-2-Clause-Views
# Copyright (c) 2023 Missing Link Electronics, Inc.

while true
do
    for i in {0..127}
    do
        (set -x; devmem 0xa8000010 8 $i)
        sleep 1
    done
done
