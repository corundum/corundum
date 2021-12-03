/*

Copyright (c) 2018-2021 Alex Forencich

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
 * PCIe AXI DMA descriptor mux
 */
module pcie_axi_dma_desc_mux #
(
    // Number of ports
    parameter PORTS = 2,
    // PCIe address width
    parameter PCIE_ADDR_WIDTH = 64,
    // AXI address width
    parameter AXI_ADDR_WIDTH = 16,
    // Length field width
    parameter LEN_WIDTH = 20,
    // Input tag field width
    parameter S_TAG_WIDTH = 8,
    // Output tag field width (towards DMA module)
    // Additional bits required for response routing
    parameter M_TAG_WIDTH = S_TAG_WIDTH+$clog2(PORTS),
    // select round robin arbitration
    parameter ARB_TYPE_ROUND_ROBIN = 0,
    // LSB priority selection
    parameter ARB_LSB_HIGH_PRIORITY = 1
)
(
    input  wire                             clk,
    input  wire                             rst,

    /*
     * Descriptor output (to PCIe DMA core)
     */
    output wire [PCIE_ADDR_WIDTH-1:0]       m_axis_desc_pcie_addr,
    output wire [AXI_ADDR_WIDTH-1:0]        m_axis_desc_axi_addr,
    output wire [LEN_WIDTH-1:0]             m_axis_desc_len,
    output wire [M_TAG_WIDTH-1:0]           m_axis_desc_tag,
    output wire                             m_axis_desc_valid,
    input  wire                             m_axis_desc_ready,

    /*
     * Descriptor status input (from PCIe DMA core)
     */
    input  wire [M_TAG_WIDTH-1:0]           s_axis_desc_status_tag,
    input  wire [3:0]                       s_axis_desc_status_error,
    input  wire                             s_axis_desc_status_valid,

    /*
     * Descriptor input
     */
    input  wire [PORTS*PCIE_ADDR_WIDTH-1:0] s_axis_desc_pcie_addr,
    input  wire [PORTS*AXI_ADDR_WIDTH-1:0]  s_axis_desc_axi_addr,
    input  wire [PORTS*LEN_WIDTH-1:0]       s_axis_desc_len,
    input  wire [PORTS*S_TAG_WIDTH-1:0]     s_axis_desc_tag,
    input  wire [PORTS-1:0]                 s_axis_desc_valid,
    output wire [PORTS-1:0]                 s_axis_desc_ready,

    /*
     * Descriptor status output
     */
    output wire [PORTS*S_TAG_WIDTH-1:0]     m_axis_desc_status_tag,
    output wire [PORTS*4-1:0]               m_axis_desc_status_error,
    output wire [PORTS-1:0]                 m_axis_desc_status_valid
);

parameter CL_PORTS = $clog2(PORTS);

// check configuration
initial begin
    if (M_TAG_WIDTH < S_TAG_WIDTH+$clog2(PORTS)) begin
        $error("Error: M_TAG_WIDTH must be at least $clog2(PORTS) larger than S_TAG_WIDTH (instance %m)");
        $finish;
    end
end

// descriptor mux
wire [PORTS-1:0] request;
wire [PORTS-1:0] acknowledge;
wire [PORTS-1:0] grant;
wire grant_valid;
wire [CL_PORTS-1:0] grant_encoded;

// internal datapath
reg  [PCIE_ADDR_WIDTH-1:0] m_axis_desc_pcie_addr_int;
reg  [AXI_ADDR_WIDTH-1:0]  m_axis_desc_axi_addr_int;
reg  [LEN_WIDTH-1:0]       m_axis_desc_len_int;
reg  [M_TAG_WIDTH-1:0]     m_axis_desc_tag_int;
reg                        m_axis_desc_valid_int;
reg                        m_axis_desc_ready_int_reg = 1'b0;
wire                       m_axis_desc_ready_int_early;

assign s_axis_desc_ready = (m_axis_desc_ready_int_reg && grant_valid) << grant_encoded;

