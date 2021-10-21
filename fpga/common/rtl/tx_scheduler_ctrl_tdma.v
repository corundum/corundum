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
 * TDMA Transmit scheduler control module
 */
module tx_scheduler_ctrl_tdma #
(
    // Width of AXI lite data bus in bits
    parameter AXIL_DATA_WIDTH = 32,
    // Width of AXI lite address bus in bits
    parameter AXIL_ADDR_WIDTH = 16,
    // Width of AXI lite wstrb (width of data bus in words)
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    // TDMA timeslot index width
    parameter TDMA_INDEX_WIDTH = 6,
    // Queue index width
    parameter QUEUE_INDEX_WIDTH = 6,
    // Pipeline stages
    parameter PIPELINE = 2
)
(
    input  wire                          clk,
    input  wire                          rst,

    /*
     * Scheduler control output
     */
    output wire [QUEUE_INDEX_WIDTH-1:0]  m_axis_sched_ctrl_queue,
    output wire                          m_axis_sched_ctrl_enable,
    output wire                          m_axis_sched_ctrl_valid,
    input  wire                          m_axis_sched_ctrl_ready,

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
     * TDMA schedule inputs
     */
    input  wire                          tdma_schedule_start,
    input  wire [TDMA_INDEX_WIDTH-1:0]   tdma_timeslot_index,
    input  wire                          tdma_timeslot_start,
    input  wire                          tdma_timeslot_end,
    input  wire                          tdma_timeslot_active
);

parameter WORD_WIDTH = AXIL_STRB_WIDTH;
parameter WORD_SIZE = AXIL_DATA_WIDTH/WORD_WIDTH;

parameter QUEUE_COUNT = 2**QUEUE_INDEX_WIDTH;

parameter QUEUE_RAM_BE_WIDTH = (2**TDMA_INDEX_WIDTH+WORD_SIZE-1)/WORD_SIZE;
parameter QUEUE_RAM_WIDTH = QUEUE_RAM_BE_WIDTH*WORD_SIZE;

parameter ADDR_SHIFT = QUEUE_RAM_BE_WIDTH > AXIL_STRB_WIDTH ? $clog2(QUEUE_RAM_BE_WIDTH) : $clog2(AXIL_STRB_WIDTH);

parameter SEGMENT_SHIFT = $clog2(AXIL_STRB_WIDTH);
parameter SEGMENT_AW = QUEUE_RAM_BE_WIDTH > AXIL_STRB_WIDTH ? $clog2(QUEUE_RAM_BE_WIDTH) - $clog2(AXIL_STRB_WIDTH) : 0;
parameter SEGMENT_COUNT = 2**SEGMENT_AW;

