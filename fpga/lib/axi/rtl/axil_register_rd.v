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
 * AXI4 lite register (read)
 */
module axil_register_rd #
(
    // Width of data bus in bits
    parameter DATA_WIDTH = 32,
    // Width of address bus in bits
    parameter ADDR_WIDTH = 32,
    // Width of wstrb (width of data bus in words)
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    // AR channel register type
    // 0 to bypass, 1 for simple buffer
    parameter AR_REG_TYPE = 1,
    // R channel register type
    // 0 to bypass, 1 for simple buffer
    parameter R_REG_TYPE = 1
)
(
    input  wire                     clk,
    input  wire                     rst,

    /*
     * AXI lite slave interface
     */
    input  wire [ADDR_WIDTH-1:0]    s_axil_araddr,
    input  wire [2:0]               s_axil_arprot,
    input  wire                     s_axil_arvalid,
    output wire                     s_axil_arready,
    output wire [DATA_WIDTH-1:0]    s_axil_rdata,
    output wire [1:0]               s_axil_rresp,
    output wire                     s_axil_rvalid,
    input  wire                     s_axil_rready,

    /*
     * AXI lite master interface
     */
    output wire [ADDR_WIDTH-1:0]    m_axil_araddr,
    output wire [2:0]               m_axil_arprot,
    output wire                     m_axil_arvalid,
    input  wire                     m_axil_arready,
    input  wire [DATA_WIDTH-1:0]    m_axil_rdata,
    input  wire [1:0]               m_axil_rresp,
    input  wire                     m_axil_rvalid,
    output wire                     m_axil_rready
);

generate

// AR channel

if (AR_REG_TYPE > 1) begin
// skid buffer, no bubble cycles

// datapath registers
reg                    s_axil_arready_reg = 1'b0;

