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
 * AXI4 crossbar (read)
 */
module axi_crossbar_rd #
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
    // Propagate aruser signal
    parameter ARUSER_ENABLE = 0,
    // Width of aruser signal
    parameter ARUSER_WIDTH = 1,
    // Propagate ruser signal
    parameter RUSER_ENABLE = 0,
    // Width of ruser signal
    parameter RUSER_WIDTH = 1,
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
    // Read connections between interfaces
    // M_COUNT concatenated fields of S_COUNT bits
    parameter M_CONNECT = {M_COUNT{{S_COUNT{1'b1}}}},
    // Number of concurrent operations for each master interface
    // M_COUNT concatenated fields of 32 bits
    parameter M_ISSUE = {M_COUNT{32'd4}},
    // Secure master (fail operations based on awprot/arprot)
    // M_COUNT bits
    parameter M_SECURE = {M_COUNT{1'b0}},
    // Slave interface AR channel register type (input)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter S_AR_REG_TYPE = {S_COUNT{2'd0}},
    // Slave interface R channel register type (output)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter S_R_REG_TYPE = {S_COUNT{2'd2}},
    // Master interface AR channel register type (output)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter M_AR_REG_TYPE = {M_COUNT{2'd1}},
    // Master interface R channel register type (input)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter M_R_REG_TYPE = {M_COUNT{2'd0}}
)
(
    input  wire                             clk,
    input  wire                             rst,

    /*
     * AXI slave interfaces
     */
    input  wire [S_COUNT*S_ID_WIDTH-1:0]    s_axi_arid,
    input  wire [S_COUNT*ADDR_WIDTH-1:0]    s_axi_araddr,
    input  wire [S_COUNT*8-1:0]             s_axi_arlen,
    input  wire [S_COUNT*3-1:0]             s_axi_arsize,
    input  wire [S_COUNT*2-1:0]             s_axi_arburst,
    input  wire [S_COUNT-1:0]               s_axi_arlock,
    input  wire [S_COUNT*4-1:0]             s_axi_arcache,
    input  wire [S_COUNT*3-1:0]             s_axi_arprot,
    input  wire [S_COUNT*4-1:0]             s_axi_arqos,
    input  wire [S_COUNT*ARUSER_WIDTH-1:0]  s_axi_aruser,
    input  wire [S_COUNT-1:0]               s_axi_arvalid,
    output wire [S_COUNT-1:0]               s_axi_arready,
    output wire [S_COUNT*S_ID_WIDTH-1:0]    s_axi_rid,
    output wire [S_COUNT*DATA_WIDTH-1:0]    s_axi_rdata,
    output wire [S_COUNT*2-1:0]             s_axi_rresp,
    output wire [S_COUNT-1:0]               s_axi_rlast,
    output wire [S_COUNT*RUSER_WIDTH-1:0]   s_axi_ruser,
    output wire [S_COUNT-1:0]               s_axi_rvalid,
    input  wire [S_COUNT-1:0]               s_axi_rready,

    /*
     * AXI master interfaces
     */
    output wire [M_COUNT*M_ID_WIDTH-1:0]    m_axi_arid,
    output wire [M_COUNT*ADDR_WIDTH-1:0]    m_axi_araddr,
    output wire [M_COUNT*8-1:0]             m_axi_arlen,
    output wire [M_COUNT*3-1:0]             m_axi_arsize,
    output wire [M_COUNT*2-1:0]             m_axi_arburst,
    output wire [M_COUNT-1:0]               m_axi_arlock,
    output wire [M_COUNT*4-1:0]             m_axi_arcache,
    output wire [M_COUNT*3-1:0]             m_axi_arprot,
    output wire [M_COUNT*4-1:0]             m_axi_arqos,
    output wire [M_COUNT*4-1:0]             m_axi_arregion,
    output wire [M_COUNT*ARUSER_WIDTH-1:0]  m_axi_aruser,
    output wire [M_COUNT-1:0]               m_axi_arvalid,
    input  wire [M_COUNT-1:0]               m_axi_arready,
    input  wire [M_COUNT*M_ID_WIDTH-1:0]    m_axi_rid,
    input  wire [M_COUNT*DATA_WIDTH-1:0]    m_axi_rdata,
    input  wire [M_COUNT*2-1:0]             m_axi_rresp,
    input  wire [M_COUNT-1:0]               m_axi_rlast,
    input  wire [M_COUNT*RUSER_WIDTH-1:0]   m_axi_ruser,
    input  wire [M_COUNT-1:0]               m_axi_rvalid,
    output wire [M_COUNT-1:0]               m_axi_rready
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

wire [S_COUNT*S_ID_WIDTH-1:0]    int_s_axi_arid;
wire [S_COUNT*ADDR_WIDTH-1:0]    int_s_axi_araddr;
wire [S_COUNT*8-1:0]             int_s_axi_arlen;
wire [S_COUNT*3-1:0]             int_s_axi_arsize;
wire [S_COUNT*2-1:0]             int_s_axi_arburst;
wire [S_COUNT-1:0]               int_s_axi_arlock;
wire [S_COUNT*4-1:0]             int_s_axi_arcache;
wire [S_COUNT*3-1:0]             int_s_axi_arprot;
wire [S_COUNT*4-1:0]             int_s_axi_arqos;
wire [S_COUNT*4-1:0]             int_s_axi_arregion;
wire [S_COUNT*ARUSER_WIDTH-1:0]  int_s_axi_aruser;
wire [S_COUNT-1:0]               int_s_axi_arvalid;
wire [S_COUNT-1:0]               int_s_axi_arready;

wire [S_COUNT*M_COUNT-1:0]       int_axi_arvalid;
wire [M_COUNT*S_COUNT-1:0]       int_axi_arready;

wire [M_COUNT*M_ID_WIDTH-1:0]    int_m_axi_rid;
wire [M_COUNT*DATA_WIDTH-1:0]    int_m_axi_rdata;
wire [M_COUNT*2-1:0]             int_m_axi_rresp;
wire [M_COUNT-1:0]               int_m_axi_rlast;
wire [M_COUNT*RUSER_WIDTH-1:0]   int_m_axi_ruser;
wire [M_COUNT-1:0]               int_m_axi_rvalid;
wire [M_COUNT-1:0]               int_m_axi_rready;

wire [M_COUNT*S_COUNT-1:0]       int_axi_rvalid;
wire [S_COUNT*M_COUNT-1:0]       int_axi_rready;

generate

    genvar m, n;

    for (m = 0; m < S_COUNT; m = m + 1) begin : s_ifaces
        // address decode and admission control
        wire [CL_M_COUNT-1:0] a_select;

        wire m_axi_avalid;
        wire m_axi_aready;

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
            .WC_OUTPUT(0)
        )
        addr_inst (
            .clk(clk),
            .rst(rst),

            /*
             * Address input
             */
            .s_axi_aid(int_s_axi_arid[m*S_ID_WIDTH +: S_ID_WIDTH]),
            .s_axi_aaddr(int_s_axi_araddr[m*ADDR_WIDTH +: ADDR_WIDTH]),
            .s_axi_aprot(int_s_axi_arprot[m*3 +: 3]),
            .s_axi_aqos(int_s_axi_arqos[m*4 +: 4]),
            .s_axi_avalid(int_s_axi_arvalid[m]),
            .s_axi_aready(int_s_axi_arready[m]),

            /*
             * Address output
             */
            .m_axi_aregion(int_s_axi_arregion[m*4 +: 4]),
            .m_select(a_select),
            .m_axi_avalid(m_axi_avalid),
            .m_axi_aready(m_axi_aready),

            /*
             * Write command output
             */
            .m_wc_select(),
            .m_wc_decerr(),
            .m_wc_valid(),
            .m_wc_ready(1'b1),

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

        assign int_axi_arvalid[m*M_COUNT +: M_COUNT] = m_axi_avalid << a_select;
        assign m_axi_aready = int_axi_arready[a_select*S_COUNT+m];

        // decode error handling
        reg [S_ID_WIDTH-1:0]  decerr_m_axi_rid_reg = {S_ID_WIDTH{1'b0}}, decerr_m_axi_rid_next;
        reg                   decerr_m_axi_rlast_reg = 1'b0, decerr_m_axi_rlast_next;
        reg                   decerr_m_axi_rvalid_reg = 1'b0, decerr_m_axi_rvalid_next;
        wire                  decerr_m_axi_rready;

        reg [7:0] decerr_len_reg = 8'd0, decerr_len_next;

        assign m_rc_ready = !decerr_m_axi_rvalid_reg;

        always @* begin
            decerr_len_next = decerr_len_reg;
            decerr_m_axi_rid_next = decerr_m_axi_rid_reg;
            decerr_m_axi_rlast_next = decerr_m_axi_rlast_reg;
            decerr_m_axi_rvalid_next = decerr_m_axi_rvalid_reg;

            if (decerr_m_axi_rvalid_reg) begin
                if (decerr_m_axi_rready) begin
                    if (decerr_len_reg > 0) begin
                        decerr_len_next = decerr_len_reg-1;
                        decerr_m_axi_rlast_next = (decerr_len_next == 0);
                        decerr_m_axi_rvalid_next = 1'b1;
                    end else begin
                        decerr_m_axi_rvalid_next = 1'b0;
                    end
                end
            end else if (m_rc_valid && m_rc_ready) begin
                decerr_len_next = int_s_axi_arlen[m*8 +: 8];
                decerr_m_axi_rid_next = int_s_axi_arid[m*S_ID_WIDTH +: S_ID_WIDTH];
                decerr_m_axi_rlast_next = (decerr_len_next == 0);
                decerr_m_axi_rvalid_next = 1'b1;
            end
        end

        always @(posedge clk) begin
            if (rst) begin
                decerr_m_axi_rvalid_reg <= 1'b0;
            end else begin
                decerr_m_axi_rvalid_reg <= decerr_m_axi_rvalid_next;
            end

            decerr_m_axi_rid_reg <= decerr_m_axi_rid_next;
            decerr_m_axi_rlast_reg <= decerr_m_axi_rlast_next;
            decerr_len_reg <= decerr_len_next;
        end

        // read response arbitration
        wire [M_COUNT_P1-1:0] r_request;
        wire [M_COUNT_P1-1:0] r_acknowledge;
        wire [M_COUNT_P1-1:0] r_grant;
        wire r_grant_valid;
        wire [CL_M_COUNT_P1-1:0] r_grant_encoded;

        arbiter #(
            .PORTS(M_COUNT_P1),
            .ARB_TYPE_ROUND_ROBIN(1),
            .ARB_BLOCK(1),
            .ARB_BLOCK_ACK(1),
            .ARB_LSB_HIGH_PRIORITY(1)
        )
        r_arb_inst (
            .clk(clk),
            .rst(rst),
            .request(r_request),
            .acknowledge(r_acknowledge),
            .grant(r_grant),
            .grant_valid(r_grant_valid),
            .grant_encoded(r_grant_encoded)
        );

        // read response mux
        wire [S_ID_WIDTH-1:0]  m_axi_rid_mux    = {decerr_m_axi_rid_reg, int_m_axi_rid} >> r_grant_encoded*M_ID_WIDTH;
        wire [DATA_WIDTH-1:0]  m_axi_rdata_mux  = {{DATA_WIDTH{1'b0}}, int_m_axi_rdata} >> r_grant_encoded*DATA_WIDTH;
        wire [1:0]             m_axi_rresp_mux  = {2'b11, int_m_axi_rresp} >> r_grant_encoded*2;
        wire                   m_axi_rlast_mux  = {decerr_m_axi_rlast_reg, int_m_axi_rlast} >> r_grant_encoded;
        wire [RUSER_WIDTH-1:0] m_axi_ruser_mux  = {{RUSER_WIDTH{1'b0}}, int_m_axi_ruser} >> r_grant_encoded*RUSER_WIDTH;
        wire                   m_axi_rvalid_mux = ({decerr_m_axi_rvalid_reg, int_m_axi_rvalid} >> r_grant_encoded) & r_grant_valid;
        wire                   m_axi_rready_mux;

        assign int_axi_rready[m*M_COUNT +: M_COUNT] = (r_grant_valid && m_axi_rready_mux) << r_grant_encoded;
        assign decerr_m_axi_rready = (r_grant_valid && m_axi_rready_mux) && (r_grant_encoded == M_COUNT_P1-1);

        for (n = 0; n < M_COUNT; n = n + 1) begin
            assign r_request[n] = int_axi_rvalid[n*S_COUNT+m] && !r_grant[n];
            assign r_acknowledge[n] = r_grant[n] && int_axi_rvalid[n*S_COUNT+m] && m_axi_rlast_mux && m_axi_rready_mux;
        end

        assign r_request[M_COUNT_P1-1] = decerr_m_axi_rvalid_reg && !r_grant[M_COUNT_P1-1];
        assign r_acknowledge[M_COUNT_P1-1] = r_grant[M_COUNT_P1-1] && decerr_m_axi_rvalid_reg && decerr_m_axi_rlast_reg && m_axi_rready_mux;

        assign s_cpl_id = m_axi_rid_mux;
        assign s_cpl_valid = m_axi_rvalid_mux && m_axi_rready_mux && m_axi_rlast_mux;

        // S side register
        axi_register_rd #(
            .DATA_WIDTH(DATA_WIDTH),
            .ADDR_WIDTH(ADDR_WIDTH),
            .STRB_WIDTH(STRB_WIDTH),
            .ID_WIDTH(S_ID_WIDTH),
            .ARUSER_ENABLE(ARUSER_ENABLE),
            .ARUSER_WIDTH(ARUSER_WIDTH),
            .RUSER_ENABLE(RUSER_ENABLE),
            .RUSER_WIDTH(RUSER_WIDTH),
            .AR_REG_TYPE(S_AR_REG_TYPE[m*2 +: 2]),
            .R_REG_TYPE(S_R_REG_TYPE[m*2 +: 2])
        )
        reg_inst (
            .clk(clk),
            .rst(rst),
            .s_axi_arid(s_axi_arid[m*S_ID_WIDTH +: S_ID_WIDTH]),
            .s_axi_araddr(s_axi_araddr[m*ADDR_WIDTH +: ADDR_WIDTH]),
            .s_axi_arlen(s_axi_arlen[m*8 +: 8]),
            .s_axi_arsize(s_axi_arsize[m*3 +: 3]),
            .s_axi_arburst(s_axi_arburst[m*2 +: 2]),
            .s_axi_arlock(s_axi_arlock[m]),
            .s_axi_arcache(s_axi_arcache[m*4 +: 4]),
            .s_axi_arprot(s_axi_arprot[m*3 +: 3]),
            .s_axi_arqos(s_axi_arqos[m*4 +: 4]),
            .s_axi_arregion(4'd0),
            .s_axi_aruser(s_axi_aruser[m*ARUSER_WIDTH +: ARUSER_WIDTH]),
            .s_axi_arvalid(s_axi_arvalid[m]),
            .s_axi_arready(s_axi_arready[m]),
            .s_axi_rid(s_axi_rid[m*S_ID_WIDTH +: S_ID_WIDTH]),
            .s_axi_rdata(s_axi_rdata[m*DATA_WIDTH +: DATA_WIDTH]),
            .s_axi_rresp(s_axi_rresp[m*2 +: 2]),
            .s_axi_rlast(s_axi_rlast[m]),
            .s_axi_ruser(s_axi_ruser[m*RUSER_WIDTH +: RUSER_WIDTH]),
            .s_axi_rvalid(s_axi_rvalid[m]),
            .s_axi_rready(s_axi_rready[m]),
            .m_axi_arid(int_s_axi_arid[m*S_ID_WIDTH +: S_ID_WIDTH]),
            .m_axi_araddr(int_s_axi_araddr[m*ADDR_WIDTH +: ADDR_WIDTH]),
            .m_axi_arlen(int_s_axi_arlen[m*8 +: 8]),
            .m_axi_arsize(int_s_axi_arsize[m*3 +: 3]),
            .m_axi_arburst(int_s_axi_arburst[m*2 +: 2]),
            .m_axi_arlock(int_s_axi_arlock[m]),
            .m_axi_arcache(int_s_axi_arcache[m*4 +: 4]),
            .m_axi_arprot(int_s_axi_arprot[m*3 +: 3]),
            .m_axi_arqos(int_s_axi_arqos[m*4 +: 4]),
            .m_axi_arregion(),
            .m_axi_aruser(int_s_axi_aruser[m*ARUSER_WIDTH +: ARUSER_WIDTH]),
            .m_axi_arvalid(int_s_axi_arvalid[m]),
            .m_axi_arready(int_s_axi_arready[m]),
            .m_axi_rid(m_axi_rid_mux),
            .m_axi_rdata(m_axi_rdata_mux),
            .m_axi_rresp(m_axi_rresp_mux),
            .m_axi_rlast(m_axi_rlast_mux),
            .m_axi_ruser(m_axi_ruser_mux),
            .m_axi_rvalid(m_axi_rvalid_mux),
            .m_axi_rready(m_axi_rready_mux)
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
        wire [M_ID_WIDTH-1:0]   s_axi_arid_mux     = int_s_axi_arid[a_grant_encoded*S_ID_WIDTH +: S_ID_WIDTH] | (a_grant_encoded << S_ID_WIDTH);
        wire [ADDR_WIDTH-1:0]   s_axi_araddr_mux   = int_s_axi_araddr[a_grant_encoded*ADDR_WIDTH +: ADDR_WIDTH];
        wire [7:0]              s_axi_arlen_mux    = int_s_axi_arlen[a_grant_encoded*8 +: 8];
        wire [2:0]              s_axi_arsize_mux   = int_s_axi_arsize[a_grant_encoded*3 +: 3];
        wire [1:0]              s_axi_arburst_mux  = int_s_axi_arburst[a_grant_encoded*2 +: 2];
        wire                    s_axi_arlock_mux   = int_s_axi_arlock[a_grant_encoded];
        wire [3:0]              s_axi_arcache_mux  = int_s_axi_arcache[a_grant_encoded*4 +: 4];
        wire [2:0]              s_axi_arprot_mux   = int_s_axi_arprot[a_grant_encoded*3 +: 3];
        wire [3:0]              s_axi_arqos_mux    = int_s_axi_arqos[a_grant_encoded*4 +: 4];
        wire [3:0]              s_axi_arregion_mux = int_s_axi_arregion[a_grant_encoded*4 +: 4];
        wire [ARUSER_WIDTH-1:0] s_axi_aruser_mux   = int_s_axi_aruser[a_grant_encoded*ARUSER_WIDTH +: ARUSER_WIDTH];
        wire                    s_axi_arvalid_mux  = int_axi_arvalid[a_grant_encoded*M_COUNT+n] && a_grant_valid;
        wire                    s_axi_arready_mux;

        assign int_axi_arready[n*S_COUNT +: S_COUNT] = (a_grant_valid && s_axi_arready_mux) << a_grant_encoded;

        for (m = 0; m < S_COUNT; m = m + 1) begin
            assign a_request[m] = int_axi_arvalid[m*M_COUNT+n] && !a_grant[m] && !trans_limit;
            assign a_acknowledge[m] = a_grant[m] && int_axi_arvalid[m*M_COUNT+n] && s_axi_arready_mux;
        end

        assign trans_start = s_axi_arvalid_mux && s_axi_arready_mux && a_grant_valid;

        // read response forwarding
        wire [CL_S_COUNT-1:0] r_select = m_axi_rid[n*M_ID_WIDTH +: M_ID_WIDTH] >> S_ID_WIDTH;

        assign int_axi_rvalid[n*S_COUNT +: S_COUNT] = int_m_axi_rvalid[n] << r_select;
        assign int_m_axi_rready[n] = int_axi_rready[r_select*M_COUNT+n];

        assign trans_complete = int_m_axi_rvalid[n] && int_m_axi_rready[n] && int_m_axi_rlast[n];

        // M side register
        axi_register_rd #(
            .DATA_WIDTH(DATA_WIDTH),
            .ADDR_WIDTH(ADDR_WIDTH),
            .STRB_WIDTH(STRB_WIDTH),
            .ID_WIDTH(M_ID_WIDTH),
            .ARUSER_ENABLE(ARUSER_ENABLE),
            .ARUSER_WIDTH(ARUSER_WIDTH),
            .RUSER_ENABLE(RUSER_ENABLE),
            .RUSER_WIDTH(RUSER_WIDTH),
            .AR_REG_TYPE(M_AR_REG_TYPE[n*2 +: 2]),
            .R_REG_TYPE(M_R_REG_TYPE[n*2 +: 2])
        )
        reg_inst (
            .clk(clk),
            .rst(rst),
            .s_axi_arid(s_axi_arid_mux),
            .s_axi_araddr(s_axi_araddr_mux),
            .s_axi_arlen(s_axi_arlen_mux),
            .s_axi_arsize(s_axi_arsize_mux),
            .s_axi_arburst(s_axi_arburst_mux),
            .s_axi_arlock(s_axi_arlock_mux),
            .s_axi_arcache(s_axi_arcache_mux),
            .s_axi_arprot(s_axi_arprot_mux),
            .s_axi_arqos(s_axi_arqos_mux),
            .s_axi_arregion(s_axi_arregion_mux),
            .s_axi_aruser(s_axi_aruser_mux),
            .s_axi_arvalid(s_axi_arvalid_mux),
            .s_axi_arready(s_axi_arready_mux),
            .s_axi_rid(int_m_axi_rid[n*M_ID_WIDTH +: M_ID_WIDTH]),
            .s_axi_rdata(int_m_axi_rdata[n*DATA_WIDTH +: DATA_WIDTH]),
            .s_axi_rresp(int_m_axi_rresp[n*2 +: 2]),
            .s_axi_rlast(int_m_axi_rlast[n]),
            .s_axi_ruser(int_m_axi_ruser[n*RUSER_WIDTH +: RUSER_WIDTH]),
            .s_axi_rvalid(int_m_axi_rvalid[n]),
            .s_axi_rready(int_m_axi_rready[n]),
            .m_axi_arid(m_axi_arid[n*M_ID_WIDTH +: M_ID_WIDTH]),
            .m_axi_araddr(m_axi_araddr[n*ADDR_WIDTH +: ADDR_WIDTH]),
            .m_axi_arlen(m_axi_arlen[n*8 +: 8]),
            .m_axi_arsize(m_axi_arsize[n*3 +: 3]),
            .m_axi_arburst(m_axi_arburst[n*2 +: 2]),
            .m_axi_arlock(m_axi_arlock[n]),
            .m_axi_arcache(m_axi_arcache[n*4 +: 4]),
            .m_axi_arprot(m_axi_arprot[n*3 +: 3]),
            .m_axi_arqos(m_axi_arqos[n*4 +: 4]),
            .m_axi_arregion(m_axi_arregion[n*4 +: 4]),
            .m_axi_aruser(m_axi_aruser[n*ARUSER_WIDTH +: ARUSER_WIDTH]),
            .m_axi_arvalid(m_axi_arvalid[n]),
            .m_axi_arready(m_axi_arready[n]),
            .m_axi_rid(m_axi_rid[n*M_ID_WIDTH +: M_ID_WIDTH]),
            .m_axi_rdata(m_axi_rdata[n*DATA_WIDTH +: DATA_WIDTH]),
            .m_axi_rresp(m_axi_rresp[n*2 +: 2]),
            .m_axi_rlast(m_axi_rlast[n]),
            .m_axi_ruser(m_axi_ruser[n*RUSER_WIDTH +: RUSER_WIDTH]),
            .m_axi_rvalid(m_axi_rvalid[n]),
            .m_axi_rready(m_axi_rready[n])
        );
    end // m_ifaces

endgenerate

endmodule

`resetall
