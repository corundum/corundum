#!/usr/bin/env python
"""

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

"""

import argparse
import matplotlib.pyplot as plt
import numpy as np
import os
import pandas as pd


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-i', '--input', type=str, default='', help="input CSV file")
    parser.add_argument('-d', '--directory', type=str, default='.', help="output directory")
    parser.add_argument('-o', '--output', type=str, default=None, help="output file")
    parser.add_argument('-t', '--text', action='store_true', help="add text")

    args = parser.parse_args()

    name = args.output
    if name is None:
        name = os.path.basename(os.path.splitext(args.input)[0])

    df = pd.read_csv(args.input, comment="#")

    h_offsets = df['h_offset'].unique()
    v_offsets = df['v_offset'].unique()

    df['ber'] = df['error_count'] / df['bit_count']

    df2 = df.groupby(['h_offset', 'v_offset'], as_index=False)['ber'].sum()

    print(df2)

    ber = df2.pivot_table(index='v_offset', columns='h_offset', values='ber').values

    print(ber)

    ber_l10 = np.log10(ber)

    ber_hm = ber_l10
    ber_hm[ber_hm == -np.inf] = -10

    f, ax = plt.subplots(1, figsize=(10, 8))

    im = ax.imshow(np.flipud(ber_hm), cmap='plasma', interpolation='nearest',
        extent=[min(h_offsets), max(h_offsets), min(v_offsets), max(v_offsets)], aspect="auto")

    cbar = ax.figure.colorbar(im, ax=ax)
    cbar.ax.set_ylabel("$\\log_{10}(BER)$", rotation=-90, va="bottom")

    ax.set_title("BER")
    ax.set_xlabel("Horizontal offset")
    ax.set_ylabel("Vertical offset")

    f.savefig(args.directory+'/'+name+'.png')


if __name__ == '__main__':
    main()