reg [ADDR_WIDTH-1:0]   m_axil_araddr_reg   = {ADDR_WIDTH{1'b0}};
reg [2:0]              m_axil_arprot_reg   = 3'd0;
reg                    m_axil_arvalid_reg  = 1'b0, m_axil_arvalid_next;

reg [ADDR_WIDTH-1:0]   temp_m_axil_araddr_reg   = {ADDR_WIDTH{1'b0}};
reg [2:0]              temp_m_axil_arprot_reg   = 3'd0;
reg                    temp_m_axil_arvalid_reg  = 1'b0, temp_m_axil_arvalid_next;

// datapath control
reg store_axil_ar_input_to_output;
reg store_axil_ar_input_to_temp;
reg store_axil_ar_temp_to_output;

assign s_axil_arready  = s_axil_arready_reg;

assign m_axil_araddr   = m_axil_araddr_reg;
assign m_axil_arprot   = m_axil_arprot_reg;
assign m_axil_arvalid  = m_axil_arvalid_reg;

// enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
wire s_axil_arready_early = m_axil_arready | (~temp_m_axil_arvalid_reg & (~m_axil_arvalid_reg | ~s_axil_arvalid));

always @* begin
    // transfer sink ready state to source
    m_axil_arvalid_next = m_axil_arvalid_reg;
    temp_m_axil_arvalid_next = temp_m_axil_arvalid_reg;

    store_axil_ar_input_to_output = 1'b0;
    store_axil_ar_input_to_temp = 1'b0;
    store_axil_ar_temp_to_output = 1'b0;

    if (s_axil_arready_reg) begin
        // input is ready
        if (m_axil_arready | ~m_axil_arvalid_reg) begin
            // output is ready or currently not valid, transfer data to output
            m_axil_arvalid_next = s_axil_arvalid;
            store_axil_ar_input_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_m_axil_arvalid_next = s_axil_arvalid;
            store_axil_ar_input_to_temp = 1'b1;
        end
    end else if (m_axil_arready) begin
        // input is not ready, but output is ready
        m_axil_arvalid_next = temp_m_axil_arvalid_reg;
        temp_m_axil_arvalid_next = 1'b0;
        store_axil_ar_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    if (rst) begin
        s_axil_arready_reg <= 1'b0;
        m_axil_arvalid_reg <= 1'b0;
        temp_m_axil_arvalid_reg <= 1'b0;
    end else begin
        s_axil_arready_reg <= s_axil_arready_early;
        m_axil_arvalid_reg <= m_axil_arvalid_next;
        temp_m_axil_arvalid_reg <= temp_m_axil_arvalid_next;
    end

    // datapath
    if (store_axil_ar_input_to_output) begin
        m_axil_araddr_reg <= s_axil_araddr;
        m_axil_arprot_reg <= s_axil_arprot;
    end else if (store_axil_ar_temp_to_output) begin
        m_axil_araddr_reg <= temp_m_axil_araddr_reg;
        m_axil_arprot_reg <= temp_m_axil_arprot_reg;
    end

    if (store_axil_ar_input_to_temp) begin
        temp_m_axil_araddr_reg <= s_axil_araddr;
        temp_m_axil_arprot_reg <= s_axil_arprot;
    end
end

end else if (AR_REG_TYPE == 1) begin
// simple register, inserts bubble cycles

// datapath registers
reg                    s_axil_arready_reg = 1'b0;

reg [ADDR_WIDTH-1:0]   m_axil_araddr_reg   = {ADDR_WIDTH{1'b0}};
reg [2:0]              m_axil_arprot_reg   = 3'd0;
reg                    m_axil_arvalid_reg  = 1'b0, m_axil_arvalid_next;

// datapath control
reg store_axil_ar_input_to_output;

assign s_axil_arready  = s_axil_arready_reg;

assign m_axil_araddr   = m_axil_araddr_reg;
assign m_axil_arprot   = m_axil_arprot_reg;
assign m_axil_arvalid  = m_axil_arvalid_reg;

// enable ready input next cycle if output buffer will be empty
wire s_axil_arready_early = !m_axil_arvalid_next;

always @* begin
    // transfer sink ready state to source
    m_axil_arvalid_next = m_axil_arvalid_reg;

    store_axil_ar_input_to_output = 1'b0;

    if (s_axil_arready_reg) begin
        m_axil_arvalid_next = s_axil_arvalid;
        store_axil_ar_input_to_output = 1'b1;
    end else if (m_axil_arready) begin
        m_axil_arvalid_next = 1'b0;
    end
end

always @(posedge clk) begin
    if (rst) begin
        s_axil_arready_reg <= 1'b0;
        m_axil_arvalid_reg <= 1'b0;
    end else begin
        s_axil_arready_reg <= s_axil_arready_early;
        m_axil_arvalid_reg <= m_axil_arvalid_next;
    end

    // datapath
    if (store_axil_ar_input_to_output) begin
        m_axil_araddr_reg <= s_axil_araddr;
        m_axil_arprot_reg <= s_axil_arprot;
    end
end

end else begin

    // bypass AR channel
    assign m_axil_araddr = s_axil_araddr;
    assign m_axil_arprot = s_axil_arprot;
    assign m_axil_arvalid = s_axil_arvalid;
    assign s_axil_arready = m_axil_arready;

end

// R channel

if (R_REG_TYPE > 1) begin
// skid buffer, no bubble cycles

// datapath registers
reg                   m_axil_rready_reg = 1'b0;

reg [DATA_WIDTH-1:0]  s_axil_rdata_reg  = {DATA_WIDTH{1'b0}};
reg [1:0]             s_axil_rresp_reg  = 2'b0;
reg                   s_axil_rvalid_reg = 1'b0, s_axil_rvalid_next;

reg [DATA_WIDTH-1:0]  temp_s_axil_rdata_reg  = {DATA_WIDTH{1'b0}};
reg [1:0]             temp_s_axil_rresp_reg  = 2'b0;
reg                   temp_s_axil_rvalid_reg = 1'b0, temp_s_axil_rvalid_next;

// datapath control
reg store_axil_r_input_to_output;
reg store_axil_r_input_to_temp;
reg store_axil_r_temp_to_output;

assign m_axil_rready = m_axil_rready_reg;

assign s_axil_rdata  = s_axil_rdata_reg;
assign s_axil_rresp  = s_axil_rresp_reg;
assign s_axil_rvalid = s_axil_rvalid_reg;

// enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
wire m_axil_rready_early = s_axil_rready | (~temp_s_axil_rvalid_reg & (~s_axil_rvalid_reg | ~m_axil_rvalid));

always @* begin
    // transfer sink ready state to source
    s_axil_rvalid_next = s_axil_rvalid_reg;
    temp_s_axil_rvalid_next = temp_s_axil_rvalid_reg;

    store_axil_r_input_to_output = 1'b0;
    store_axil_r_input_to_temp = 1'b0;
    store_axil_r_temp_to_output = 1'b0;

    if (m_axil_rready_reg) begin
        // input is ready
        if (s_axil_rready | ~s_axil_rvalid_reg) begin
            // output is ready or currently not valid, transfer data to output
            s_axil_rvalid_next = m_axil_rvalid;
            store_axil_r_input_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_s_axil_rvalid_next = m_axil_rvalid;
            store_axil_r_input_to_temp = 1'b1;
        end
    end else if (s_axil_rready) begin
        // input is not ready, but output is ready
        s_axil_rvalid_next = temp_s_axil_rvalid_reg;
        temp_s_axil_rvalid_next = 1'b0;
        store_axil_r_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    if (rst) begin
        m_axil_rready_reg <= 1'b0;
        s_axil_rvalid_reg <= 1'b0;
        temp_s_axil_rvalid_reg <= 1'b0;
    end else begin
        m_axil_rready_reg <= m_axil_rready_early;
        s_axil_rvalid_reg <= s_axil_rvalid_next;
        temp_s_axil_rvalid_reg <= temp_s_axil_rvalid_next;
    end

    // datapath
    if (store_axil_r_input_to_output) begin
        s_axil_rdata_reg <= m_axil_rdata;
        s_axil_rresp_reg <= m_axil_rresp;
    end else if (store_axil_r_temp_to_output) begin
        s_axil_rdata_reg <= temp_s_axil_rdata_reg;
        s_axil_rresp_reg <= temp_s_axil_rresp_reg;
    end

    if (store_axil_r_input_to_temp) begin
        temp_s_axil_rdata_reg <= m_axil_rdata;
        temp_s_axil_rresp_reg <= m_axil_rresp;
    end
end

end else if (R_REG_TYPE == 1) begin
// simple register, inserts bubble cycles

// datapath registers
reg                   m_axil_rready_reg = 1'b0;

reg [DATA_WIDTH-1:0]  s_axil_rdata_reg  = {DATA_WIDTH{1'b0}};
reg [1:0]             s_axil_rresp_reg  = 2'b0;
reg                   s_axil_rvalid_reg = 1'b0, s_axil_rvalid_next;

// datapath control
reg store_axil_r_input_to_output;

assign m_axil_rready = m_axil_rready_reg;

assign s_axil_rdata  = s_axil_rdata_reg;
assign s_axil_rresp  = s_axil_rresp_reg;
assign s_axil_rvalid = s_axil_rvalid_reg;

// enable ready input next cycle if output buffer will be empty
wire m_axil_rready_early = !s_axil_rvalid_next;

always @* begin
    // transfer sink ready state to source
    s_axil_rvalid_next = s_axil_rvalid_reg;

    store_axil_r_input_to_output = 1'b0;

    if (m_axil_rready_reg) begin
        s_axil_rvalid_next = m_axil_rvalid;
        store_axil_r_input_to_output = 1'b1;
    end else if (s_axil_rready) begin
        s_axil_rvalid_next = 1'b0;
    end
end

always @(posedge clk) begin
    if (rst) begin
        m_axil_rready_reg <= 1'b0;
        s_axil_rvalid_reg <= 1'b0;
    end else begin
        m_axil_rready_reg <= m_axil_rready_early;
        s_axil_rvalid_reg <= s_axil_rvalid_next;
    end

    // datapath
    if (store_axil_r_input_to_output) begin
        s_axil_rdata_reg <= m_axil_rdata;
        s_axil_rresp_reg <= m_axil_rresp;
    end
end

end else begin

    // bypass R channel
    assign s_axil_rdata = m_axil_rdata;
    assign s_axil_rresp = m_axil_rresp;
    assign s_axil_rvalid = m_axil_rvalid;
    assign m_axil_rready = s_axil_rready;

end

endgenerate

endmodule

`resetall
