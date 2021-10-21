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
 * AXI4 crossbar (write)
 */
module axi_crossbar_wr #
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
    // Input ID field width (from AXI masters)
    parameter S_ID_WIDTH = 8,
    // Output ID field width (towards AXI slaves)
    // Additional bits required for response routing
    parameter M_ID_WIDTH = S_ID_WIDTH+$clog2(S_COUNT),
    // Propagate awuser signal
    parameter AWUSER_ENABLE = 0,
    // Width of awuser signal
    parameter AWUSER_WIDTH = 1,
    // Propagate wuser signal
    parameter WUSER_ENABLE = 0,
    // Width of wuser signal
    parameter WUSER_WIDTH = 1,
    // Propagate buser signal
    parameter BUSER_ENABLE = 0,
    // Width of buser signal
    parameter BUSER_WIDTH = 1,
    // Number of concurrent unique IDs for each slave interface
    // S_COUNT concatenated fields of 32 bits
    parameter S_THREADS = {S_COUNT{32'd2}},
    // Number of concurrent operations for each slave interface
    // S_COUNT concatenated fields of 32 bits
    parameter S_ACCEPT = {S_COUNT{32'd16}},
    // Number of regions per master interface
    parameter M_REGIONS = 1,
    // Master interface base addresses
    // M_COUNT concatenated fields of M_REGIONS concatenated fields of ADDR_WIDTH bits
    // set to zero for default addressing based on M_ADDR_WIDTH
    parameter M_BASE_ADDR = 0,
    // Master interface address widths
    // M_COUNT concatenated fields of M_REGIONS concatenated fields of 32 bits
    parameter M_ADDR_WIDTH = {M_COUNT{{M_REGIONS{32'd24}}}},
    // Write connections between interfaces
    // M_COUNT concatenated fields of S_COUNT bits
    parameter M_CONNECT = {M_COUNT{{S_COUNT{1'b1}}}},
    // Number of concurrent operations for each master interface
    // M_COUNT concatenated fields of 32 bits
    parameter M_ISSUE = {M_COUNT{32'd4}},
    // Secure master (fail operations based on awprot/arprot)
    // M_COUNT bits
    parameter M_SECURE = {M_COUNT{1'b0}},
    // Slave interface AW channel register type (input)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter S_AW_REG_TYPE = {S_COUNT{2'd0}},
    // Slave interface W channel register type (input)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter S_W_REG_TYPE = {S_COUNT{2'd0}},
    // Slave interface B channel register type (output)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter S_B_REG_TYPE = {S_COUNT{2'd1}},
    // Master interface AW channel register type (output)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter M_AW_REG_TYPE = {M_COUNT{2'd1}},
    // Master interface W channel register type (output)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter M_W_REG_TYPE = {M_COUNT{2'd2}},
    // Master interface B channel register type (input)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter M_B_REG_TYPE = {M_COUNT{2'd0}}
)
(
    input  wire                             clk,
    input  wire                             rst,

    /*
     * AXI slave interfaces
     */
    input  wire [S_COUNT*S_ID_WIDTH-1:0]    s_axi_awid,
    input  wire [S_COUNT*ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  wire [S_COUNT*8-1:0]             s_axi_awlen,
    input  wire [S_COUNT*3-1:0]             s_axi_awsize,
    input  wire [S_COUNT*2-1:0]             s_axi_awburst,
    input  wire [S_COUNT-1:0]               s_axi_awlock,
    input  wire [S_COUNT*4-1:0]             s_axi_awcache,
    input  wire [S_COUNT*3-1:0]             s_axi_awprot,
    input  wire [S_COUNT*4-1:0]             s_axi_awqos,
    input  wire [S_COUNT*AWUSER_WIDTH-1:0]  s_axi_awuser,
    input  wire [S_COUNT-1:0]               s_axi_awvalid,
    output wire [S_COUNT-1:0]               s_axi_awready,
    input  wire [S_COUNT*DATA_WIDTH-1:0]    s_axi_wdata,
    input  wire [S_COUNT*STRB_WIDTH-1:0]    s_axi_wstrb,
    input  wire [S_COUNT-1:0]               s_axi_wlast,
    input  wire [S_COUNT*WUSER_WIDTH-1:0]   s_axi_wuser,
    input  wire [S_COUNT-1:0]               s_axi_wvalid,
    output wire [S_COUNT-1:0]               s_axi_wready,
    output wire [S_COUNT*S_ID_WIDTH-1:0]    s_axi_bid,
    output wire [S_COUNT*2-1:0]             s_axi_bresp,
    output wire [S_COUNT*BUSER_WIDTH-1:0]   s_axi_buser,
    output wire [S_COUNT-1:0]               s_axi_bvalid,
    input  wire [S_COUNT-1:0]               s_axi_bready,

    /*
     * AXI master interfaces
     */
    output wire [M_COUNT*M_ID_WIDTH-1:0]    m_axi_awid,
    output wire [M_COUNT*ADDR_WIDTH-1:0]    m_axi_awaddr,
    output wire [M_COUNT*8-1:0]             m_axi_awlen,
    output wire [M_COUNT*3-1:0]             m_axi_awsize,
    output wire [M_COUNT*2-1:0]             m_axi_awburst,
    output wire [M_COUNT-1:0]               m_axi_awlock,
    output wire [M_COUNT*4-1:0]             m_axi_awcache,
    output wire [M_COUNT*3-1:0]             m_axi_awprot,
    output wire [M_COUNT*4-1:0]             m_axi_awqos,
    output wire [M_COUNT*4-1:0]             m_axi_awregion,
    output wire [M_COUNT*AWUSER_WIDTH-1:0]  m_axi_awuser,
    output wire [M_COUNT-1:0]               m_axi_awvalid,
    input  wire [M_COUNT-1:0]               m_axi_awready,
    output wire [M_COUNT*DATA_WIDTH-1:0]    m_axi_wdata,
    output wire [M_COUNT*STRB_WIDTH-1:0]    m_axi_wstrb,
    output wire [M_COUNT-1:0]               m_axi_wlast,
    output wire [M_COUNT*WUSER_WIDTH-1:0]   m_axi_wuser,
    output wire [M_COUNT-1:0]               m_axi_wvalid,
    input  wire [M_COUNT-1:0]               m_axi_wready,
    input  wire [M_COUNT*M_ID_WIDTH-1:0]    m_axi_bid,
    input  wire [M_COUNT*2-1:0]             m_axi_bresp,
    input  wire [M_COUNT*BUSER_WIDTH-1:0]   m_axi_buser,
    input  wire [M_COUNT-1:0]               m_axi_bvalid,
    output wire [M_COUNT-1:0]               m_axi_bready
);

parameter CL_S_COUNT = $clog2(S_COUNT);
parameter CL_M_COUNT = $clog2(M_COUNT);
parameter M_COUNT_P1 = M_COUNT+1;
parameter CL_M_COUNT_P1 = $clog2(M_COUNT_P1);

integer i;

// check configuration
initial begin
    if (M_ID_WIDTH < S_ID_WIDTH+$clog2(S_COUNT)) begin
        $error("Error: M_ID_WIDTH must be at least $clog2(S_COUNT) larger than S_ID_WIDTH (instance %m)");
        $finish;
    end

    for (i = 0; i < M_COUNT*M_REGIONS; i = i + 1) begin
        if (M_ADDR_WIDTH[i*32 +: 32] && (M_ADDR_WIDTH[i*32 +: 32] < 12 || M_ADDR_WIDTH[i*32 +: 32] > ADDR_WIDTH)) begin
            $error("Error: value out of range (instance %m)");
            $finish;
        end
    end
end

wire [S_COUNT*S_ID_WIDTH-1:0]    int_s_axi_awid;
wire [S_COUNT*ADDR_WIDTH-1:0]    int_s_axi_awaddr;
wire [S_COUNT*8-1:0]             int_s_axi_awlen;
wire [S_COUNT*3-1:0]             int_s_axi_awsize;
wire [S_COUNT*2-1:0]             int_s_axi_awburst;
wire [S_COUNT-1:0]               int_s_axi_awlock;
wire [S_COUNT*4-1:0]             int_s_axi_awcache;
wire [S_COUNT*3-1:0]             int_s_axi_awprot;
wire [S_COUNT*4-1:0]             int_s_axi_awqos;
wire [S_COUNT*4-1:0]             int_s_axi_awregion;
wire [S_COUNT*AWUSER_WIDTH-1:0]  int_s_axi_awuser;
wire [S_COUNT-1:0]               int_s_axi_awvalid;
wire [S_COUNT-1:0]               int_s_axi_awready;

wire [S_COUNT*M_COUNT-1:0]       int_axi_awvalid;
wire [M_COUNT*S_COUNT-1:0]       int_axi_awready;

wire [S_COUNT*DATA_WIDTH-1:0]    int_s_axi_wdata;
wire [S_COUNT*STRB_WIDTH-1:0]    int_s_axi_wstrb;
wire [S_COUNT-1:0]               int_s_axi_wlast;
wire [S_COUNT*WUSER_WIDTH-1:0]   int_s_axi_wuser;
wire [S_COUNT-1:0]               int_s_axi_wvalid;
wire [S_COUNT-1:0]               int_s_axi_wready;

wire [S_COUNT*M_COUNT-1:0]       int_axi_wvalid;
wire [M_COUNT*S_COUNT-1:0]       int_axi_wready;

wire [M_COUNT*M_ID_WIDTH-1:0]    int_m_axi_bid;
wire [M_COUNT*2-1:0]             int_m_axi_bresp;
wire [M_COUNT*BUSER_WIDTH-1:0]   int_m_axi_buser;
wire [M_COUNT-1:0]               int_m_axi_bvalid;
wire [M_COUNT-1:0]               int_m_axi_bready;

wire [M_COUNT*S_COUNT-1:0]       int_axi_bvalid;
wire [S_COUNT*M_COUNT-1:0]       int_axi_bready;

generate

    genvar m, n;

    for (m = 0; m < S_COUNT; m = m + 1) begin : s_ifaces
        // address decode and admission control
        wire [CL_M_COUNT-1:0] a_select;

        wire m_axi_avalid;
        wire m_axi_aready;

        wire [CL_M_COUNT-1:0] m_wc_select;
        wire m_wc_decerr;
        wire m_wc_valid;
        wire m_wc_ready;

        wire m_rc_decerr;
        wire m_rc_valid;
        wire m_rc_ready;

        wire [S_ID_WIDTH-1:0] s_cpl_id;
        wire s_cpl_valid;

        axi_crossbar_addr #(
            .S(m),
            .S_COUNT(S_COUNT),
            .M_COUNT(M_COUNT),
            .ADDR_WIDTH(ADDR_WIDTH),
            .ID_WIDTH(S_ID_WIDTH),
            .S_THREADS(S_THREADS[m*32 +: 32]),
            .S_ACCEPT(S_ACCEPT[m*32 +: 32]),
            .M_REGIONS(M_REGIONS),
            .M_BASE_ADDR(M_BASE_ADDR),
            .M_ADDR_WIDTH(M_ADDR_WIDTH),
            .M_CONNECT(M_CONNECT),
            .M_SECURE(M_SECURE),
            .WC_OUTPUT(1)
        )
        addr_inst (
            .clk(clk),
            .rst(rst),

            /*
             * Address input
             */
            .s_axi_aid(int_s_axi_awid[m*S_ID_WIDTH +: S_ID_WIDTH]),
            .s_axi_aaddr(int_s_axi_awaddr[m*ADDR_WIDTH +: ADDR_WIDTH]),
            .s_axi_aprot(int_s_axi_awprot[m*3 +: 3]),
            .s_axi_aqos(int_s_axi_awqos[m*4 +: 4]),
            .s_axi_avalid(int_s_axi_awvalid[m]),
            .s_axi_aready(int_s_axi_awready[m]),

            /*
             * Address output
             */
            .m_axi_aregion(int_s_axi_awregion[m*4 +: 4]),
            .m_select(a_select),
            .m_axi_avalid(m_axi_avalid),
            .m_axi_aready(m_axi_aready),

            /*
             * Write command output
             */
            .m_wc_select(m_wc_select),
            .m_wc_decerr(m_wc_decerr),
            .m_wc_valid(m_wc_valid),
            .m_wc_ready(m_wc_ready),

            /*
             * Response command output
             */
            .m_rc_decerr(m_rc_decerr),
            .m_rc_valid(m_rc_valid),
            .m_rc_ready(m_rc_ready),

            /*
             * Completion input
             */
            .s_cpl_id(s_cpl_id),
            .s_cpl_valid(s_cpl_valid)
        );

        assign int_axi_awvalid[m*M_COUNT +: M_COUNT] = m_axi_avalid << a_select;
        assign m_axi_aready = int_axi_awready[a_select*S_COUNT+m];

        // write command handling
        reg [CL_M_COUNT-1:0] w_select_reg = 0, w_select_next;
        reg w_drop_reg = 1'b0, w_drop_next;
        reg w_select_valid_reg = 1'b0, w_select_valid_next;

        assign m_wc_ready = !w_select_valid_reg;

        always @* begin
            w_select_next = w_select_reg;
            w_drop_next = w_drop_reg && !(int_s_axi_wvalid[m] && int_s_axi_wready[m] && int_s_axi_wlast[m]);
            w_select_valid_next = w_select_valid_reg && !(int_s_axi_wvalid[m] && int_s_axi_wready[m] && int_s_axi_wlast[m]);

            if (m_wc_valid && !w_select_valid_reg) begin
                w_select_next = m_wc_select;
                w_drop_next = m_wc_decerr;
                w_select_valid_next = m_wc_valid;
            end
        end

        always @(posedge clk) begin
            if (rst) begin
                w_select_valid_reg <= 1'b0;
            end else begin
                w_select_valid_reg <= w_select_valid_next;
            end

            w_select_reg <= w_select_next;
            w_drop_reg <= w_drop_next;
        end

        // write data forwarding
        assign int_axi_wvalid[m*M_COUNT +: M_COUNT] = (int_s_axi_wvalid[m] && w_select_valid_reg && !w_drop_reg) << w_select_reg;
        assign int_s_axi_wready[m] = int_axi_wready[w_select_reg*S_COUNT+m] || w_drop_reg;

        // decode error handling
        reg [S_ID_WIDTH-1:0]  decerr_m_axi_bid_reg = {S_ID_WIDTH{1'b0}}, decerr_m_axi_bid_next;
        reg                   decerr_m_axi_bvalid_reg = 1'b0, decerr_m_axi_bvalid_next;
        wire                  decerr_m_axi_bready;

        assign m_rc_ready = !decerr_m_axi_bvalid_reg;

        always @* begin
            decerr_m_axi_bid_next = decerr_m_axi_bid_reg;
            decerr_m_axi_bvalid_next = decerr_m_axi_bvalid_reg;

            if (decerr_m_axi_bvalid_reg) begin
                if (decerr_m_axi_bready) begin
                    decerr_m_axi_bvalid_next = 1'b0;
                end
            end else if (m_rc_valid && m_rc_ready) begin
                decerr_m_axi_bid_next = int_s_axi_awid[m*S_ID_WIDTH +: S_ID_WIDTH];
                decerr_m_axi_bvalid_next = 1'b1;
            end
        end

        always @(posedge clk) begin
            if (rst) begin
                decerr_m_axi_bvalid_reg <= 1'b0;
            end else begin
                decerr_m_axi_bvalid_reg <= decerr_m_axi_bvalid_next;
            end

            decerr_m_axi_bid_reg <= decerr_m_axi_bid_next;
        end

        // write response arbitration
        wire [M_COUNT_P1-1:0] b_request;
        wire [M_COUNT_P1-1:0] b_acknowledge;
        wire [M_COUNT_P1-1:0] b_grant;
        wire b_grant_valid;
        wire [CL_M_COUNT_P1-1:0] b_grant_encoded;

        arbiter #(
            .PORTS(M_COUNT_P1),
            .ARB_TYPE_ROUND_ROBIN(1),
            .ARB_BLOCK(1),
            .ARB_BLOCK_ACK(1),
            .ARB_LSB_HIGH_PRIORITY(1)
        )
        b_arb_inst (
            .clk(clk),
            .rst(rst),
            .request(b_request),
            .acknowledge(b_acknowledge),
            .grant(b_grant),
            .grant_valid(b_grant_valid),
            .grant_encoded(b_grant_encoded)
        );

        // write response mux
        wire [S_ID_WIDTH-1:0]  m_axi_bid_mux    = {decerr_m_axi_bid_reg, int_m_axi_bid} >> b_grant_encoded*M_ID_WIDTH;
        wire [1:0]             m_axi_bresp_mux  = {2'b11, int_m_axi_bresp} >> b_grant_encoded*2;
        wire [BUSER_WIDTH-1:0] m_axi_buser_mux  = {{BUSER_WIDTH{1'b0}}, int_m_axi_buser} >> b_grant_encoded*BUSER_WIDTH;
        wire                   m_axi_bvalid_mux = ({decerr_m_axi_bvalid_reg, int_m_axi_bvalid} >> b_grant_encoded) & b_grant_valid;
        wire                   m_axi_bready_mux;

        assign int_axi_bready[m*M_COUNT +: M_COUNT] = (b_grant_valid && m_axi_bready_mux) << b_grant_encoded;
        assign decerr_m_axi_bready = (b_grant_valid && m_axi_bready_mux) && (b_grant_encoded == M_COUNT_P1-1);

        for (n = 0; n < M_COUNT; n = n + 1) begin
            assign b_request[n] = int_axi_bvalid[n*S_COUNT+m] && !b_grant[n];
            assign b_acknowledge[n] = b_grant[n] && int_axi_bvalid[n*S_COUNT+m] && m_axi_bready_mux;
        end

        assign b_request[M_COUNT_P1-1] = decerr_m_axi_bvalid_reg && !b_grant[M_COUNT_P1-1];
        assign b_acknowledge[M_COUNT_P1-1] = b_grant[M_COUNT_P1-1] && decerr_m_axi_bvalid_reg && m_axi_bready_mux;

        assign s_cpl_id = m_axi_bid_mux;
        assign s_cpl_valid = m_axi_bvalid_mux && m_axi_bready_mux;

        // S side register
        axi_register_wr #(
            .DATA_WIDTH(DATA_WIDTH),
            .ADDR_WIDTH(ADDR_WIDTH),
            .STRB_WIDTH(STRB_WIDTH),
            .ID_WIDTH(S_ID_WIDTH),
            .AWUSER_ENABLE(AWUSER_ENABLE),
            .AWUSER_WIDTH(AWUSER_WIDTH),
            .WUSER_ENABLE(WUSER_ENABLE),
            .WUSER_WIDTH(WUSER_WIDTH),
            .BUSER_ENABLE(BUSER_ENABLE),
            .BUSER_WIDTH(BUSER_WIDTH),
            .AW_REG_TYPE(S_AW_REG_TYPE[m*2 +: 2]),
            .W_REG_TYPE(S_W_REG_TYPE[m*2 +: 2]),
            .B_REG_TYPE(S_B_REG_TYPE[m*2 +: 2])
        )
        reg_inst (
            .clk(clk),
            .rst(rst),
            .s_axi_awid(s_axi_awid[m*S_ID_WIDTH +: S_ID_WIDTH]),
            .s_axi_awaddr(s_axi_awaddr[m*ADDR_WIDTH +: ADDR_WIDTH]),
            .s_axi_awlen(s_axi_awlen[m*8 +: 8]),
            .s_axi_awsize(s_axi_awsize[m*3 +: 3]),
            .s_axi_awburst(s_axi_awburst[m*2 +: 2]),
            .s_axi_awlock(s_axi_awlock[m]),
            .s_axi_awcache(s_axi_awcache[m*4 +: 4]),
            .s_axi_awprot(s_axi_awprot[m*3 +: 3]),
            .s_axi_awqos(s_axi_awqos[m*4 +: 4]),
            .s_axi_awregion(4'd0),
            .s_axi_awuser(s_axi_awuser[m*AWUSER_WIDTH +: AWUSER_WIDTH]),
            .s_axi_awvalid(s_axi_awvalid[m]),
            .s_axi_awready(s_axi_awready[m]),
            .s_axi_wdata(s_axi_wdata[m*DATA_WIDTH +: DATA_WIDTH]),
            .s_axi_wstrb(s_axi_wstrb[m*STRB_WIDTH +: STRB_WIDTH]),
            .s_axi_wlast(s_axi_wlast[m]),
            .s_axi_wuser(s_axi_wuser[m*WUSER_WIDTH +: WUSER_WIDTH]),
            .s_axi_wvalid(s_axi_wvalid[m]),
            .s_axi_wready(s_axi_wready[m]),
            .s_axi_bid(s_axi_bid[m*S_ID_WIDTH +: S_ID_WIDTH]),
            .s_axi_bresp(s_axi_bresp[m*2 +: 2]),
            .s_axi_buser(s_axi_buser[m*BUSER_WIDTH +: BUSER_WIDTH]),
            .s_axi_bvalid(s_axi_bvalid[m]),
            .s_axi_bready(s_axi_bready[m]),
            .m_axi_awid(int_s_axi_awid[m*S_ID_WIDTH +: S_ID_WIDTH]),
            .m_axi_awaddr(int_s_axi_awaddr[m*ADDR_WIDTH +: ADDR_WIDTH]),
            .m_axi_awlen(int_s_axi_awlen[m*8 +: 8]),
            .m_axi_awsize(int_s_axi_awsize[m*3 +: 3]),
            .m_axi_awburst(int_s_axi_awburst[m*2 +: 2]),
            .m_axi_awlock(int_s_axi_awlock[m]),
            .m_axi_awcache(int_s_axi_awcache[m*4 +: 4]),
            .m_axi_awprot(int_s_axi_awprot[m*3 +: 3]),
            .m_axi_awqos(int_s_axi_awqos[m*4 +: 4]),
            .m_axi_awregion(),
            .m_axi_awuser(int_s_axi_awuser[m*AWUSER_WIDTH +: AWUSER_WIDTH]),
            .m_axi_awvalid(int_s_axi_awvalid[m]),
            .m_axi_awready(int_s_axi_awready[m]),
            .m_axi_wdata(int_s_axi_wdata[m*DATA_WIDTH +: DATA_WIDTH]),
            .m_axi_wstrb(int_s_axi_wstrb[m*STRB_WIDTH +: STRB_WIDTH]),
            .m_axi_wlast(int_s_axi_wlast[m]),
            .m_axi_wuser(int_s_axi_wuser[m*WUSER_WIDTH +: WUSER_WIDTH]),
            .m_axi_wvalid(int_s_axi_wvalid[m]),
            .m_axi_wready(int_s_axi_wready[m]),
            .m_axi_bid(m_axi_bid_mux),
            .m_axi_bresp(m_axi_bresp_mux),
            .m_axi_buser(m_axi_buser_mux),
            .m_axi_bvalid(m_axi_bvalid_mux),
            .m_axi_bready(m_axi_bready_mux)
        );
    end // s_ifaces

    for (n = 0; n < M_COUNT; n = n + 1) begin : m_ifaces
        // in-flight transaction count
        wire trans_start;
        wire trans_complete;
        reg [$clog2(M_ISSUE[n*32 +: 32]+1)-1:0] trans_count_reg = 0;

        wire trans_limit = trans_count_reg >= M_ISSUE[n*32 +: 32] && !trans_complete;

        always @(posedge clk) begin
            if (rst) begin
                trans_count_reg <= 0;
            end else begin
                if (trans_start && !trans_complete) begin
                    trans_count_reg <= trans_count_reg + 1;
                end else if (!trans_start && trans_complete) begin
                    trans_count_reg <= trans_count_reg - 1;
                end
            end
        end

        // address arbitration
        reg [CL_S_COUNT-1:0] w_select_reg = 0, w_select_next;
        reg w_select_valid_reg = 1'b0, w_select_valid_next;
        reg w_select_new_reg = 1'b0, w_select_new_next;

        wire [S_COUNT-1:0] a_request;
        wire [S_COUNT-1:0] a_acknowledge;
        wire [S_COUNT-1:0] a_grant;
        wire a_grant_valid;
        wire [CL_S_COUNT-1:0] a_grant_encoded;

        arbiter #(
            .PORTS(S_COUNT),
            .ARB_TYPE_ROUND_ROBIN(1),
            .ARB_BLOCK(1),
            .ARB_BLOCK_ACK(1),
            .ARB_LSB_HIGH_PRIORITY(1)
        )
        a_arb_inst (
            .clk(clk),
            .rst(rst),
            .request(a_request),
            .acknowledge(a_acknowledge),
            .grant(a_grant),
            .grant_valid(a_grant_valid),
            .grant_encoded(a_grant_encoded)
        );

        // address mux
        wire [M_ID_WIDTH-1:0]   s_axi_awid_mux     = int_s_axi_awid[a_grant_encoded*S_ID_WIDTH +: S_ID_WIDTH] | (a_grant_encoded << S_ID_WIDTH);
        wire [ADDR_WIDTH-1:0]   s_axi_awaddr_mux   = int_s_axi_awaddr[a_grant_encoded*ADDR_WIDTH +: ADDR_WIDTH];
        wire [7:0]              s_axi_awlen_mux    = int_s_axi_awlen[a_grant_encoded*8 +: 8];
        wire [2:0]              s_axi_awsize_mux   = int_s_axi_awsize[a_grant_encoded*3 +: 3];
        wire [1:0]              s_axi_awburst_mux  = int_s_axi_awburst[a_grant_encoded*2 +: 2];
        wire                    s_axi_awlock_mux   = int_s_axi_awlock[a_grant_encoded];
        wire [3:0]              s_axi_awcache_mux  = int_s_axi_awcache[a_grant_encoded*4 +: 4];
        wire [2:0]              s_axi_awprot_mux   = int_s_axi_awprot[a_grant_encoded*3 +: 3];
        wire [3:0]              s_axi_awqos_mux    = int_s_axi_awqos[a_grant_encoded*4 +: 4];
        wire [3:0]              s_axi_awregion_mux = int_s_axi_awregion[a_grant_encoded*4 +: 4];
        wire [AWUSER_WIDTH-1:0] s_axi_awuser_mux   = int_s_axi_awuser[a_grant_encoded*AWUSER_WIDTH +: AWUSER_WIDTH];
        wire                    s_axi_awvalid_mux  = int_axi_awvalid[a_grant_encoded*M_COUNT+n] && a_grant_valid;
        wire                    s_axi_awready_mux;

        assign int_axi_awready[n*S_COUNT +: S_COUNT] = (a_grant_valid && s_axi_awready_mux) << a_grant_encoded;

        for (m = 0; m < S_COUNT; m = m + 1) begin
            assign a_request[m] = int_axi_awvalid[m*M_COUNT+n] && !a_grant[m] && !trans_limit && !w_select_valid_next;
            assign a_acknowledge[m] = a_grant[m] && int_axi_awvalid[m*M_COUNT+n] && s_axi_awready_mux;
        end

        assign trans_start = s_axi_awvalid_mux && s_axi_awready_mux && a_grant_valid;

        // write data mux
        wire [DATA_WIDTH-1:0]  s_axi_wdata_mux   = int_s_axi_wdata[w_select_reg*DATA_WIDTH +: DATA_WIDTH];
        wire [STRB_WIDTH-1:0]  s_axi_wstrb_mux   = int_s_axi_wstrb[w_select_reg*STRB_WIDTH +: STRB_WIDTH];
        wire                   s_axi_wlast_mux   = int_s_axi_wlast[w_select_reg];
        wire [WUSER_WIDTH-1:0] s_axi_wuser_mux   = int_s_axi_wuser[w_select_reg*WUSER_WIDTH +: WUSER_WIDTH];
        wire                   s_axi_wvalid_mux  = int_axi_wvalid[w_select_reg*M_COUNT+n] && w_select_valid_reg;
        wire                   s_axi_wready_mux;

        assign int_axi_wready[n*S_COUNT +: S_COUNT] = (w_select_valid_reg && s_axi_wready_mux) << w_select_reg;

        // write data routing
        always @* begin
            w_select_next = w_select_reg;
            w_select_valid_next = w_select_valid_reg && !(s_axi_wvalid_mux && s_axi_wready_mux && s_axi_wlast_mux);
            w_select_new_next = w_select_new_reg || !a_grant_valid || a_acknowledge;

            if (a_grant_valid && !w_select_valid_reg && w_select_new_reg) begin
                w_select_next = a_grant_encoded;
                w_select_valid_next = a_grant_valid;
                w_select_new_next = 1'b0;
            end
        end

        always @(posedge clk) begin
            if (rst) begin
                w_select_valid_reg <= 1'b0;
                w_select_new_reg <= 1'b1;
            end else begin
                w_select_valid_reg <= w_select_valid_next;
                w_select_new_reg <= w_select_new_next;
            end

            w_select_reg <= w_select_next;
        end

        // write response forwarding
        wire [CL_S_COUNT-1:0] b_select = m_axi_bid[n*M_ID_WIDTH +: M_ID_WIDTH] >> S_ID_WIDTH;

        assign int_axi_bvalid[n*S_COUNT +: S_COUNT] = int_m_axi_bvalid[n] << b_select;
        assign int_m_axi_bready[n] = int_axi_bready[b_select*M_COUNT+n];

        assign trans_complete = int_m_axi_bvalid[n] && int_m_axi_bready[n];

        // M side register
        axi_register_wr #(
            .DATA_WIDTH(DATA_WIDTH),
            .ADDR_WIDTH(ADDR_WIDTH),
            .STRB_WIDTH(STRB_WIDTH),
            .ID_WIDTH(M_ID_WIDTH),
            .AWUSER_ENABLE(AWUSER_ENABLE),
            .AWUSER_WIDTH(AWUSER_WIDTH),
            .WUSER_ENABLE(WUSER_ENABLE),
            .WUSER_WIDTH(WUSER_WIDTH),
            .BUSER_ENABLE(BUSER_ENABLE),
            .BUSER_WIDTH(BUSER_WIDTH),
            .AW_REG_TYPE(M_AW_REG_TYPE[n*2 +: 2]),
            .W_REG_TYPE(M_W_REG_TYPE[n*2 +: 2]),
            .B_REG_TYPE(M_B_REG_TYPE[n*2 +: 2])
        )
        reg_inst (
            .clk(clk),
            .rst(rst),
            .s_axi_awid(s_axi_awid_mux),
            .s_axi_awaddr(s_axi_awaddr_mux),
            .s_axi_awlen(s_axi_awlen_mux),
            .s_axi_awsize(s_axi_awsize_mux),
            .s_axi_awburst(s_axi_awburst_mux),
            .s_axi_awlock(s_axi_awlock_mux),
            .s_axi_awcache(s_axi_awcache_mux),
            .s_axi_awprot(s_axi_awprot_mux),
            .s_axi_awqos(s_axi_awqos_mux),
            .s_axi_awregion(s_axi_awregion_mux),
            .s_axi_awuser(s_axi_awuser_mux),
            .s_axi_awvalid(s_axi_awvalid_mux),
            .s_axi_awready(s_axi_awready_mux),
            .s_axi_wdata(s_axi_wdata_mux),
            .s_axi_wstrb(s_axi_wstrb_mux),
            .s_axi_wlast(s_axi_wlast_mux),
            .s_axi_wuser(s_axi_wuser_mux),
            .s_axi_wvalid(s_axi_wvalid_mux),
            .s_axi_wready(s_axi_wready_mux),
            .s_axi_bid(int_m_axi_bid[n*M_ID_WIDTH +: M_ID_WIDTH]),
            .s_axi_bresp(int_m_axi_bresp[n*2 +: 2]),
            .s_axi_buser(int_m_axi_buser[n*BUSER_WIDTH +: BUSER_WIDTH]),
            .s_axi_bvalid(int_m_axi_bvalid[n]),
            .s_axi_bready(int_m_axi_bready[n]),
            .m_axi_awid(m_axi_awid[n*M_ID_WIDTH +: M_ID_WIDTH]),
            .m_axi_awaddr(m_axi_awaddr[n*ADDR_WIDTH +: ADDR_WIDTH]),
            .m_axi_awlen(m_axi_awlen[n*8 +: 8]),
            .m_axi_awsize(m_axi_awsize[n*3 +: 3]),
            .m_axi_awburst(m_axi_awburst[n*2 +: 2]),
            .m_axi_awlock(m_axi_awlock[n]),
            .m_axi_awcache(m_axi_awcache[n*4 +: 4]),
            .m_axi_awprot(m_axi_awprot[n*3 +: 3]),
            .m_axi_awqos(m_axi_awqos[n*4 +: 4]),
            .m_axi_awregion(m_axi_awregion[n*4 +: 4]),
            .m_axi_awuser(m_axi_awuser[n*AWUSER_WIDTH +: AWUSER_WIDTH]),
            .m_axi_awvalid(m_axi_awvalid[n]),
            .m_axi_awready(m_axi_awready[n]),
            .m_axi_wdata(m_axi_wdata[n*DATA_WIDTH +: DATA_WIDTH]),
            .m_axi_wstrb(m_axi_wstrb[n*STRB_WIDTH +: STRB_WIDTH]),
            .m_axi_wlast(m_axi_wlast[n]),
            .m_axi_wuser(m_axi_wuser[n*WUSER_WIDTH +: WUSER_WIDTH]),
            .m_axi_wvalid(m_axi_wvalid[n]),
            .m_axi_wready(m_axi_wready[n]),
            .m_axi_bid(m_axi_bid[n*M_ID_WIDTH +: M_ID_WIDTH]),
            .m_axi_bresp(m_axi_bresp[n*2 +: 2]),
            .m_axi_buser(m_axi_buser[n*BUSER_WIDTH +: BUSER_WIDTH]),
            .m_axi_bvalid(m_axi_bvalid[n]),
            .m_axi_bready(m_axi_bready[n])
        );
    end // m_ifaces

endgenerate

endmodule

`resetall
