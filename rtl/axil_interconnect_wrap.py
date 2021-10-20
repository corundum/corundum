#!/usr/bin/env python
"""
Generates an AXI lite interconnect wrapper with the specified number of ports
"""

import argparse
from jinja2 import Template


def main():
    parser = argparse.ArgumentParser(description=__doc__.strip())
    parser.add_argument('-p', '--ports',  type=int, default=[4], nargs='+', help="number of ports")
    parser.add_argument('-n', '--name',   type=str, help="module name")
    parser.add_argument('-o', '--output', type=str, help="output file name")

    args = parser.parse_args()

    try:
        generate(**args.__dict__)
    except IOError as ex:
        print(ex)
        exit(1)


def generate(ports=4, name=None, output=None):
    if type(ports) is int:
        m = n = ports
    elif len(ports) == 1:
        m = n = ports[0]
    else:
        m, n = ports

    if name is None:
        name = "axil_interconnect_wrap_{0}x{1}".format(m, n)

    if output is None:
        output = name + ".v"

    print("Generating {0}x{1} port AXI lite interconnect wrapper {2}...".format(m, n, name))

    cm = (m-1).bit_length()
    cn = (n-1).bit_length()

    t = Template(u"""/*

Copyright (c) 2020 Alex Forencich

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
 * AXI4 lite {{m}}x{{n}} interconnect (wrapper)
 */
module {{name}} #
(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 16,
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    parameter M_REGIONS = 1,
{%- for p in range(n) %}
    parameter M{{'%02d'%p}}_BASE_ADDR = 0,
    parameter M{{'%02d'%p}}_ADDR_WIDTH = {M_REGIONS{32'd24}},
    parameter M{{'%02d'%p}}_CONNECT_READ = {{m}}'b{% for p in range(m) %}1{% endfor %},
    parameter M{{'%02d'%p}}_CONNECT_WRITE = {{m}}'b{% for p in range(m) %}1{% endfor %},
    parameter M{{'%02d'%p}}_SECURE = 1'b0{% if not loop.last %},{% endif %}
{%- endfor %}
)
(
    input  wire                     clk,
    input  wire                     rst,

    /*
     * AXI lite slave interfaces
     */
{%- for p in range(m) %}
    input  wire [ADDR_WIDTH-1:0]    s{{'%02d'%p}}_axil_awaddr,
    input  wire [2:0]               s{{'%02d'%p}}_axil_awprot,
    input  wire                     s{{'%02d'%p}}_axil_awvalid,
    output wire                     s{{'%02d'%p}}_axil_awready,
    input  wire [DATA_WIDTH-1:0]    s{{'%02d'%p}}_axil_wdata,
    input  wire [STRB_WIDTH-1:0]    s{{'%02d'%p}}_axil_wstrb,
    input  wire                     s{{'%02d'%p}}_axil_wvalid,
    output wire                     s{{'%02d'%p}}_axil_wready,
    output wire [1:0]               s{{'%02d'%p}}_axil_bresp,
    output wire                     s{{'%02d'%p}}_axil_bvalid,
    input  wire                     s{{'%02d'%p}}_axil_bready,
    input  wire [ADDR_WIDTH-1:0]    s{{'%02d'%p}}_axil_araddr,
    input  wire [2:0]               s{{'%02d'%p}}_axil_arprot,
    input  wire                     s{{'%02d'%p}}_axil_arvalid,
    output wire                     s{{'%02d'%p}}_axil_arready,
    output wire [DATA_WIDTH-1:0]    s{{'%02d'%p}}_axil_rdata,
    output wire [1:0]               s{{'%02d'%p}}_axil_rresp,
    output wire                     s{{'%02d'%p}}_axil_rvalid,
    input  wire                     s{{'%02d'%p}}_axil_rready,
{% endfor %}
    /*
     * AXI lite master interfaces
     */
{%- for p in range(n) %}
    output wire [ADDR_WIDTH-1:0]    m{{'%02d'%p}}_axil_awaddr,
    output wire [2:0]               m{{'%02d'%p}}_axil_awprot,
    output wire                     m{{'%02d'%p}}_axil_awvalid,
    input  wire                     m{{'%02d'%p}}_axil_awready,
    output wire [DATA_WIDTH-1:0]    m{{'%02d'%p}}_axil_wdata,
    output wire [STRB_WIDTH-1:0]    m{{'%02d'%p}}_axil_wstrb,
    output wire                     m{{'%02d'%p}}_axil_wvalid,
    input  wire                     m{{'%02d'%p}}_axil_wready,
    input  wire [1:0]               m{{'%02d'%p}}_axil_bresp,
    input  wire                     m{{'%02d'%p}}_axil_bvalid,
    output wire                     m{{'%02d'%p}}_axil_bready,
    output wire [ADDR_WIDTH-1:0]    m{{'%02d'%p}}_axil_araddr,
    output wire [2:0]               m{{'%02d'%p}}_axil_arprot,
    output wire                     m{{'%02d'%p}}_axil_arvalid,
    input  wire                     m{{'%02d'%p}}_axil_arready,
    input  wire [DATA_WIDTH-1:0]    m{{'%02d'%p}}_axil_rdata,
    input  wire [1:0]               m{{'%02d'%p}}_axil_rresp,
    input  wire                     m{{'%02d'%p}}_axil_rvalid,
    output wire                     m{{'%02d'%p}}_axil_rready{% if not loop.last %},{% endif %}
{% endfor -%}
);

localparam S_COUNT = {{m}};
localparam M_COUNT = {{n}};

// parameter sizing helpers
function [ADDR_WIDTH*M_REGIONS-1:0] w_a_r(input [ADDR_WIDTH*M_REGIONS-1:0] val);
    w_a_r = val;
endfunction

function [32*M_REGIONS-1:0] w_32_r(input [32*M_REGIONS-1:0] val);
    w_32_r = val;
endfunction

function [S_COUNT-1:0] w_s(input [S_COUNT-1:0] val);
    w_s = val;
endfunction

function w_1(input val);
    w_1 = val;
endfunction

axil_interconnect #(
    .S_COUNT(S_COUNT),
    .M_COUNT(M_COUNT),
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
    .M_REGIONS(M_REGIONS),
    .M_BASE_ADDR({ {% for p in range(n-1,-1,-1) %}w_a_r(M{{'%02d'%p}}_BASE_ADDR){% if not loop.last %}, {% endif %}{% endfor %} }),
    .M_ADDR_WIDTH({ {% for p in range(n-1,-1,-1) %}w_32_r(M{{'%02d'%p}}_ADDR_WIDTH){% if not loop.last %}, {% endif %}{% endfor %} }),
    .M_CONNECT_READ({ {% for p in range(n-1,-1,-1) %}w_s(M{{'%02d'%p}}_CONNECT_READ){% if not loop.last %}, {% endif %}{% endfor %} }),
    .M_CONNECT_WRITE({ {% for p in range(n-1,-1,-1) %}w_s(M{{'%02d'%p}}_CONNECT_WRITE){% if not loop.last %}, {% endif %}{% endfor %} }),
    .M_SECURE({ {% for p in range(n-1,-1,-1) %}w_1(M{{'%02d'%p}}_SECURE){% if not loop.last %}, {% endif %}{% endfor %} })
)
axil_interconnect_inst (
    .clk(clk),
    .rst(rst),
    .s_axil_awaddr({ {% for p in range(m-1,-1,-1) %}s{{'%02d'%p}}_axil_awaddr{% if not loop.last %}, {% endif %}{% endfor %} }),
    .s_axil_awprot({ {% for p in range(m-1,-1,-1) %}s{{'%02d'%p}}_axil_awprot{% if not loop.last %}, {% endif %}{% endfor %} }),
    .s_axil_awvalid({ {% for p in range(m-1,-1,-1) %}s{{'%02d'%p}}_axil_awvalid{% if not loop.last %}, {% endif %}{% endfor %} }),
    .s_axil_awready({ {% for p in range(m-1,-1,-1) %}s{{'%02d'%p}}_axil_awready{% if not loop.last %}, {% endif %}{% endfor %} }),
    .s_axil_wdata({ {% for p in range(m-1,-1,-1) %}s{{'%02d'%p}}_axil_wdata{% if not loop.last %}, {% endif %}{% endfor %} }),
    .s_axil_wstrb({ {% for p in range(m-1,-1,-1) %}s{{'%02d'%p}}_axil_wstrb{% if not loop.last %}, {% endif %}{% endfor %} }),
    .s_axil_wvalid({ {% for p in range(m-1,-1,-1) %}s{{'%02d'%p}}_axil_wvalid{% if not loop.last %}, {% endif %}{% endfor %} }),
    .s_axil_wready({ {% for p in range(m-1,-1,-1) %}s{{'%02d'%p}}_axil_wready{% if not loop.last %}, {% endif %}{% endfor %} }),
    .s_axil_bresp({ {% for p in range(m-1,-1,-1) %}s{{'%02d'%p}}_axil_bresp{% if not loop.last %}, {% endif %}{% endfor %} }),
    .s_axil_bvalid({ {% for p in range(m-1,-1,-1) %}s{{'%02d'%p}}_axil_bvalid{% if not loop.last %}, {% endif %}{% endfor %} }),
    .s_axil_bready({ {% for p in range(m-1,-1,-1) %}s{{'%02d'%p}}_axil_bready{% if not loop.last %}, {% endif %}{% endfor %} }),
    .s_axil_araddr({ {% for p in range(m-1,-1,-1) %}s{{'%02d'%p}}_axil_araddr{% if not loop.last %}, {% endif %}{% endfor %} }),
    .s_axil_arprot({ {% for p in range(m-1,-1,-1) %}s{{'%02d'%p}}_axil_arprot{% if not loop.last %}, {% endif %}{% endfor %} }),
    .s_axil_arvalid({ {% for p in range(m-1,-1,-1) %}s{{'%02d'%p}}_axil_arvalid{% if not loop.last %}, {% endif %}{% endfor %} }),
    .s_axil_arready({ {% for p in range(m-1,-1,-1) %}s{{'%02d'%p}}_axil_arready{% if not loop.last %}, {% endif %}{% endfor %} }),
    .s_axil_rdata({ {% for p in range(m-1,-1,-1) %}s{{'%02d'%p}}_axil_rdata{% if not loop.last %}, {% endif %}{% endfor %} }),
    .s_axil_rresp({ {% for p in range(m-1,-1,-1) %}s{{'%02d'%p}}_axil_rresp{% if not loop.last %}, {% endif %}{% endfor %} }),
    .s_axil_rvalid({ {% for p in range(m-1,-1,-1) %}s{{'%02d'%p}}_axil_rvalid{% if not loop.last %}, {% endif %}{% endfor %} }),
    .s_axil_rready({ {% for p in range(m-1,-1,-1) %}s{{'%02d'%p}}_axil_rready{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_awaddr({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_awaddr{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_awprot({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_awprot{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_awvalid({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_awvalid{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_awready({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_awready{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_wdata({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_wdata{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_wstrb({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_wstrb{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_wvalid({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_wvalid{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_wready({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_wready{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_bresp({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_bresp{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_bvalid({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_bvalid{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_bready({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_bready{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_araddr({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_araddr{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_arprot({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_arprot{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_arvalid({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_arvalid{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_arready({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_arready{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_rdata({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_rdata{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_rresp({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_rresp{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_rvalid({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_rvalid{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_rready({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_rready{% if not loop.last %}, {% endif %}{% endfor %} })
);

endmodule

`resetall

""")

    print(f"Writing file '{output}'...")

    with open(output, 'w') as f:
        f.write(t.render(
            m=m,
            n=n,
            cm=cm,
            cn=cn,
            name=name
        ))
        f.flush()

    print("Done")


if __name__ == "__main__":
    main()
