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
 * AXI4 lite crossbar (read)
 */
module axil_crossbar_rd #
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
    parameter M_ISSUE = {M_COUNT{32'd16}},
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
     * AXI lite slave interfaces
     */
    input  wire [S_COUNT*ADDR_WIDTH-1:0]    s_axil_araddr,
    input  wire [S_COUNT*3-1:0]             s_axil_arprot,
    input  wire [S_COUNT-1:0]               s_axil_arvalid,
    output wire [S_COUNT-1:0]               s_axil_arready,
    output wire [S_COUNT*DATA_WIDTH-1:0]    s_axil_rdata,
    output wire [S_COUNT*2-1:0]             s_axil_rresp,
    output wire [S_COUNT-1:0]               s_axil_rvalid,
    input  wire [S_COUNT-1:0]               s_axil_rready,

    /*
     * AXI lite master interfaces
     */
    output wire [M_COUNT*ADDR_WIDTH-1:0]    m_axil_araddr,
    output wire [M_COUNT*3-1:0]             m_axil_arprot,
    output wire [M_COUNT-1:0]               m_axil_arvalid,
    input  wire [M_COUNT-1:0]               m_axil_arready,
    input  wire [M_COUNT*DATA_WIDTH-1:0]    m_axil_rdata,
    input  wire [M_COUNT*2-1:0]             m_axil_rresp,
    input  wire [M_COUNT-1:0]               m_axil_rvalid,
    output wire [M_COUNT-1:0]               m_axil_rready
);

parameter CL_S_COUNT = $clog2(S_COUNT);
parameter CL_M_COUNT = $clog2(M_COUNT);
parameter M_COUNT_P1 = M_COUNT+1;
parameter CL_M_COUNT_P1 = $clog2(M_COUNT_P1);

integer i;

// check configuration
initial begin
    for (i = 0; i < M_COUNT*M_REGIONS; i = i + 1) begin
        if (M_ADDR_WIDTH[i*32 +: 32] && (M_ADDR_WIDTH[i*32 +: 32] < 12 || M_ADDR_WIDTH[i*32 +: 32] > ADDR_WIDTH)) begin
            $error("Error: value out of range (instance %m)");
            $finish;
        end
    end
end

wire [S_COUNT*ADDR_WIDTH-1:0]    int_s_axil_araddr;
wire [S_COUNT*3-1:0]             int_s_axil_arprot;
wire [S_COUNT-1:0]               int_s_axil_arvalid;
wire [S_COUNT-1:0]               int_s_axil_arready;

wire [S_COUNT*M_COUNT-1:0]       int_axil_arvalid;
wire [M_COUNT*S_COUNT-1:0]       int_axil_arready;

wire [M_COUNT*DATA_WIDTH-1:0]    int_m_axil_rdata;
wire [M_COUNT*2-1:0]             int_m_axil_rresp;
wire [M_COUNT-1:0]               int_m_axil_rvalid;
wire [M_COUNT-1:0]               int_m_axil_rready;

wire [M_COUNT*S_COUNT-1:0]       int_axil_rvalid;
wire [S_COUNT*M_COUNT-1:0]       int_axil_rready;

generate

    genvar m, n;

    for (m = 0; m < S_COUNT; m = m + 1) begin : s_ifaces
        // response routing FIFO
        localparam FIFO_ADDR_WIDTH = $clog2(S_ACCEPT[m*32 +: 32])+1;

        reg [FIFO_ADDR_WIDTH+1-1:0] fifo_wr_ptr_reg = 0;
        reg [FIFO_ADDR_WIDTH+1-1:0] fifo_rd_ptr_reg = 0;

        (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
        reg [CL_M_COUNT-1:0] fifo_select[(2**FIFO_ADDR_WIDTH)-1:0];
        (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
        reg fifo_decerr[(2**FIFO_ADDR_WIDTH)-1:0];

        wire [CL_M_COUNT-1:0] fifo_wr_select;
        wire fifo_wr_decerr;
        wire fifo_wr_en;

        reg [CL_M_COUNT-1:0] fifo_rd_select_reg = 0;
        reg fifo_rd_decerr_reg = 0;
        reg fifo_rd_valid_reg = 0;
        wire fifo_rd_en;
        reg fifo_half_full_reg = 1'b0;

        wire fifo_empty = fifo_rd_ptr_reg == fifo_wr_ptr_reg;

        integer i;

        initial begin
            for (i = 0; i < 2**FIFO_ADDR_WIDTH; i = i + 1) begin
                fifo_select[i] = 0;
                fifo_decerr[i] = 0;
            end
        end

        always @(posedge clk) begin
            if (fifo_wr_en) begin
                fifo_select[fifo_wr_ptr_reg[FIFO_ADDR_WIDTH-1:0]] <= fifo_wr_select;
                fifo_decerr[fifo_wr_ptr_reg[FIFO_ADDR_WIDTH-1:0]] <= fifo_wr_decerr;
                fifo_wr_ptr_reg <= fifo_wr_ptr_reg + 1;
            end

            fifo_rd_valid_reg <= fifo_rd_valid_reg && !fifo_rd_en;

            if ((fifo_rd_ptr_reg != fifo_wr_ptr_reg) && (!fifo_rd_valid_reg || fifo_rd_en)) begin
                fifo_rd_select_reg <= fifo_select[fifo_rd_ptr_reg[FIFO_ADDR_WIDTH-1:0]];
                fifo_rd_decerr_reg <= fifo_decerr[fifo_rd_ptr_reg[FIFO_ADDR_WIDTH-1:0]];
                fifo_rd_valid_reg <= 1'b1;
                fifo_rd_ptr_reg <= fifo_rd_ptr_reg + 1;
            end

            fifo_half_full_reg <= $unsigned(fifo_wr_ptr_reg - fifo_rd_ptr_reg) >= 2**(FIFO_ADDR_WIDTH-1);

            if (rst) begin
                fifo_wr_ptr_reg <= 0;
                fifo_rd_ptr_reg <= 0;
                fifo_rd_valid_reg <= 1'b0;
            end
        end

        // address decode and admission control
        wire [CL_M_COUNT-1:0] a_select;

        wire m_axil_avalid;
        wire m_axil_aready;

        wire [CL_M_COUNT-1:0] m_rc_select;
        wire m_rc_decerr;
        wire m_rc_valid;
        wire m_rc_ready;

        axil_crossbar_addr #(
            .S(m),
            .S_COUNT(S_COUNT),
            .M_COUNT(M_COUNT),
            .ADDR_WIDTH(ADDR_WIDTH),
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
            .s_axil_aaddr(int_s_axil_araddr[m*ADDR_WIDTH +: ADDR_WIDTH]),
            .s_axil_aprot(int_s_axil_arprot[m*3 +: 3]),
            .s_axil_avalid(int_s_axil_arvalid[m]),
            .s_axil_aready(int_s_axil_arready[m]),

            /*
             * Address output
             */
            .m_select(a_select),
            .m_axil_avalid(m_axil_avalid),
            .m_axil_aready(m_axil_aready),

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
            .m_rc_select(m_rc_select),
            .m_rc_decerr(m_rc_decerr),
            .m_rc_valid(m_rc_valid),
            .m_rc_ready(m_rc_ready)
        );

        assign int_axil_arvalid[m*M_COUNT +: M_COUNT] = m_axil_avalid << a_select;
        assign m_axil_aready = int_axil_arready[a_select*S_COUNT+m];

        // response handling
        assign fifo_wr_select = m_rc_select;
        assign fifo_wr_decerr = m_rc_decerr;
        assign fifo_wr_en = m_rc_valid && !fifo_half_full_reg;
        assign m_rc_ready = !fifo_half_full_reg;

        // write response handling
        wire [CL_M_COUNT-1:0] r_select = M_COUNT > 1 ? fifo_rd_select_reg : 0;
        wire r_decerr = fifo_rd_decerr_reg;
        wire r_valid = fifo_rd_valid_reg;

        // read response mux
        wire [DATA_WIDTH-1:0]  m_axil_rdata_mux  = r_decerr ? {DATA_WIDTH{1'b0}} : int_m_axil_rdata[r_select*DATA_WIDTH +: DATA_WIDTH];
        wire [1:0]             m_axil_rresp_mux  = r_decerr ? 2'b11 : int_m_axil_rresp[r_select*2 +: 2];
        wire                   m_axil_rvalid_mux = (r_decerr ? 1'b1 : int_axil_rvalid[r_select*S_COUNT+m]) && r_valid;
        wire                   m_axil_rready_mux;

        assign int_axil_rready[m*M_COUNT +: M_COUNT] = (r_valid && m_axil_rready_mux) << r_select;

        assign fifo_rd_en = m_axil_rvalid_mux && m_axil_rready_mux && r_valid;

        // S side register
        axil_register_rd #(
            .DATA_WIDTH(DATA_WIDTH),
            .ADDR_WIDTH(ADDR_WIDTH),
            .STRB_WIDTH(STRB_WIDTH),
            .AR_REG_TYPE(S_AR_REG_TYPE[m*2 +: 2]),
            .R_REG_TYPE(S_R_REG_TYPE[m*2 +: 2])
        )
        reg_inst (
            .clk(clk),
            .rst(rst),
            .s_axil_araddr(s_axil_araddr[m*ADDR_WIDTH +: ADDR_WIDTH]),
            .s_axil_arprot(s_axil_arprot[m*3 +: 3]),
            .s_axil_arvalid(s_axil_arvalid[m]),
            .s_axil_arready(s_axil_arready[m]),
            .s_axil_rdata(s_axil_rdata[m*DATA_WIDTH +: DATA_WIDTH]),
            .s_axil_rresp(s_axil_rresp[m*2 +: 2]),
            .s_axil_rvalid(s_axil_rvalid[m]),
            .s_axil_rready(s_axil_rready[m]),
            .m_axil_araddr(int_s_axil_araddr[m*ADDR_WIDTH +: ADDR_WIDTH]),
            .m_axil_arprot(int_s_axil_arprot[m*3 +: 3]),
            .m_axil_arvalid(int_s_axil_arvalid[m]),
            .m_axil_arready(int_s_axil_arready[m]),
            .m_axil_rdata(m_axil_rdata_mux),
            .m_axil_rresp(m_axil_rresp_mux),
            .m_axil_rvalid(m_axil_rvalid_mux),
            .m_axil_rready(m_axil_rready_mux)
        );
    end // s_ifaces

    for (n = 0; n < M_COUNT; n = n + 1) begin : m_ifaces
        // response routing FIFO
        localparam FIFO_ADDR_WIDTH = $clog2(M_ISSUE[n*32 +: 32])+1;

        reg [FIFO_ADDR_WIDTH+1-1:0] fifo_wr_ptr_reg = 0;
        reg [FIFO_ADDR_WIDTH+1-1:0] fifo_rd_ptr_reg = 0;

        (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
        reg [CL_S_COUNT-1:0] fifo_select[(2**FIFO_ADDR_WIDTH)-1:0];
        wire [CL_S_COUNT-1:0] fifo_wr_select;
        wire fifo_wr_en;
        wire fifo_rd_en;
        reg fifo_half_full_reg = 1'b0;

        wire fifo_empty = fifo_rd_ptr_reg == fifo_wr_ptr_reg;

        integer i;

        initial begin
            for (i = 0; i < 2**FIFO_ADDR_WIDTH; i = i + 1) begin
                fifo_select[i] = 0;
            end
        end

        always @(posedge clk) begin
            if (fifo_wr_en) begin
                fifo_select[fifo_wr_ptr_reg[FIFO_ADDR_WIDTH-1:0]] <= fifo_wr_select;
                fifo_wr_ptr_reg <= fifo_wr_ptr_reg + 1;
            end
            if (fifo_rd_en) begin
                fifo_rd_ptr_reg <= fifo_rd_ptr_reg + 1;
            end

            fifo_half_full_reg <= $unsigned(fifo_wr_ptr_reg - fifo_rd_ptr_reg) >= 2**(FIFO_ADDR_WIDTH-1);

            if (rst) begin
                fifo_wr_ptr_reg <= 0;
                fifo_rd_ptr_reg <= 0;
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
        wire [ADDR_WIDTH-1:0]  s_axil_araddr_mux   = int_s_axil_araddr[a_grant_encoded*ADDR_WIDTH +: ADDR_WIDTH];
        wire [2:0]             s_axil_arprot_mux   = int_s_axil_arprot[a_grant_encoded*3 +: 3];
        wire                   s_axil_arvalid_mux  = int_axil_arvalid[a_grant_encoded*M_COUNT+n] && a_grant_valid;
        wire                   s_axil_arready_mux;

        assign int_axil_arready[n*S_COUNT +: S_COUNT] = (a_grant_valid && s_axil_arready_mux) << a_grant_encoded;

        for (m = 0; m < S_COUNT; m = m + 1) begin
            assign a_request[m] = int_axil_arvalid[m*M_COUNT+n] && !a_grant[m] && !fifo_half_full_reg;
            assign a_acknowledge[m] = a_grant[m] && int_axil_arvalid[m*M_COUNT+n] && s_axil_arready_mux;
        end

        assign fifo_wr_select = a_grant_encoded;
        assign fifo_wr_en = s_axil_arvalid_mux && s_axil_arready_mux && a_grant_valid;

        // read response forwarding
        wire [CL_S_COUNT-1:0] r_select = S_COUNT > 1 ? fifo_select[fifo_rd_ptr_reg[FIFO_ADDR_WIDTH-1:0]] : 0;

        assign int_axil_rvalid[n*S_COUNT +: S_COUNT] = int_m_axil_rvalid[n] << r_select;
        assign int_m_axil_rready[n] = int_axil_rready[r_select*M_COUNT+n];

        assign fifo_rd_en = int_m_axil_rvalid[n] && int_m_axil_rready[n];

        // M side register
        axil_register_rd #(
            .DATA_WIDTH(DATA_WIDTH),
            .ADDR_WIDTH(ADDR_WIDTH),
            .STRB_WIDTH(STRB_WIDTH),
            .AR_REG_TYPE(M_AR_REG_TYPE[n*2 +: 2]),
            .R_REG_TYPE(M_R_REG_TYPE[n*2 +: 2])
        )
        reg_inst (
            .clk(clk),
            .rst(rst),
            .s_axil_araddr(s_axil_araddr_mux),
            .s_axil_arprot(s_axil_arprot_mux),
            .s_axil_arvalid(s_axil_arvalid_mux),
            .s_axil_arready(s_axil_arready_mux),
            .s_axil_rdata(int_m_axil_rdata[n*DATA_WIDTH +: DATA_WIDTH]),
            .s_axil_rresp(int_m_axil_rresp[n*2 +: 2]),
            .s_axil_rvalid(int_m_axil_rvalid[n]),
            .s_axil_rready(int_m_axil_rready[n]),
            .m_axil_araddr(m_axil_araddr[n*ADDR_WIDTH +: ADDR_WIDTH]),
            .m_axil_arprot(m_axil_arprot[n*3 +: 3]),
            .m_axil_arvalid(m_axil_arvalid[n]),
            .m_axil_arready(m_axil_arready[n]),
            .m_axil_rdata(m_axil_rdata[n*DATA_WIDTH +: DATA_WIDTH]),
            .m_axil_rresp(m_axil_rresp[n*2 +: 2]),
            .m_axil_rvalid(m_axil_rvalid[n]),
            .m_axil_rready(m_axil_rready[n])
        );
    end // m_ifaces

endgenerate

endmodule

`resetall