// mux for incoming packet
wire [PCIE_ADDR_WIDTH-1:0] current_s_desc_pcie_addr  = s_axis_desc_pcie_addr[grant_encoded*PCIE_ADDR_WIDTH +: PCIE_ADDR_WIDTH];
wire [AXI_ADDR_WIDTH-1:0]  current_s_desc_axi_addr   = s_axis_desc_axi_addr[grant_encoded*AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH];
wire [LEN_WIDTH-1:0]       current_s_desc_len        = s_axis_desc_len[grant_encoded*LEN_WIDTH +: LEN_WIDTH];
wire [S_TAG_WIDTH-1:0]     current_s_desc_tag        = s_axis_desc_tag[grant_encoded*S_TAG_WIDTH +: S_TAG_WIDTH];
wire                       current_s_desc_valid      = s_axis_desc_valid[grant_encoded];
wire                       current_s_desc_ready      = s_axis_desc_ready[grant_encoded];

// arbiter instance
arbiter #(
    .PORTS(PORTS),
    .ARB_TYPE_ROUND_ROBIN(ARB_TYPE_ROUND_ROBIN),
    .ARB_BLOCK(1),
    .ARB_BLOCK_ACK(1),
    .ARB_LSB_HIGH_PRIORITY(ARB_LSB_HIGH_PRIORITY)
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

assign request = s_axis_desc_valid & ~grant;
assign acknowledge = grant & s_axis_desc_valid & s_axis_desc_ready;

always @* begin
    // pass through selected packet data
    m_axis_desc_pcie_addr_int  = current_s_desc_pcie_addr;
    m_axis_desc_axi_addr_int   = current_s_desc_axi_addr;
    m_axis_desc_len_int        = current_s_desc_len;
    m_axis_desc_tag_int        = current_s_desc_tag;
    if (PORTS > 1) begin
        m_axis_desc_tag_int[M_TAG_WIDTH-1:M_TAG_WIDTH-CL_PORTS] = grant_encoded;
    end
    m_axis_desc_valid_int      = current_s_desc_valid && m_axis_desc_ready_int_reg && grant_valid;
end

