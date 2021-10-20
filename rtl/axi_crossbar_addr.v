/*

Copyright (c) 2018 Alex Forencich

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
 * AXI4 crossbar address decode and admission control
 */
module axi_crossbar_addr #
(
    // Slave interface index
    parameter S = 0,
    // Number of AXI inputs (slave interfaces)
    parameter S_COUNT = 4,
    // Number of AXI outputs (master interfaces)
    parameter M_COUNT = 4,
    // Width of address bus in bits
    parameter ADDR_WIDTH = 32,
    // ID field width
    parameter ID_WIDTH = 8,
    // Number of concurrent unique IDs
    parameter S_THREADS = 32'd2,
    // Number of concurrent operations
    parameter S_ACCEPT = 32'd16,
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
    input  wire [ID_WIDTH-1:0]        s_axi_aid,
    input  wire [ADDR_WIDTH-1:0]      s_axi_aaddr,
    input  wire [2:0]                 s_axi_aprot,
    input  wire [3:0]                 s_axi_aqos,
    input  wire                       s_axi_avalid,
    output wire                       s_axi_aready,

    /*
     * Address output
     */
    output wire [3:0]                 m_axi_aregion,
    output wire [$clog2(M_COUNT)-1:0] m_select,
    output wire                       m_axi_avalid,
    input  wire                       m_axi_aready,

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
    output wire                       m_rc_decerr,
    output wire                       m_rc_valid,
    input  wire                       m_rc_ready,

    /*
     * Completion input
     */
    input  wire [ID_WIDTH-1:0]        s_cpl_id,
    input  wire                       s_cpl_valid
);

parameter CL_S_COUNT = $clog2(S_COUNT);
parameter CL_M_COUNT = $clog2(M_COUNT);

parameter S_INT_THREADS = S_THREADS > S_ACCEPT ? S_ACCEPT : S_THREADS;
parameter CL_S_INT_THREADS = $clog2(S_INT_THREADS);
parameter CL_S_ACCEPT = $clog2(S_ACCEPT);

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
    if (S_ACCEPT < 1) begin
        $error("Error: need at least 1 accept (instance %m)");
        $finish;
    end

    if (S_THREADS < 1) begin
        $error("Error: need at least 1 thread (instance %m)");
        $finish;
    end

    if (S_THREADS > S_ACCEPT) begin
        $warning("Warning: requested thread count larger than accept count; limiting thread count to accept count (instance %m)");
    end

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

    $display("Addressing configuration for axi_crossbar_addr instance %m");
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

reg s_axi_aready_reg = 0, s_axi_aready_next;

reg [3:0] m_axi_aregion_reg = 4'd0, m_axi_aregion_next;
reg [CL_M_COUNT-1:0] m_select_reg = 0, m_select_next;
reg m_axi_avalid_reg = 1'b0, m_axi_avalid_next;
reg m_decerr_reg = 1'b0, m_decerr_next;
reg m_wc_valid_reg = 1'b0, m_wc_valid_next;
reg m_rc_valid_reg = 1'b0, m_rc_valid_next;

assign s_axi_aready = s_axi_aready_reg;

assign m_axi_aregion = m_axi_aregion_reg;
assign m_select = m_select_reg;
assign m_axi_avalid = m_axi_avalid_reg;

assign m_wc_select = m_select_reg;
assign m_wc_decerr = m_decerr_reg;
assign m_wc_valid = m_wc_valid_reg;

assign m_rc_decerr = m_decerr_reg;
assign m_rc_valid = m_rc_valid_reg;

reg match;
reg trans_start;
reg trans_complete;

reg [$clog2(S_ACCEPT+1)-1:0] trans_count_reg = 0;
wire trans_limit = trans_count_reg >= S_ACCEPT && !trans_complete;

// transfer ID thread tracking
reg [ID_WIDTH-1:0] thread_id_reg[S_INT_THREADS-1:0];
reg [CL_M_COUNT-1:0] thread_m_reg[S_INT_THREADS-1:0];
reg [3:0] thread_region_reg[S_INT_THREADS-1:0];
reg [$clog2(S_ACCEPT+1)-1:0] thread_count_reg[S_INT_THREADS-1:0];

wire [S_INT_THREADS-1:0] thread_active;
wire [S_INT_THREADS-1:0] thread_match;
wire [S_INT_THREADS-1:0] thread_match_dest;
wire [S_INT_THREADS-1:0] thread_cpl_match;
wire [S_INT_THREADS-1:0] thread_trans_start;
wire [S_INT_THREADS-1:0] thread_trans_complete;

