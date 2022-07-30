#!/usr/bin/env python
"""
Generates a PCIe TLP mux with input FIFOs wrapper with the specified number of ports
"""

import argparse
from jinja2 import Template


def main():
    parser = argparse.ArgumentParser(description=__doc__.strip())
    parser.add_argument('-p', '--ports',  type=int, default=4, help="number of ports")
    parser.add_argument('-n', '--name',   type=str, help="module name")
    parser.add_argument('-o', '--output', type=str, help="output file name")

    args = parser.parse_args()

    try:
        generate(**args.__dict__)
    except IOError as ex:
        print(ex)
        exit(1)


def generate(ports=4, name=None, output=None):
    n = ports

    if name is None:
        name = "pcie_tlp_fifo_mux_wrap_{0}".format(n)

    if output is None:
        output = name + ".v"

    print("Generating {0} port PCIe TLP mux with input FIFOs wrapper {1}...".format(n, name))

    cn = (n-1).bit_length()

    t = Template(u"""/*

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

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * PCIe TLP {{n}} port mux with input FIFOs (wrapper)
 */
module {{name}} #
(
    // TLP data width
    parameter TLP_DATA_WIDTH = 256,
    // TLP strobe width
    parameter TLP_STRB_WIDTH = TLP_DATA_WIDTH/32,
    // TLP header width
    parameter TLP_HDR_WIDTH = 128,
    // Sequence number width
    parameter SEQ_NUM_WIDTH = 6,
    // TLP segment count (input)
    parameter IN_TLP_SEG_COUNT = 1,
    // TLP segment count (output)
    parameter OUT_TLP_SEG_COUNT = IN_TLP_SEG_COUNT,
    // select round robin arbitration
    parameter ARB_TYPE_ROUND_ROBIN = 0,
    // LSB priority selection
    parameter ARB_LSB_HIGH_PRIORITY = 1,
    // FIFO depth
    parameter FIFO_DEPTH = 2048,
    // FIFO watermark level
    parameter FIFO_WATERMARK = FIFO_DEPTH/2
)
(
    input  wire                                        clk,
    input  wire                                        rst,

    /*
     * TLP inputs
     */
{%- for p in range(n) %}
    input  wire [TLP_DATA_WIDTH-1:0]                   in{{'%02d'%p}}_tlp_data,
    input  wire [TLP_STRB_WIDTH-1:0]                   in{{'%02d'%p}}_tlp_strb,
    input  wire [IN_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]   in{{'%02d'%p}}_tlp_hdr,
    input  wire [IN_TLP_SEG_COUNT*SEQ_NUM_WIDTH-1:0]   in{{'%02d'%p}}_tlp_seq,
    input  wire [IN_TLP_SEG_COUNT*3-1:0]               in{{'%02d'%p}}_tlp_bar_id,
    input  wire [IN_TLP_SEG_COUNT*8-1:0]               in{{'%02d'%p}}_tlp_func_num,
    input  wire [IN_TLP_SEG_COUNT*4-1:0]               in{{'%02d'%p}}_tlp_error,
    input  wire [IN_TLP_SEG_COUNT-1:0]                 in{{'%02d'%p}}_tlp_valid,
    input  wire [IN_TLP_SEG_COUNT-1:0]                 in{{'%02d'%p}}_tlp_sop,
    input  wire [IN_TLP_SEG_COUNT-1:0]                 in{{'%02d'%p}}_tlp_eop,
    output wire                                        in{{'%02d'%p}}_tlp_ready,
{% endfor %}
    /*
     * TLP output
     */
    output wire [TLP_DATA_WIDTH-1:0]                   out_tlp_data,
    output wire [TLP_STRB_WIDTH-1:0]                   out_tlp_strb,
    output wire [OUT_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]  out_tlp_hdr,
    output wire [OUT_TLP_SEG_COUNT*SEQ_NUM_WIDTH-1:0]  out_tlp_seq,
    output wire [OUT_TLP_SEG_COUNT*3-1:0]              out_tlp_bar_id,
    output wire [OUT_TLP_SEG_COUNT*8-1:0]              out_tlp_func_num,
    output wire [OUT_TLP_SEG_COUNT*4-1:0]              out_tlp_error,
    output wire [OUT_TLP_SEG_COUNT-1:0]                out_tlp_valid,
    output wire [OUT_TLP_SEG_COUNT-1:0]                out_tlp_sop,
    output wire [OUT_TLP_SEG_COUNT-1:0]                out_tlp_eop,
    input  wire                                        out_tlp_ready,

    /*
     * Control
     */
{%- for p in range(n) %}
    input  wire                                        in{{'%02d'%p}}_pause,
{%- endfor %}

    /*
     * Status
     */
{%- for p in range(n) %}
    output wire [OUT_TLP_SEG_COUNT*SEQ_NUM_WIDTH-1:0]  in{{'%02d'%p}}_sel_tlp_seq,
    output wire [OUT_TLP_SEG_COUNT-1:0]                in{{'%02d'%p}}_sel_tlp_seq_valid,
    output wire                                        in{{'%02d'%p}}_fifo_half_full,
    output wire                                        in{{'%02d'%p}}_fifo_watermark{% if not loop.last %},{% endif %}
{%- endfor %}
);

pcie_tlp_fifo_mux #(
    .PORTS({{n}}),
    .TLP_DATA_WIDTH(TLP_DATA_WIDTH),
    .TLP_STRB_WIDTH(TLP_STRB_WIDTH),
    .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
    .SEQ_NUM_WIDTH(SEQ_NUM_WIDTH),
    .IN_TLP_SEG_COUNT(IN_TLP_SEG_COUNT),
    .OUT_TLP_SEG_COUNT(OUT_TLP_SEG_COUNT),
    .ARB_TYPE_ROUND_ROBIN(ARB_TYPE_ROUND_ROBIN),
    .ARB_LSB_HIGH_PRIORITY(ARB_LSB_HIGH_PRIORITY),
    .FIFO_DEPTH(FIFO_DEPTH),
    .FIFO_WATERMARK(FIFO_WATERMARK)
)
pcie_tlp_fifo_mux_inst (
    .clk(clk),
    .rst(rst),

    /*
     * TLP input
     */
    .in_tlp_data({ {% for p in range(n-1,-1,-1) %}in{{'%02d'%p}}_tlp_data{% if not loop.last %}, {% endif %}{% endfor %} }),
    .in_tlp_strb({ {% for p in range(n-1,-1,-1) %}in{{'%02d'%p}}_tlp_strb{% if not loop.last %}, {% endif %}{% endfor %} }),
    .in_tlp_hdr({ {% for p in range(n-1,-1,-1) %}in{{'%02d'%p}}_tlp_hdr{% if not loop.last %}, {% endif %}{% endfor %} }),
    .in_tlp_seq({ {% for p in range(n-1,-1,-1) %}in{{'%02d'%p}}_tlp_seq{% if not loop.last %}, {% endif %}{% endfor %} }),
    .in_tlp_bar_id({ {% for p in range(n-1,-1,-1) %}in{{'%02d'%p}}_tlp_bar_id{% if not loop.last %}, {% endif %}{% endfor %} }),
    .in_tlp_func_num({ {% for p in range(n-1,-1,-1) %}in{{'%02d'%p}}_tlp_func_num{% if not loop.last %}, {% endif %}{% endfor %} }),
    .in_tlp_error({ {% for p in range(n-1,-1,-1) %}in{{'%02d'%p}}_tlp_error{% if not loop.last %}, {% endif %}{% endfor %} }),
    .in_tlp_valid({ {% for p in range(n-1,-1,-1) %}in{{'%02d'%p}}_tlp_valid{% if not loop.last %}, {% endif %}{% endfor %} }),
    .in_tlp_sop({ {% for p in range(n-1,-1,-1) %}in{{'%02d'%p}}_tlp_sop{% if not loop.last %}, {% endif %}{% endfor %} }),
    .in_tlp_eop({ {% for p in range(n-1,-1,-1) %}in{{'%02d'%p}}_tlp_eop{% if not loop.last %}, {% endif %}{% endfor %} }),
    .in_tlp_ready({ {% for p in range(n-1,-1,-1) %}in{{'%02d'%p}}_tlp_ready{% if not loop.last %}, {% endif %}{% endfor %} }),

    /*
     * TLP output
     */
    .out_tlp_data(out_tlp_data),
    .out_tlp_strb(out_tlp_strb),
    .out_tlp_hdr(out_tlp_hdr),
    .out_tlp_seq(out_tlp_seq),
    .out_tlp_bar_id(out_tlp_bar_id),
    .out_tlp_func_num(out_tlp_func_num),
    .out_tlp_error(out_tlp_error),
    .out_tlp_valid(out_tlp_valid),
    .out_tlp_sop(out_tlp_sop),
    .out_tlp_eop(out_tlp_eop),
    .out_tlp_ready(out_tlp_ready),

    /*
     * Control
     */
    .pause({ {% for p in range(n-1,-1,-1) %}in{{'%02d'%p}}_pause{% if not loop.last %}, {% endif %}{% endfor %} }),

    /*
     * Status
     */
    .sel_tlp_seq({ {% for p in range(n-1,-1,-1) %}in{{'%02d'%p}}_sel_tlp_seq{% if not loop.last %}, {% endif %}{% endfor %} }),
    .sel_tlp_seq_valid({ {% for p in range(n-1,-1,-1) %}in{{'%02d'%p}}_sel_tlp_seq_valid{% if not loop.last %}, {% endif %}{% endfor %} }),
    .fifo_half_full({ {% for p in range(n-1,-1,-1) %}in{{'%02d'%p}}_fifo_half_full{% if not loop.last %}, {% endif %}{% endfor %} }),
    .fifo_watermark({ {% for p in range(n-1,-1,-1) %}in{{'%02d'%p}}_fifo_watermark{% if not loop.last %}, {% endif %}{% endfor %} })
);

endmodule

`resetall

""")

    print(f"Writing file '{output}'...")

    with open(output, 'w') as f:
        f.write(t.render(
            n=n,
            cn=cn,
            name=name
        ))
        f.flush()

    print("Done")


if __name__ == "__main__":
    main()
