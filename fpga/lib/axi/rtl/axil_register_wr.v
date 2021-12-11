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
 * AXI4 lite register (write)
 */
module axil_register_wr #
(
    // Width of data bus in bits
    parameter DATA_WIDTH = 32,
    // Width of address bus in bits
    parameter ADDR_WIDTH = 32,
    // Width of wstrb (width of data bus in words)
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    // AW channel register type
    // 0 to bypass, 1 for simple buffer
    parameter AW_REG_TYPE = 1,
    // W channel register type
    // 0 to bypass, 1 for simple buffer
    parameter W_REG_TYPE = 1,
    // B channel register type
    // 0 to bypass, 1 for simple buffer
    parameter B_REG_TYPE = 1
)
(
    input  wire                     clk,
    input  wire                     rst,

    /*
     * AXI lite slave interface
     */
    input  wire [ADDR_WIDTH-1:0]    s_axil_awaddr,
    input  wire [2:0]               s_axil_awprot,
    input  wire                     s_axil_awvalid,
    output wire                     s_axil_awready,
    input  wire [DATA_WIDTH-1:0]    s_axil_wdata,
    input  wire [STRB_WIDTH-1:0]    s_axil_wstrb,
    input  wire                     s_axil_wvalid,
    output wire                     s_axil_wready,
    output wire [1:0]               s_axil_bresp,
    output wire                     s_axil_bvalid,
    input  wire                     s_axil_bready,

    /*
     * AXI lite master interface
     */
    output wire [ADDR_WIDTH-1:0]    m_axil_awaddr,
    output wire [2:0]               m_axil_awprot,
    output wire                     m_axil_awvalid,
    input  wire                     m_axil_awready,
    output wire [DATA_WIDTH-1:0]    m_axil_wdata,
    output wire [STRB_WIDTH-1:0]    m_axil_wstrb,
    output wire                     m_axil_wvalid,
    input  wire                     m_axil_wready,
    input  wire [1:0]               m_axil_bresp,
    input  wire                     m_axil_bvalid,
    output wire                     m_axil_bready
);

generate

// AW channel

if (AW_REG_TYPE > 1) begin
// skid buffer, no bubble cycles

// datapath registers
reg                    s_axil_awready_reg = 1'b0;

