#!/usr/bin/env python3
"""

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

"""

import argparse
import matplotlib
import matplotlib.pyplot as plt
import os
import pandas as pd


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-i', '--input', type=str, default='', help="input log directory")
    parser.add_argument('-d', '--directory', type=str, default='.', help="output directory")
    parser.add_argument('-o', '--output', type=str, default=None, help="output file")
    parser.add_argument('-t', '--text', action='store_true', help="add text")

    args = parser.parse_args()

    name = args.output
    if name is None:
        name = os.path.basename(os.path.splitext(args.input)[0])

    files = [
        ("tx.csv", "TX", "lcl_txkbps", 1000/1e9),
        ("rx.csv", "RX", "lcl_rxkbps", 1000/1e9),
        ("txrx.csv", "TX S", "lcl_txkbps", 1000/1e9),
        ("txrx.csv", "RX S", "lcl_rxkbps", 1000/1e9),
    ]

    curves = []

    for fn, label, col, scale in files:
        data = pd.read_csv(os.path.join(args.input, fn)).rename(columns=lambda x: x.strip())

        n_list = []
        rate_list = []

        for n, d in data.groupby(data['n']):
            n_list.append(n)
            rate_list.append(d[col].mean()*scale)

        print(n_list)
        print(rate_list)

        curves.append((n_list, rate_list, label))

    matplotlib.rcParams.update({'font.size': 14})

    f, ax = plt.subplots(1, figsize=(8, 6))
    for x, y, label in curves:
        ax.plot(x, y, label=label)
    ax.set_title("Data rate")
    ax.set_xlabel("iperf processes")
    ax.set_ylabel("Data rate (Gbps)")
    ax.set_ylim(0, 100)
    ax.legend(fontsize='small', handlelength=1, handletextpad=0.3)

    f.savefig('rates.png', dpi=300)
    f.savefig('rates.eps', dpi=300)


if __name__ == '__main__':
    main()
