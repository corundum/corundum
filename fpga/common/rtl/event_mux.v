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
 * Event mux
 */
module event_mux #
(
    // Number of ports
    parameter PORTS = 2,
    // Queue index width
    parameter QUEUE_INDEX_WIDTH = 4,
    // Event type field width
    parameter EVENT_TYPE_WIDTH = 16,
    // Event source field width
    parameter EVENT_SOURCE_WIDTH = 16,
    // select round robin arbitration
    parameter ARB_TYPE_ROUND_ROBIN = 0,
    // LSB priority selection
    parameter ARB_LSB_HIGH_PRIORITY = 1
)
(
    input  wire                                clk,
    input  wire                                rst,

    /*
     * Event output
     */
    output wire [QUEUE_INDEX_WIDTH-1:0]        m_axis_event_queue,
    output wire [EVENT_TYPE_WIDTH-1:0]         m_axis_event_type,
    output wire [EVENT_SOURCE_WIDTH-1:0]       m_axis_event_source,
    output wire                                m_axis_event_valid,
    input  wire                                m_axis_event_ready,

    /*
     * Event input
     */
    input  wire [PORTS*QUEUE_INDEX_WIDTH-1:0]  s_axis_event_queue,
    input  wire [PORTS*EVENT_TYPE_WIDTH-1:0]   s_axis_event_type,
    input  wire [PORTS*EVENT_SOURCE_WIDTH-1:0] s_axis_event_source,
    input  wire [PORTS-1:0]                    s_axis_event_valid,
    output wire [PORTS-1:0]                    s_axis_event_ready
);

parameter CL_PORTS = $clog2(PORTS);

// eventriptor mux
wire [PORTS-1:0] request;
wire [PORTS-1:0] acknowledge;
wire [PORTS-1:0] grant;
wire grant_valid;
wire [CL_PORTS-1:0] grant_encoded;

// internal datapath
reg  [QUEUE_INDEX_WIDTH-1:0]  m_axis_event_queue_int;
reg  [EVENT_TYPE_WIDTH-1:0]   m_axis_event_type_int;
reg  [EVENT_SOURCE_WIDTH-1:0] m_axis_event_source_int;
reg                           m_axis_event_valid_int;
reg                           m_axis_event_ready_int_reg = 1'b0;
wire                          m_axis_event_ready_int_early;

assign s_axis_event_ready = (m_axis_event_ready_int_reg && grant_valid) << grant_encoded;

// mux for incoming packet
wire [QUEUE_INDEX_WIDTH-1:0]  current_s_event_queue   = s_axis_event_queue[grant_encoded*QUEUE_INDEX_WIDTH +: QUEUE_INDEX_WIDTH];
wire [EVENT_TYPE_WIDTH-1:0]   current_s_event_type    = s_axis_event_type[grant_encoded*EVENT_TYPE_WIDTH +: EVENT_TYPE_WIDTH];
wire [EVENT_SOURCE_WIDTH-1:0] current_s_event_source  = s_axis_event_source[grant_encoded*EVENT_SOURCE_WIDTH +: EVENT_SOURCE_WIDTH];
wire                          current_s_event_valid   = s_axis_event_valid[grant_encoded];
wire                          current_s_event_ready   = s_axis_event_ready[grant_encoded];

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

assign request = s_axis_event_valid & ~grant;
assign acknowledge = grant & s_axis_event_valid & s_axis_event_ready;

always @* begin
    m_axis_event_queue_int   = current_s_event_queue;
    m_axis_event_type_int    = current_s_event_type;
    m_axis_event_source_int  = current_s_event_source;
    m_axis_event_valid_int   = current_s_event_valid && m_axis_event_ready_int_reg && grant_valid;
end

