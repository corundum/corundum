// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2021-2023 The Regents of the University of California
 */

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Transmit request mux
 */
module tx_req_mux #
(
    // Number of ports
    parameter PORTS = 2,
    // Queue index width
    parameter QUEUE_INDEX_WIDTH = 4,
    // Input request tag field width
    parameter S_REQ_TAG_WIDTH = 8,
    // Output request tag field width (towards transmit engine)
    // Additional bits required for response routing
    parameter M_REQ_TAG_WIDTH = S_REQ_TAG_WIDTH+$clog2(PORTS),
    // dest width
    parameter DEST_WIDTH = 8,
    // Length field width
    parameter LEN_WIDTH = 20,
    // select round robin arbitration
    parameter ARB_TYPE_ROUND_ROBIN = 0,
    // LSB priority selection
    parameter ARB_LSB_HIGH_PRIORITY = 1
)
(
    input  wire                                 clk,
    input  wire                                 rst,

    /*
     * Transmit request output (to transmit engine)
     */
    output wire [QUEUE_INDEX_WIDTH-1:0]         m_axis_req_queue,
    output wire [M_REQ_TAG_WIDTH-1:0]           m_axis_req_tag,
    output wire [DEST_WIDTH-1:0]                m_axis_req_dest,
    output wire                                 m_axis_req_valid,
    input  wire                                 m_axis_req_ready,

    /*
     * Transmit request status input (from transmit engine)
     */
    input  wire [LEN_WIDTH-1:0]                 s_axis_req_status_len,
    input  wire [M_REQ_TAG_WIDTH-1:0]           s_axis_req_status_tag,
    input  wire                                 s_axis_req_status_empty,
    input  wire                                 s_axis_req_status_error,
    input  wire                                 s_axis_req_status_valid,

    /*
     * Transmit request input
     */
    input  wire [PORTS*QUEUE_INDEX_WIDTH-1:0]   s_axis_req_queue,
    input  wire [PORTS*S_REQ_TAG_WIDTH-1:0]     s_axis_req_tag,
    input  wire [PORTS*DEST_WIDTH-1:0]          s_axis_req_dest,
    input  wire [PORTS-1:0]                     s_axis_req_valid,
    output wire [PORTS-1:0]                     s_axis_req_ready,

    /*
     * Transmit request status output
     */
    output wire [PORTS*LEN_WIDTH-1:0]           m_axis_req_status_len,
    output wire [PORTS*S_REQ_TAG_WIDTH-1:0]     m_axis_req_status_tag,
    output wire [PORTS-1:0]                     m_axis_req_status_empty,
    output wire [PORTS-1:0]                     m_axis_req_status_error,
    output wire [PORTS-1:0]                     m_axis_req_status_valid
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

// input registers to pipeline arbitration delay
reg [PORTS*QUEUE_INDEX_WIDTH-1:0] s_axis_req_queue_reg = 0;
reg [PORTS*S_REQ_TAG_WIDTH-1:0]   s_axis_req_tag_reg = 0;
reg [PORTS*DEST_WIDTH-1:0]        s_axis_req_dest_reg = 0;
reg [PORTS-1:0]                   s_axis_req_valid_reg = 0;

// internal datapath
reg  [QUEUE_INDEX_WIDTH-1:0] m_axis_req_queue_int;
reg  [M_REQ_TAG_WIDTH-1:0]   m_axis_req_tag_int;
reg  [DEST_WIDTH-1:0]        m_axis_req_dest_int;
reg                          m_axis_req_valid_int;
reg                          m_axis_req_ready_int_reg = 1'b0;
wire                         m_axis_req_ready_int_early;

assign s_axis_req_ready = ~s_axis_req_valid_reg | ({PORTS{m_axis_req_ready_int_reg}} & grant);

// mux for incoming packet
wire [QUEUE_INDEX_WIDTH-1:0] current_s_desc_queue = s_axis_req_queue_reg[grant_encoded*QUEUE_INDEX_WIDTH +: QUEUE_INDEX_WIDTH];
wire [S_REQ_TAG_WIDTH-1:0]   current_s_desc_tag   = s_axis_req_tag_reg[grant_encoded*S_REQ_TAG_WIDTH +: S_REQ_TAG_WIDTH];
wire [DEST_WIDTH-1:0]        current_s_desc_data  = s_axis_req_dest_reg[grant_encoded*DEST_WIDTH +: DEST_WIDTH];
wire                         current_s_desc_valid = s_axis_req_valid_reg[grant_encoded];
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

assign request = (s_axis_req_valid_reg & ~grant) | (s_axis_req_valid & grant);
assign acknowledge = grant & s_axis_req_valid_reg & {PORTS{m_axis_req_ready_int_reg}};

always @* begin
    // pass through selected packet data
    m_axis_req_queue_int = current_s_desc_queue;
    m_axis_req_tag_int   = {grant_encoded, current_s_desc_tag};
    m_axis_req_dest_int  = current_s_desc_data;
    m_axis_req_valid_int = current_s_desc_valid && m_axis_req_ready_int_reg && grant_valid;
end

integer i;

always @(posedge clk) begin
    // register inputs
    for (i = 0; i < PORTS; i = i + 1) begin
        if (s_axis_req_ready[i]) begin
            s_axis_req_queue_reg[i*QUEUE_INDEX_WIDTH +: QUEUE_INDEX_WIDTH] <= s_axis_req_queue[i*QUEUE_INDEX_WIDTH +: QUEUE_INDEX_WIDTH];
            s_axis_req_tag_reg[i*S_REQ_TAG_WIDTH +: S_REQ_TAG_WIDTH] <= s_axis_req_tag[i*S_REQ_TAG_WIDTH +: S_REQ_TAG_WIDTH];
            s_axis_req_dest_reg[i*DEST_WIDTH +: DEST_WIDTH] <= s_axis_req_dest[i*DEST_WIDTH +: DEST_WIDTH];
            s_axis_req_valid_reg[i] <= s_axis_req_valid[i];
       end
    end

    if (rst) begin
        s_axis_req_valid_reg <= 0;
    end
end

// output datapath logic
reg [QUEUE_INDEX_WIDTH-1:0] m_axis_req_queue_reg = {QUEUE_INDEX_WIDTH{1'b0}};
reg [M_REQ_TAG_WIDTH-1:0]   m_axis_req_tag_reg   = {M_REQ_TAG_WIDTH{1'b0}};
reg [DEST_WIDTH-1:0]        m_axis_req_dest_reg   = {DEST_WIDTH{1'b0}};
reg                         m_axis_req_valid_reg = 1'b0, m_axis_req_valid_next;

reg [QUEUE_INDEX_WIDTH-1:0] temp_m_axis_req_queue_reg = {QUEUE_INDEX_WIDTH{1'b0}};
reg [M_REQ_TAG_WIDTH-1:0]   temp_m_axis_req_tag_reg   = {M_REQ_TAG_WIDTH{1'b0}};
reg [DEST_WIDTH-1:0]        temp_m_axis_req_dest_reg   = {DEST_WIDTH{1'b0}};
reg                         temp_m_axis_req_valid_reg = 1'b0, temp_m_axis_req_valid_next;

// datapath control
reg store_axis_int_to_output;
reg store_axis_int_to_temp;
reg store_axis_temp_to_output;

assign m_axis_req_queue = m_axis_req_queue_reg;
assign m_axis_req_tag   = m_axis_req_tag_reg;
assign m_axis_req_dest  = m_axis_req_dest_reg;
assign m_axis_req_valid = m_axis_req_valid_reg;

// enable ready input next cycle if output is ready or if both output registers are empty
assign m_axis_req_ready_int_early = m_axis_req_ready || (!temp_m_axis_req_valid_reg && !m_axis_req_valid_reg);

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
    m_axis_req_valid_reg <= m_axis_req_valid_next;
    m_axis_req_ready_int_reg <= m_axis_req_ready_int_early;
    temp_m_axis_req_valid_reg <= temp_m_axis_req_valid_next;

    // datapath
    if (store_axis_int_to_output) begin
        m_axis_req_queue_reg <= m_axis_req_queue_int;
        m_axis_req_tag_reg <= m_axis_req_tag_int;
        m_axis_req_dest_reg <= m_axis_req_dest_int;
    end else if (store_axis_temp_to_output) begin
        m_axis_req_queue_reg <= temp_m_axis_req_queue_reg;
        m_axis_req_tag_reg <= temp_m_axis_req_tag_reg;
        m_axis_req_dest_reg <= temp_m_axis_req_dest_reg;
    end

    if (store_axis_int_to_temp) begin
        temp_m_axis_req_queue_reg <= m_axis_req_queue_int;
        temp_m_axis_req_tag_reg <= m_axis_req_tag_int;
        temp_m_axis_req_dest_reg <= m_axis_req_dest_int;
    end

    if (rst) begin
        m_axis_req_valid_reg <= 1'b0;
        m_axis_req_ready_int_reg <= 1'b0;
        temp_m_axis_req_valid_reg <= 1'b0;
    end
end

// request status demux
reg [LEN_WIDTH-1:0] m_axis_req_status_len_reg = {LEN_WIDTH{1'b0}}, m_axis_req_status_len_next;
reg [S_REQ_TAG_WIDTH-1:0] m_axis_req_status_tag_reg = {S_REQ_TAG_WIDTH{1'b0}}, m_axis_req_status_tag_next;
reg m_axis_req_status_empty_reg = 1'b0, m_axis_req_status_empty_next;
reg m_axis_req_status_error_reg = 1'b0, m_axis_req_status_error_next;
reg [PORTS-1:0] m_axis_req_status_valid_reg = {PORTS{1'b0}}, m_axis_req_status_valid_next;

assign m_axis_req_status_len = {PORTS{m_axis_req_status_len_reg}};
assign m_axis_req_status_tag = {PORTS{m_axis_req_status_tag_reg}};
assign m_axis_req_status_empty = {PORTS{m_axis_req_status_empty_reg}};
assign m_axis_req_status_error = {PORTS{m_axis_req_status_error_reg}};
assign m_axis_req_status_valid = m_axis_req_status_valid_reg;

always @* begin
    m_axis_req_status_len_next = s_axis_req_status_len;
    m_axis_req_status_tag_next = s_axis_req_status_tag;
    m_axis_req_status_empty_next = s_axis_req_status_empty;
    m_axis_req_status_error_next = s_axis_req_status_error;
    m_axis_req_status_valid_next = s_axis_req_status_valid << (PORTS > 1 ? (s_axis_req_status_tag >> S_REQ_TAG_WIDTH) : 0);
end

always @(posedge clk) begin
    m_axis_req_status_len_reg <= m_axis_req_status_len_next;
    m_axis_req_status_tag_reg <= m_axis_req_status_tag_next;
    m_axis_req_status_empty_reg <= m_axis_req_status_empty_next;
    m_axis_req_status_error_reg <= m_axis_req_status_error_next;
    m_axis_req_status_valid_reg <= m_axis_req_status_valid_next;

    if (rst) begin
        m_axis_req_status_valid_reg <= {PORTS{1'b0}};
    end
end

endmodule

`resetall
