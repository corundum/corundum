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

`timescale 1ns / 1ps

/*
 * PCIe tag manager
 */
module pcie_tag_manager #
(
    parameter PCIE_TAG_COUNT = 256,
    parameter PCIE_TAG_WIDTH = $clog2(PCIE_TAG_COUNT),
    parameter PCIE_EXT_TAG_ENABLE = 1
)
(
    input  wire                       clk,
    input  wire                       rst,

    /*
     * AXIS tag output
     */
    output wire [PCIE_TAG_WIDTH-1:0]  m_axis_tag,
    output wire                       m_axis_tag_valid,
    input  wire                       m_axis_tag_ready,

    /*
     * AXIS tag output
     */
    input  wire [PCIE_TAG_WIDTH-1:0]  s_axis_tag,
    input  wire                       s_axis_tag_valid,

    /*
     * Configuration
     */
    input  wire                       ext_tag_enable,

    /*
     * Status
     */
    output wire [PCIE_TAG_COUNT-1:0]  active_tags
);

// parameter assertions
initial begin
    if (PCIE_TAG_WIDTH < $clog2(PCIE_TAG_COUNT)) begin
        $error("Error: PCIe tag width insufficient for requested tag count (instance %m)");
        $finish;
    end

    if (PCIE_TAG_COUNT < 1 || PCIE_TAG_COUNT > 256) begin
        $error("Error: PCIe tag count must be between 1 and 256 (instance %m)");
        $finish;
    end

    if (PCIE_TAG_COUNT > 32 && !PCIE_EXT_TAG_ENABLE) begin
        $warning("Warning: PCIe tag count set larger than 32, but extended tag support is disabled (instance %m)");
    end

    if (PCIE_TAG_COUNT <= 32 && PCIE_EXT_TAG_ENABLE) begin
        $warning("Warning: PCIe tag count set to 32 or less, but extended tag support is enabled (instance %m)");
    end
end

reg [PCIE_TAG_COUNT-1:0] tag_active_reg = {PCIE_TAG_COUNT{1'b0}}, tag_active_next;
reg [PCIE_TAG_COUNT-1:0] tag_mask_reg = {PCIE_TAG_COUNT{1'b0}}, tag_mask_next;

reg [PCIE_TAG_WIDTH-1:0] m_axis_tag_reg = {PCIE_TAG_WIDTH{1'b0}}, m_axis_tag_next;
reg m_axis_tag_valid_reg = 1'b0, m_axis_tag_valid_next;

assign m_axis_tag = m_axis_tag_reg;
assign m_axis_tag_valid = m_axis_tag_valid_reg;

assign active_tags = tag_active_reg;

wire tag_valid;
wire [PCIE_TAG_WIDTH-1:0] tag_index;

priority_encoder #(
    .WIDTH(PCIE_TAG_COUNT),
    .LSB_PRIORITY("HIGH")
)
priority_encoder_inst (
    .input_unencoded(~tag_active_reg & (ext_tag_enable && PCIE_EXT_TAG_ENABLE ? {256{1'b1}} : {32{1'b1}})),
    .output_valid(tag_valid),
    .output_encoded(tag_index),
    .output_unencoded()
);

wire masked_tag_valid;
wire [PCIE_TAG_WIDTH-1:0] masked_tag_index;

priority_encoder #(
    .WIDTH(PCIE_TAG_COUNT),
    .LSB_PRIORITY("HIGH")
)
priority_encoder_masked (
    .input_unencoded(~tag_active_reg & tag_mask_reg & (ext_tag_enable && PCIE_EXT_TAG_ENABLE ? {256{1'b1}} : {32{1'b1}})),
    .output_valid(masked_tag_valid),
    .output_encoded(masked_tag_index),
    .output_unencoded()
);

always @* begin
    tag_active_next = tag_active_reg;
    tag_mask_next = tag_mask_reg;

    m_axis_tag_next = m_axis_tag_reg;
    m_axis_tag_valid_next = m_axis_tag_valid_reg && !m_axis_tag_ready;

    if (s_axis_tag_valid) begin
        tag_active_next[s_axis_tag] = 1'b0;
    end

    if (!m_axis_tag_valid || m_axis_tag_ready) begin
        if (tag_valid) begin
            if (masked_tag_valid) begin
                m_axis_tag_next = masked_tag_index;
                m_axis_tag_valid_next = 1'b1;
                tag_active_next[masked_tag_index] = 1'b1;
                tag_mask_next = {PCIE_TAG_COUNT{1'b1}} << (masked_tag_index + 1);
            end else begin
                m_axis_tag_next = tag_index;
                m_axis_tag_valid_next = 1'b1;
                tag_active_next[tag_index] = 1'b1;
                tag_mask_next = {PCIE_TAG_COUNT{1'b1}} << (tag_index + 1);
            end
        end
    end
end

always @(posedge clk) begin
    if (rst) begin
        tag_active_reg <= {PCIE_TAG_COUNT{1'b0}};
        tag_mask_reg <= {PCIE_TAG_COUNT{1'b0}};
        m_axis_tag_valid_reg <= 1'b0;
    end else begin
        tag_active_reg <= tag_active_next;
        tag_mask_reg <= tag_mask_next;
        m_axis_tag_valid_reg <= m_axis_tag_valid_next;
    end

    m_axis_tag_reg <= m_axis_tag_next;
end

endmodule
