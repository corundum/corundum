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

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Completion operation mux
 */
module cpl_op_mux #
(
    // Number of ports
    parameter PORTS = 2,
    // Select field width
    parameter SELECT_WIDTH = 1,
    // Queue index width
    parameter QUEUE_INDEX_WIDTH = 4,
    // Input request tag field width
    parameter S_REQ_TAG_WIDTH = 8,
    // Output request tag field width (towards descriptor module)
    // Additional bits required for response routing
    parameter M_REQ_TAG_WIDTH = S_REQ_TAG_WIDTH+$clog2(PORTS),
    // Completion size (bytes)
    parameter CPL_SIZE = 32,
    // select round robin arbitration
    parameter ARB_TYPE_ROUND_ROBIN = 0,
    // LSB priority selection
    parameter ARB_LSB_HIGH_PRIORITY = 1
)
(
    input  wire                                   clk,
    input  wire                                   rst,

    /*
     * Completion request output (to completion module)
     */
    output wire [SELECT_WIDTH-1:0]                m_axis_req_sel,
    output wire [QUEUE_INDEX_WIDTH-1:0]           m_axis_req_queue,
    output wire [M_REQ_TAG_WIDTH-1:0]             m_axis_req_tag,
    output wire [CPL_SIZE*8-1:0]                  m_axis_req_data,
    output wire                                   m_axis_req_valid,
    input  wire                                   m_axis_req_ready,

    /*
     * Completion request status input (from completion module)
     */
    input  wire [M_REQ_TAG_WIDTH-1:0]             s_axis_req_status_tag,
    input  wire                                   s_axis_req_status_full,
    input  wire                                   s_axis_req_status_error,
    input  wire                                   s_axis_req_status_valid,

    /*
     * Completion request input
     */
    input  wire [PORTS*SELECT_WIDTH-1:0]          s_axis_req_sel,
    input  wire [PORTS*QUEUE_INDEX_WIDTH-1:0]     s_axis_req_queue,
    input  wire [PORTS*S_REQ_TAG_WIDTH-1:0]       s_axis_req_tag,
    input  wire [PORTS*CPL_SIZE*8-1:0]            s_axis_req_data,
    input  wire [PORTS-1:0]                       s_axis_req_valid,
    output wire [PORTS-1:0]                       s_axis_req_ready,

    /*
     * Completion request status output
     */
    output wire [PORTS*S_REQ_TAG_WIDTH-1:0]       m_axis_req_status_tag,
    output wire [PORTS-1:0]                       m_axis_req_status_full,
    output wire [PORTS-1:0]                       m_axis_req_status_error,
    output wire [PORTS-1:0]                       m_axis_req_status_valid
);

parameter CL_PORTS = $clog2(PORTS);

// check configuration
initial begin
    if (M_REQ_TAG_WIDTH < S_REQ_TAG_WIDTH+$clog2(PORTS)) begin
        $error("Error: M_REQ_TAG_WIDTH must be at least $clog2(PORTS) larger than S_REQ_TAG_WIDTH (instance %m)");
        $finish;
    end
end

// request mux
wire [PORTS-1:0] request;
wire [PORTS-1:0] acknowledge;
wire [PORTS-1:0] grant;
wire grant_valid;
wire [CL_PORTS-1:0] grant_encoded;

// internal datapath
reg  [SELECT_WIDTH-1:0]      m_axis_req_sel_int;
reg  [QUEUE_INDEX_WIDTH-1:0] m_axis_req_queue_int;
reg  [M_REQ_TAG_WIDTH-1:0]   m_axis_req_tag_int;
reg  [CPL_SIZE*8-1:0]        m_axis_req_data_int;
reg                          m_axis_req_valid_int;
reg                          m_axis_req_ready_int_reg = 1'b0;
wire                         m_axis_req_ready_int_early;

assign s_axis_req_ready = (m_axis_req_ready_int_reg && grant_valid) << grant_encoded;

