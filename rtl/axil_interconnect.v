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
 * AXI4 lite interconnect
 */
module axil_interconnect #
(
    // Number of AXI inputs (slave interfaces)
    parameter S_COUNT = 4,
    // Number of AXI outputs (master interfaces)
    parameter M_COUNT = 4,
    // Width of data bus in bits
    parameter DATA_WIDTH = 32,
    // Width of address bus in bits
    parameter ADDR_WIDTH = 32,
    // Width of wstrb (width of data bus in words)
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    // Number of regions per master interface
    parameter M_REGIONS = 1,
    // Master interface base addresses
    // M_COUNT concatenated fields of M_REGIONS concatenated fields of ADDR_WIDTH bits
    // set to zero for default addressing based on M_ADDR_WIDTH
    parameter M_BASE_ADDR = 0,
    // Master interface address widths
    // M_COUNT concatenated fields of M_REGIONS concatenated fields of 32 bits
    parameter M_ADDR_WIDTH = {M_COUNT{{M_REGIONS{32'd24}}}},
    // Read connections between interfaces
    // M_COUNT concatenated fields of S_COUNT bits
    parameter M_CONNECT_READ = {M_COUNT{{S_COUNT{1'b1}}}},
    // Write connections between interfaces
    // M_COUNT concatenated fields of S_COUNT bits
    parameter M_CONNECT_WRITE = {M_COUNT{{S_COUNT{1'b1}}}},
    // Secure master (fail operations based on awprot/arprot)
    // M_COUNT bits
    parameter M_SECURE = {M_COUNT{1'b0}}
)
(
    input  wire                           clk,
    input  wire                           rst,

    /*
     * AXI lite slave interfaces
     */
    input  wire [S_COUNT*ADDR_WIDTH-1:0]  s_axil_awaddr,
    input  wire [S_COUNT*3-1:0]           s_axil_awprot,
    input  wire [S_COUNT-1:0]             s_axil_awvalid,
    output wire [S_COUNT-1:0]             s_axil_awready,
    input  wire [S_COUNT*DATA_WIDTH-1:0]  s_axil_wdata,
    input  wire [S_COUNT*STRB_WIDTH-1:0]  s_axil_wstrb,
    input  wire [S_COUNT-1:0]             s_axil_wvalid,
    output wire [S_COUNT-1:0]             s_axil_wready,
    output wire [S_COUNT*2-1:0]           s_axil_bresp,
    output wire [S_COUNT-1:0]             s_axil_bvalid,
    input  wire [S_COUNT-1:0]             s_axil_bready,
    input  wire [S_COUNT*ADDR_WIDTH-1:0]  s_axil_araddr,
    input  wire [S_COUNT*3-1:0]           s_axil_arprot,
    input  wire [S_COUNT-1:0]             s_axil_arvalid,
    output wire [S_COUNT-1:0]             s_axil_arready,
    output wire [S_COUNT*DATA_WIDTH-1:0]  s_axil_rdata,
    output wire [S_COUNT*2-1:0]           s_axil_rresp,
    output wire [S_COUNT-1:0]             s_axil_rvalid,
    input  wire [S_COUNT-1:0]             s_axil_rready,

    /*
     * AXI lite master interfaces
     */
    output wire [M_COUNT*ADDR_WIDTH-1:0]  m_axil_awaddr,
    output wire [M_COUNT*3-1:0]           m_axil_awprot,
    output wire [M_COUNT-1:0]             m_axil_awvalid,
    input  wire [M_COUNT-1:0]             m_axil_awready,
    output wire [M_COUNT*DATA_WIDTH-1:0]  m_axil_wdata,
    output wire [M_COUNT*STRB_WIDTH-1:0]  m_axil_wstrb,
    output wire [M_COUNT-1:0]             m_axil_wvalid,
    input  wire [M_COUNT-1:0]             m_axil_wready,
    input  wire [M_COUNT*2-1:0]           m_axil_bresp,
    input  wire [M_COUNT-1:0]             m_axil_bvalid,
    output wire [M_COUNT-1:0]             m_axil_bready,
    output wire [M_COUNT*ADDR_WIDTH-1:0]  m_axil_araddr,
    output wire [M_COUNT*3-1:0]           m_axil_arprot,
    output wire [M_COUNT-1:0]             m_axil_arvalid,
    input  wire [M_COUNT-1:0]             m_axil_arready,
    input  wire [M_COUNT*DATA_WIDTH-1:0]  m_axil_rdata,
    input  wire [M_COUNT*2-1:0]           m_axil_rresp,
    input  wire [M_COUNT-1:0]             m_axil_rvalid,
    output wire [M_COUNT-1:0]             m_axil_rready
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
    for (i = 0; i < M_COUNT*M_REGIONS; i = i + 1) begin
        if (M_ADDR_WIDTH[i*32 +: 32] && (M_ADDR_WIDTH[i*32 +: 32] < 0 || M_ADDR_WIDTH[i*32 +: 32] > ADDR_WIDTH)) begin
            $error("Error: address width out of range (instance %m)");
            $finish;
        end
    end

    $display("Addressing configuration for axil_interconnect instance %m");
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
    STATE_DECODE = 3'd1,
    STATE_WRITE = 3'd2,
    STATE_WRITE_RESP = 3'd3,
    STATE_WRITE_DROP = 3'd4,
    STATE_READ = 3'd5,
    STATE_WAIT_IDLE = 3'd6;

reg [2:0] state_reg = STATE_IDLE, state_next;

reg match;

reg [CL_M_COUNT-1:0] m_select_reg = 2'd0, m_select_next;
reg [ADDR_WIDTH-1:0] axil_addr_reg = {ADDR_WIDTH{1'b0}}, axil_addr_next;
reg axil_addr_valid_reg = 1'b0, axil_addr_valid_next;
reg [2:0] axil_prot_reg = 3'b000, axil_prot_next;
reg [DATA_WIDTH-1:0] axil_data_reg = {DATA_WIDTH{1'b0}}, axil_data_next;
reg [STRB_WIDTH-1:0] axil_wstrb_reg = {STRB_WIDTH{1'b0}}, axil_wstrb_next;
reg [1:0] axil_resp_reg = 2'b00, axil_resp_next;

reg [S_COUNT-1:0] s_axil_awready_reg = 0, s_axil_awready_next;
reg [S_COUNT-1:0] s_axil_wready_reg = 0, s_axil_wready_next;
reg [S_COUNT-1:0] s_axil_bvalid_reg = 0, s_axil_bvalid_next;
reg [S_COUNT-1:0] s_axil_arready_reg = 0, s_axil_arready_next;
reg [S_COUNT-1:0] s_axil_rvalid_reg = 0, s_axil_rvalid_next;

reg [M_COUNT-1:0] m_axil_awvalid_reg = 0, m_axil_awvalid_next;
reg [M_COUNT-1:0] m_axil_wvalid_reg = 0, m_axil_wvalid_next;
reg [M_COUNT-1:0] m_axil_bready_reg = 0, m_axil_bready_next;
reg [M_COUNT-1:0] m_axil_arvalid_reg = 0, m_axil_arvalid_next;
reg [M_COUNT-1:0] m_axil_rready_reg = 0, m_axil_rready_next;

assign s_axil_awready = s_axil_awready_reg;
assign s_axil_wready = s_axil_wready_reg;
assign s_axil_bresp = {S_COUNT{axil_resp_reg}};
assign s_axil_bvalid = s_axil_bvalid_reg;
assign s_axil_arready = s_axil_arready_reg;
assign s_axil_rdata = {S_COUNT{axil_data_reg}};
assign s_axil_rresp = {S_COUNT{axil_resp_reg}};
assign s_axil_rvalid = s_axil_rvalid_reg;

assign m_axil_awaddr = {M_COUNT{axil_addr_reg}};
assign m_axil_awprot = {M_COUNT{axil_prot_reg}};
assign m_axil_awvalid = m_axil_awvalid_reg;
assign m_axil_wdata = {M_COUNT{axil_data_reg}};
assign m_axil_wstrb = {M_COUNT{axil_wstrb_reg}};
assign m_axil_wvalid = m_axil_wvalid_reg;
assign m_axil_bready = m_axil_bready_reg;
assign m_axil_araddr = {M_COUNT{axil_addr_reg}};
assign m_axil_arprot = {M_COUNT{axil_prot_reg}};
assign m_axil_arvalid = m_axil_arvalid_reg;
assign m_axil_rready = m_axil_rready_reg;

// slave side mux
wire [(CL_S_COUNT > 0 ? CL_S_COUNT-1 : 0):0] s_select;

wire [ADDR_WIDTH-1:0] current_s_axil_awaddr  = s_axil_awaddr[s_select*ADDR_WIDTH +: ADDR_WIDTH];
wire [2:0]            current_s_axil_awprot  = s_axil_awprot[s_select*3 +: 3];
wire                  current_s_axil_awvalid = s_axil_awvalid[s_select];
wire                  current_s_axil_awready = s_axil_awready[s_select];
wire [DATA_WIDTH-1:0] current_s_axil_wdata   = s_axil_wdata[s_select*DATA_WIDTH +: DATA_WIDTH];
wire [STRB_WIDTH-1:0] current_s_axil_wstrb   = s_axil_wstrb[s_select*STRB_WIDTH +: STRB_WIDTH];
wire                  current_s_axil_wvalid  = s_axil_wvalid[s_select];
wire                  current_s_axil_wready  = s_axil_wready[s_select];
wire [1:0]            current_s_axil_bresp   = s_axil_bresp[s_select*2 +: 2];
wire                  current_s_axil_bvalid  = s_axil_bvalid[s_select];
wire                  current_s_axil_bready  = s_axil_bready[s_select];
wire [ADDR_WIDTH-1:0] current_s_axil_araddr  = s_axil_araddr[s_select*ADDR_WIDTH +: ADDR_WIDTH];
wire [2:0]            current_s_axil_arprot  = s_axil_arprot[s_select*3 +: 3];
wire                  current_s_axil_arvalid = s_axil_arvalid[s_select];
wire                  current_s_axil_arready = s_axil_arready[s_select];
wire [DATA_WIDTH-1:0] current_s_axil_rdata   = s_axil_rdata[s_select*DATA_WIDTH +: DATA_WIDTH];
wire [1:0]            current_s_axil_rresp   = s_axil_rresp[s_select*2 +: 2];
wire                  current_s_axil_rvalid  = s_axil_rvalid[s_select];
wire                  current_s_axil_rready  = s_axil_rready[s_select];

// master side mux
wire [ADDR_WIDTH-1:0] current_m_axil_awaddr  = m_axil_awaddr[m_select_reg*ADDR_WIDTH +: ADDR_WIDTH];
wire [2:0]            current_m_axil_awprot  = m_axil_awprot[m_select_reg*3 +: 3];
wire                  current_m_axil_awvalid = m_axil_awvalid[m_select_reg];
wire                  current_m_axil_awready = m_axil_awready[m_select_reg];
wire [DATA_WIDTH-1:0] current_m_axil_wdata   = m_axil_wdata[m_select_reg*DATA_WIDTH +: DATA_WIDTH];
wire [STRB_WIDTH-1:0] current_m_axil_wstrb   = m_axil_wstrb[m_select_reg*STRB_WIDTH +: STRB_WIDTH];
wire                  current_m_axil_wvalid  = m_axil_wvalid[m_select_reg];
wire                  current_m_axil_wready  = m_axil_wready[m_select_reg];
wire [1:0]            current_m_axil_bresp   = m_axil_bresp[m_select_reg*2 +: 2];
wire                  current_m_axil_bvalid  = m_axil_bvalid[m_select_reg];
wire                  current_m_axil_bready  = m_axil_bready[m_select_reg];
wire [ADDR_WIDTH-1:0] current_m_axil_araddr  = m_axil_araddr[m_select_reg*ADDR_WIDTH +: ADDR_WIDTH];
wire [2:0]            current_m_axil_arprot  = m_axil_arprot[m_select_reg*3 +: 3];
wire                  current_m_axil_arvalid = m_axil_arvalid[m_select_reg];
wire                  current_m_axil_arready = m_axil_arready[m_select_reg];
wire [DATA_WIDTH-1:0] current_m_axil_rdata   = m_axil_rdata[m_select_reg*DATA_WIDTH +: DATA_WIDTH];
wire [1:0]            current_m_axil_rresp   = m_axil_rresp[m_select_reg*2 +: 2];
wire                  current_m_axil_rvalid  = m_axil_rvalid[m_select_reg];
wire                  current_m_axil_rready  = m_axil_rready[m_select_reg];

// arbiter instance
wire [S_COUNT*2-1:0] request;
wire [S_COUNT*2-1:0] acknowledge;
wire [S_COUNT*2-1:0] grant;
wire grant_valid;
wire [CL_S_COUNT:0] grant_encoded;

wire read = grant_encoded[0];
assign s_select = grant_encoded >> 1;

arbiter #(
    .PORTS(S_COUNT*2),
    .ARB_TYPE_ROUND_ROBIN(1),
    .ARB_BLOCK(1),
    .ARB_BLOCK_ACK(1),
    .ARB_LSB_HIGH_PRIORITY(1)
)
arb_inst (
    .clk(clk),
    .rst(rst),
    .request(request),
    .acknowledge(acknowledge),
    .grant(grant),
    .grant_valid(grant_valid),
    .grant_encoded(grant_encoded)
);

genvar n;

// request generation
generate
for (n = 0; n < S_COUNT; n = n + 1) begin
    assign request[2*n]   = s_axil_awvalid[n];
    assign request[2*n+1] = s_axil_arvalid[n];
end
endgenerate

// acknowledge generation
generate
for (n = 0; n < S_COUNT; n = n + 1) begin
    assign acknowledge[2*n]   = grant[2*n]   && s_axil_bvalid[n] && s_axil_bready[n];
    assign acknowledge[2*n+1] = grant[2*n+1] && s_axil_rvalid[n] && s_axil_rready[n];
end
endgenerate

always @* begin
    state_next = STATE_IDLE;

    match = 1'b0;

    m_select_next = m_select_reg;
    axil_addr_next = axil_addr_reg;
    axil_addr_valid_next = axil_addr_valid_reg;
    axil_prot_next = axil_prot_reg;
    axil_data_next = axil_data_reg;
    axil_wstrb_next = axil_wstrb_reg;
    axil_resp_next = axil_resp_reg;

    s_axil_awready_next = 0;
    s_axil_wready_next = 0;
    s_axil_bvalid_next = s_axil_bvalid_reg & ~s_axil_bready;
    s_axil_arready_next = 0;
    s_axil_rvalid_next = s_axil_rvalid_reg & ~s_axil_rready;

    m_axil_awvalid_next = m_axil_awvalid_reg & ~m_axil_awready;
    m_axil_wvalid_next = m_axil_wvalid_reg & ~m_axil_wready;
    m_axil_bready_next = 0;
    m_axil_arvalid_next = m_axil_arvalid_reg & ~m_axil_arready;
    m_axil_rready_next = 0;

    case (state_reg)
        STATE_IDLE: begin
            // idle state; wait for arbitration

            if (grant_valid) begin

                axil_addr_valid_next = 1'b1;

                if (read) begin
                    // reading
                    axil_addr_next = current_s_axil_araddr;
                    axil_prot_next = current_s_axil_arprot;
                    s_axil_arready_next[s_select] = 1'b1;
                end else  begin
                    // writing
                    axil_addr_next = current_s_axil_awaddr;
                    axil_prot_next = current_s_axil_awprot;
                    s_axil_awready_next[s_select] = 1'b1;
                end

                state_next = STATE_DECODE;
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_DECODE: begin
            // decode state; determine master interface

            match = 1'b0;
            for (i = 0; i < M_COUNT; i = i + 1) begin
                for (j = 0; j < M_REGIONS; j = j + 1) begin
                    if (M_ADDR_WIDTH[(i*M_REGIONS+j)*32 +: 32] && (!M_SECURE[i] || !axil_prot_reg[1]) && ((read ? M_CONNECT_READ : M_CONNECT_WRITE) & (1 << (s_select+i*S_COUNT))) && (axil_addr_reg >> M_ADDR_WIDTH[(i*M_REGIONS+j)*32 +: 32]) == (M_BASE_ADDR_INT[(i*M_REGIONS+j)*ADDR_WIDTH +: ADDR_WIDTH] >> M_ADDR_WIDTH[(i*M_REGIONS+j)*32 +: 32])) begin
                        m_select_next = i;
                        match = 1'b1;
                    end
                end
            end

            if (match) begin
                if (read) begin
                    // reading
                    m_axil_rready_next[m_select_next] = 1'b1;
                    state_next = STATE_READ;
                end else begin
                    // writing
                    s_axil_wready_next[s_select] = 1'b1;
                    state_next = STATE_WRITE;
                end
            end else begin
                // no match; return decode error
                axil_data_next = {DATA_WIDTH{1'b0}};
                axil_resp_next = 2'b11;
                if (read) begin
                    // reading
                    s_axil_rvalid_next[s_select] = 1'b1;
                    state_next = STATE_WAIT_IDLE;
                end else begin
                    // writing
                    s_axil_wready_next[s_select] = 1'b1;
                    state_next = STATE_WRITE_DROP;
                end
            end
        end
        STATE_WRITE: begin
            // write state; store and forward write data
            s_axil_wready_next[s_select] = 1'b1;

            if (axil_addr_valid_reg) begin
                m_axil_awvalid_next[m_select_reg] = 1'b1;
            end
            axil_addr_valid_next = 1'b0;

            if (current_s_axil_wready && current_s_axil_wvalid) begin
                s_axil_wready_next[s_select] = 1'b0;
                axil_data_next = current_s_axil_wdata;
                axil_wstrb_next = current_s_axil_wstrb;
                m_axil_wvalid_next[m_select_reg] = 1'b1;
                m_axil_bready_next[m_select_reg] = 1'b1;
                state_next = STATE_WRITE_RESP;
            end else begin
                state_next = STATE_WRITE;
            end
        end
        STATE_WRITE_RESP: begin
            // write response state; store and forward write response
            m_axil_bready_next[m_select_reg] = 1'b1;

            if (current_m_axil_bready && current_m_axil_bvalid) begin
                m_axil_bready_next[m_select_reg] = 1'b0;
                axil_resp_next = current_m_axil_bresp;
                s_axil_bvalid_next[s_select] = 1'b1;
                state_next = STATE_WAIT_IDLE;
            end else begin
                state_next = STATE_WRITE_RESP;
            end
        end
        STATE_WRITE_DROP: begin
            // write drop state; drop write data
            s_axil_wready_next[s_select] = 1'b1;

            axil_addr_valid_next = 1'b0;

            if (current_s_axil_wready && current_s_axil_wvalid) begin
                s_axil_wready_next[s_select] = 1'b0;
                s_axil_bvalid_next[s_select] = 1'b1;
                state_next = STATE_WAIT_IDLE;
            end else begin
                state_next = STATE_WRITE_DROP;
            end
        end
        STATE_READ: begin
            // read state; store and forward read response
            m_axil_rready_next[m_select_reg] = 1'b1;

            if (axil_addr_valid_reg) begin
                m_axil_arvalid_next[m_select_reg] = 1'b1;
            end
            axil_addr_valid_next = 1'b0;

            if (current_m_axil_rready && current_m_axil_rvalid) begin
                m_axil_rready_next[m_select_reg] = 1'b0;
                axil_data_next = current_m_axil_rdata;
                axil_resp_next = current_m_axil_rresp;
                s_axil_rvalid_next[s_select] = 1'b1;
                state_next = STATE_WAIT_IDLE;
            end else begin
                state_next = STATE_READ;
            end
        end
        STATE_WAIT_IDLE: begin
            // wait for idle state; wait untl grant valid is deasserted

            if (!grant_valid || acknowledge) begin
                state_next = STATE_IDLE;
            end else begin
                state_next = STATE_WAIT_IDLE;
            end
        end
    endcase
end

always @(posedge clk) begin
    if (rst) begin
        state_reg <= STATE_IDLE;

        s_axil_awready_reg <= 0;
        s_axil_wready_reg <= 0;
        s_axil_bvalid_reg <= 0;
        s_axil_arready_reg <= 0;
        s_axil_rvalid_reg <= 0;

        m_axil_awvalid_reg <= 0;
        m_axil_wvalid_reg <= 0;
        m_axil_bready_reg <= 0;
        m_axil_arvalid_reg <= 0;
        m_axil_rready_reg <= 0;
    end else begin
        state_reg <= state_next;

        s_axil_awready_reg <= s_axil_awready_next;
        s_axil_wready_reg <= s_axil_wready_next;
        s_axil_bvalid_reg <= s_axil_bvalid_next;
        s_axil_arready_reg <= s_axil_arready_next;
        s_axil_rvalid_reg <= s_axil_rvalid_next;

        m_axil_awvalid_reg <= m_axil_awvalid_next;
        m_axil_wvalid_reg <= m_axil_wvalid_next;
        m_axil_bready_reg <= m_axil_bready_next;
        m_axil_arvalid_reg <= m_axil_arvalid_next;
        m_axil_rready_reg <= m_axil_rready_next;
    end

    m_select_reg <= m_select_next;
    axil_addr_reg <= axil_addr_next;
    axil_addr_valid_reg <= axil_addr_valid_next;
    axil_prot_reg <= axil_prot_next;
    axil_data_reg <= axil_data_next;
    axil_wstrb_reg <= axil_wstrb_next;
    axil_resp_reg <= axil_resp_next;
end

endmodule

`resetall
