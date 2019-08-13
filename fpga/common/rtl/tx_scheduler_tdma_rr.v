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
 * TDMA Transmit scheduler (round-robin)
 */
module tx_scheduler_tdma_rr #
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
    // TDMA timeslot index width
    parameter TDMA_INDEX_WIDTH = 6,
    // Queue index width
    parameter QUEUE_INDEX_WIDTH = 6,
    // Schedule absolute PTP start time, seconds part
    parameter SCHEDULE_START_S = 48'h0,
    // Schedule absolute PTP start time, nanoseconds part
    parameter SCHEDULE_START_NS = 30'h0,
    // Schedule period, seconds part
    parameter SCHEDULE_PERIOD_S = 48'd0,
    // Schedule period, nanoseconds part
    parameter SCHEDULE_PERIOD_NS = 30'd1000000,
    // Timeslot period, seconds part
    parameter TIMESLOT_PERIOD_S = 48'd0,
    // Timeslot period, nanoseconds part
    parameter TIMESLOT_PERIOD_NS = 30'd100000,
    // Timeslot active period, seconds part
    parameter ACTIVE_PERIOD_S = 48'd0,
    // Timeslot active period, nanoseconds part
    parameter ACTIVE_PERIOD_NS = 30'd100000
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
    input  wire                          s_axil_rready,

    /*
     * PTP clock
     */
    input  wire [95:0]                   ptp_ts_96,
    input  wire                          ptp_ts_step
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
reg [QUEUE_WIDTH-1:0] global_enable_reg = 0, global_enable_next;
reg [QUEUE_WIDTH-1:0] slot_enable_reg = 0;

reg slot_enable_mem_read_reg = 0;
reg [QUEUE_WIDTH-1:0] slot_enable_mem_read_data_reg = 0;

reg tdma_timeslot_active_delay_reg = 1'b0;
reg [QUEUE_WIDTH-1:0] slot_enable_delay_reg = 0;

reg [QUEUE_WIDTH-1:0] slot_enable_mem[(2**TDMA_INDEX_WIDTH)-1:0];

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
    .input_unencoded(queue_active_reg & queue_enable_reg & (global_enable_reg | slot_enable_reg)),
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
    .input_unencoded(queue_active_reg & queue_mask_reg & queue_enable_reg & (global_enable_reg | slot_enable_reg)),
    .output_valid(masked_queue_valid),
    .output_encoded(masked_queue_index),
    .output_unencoded()
);

integer i;

initial begin
    for (i = 0; i < 2**(TDMA_INDEX_WIDTH); i = i + 1) begin
        slot_enable_mem[i] = 0;
    end
end

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

    slot_enable_delay_reg <= slot_enable_mem[tdma_timeslot_index];
    tdma_timeslot_active_delay_reg <= tdma_timeslot_active;

    if (tdma_enable_reg && tdma_timeslot_active_delay_reg) begin
        slot_enable_reg <= slot_enable_delay_reg;
    end else begin
        slot_enable_reg <= 0;
    end

    if (rst) begin
        queue_active_reg <= 0;
        queue_mask_reg <= 0;
        tdma_timeslot_active_delay_reg <= 1'b0;
    end
end

// control registers
reg read_eligible;
reg write_eligible;

reg mem_wr_en;
reg mem_rd_en;

reg last_read_reg = 1'b0, last_read_next;