// mux for incoming packet
wire [SELECT_WIDTH-1:0]      current_s_desc_sel   = s_axis_req_sel[grant_encoded*SELECT_WIDTH +: SELECT_WIDTH];
wire [QUEUE_INDEX_WIDTH-1:0] current_s_desc_queue = s_axis_req_queue[grant_encoded*QUEUE_INDEX_WIDTH +: QUEUE_INDEX_WIDTH];
wire [S_REQ_TAG_WIDTH-1:0]   current_s_desc_tag   = s_axis_req_tag[grant_encoded*S_REQ_TAG_WIDTH +: S_REQ_TAG_WIDTH];
wire [CPL_SIZE*8-1:0]        current_s_desc_data  = s_axis_req_data[grant_encoded*CPL_SIZE*8 +: CPL_SIZE*8];
wire                         current_s_desc_valid = s_axis_req_valid[grant_encoded];
wire                         current_s_desc_ready = s_axis_req_ready[grant_encoded];

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

assign request = s_axis_req_valid & ~grant;
assign acknowledge = grant & s_axis_req_valid & s_axis_req_ready;

always @* begin
    // pass through selected packet data
    m_axis_req_sel_int   = current_s_desc_sel;
    m_axis_req_queue_int = current_s_desc_queue;
    m_axis_req_tag_int   = {grant_encoded, current_s_desc_tag};
    m_axis_req_data_int  = current_s_desc_data;
    m_axis_req_valid_int = current_s_desc_valid && m_axis_req_ready_int_reg && grant_valid;
end

