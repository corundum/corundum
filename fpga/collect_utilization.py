#!/usr/bin/env python3
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
import os
import re


class record(object):
    def __init__(self):
        self.file = None
        self.project_dir = None
        self.tool = None
        self.date = None
        self.device = None
        self.lut_used = None
        self.lut_total = None
        self.ff_used = None
        self.ff_total = None
        self.bram_used = None
        self.bram_total = None
        self.uram_used = None
        self.uram_total = None
        self.wns = None
        self.tns = None

    def format_str(self):
        s = f"File: {self.file}\n"
        s += f"Project directory: {self.project_dir}\n"
        s += f"Tool: {self.tool}\n"
        s += f"Date: {self.date}\n"
        s += f"Device: {self.device}\n"
        s += f"LUTs: {self.lut_used} / {self.lut_total} ({self.lut_used/self.lut_total*100:.2f}%)\n"
        s += f"FFs:  {self.ff_used} / {self.ff_total} ({self.ff_used/self.ff_total*100:.2f}%)\n"
        if self.bram_total:
            s += f"BRAM: {self.bram_used} / {self.bram_total} ({self.bram_used/self.bram_total*100:.2f}%)\n"
        else:
            s += "BRAM: N/A\n"
        if self.uram_total:
            s += f"URAM: {self.uram_used} / {self.uram_total} ({self.uram_used/self.uram_total*100:.2f}%)\n"
        else:
            s += "URAM: N/A\n"
        s += f"Slack: WNS {self.wns} ns, TNS {self.tns} ns"
        return s

    def format_csv(self):
        s = f"\"{self.file}\","
        s += f"\"{self.project_dir}\","
        s += f"\"{self.tool}\","
        s += f"\"{self.date}\","
        s += f"\"{self.device}\","
        s += f"{self.lut_used},{self.lut_total},"
        s += f"{self.ff_used},{self.ff_total},"
        s += f"{self.bram_used},{self.bram_total},"
        s += f"{self.uram_used},{self.uram_total},"
        s += f"{self.wns},{self.tns}\n"
        return s


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-d', '--dir',  type=str, default='.', help="directory")
    parser.add_argument('--csv', type=str, help="CSV file")
    parser.add_argument('--log', type=str, help="log file")

    args = parser.parse_args()

    records = []

    for root, dirs, files in os.walk(args.dir):
        for file in files:
            # Vivado
            if file.endswith("_utilization_placed.rpt"):
                r = record()

                fn = os.path.join(root, file)
                r.file = fn
                r.project_dir = os.path.dirname(os.path.dirname(root))

                s = ''
                with open(fn, 'r') as f:
                    s = f.read()

                m = re.search(r'Tool Version\s*:\s*(.+)', s)
                r.tool = m.group(1)

                m = re.search(r'Date\s*:\s*(.+)', s)
                r.date = m.group(1)

                m = re.search(r'Device\s*:\s*(.+)', s)
                r.device = m.group(1)

                m = re.search(r'^\|\s*(?:CLB|Slice) LUTs\s*\|(.+)\|$', s, re.M)
                lst = m.group(1).split("|")
                r.lut_used = int(lst[0])
                r.lut_total = int(lst[2 if '.' in lst[3] else 3])

                m = re.search(r'^\|\s*(?:CLB|Slice) Registers\s*\|(.+)\|$', s, re.M)
                lst = m.group(1).split("|")
                r.ff_used = int(lst[0])
                r.ff_total = int(lst[2 if '.' in lst[3] else 3])

                m = re.search(r'^\|\s*Block RAM Tile\s*\|(.+)\|$', s, re.M)
                lst = m.group(1).split("|")
                r.bram_used = float(lst[0])
                r.bram_total = int(lst[2 if '.' in lst[3] else 3])

                m = re.search(r'^\|\s*URAM\s*\|(.+)\|$', s, re.M)
                if m:
                    lst = m.group(1).split("|")
                    r.uram_used = int(lst[0])
                    r.uram_total = int(lst[2 if '.' in lst[3] else 3])

                fn = os.path.join(root, file.replace("_utilization_placed.rpt", "_timing_summary_routed.rpt"))
                if os.path.isfile(fn):

                    lines = []
                    with open(fn, 'r') as f:
                        lines = f.readlines()

                    line = None
                    for i in range(len(lines)):
                        if "Design Timing Summary" in lines[i]:
                            line = i

                    fields = lines[line+6].split()

                    r.wns = fields[0]
                    r.tns = fields[1]

                records.append(r)

            # ISE
            if file.endswith("_map.mrp"):
                r = record()
                r.tool = "ISE"

                fn = os.path.join(root, file)
                r.file = fn
                r.project_dir = root

                s = ''
                with open(fn, 'r') as f:
                    s = f.read()

                m = re.search(r'Release\s*(\S+)\s*Map', s)
                r.tool = "ISE "+m.group(1)

                m = re.search(r'Mapped Date\s*:\s*(.+)', s)
                r.date = m.group(1)

                m = re.search(r'Target Device\s*:\s*(.+)', s)
                r.device = m.group(1)
                m = re.search(r'Target Package\s*:\s*(.+)', s)
                r.device += m.group(1)
                m = re.search(r'Target Speed\s*:\s*(.+)', s)
                r.device += m.group(1)

                m = re.search(r'Slice LUTs\:\s*(\S+)\s*out of\s*(\S+)\s*(\d+)', s)
                r.lut_used = int(m.group(1).replace(',', ''))
                r.lut_total = int(m.group(2).replace(',', ''))

                m = re.search(r'Slice Registers\:\s*(\S+)\s*out of\s*(\S+)\s*(\d+)', s)
                r.ff_used = int(m.group(1).replace(',', ''))
                r.ff_total = int(m.group(2).replace(',', ''))

                m = re.search(r'(?:RAMB16BWER|RAMB36E1)[^:]*\:\s*(\S+)\s*out of\s*(\S+)\s*(\d+)', s)
                r.bram_used = float(m.group(1).replace(',', ''))
                r.bram_total = int(m.group(2).replace(',', ''))

                records.append(r)

            # Quartus
            if file.endswith(".fit.summary"):
                r = record()
                r.tool = "Quartus"

                fn = os.path.join(root, file)
                r.file = fn
                r.project_dir = root

                s = ''
                with open(fn, 'r') as f:
                    s = f.read()

                m = re.search(r'(Quartus.+Version\s*:\s*.+)', s)
                r.tool = m.group(1)

                m = re.search(r'Fitter Status.+-\s*(.+)', s)
                r.date = m.group(1)

                m = re.search(r'Device\s*:\s*(.+)', s)
                r.device = m.group(1)

                m = re.search(r'Total combinational functions[^:]*\:\s*(\S+)\s*/\s*(\S+)\s*\([^\d]+(\d+)', s)
                if m:
                    r.lut_used = int(m.group(1).replace(',', ''))
                    r.lut_total = int(m.group(2).replace(',', ''))
                else:
                    m = re.search(r'Logic utilization[^:]*\:\s*(\S+)\s*/\s*(\S+)\s*\([^\d]+(\d+)', s)
                    r.lut_used = int(m.group(1).replace(',', ''))
                    r.lut_total = int(m.group(2).replace(',', ''))

                m = re.search(r'Dedicated logic registers[^:]*\:\s*(\S+)\s*/\s*(\S+)\s*\([^\d]+(\d+)', s)
                if m:
                    r.ff_used = int(m.group(1).replace(',', ''))
                    r.ff_total = int(m.group(2).replace(',', ''))

                m = re.search(r'Total (?:dedicated logic)?\s*registers[^:]*\:\s*(\S+)', s)
                if m:
                    r.ff_used = int(m.group(1).replace(',', ''))
                    r.ff_total = r.lut_total

                m = re.search(r'RAM Blocks[^:]*\:\s*(\S+)\s*/\s*(\S+)\s*\([^\d]+(\d+)', s)
                if m:
                    r.bram_used = int(m.group(1).replace(',', ''))
                    r.bram_total = int(m.group(2).replace(',', ''))

                fn = os.path.join(root, file.replace(".fit.summary", ".sta.summary"))
                if os.path.isfile(fn):

                    lines = []
                    with open(fn, 'r') as f:
                        lines = f.readlines()

                    wns = 1e9
                    tns = 0

                    for line in lines:
                        m = re.search(r'(\S+)\s*\:\s*(\S+)', line)
                        if m:
                            if m.group(1) == "Slack":
                                wns = min(wns, float(m.group(2)))
                            if m.group(1) == "TNS":
                                tns += float(m.group(2))

                    r.wns = wns
                    r.tns = tns

                records.append(r)

    records.sort(key=lambda r: r.file)

    for r in records:
        print(r.format_str())
        print()

    if args.log:
        with open(args.log, 'w') as f:
            for r in records:
                f.write(r.format_str())
                f.write("\n\n")

    if args.csv:
        with open(args.csv, 'w') as f:
            f.write("file,project_dir,tool,date,device,lut_used,lut_total,ff_used,ff_total,bram_used,bram_total,uram_used,uram_total,wns,tns\n")
            for r in records:
                f.write(r.format_csv())


if __name__ == '__main__':
    main()
