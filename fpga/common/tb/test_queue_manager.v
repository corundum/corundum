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
 * Testbench for queue_manager
 */
module test_queue_manager;

// Parameters
parameter ADDR_WIDTH = 64;
parameter REQ_TAG_WIDTH = 8;
parameter OP_TABLE_SIZE = 16;
parameter OP_TAG_WIDTH = 8;
parameter QUEUE_INDEX_WIDTH = 8;
parameter CPL_INDEX_WIDTH = 8;
parameter QUEUE_PTR_WIDTH = 16;
parameter QUEUE_LOG_SIZE_WIDTH = 4;
parameter DESC_SIZE = 16;
parameter PIPELINE = 2;
parameter AXIL_DATA_WIDTH = 32;
parameter AXIL_ADDR_WIDTH = 16;
parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8);

// Inputs
reg clk = 0;
reg rst = 0;
reg [7:0] current_test = 0;

reg [QUEUE_INDEX_WIDTH-1:0] s_axis_dequeue_req_queue = 0;
reg [REQ_TAG_WIDTH-1:0] s_axis_dequeue_req_tag = 0;
reg s_axis_dequeue_req_valid = 0;
reg m_axis_dequeue_resp_ready = 0;
reg [OP_TAG_WIDTH-1:0] s_axis_dequeue_commit_op_tag = 0;
reg s_axis_dequeue_commit_valid = 0;
reg [AXIL_ADDR_WIDTH-1:0] s_axil_awaddr = 0;
reg [2:0] s_axil_awprot = 0;
reg s_axil_awvalid = 0;
reg [AXIL_DATA_WIDTH-1:0] s_axil_wdata = 0;
reg [AXIL_STRB_WIDTH-1:0] s_axil_wstrb = 0;
reg s_axil_wvalid = 0;
reg s_axil_bready = 0;
reg [AXIL_ADDR_WIDTH-1:0] s_axil_araddr = 0;
reg [2:0] s_axil_arprot = 0;
reg s_axil_arvalid = 0;
reg s_axil_rready = 0;
reg enable = 0;

// Outputs
wire s_axis_dequeue_req_ready;
wire [QUEUE_INDEX_WIDTH-1:0] m_axis_dequeue_resp_queue;
wire [QUEUE_PTR_WIDTH-1:0] m_axis_dequeue_resp_ptr;
wire [ADDR_WIDTH-1:0] m_axis_dequeue_resp_addr;
wire [CPL_INDEX_WIDTH-1:0] m_axis_dequeue_resp_cpl;
wire [REQ_TAG_WIDTH-1:0] m_axis_dequeue_resp_tag;
wire [OP_TAG_WIDTH-1:0] m_axis_dequeue_resp_op_tag;
wire m_axis_dequeue_resp_empty;
wire m_axis_dequeue_resp_error;
wire m_axis_dequeue_resp_valid;
wire s_axis_dequeue_commit_ready;
wire [QUEUE_INDEX_WIDTH-1:0] m_axis_doorbell_queue;
wire m_axis_doorbell_valid;
wire s_axil_awready;
wire s_axil_wready;
wire [1:0] s_axil_bresp;
wire s_axil_bvalid;
wire s_axil_arready;
wire [AXIL_DATA_WIDTH-1:0] s_axil_rdata;
wire [1:0] s_axil_rresp;
wire s_axil_rvalid;

initial begin
    // myhdl integration
    $from_myhdl(
        clk,
        rst,
        current_test,
        s_axis_dequeue_req_queue,
        s_axis_dequeue_req_tag,
        s_axis_dequeue_req_valid,
        m_axis_dequeue_resp_ready,
        s_axis_dequeue_commit_op_tag,
        s_axis_dequeue_commit_valid,
        s_axil_awaddr,
        s_axil_awprot,
        s_axil_awvalid,
        s_axil_wdata,
        s_axil_wstrb,
        s_axil_wvalid,
        s_axil_bready,
        s_axil_araddr,
        s_axil_arprot,
        s_axil_arvalid,
        s_axil_rready,
        enable
    );
    $to_myhdl(
        s_axis_dequeue_req_ready,
        m_axis_dequeue_resp_queue,
        m_axis_dequeue_resp_ptr,
        m_axis_dequeue_resp_addr,
        m_axis_dequeue_resp_cpl,
        m_axis_dequeue_resp_tag,
        m_axis_dequeue_resp_op_tag,
        m_axis_dequeue_resp_empty,
        m_axis_dequeue_resp_error,
        m_axis_dequeue_resp_valid,
        s_axis_dequeue_commit_ready,
        m_axis_doorbell_queue,
        m_axis_doorbell_valid,
        s_axil_awready,
        s_axil_wready,
        s_axil_bresp,
        s_axil_bvalid,
        s_axil_arready,
        s_axil_rdata,
        s_axil_rresp,
        s_axil_rvalid
    );

    // dump file
    $dumpfile("test_queue_manager.lxt");
    $dumpvars(0, test_queue_manager);