reg s_axil_awready_reg = 1'b0, s_axil_awready_next;
reg s_axil_wready_reg = 1'b0, s_axil_wready_next;
reg s_axil_bvalid_reg = 1'b0, s_axil_bvalid_next;
reg s_axil_arready_reg = 1'b0, s_axil_arready_next;
reg [AXIL_DATA_WIDTH-1:0] s_axil_rdata_reg = {AXIL_DATA_WIDTH{1'b0}}, s_axil_rdata_next;
reg s_axil_rvalid_reg = 1'b0, s_axil_rvalid_next;

reg tdma_enable_reg = 1'b0, tdma_enable_next;
wire tdma_locked;
wire tdma_error;

reg [79:0] set_tdma_schedule_start_reg = 0, set_tdma_schedule_start_next;
reg set_tdma_schedule_start_valid_reg = 0, set_tdma_schedule_start_valid_next;
reg [79:0] set_tdma_schedule_period_reg = 0, set_tdma_schedule_period_next;
reg set_tdma_schedule_period_valid_reg = 0, set_tdma_schedule_period_valid_next;
reg [79:0] set_tdma_timeslot_period_reg = 0, set_tdma_timeslot_period_next;
reg set_tdma_timeslot_period_valid_reg = 0, set_tdma_timeslot_period_valid_next;
reg [79:0] set_tdma_active_period_reg = 0, set_tdma_active_period_next;
reg set_tdma_active_period_valid_reg = 0, set_tdma_active_period_valid_next;

wire tdma_schedule_start;
wire [TDMA_INDEX_WIDTH-1:0] tdma_timeslot_index;
wire tdma_timeslot_start;
wire tdma_timeslot_end;
wire tdma_timeslot_active;

assign m_axis_tx_req_queue = m_axis_tx_req_queue_reg;
assign m_axis_tx_req_tag = m_axis_tx_req_tag_reg;
assign m_axis_tx_req_valid = m_axis_tx_req_valid_reg;

assign s_axil_awready = s_axil_awready_reg;
assign s_axil_wready = s_axil_wready_reg;
assign s_axil_bresp = 2'b00;
assign s_axil_bvalid = s_axil_bvalid_reg;
assign s_axil_arready = s_axil_arready_reg;
assign s_axil_rdata = slot_enable_mem_read_reg ? slot_enable_mem_read_data_reg : s_axil_rdata_reg;
assign s_axil_rresp = 2'b00;
assign s_axil_rvalid = s_axil_rvalid_reg;

wire [TDMA_INDEX_WIDTH-1:0] axil_ram_addr = mem_rd_en ? s_axil_araddr[15:8] : s_axil_awaddr[15:8];

always @* begin
    mem_wr_en = 1'b0;
    mem_rd_en = 1'b0;

    last_read_next = last_read_reg;

    s_axil_awready_next = 1'b0;
    s_axil_wready_next = 1'b0;
    s_axil_bvalid_next = s_axil_bvalid_reg && !s_axil_bready;

    s_axil_arready_next = 1'b0;
    s_axil_rdata_next = s_axil_rdata_reg;
    s_axil_rvalid_next = s_axil_rvalid_reg && !s_axil_rready;

    set_tdma_schedule_start_next = set_tdma_schedule_start_reg;
    set_tdma_schedule_start_valid_next = 1'b0;
    set_tdma_schedule_period_next = set_tdma_schedule_period_reg;
    set_tdma_schedule_period_valid_next = 1'b0;
    set_tdma_timeslot_period_next = set_tdma_timeslot_period_reg;
    set_tdma_timeslot_period_valid_next = 1'b0;
    set_tdma_active_period_next = set_tdma_active_period_reg;
    set_tdma_active_period_valid_next = 1'b0;

    queue_enable_next = queue_enable_reg;
    global_enable_next = global_enable_reg;

    tdma_enable_next = tdma_enable_reg;

    write_eligible = s_axil_awvalid && s_axil_wvalid && (!s_axil_bvalid || s_axil_bready) && (!s_axil_awready && !s_axil_wready);
    read_eligible = s_axil_arvalid && (!s_axil_rvalid || s_axil_rready) && (!s_axil_arready);

    if (write_eligible && (!read_eligible || last_read_reg)) begin
        last_read_next = 1'b0;

        // write operation
        s_axil_awready_next = 1'b1;
        s_axil_wready_next = 1'b1;
        s_axil_bvalid_next = 1'b1;

        if (s_axil_awaddr[16]) begin
            mem_wr_en = 1'b1;
        end else begin
            case (s_axil_awaddr & {{14{1'b1}}, 2'b00})
                // TDMA scheduler
                16'h0100: begin
                    // TDMA control
                    tdma_enable_next = s_axil_wdata[0];
                end
                16'h0114: set_tdma_schedule_start_next[29:0] = s_axil_wdata; // TDMA schedule start ns
                16'h0118: set_tdma_schedule_start_next[63:32] = s_axil_wdata; // TDMA schedule start sec l
                16'h011C: begin
                    // TDMA schedule start sec h
                    set_tdma_schedule_start_next[79:64] = s_axil_wdata;
                    set_tdma_schedule_start_valid_next = 1'b1;
                end
                16'h0124: set_tdma_schedule_period_next[29:0] = s_axil_wdata; // TDMA schedule period ns
                16'h0128: set_tdma_schedule_period_next[63:32] = s_axil_wdata; // TDMA schedule period sec l
                16'h012C: begin
                    // TDMA schedule period sec h
                    set_tdma_schedule_period_next[79:64] = s_axil_wdata;
                    set_tdma_schedule_period_valid_next = 1'b1;
                end
                16'h0134: set_tdma_timeslot_period_next[29:0] = s_axil_wdata; // TDMA timeslot period ns
                16'h0138: set_tdma_timeslot_period_next[63:32] = s_axil_wdata; // TDMA timeslot period sec l
                16'h013C: begin
                    // TDMA timeslot period sec h
                    set_tdma_timeslot_period_next[79:64] = s_axil_wdata;
                    set_tdma_timeslot_period_valid_next = 1'b1;
                end
                16'h0144: set_tdma_active_period_next[29:0] = s_axil_wdata; // TDMA active period ns
                16'h0148: set_tdma_active_period_next[63:32] = s_axil_wdata; // TDMA active period sec l
                16'h014C: begin
                    // TDMA active period sec h
                    set_tdma_active_period_next[79:64] = s_axil_wdata;
                    set_tdma_active_period_valid_next = 1'b1;
                end
                // 
                16'h0200: queue_enable_next = (queue_enable_reg & ~(32'hffffffff << 0)) | s_axil_wdata << 0;
                16'h0204: queue_enable_next = (queue_enable_reg & ~(32'hffffffff << 32)) | s_axil_wdata << 32;
                16'h0208: queue_enable_next = (queue_enable_reg & ~(32'hffffffff << 64)) | s_axil_wdata << 64;
                16'h020c: queue_enable_next = (queue_enable_reg & ~(32'hffffffff << 96)) | s_axil_wdata << 96;
                16'h0210: queue_enable_next = (queue_enable_reg & ~(32'hffffffff << 128)) | s_axil_wdata << 128;
                16'h0214: queue_enable_next = (queue_enable_reg & ~(32'hffffffff << 160)) | s_axil_wdata << 160;
                16'h0218: queue_enable_next = (queue_enable_reg & ~(32'hffffffff << 192)) | s_axil_wdata << 192;
                16'h021c: queue_enable_next = (queue_enable_reg & ~(32'hffffffff << 224)) | s_axil_wdata << 224;
                16'h0300: global_enable_next = (global_enable_reg & ~(32'hffffffff << 0)) | s_axil_wdata << 0;
                16'h0304: global_enable_next = (global_enable_reg & ~(32'hffffffff << 32)) | s_axil_wdata << 32;
                16'h0308: global_enable_next = (global_enable_reg & ~(32'hffffffff << 64)) | s_axil_wdata << 64;
                16'h030c: global_enable_next = (global_enable_reg & ~(32'hffffffff << 96)) | s_axil_wdata << 96;
                16'h0310: global_enable_next = (global_enable_reg & ~(32'hffffffff << 128)) | s_axil_wdata << 128;
                16'h0314: global_enable_next = (global_enable_reg & ~(32'hffffffff << 160)) | s_axil_wdata << 160;
                16'h0318: global_enable_next = (global_enable_reg & ~(32'hffffffff << 192)) | s_axil_wdata << 192;
                16'h031c: global_enable_next = (global_enable_reg & ~(32'hffffffff << 224)) | s_axil_wdata << 224;
            endcase
        end
    end else if (read_eligible) begin
        last_read_next = 1'b1;

        // read operation
        s_axil_arready_next = 1'b1;
        s_axil_rvalid_next = 1'b1;
        s_axil_rdata_next = {AXIL_DATA_WIDTH{1'b0}};

        if (s_axil_araddr[16]) begin
            mem_rd_en = 1'b1;
        end else begin
            case (s_axil_araddr & {{14{1'b1}}, 2'b00})
                16'h0000: s_axil_rdata_next = 32'h00000001;
                16'h0010: s_axil_rdata_next = QUEUE_INDEX_WIDTH;
                16'h0014: s_axil_rdata_next = TDMA_INDEX_WIDTH;
                // TDMA scheduler
                16'h0100: begin
                    // TDMA control
                    s_axil_rdata_next[0] = tdma_enable_reg;
                end
                16'h0104: begin
                    // TDMA status
                    s_axil_rdata_next[0] = tdma_locked;
                    s_axil_rdata_next[1] = tdma_error;
                end
                16'h0114: s_axil_rdata_next = set_tdma_schedule_start_reg[29:0]; // TDMA schedule start ns
                16'h0118: s_axil_rdata_next = set_tdma_schedule_start_reg[63:32]; // TDMA schedule start sec l
                16'h011C: s_axil_rdata_next = set_tdma_schedule_start_reg[79:64]; // TDMA schedule start sec h
                16'h0124: s_axil_rdata_next = set_tdma_schedule_period_reg[29:0]; // TDMA schedule period ns
                16'h0128: s_axil_rdata_next = set_tdma_schedule_period_reg[63:32]; // TDMA schedule period sec l
                16'h012C: s_axil_rdata_next = set_tdma_schedule_period_reg[79:64]; // TDMA schedule period sec h
                16'h0134: s_axil_rdata_next = set_tdma_timeslot_period_reg[29:0]; // TDMA timeslot period ns
                16'h0138: s_axil_rdata_next = set_tdma_timeslot_period_reg[63:32]; // TDMA timeslot period sec l
                16'h013C: s_axil_rdata_next = set_tdma_timeslot_period_reg[79:64]; // TDMA timeslot period sec h
                16'h0144: s_axil_rdata_next = set_tdma_active_period_reg[29:0]; // TDMA active period ns
                16'h0148: s_axil_rdata_next = set_tdma_active_period_reg[63:32]; // TDMA active period sec l
                16'h014C: s_axil_rdata_next = set_tdma_active_period_reg[79:64]; // TDMA active period sec h
                // 
                16'h0200: s_axil_rdata_next = queue_enable_reg;
                16'h0204: s_axil_rdata_next = queue_enable_reg >> 32;
                16'h0208: s_axil_rdata_next = queue_enable_reg >> 64;
                16'h020C: s_axil_rdata_next = queue_enable_reg >> 96;
                16'h0210: s_axil_rdata_next = queue_enable_reg >> 128;
                16'h0214: s_axil_rdata_next = queue_enable_reg >> 160;
                16'h0218: s_axil_rdata_next = queue_enable_reg >> 192;
                16'h021C: s_axil_rdata_next = queue_enable_reg >> 224;
                16'h0300: s_axil_rdata_next = global_enable_reg;
                16'h0304: s_axil_rdata_next = global_enable_reg >> 32;
                16'h0308: s_axil_rdata_next = global_enable_reg >> 64;
                16'h030C: s_axil_rdata_next = global_enable_reg >> 96;
                16'h0310: s_axil_rdata_next = global_enable_reg >> 128;
                16'h0314: s_axil_rdata_next = global_enable_reg >> 160;
                16'h0318: s_axil_rdata_next = global_enable_reg >> 192;
                16'h031C: s_axil_rdata_next = global_enable_reg >> 224;
            endcase
        end
    end
end

always @(posedge clk) begin
    last_read_reg <= last_read_next;

    s_axil_awready_reg <= s_axil_awready_next;
    s_axil_wready_reg <= s_axil_wready_next;
    s_axil_bvalid_reg <= s_axil_bvalid_next;

    s_axil_arready_reg <= s_axil_arready_next;
    s_axil_rdata_reg <= s_axil_rdata_next;
    s_axil_rvalid_reg <= s_axil_rvalid_next;

    set_tdma_schedule_start_reg <= set_tdma_schedule_start_next;
    set_tdma_schedule_start_valid_reg <= set_tdma_schedule_start_valid_next;
    set_tdma_schedule_period_reg <= set_tdma_schedule_period_next;
    set_tdma_schedule_period_valid_reg <= set_tdma_schedule_period_valid_next;
    set_tdma_timeslot_period_reg <= set_tdma_timeslot_period_next;
    set_tdma_timeslot_period_valid_reg <= set_tdma_timeslot_period_valid_next;
    set_tdma_active_period_reg <= set_tdma_active_period_next;
    set_tdma_active_period_valid_reg <= set_tdma_active_period_valid_next;

    queue_enable_reg <= queue_enable_next;
    global_enable_reg <= global_enable_next;

    tdma_enable_reg <= tdma_enable_next;

    slot_enable_mem_read_reg <= 1'b0;

    if (mem_rd_en) begin
        slot_enable_mem_read_data_reg <= slot_enable_mem[axil_ram_addr];
        slot_enable_mem_read_reg <= 1'b1;
    end else begin
        for (i = 0; i < WORD_WIDTH; i = i + 1) begin
            if (mem_wr_en && s_axil_wstrb[i]) begin
                slot_enable_mem[axil_ram_addr][WORD_SIZE*i +: WORD_SIZE] <= s_axil_wdata[WORD_SIZE*i +: WORD_SIZE];
            end
        end
    end

    if (rst) begin
        last_read_reg <= 1'b0;

        s_axil_awready_reg <= 1'b0;
        s_axil_wready_reg <= 1'b0;
        s_axil_bvalid_reg <= 1'b0;

        s_axil_arready_reg <= 1'b0;
        s_axil_rvalid_reg <= 1'b0;

        set_tdma_schedule_start_valid_reg <= 1'b0;
        set_tdma_schedule_period_valid_reg <= 1'b0;
        set_tdma_timeslot_period_valid_reg <= 1'b0;
        set_tdma_active_period_valid_reg <= 1'b0;

        queue_enable_reg <= 0;
        global_enable_reg <= 0;

        tdma_enable_reg <= 1'b0;
    end
end

tdma_scheduler #(
    .INDEX_WIDTH(TDMA_INDEX_WIDTH),
    .SCHEDULE_START_S(SCHEDULE_START_S),
    .SCHEDULE_START_NS(SCHEDULE_START_NS),
    .SCHEDULE_PERIOD_S(SCHEDULE_PERIOD_S),
    .SCHEDULE_PERIOD_NS(SCHEDULE_PERIOD_NS),
    .TIMESLOT_PERIOD_S(TIMESLOT_PERIOD_S),
    .TIMESLOT_PERIOD_NS(TIMESLOT_PERIOD_NS),
    .ACTIVE_PERIOD_S(ACTIVE_PERIOD_S),
    .ACTIVE_PERIOD_NS(ACTIVE_PERIOD_NS)
)
tdma_scheduler_inst (
    .clk(clk),
    .rst(rst),
    .input_ts_96(ptp_ts_96),
    .input_ts_step(ptp_ts_step),
    .enable(tdma_enable_reg),
    .input_schedule_start(set_tdma_schedule_start_reg),
    .input_schedule_start_valid(set_tdma_schedule_start_valid_reg),
    .input_schedule_period(set_tdma_schedule_period_reg),
    .input_schedule_period_valid(set_tdma_schedule_period_valid_reg),
    .input_timeslot_period(set_tdma_timeslot_period_reg),
    .input_timeslot_period_valid(set_tdma_timeslot_period_valid_reg),
    .input_active_period(set_tdma_active_period_reg),
    .input_active_period_valid(set_tdma_active_period_valid_reg),
    .locked(tdma_locked),
    .error(tdma_error),
    .schedule_start(tdma_schedule_start),
    .timeslot_index(tdma_timeslot_index),
    .timeslot_start(tdma_timeslot_start),
    .timeslot_end(tdma_timeslot_end),
    .timeslot_active(tdma_timeslot_active)
);

endmodule
