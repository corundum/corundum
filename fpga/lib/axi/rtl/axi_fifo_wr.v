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
 * AXI4 FIFO (write)
 */
module axi_fifo_wr #
(
    // Width of data bus in bits
    parameter DATA_WIDTH = 32,
    // Width of address bus in bits
    parameter ADDR_WIDTH = 32,
    // Width of wstrb (width of data bus in words)
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    // Width of ID signal
    parameter ID_WIDTH = 8,
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
    // Write data FIFO depth (cycles)
    parameter FIFO_DEPTH = 32,
    // Hold write address until write data in FIFO, if possible
    parameter FIFO_DELAY = 0
)
(
    input  wire                     clk,
    input  wire                     rst,

    /*
     * AXI slave interface
     */
    input  wire [ID_WIDTH-1:0]      s_axi_awid,
    input  wire [ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  wire [7:0]               s_axi_awlen,
    input  wire [2:0]               s_axi_awsize,
    input  wire [1:0]               s_axi_awburst,
    input  wire                     s_axi_awlock,
    input  wire [3:0]               s_axi_awcache,
    input  wire [2:0]               s_axi_awprot,
    input  wire [3:0]               s_axi_awqos,
    input  wire [3:0]               s_axi_awregion,
    input  wire [AWUSER_WIDTH-1:0]  s_axi_awuser,
    input  wire                     s_axi_awvalid,
    output wire                     s_axi_awready,
    input  wire [DATA_WIDTH-1:0]    s_axi_wdata,
    input  wire [STRB_WIDTH-1:0]    s_axi_wstrb,
    input  wire                     s_axi_wlast,
    input  wire [WUSER_WIDTH-1:0]   s_axi_wuser,
    input  wire                     s_axi_wvalid,
    output wire                     s_axi_wready,
    output wire [ID_WIDTH-1:0]      s_axi_bid,
    output wire [1:0]               s_axi_bresp,
    output wire [BUSER_WIDTH-1:0]   s_axi_buser,
    output wire                     s_axi_bvalid,
    input  wire                     s_axi_bready,

    /*
     * AXI master interface
     */
    output wire [ID_WIDTH-1:0]      m_axi_awid,
    output wire [ADDR_WIDTH-1:0]    m_axi_awaddr,
    output wire [7:0]               m_axi_awlen,
    output wire [2:0]               m_axi_awsize,
    output wire [1:0]               m_axi_awburst,
    output wire                     m_axi_awlock,
    output wire [3:0]               m_axi_awcache,
    output wire [2:0]               m_axi_awprot,
    output wire [3:0]               m_axi_awqos,
    output wire [3:0]               m_axi_awregion,
    output wire [AWUSER_WIDTH-1:0]  m_axi_awuser,
    output wire                     m_axi_awvalid,
    input  wire                     m_axi_awready,
    output wire [DATA_WIDTH-1:0]    m_axi_wdata,
    output wire [STRB_WIDTH-1:0]    m_axi_wstrb,
    output wire                     m_axi_wlast,
    output wire [WUSER_WIDTH-1:0]   m_axi_wuser,
    output wire                     m_axi_wvalid,
    input  wire                     m_axi_wready,
    input  wire [ID_WIDTH-1:0]      m_axi_bid,
    input  wire [1:0]               m_axi_bresp,
    input  wire [BUSER_WIDTH-1:0]   m_axi_buser,
    input  wire                     m_axi_bvalid,
    output wire                     m_axi_bready
);

parameter STRB_OFFSET  = DATA_WIDTH;
parameter LAST_OFFSET  = STRB_OFFSET + STRB_WIDTH;
parameter WUSER_OFFSET = LAST_OFFSET + 1;
parameter WWIDTH       = WUSER_OFFSET + (WUSER_ENABLE ? WUSER_WIDTH : 0);

parameter FIFO_ADDR_WIDTH = $clog2(FIFO_DEPTH);

reg [FIFO_ADDR_WIDTH:0] wr_ptr_reg = {FIFO_ADDR_WIDTH+1{1'b0}}, wr_ptr_next;
reg [FIFO_ADDR_WIDTH:0] wr_addr_reg = {FIFO_ADDR_WIDTH+1{1'b0}};
reg [FIFO_ADDR_WIDTH:0] rd_ptr_reg = {FIFO_ADDR_WIDTH+1{1'b0}}, rd_ptr_next;
reg [FIFO_ADDR_WIDTH:0] rd_addr_reg = {FIFO_ADDR_WIDTH+1{1'b0}};

(* ramstyle = "no_rw_check" *)
reg [WWIDTH-1:0] mem[(2**FIFO_ADDR_WIDTH)-1:0];
reg [WWIDTH-1:0] mem_read_data_reg;
reg mem_read_data_valid_reg = 1'b0, mem_read_data_valid_next;

wire [WWIDTH-1:0] s_axi_w;

reg [WWIDTH-1:0] m_axi_w_reg;
reg m_axi_wvalid_reg = 1'b0, m_axi_wvalid_next;

// full when first MSB different but rest same
wire full = ((wr_ptr_reg[FIFO_ADDR_WIDTH] != rd_ptr_reg[FIFO_ADDR_WIDTH]) &&
             (wr_ptr_reg[FIFO_ADDR_WIDTH-1:0] == rd_ptr_reg[FIFO_ADDR_WIDTH-1:0]));
// empty when pointers match exactly
wire empty = wr_ptr_reg == rd_ptr_reg;

wire hold;

// control signals
reg write;
reg read;
reg store_output;

assign s_axi_wready = !full && !hold;

generate
    assign s_axi_w[DATA_WIDTH-1:0] = s_axi_wdata;
    assign s_axi_w[STRB_OFFSET +: STRB_WIDTH] = s_axi_wstrb;
    assign s_axi_w[LAST_OFFSET] = s_axi_wlast;
    if (WUSER_ENABLE) assign s_axi_w[WUSER_OFFSET +: WUSER_WIDTH] = s_axi_wuser;
endgenerate

generate

if (FIFO_DELAY) begin
    // store AW channel value until W channel burst is stored in FIFO or FIFO is full

    localparam [1:0]
        STATE_IDLE = 2'd0,
        STATE_TRANSFER_IN = 2'd1,
        STATE_TRANSFER_OUT = 2'd2;

    reg [1:0] state_reg = STATE_IDLE, state_next;

    reg hold_reg = 1'b1, hold_next;
    reg [8:0] count_reg = 9'd0, count_next;

    reg [ID_WIDTH-1:0] m_axi_awid_reg = {ID_WIDTH{1'b0}}, m_axi_awid_next;
    reg [ADDR_WIDTH-1:0] m_axi_awaddr_reg = {ADDR_WIDTH{1'b0}}, m_axi_awaddr_next;
    reg [7:0] m_axi_awlen_reg = 8'd0, m_axi_awlen_next;
    reg [2:0] m_axi_awsize_reg = 3'd0, m_axi_awsize_next;
    reg [1:0] m_axi_awburst_reg = 2'd0, m_axi_awburst_next;
    reg m_axi_awlock_reg = 1'b0, m_axi_awlock_next;
    reg [3:0] m_axi_awcache_reg = 4'd0, m_axi_awcache_next;
    reg [2:0] m_axi_awprot_reg = 3'd0, m_axi_awprot_next;
    reg [3:0] m_axi_awqos_reg = 4'd0, m_axi_awqos_next;
    reg [3:0] m_axi_awregion_reg = 4'd0, m_axi_awregion_next;
    reg [AWUSER_WIDTH-1:0] m_axi_awuser_reg = {AWUSER_WIDTH{1'b0}}, m_axi_awuser_next;
    reg m_axi_awvalid_reg = 1'b0, m_axi_awvalid_next;

    reg s_axi_awready_reg = 1'b0, s_axi_awready_next;

    assign m_axi_awid = m_axi_awid_reg;
    assign m_axi_awaddr = m_axi_awaddr_reg;
    assign m_axi_awlen = m_axi_awlen_reg;
    assign m_axi_awsize = m_axi_awsize_reg;
    assign m_axi_awburst = m_axi_awburst_reg;
    assign m_axi_awlock = m_axi_awlock_reg;
    assign m_axi_awcache = m_axi_awcache_reg;
    assign m_axi_awprot = m_axi_awprot_reg;
    assign m_axi_awqos = m_axi_awqos_reg;
    assign m_axi_awregion = m_axi_awregion_reg;
    assign m_axi_awuser = AWUSER_ENABLE ? m_axi_awuser_reg : {AWUSER_WIDTH{1'b0}};
    assign m_axi_awvalid = m_axi_awvalid_reg;

    assign s_axi_awready = s_axi_awready_reg;

    assign hold = hold_reg;

    always @* begin
        state_next = STATE_IDLE;

        hold_next = hold_reg;
        count_next = count_reg;

        m_axi_awid_next = m_axi_awid_reg;
        m_axi_awaddr_next = m_axi_awaddr_reg;
        m_axi_awlen_next = m_axi_awlen_reg;
        m_axi_awsize_next = m_axi_awsize_reg;
        m_axi_awburst_next = m_axi_awburst_reg;
        m_axi_awlock_next = m_axi_awlock_reg;
        m_axi_awcache_next = m_axi_awcache_reg;
        m_axi_awprot_next = m_axi_awprot_reg;
        m_axi_awqos_next = m_axi_awqos_reg;
        m_axi_awregion_next = m_axi_awregion_reg;
        m_axi_awuser_next = m_axi_awuser_reg;
        m_axi_awvalid_next = m_axi_awvalid_reg && !m_axi_awready;
        s_axi_awready_next = s_axi_awready_reg;

        case (state_reg)
            STATE_IDLE: begin
                s_axi_awready_next = !m_axi_awvalid || m_axi_awready;
                hold_next = 1'b1;

                if (s_axi_awready && s_axi_awvalid) begin
                    s_axi_awready_next = 1'b0;

                    m_axi_awid_next = s_axi_awid;
                    m_axi_awaddr_next = s_axi_awaddr;
                    m_axi_awlen_next = s_axi_awlen;
                    m_axi_awsize_next = s_axi_awsize;
                    m_axi_awburst_next = s_axi_awburst;
                    m_axi_awlock_next = s_axi_awlock;
                    m_axi_awcache_next = s_axi_awcache;
                    m_axi_awprot_next = s_axi_awprot;
                    m_axi_awqos_next = s_axi_awqos;
                    m_axi_awregion_next = s_axi_awregion;
                    m_axi_awuser_next = s_axi_awuser;

                    hold_next = 1'b0;
                    count_next = 0;
                    state_next = STATE_TRANSFER_IN;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            STATE_TRANSFER_IN: begin
                s_axi_awready_next = 1'b0;
                hold_next = 1'b0;

                if (s_axi_wready && s_axi_wvalid) begin
                    count_next = count_reg + 1;
                    if (s_axi_wlast) begin
                        m_axi_awvalid_next = 1'b1;
                        hold_next = 1'b1;
                        state_next = STATE_IDLE;
                    end else if (FIFO_ADDR_WIDTH < 8 && count_next == 2**FIFO_ADDR_WIDTH) begin
                        m_axi_awvalid_next = 1'b1;
                        state_next = STATE_TRANSFER_OUT;
                    end else begin
                        state_next = STATE_TRANSFER_IN;
                    end
                end else begin
                    state_next = STATE_TRANSFER_IN;
                end
            end
            STATE_TRANSFER_OUT: begin
                s_axi_awready_next = 1'b0;
                hold_next = 1'b0;

                if (s_axi_wready && s_axi_wvalid) begin
                    if (s_axi_wlast) begin
                        hold_next = 1'b1;
                        state_next = STATE_IDLE;
                    end else begin
                        state_next = STATE_TRANSFER_OUT;
                    end
                end else begin
                    state_next = STATE_TRANSFER_OUT;
                end
            end
        endcase
    end

    always @(posedge clk) begin
        state_reg <= state_next;

        hold_reg <= hold_next;
        count_reg <= count_next;

        m_axi_awid_reg <= m_axi_awid_next;
        m_axi_awaddr_reg <= m_axi_awaddr_next;
        m_axi_awlen_reg <= m_axi_awlen_next;
        m_axi_awsize_reg <= m_axi_awsize_next;
        m_axi_awburst_reg <= m_axi_awburst_next;
        m_axi_awlock_reg <= m_axi_awlock_next;
        m_axi_awcache_reg <= m_axi_awcache_next;
        m_axi_awprot_reg <= m_axi_awprot_next;
        m_axi_awqos_reg <= m_axi_awqos_next;
        m_axi_awregion_reg <= m_axi_awregion_next;
        m_axi_awuser_reg <= m_axi_awuser_next;
        m_axi_awvalid_reg <= m_axi_awvalid_next;
        s_axi_awready_reg <= s_axi_awready_next;

        if (rst) begin
            state_reg <= STATE_IDLE;
            hold_reg <= 1'b1;
            m_axi_awvalid_reg <= 1'b0;
            s_axi_awready_reg <= 1'b0;
        end
    end
end else begin
    // bypass AW channel
    assign m_axi_awid = s_axi_awid;
    assign m_axi_awaddr = s_axi_awaddr;
    assign m_axi_awlen = s_axi_awlen;
    assign m_axi_awsize = s_axi_awsize;
    assign m_axi_awburst = s_axi_awburst;
    assign m_axi_awlock = s_axi_awlock;
    assign m_axi_awcache = s_axi_awcache;
    assign m_axi_awprot = s_axi_awprot;
    assign m_axi_awqos = s_axi_awqos;
    assign m_axi_awregion = s_axi_awregion;
    assign m_axi_awuser = AWUSER_ENABLE ? s_axi_awuser : {AWUSER_WIDTH{1'b0}};
    assign m_axi_awvalid = s_axi_awvalid;
    assign s_axi_awready = m_axi_awready;

    assign hold = 1'b0;
end

endgenerate

// bypass B channel
assign s_axi_bid = m_axi_bid;
assign s_axi_bresp = m_axi_bresp;
assign s_axi_buser = BUSER_ENABLE ? m_axi_buser : {BUSER_WIDTH{1'b0}};
assign s_axi_bvalid = m_axi_bvalid;
assign m_axi_bready = s_axi_bready;

assign m_axi_wvalid = m_axi_wvalid_reg;

assign m_axi_wdata = m_axi_w_reg[DATA_WIDTH-1:0];
assign m_axi_wstrb = m_axi_w_reg[STRB_OFFSET +: STRB_WIDTH];
assign m_axi_wlast = m_axi_w_reg[LAST_OFFSET];
assign m_axi_wuser = WUSER_ENABLE ? m_axi_w_reg[WUSER_OFFSET +: WUSER_WIDTH] : {WUSER_WIDTH{1'b0}};

// Write logic
always @* begin
    write = 1'b0;

    wr_ptr_next = wr_ptr_reg;

    if (s_axi_wvalid) begin
        // input data valid
        if (!full && !hold) begin
            // not full, perform write
            write = 1'b1;
            wr_ptr_next = wr_ptr_reg + 1;
        end
    end
end

always @(posedge clk) begin
    wr_ptr_reg <= wr_ptr_next;
    wr_addr_reg <= wr_ptr_next;

    if (write) begin
        mem[wr_addr_reg[FIFO_ADDR_WIDTH-1:0]] <= s_axi_w;
    end

    if (rst) begin
        wr_ptr_reg <= {FIFO_ADDR_WIDTH+1{1'b0}};
    end
end

// Read logic
always @* begin
    read = 1'b0;

    rd_ptr_next = rd_ptr_reg;

    mem_read_data_valid_next = mem_read_data_valid_reg;

    if (store_output || !mem_read_data_valid_reg) begin
        // output data not valid OR currently being transferred
        if (!empty) begin
            // not empty, perform read
            read = 1'b1;
            mem_read_data_valid_next = 1'b1;
            rd_ptr_next = rd_ptr_reg + 1;
        end else begin
            // empty, invalidate
            mem_read_data_valid_next = 1'b0;
        end
    end
end

always @(posedge clk) begin
    rd_ptr_reg <= rd_ptr_next;
    rd_addr_reg <= rd_ptr_next;

    mem_read_data_valid_reg <= mem_read_data_valid_next;

    if (read) begin
        mem_read_data_reg <= mem[rd_addr_reg[FIFO_ADDR_WIDTH-1:0]];
    end

    if (rst) begin
        rd_ptr_reg <= {FIFO_ADDR_WIDTH+1{1'b0}};
        mem_read_data_valid_reg <= 1'b0;
    end
end

// Output register
always @* begin
    store_output = 1'b0;

    m_axi_wvalid_next = m_axi_wvalid_reg;

    if (m_axi_wready || !m_axi_wvalid) begin
        store_output = 1'b1;
        m_axi_wvalid_next = mem_read_data_valid_reg;
    end
end

always @(posedge clk) begin
    m_axi_wvalid_reg <= m_axi_wvalid_next;

    if (store_output) begin
        m_axi_w_reg <= mem_read_data_reg;
    end

    if (rst) begin
        m_axi_wvalid_reg <= 1'b0;
    end
end

endmodule

`resetall