// output datapath logic
reg [PCIE_ADDR_WIDTH-1:0] m_axis_desc_pcie_addr_reg  = {PCIE_ADDR_WIDTH{1'b0}};
reg [AXI_ADDR_WIDTH-1:0]  m_axis_desc_axi_addr_reg   = {AXI_ADDR_WIDTH{1'b0}};
reg [LEN_WIDTH-1:0]       m_axis_desc_len_reg        = {LEN_WIDTH{1'b0}};
reg [M_TAG_WIDTH-1:0]     m_axis_desc_tag_reg        = {M_TAG_WIDTH{1'b0}};
reg                       m_axis_desc_valid_reg      = 1'b0, m_axis_desc_valid_next;

reg [PCIE_ADDR_WIDTH-1:0] temp_m_axis_desc_pcie_addr_reg  = {PCIE_ADDR_WIDTH{1'b0}};
reg [AXI_ADDR_WIDTH-1:0]  temp_m_axis_desc_axi_addr_reg   = {AXI_ADDR_WIDTH{1'b0}};
reg [LEN_WIDTH-1:0]       temp_m_axis_desc_len_reg        = {LEN_WIDTH{1'b0}};
reg [M_TAG_WIDTH-1:0]     temp_m_axis_desc_tag_reg        = {M_TAG_WIDTH{1'b0}};
reg                       temp_m_axis_desc_valid_reg      = 1'b0, temp_m_axis_desc_valid_next;

// datapath control
reg store_axis_int_to_output;
reg store_axis_int_to_temp;
reg store_axis_temp_to_output;

assign m_axis_desc_pcie_addr  = m_axis_desc_pcie_addr_reg;
assign m_axis_desc_axi_addr   = m_axis_desc_axi_addr_reg;
assign m_axis_desc_len        = m_axis_desc_len_reg;
assign m_axis_desc_tag        = m_axis_desc_tag_reg;
assign m_axis_desc_valid      = m_axis_desc_valid_reg;

// enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
assign m_axis_desc_ready_int_early = m_axis_desc_ready || (!temp_m_axis_desc_valid_reg && (!m_axis_desc_valid_reg || !m_axis_desc_valid_int));

always @* begin
    // transfer sink ready state to source
    m_axis_desc_valid_next = m_axis_desc_valid_reg;
    temp_m_axis_desc_valid_next = temp_m_axis_desc_valid_reg;

    store_axis_int_to_output = 1'b0;
    store_axis_int_to_temp = 1'b0;
    store_axis_temp_to_output = 1'b0;

    if (m_axis_desc_ready_int_reg) begin
        // input is ready
        if (m_axis_desc_ready || !m_axis_desc_valid_reg) begin
            // output is ready or currently not valid, transfer data to output
            m_axis_desc_valid_next = m_axis_desc_valid_int;
            store_axis_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_m_axis_desc_valid_next = m_axis_desc_valid_int;
            store_axis_int_to_temp = 1'b1;
        end
    end else if (m_axis_desc_ready) begin
        // input is not ready, but output is ready
        m_axis_desc_valid_next = temp_m_axis_desc_valid_reg;
        temp_m_axis_desc_valid_next = 1'b0;
        store_axis_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    if (rst) begin
        m_axis_desc_valid_reg <= 1'b0;
        m_axis_desc_ready_int_reg <= 1'b0;
        temp_m_axis_desc_valid_reg <= 1'b0;
    end else begin
        m_axis_desc_valid_reg <= m_axis_desc_valid_next;
        m_axis_desc_ready_int_reg <= m_axis_desc_ready_int_early;
        temp_m_axis_desc_valid_reg <= temp_m_axis_desc_valid_next;
    end

    // datapath
    if (store_axis_int_to_output) begin
        m_axis_desc_pcie_addr_reg <= m_axis_desc_pcie_addr_int;
        m_axis_desc_axi_addr_reg <= m_axis_desc_axi_addr_int;
        m_axis_desc_len_reg <= m_axis_desc_len_int;
        m_axis_desc_tag_reg <= m_axis_desc_tag_int;
    end else if (store_axis_temp_to_output) begin
        m_axis_desc_pcie_addr_reg <= temp_m_axis_desc_pcie_addr_reg;
        m_axis_desc_axi_addr_reg <= temp_m_axis_desc_axi_addr_reg;
        m_axis_desc_len_reg <= temp_m_axis_desc_len_reg;
        m_axis_desc_tag_reg <= temp_m_axis_desc_tag_reg;
    end

    if (store_axis_int_to_temp) begin
        temp_m_axis_desc_pcie_addr_reg <= m_axis_desc_pcie_addr_int;
        temp_m_axis_desc_axi_addr_reg <= m_axis_desc_axi_addr_int;
        temp_m_axis_desc_len_reg <= m_axis_desc_len_int;
        temp_m_axis_desc_tag_reg <= m_axis_desc_tag_int;
    end
end

// descriptor status demux
reg [S_TAG_WIDTH-1:0] m_axis_desc_status_tag_reg = {S_TAG_WIDTH{1'b0}}, m_axis_desc_status_tag_next;
reg [3:0] m_axis_desc_status_error_reg = 4'd0, m_axis_desc_status_error_next;
reg [PORTS-1:0] m_axis_desc_status_valid_reg = {PORTS{1'b0}}, m_axis_desc_status_valid_next;

assign m_axis_desc_status_tag = {PORTS{m_axis_desc_status_tag_reg}};
assign m_axis_desc_status_error = {PORTS{m_axis_desc_status_error_reg}};
assign m_axis_desc_status_valid = m_axis_desc_status_valid_reg;

always @* begin
    m_axis_desc_status_tag_next = s_axis_desc_status_tag;
    m_axis_desc_status_error_next = s_axis_desc_status_error;
    m_axis_desc_status_valid_next = s_axis_desc_status_valid << (PORTS > 1 ? s_axis_desc_status_tag[M_TAG_WIDTH-1:M_TAG_WIDTH-CL_PORTS] : 0);
end

always @(posedge clk) begin
    if (rst) begin
        m_axis_desc_status_valid_reg <= {PORTS{1'b0}};
    end else begin
        m_axis_desc_status_valid_reg <= m_axis_desc_status_valid_next;
    end

    m_axis_desc_status_tag_reg <= m_axis_desc_status_tag_next;
    m_axis_desc_status_error_reg <= m_axis_desc_status_error_next;
end

endmodule

`resetall
