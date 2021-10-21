/*

Copyright 2019, The Regents of the University of California.
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

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Receive hashing module
 */
module rx_hash #
(
    // Width of AXI stream interfaces in bits
    parameter DATA_WIDTH = 256,
    // AXI stream tkeep signal width (words per cycle)
    parameter KEEP_WIDTH = (DATA_WIDTH/8)
)
(
    input  wire                   clk,
    input  wire                   rst,

    /*
     * AXI input
     */
    input  wire [DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]  s_axis_tkeep,
    input  wire                   s_axis_tvalid,
    input  wire                   s_axis_tlast,

    /*
     * Control
     */
    input  wire [40*8-1:0]        hash_key,

    /*
     * Hash output
     */
    output wire [31:0]            m_axis_hash,
    output wire [3:0]             m_axis_hash_type,
    output wire                   m_axis_hash_valid
);

parameter CYCLE_COUNT = (38+KEEP_WIDTH-1)/KEEP_WIDTH;

parameter PTR_WIDTH = $clog2(CYCLE_COUNT);

// bus width assertions
initial begin
    if (KEEP_WIDTH * 8 != DATA_WIDTH) begin
        $error("Error: AXI stream interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end
end

/*

TCP/UDP Frame (IPv4)

 Field                       Length
 Destination MAC address     6 octets
 Source MAC address          6 octets
 Ethertype (0x0800)          2 octets
 Version (4)                 4 bits
 IHL (5-15)                  4 bits
 DSCP (0)                    6 bits
 ECN (0)                     2 bits
 length                      2 octets
 identification (0?)         2 octets
 flags (010)                 3 bits
 fragment offset (0)         13 bits
 time to live (64?)          1 octet
 protocol (6 or 17)          1 octet
 header checksum             2 octets
 source IP                   4 octets
 destination IP              4 octets
 options                     (IHL-5)*4 octets

 source port                 2 octets
 desination port             2 octets
 other fields + payload

TCP/UDP Frame (IPv6)

 Field                       Length
 Destination MAC address     6 octets
 Source MAC address          6 octets
 Ethertype (0x86dd)          2 octets
 Version (4)                 4 bits
 Traffic class               8 bits
 Flow label                  20 bits
 length                      2 octets
 next header (6 or 17)       1 octet
 hop limit                   1 octet
 source IP                   16 octets
 destination IP              16 octets

 source port                 2 octets
 desination port             2 octets
 other fields + payload

*/

reg active_reg = 1'b1, active_next;
reg [PTR_WIDTH-1:0] ptr_reg = 0, ptr_next;

reg [15:0] eth_type_reg = 15'd0, eth_type_next;
reg [3:0] ihl_reg = 4'd0, ihl_next;

reg [36*8-1:0] hash_data_reg = 0, hash_data_next;
reg hash_data_ipv4_reg = 1'b0, hash_data_ipv4_next;
reg hash_data_tcp_reg = 1'b0, hash_data_tcp_next;
reg hash_data_udp_reg = 1'b0, hash_data_udp_next;
reg [3:0] hash_data_type_reg = 4'b0000, hash_data_type_next;
reg hash_data_valid_reg = 0, hash_data_valid_next;

reg [31:0] hash_part_ipv4_ip_reg = 32'd0;
reg [31:0] hash_part_ipv4_port_reg = 32'd0;
reg hash_part_ipv4_reg = 0;
reg hash_part_tcp_reg = 0;
reg hash_part_udp_reg = 0;
reg [3:0] hash_part_type_reg = 4'b0000;
reg hash_part_valid_reg = 0;

reg [31:0] hash_reg = 32'd0;
reg [3:0] hash_type_reg = 4'b0000;
reg hash_valid_reg = 0;

assign m_axis_hash = hash_reg;
assign m_axis_hash_type = hash_type_reg;
assign m_axis_hash_valid = hash_valid_reg;

function [31:0] hash_toep(input [36*8-1:0] data, input [5:0] len, input [40*8-1:0] key);
    integer i, j;
    begin
        hash_toep = 0;
        for (i = 0; i < len; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                if (data[i*8 + (7-j)]) begin
                    hash_toep = hash_toep ^ key[40*8 - 32 - i*8 - j +: 32];
                end
            end
        end
    end
endfunction

// compute toeplitz hashes
wire [31:0] hash_part_ipv4_ip = hash_toep(hash_data_reg, 8, hash_key);
wire [31:0] hash_part_ipv4_port = hash_toep(hash_data_reg >> 8*8, 4, hash_key << 8*8);

always @* begin
    active_next = active_reg;
    ptr_next = ptr_reg;

    eth_type_next = eth_type_reg;
    ihl_next = ihl_reg;

    hash_data_next = hash_data_reg;
    hash_data_ipv4_next = hash_data_ipv4_reg;
    hash_data_tcp_next = hash_data_tcp_reg;
    hash_data_udp_next = hash_data_udp_reg;
    hash_data_type_next = hash_data_type_reg;
    hash_data_valid_next = 1'b0;

    if (s_axis_tvalid) begin
        if (active_reg) begin
            ptr_next = ptr_reg + 1;

            if (ptr_reg == 0) begin
                hash_data_ipv4_next = 1'b0;
                hash_data_tcp_next = 1'b0;
                hash_data_udp_next = 1'b0;
            end
            if (ptr_reg == 12/KEEP_WIDTH) begin
                // eth type MSB
                eth_type_next[15:8] = s_axis_tdata[(12%KEEP_WIDTH)*8 +: 8];
            end
            if (ptr_reg == 13/KEEP_WIDTH) begin
                // eth type LSB
                eth_type_next[7:0] = s_axis_tdata[(13%KEEP_WIDTH)*8 +: 8];

                // check eth type
                if (eth_type_next == 16'h0800) begin
                    // ipv4
                    hash_data_ipv4_next = 1'b1;
                end else if (eth_type_next == 16'h86dd) begin
                    // ipv6
                    // TODO
                end else begin
                    // other
                    hash_data_type_next = 4'b0000;
                    hash_data_valid_next = 1'b1;
                    active_next = 1'b0;
                end
            end
            if (ptr_reg == 14/KEEP_WIDTH) begin
                // capture IHL
                ihl_next = s_axis_tdata[(14%KEEP_WIDTH)*8 +: 8];
            end
            if (hash_data_ipv4_next) begin
                if (ptr_reg == 23/KEEP_WIDTH) begin
                    // capture protocol
                    if (s_axis_tdata[(23%KEEP_WIDTH)*8 +: 8] == 8'h06 && ihl_next == 5) begin
                        // TCP
                        hash_data_tcp_next = 1'b1;
                    end else if (s_axis_tdata[(23%KEEP_WIDTH)*8 +: 8] == 8'h11 && ihl_next == 5) begin
                        // UDP
                        hash_data_udp_next = 1'b1;
                    end
                end
                if (ptr_reg == 26/KEEP_WIDTH) begin
                    // capture source IP
                    hash_data_next[7:0] = s_axis_tdata[(26%KEEP_WIDTH)*8 +: 8];
                end
                if (ptr_reg == 27/KEEP_WIDTH) begin
                    // capture source IP
                    hash_data_next[15:8] = s_axis_tdata[(27%KEEP_WIDTH)*8 +: 8];
                end
                if (ptr_reg == 28/KEEP_WIDTH) begin
                    // capture source IP
                    hash_data_next[23:16] = s_axis_tdata[(28%KEEP_WIDTH)*8 +: 8];
                end
                if (ptr_reg == 29/KEEP_WIDTH) begin
                    // capture source IP
                    hash_data_next[31:24] = s_axis_tdata[(29%KEEP_WIDTH)*8 +: 8];
                end
                if (ptr_reg == 30/KEEP_WIDTH) begin
                    // capture dest IP
                    hash_data_next[39:32] = s_axis_tdata[(30%KEEP_WIDTH)*8 +: 8];
                end
                if (ptr_reg == 31/KEEP_WIDTH) begin
                    // capture dest IP
                    hash_data_next[47:40] = s_axis_tdata[(31%KEEP_WIDTH)*8 +: 8];
                end
                if (ptr_reg == 32/KEEP_WIDTH) begin
                    // capture dest IP
                    hash_data_next[55:48] = s_axis_tdata[(32%KEEP_WIDTH)*8 +: 8];
                end
                if (ptr_reg == 33/KEEP_WIDTH) begin
                    // capture dest IP
                    hash_data_next[63:56] = s_axis_tdata[(33%KEEP_WIDTH)*8 +: 8];
                    if (!(hash_data_tcp_next || hash_data_udp_next)) begin
                        hash_data_type_next = {1'b0, 1'b0, 1'b0, 1'b1};
                        hash_data_valid_next = 1'b1;
                        active_next = 1'b0;
                    end
                end
                if (hash_data_tcp_next || hash_data_udp_next) begin
                    // TODO IHL (skip options)
                    if (ptr_reg == 34/KEEP_WIDTH) begin
                        // capture source port
                        hash_data_next[71:64] = s_axis_tdata[(34%KEEP_WIDTH)*8 +: 8];
                    end
                    if (ptr_reg == 35/KEEP_WIDTH) begin
                        // capture source port
                        hash_data_next[79:72] = s_axis_tdata[(35%KEEP_WIDTH)*8 +: 8];
                    end
                    if (ptr_reg == 36/KEEP_WIDTH) begin
                        // capture dest port
                        hash_data_next[87:80] = s_axis_tdata[(36%KEEP_WIDTH)*8 +: 8];
                    end
                    if (ptr_reg == 37/KEEP_WIDTH) begin
                        // capture dest port
                        hash_data_next[95:88] = s_axis_tdata[(37%KEEP_WIDTH)*8 +: 8];
                        hash_data_type_next = {hash_data_udp_next, hash_data_tcp_next, 1'b0, 1'b1};
                        hash_data_valid_next = 1'b1;
                        active_next = 1'b0;
                    end
                end
            end
        end

        if (s_axis_tlast) begin
            if (active_next) begin
                hash_data_type_next = 4'b0000;
                hash_data_valid_next = 1'b1;
            end
            ptr_next = 0;
            active_next = 1'b1;
        end
    end
end

always @(posedge clk) begin
    active_reg <= active_next;
    ptr_reg <= ptr_next;

    eth_type_reg <= eth_type_next;
    ihl_reg <= ihl_next;

    hash_data_reg <= hash_data_next;
    hash_data_ipv4_reg <= hash_data_ipv4_next;
    hash_data_tcp_reg <= hash_data_tcp_next;
    hash_data_udp_reg <= hash_data_udp_next;
    hash_data_type_reg <= hash_data_type_next;
    hash_data_valid_reg <= hash_data_valid_next;

    hash_part_ipv4_ip_reg <= hash_part_ipv4_ip;
    hash_part_ipv4_port_reg <= hash_part_ipv4_port;
    hash_part_ipv4_reg <= hash_data_ipv4_reg;
    hash_part_tcp_reg <= hash_data_tcp_reg;
    hash_part_udp_reg <= hash_data_udp_reg;
    hash_part_type_reg <= hash_data_type_reg;
    hash_part_valid_reg <= hash_data_valid_reg;

    if (hash_part_ipv4_reg) begin
        if (hash_part_tcp_reg || hash_part_udp_reg) begin
            hash_reg <= hash_part_ipv4_ip_reg ^ hash_part_ipv4_port_reg;
        end else begin
            hash_reg <= hash_part_ipv4_ip_reg;
        end
    end else begin
        hash_reg <= 0;
    end
    hash_type_reg <= hash_part_type_reg;
    hash_valid_reg <= hash_part_valid_reg;

    if (rst) begin
        active_reg <= 1'b1;
        ptr_reg <= 0;
        hash_data_valid_reg <= 0;
    end
end

endmodule

`resetall