// bus width assertions
initial begin
    if (WORD_SIZE != 8) begin
        $error("Error: AXI lite interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end

    if (AXIL_ADDR_WIDTH < QUEUE_INDEX_WIDTH+ADDR_SHIFT) begin
        $error("Error: AXI lite address width too narrow (instance %m)");
        $finish;
    end
end

localparam [2:0]
    STATE_IDLE = 3'd0,
    STATE_FILL_START = 3'd1,
    STATE_WAIT_START = 3'd2,
    STATE_START_0 = 3'd3,
    STATE_START_N = 3'd4,
    STATE_WAIT_STOP = 3'd5,
    STATE_STOP = 3'd6;

reg [2:0] state_reg = STATE_IDLE, state_next;

reg read_eligible;
reg write_eligible;

reg set_inconsistent;
reg clear_inconsistent;
reg inconsistent_reg = 1'b0;

reg last_read_reg = 1'b0, last_read_next;

reg [QUEUE_INDEX_WIDTH-1:0] m_axis_sched_ctrl_queue_reg = 1'b0, m_axis_sched_ctrl_queue_next;
reg m_axis_sched_ctrl_enable_reg = 1'b0, m_axis_sched_ctrl_enable_next;
reg m_axis_sched_ctrl_valid_reg = 1'b0, m_axis_sched_ctrl_valid_next;

reg s_axil_awready_reg = 1'b0, s_axil_awready_next;
reg s_axil_wready_reg = 1'b0, s_axil_wready_next;
reg s_axil_bvalid_reg = 1'b0, s_axil_bvalid_next;
reg s_axil_arready_reg = 1'b0, s_axil_arready_next;
reg [AXIL_DATA_WIDTH-1:0] s_axil_rdata_reg = {AXIL_DATA_WIDTH{1'b0}};
reg s_axil_rvalid_reg = 1'b0;

// (* RAM_STYLE="BLOCK" *)
reg [QUEUE_RAM_WIDTH-1:0] queue_ram[QUEUE_COUNT-1:0];
reg [QUEUE_INDEX_WIDTH-1:0] queue_ram_axil_ptr;
reg queue_ram_axil_wr_en;
reg [QUEUE_RAM_WIDTH-1:0] queue_ram_axil_wr_data;
reg [QUEUE_RAM_BE_WIDTH-1:0] queue_ram_axil_wr_be;
reg queue_ram_axil_rd_en;
reg [QUEUE_RAM_WIDTH-1:0] queue_ram_read_data_pipeline_reg[PIPELINE-1:0];
reg [SEGMENT_AW-1:0] queue_ram_read_data_shift_pipeline_reg[PIPELINE-1:0];
reg [PIPELINE-1:0] queue_ram_read_data_valid_pipeline_reg;

reg [QUEUE_INDEX_WIDTH-1:0] queue_ram_ptr_reg = 0, queue_ram_ptr_next;

reg [QUEUE_INDEX_WIDTH-1:0] start_queue_ts_0_ram[QUEUE_COUNT-1:0];
reg [QUEUE_INDEX_WIDTH+1-1:0] start_queue_ts_0_wr_ptr_reg = 0, start_queue_ts_0_wr_ptr_next;
reg [QUEUE_INDEX_WIDTH+1-1:0] start_queue_ts_0_rd_ptr_reg = 0, start_queue_ts_0_rd_ptr_next;
reg [QUEUE_INDEX_WIDTH-1:0] start_queue_ts_0_wr_data;
reg start_queue_ts_0_wr_en;

reg [QUEUE_INDEX_WIDTH-1:0] start_queue_ts_n_ram[QUEUE_COUNT-1:0];
reg [QUEUE_INDEX_WIDTH+1-1:0] start_queue_ts_n_wr_ptr_reg = 0, start_queue_ts_n_wr_ptr_next;
reg [QUEUE_INDEX_WIDTH+1-1:0] start_queue_ts_n_rd_ptr_reg = 0, start_queue_ts_n_rd_ptr_next;
reg [QUEUE_INDEX_WIDTH-1:0] start_queue_ts_n_wr_data;
reg start_queue_ts_n_wr_en;

reg [QUEUE_INDEX_WIDTH-1:0] stop_queue_ram[QUEUE_COUNT-1:0];
reg [QUEUE_INDEX_WIDTH+1-1:0] stop_queue_wr_ptr_reg = 0, stop_queue_wr_ptr_next;
reg [QUEUE_INDEX_WIDTH+1-1:0] stop_queue_rd_ptr_reg = 0, stop_queue_rd_ptr_next;
reg [QUEUE_INDEX_WIDTH-1:0] stop_queue_wr_data;
reg stop_queue_wr_en;

reg got_start_reg = 0, got_start_next;
reg [TDMA_INDEX_WIDTH-1:0] start_index_reg = 0, start_index_next;
reg [TDMA_INDEX_WIDTH-1:0] cur_index_reg = 0, cur_index_next;
reg got_stop_reg = 0, got_stop_next;

assign m_axis_sched_ctrl_queue = m_axis_sched_ctrl_queue_reg;
assign m_axis_sched_ctrl_enable = m_axis_sched_ctrl_enable_reg;
assign m_axis_sched_ctrl_valid = m_axis_sched_ctrl_valid_reg;

assign s_axil_awready = s_axil_awready_reg;
assign s_axil_wready = s_axil_wready_reg;
assign s_axil_bresp = 2'b00;
assign s_axil_bvalid = s_axil_bvalid_reg;
assign s_axil_arready = s_axil_arready_reg;
assign s_axil_rdata = s_axil_rdata_reg;
assign s_axil_rresp = 2'b00;
assign s_axil_rvalid = s_axil_rvalid_reg;

integer i, j;

initial begin
    // two nested loops for smaller number of iterations per loop
    // workaround for synthesizer complaints about large loop counts
    for (i = 0; i < 2**QUEUE_INDEX_WIDTH; i = i + 2**(QUEUE_INDEX_WIDTH/2)) begin
        for (j = i; j < i + 2**(QUEUE_INDEX_WIDTH/2); j = j + 1) begin
            queue_ram[j] = 0;
        end
    end

    for (i = 0; i < PIPELINE; i = i + 1) begin
        queue_ram_read_data_pipeline_reg[i] = 0;
        queue_ram_read_data_shift_pipeline_reg[i] = 0;
        queue_ram_read_data_valid_pipeline_reg[i] = 0;
    end
end

always @* begin
    state_next = state_reg;

    clear_inconsistent = 1'b0;

    start_queue_ts_0_wr_data = queue_ram_ptr_reg;
    start_queue_ts_n_wr_data = queue_ram_ptr_reg;
    start_queue_ts_0_wr_en = 1'b0;
    start_queue_ts_n_wr_en = 1'b0;
    stop_queue_wr_data = 0;
    stop_queue_wr_en = 1'b0;

    got_start_next = got_start_reg;
    start_index_next = start_index_reg;
    cur_index_next = cur_index_reg;
    got_stop_next = got_stop_reg;

    start_queue_ts_0_wr_ptr_next = start_queue_ts_0_wr_ptr_reg;
    start_queue_ts_0_rd_ptr_next = start_queue_ts_0_rd_ptr_reg;
    start_queue_ts_n_wr_ptr_next = start_queue_ts_n_wr_ptr_reg;
    start_queue_ts_n_rd_ptr_next = start_queue_ts_n_rd_ptr_reg;
    stop_queue_wr_ptr_next = stop_queue_wr_ptr_reg;
    stop_queue_rd_ptr_next = stop_queue_rd_ptr_reg;

    queue_ram_ptr_next = queue_ram_ptr_reg;

    m_axis_sched_ctrl_queue_next = m_axis_sched_ctrl_queue_reg;
    m_axis_sched_ctrl_enable_next = m_axis_sched_ctrl_enable_reg;
    m_axis_sched_ctrl_valid_next = m_axis_sched_ctrl_valid_reg && !m_axis_sched_ctrl_ready;

    case (state_reg)
        STATE_IDLE: begin
            start_queue_ts_0_rd_ptr_next = 0;
            start_queue_ts_0_wr_ptr_next = 0;
            start_queue_ts_n_rd_ptr_next = 0;
            start_queue_ts_n_wr_ptr_next = 0;
            queue_ram_ptr_next = 0;
            clear_inconsistent = 1'b1;
            state_next = STATE_FILL_START;
        end
        STATE_FILL_START: begin
            // fill up start queue
            start_queue_ts_0_wr_data = queue_ram_ptr_reg;
            if (queue_ram[queue_ram_ptr_reg] & 1) begin
                start_queue_ts_0_wr_en = 1'b1;
                start_queue_ts_0_wr_ptr_next = start_queue_ts_0_wr_ptr_reg+1;
            end

            start_queue_ts_n_wr_data = queue_ram_ptr_reg;
            if (queue_ram[queue_ram_ptr_reg] & (1 << cur_index_reg)) begin
                start_queue_ts_n_wr_en = 1'b1;
                start_queue_ts_n_wr_ptr_next = start_queue_ts_n_wr_ptr_reg+1;
            end

            queue_ram_ptr_next = queue_ram_ptr_reg+1;

            if (queue_ram_ptr_reg+1 == QUEUE_COUNT) begin
                state_next = STATE_WAIT_START;
            end else begin
                state_next = STATE_FILL_START;
            end
        end
        STATE_WAIT_START: begin
            // wait for start event
            stop_queue_rd_ptr_next = 0;
            stop_queue_wr_ptr_next = 0;
            if (got_start_reg) begin
                cur_index_next = start_index_reg+1;
                if (!inconsistent_reg && start_index_reg == 0) begin
                    if (start_queue_ts_0_wr_ptr_reg == 0) begin
                        stop_queue_rd_ptr_next = 0;
                        got_start_next = 1'b0;
                        state_next = STATE_WAIT_STOP;
                    end else begin
                        state_next = STATE_START_0;
                    end
                end else if (!inconsistent_reg && start_index_reg == cur_index_reg) begin
                    if (start_queue_ts_n_wr_ptr_reg == 0) begin
                        stop_queue_rd_ptr_next = 0;
                        got_start_next = 1'b0;
                        state_next = STATE_WAIT_STOP;
                    end else begin
                        state_next = STATE_START_N;
                    end
                end else begin
                    start_queue_ts_0_rd_ptr_next = 0;
                    start_queue_ts_0_wr_ptr_next = 0;
                    start_queue_ts_n_rd_ptr_next = 0;
                    start_queue_ts_n_wr_ptr_next = 0;
                    queue_ram_ptr_next = 0;
                    clear_inconsistent = 1'b1;
                    cur_index_next = start_index_reg;
                    state_next = STATE_FILL_START;
                end
            end else begin
                state_next = STATE_WAIT_START;
            end
        end
        STATE_START_0: begin
            // output start queue
            if (!m_axis_sched_ctrl_valid_reg || m_axis_sched_ctrl_ready) begin
                m_axis_sched_ctrl_queue_next = start_queue_ts_0_ram[start_queue_ts_0_rd_ptr_reg];
                m_axis_sched_ctrl_enable_next = 1'b1;
                m_axis_sched_ctrl_valid_next = 1'b1;

                stop_queue_wr_data = start_queue_ts_0_ram[start_queue_ts_0_rd_ptr_reg];
                start_queue_ts_0_rd_ptr_next = start_queue_ts_0_rd_ptr_reg+1;

                stop_queue_wr_en = 1'b1;
                stop_queue_wr_ptr_next = stop_queue_wr_ptr_reg+1;

                if (start_queue_ts_0_rd_ptr_reg+1 == start_queue_ts_0_wr_ptr_reg) begin
                    stop_queue_rd_ptr_next = 0;
                    got_start_next = 1'b0;
                    state_next = STATE_WAIT_STOP;
                end else begin
                    state_next = STATE_START_0;
                end
            end else begin
                state_next = STATE_START_0;
            end
        end
        STATE_START_N: begin
            // output start queue
            if (!m_axis_sched_ctrl_valid_reg || m_axis_sched_ctrl_ready) begin
                m_axis_sched_ctrl_queue_next = start_queue_ts_n_ram[start_queue_ts_n_rd_ptr_reg];
                m_axis_sched_ctrl_enable_next = 1'b1;
                m_axis_sched_ctrl_valid_next = 1'b1;

                stop_queue_wr_data = start_queue_ts_n_ram[start_queue_ts_n_rd_ptr_reg];
                start_queue_ts_n_rd_ptr_next = start_queue_ts_n_rd_ptr_reg+1;

                stop_queue_wr_en = 1'b1;
                stop_queue_wr_ptr_next = stop_queue_wr_ptr_reg+1;

                if (start_queue_ts_n_rd_ptr_reg+1 == start_queue_ts_n_wr_ptr_reg) begin
                    stop_queue_rd_ptr_next = 0;
                    got_start_next = 1'b0;
                    state_next = STATE_WAIT_STOP;
                end else begin
                    state_next = STATE_START_N;
                end
            end else begin
                state_next = STATE_START_N;
            end
        end
        STATE_WAIT_STOP: begin
            // wait for stop event
            if (got_stop_reg) begin
                state_next = STATE_STOP;
                if (stop_queue_wr_ptr_reg == 0) begin
                    start_queue_ts_0_rd_ptr_next = 0;
                    start_queue_ts_0_wr_ptr_next = 0;
                    start_queue_ts_n_rd_ptr_next = 0;
                    start_queue_ts_n_wr_ptr_next = 0;
                    queue_ram_ptr_next = 0;
                    clear_inconsistent = 1'b1;
                    got_stop_next = 1'b0;
                    state_next = STATE_FILL_START;
                end else begin
                    state_next = STATE_STOP;
                end
            end else begin
                state_next = STATE_WAIT_STOP;
            end
        end
        STATE_STOP: begin
            // output stop queue
            if (!m_axis_sched_ctrl_valid_reg || m_axis_sched_ctrl_ready) begin
                m_axis_sched_ctrl_queue_next = stop_queue_ram[stop_queue_rd_ptr_reg];
                m_axis_sched_ctrl_enable_next = 1'b0;
                m_axis_sched_ctrl_valid_next = 1'b1;

                stop_queue_rd_ptr_next = stop_queue_rd_ptr_reg+1;
                if (stop_queue_rd_ptr_reg+1 == stop_queue_wr_ptr_reg) begin
                    start_queue_ts_0_rd_ptr_next = 0;
                    start_queue_ts_0_wr_ptr_next = 0;
                    start_queue_ts_n_rd_ptr_next = 0;
                    start_queue_ts_n_wr_ptr_next = 0;
                    queue_ram_ptr_next = 0;
                    clear_inconsistent = 1'b1;
                    got_stop_next = 1'b0;
                    state_next = STATE_FILL_START;
                end else begin
                    state_next = STATE_STOP;
                end
            end else begin
                state_next = STATE_STOP;
            end
        end
    endcase

    if (!got_start_reg && tdma_timeslot_start) begin
        got_start_next = 1'b1;
        start_index_next = tdma_timeslot_index;
    end

    if (!got_stop_reg && tdma_timeslot_end) begin
        got_stop_next = 1'b1;
    end
end

always @(posedge clk) begin
    state_reg <= state_next;

    got_start_reg <= got_start_next;
    start_index_reg <= start_index_next;
    cur_index_reg <= cur_index_next;
    got_stop_reg <= got_stop_next;

    start_queue_ts_0_wr_ptr_reg <= start_queue_ts_0_wr_ptr_next;
    start_queue_ts_0_rd_ptr_reg <= start_queue_ts_0_rd_ptr_next;
    start_queue_ts_n_wr_ptr_reg <= start_queue_ts_n_wr_ptr_next;
    start_queue_ts_n_rd_ptr_reg <= start_queue_ts_n_rd_ptr_next;
    stop_queue_wr_ptr_reg <= stop_queue_wr_ptr_next;
    stop_queue_rd_ptr_reg <= stop_queue_rd_ptr_next;

    queue_ram_ptr_reg <= queue_ram_ptr_next;

    m_axis_sched_ctrl_queue_reg <= m_axis_sched_ctrl_queue_next;
    m_axis_sched_ctrl_enable_reg <= m_axis_sched_ctrl_enable_next;
    m_axis_sched_ctrl_valid_reg <= m_axis_sched_ctrl_valid_next;

    if (start_queue_ts_0_wr_en) begin
        start_queue_ts_0_ram[start_queue_ts_0_wr_ptr_reg] <= start_queue_ts_0_wr_data;
    end
    if (start_queue_ts_n_wr_en) begin
        start_queue_ts_n_ram[start_queue_ts_n_wr_ptr_reg] <= start_queue_ts_n_wr_data;
    end
    if (stop_queue_wr_en) begin
        stop_queue_ram[stop_queue_wr_ptr_reg] <= stop_queue_wr_data;
    end

    inconsistent_reg <= (inconsistent_reg && !clear_inconsistent) || set_inconsistent;

    if (rst) begin
        state_reg <= STATE_IDLE;

        inconsistent_reg <= 1'b0;

        m_axis_sched_ctrl_valid_reg <= 1'b0;

        got_start_reg <= 1'b0;
        got_stop_reg <= 1'b0;
    end
end

// AXIL interface
always @* begin
    queue_ram_axil_wr_en = 1'b0;
    queue_ram_axil_rd_en = 1'b0;

    queue_ram_axil_ptr = 0;
    queue_ram_axil_wr_data = {SEGMENT_COUNT{s_axil_wdata}};
    if (SEGMENT_COUNT > 1) begin
        queue_ram_axil_wr_be = s_axil_wstrb << (((s_axil_awaddr >> SEGMENT_SHIFT) & {SEGMENT_AW{1'b1}}) * AXIL_STRB_WIDTH);
    end else begin
        queue_ram_axil_wr_be = s_axil_wstrb;
    end

    set_inconsistent = 1'b0;

    last_read_next = last_read_reg;

    s_axil_awready_next = 1'b0;
    s_axil_wready_next = 1'b0;
    s_axil_bvalid_next = s_axil_bvalid_reg && !s_axil_bready;

    s_axil_arready_next = 1'b0;

    write_eligible = s_axil_awvalid && s_axil_wvalid && (!s_axil_bvalid || s_axil_bready) && (!s_axil_awready && !s_axil_wready);
    read_eligible = s_axil_arvalid && (!s_axil_rvalid || s_axil_rready || ~queue_ram_read_data_valid_pipeline_reg) && (!s_axil_arready);

    if (write_eligible && (!read_eligible || last_read_reg)) begin
        last_read_next = 1'b0;

        s_axil_awready_next = 1'b1;
        s_axil_wready_next = 1'b1;
        s_axil_bvalid_next = 1'b1;

        set_inconsistent = 1'b1;

        queue_ram_axil_wr_en = 1'b1;

        queue_ram_axil_ptr = s_axil_awaddr >> ADDR_SHIFT;
        queue_ram_axil_wr_data = {SEGMENT_COUNT{s_axil_wdata}};
        if (SEGMENT_COUNT > 1) begin
            queue_ram_axil_wr_be = s_axil_wstrb << (((s_axil_awaddr >> SEGMENT_SHIFT) & {SEGMENT_AW{1'b1}}) * AXIL_STRB_WIDTH);
        end else begin
            queue_ram_axil_wr_be = s_axil_wstrb;
        end
    end else if (read_eligible) begin
        last_read_next = 1'b1;

        s_axil_arready_next = 1'b1;

        queue_ram_axil_rd_en = 1'b1;
        queue_ram_axil_ptr = s_axil_araddr >> ADDR_SHIFT;
    end
end

always @(posedge clk) begin
    last_read_reg <= last_read_next;

    s_axil_awready_reg <= s_axil_awready_next;
    s_axil_wready_reg <= s_axil_wready_next;
    s_axil_bvalid_reg <= s_axil_bvalid_next;

    s_axil_arready_reg <= s_axil_arready_next;

    if (!s_axil_rvalid_reg || s_axil_rready) begin
       s_axil_rdata_reg <= queue_ram_read_data_pipeline_reg[PIPELINE-1] >> (queue_ram_read_data_shift_pipeline_reg[PIPELINE-1] * AXIL_DATA_WIDTH);
       s_axil_rvalid_reg <= queue_ram_read_data_valid_pipeline_reg[PIPELINE-1];
    end

    // TODO loop
    if (!queue_ram_read_data_valid_pipeline_reg[PIPELINE-1] || s_axil_rready) begin
        queue_ram_read_data_pipeline_reg[PIPELINE-1] <= queue_ram_read_data_pipeline_reg[0];
        queue_ram_read_data_shift_pipeline_reg[PIPELINE-1] <= queue_ram_read_data_shift_pipeline_reg[0];
        queue_ram_read_data_valid_pipeline_reg[PIPELINE-1] <= queue_ram_read_data_valid_pipeline_reg[0];
        queue_ram_read_data_valid_pipeline_reg[0] <= 1'b0;
    end

    if (queue_ram_axil_rd_en) begin
        queue_ram_read_data_pipeline_reg[0] <= queue_ram[queue_ram_axil_ptr];
        if (SEGMENT_COUNT > 1) begin
            queue_ram_read_data_shift_pipeline_reg[0] <= (s_axil_araddr >> SEGMENT_SHIFT) & {SEGMENT_AW{1'b1}};
        end else begin
            queue_ram_read_data_shift_pipeline_reg[0] <= 0;
        end
        queue_ram_read_data_valid_pipeline_reg[0] <= 1'b1;
    end else begin
        for (i = 0; i < QUEUE_RAM_BE_WIDTH; i = i + 1) begin
            if (queue_ram_axil_wr_en && queue_ram_axil_wr_be[i]) begin
                queue_ram[queue_ram_axil_ptr][WORD_SIZE*i +: WORD_SIZE] <= queue_ram_axil_wr_data[WORD_SIZE*i +: WORD_SIZE];
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
    end
end

endmodule

`resetall
