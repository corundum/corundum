/*

Copyright 2019, The Regents of the University of California.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

   1. Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.

   2. Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE REGENTS OF THE UNIVERSITY OF CALIFORNIA ''AS
IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE REGENTS OF THE UNIVERSITY OF CALIFORNIA OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of The Regents of the University of California.

*/

// Language: Verilog 2001

`timescale 1ns / 1ps

/*
 * Transmit scheduler (round-robin)
 */
module tx_scheduler_rr #
(
    // Width of AXI lite data bus in bits
    parameter AXIL_DATA_WIDTH = 32,
    // Width of AXI lite address bus in bits
    parameter AXIL_ADDR_WIDTH = 16,
    // Width of AXI lite wstrb (width of data bus in words)
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    // AXI DMA length field width
    parameter AXI_DMA_LEN_WIDTH = 16,
    // Transmit request tag field width
    parameter REQ_TAG_WIDTH = 8,
    // Queue index width
    parameter QUEUE_INDEX_WIDTH = 6
)
(
    input  wire                          clk,
    input  wire                          rst,

    /*
     * Transmit request output (queue index)
     */
    output wire [QUEUE_INDEX_WIDTH-1:0]  m_axis_tx_req_queue,
    output wire [REQ_TAG_WIDTH-1:0]      m_axis_tx_req_tag,
    output wire                          m_axis_tx_req_valid,
    input  wire                          m_axis_tx_req_ready,

    /*
     * Transmit request status input
     */
    input  wire [AXI_DMA_LEN_WIDTH-1:0]  s_axis_tx_req_status_len,
    input  wire [REQ_TAG_WIDTH-1:0]      s_axis_tx_req_status_tag,
    input  wire                          s_axis_tx_req_status_valid,

    /*
     * Doorbell input
     */
    input  wire [QUEUE_INDEX_WIDTH-1:0]  s_axis_doorbell_queue,
    input  wire                          s_axis_doorbell_valid,

    /*
     * AXI-Lite slave interface
     */
    input  wire [AXIL_ADDR_WIDTH-1:0]    s_axil_awaddr,
    input  wire [2:0]                    s_axil_awprot,
    input  wire                          s_axil_awvalid,
    output wire                          s_axil_awready,
    input  wire [AXIL_DATA_WIDTH-1:0]    s_axil_wdata,
    input  wire [AXIL_STRB_WIDTH-1:0]    s_axil_wstrb,
    input  wire                          s_axil_wvalid,
    output wire                          s_axil_wready,
    output wire [1:0]                    s_axil_bresp,
    output wire                          s_axil_bvalid,
    input  wire                          s_axil_bready,
    input  wire [AXIL_ADDR_WIDTH-1:0]    s_axil_araddr,
    input  wire [2:0]                    s_axil_arprot,
    input  wire                          s_axil_arvalid,
    output wire                          s_axil_arready,
    output wire [AXIL_DATA_WIDTH-1:0]    s_axil_rdata,
    output wire [1:0]                    s_axil_rresp,
    output wire                          s_axil_rvalid,
    input  wire                          s_axil_rready
);

parameter VALID_ADDR_WIDTH = AXIL_ADDR_WIDTH - $clog2(AXIL_STRB_WIDTH);
parameter WORD_WIDTH = AXIL_STRB_WIDTH;
parameter WORD_SIZE = AXIL_DATA_WIDTH/WORD_WIDTH;

// check configuration
initial begin
    if (AXIL_ADDR_WIDTH < 18) begin // TODO
        $error("Error: AXI address width too narrow (instance %m)");
        $finish;
    end

    if (AXIL_DATA_WIDTH != 32) begin
        $error("Error: AXI data width must be 32 (instance %m)");
        $finish;
    end

    if (AXIL_STRB_WIDTH * 8 != AXIL_DATA_WIDTH) begin
        $error("Error: Interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end
end

parameter QUEUE_WIDTH = 2**QUEUE_INDEX_WIDTH;

reg [QUEUE_WIDTH-1:0] queue_enable_reg = 0, queue_enable_next;
reg [QUEUE_WIDTH-1:0] queue_active_reg = 0;
reg [QUEUE_WIDTH-1:0] queue_mask_reg = 0;

reg [QUEUE_INDEX_WIDTH-1:0] m_axis_tx_req_queue_reg = 0;
reg [REQ_TAG_WIDTH-1:0] m_axis_tx_req_tag_reg = 0;
reg m_axis_tx_req_valid_reg = 1'b0;

wire queue_valid;
wire [QUEUE_INDEX_WIDTH-1:0] queue_index;

priority_encoder #(
    .WIDTH(QUEUE_WIDTH),
    .LSB_PRIORITY("HIGH")
)
priority_encoder_inst (
    .input_unencoded(queue_active_reg & queue_enable_reg),
    .output_valid(queue_valid),
    .output_encoded(queue_index),
    .output_unencoded()
);

wire masked_queue_valid;
wire [QUEUE_INDEX_WIDTH-1:0] masked_queue_index;

priority_encoder #(
    .WIDTH(QUEUE_WIDTH),
    .LSB_PRIORITY("HIGH")
)
priority_encoder_masked (
    .input_unencoded(queue_active_reg & queue_mask_reg & queue_enable_reg),
    .output_valid(masked_queue_valid),
    .output_encoded(masked_queue_index),
    .output_unencoded()
);

always @(posedge clk) begin
    if (s_axis_doorbell_valid) begin
        queue_active_reg <= queue_active_reg | (1 << s_axis_doorbell_queue);
    end

    // TODO deactivate idle queues

    m_axis_tx_req_valid_reg <= m_axis_tx_req_valid_reg && !m_axis_tx_req_ready;

    if (!m_axis_tx_req_valid || m_axis_tx_req_ready) begin
        if (queue_valid) begin
            if (masked_queue_valid) begin
                m_axis_tx_req_queue_reg <= masked_queue_index;
                m_axis_tx_req_valid_reg <= 1'b1;
                queue_mask_reg <= {QUEUE_WIDTH{1'b1}} << (masked_queue_index + 1);
            end else begin
                m_axis_tx_req_queue_reg <= queue_index;
                m_axis_tx_req_valid_reg <= 1'b1;
                queue_mask_reg <= {QUEUE_WIDTH{1'b1}} << (queue_index + 1);
            end
        end
    end

    if (rst) begin
        queue_active_reg <= 0;
        queue_mask_reg <= 0;
    end
end

// control registers
reg s_axil_awready_reg = 1'b0, s_axil_awready_next;
reg s_axil_wready_reg = 1'b0, s_axil_wready_next;
reg s_axil_bvalid_reg = 1'b0, s_axil_bvalid_next;
reg s_axil_arready_reg = 1'b0, s_axil_arready_next;
reg [AXIL_DATA_WIDTH-1:0] s_axil_rdata_reg = {AXIL_DATA_WIDTH{1'b0}}, s_axil_rdata_next;
reg s_axil_rvalid_reg = 1'b0, s_axil_rvalid_next;

assign m_axis_tx_req_queue = m_axis_tx_req_queue_reg;
assign m_axis_tx_req_tag = m_axis_tx_req_tag_reg;
assign m_axis_tx_req_valid = m_axis_tx_req_valid_reg;

assign s_axil_awready = s_axil_awready_reg;
assign s_axil_wready = s_axil_wready_reg;
assign s_axil_bresp = 2'b00;
assign s_axil_bvalid = s_axil_bvalid_reg;
assign s_axil_arready = s_axil_arready_reg;
assign s_axil_rdata = s_axil_rdata_reg;
assign s_axil_rresp = 2'b00;
assign s_axil_rvalid = s_axil_rvalid_reg;

always @* begin
    s_axil_awready_next = 1'b0;
    s_axil_wready_next = 1'b0;
    s_axil_bvalid_next = s_axil_bvalid_reg && !s_axil_bready;

    s_axil_arready_next = 1'b0;
    s_axil_rdata_next = s_axil_rdata_reg;
    s_axil_rvalid_next = s_axil_rvalid_reg && !s_axil_rready;

    queue_enable_next = queue_enable_reg;

    if (s_axil_awvalid && s_axil_wvalid && !s_axil_bvalid) begin
        // write operation
        s_axil_awready_next = 1'b1;
        s_axil_wready_next = 1'b1;
        s_axil_bvalid_next = 1'b1;

        case (s_axil_awaddr & {{AXIL_ADDR_WIDTH{1'b1}}, 2'b00})
            16'h0200: queue_enable_next = (queue_enable_reg & ~(32'hffffffff << 0)) | s_axil_wdata << 0;
            16'h0204: queue_enable_next = (queue_enable_reg & ~(32'hffffffff << 32)) | s_axil_wdata << 32;
            16'h0208: queue_enable_next = (queue_enable_reg & ~(32'hffffffff << 64)) | s_axil_wdata << 64;
            16'h020c: queue_enable_next = (queue_enable_reg & ~(32'hffffffff << 96)) | s_axil_wdata << 96;
            16'h0210: queue_enable_next = (queue_enable_reg & ~(32'hffffffff << 128)) | s_axil_wdata << 128;
            16'h0214: queue_enable_next = (queue_enable_reg & ~(32'hffffffff << 160)) | s_axil_wdata << 160;
            16'h0218: queue_enable_next = (queue_enable_reg & ~(32'hffffffff << 192)) | s_axil_wdata << 192;
            16'h021c: queue_enable_next = (queue_enable_reg & ~(32'hffffffff << 224)) | s_axil_wdata << 224;
        endcase
    end

    if (s_axil_arvalid && !s_axil_rvalid) begin
        // read operation
        s_axil_arready_next = 1'b1;
        s_axil_rvalid_next = 1'b1;
        s_axil_rdata_next = {AXIL_DATA_WIDTH{1'b0}};

        case (s_axil_araddr & {{AXIL_ADDR_WIDTH{1'b1}}, 2'b00})
            16'h0000: s_axil_rdata_next = 32'h00000001;
            16'h0010: s_axil_rdata_next = QUEUE_INDEX_WIDTH;
            16'h0014: s_axil_rdata_next = 0;
            // 
            16'h0200: s_axil_rdata_next = queue_enable_reg;
            16'h0204: s_axil_rdata_next = queue_enable_reg >> 32;
            16'h0208: s_axil_rdata_next = queue_enable_reg >> 64;
            16'h020C: s_axil_rdata_next = queue_enable_reg >> 96;
            16'h0210: s_axil_rdata_next = queue_enable_reg >> 128;
            16'h0214: s_axil_rdata_next = queue_enable_reg >> 160;
            16'h0218: s_axil_rdata_next = queue_enable_reg >> 192;
            16'h021C: s_axil_rdata_next = queue_enable_reg >> 224;
        endcase
    end
end

always @(posedge clk) begin
    s_axil_awready_reg <= s_axil_awready_next;
    s_axil_wready_reg <= s_axil_wready_next;
    s_axil_bvalid_reg <= s_axil_bvalid_next;

    s_axil_arready_reg <= s_axil_arready_next;
    s_axil_rdata_reg <= s_axil_rdata_next;
    s_axil_rvalid_reg <= s_axil_rvalid_next;

    queue_enable_reg <= queue_enable_next;

    if (rst) begin
        s_axil_awready_reg <= 1'b0;
        s_axil_wready_reg <= 1'b0;
        s_axil_bvalid_reg <= 1'b0;

        s_axil_arready_reg <= 1'b0;
        s_axil_rvalid_reg <= 1'b0;

        queue_enable_reg <= 0;
    end
end

endmodule