generate
    genvar n;

    for (n = 0; n < S_INT_THREADS; n = n + 1) begin
        initial begin
            thread_count_reg[n] <= 0;
        end

        assign thread_active[n] = thread_count_reg[n] != 0;
        assign thread_match[n] = thread_active[n] && thread_id_reg[n] == s_axi_aid;
        assign thread_match_dest[n] = thread_match[n] && thread_m_reg[n] == m_select_next && (M_REGIONS < 2 || thread_region_reg[n] == m_axi_aregion_next);
        assign thread_cpl_match[n] = thread_active[n] && thread_id_reg[n] == s_cpl_id;
        assign thread_trans_start[n] = (thread_match[n] || (!thread_active[n] && !thread_match && !(thread_trans_start & ({S_INT_THREADS{1'b1}} >> (S_INT_THREADS-n))))) && trans_start;
        assign thread_trans_complete[n] = thread_cpl_match[n] && trans_complete;

        always @(posedge clk) begin
            if (rst) begin
                thread_count_reg[n] <= 0;
            end else begin
                if (thread_trans_start[n] && !thread_trans_complete[n]) begin
                    thread_count_reg[n] <= thread_count_reg[n] + 1;
                end else if (!thread_trans_start[n] && thread_trans_complete[n]) begin
                    thread_count_reg[n] <= thread_count_reg[n] - 1;
                end
            end

            if (thread_trans_start[n]) begin
                thread_id_reg[n] <= s_axi_aid;
                thread_m_reg[n] <= m_select_next;
                thread_region_reg[n] <= m_axi_aregion_next;
            end
        end
    end
endgenerate

always @* begin
    state_next = STATE_IDLE;

    match = 1'b0;
    trans_start = 1'b0;
    trans_complete = 1'b0;

    s_axi_aready_next = 1'b0;

    m_axi_aregion_next = m_axi_aregion_reg;
    m_select_next = m_select_reg;
    m_axi_avalid_next = m_axi_avalid_reg && !m_axi_aready;
    m_decerr_next = m_decerr_reg;
    m_wc_valid_next = m_wc_valid_reg && !m_wc_ready;
    m_rc_valid_next = m_rc_valid_reg && !m_rc_ready;

    case (state_reg)
        STATE_IDLE: begin
            // idle state, store values
            s_axi_aready_next = 1'b0;

            if (s_axi_avalid && !s_axi_aready) begin
                match = 1'b0;
                for (i = 0; i < M_COUNT; i = i + 1) begin
                    for (j = 0; j < M_REGIONS; j = j + 1) begin
                        if (M_ADDR_WIDTH[(i*M_REGIONS+j)*32 +: 32] && (!M_SECURE[i] || !s_axi_aprot[1]) && (M_CONNECT & (1 << (S+i*S_COUNT))) && (s_axi_aaddr >> M_ADDR_WIDTH[(i*M_REGIONS+j)*32 +: 32]) == (M_BASE_ADDR_INT[(i*M_REGIONS+j)*ADDR_WIDTH +: ADDR_WIDTH] >> M_ADDR_WIDTH[(i*M_REGIONS+j)*32 +: 32])) begin
                            m_select_next = i;
                            m_axi_aregion_next = j;
                            match = 1'b1;
                        end
                    end
                end

                if (match) begin
                    // address decode successful
                    if (!trans_limit && (thread_match_dest || (!(&thread_active) && !thread_match))) begin
                        // transaction limit not reached
                        m_axi_avalid_next = 1'b1;
                        m_decerr_next = 1'b0;
                        m_wc_valid_next = WC_OUTPUT;
                        m_rc_valid_next = 1'b0;
                        trans_start = 1'b1;
                        state_next = STATE_DECODE;
                    end else begin
                        // transaction limit reached; block in idle
                        state_next = STATE_IDLE;
                    end
                end else begin
                    // decode error
                    m_axi_avalid_next = 1'b0;
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
            if (!m_axi_avalid_next && (!m_wc_valid_next || !WC_OUTPUT) && !m_rc_valid_next) begin
                s_axi_aready_next = 1'b1;
                state_next = STATE_IDLE;
            end else begin
                state_next = STATE_DECODE;
            end
        end
    endcase

    // manage completions
    trans_complete = s_cpl_valid;
end

always @(posedge clk) begin
    if (rst) begin
        state_reg <= STATE_IDLE;
        s_axi_aready_reg <= 1'b0;
        m_axi_avalid_reg <= 1'b0;
        m_wc_valid_reg <= 1'b0;
        m_rc_valid_reg <= 1'b0;

        trans_count_reg <= 0;
    end else begin
        state_reg <= state_next;
        s_axi_aready_reg <= s_axi_aready_next;
        m_axi_avalid_reg <= m_axi_avalid_next;
        m_wc_valid_reg <= m_wc_valid_next;
        m_rc_valid_reg <= m_rc_valid_next;

        if (trans_start && !trans_complete) begin
            trans_count_reg <= trans_count_reg + 1;
        end else if (!trans_start && trans_complete) begin
            trans_count_reg <= trans_count_reg - 1;
        end
    end

    m_axi_aregion_reg <= m_axi_aregion_next;
    m_select_reg <= m_select_next;
    m_decerr_reg <= m_decerr_next;
end

endmodule

`resetall