// output datapath logic
reg [QUEUE_INDEX_WIDTH-1:0]  m_axis_event_queue_reg   = {QUEUE_INDEX_WIDTH{1'b0}};
reg [EVENT_TYPE_WIDTH-1:0]   m_axis_event_type_reg    = {EVENT_TYPE_WIDTH{1'b0}};
reg [EVENT_SOURCE_WIDTH-1:0] m_axis_event_source_reg  = {EVENT_SOURCE_WIDTH{1'b0}};
reg                          m_axis_event_valid_reg   = 1'b0, m_axis_event_valid_next;

reg [QUEUE_INDEX_WIDTH-1:0]  temp_m_axis_event_queue_reg   = {QUEUE_INDEX_WIDTH{1'b0}};
reg [EVENT_TYPE_WIDTH-1:0]   temp_m_axis_event_type_reg    = {EVENT_TYPE_WIDTH{1'b0}};
reg [EVENT_SOURCE_WIDTH-1:0] temp_m_axis_event_source_reg  = {EVENT_SOURCE_WIDTH{1'b0}};
reg                          temp_m_axis_event_valid_reg   = 1'b0, temp_m_axis_event_valid_next;

// datapath control
reg store_axis_int_to_output;
reg store_axis_int_to_temp;
reg store_axis_temp_to_output;

assign m_axis_event_queue   = m_axis_event_queue_reg;
assign m_axis_event_type    = m_axis_event_type_reg;
assign m_axis_event_source  = m_axis_event_source_reg;
assign m_axis_event_valid   = m_axis_event_valid_reg;

// enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
assign m_axis_event_ready_int_early = m_axis_event_ready || (!temp_m_axis_event_valid_reg && (!m_axis_event_valid_reg || !m_axis_event_valid_int));

always @* begin
    // transfer sink ready state to source
    m_axis_event_valid_next = m_axis_event_valid_reg;
    temp_m_axis_event_valid_next = temp_m_axis_event_valid_reg;

    store_axis_int_to_output = 1'b0;
    store_axis_int_to_temp = 1'b0;
    store_axis_temp_to_output = 1'b0;

    if (m_axis_event_ready_int_reg) begin
        // input is ready
        if (m_axis_event_ready || !m_axis_event_valid_reg) begin
            // output is ready or currently not valid, transfer data to output
            m_axis_event_valid_next = m_axis_event_valid_int;
            store_axis_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_m_axis_event_valid_next = m_axis_event_valid_int;
            store_axis_int_to_temp = 1'b1;
        end
    end else if (m_axis_event_ready) begin
        // input is not ready, but output is ready
        m_axis_event_valid_next = temp_m_axis_event_valid_reg;
        temp_m_axis_event_valid_next = 1'b0;
        store_axis_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    if (rst) begin
        m_axis_event_valid_reg <= 1'b0;
        m_axis_event_ready_int_reg <= 1'b0;
        temp_m_axis_event_valid_reg <= 1'b0;
    end else begin
        m_axis_event_valid_reg <= m_axis_event_valid_next;
        m_axis_event_ready_int_reg <= m_axis_event_ready_int_early;
        temp_m_axis_event_valid_reg <= temp_m_axis_event_valid_next;
    end

    // datapath
    if (store_axis_int_to_output) begin
        m_axis_event_queue_reg <= m_axis_event_queue_int;
        m_axis_event_type_reg <= m_axis_event_type_int;
        m_axis_event_source_reg <= m_axis_event_source_int;
    end else if (store_axis_temp_to_output) begin
        m_axis_event_queue_reg <= temp_m_axis_event_queue_reg;
        m_axis_event_type_reg <= temp_m_axis_event_type_reg;
        m_axis_event_source_reg <= temp_m_axis_event_source_reg;
    end

    if (store_axis_int_to_temp) begin
        temp_m_axis_event_queue_reg <= m_axis_event_queue_int;
        temp_m_axis_event_type_reg <= m_axis_event_type_int;
        temp_m_axis_event_source_reg <= m_axis_event_source_int;
    end
end

endmodule

`resetall