end

queue_manager #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .REQ_TAG_WIDTH(REQ_TAG_WIDTH),
    .OP_TABLE_SIZE(OP_TABLE_SIZE),
    .OP_TAG_WIDTH(OP_TAG_WIDTH),
    .QUEUE_INDEX_WIDTH(QUEUE_INDEX_WIDTH),
    .CPL_INDEX_WIDTH(CPL_INDEX_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .QUEUE_LOG_SIZE_WIDTH(QUEUE_LOG_SIZE_WIDTH),
    .DESC_SIZE(DESC_SIZE),
    .PIPELINE(PIPELINE),
    .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
    .AXIL_STRB_WIDTH(AXIL_STRB_WIDTH)
)
UUT (
    .clk(clk),
    .rst(rst),
    .s_axis_dequeue_req_queue(s_axis_dequeue_req_queue),
    .s_axis_dequeue_req_tag(s_axis_dequeue_req_tag),
    .s_axis_dequeue_req_valid(s_axis_dequeue_req_valid),
    .s_axis_dequeue_req_ready(s_axis_dequeue_req_ready),
    .m_axis_dequeue_resp_queue(m_axis_dequeue_resp_queue),
    .m_axis_dequeue_resp_ptr(m_axis_dequeue_resp_ptr),
    .m_axis_dequeue_resp_addr(m_axis_dequeue_resp_addr),
    .m_axis_dequeue_resp_cpl(m_axis_dequeue_resp_cpl),
    .m_axis_dequeue_resp_tag(m_axis_dequeue_resp_tag),
    .m_axis_dequeue_resp_op_tag(m_axis_dequeue_resp_op_tag),
    .m_axis_dequeue_resp_empty(m_axis_dequeue_resp_empty),
    .m_axis_dequeue_resp_error(m_axis_dequeue_resp_error),
    .m_axis_dequeue_resp_valid(m_axis_dequeue_resp_valid),
    .m_axis_dequeue_resp_ready(m_axis_dequeue_resp_ready),
    .s_axis_dequeue_commit_op_tag(s_axis_dequeue_commit_op_tag),
    .s_axis_dequeue_commit_valid(s_axis_dequeue_commit_valid),
    .s_axis_dequeue_commit_ready(s_axis_dequeue_commit_ready),
    .m_axis_doorbell_queue(m_axis_doorbell_queue),
    .m_axis_doorbell_valid(m_axis_doorbell_valid),
    .s_axil_awaddr(s_axil_awaddr),
    .s_axil_awprot(s_axil_awprot),
    .s_axil_awvalid(s_axil_awvalid),
    .s_axil_awready(s_axil_awready),
    .s_axil_wdata(s_axil_wdata),
    .s_axil_wstrb(s_axil_wstrb),
    .s_axil_wvalid(s_axil_wvalid),
    .s_axil_wready(s_axil_wready),
    .s_axil_bresp(s_axil_bresp),
    .s_axil_bvalid(s_axil_bvalid),
    .s_axil_bready(s_axil_bready),
    .s_axil_araddr(s_axil_araddr),
    .s_axil_arprot(s_axil_arprot),
    .s_axil_arvalid(s_axil_arvalid),
    .s_axil_arready(s_axil_arready),
    .s_axil_rdata(s_axil_rdata),
    .s_axil_rresp(s_axil_rresp),
    .s_axil_rvalid(s_axil_rvalid),
    .s_axil_rready(s_axil_rready),
    .enable(enable)
);

endmodule