// output datapath logic
reg [SELECT_WIDTH-1:0]      m_axis_req_sel_reg   = {SELECT_WIDTH{1'b0}};
reg [QUEUE_INDEX_WIDTH-1:0] m_axis_req_queue_reg = {QUEUE_INDEX_WIDTH{1'b0}};
reg [M_REQ_TAG_WIDTH-1:0]   m_axis_req_tag_reg   = {M_REQ_TAG_WIDTH{1'b0}};
reg [CPL_SIZE*8-1:0]        m_axis_req_data_reg   = {CPL_SIZE*8{1'b0}};
reg                         m_axis_req_valid_reg = 1'b0, m_axis_req_valid_next;

reg [SELECT_WIDTH-1:0]      temp_m_axis_req_sel_reg   = {SELECT_WIDTH{1'b0}};
reg [QUEUE_INDEX_WIDTH-1:0] temp_m_axis_req_queue_reg = {QUEUE_INDEX_WIDTH{1'b0}};
reg [M_REQ_TAG_WIDTH-1:0]   temp_m_axis_req_tag_reg   = {M_REQ_TAG_WIDTH{1'b0}};
reg [CPL_SIZE*8-1:0]        temp_m_axis_req_data_reg   = {CPL_SIZE*8{1'b0}};
reg                         temp_m_axis_req_valid_reg = 1'b0, temp_m_axis_req_valid_next;

// datapath control
reg store_axis_int_to_output;
reg store_axis_int_to_temp;
reg store_axis_temp_to_output;

assign m_axis_req_sel   = m_axis_req_sel_reg;
assign m_axis_req_queue = m_axis_req_queue_reg;
assign m_axis_req_tag   = m_axis_req_tag_reg;
assign m_axis_req_data  = m_axis_req_data_reg;
assign m_axis_req_valid = m_axis_req_valid_reg;

// enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
assign m_axis_req_ready_int_early = m_axis_req_ready || (!temp_m_axis_req_valid_reg && (!m_axis_req_valid_reg || !m_axis_req_valid_int));

always @* begin
    // transfer sink ready state to source
    m_axis_req_valid_next = m_axis_req_valid_reg;
    temp_m_axis_req_valid_next = temp_m_axis_req_valid_reg;

    store_axis_int_to_output = 1'b0;
    store_axis_int_to_temp = 1'b0;
    store_axis_temp_to_output = 1'b0;

    if (m_axis_req_ready_int_reg) begin
        // input is ready
        if (m_axis_req_ready || !m_axis_req_valid_reg) begin
            // output is ready or currently not valid, transfer data to output
            m_axis_req_valid_next = m_axis_req_valid_int;
            store_axis_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_m_axis_req_valid_next = m_axis_req_valid_int;
            store_axis_int_to_temp = 1'b1;
        end
    end else if (m_axis_req_ready) begin
        // input is not ready, but output is ready
        m_axis_req_valid_next = temp_m_axis_req_valid_reg;
        temp_m_axis_req_valid_next = 1'b0;
        store_axis_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    if (rst) begin
        m_axis_req_valid_reg <= 1'b0;
        m_axis_req_ready_int_reg <= 1'b0;
        temp_m_axis_req_valid_reg <= 1'b0;
    end else begin
        m_axis_req_valid_reg <= m_axis_req_valid_next;
        m_axis_req_ready_int_reg <= m_axis_req_ready_int_early;
        temp_m_axis_req_valid_reg <= temp_m_axis_req_valid_next;
    end

    // datapath
    if (store_axis_int_to_output) begin
        m_axis_req_sel_reg <= m_axis_req_sel_int;
        m_axis_req_queue_reg <= m_axis_req_queue_int;
        m_axis_req_tag_reg <= m_axis_req_tag_int;
        m_axis_req_data_reg <= m_axis_req_data_int;
    end else if (store_axis_temp_to_output) begin
        m_axis_req_sel_reg <= temp_m_axis_req_sel_reg;
        m_axis_req_queue_reg <= temp_m_axis_req_queue_reg;
        m_axis_req_tag_reg <= temp_m_axis_req_tag_reg;
        m_axis_req_data_reg <= temp_m_axis_req_data_reg;
    end

    if (store_axis_int_to_temp) begin
        temp_m_axis_req_sel_reg <= m_axis_req_sel_int;
        temp_m_axis_req_queue_reg <= m_axis_req_queue_int;
        temp_m_axis_req_tag_reg <= m_axis_req_tag_int;
        temp_m_axis_req_data_reg <= m_axis_req_data_int;
    end
end

// request status demux
reg [S_REQ_TAG_WIDTH-1:0] m_axis_req_status_tag_reg = {S_REQ_TAG_WIDTH{1'b0}}, m_axis_req_status_tag_next;
reg m_axis_req_status_full_reg = 1'b0, m_axis_req_status_full_next;
reg m_axis_req_status_error_reg = 1'b0, m_axis_req_status_error_next;
reg [PORTS-1:0] m_axis_req_status_valid_reg = {PORTS{1'b0}}, m_axis_req_status_valid_next;

assign m_axis_req_status_tag = {PORTS{m_axis_req_status_tag_reg}};
assign m_axis_req_status_full = {PORTS{m_axis_req_status_full_reg}};
assign m_axis_req_status_error = {PORTS{m_axis_req_status_error_reg}};
assign m_axis_req_status_valid = m_axis_req_status_valid_reg;

always @* begin
    m_axis_req_status_tag_next = s_axis_req_status_tag;
    m_axis_req_status_full_next = s_axis_req_status_full;
    m_axis_req_status_error_next = s_axis_req_status_error;
    m_axis_req_status_valid_next = s_axis_req_status_valid << (PORTS > 1 ? (s_axis_req_status_tag >> S_REQ_TAG_WIDTH) : 0);
end

always @(posedge clk) begin
    if (rst) begin
        m_axis_req_status_valid_reg <= {PORTS{1'b0}};
    end else begin
        m_axis_req_status_valid_reg <= m_axis_req_status_valid_next;
    end

    m_axis_req_status_tag_reg <= m_axis_req_status_tag_next;
    m_axis_req_status_full_reg <= m_axis_req_status_full_next;
    m_axis_req_status_error_reg <= m_axis_req_status_error_next;
end

endmodule

`resetall
