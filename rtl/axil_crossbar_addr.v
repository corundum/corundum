/*

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
 * AXI4 lite crossbar address decode and admission control
 */
module axil_crossbar_addr #
(
    // Slave interface index
    parameter S = 0,
    // Number of AXI inputs (slave interfaces)
    parameter S_COUNT = 4,
    // Number of AXI outputs (master interfaces)
    parameter M_COUNT = 4,
    // Width of address bus in bits
    parameter ADDR_WIDTH = 32,
    // Number of regions per master interface
    parameter M_REGIONS = 1,
    // Master interface base addresses
    // M_COUNT concatenated fields of M_REGIONS concatenated fields of ADDR_WIDTH bits
    // set to zero for default addressing based on M_ADDR_WIDTH
    parameter M_BASE_ADDR = 0,
    // Master interface address widths
    // M_COUNT concatenated fields of M_REGIONS concatenated fields of 32 bits
    parameter M_ADDR_WIDTH = {M_COUNT{{M_REGIONS{32'd24}}}},
    // Connections between interfaces
    // M_COUNT concatenated fields of S_COUNT bits
    parameter M_CONNECT = {M_COUNT{{S_COUNT{1'b1}}}},
    // Secure master (fail operations based on awprot/arprot)
    // M_COUNT bits
    parameter M_SECURE = {M_COUNT{1'b0}},
    // Enable write command output
    parameter WC_OUTPUT = 0
)
(
    input  wire                       clk,
    input  wire                       rst,

    /*
     * Address input
     */
    input  wire [ADDR_WIDTH-1:0]      s_axil_aaddr,
    input  wire [2:0]                 s_axil_aprot,
    input  wire                       s_axil_avalid,
    output wire                       s_axil_aready,

    /*
     * Address output
     */
    output wire [$clog2(M_COUNT)-1:0] m_select,
    output wire                       m_axil_avalid,
    input  wire                       m_axil_aready,

    /*
     * Write command output
     */
    output wire [$clog2(M_COUNT)-1:0] m_wc_select,
    output wire                       m_wc_decerr,
    output wire                       m_wc_valid,
    input  wire                       m_wc_ready,

    /*
     * Reply command output
     */
    output wire [$clog2(M_COUNT)-1:0] m_rc_select,
    output wire                       m_rc_decerr,
    output wire                       m_rc_valid,
    input  wire                       m_rc_ready
);

parameter CL_S_COUNT = $clog2(S_COUNT);
parameter CL_M_COUNT = $clog2(M_COUNT);

// default address computation
function [M_COUNT*M_REGIONS*ADDR_WIDTH-1:0] calcBaseAddrs(input [31:0] dummy);
    integer i;
    reg [ADDR_WIDTH-1:0] base;
    reg [ADDR_WIDTH-1:0] width;
    reg [ADDR_WIDTH-1:0] size;
    reg [ADDR_WIDTH-1:0] mask;
    begin
        calcBaseAddrs = {M_COUNT*M_REGIONS*ADDR_WIDTH{1'b0}};
        base = 0;
        for (i = 0; i < M_COUNT*M_REGIONS; i = i + 1) begin
            width = M_ADDR_WIDTH[i*32 +: 32];
            mask = {ADDR_WIDTH{1'b1}} >> (ADDR_WIDTH - width);
            size = mask + 1;
            if (width > 0) begin
                if ((base & mask) != 0) begin
                   base = base + size - (base & mask); // align
                end
                calcBaseAddrs[i * ADDR_WIDTH +: ADDR_WIDTH] = base;
                base = base + size; // increment
            end
        end
    end
endfunction

parameter M_BASE_ADDR_INT = M_BASE_ADDR ? M_BASE_ADDR : calcBaseAddrs(0);

integer i, j;

// check configuration
initial begin
    if (M_REGIONS < 1) begin
        $error("Error: need at least 1 region (instance %m)");
        $finish;
    end

    for (i = 0; i < M_COUNT*M_REGIONS; i = i + 1) begin
        if (M_ADDR_WIDTH[i*32 +: 32] && (M_ADDR_WIDTH[i*32 +: 32] < 12 || M_ADDR_WIDTH[i*32 +: 32] > ADDR_WIDTH)) begin
            $error("Error: address width out of range (instance %m)");
            $finish;
        end
    end

    $display("Addressing configuration for axil_crossbar_addr instance %m");
    for (i = 0; i < M_COUNT*M_REGIONS; i = i + 1) begin
        if (M_ADDR_WIDTH[i*32 +: 32]) begin
            $display("%2d (%2d): %x / %02d -- %x-%x",
                i/M_REGIONS, i%M_REGIONS,
                M_BASE_ADDR_INT[i*ADDR_WIDTH +: ADDR_WIDTH],
                M_ADDR_WIDTH[i*32 +: 32],
                M_BASE_ADDR_INT[i*ADDR_WIDTH +: ADDR_WIDTH] & ({ADDR_WIDTH{1'b1}} << M_ADDR_WIDTH[i*32 +: 32]),
                M_BASE_ADDR_INT[i*ADDR_WIDTH +: ADDR_WIDTH] | ({ADDR_WIDTH{1'b1}} >> (ADDR_WIDTH - M_ADDR_WIDTH[i*32 +: 32]))
            );
        end
    end

    for (i = 0; i < M_COUNT*M_REGIONS; i = i + 1) begin
        if ((M_BASE_ADDR_INT[i*ADDR_WIDTH +: ADDR_WIDTH] & (2**M_ADDR_WIDTH[i*32 +: 32]-1)) != 0) begin
            $display("Region not aligned:");
            $display("%2d (%2d): %x / %2d -- %x-%x",
                i/M_REGIONS, i%M_REGIONS,
                M_BASE_ADDR_INT[i*ADDR_WIDTH +: ADDR_WIDTH],
                M_ADDR_WIDTH[i*32 +: 32],
                M_BASE_ADDR_INT[i*ADDR_WIDTH +: ADDR_WIDTH] & ({ADDR_WIDTH{1'b1}} << M_ADDR_WIDTH[i*32 +: 32]),
                M_BASE_ADDR_INT[i*ADDR_WIDTH +: ADDR_WIDTH] | ({ADDR_WIDTH{1'b1}} >> (ADDR_WIDTH - M_ADDR_WIDTH[i*32 +: 32]))
            );
            $error("Error: address range not aligned (instance %m)");
            $finish;
        end
    end

    for (i = 0; i < M_COUNT*M_REGIONS; i = i + 1) begin
        for (j = i+1; j < M_COUNT*M_REGIONS; j = j + 1) begin
            if (M_ADDR_WIDTH[i*32 +: 32] && M_ADDR_WIDTH[j*32 +: 32]) begin
                if (((M_BASE_ADDR_INT[i*ADDR_WIDTH +: ADDR_WIDTH] & ({ADDR_WIDTH{1'b1}} << M_ADDR_WIDTH[i*32 +: 32])) <= (M_BASE_ADDR_INT[j*ADDR_WIDTH +: ADDR_WIDTH] | ({ADDR_WIDTH{1'b1}} >> (ADDR_WIDTH - M_ADDR_WIDTH[j*32 +: 32]))))
                        && ((M_BASE_ADDR_INT[j*ADDR_WIDTH +: ADDR_WIDTH] & ({ADDR_WIDTH{1'b1}} << M_ADDR_WIDTH[j*32 +: 32])) <= (M_BASE_ADDR_INT[i*ADDR_WIDTH +: ADDR_WIDTH] | ({ADDR_WIDTH{1'b1}} >> (ADDR_WIDTH - M_ADDR_WIDTH[i*32 +: 32]))))) begin
                    $display("Overlapping regions:");
                    $display("%2d (%2d): %x / %2d -- %x-%x",
                        i/M_REGIONS, i%M_REGIONS,
                        M_BASE_ADDR_INT[i*ADDR_WIDTH +: ADDR_WIDTH],
                        M_ADDR_WIDTH[i*32 +: 32],
                        M_BASE_ADDR_INT[i*ADDR_WIDTH +: ADDR_WIDTH] & ({ADDR_WIDTH{1'b1}} << M_ADDR_WIDTH[i*32 +: 32]),
                        M_BASE_ADDR_INT[i*ADDR_WIDTH +: ADDR_WIDTH] | ({ADDR_WIDTH{1'b1}} >> (ADDR_WIDTH - M_ADDR_WIDTH[i*32 +: 32]))
                    );
                    $display("%2d (%2d): %x / %2d -- %x-%x",
                        j/M_REGIONS, j%M_REGIONS,
                        M_BASE_ADDR_INT[j*ADDR_WIDTH +: ADDR_WIDTH],
                        M_ADDR_WIDTH[j*32 +: 32],
                        M_BASE_ADDR_INT[j*ADDR_WIDTH +: ADDR_WIDTH] & ({ADDR_WIDTH{1'b1}} << M_ADDR_WIDTH[j*32 +: 32]),
                        M_BASE_ADDR_INT[j*ADDR_WIDTH +: ADDR_WIDTH] | ({ADDR_WIDTH{1'b1}} >> (ADDR_WIDTH - M_ADDR_WIDTH[j*32 +: 32]))
                    );
                    $error("Error: address ranges overlap (instance %m)");
                    $finish;
                end
            end
        end
    end
end

localparam [2:0]
    STATE_IDLE = 3'd0,
    STATE_DECODE = 3'd1;

reg [2:0] state_reg = STATE_IDLE, state_next;

reg s_axil_aready_reg = 0, s_axil_aready_next;

reg [CL_M_COUNT-1:0] m_select_reg = 0, m_select_next;
reg m_axil_avalid_reg = 1'b0, m_axil_avalid_next;
reg m_decerr_reg = 1'b0, m_decerr_next;
reg m_wc_valid_reg = 1'b0, m_wc_valid_next;
reg m_rc_valid_reg = 1'b0, m_rc_valid_next;

assign s_axil_aready = s_axil_aready_reg;

assign m_select = m_select_reg;
assign m_axil_avalid = m_axil_avalid_reg;

assign m_wc_select = m_select_reg;
assign m_wc_decerr = m_decerr_reg;
assign m_wc_valid = m_wc_valid_reg;

assign m_rc_select = m_select_reg;
assign m_rc_decerr = m_decerr_reg;
assign m_rc_valid = m_rc_valid_reg;

reg match;

always @* begin
    state_next = STATE_IDLE;

    match = 1'b0;

    s_axil_aready_next = 1'b0;

    m_select_next = m_select_reg;
    m_axil_avalid_next = m_axil_avalid_reg && !m_axil_aready;
    m_decerr_next = m_decerr_reg;
    m_wc_valid_next = m_wc_valid_reg && !m_wc_ready;
    m_rc_valid_next = m_rc_valid_reg && !m_rc_ready;

    case (state_reg)
        STATE_IDLE: begin
            // idle state, store values
            s_axil_aready_next = 1'b0;

            if (s_axil_avalid && !s_axil_aready) begin
                match = 1'b0;
                for (i = 0; i < M_COUNT; i = i + 1) begin
                    for (j = 0; j < M_REGIONS; j = j + 1) begin
                        if (M_ADDR_WIDTH[(i*M_REGIONS+j)*32 +: 32] && (!M_SECURE[i] || !s_axil_aprot[1]) && (M_CONNECT & (1 << (S+i*S_COUNT))) && (s_axil_aaddr >> M_ADDR_WIDTH[(i*M_REGIONS+j)*32 +: 32]) == (M_BASE_ADDR_INT[(i*M_REGIONS+j)*ADDR_WIDTH +: ADDR_WIDTH] >> M_ADDR_WIDTH[(i*M_REGIONS+j)*32 +: 32])) begin
                            m_select_next = i;
                            match = 1'b1;
                        end
                    end
                end

                if (match) begin
                    // address decode successful
                    m_axil_avalid_next = 1'b1;
                    m_decerr_next = 1'b0;
                    m_wc_valid_next = WC_OUTPUT;
                    m_rc_valid_next = 1'b1;
                    state_next = STATE_DECODE;
                end else begin
                    // decode error
                    m_axil_avalid_next = 1'b0;
                    m_decerr_next = 1'b1;
                    m_wc_valid_next = WC_OUTPUT;
                    m_rc_valid_next = 1'b1;
                    state_next = STATE_DECODE;
                end
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_DECODE: begin
            if (!m_axil_avalid_next && (!m_wc_valid_next || !WC_OUTPUT) && !m_rc_valid_next) begin
                s_axil_aready_next = 1'b1;
                state_next = STATE_IDLE;
            end else begin
                state_next = STATE_DECODE;
            end
        end
    endcase
end

always @(posedge clk) begin
    if (rst) begin
        state_reg <= STATE_IDLE;
        s_axil_aready_reg <= 1'b0;
        m_axil_avalid_reg <= 1'b0;
        m_wc_valid_reg <= 1'b0;
        m_rc_valid_reg <= 1'b0;
    end else begin
        state_reg <= state_next;
        s_axil_aready_reg <= s_axil_aready_next;
        m_axil_avalid_reg <= m_axil_avalid_next;
        m_wc_valid_reg <= m_wc_valid_next;
        m_rc_valid_reg <= m_rc_valid_next;
    end

    m_select_reg <= m_select_next;
    m_decerr_reg <= m_decerr_next;
end

endmodule

`resetall
