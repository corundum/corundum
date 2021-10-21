#!/usr/bin/env python
"""
Generates an AXI lite crossbar wrapper with the specified number of ports
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
        name = "axil_crossbar_wrap_{0}x{1}".format(m, n)

    if output is None:
        output = name + ".v"

    print("Generating {0}x{1} port AXI lite crossbar wrapper {2}...".format(m, n, name))

    cm = (m-1).bit_length()
    cn = (n-1).bit_length()

    t = Template(u"""/*

Copyright (c) 2021 Alex Forencich

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
 * AXI4 lite {{m}}x{{n}} crossbar (wrapper)
 */
module {{name}} #
(
    // Width of data bus in bits
    parameter DATA_WIDTH = 32,
    // Width of address bus in bits
    parameter ADDR_WIDTH = 32,
    // Width of wstrb (width of data bus in words)
    parameter STRB_WIDTH = (DATA_WIDTH/8),
{%- for p in range(m) %}
    // Number of concurrent operations
    parameter S{{'%02d'%p}}_ACCEPT = 16,
{%- endfor %}
    // Number of regions per master interface
    parameter M_REGIONS = 1,
{%- for p in range(n) %}
    // Master interface base addresses
    // M_REGIONS concatenated fields of ADDR_WIDTH bits
    parameter M{{'%02d'%p}}_BASE_ADDR = 0,
    // Master interface address widths
    // M_REGIONS concatenated fields of 32 bits
    parameter M{{'%02d'%p}}_ADDR_WIDTH = {M_REGIONS{32'd24}},
    // Read connections between interfaces
    // S_COUNT bits
    parameter M{{'%02d'%p}}_CONNECT_READ = {{m}}'b{% for p in range(m) %}1{% endfor %},
    // Write connections between interfaces
    // S_COUNT bits
    parameter M{{'%02d'%p}}_CONNECT_WRITE = {{m}}'b{% for p in range(m) %}1{% endfor %},
    // Number of concurrent operations for each master interface
    parameter M{{'%02d'%p}}_ISSUE = 16,
    // Secure master (fail operations based on awprot/arprot)
    parameter M{{'%02d'%p}}_SECURE = 0,
{%- endfor %}
{%- for p in range(m) %}
    // Slave interface AW channel register type (input)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter S{{'%02d'%p}}_AW_REG_TYPE = 0,
    // Slave interface W channel register type (input)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter S{{'%02d'%p}}_W_REG_TYPE = 0,
    // Slave interface B channel register type (output)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter S{{'%02d'%p}}_B_REG_TYPE = 1,
    // Slave interface AR channel register type (input)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter S{{'%02d'%p}}_AR_REG_TYPE = 0,
    // Slave interface R channel register type (output)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter S{{'%02d'%p}}_R_REG_TYPE = 2,
{%- endfor %}
{%- for p in range(n) %}
    // Master interface AW channel register type (output)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter M{{'%02d'%p}}_AW_REG_TYPE = 1,
    // Master interface W channel register type (output)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter M{{'%02d'%p}}_W_REG_TYPE = 2,
    // Master interface B channel register type (input)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter M{{'%02d'%p}}_B_REG_TYPE = 0,
    // Master interface AR channel register type (output)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter M{{'%02d'%p}}_AR_REG_TYPE = 1,
    // Master interface R channel register type (input)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter M{{'%02d'%p}}_R_REG_TYPE = 0{% if not loop.last %},{% endif %}
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

function [31:0] w_32(input [31:0] val);
    w_32 = val;
endfunction

function [1:0] w_2(input [1:0] val);
    w_2 = val;
endfunction

function w_1(input val);
    w_1 = val;
endfunction

axil_crossbar #(
    .S_COUNT(S_COUNT),
    .M_COUNT(M_COUNT),
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
    .S_ACCEPT({ {% for p in range(m-1,-1,-1) %}w_32(S{{'%02d'%p}}_ACCEPT){% if not loop.last %}, {% endif %}{% endfor %} }),
    .M_REGIONS(M_REGIONS),
    .M_BASE_ADDR({ {% for p in range(n-1,-1,-1) %}w_a_r(M{{'%02d'%p}}_BASE_ADDR){% if not loop.last %}, {% endif %}{% endfor %} }),
    .M_ADDR_WIDTH({ {% for p in range(n-1,-1,-1) %}w_32_r(M{{'%02d'%p}}_ADDR_WIDTH){% if not loop.last %}, {% endif %}{% endfor %} }),
    .M_CONNECT_READ({ {% for p in range(n-1,-1,-1) %}w_s(M{{'%02d'%p}}_CONNECT_READ){% if not loop.last %}, {% endif %}{% endfor %} }),
    .M_CONNECT_WRITE({ {% for p in range(n-1,-1,-1) %}w_s(M{{'%02d'%p}}_CONNECT_WRITE){% if not loop.last %}, {% endif %}{% endfor %} }),
    .M_ISSUE({ {% for p in range(n-1,-1,-1) %}w_32(M{{'%02d'%p}}_ISSUE){% if not loop.last %}, {% endif %}{% endfor %} }),
    .M_SECURE({ {% for p in range(n-1,-1,-1) %}w_1(M{{'%02d'%p}}_SECURE){% if not loop.last %}, {% endif %}{% endfor %} }),
    .S_AR_REG_TYPE({ {% for p in range(m-1,-1,-1) %}w_2(S{{'%02d'%p}}_AR_REG_TYPE){% if not loop.last %}, {% endif %}{% endfor %} }),
    .S_R_REG_TYPE({ {% for p in range(m-1,-1,-1) %}w_2(S{{'%02d'%p}}_R_REG_TYPE){% if not loop.last %}, {% endif %}{% endfor %} }),
    .S_AW_REG_TYPE({ {% for p in range(m-1,-1,-1) %}w_2(S{{'%02d'%p}}_AW_REG_TYPE){% if not loop.last %}, {% endif %}{% endfor %} }),
    .S_W_REG_TYPE({ {% for p in range(m-1,-1,-1) %}w_2(S{{'%02d'%p}}_W_REG_TYPE){% if not loop.last %}, {% endif %}{% endfor %} }),
    .S_B_REG_TYPE({ {% for p in range(m-1,-1,-1) %}w_2(S{{'%02d'%p}}_B_REG_TYPE){% if not loop.last %}, {% endif %}{% endfor %} }),
    .M_AR_REG_TYPE({ {% for p in range(n-1,-1,-1) %}w_2(M{{'%02d'%p}}_AR_REG_TYPE){% if not loop.last %}, {% endif %}{% endfor %} }),
    .M_R_REG_TYPE({ {% for p in range(n-1,-1,-1) %}w_2(M{{'%02d'%p}}_R_REG_TYPE){% if not loop.last %}, {% endif %}{% endfor %} }),
    .M_AW_REG_TYPE({ {% for p in range(n-1,-1,-1) %}w_2(M{{'%02d'%p}}_AW_REG_TYPE){% if not loop.last %}, {% endif %}{% endfor %} }),
    .M_W_REG_TYPE({ {% for p in range(n-1,-1,-1) %}w_2(M{{'%02d'%p}}_W_REG_TYPE){% if not loop.last %}, {% endif %}{% endfor %} }),
    .M_B_REG_TYPE({ {% for p in range(n-1,-1,-1) %}w_2(M{{'%02d'%p}}_B_REG_TYPE){% if not loop.last %}, {% endif %}{% endfor %} })
)
axil_crossbar_inst (
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