reg [ADDR_WIDTH-1:0]   m_axil_awaddr_reg   = {ADDR_WIDTH{1'b0}};
reg [2:0]              m_axil_awprot_reg   = 3'd0;
reg                    m_axil_awvalid_reg  = 1'b0, m_axil_awvalid_next;

reg [ADDR_WIDTH-1:0]   temp_m_axil_awaddr_reg   = {ADDR_WIDTH{1'b0}};
reg [2:0]              temp_m_axil_awprot_reg   = 3'd0;
reg                    temp_m_axil_awvalid_reg  = 1'b0, temp_m_axil_awvalid_next;

// datapath control
reg store_axil_aw_input_to_output;
reg store_axil_aw_input_to_temp;
reg store_axil_aw_temp_to_output;

assign s_axil_awready  = s_axil_awready_reg;

assign m_axil_awaddr   = m_axil_awaddr_reg;
assign m_axil_awprot   = m_axil_awprot_reg;
assign m_axil_awvalid  = m_axil_awvalid_reg;

// enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
wire s_axil_awready_early = m_axil_awready | (~temp_m_axil_awvalid_reg & (~m_axil_awvalid_reg | ~s_axil_awvalid));

always @* begin
    // transfer sink ready state to source
    m_axil_awvalid_next = m_axil_awvalid_reg;
    temp_m_axil_awvalid_next = temp_m_axil_awvalid_reg;

    store_axil_aw_input_to_output = 1'b0;
    store_axil_aw_input_to_temp = 1'b0;
    store_axil_aw_temp_to_output = 1'b0;

    if (s_axil_awready_reg) begin
        // input is ready
        if (m_axil_awready | ~m_axil_awvalid_reg) begin
            // output is ready or currently not valid, transfer data to output
            m_axil_awvalid_next = s_axil_awvalid;
            store_axil_aw_input_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_m_axil_awvalid_next = s_axil_awvalid;
            store_axil_aw_input_to_temp = 1'b1;
        end
    end else if (m_axil_awready) begin
        // input is not ready, but output is ready
        m_axil_awvalid_next = temp_m_axil_awvalid_reg;
        temp_m_axil_awvalid_next = 1'b0;
        store_axil_aw_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    if (rst) begin
        s_axil_awready_reg <= 1'b0;
        m_axil_awvalid_reg <= 1'b0;
        temp_m_axil_awvalid_reg <= 1'b0;
    end else begin
        s_axil_awready_reg <= s_axil_awready_early;
        m_axil_awvalid_reg <= m_axil_awvalid_next;
        temp_m_axil_awvalid_reg <= temp_m_axil_awvalid_next;
    end

    // datapath
    if (store_axil_aw_input_to_output) begin
        m_axil_awaddr_reg <= s_axil_awaddr;
        m_axil_awprot_reg <= s_axil_awprot;
    end else if (store_axil_aw_temp_to_output) begin
        m_axil_awaddr_reg <= temp_m_axil_awaddr_reg;
        m_axil_awprot_reg <= temp_m_axil_awprot_reg;
    end

    if (store_axil_aw_input_to_temp) begin
        temp_m_axil_awaddr_reg <= s_axil_awaddr;
        temp_m_axil_awprot_reg <= s_axil_awprot;
    end
end

end else if (AW_REG_TYPE == 1) begin
// simple register, inserts bubble cycles

// datapath registers
reg                    s_axil_awready_reg = 1'b0;

reg [ADDR_WIDTH-1:0]   m_axil_awaddr_reg   = {ADDR_WIDTH{1'b0}};
reg [2:0]              m_axil_awprot_reg   = 3'd0;
reg                    m_axil_awvalid_reg  = 1'b0, m_axil_awvalid_next;

// datapath control
reg store_axil_aw_input_to_output;

assign s_axil_awready  = s_axil_awready_reg;

assign m_axil_awaddr   = m_axil_awaddr_reg;
assign m_axil_awprot   = m_axil_awprot_reg;
assign m_axil_awvalid  = m_axil_awvalid_reg;

// enable ready input next cycle if output buffer will be empty
wire s_axil_awready_early = !m_axil_awvalid_next;

always @* begin
    // transfer sink ready state to source
    m_axil_awvalid_next = m_axil_awvalid_reg;

    store_axil_aw_input_to_output = 1'b0;

    if (s_axil_awready_reg) begin
        m_axil_awvalid_next = s_axil_awvalid;
        store_axil_aw_input_to_output = 1'b1;
    end else if (m_axil_awready) begin
        m_axil_awvalid_next = 1'b0;
    end
end

always @(posedge clk) begin
    if (rst) begin
        s_axil_awready_reg <= 1'b0;
        m_axil_awvalid_reg <= 1'b0;
    end else begin
        s_axil_awready_reg <= s_axil_awready_early;
        m_axil_awvalid_reg <= m_axil_awvalid_next;
    end

    // datapath
    if (store_axil_aw_input_to_output) begin
        m_axil_awaddr_reg <= s_axil_awaddr;
        m_axil_awprot_reg <= s_axil_awprot;
    end
end

end else begin

    // bypass AW channel
    assign m_axil_awaddr = s_axil_awaddr;
    assign m_axil_awprot = s_axil_awprot;
    assign m_axil_awvalid = s_axil_awvalid;
    assign s_axil_awready = m_axil_awready;

end

// W channel

if (W_REG_TYPE > 1) begin
// skid buffer, no bubble cycles

// datapath registers
reg                   s_axil_wready_reg = 1'b0;

reg [DATA_WIDTH-1:0]  m_axil_wdata_reg  = {DATA_WIDTH{1'b0}};
reg [STRB_WIDTH-1:0]  m_axil_wstrb_reg  = {STRB_WIDTH{1'b0}};
reg                   m_axil_wvalid_reg = 1'b0, m_axil_wvalid_next;

reg [DATA_WIDTH-1:0]  temp_m_axil_wdata_reg  = {DATA_WIDTH{1'b0}};
reg [STRB_WIDTH-1:0]  temp_m_axil_wstrb_reg  = {STRB_WIDTH{1'b0}};
reg                   temp_m_axil_wvalid_reg = 1'b0, temp_m_axil_wvalid_next;

// datapath control
reg store_axil_w_input_to_output;
reg store_axil_w_input_to_temp;
reg store_axil_w_temp_to_output;

assign s_axil_wready = s_axil_wready_reg;

assign m_axil_wdata  = m_axil_wdata_reg;
assign m_axil_wstrb  = m_axil_wstrb_reg;
assign m_axil_wvalid = m_axil_wvalid_reg;

// enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
wire s_axil_wready_early = m_axil_wready | (~temp_m_axil_wvalid_reg & (~m_axil_wvalid_reg | ~s_axil_wvalid));

always @* begin
    // transfer sink ready state to source
    m_axil_wvalid_next = m_axil_wvalid_reg;
    temp_m_axil_wvalid_next = temp_m_axil_wvalid_reg;

    store_axil_w_input_to_output = 1'b0;
    store_axil_w_input_to_temp = 1'b0;
    store_axil_w_temp_to_output = 1'b0;

    if (s_axil_wready_reg) begin
        // input is ready
        if (m_axil_wready | ~m_axil_wvalid_reg) begin
            // output is ready or currently not valid, transfer data to output
            m_axil_wvalid_next = s_axil_wvalid;
            store_axil_w_input_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_m_axil_wvalid_next = s_axil_wvalid;
            store_axil_w_input_to_temp = 1'b1;
        end
    end else if (m_axil_wready) begin
        // input is not ready, but output is ready
        m_axil_wvalid_next = temp_m_axil_wvalid_reg;
        temp_m_axil_wvalid_next = 1'b0;
        store_axil_w_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    if (rst) begin
        s_axil_wready_reg <= 1'b0;
        m_axil_wvalid_reg <= 1'b0;
        temp_m_axil_wvalid_reg <= 1'b0;
    end else begin
        s_axil_wready_reg <= s_axil_wready_early;
        m_axil_wvalid_reg <= m_axil_wvalid_next;
        temp_m_axil_wvalid_reg <= temp_m_axil_wvalid_next;
    end

    // datapath
    if (store_axil_w_input_to_output) begin
        m_axil_wdata_reg <= s_axil_wdata;
        m_axil_wstrb_reg <= s_axil_wstrb;
    end else if (store_axil_w_temp_to_output) begin
        m_axil_wdata_reg <= temp_m_axil_wdata_reg;
        m_axil_wstrb_reg <= temp_m_axil_wstrb_reg;
    end

    if (store_axil_w_input_to_temp) begin
        temp_m_axil_wdata_reg <= s_axil_wdata;
        temp_m_axil_wstrb_reg <= s_axil_wstrb;
    end
end

end else if (W_REG_TYPE == 1) begin
// simple register, inserts bubble cycles

// datapath registers
reg                   s_axil_wready_reg = 1'b0;

reg [DATA_WIDTH-1:0]  m_axil_wdata_reg  = {DATA_WIDTH{1'b0}};
reg [STRB_WIDTH-1:0]  m_axil_wstrb_reg  = {STRB_WIDTH{1'b0}};
reg                   m_axil_wvalid_reg = 1'b0, m_axil_wvalid_next;

// datapath control
reg store_axil_w_input_to_output;

assign s_axil_wready = s_axil_wready_reg;

assign m_axil_wdata  = m_axil_wdata_reg;
assign m_axil_wstrb  = m_axil_wstrb_reg;
assign m_axil_wvalid = m_axil_wvalid_reg;

// enable ready input next cycle if output buffer will be empty
wire s_axil_wready_early = !m_axil_wvalid_next;

always @* begin
    // transfer sink ready state to source
    m_axil_wvalid_next = m_axil_wvalid_reg;

    store_axil_w_input_to_output = 1'b0;

    if (s_axil_wready_reg) begin
        m_axil_wvalid_next = s_axil_wvalid;
        store_axil_w_input_to_output = 1'b1;
    end else if (m_axil_wready) begin
        m_axil_wvalid_next = 1'b0;
    end
end

always @(posedge clk) begin
    if (rst) begin
        s_axil_wready_reg <= 1'b0;
        m_axil_wvalid_reg <= 1'b0;
    end else begin
        s_axil_wready_reg <= s_axil_wready_early;
        m_axil_wvalid_reg <= m_axil_wvalid_next;
    end

    // datapath
    if (store_axil_w_input_to_output) begin
        m_axil_wdata_reg <= s_axil_wdata;
        m_axil_wstrb_reg <= s_axil_wstrb;
    end
end

end else begin

    // bypass W channel
    assign m_axil_wdata = s_axil_wdata;
    assign m_axil_wstrb = s_axil_wstrb;
    assign m_axil_wvalid = s_axil_wvalid;
    assign s_axil_wready = m_axil_wready;

end

// B channel

if (B_REG_TYPE > 1) begin
// skid buffer, no bubble cycles

// datapath registers
reg                   m_axil_bready_reg = 1'b0;

reg [1:0]             s_axil_bresp_reg  = 2'b0;
reg                   s_axil_bvalid_reg = 1'b0, s_axil_bvalid_next;

reg [1:0]             temp_s_axil_bresp_reg  = 2'b0;
reg                   temp_s_axil_bvalid_reg = 1'b0, temp_s_axil_bvalid_next;

// datapath control
reg store_axil_b_input_to_output;
reg store_axil_b_input_to_temp;
reg store_axil_b_temp_to_output;

assign m_axil_bready = m_axil_bready_reg;

assign s_axil_bresp  = s_axil_bresp_reg;
assign s_axil_bvalid = s_axil_bvalid_reg;

// enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
wire m_axil_bready_early = s_axil_bready | (~temp_s_axil_bvalid_reg & (~s_axil_bvalid_reg | ~m_axil_bvalid));

always @* begin
    // transfer sink ready state to source
    s_axil_bvalid_next = s_axil_bvalid_reg;
    temp_s_axil_bvalid_next = temp_s_axil_bvalid_reg;

    store_axil_b_input_to_output = 1'b0;
    store_axil_b_input_to_temp = 1'b0;
    store_axil_b_temp_to_output = 1'b0;

    if (m_axil_bready_reg) begin
        // input is ready
        if (s_axil_bready | ~s_axil_bvalid_reg) begin
            // output is ready or currently not valid, transfer data to output
            s_axil_bvalid_next = m_axil_bvalid;
            store_axil_b_input_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_s_axil_bvalid_next = m_axil_bvalid;
            store_axil_b_input_to_temp = 1'b1;
        end
    end else if (s_axil_bready) begin
        // input is not ready, but output is ready
        s_axil_bvalid_next = temp_s_axil_bvalid_reg;
        temp_s_axil_bvalid_next = 1'b0;
        store_axil_b_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    if (rst) begin
        m_axil_bready_reg <= 1'b0;
        s_axil_bvalid_reg <= 1'b0;
        temp_s_axil_bvalid_reg <= 1'b0;
    end else begin
        m_axil_bready_reg <= m_axil_bready_early;
        s_axil_bvalid_reg <= s_axil_bvalid_next;
        temp_s_axil_bvalid_reg <= temp_s_axil_bvalid_next;
    end

    // datapath
    if (store_axil_b_input_to_output) begin
        s_axil_bresp_reg <= m_axil_bresp;
    end else if (store_axil_b_temp_to_output) begin
        s_axil_bresp_reg <= temp_s_axil_bresp_reg;
    end

    if (store_axil_b_input_to_temp) begin
        temp_s_axil_bresp_reg <= m_axil_bresp;
    end
end

end else if (B_REG_TYPE == 1) begin
// simple register, inserts bubble cycles

// datapath registers
reg                   m_axil_bready_reg = 1'b0;

reg [1:0]             s_axil_bresp_reg  = 2'b0;
reg                   s_axil_bvalid_reg = 1'b0, s_axil_bvalid_next;

// datapath control
reg store_axil_b_input_to_output;

assign m_axil_bready = m_axil_bready_reg;

assign s_axil_bresp  = s_axil_bresp_reg;
assign s_axil_bvalid = s_axil_bvalid_reg;

// enable ready input next cycle if output buffer will be empty
wire m_axil_bready_early = !s_axil_bvalid_next;

always @* begin
    // transfer sink ready state to source
    s_axil_bvalid_next = s_axil_bvalid_reg;

    store_axil_b_input_to_output = 1'b0;

    if (m_axil_bready_reg) begin
        s_axil_bvalid_next = m_axil_bvalid;
        store_axil_b_input_to_output = 1'b1;
    end else if (s_axil_bready) begin
        s_axil_bvalid_next = 1'b0;
    end
end

always @(posedge clk) begin
    if (rst) begin
        m_axil_bready_reg <= 1'b0;
        s_axil_bvalid_reg <= 1'b0;
    end else begin
        m_axil_bready_reg <= m_axil_bready_early;
        s_axil_bvalid_reg <= s_axil_bvalid_next;
    end

    // datapath
    if (store_axil_b_input_to_output) begin
        s_axil_bresp_reg <= m_axil_bresp;
    end
end

end else begin

    // bypass B channel
    assign s_axil_bresp = m_axil_bresp;
    assign s_axil_bvalid = m_axil_bvalid;
    assign m_axil_bready = s_axil_bready;

end

endgenerate

endmodule

`resetall
