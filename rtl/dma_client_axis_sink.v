/*

Copyright (c) 2019-2021 Alex Forencich

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
 * AXI stream sink DMA client
 */
module dma_client_axis_sink #
(
    // RAM segment count
    parameter SEG_COUNT = 2,
    // RAM segment data width
    parameter SEG_DATA_WIDTH = 64,
    // RAM segment address width
    parameter SEG_ADDR_WIDTH = 8,
    // RAM segment byte enable width
    parameter SEG_BE_WIDTH = SEG_DATA_WIDTH/8,
    // RAM address width
    parameter RAM_ADDR_WIDTH = SEG_ADDR_WIDTH+$clog2(SEG_COUNT)+$clog2(SEG_BE_WIDTH),
    // Width of AXI stream interfaces in bits
    parameter AXIS_DATA_WIDTH = SEG_DATA_WIDTH*SEG_COUNT/2,
    // Use AXI stream tkeep signal
    parameter AXIS_KEEP_ENABLE = (AXIS_DATA_WIDTH>8),
    // AXI stream tkeep signal width (words per cycle)
    parameter AXIS_KEEP_WIDTH = (AXIS_DATA_WIDTH/8),
    // Use AXI stream tlast signal
    parameter AXIS_LAST_ENABLE = 1,
    // Propagate AXI stream tid signal
    parameter AXIS_ID_ENABLE = 0,
    // AXI stream tid signal width
    parameter AXIS_ID_WIDTH = 8,
    // Propagate AXI stream tdest signal
    parameter AXIS_DEST_ENABLE = 0,
    // AXI stream tdest signal width
    parameter AXIS_DEST_WIDTH = 8,
    // Propagate AXI stream tuser signal
    parameter AXIS_USER_ENABLE = 1,
    // AXI stream tuser signal width
    parameter AXIS_USER_WIDTH = 1,
    // Width of length field
    parameter LEN_WIDTH = 16,
    // Width of tag field
    parameter TAG_WIDTH = 8
)
(
    input  wire                                 clk,
    input  wire                                 rst,

    /*
     * AXI write descriptor input
     */
    input  wire [RAM_ADDR_WIDTH-1:0]            s_axis_write_desc_ram_addr,
    input  wire [LEN_WIDTH-1:0]                 s_axis_write_desc_len,
    input  wire [TAG_WIDTH-1:0]                 s_axis_write_desc_tag,
    input  wire                                 s_axis_write_desc_valid,
    output wire                                 s_axis_write_desc_ready,

    /*
     * AXI write descriptor status output
     */
    output wire [LEN_WIDTH-1:0]                 m_axis_write_desc_status_len,
    output wire [TAG_WIDTH-1:0]                 m_axis_write_desc_status_tag,
    output wire [AXIS_ID_WIDTH-1:0]             m_axis_write_desc_status_id,
    output wire [AXIS_DEST_WIDTH-1:0]           m_axis_write_desc_status_dest,
    output wire [AXIS_USER_WIDTH-1:0]           m_axis_write_desc_status_user,
    output wire [3:0]                           m_axis_write_desc_status_error,
    output wire                                 m_axis_write_desc_status_valid,

    /*
     * AXI stream write data input
     */
    input  wire [AXIS_DATA_WIDTH-1:0]           s_axis_write_data_tdata,
    input  wire [AXIS_KEEP_WIDTH-1:0]           s_axis_write_data_tkeep,
    input  wire                                 s_axis_write_data_tvalid,
    output wire                                 s_axis_write_data_tready,
    input  wire                                 s_axis_write_data_tlast,
    input  wire [AXIS_ID_WIDTH-1:0]             s_axis_write_data_tid,
    input  wire [AXIS_DEST_WIDTH-1:0]           s_axis_write_data_tdest,
    input  wire [AXIS_USER_WIDTH-1:0]           s_axis_write_data_tuser,

    /*
     * RAM interface
     */
    output wire [SEG_COUNT*SEG_BE_WIDTH-1:0]    ram_wr_cmd_be,
    output wire [SEG_COUNT*SEG_ADDR_WIDTH-1:0]  ram_wr_cmd_addr,
    output wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]  ram_wr_cmd_data,
    output wire [SEG_COUNT-1:0]                 ram_wr_cmd_valid,
    input  wire [SEG_COUNT-1:0]                 ram_wr_cmd_ready,
    input  wire [SEG_COUNT-1:0]                 ram_wr_done,

    /*
     * Configuration
     */
    input  wire                                 enable,
    input  wire                                 abort
);

parameter RAM_WORD_WIDTH = SEG_BE_WIDTH;
parameter RAM_WORD_SIZE = SEG_DATA_WIDTH/RAM_WORD_WIDTH;

parameter AXIS_KEEP_WIDTH_INT = AXIS_KEEP_ENABLE ? AXIS_KEEP_WIDTH : 1;
parameter AXIS_WORD_WIDTH = AXIS_KEEP_WIDTH_INT;
parameter AXIS_WORD_SIZE = AXIS_DATA_WIDTH/AXIS_WORD_WIDTH;

parameter PART_COUNT = SEG_COUNT*SEG_BE_WIDTH / AXIS_KEEP_WIDTH_INT;
parameter PART_COUNT_WIDTH = PART_COUNT > 1 ? $clog2(PART_COUNT) : 1;
parameter PART_OFFSET_WIDTH = AXIS_KEEP_WIDTH_INT > 1 ? $clog2(AXIS_KEEP_WIDTH_INT) : 1;
parameter PARTS_PER_SEG = (SEG_BE_WIDTH + AXIS_KEEP_WIDTH_INT - 1) / AXIS_KEEP_WIDTH_INT;
parameter SEGS_PER_PART = (AXIS_KEEP_WIDTH_INT + SEG_BE_WIDTH - 1) / SEG_BE_WIDTH;

parameter OFFSET_WIDTH = AXIS_KEEP_WIDTH_INT > 1 ? $clog2(AXIS_KEEP_WIDTH_INT) : 1;
parameter OFFSET_MASK = AXIS_KEEP_WIDTH_INT > 1 ? {OFFSET_WIDTH{1'b1}} : 0;
parameter ADDR_MASK = {RAM_ADDR_WIDTH{1'b1}} << $clog2(AXIS_KEEP_WIDTH_INT);
parameter CYCLE_COUNT_WIDTH = LEN_WIDTH - $clog2(AXIS_KEEP_WIDTH_INT) + 1;

parameter STATUS_FIFO_ADDR_WIDTH = 5;
parameter OUTPUT_FIFO_ADDR_WIDTH = 5;

// bus width assertions
initial begin
    if (RAM_WORD_SIZE * SEG_BE_WIDTH != SEG_DATA_WIDTH) begin
        $error("Error: RAM data width not evenly divisble (instance %m)");
        $finish;
    end

    if (AXIS_WORD_SIZE * AXIS_KEEP_WIDTH_INT != AXIS_DATA_WIDTH) begin
        $error("Error: AXI stream data width not evenly divisble (instance %m)");
        $finish;
    end

    if (RAM_WORD_SIZE != AXIS_WORD_SIZE) begin
        $error("Error: word size mismatch (instance %m)");
        $finish;
    end

    if (2**$clog2(RAM_WORD_WIDTH) != RAM_WORD_WIDTH) begin
        $error("Error: RAM word width must be even power of two (instance %m)");
        $finish;
    end

    if (RAM_ADDR_WIDTH != SEG_ADDR_WIDTH+$clog2(SEG_COUNT)+$clog2(SEG_BE_WIDTH)) begin
        $error("Error: RAM_ADDR_WIDTH does not match RAM configuration (instance %m)");
        $finish;
    end

    if (AXIS_DATA_WIDTH > SEG_COUNT*SEG_DATA_WIDTH) begin
        $error("Error: AXI stream interface width must not be wider than RAM interface width (instance %m)");
        $finish;
    end

    if (AXIS_DATA_WIDTH*2**$clog2(PART_COUNT) != SEG_COUNT*SEG_DATA_WIDTH) begin
        $error("Error: AXI stream interface width must be a power of two fraction of RAM interface width (instance %m)");
        $finish;
    end
end

localparam [1:0]
    STATE_IDLE = 2'd0,
    STATE_WRITE = 2'd1,
    STATE_DROP_DATA = 2'd2;

reg [1:0] state_reg = STATE_IDLE, state_next;

integer i;
reg [OFFSET_WIDTH:0] cycle_size;

reg [RAM_ADDR_WIDTH-1:0] addr_reg = {RAM_ADDR_WIDTH{1'b0}}, addr_next;
reg [AXIS_KEEP_WIDTH_INT-1:0] keep_mask_reg = {AXIS_KEEP_WIDTH_INT{1'b0}}, keep_mask_next;
reg [OFFSET_WIDTH-1:0] last_cycle_offset_reg = {OFFSET_WIDTH{1'b0}}, last_cycle_offset_next;
reg [LEN_WIDTH-1:0] length_reg = {LEN_WIDTH{1'b0}}, length_next;
reg [CYCLE_COUNT_WIDTH-1:0] cycle_count_reg = {CYCLE_COUNT_WIDTH{1'b0}}, cycle_count_next;
reg last_cycle_reg = 1'b0, last_cycle_next;

reg [TAG_WIDTH-1:0] tag_reg = {TAG_WIDTH{1'b0}}, tag_next;

reg [STATUS_FIFO_ADDR_WIDTH+1-1:0] status_fifo_wr_ptr_reg = 0;
reg [STATUS_FIFO_ADDR_WIDTH+1-1:0] status_fifo_rd_ptr_reg = 0, status_fifo_rd_ptr_next;
reg [LEN_WIDTH-1:0] status_fifo_len[(2**STATUS_FIFO_ADDR_WIDTH)-1:0];
reg [TAG_WIDTH-1:0] status_fifo_tag[(2**STATUS_FIFO_ADDR_WIDTH)-1:0];
reg [AXIS_ID_WIDTH-1:0] status_fifo_id[(2**STATUS_FIFO_ADDR_WIDTH)-1:0];
reg [AXIS_DEST_WIDTH-1:0] status_fifo_dest[(2**STATUS_FIFO_ADDR_WIDTH)-1:0];
reg [AXIS_USER_WIDTH-1:0] status_fifo_user[(2**STATUS_FIFO_ADDR_WIDTH)-1:0];
reg [SEG_COUNT-1:0] status_fifo_mask[(2**STATUS_FIFO_ADDR_WIDTH)-1:0];
reg status_fifo_last[(2**STATUS_FIFO_ADDR_WIDTH)-1:0];
reg [LEN_WIDTH-1:0] status_fifo_wr_len;
reg [TAG_WIDTH-1:0] status_fifo_wr_tag;
reg [AXIS_ID_WIDTH-1:0] status_fifo_wr_id;
reg [AXIS_DEST_WIDTH-1:0] status_fifo_wr_dest;
reg [AXIS_USER_WIDTH-1:0] status_fifo_wr_user;
reg [SEG_COUNT-1:0] status_fifo_wr_mask;
reg status_fifo_wr_last;
reg status_fifo_we = 1'b0;
reg status_fifo_half_full_reg = 1'b0;

reg [STATUS_FIFO_ADDR_WIDTH+1-1:0] active_count_reg = 0;
reg active_count_av_reg = 1'b1;
reg inc_active;
reg dec_active;

reg s_axis_write_desc_ready_reg = 1'b0, s_axis_write_desc_ready_next;

reg [LEN_WIDTH-1:0] m_axis_write_desc_status_len_reg = {LEN_WIDTH{1'b0}}, m_axis_write_desc_status_len_next;
reg [TAG_WIDTH-1:0] m_axis_write_desc_status_tag_reg = {TAG_WIDTH{1'b0}}, m_axis_write_desc_status_tag_next;
reg [AXIS_ID_WIDTH-1:0] m_axis_write_desc_status_id_reg = {AXIS_ID_WIDTH{1'b0}}, m_axis_write_desc_status_id_next;
reg [AXIS_DEST_WIDTH-1:0] m_axis_write_desc_status_dest_reg = {AXIS_DEST_WIDTH{1'b0}}, m_axis_write_desc_status_dest_next;
reg [AXIS_USER_WIDTH-1:0] m_axis_write_desc_status_user_reg = {AXIS_USER_WIDTH{1'b0}}, m_axis_write_desc_status_user_next;
reg m_axis_write_desc_status_valid_reg = 1'b0, m_axis_write_desc_status_valid_next;

reg s_axis_write_data_tready_reg = 1'b0, s_axis_write_data_tready_next;

// internal datapath
reg  [SEG_COUNT*SEG_BE_WIDTH-1:0]   ram_wr_cmd_be_int;
reg  [SEG_COUNT*SEG_ADDR_WIDTH-1:0] ram_wr_cmd_addr_int;
reg  [SEG_COUNT*SEG_DATA_WIDTH-1:0] ram_wr_cmd_data_int;
reg  [SEG_COUNT-1:0]                ram_wr_cmd_valid_int;
wire [SEG_COUNT-1:0]                ram_wr_cmd_ready_int;

reg [SEG_COUNT-1:0] ram_wr_cmd_mask;

wire [SEG_COUNT-1:0] out_done;
reg [SEG_COUNT-1:0] out_done_ack;

assign s_axis_write_desc_ready = s_axis_write_desc_ready_reg;

assign m_axis_write_desc_status_len = m_axis_write_desc_status_len_reg;
assign m_axis_write_desc_status_tag = m_axis_write_desc_status_tag_reg;
assign m_axis_write_desc_status_id = m_axis_write_desc_status_id_reg;
assign m_axis_write_desc_status_dest = m_axis_write_desc_status_dest_reg;
assign m_axis_write_desc_status_user = m_axis_write_desc_status_user_reg;
assign m_axis_write_desc_status_error = 4'd0;
assign m_axis_write_desc_status_valid = m_axis_write_desc_status_valid_reg;

assign s_axis_write_data_tready = s_axis_write_data_tready_reg;

always @* begin
    state_next = STATE_IDLE;

    s_axis_write_desc_ready_next = 1'b0;

    m_axis_write_desc_status_len_next = m_axis_write_desc_status_len_reg;
    m_axis_write_desc_status_tag_next = m_axis_write_desc_status_tag_reg;
    m_axis_write_desc_status_id_next = m_axis_write_desc_status_id_reg;
    m_axis_write_desc_status_dest_next = m_axis_write_desc_status_dest_reg;
    m_axis_write_desc_status_user_next = m_axis_write_desc_status_user_reg;
    m_axis_write_desc_status_valid_next = 1'b0;

    s_axis_write_data_tready_next = 1'b0;

    if (PART_COUNT > 1) begin
        ram_wr_cmd_be_int = (s_axis_write_data_tkeep & keep_mask_reg) << (addr_reg & ({PART_COUNT_WIDTH{1'b1}} << PART_OFFSET_WIDTH));
    end else begin
        ram_wr_cmd_be_int = s_axis_write_data_tkeep & keep_mask_reg;
    end
    ram_wr_cmd_addr_int = {PART_COUNT{addr_reg[RAM_ADDR_WIDTH-1:RAM_ADDR_WIDTH-SEG_ADDR_WIDTH]}};
    ram_wr_cmd_data_int = {PART_COUNT{s_axis_write_data_tdata}};
    ram_wr_cmd_valid_int = {SEG_COUNT{1'b0}};
    for (i = 0; i < SEG_COUNT; i = i + 1) begin
        ram_wr_cmd_mask[i] = ram_wr_cmd_be_int[i*SEG_BE_WIDTH +: SEG_BE_WIDTH] != 0;
    end

    cycle_size = AXIS_KEEP_WIDTH_INT;

    addr_next = addr_reg;
    keep_mask_next = keep_mask_reg;
    last_cycle_offset_next = last_cycle_offset_reg;
    length_next = length_reg;
    cycle_count_next = cycle_count_reg;
    last_cycle_next = last_cycle_reg;

    tag_next = tag_reg;

    status_fifo_rd_ptr_next = status_fifo_rd_ptr_reg;

    status_fifo_wr_len = 0;
    status_fifo_wr_tag = tag_reg;
    status_fifo_wr_id = s_axis_write_data_tid;
    status_fifo_wr_dest = s_axis_write_data_tdest;
    status_fifo_wr_user = s_axis_write_data_tuser;
    status_fifo_wr_mask = ram_wr_cmd_mask;
    status_fifo_wr_last = 1'b0;
    status_fifo_we = 1'b0;

    inc_active = 1'b0;
    dec_active = 1'b0;

    out_done_ack = {SEG_COUNT{1'b0}};

    case (state_reg)
        STATE_IDLE: begin
            // idle state - load new descriptor to start operation
            s_axis_write_desc_ready_next = enable && active_count_av_reg;

            addr_next = s_axis_write_desc_ram_addr & ADDR_MASK;
            last_cycle_offset_next = s_axis_write_desc_len & OFFSET_MASK;

            tag_next = s_axis_write_desc_tag;

            length_next = 0;

            cycle_count_next = (s_axis_write_desc_len - 1) >> $clog2(AXIS_KEEP_WIDTH_INT);
            last_cycle_next = cycle_count_next == 0;
            if (cycle_count_next == 0 && last_cycle_offset_next != 0) begin
                keep_mask_next = {AXIS_KEEP_WIDTH_INT{1'b1}} >> (AXIS_KEEP_WIDTH_INT - last_cycle_offset_next);
            end else begin
                keep_mask_next = {AXIS_KEEP_WIDTH_INT{1'b1}};
            end

            if (s_axis_write_desc_ready && s_axis_write_desc_valid) begin
                s_axis_write_desc_ready_next = 1'b0;
                s_axis_write_data_tready_next = &ram_wr_cmd_ready_int && !status_fifo_half_full_reg;

                inc_active = 1'b1;

                state_next = STATE_WRITE;
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_WRITE: begin
            // write state - generate write operations
            s_axis_write_data_tready_next = &ram_wr_cmd_ready_int && !status_fifo_half_full_reg;

            if (s_axis_write_data_tready && s_axis_write_data_tvalid) begin

                // update counters
                addr_next = addr_reg + AXIS_KEEP_WIDTH_INT;
                length_next = length_reg + AXIS_KEEP_WIDTH_INT;
                cycle_count_next = cycle_count_reg - 1;
                last_cycle_next = cycle_count_next == 0;
                if (cycle_count_next == 0 && last_cycle_offset_reg != 0) begin
                    keep_mask_next = {AXIS_KEEP_WIDTH_INT{1'b1}} >> (AXIS_KEEP_WIDTH_INT - last_cycle_offset_reg);
                end else begin
                    keep_mask_next = {AXIS_KEEP_WIDTH_INT{1'b1}};
                end

                if (PART_COUNT > 1) begin
                    ram_wr_cmd_be_int = (s_axis_write_data_tkeep & keep_mask_reg) << (addr_reg & ({PART_COUNT_WIDTH{1'b1}} << PART_OFFSET_WIDTH));
                end else begin
                    ram_wr_cmd_be_int = s_axis_write_data_tkeep & keep_mask_reg;
                end
                ram_wr_cmd_addr_int = {SEG_COUNT{addr_reg[RAM_ADDR_WIDTH-1:RAM_ADDR_WIDTH-SEG_ADDR_WIDTH]}};
                ram_wr_cmd_data_int = {PART_COUNT{s_axis_write_data_tdata}};
                ram_wr_cmd_valid_int = ram_wr_cmd_mask;

                // enqueue status FIFO entry for write completion
                status_fifo_wr_len = length_next;
                status_fifo_wr_tag = tag_reg;
                status_fifo_wr_id = s_axis_write_data_tid;
                status_fifo_wr_dest = s_axis_write_data_tdest;
                status_fifo_wr_user = s_axis_write_data_tuser;
                status_fifo_wr_mask = ram_wr_cmd_mask;
                status_fifo_wr_last = 1'b0;
                status_fifo_we = 1'b1;

                if (AXIS_LAST_ENABLE && s_axis_write_data_tlast) begin
                    if (AXIS_KEEP_ENABLE) begin
                        cycle_size = AXIS_KEEP_WIDTH_INT;
                        for (i = AXIS_KEEP_WIDTH_INT-1; i >= 0; i = i - 1) begin
                            if (~(s_axis_write_data_tkeep & keep_mask_reg) & (1 << i)) begin
                                cycle_size = i;
                            end
                        end
                    end else begin
                        cycle_size = AXIS_KEEP_WIDTH_INT;
                    end

                    // no more data to transfer, finish operation
                    if (last_cycle_reg && last_cycle_offset_reg > 0) begin
                        if (AXIS_KEEP_ENABLE && !(s_axis_write_data_tkeep & keep_mask_reg & ~({AXIS_KEEP_WIDTH_INT{1'b1}} >> (AXIS_KEEP_WIDTH_INT - last_cycle_offset_reg)))) begin
                            length_next = length_reg + cycle_size;
                        end else begin
                            length_next = length_reg + last_cycle_offset_reg;
                        end
                    end else begin
                        if (AXIS_KEEP_ENABLE) begin
                            length_next = length_reg + cycle_size;
                        end
                    end

                    // enqueue status FIFO entry for write completion
                    status_fifo_wr_len = length_next;
                    status_fifo_wr_tag = tag_reg;
                    status_fifo_wr_id = s_axis_write_data_tid;
                    status_fifo_wr_dest = s_axis_write_data_tdest;
                    status_fifo_wr_user = s_axis_write_data_tuser;
                    status_fifo_wr_mask = ram_wr_cmd_mask;
                    status_fifo_wr_last = 1'b1;
                    status_fifo_we = 1'b1;

                    s_axis_write_data_tready_next = 1'b0;
                    s_axis_write_desc_ready_next = enable && active_count_av_reg;
                    state_next = STATE_IDLE;
                end else if (last_cycle_reg) begin
                    if (last_cycle_offset_reg > 0) begin
                        length_next = length_reg + last_cycle_offset_reg;
                    end

                    // enqueue status FIFO entry for write completion
                    status_fifo_wr_len = length_next;
                    status_fifo_wr_tag = tag_reg;
                    status_fifo_wr_id = s_axis_write_data_tid;
                    status_fifo_wr_dest = s_axis_write_data_tdest;
                    status_fifo_wr_user = s_axis_write_data_tuser;
                    status_fifo_wr_mask = ram_wr_cmd_mask;
                    status_fifo_wr_last = 1'b1;
                    status_fifo_we = 1'b1;

                    if (AXIS_LAST_ENABLE) begin
                        s_axis_write_data_tready_next = 1'b1;
                        state_next = STATE_DROP_DATA;
                    end else begin
                        s_axis_write_data_tready_next = 1'b0;
                        s_axis_write_desc_ready_next = enable && active_count_av_reg;
                        state_next = STATE_IDLE;
                    end
                end else begin
                    state_next = STATE_WRITE;
                end
            end else begin
                state_next = STATE_WRITE;
            end
        end
        STATE_DROP_DATA: begin
            // drop excess AXI stream data
            s_axis_write_data_tready_next = 1'b1;

            if (s_axis_write_data_tready && s_axis_write_data_tvalid) begin
                if (s_axis_write_data_tlast) begin
                    s_axis_write_data_tready_next = 1'b0;
                    s_axis_write_desc_ready_next = enable && active_count_av_reg;
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_DROP_DATA;
                end
            end else begin
                state_next = STATE_DROP_DATA;
            end
        end
    endcase

    m_axis_write_desc_status_len_next = status_fifo_len[status_fifo_rd_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]];
    m_axis_write_desc_status_tag_next = status_fifo_tag[status_fifo_rd_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]];
    m_axis_write_desc_status_id_next = status_fifo_id[status_fifo_rd_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]];
    m_axis_write_desc_status_dest_next = status_fifo_dest[status_fifo_rd_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]];
    m_axis_write_desc_status_user_next = status_fifo_user[status_fifo_rd_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]];
    m_axis_write_desc_status_valid_next = 1'b0;

    if (status_fifo_rd_ptr_reg != status_fifo_wr_ptr_reg) begin
        // status FIFO not empty
        if ((status_fifo_mask[status_fifo_rd_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]] & ~out_done) == 0) begin
            // got write completion, pop and return status
            status_fifo_rd_ptr_next = status_fifo_rd_ptr_reg + 1;

            out_done_ack = status_fifo_mask[status_fifo_rd_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]];

            if (status_fifo_last[status_fifo_rd_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]]) begin
                m_axis_write_desc_status_valid_next = 1'b1;
                
                dec_active = 1'b1;
            end
        end
    end
end

always @(posedge clk) begin
    state_reg <= state_next;

    s_axis_write_desc_ready_reg <= s_axis_write_desc_ready_next;

    m_axis_write_desc_status_len_reg <= m_axis_write_desc_status_len_next;
    m_axis_write_desc_status_tag_reg <= m_axis_write_desc_status_tag_next;
    m_axis_write_desc_status_id_reg <= m_axis_write_desc_status_id_next;
    m_axis_write_desc_status_dest_reg <= m_axis_write_desc_status_dest_next;
    m_axis_write_desc_status_user_reg <= m_axis_write_desc_status_user_next;
    m_axis_write_desc_status_valid_reg <= m_axis_write_desc_status_valid_next;

    s_axis_write_data_tready_reg <= s_axis_write_data_tready_next;

    addr_reg <= addr_next;
    keep_mask_reg <= keep_mask_next;
    last_cycle_offset_reg <= last_cycle_offset_next;
    length_reg <= length_next;
    cycle_count_reg <= cycle_count_next;
    last_cycle_reg <= last_cycle_next;

    tag_reg <= tag_next;

    if (status_fifo_we) begin
        status_fifo_len[status_fifo_wr_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]] <= status_fifo_wr_len;
        status_fifo_tag[status_fifo_wr_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]] <= status_fifo_wr_tag;
        status_fifo_id[status_fifo_wr_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]] <= status_fifo_wr_id;
        status_fifo_dest[status_fifo_wr_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]] <= status_fifo_wr_dest;
        status_fifo_user[status_fifo_wr_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]] <= status_fifo_wr_user;
        status_fifo_mask[status_fifo_wr_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]] <= status_fifo_wr_mask;
        status_fifo_last[status_fifo_wr_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]] <= status_fifo_wr_last;
        status_fifo_wr_ptr_reg <= status_fifo_wr_ptr_reg + 1;
    end
    status_fifo_rd_ptr_reg <= status_fifo_rd_ptr_next;

    status_fifo_half_full_reg <= $unsigned(status_fifo_wr_ptr_reg - status_fifo_rd_ptr_reg) >= 2**(STATUS_FIFO_ADDR_WIDTH-1);

    if (active_count_reg < 2**STATUS_FIFO_ADDR_WIDTH && inc_active && !dec_active) begin
        active_count_reg <= active_count_reg + 1;
        active_count_av_reg <= active_count_reg < (2**STATUS_FIFO_ADDR_WIDTH-1);
    end else if (active_count_reg > 0 && !inc_active && dec_active) begin
        active_count_reg <= active_count_reg - 1;
        active_count_av_reg <= 1'b1;
    end else begin
        active_count_av_reg <= active_count_reg < 2**STATUS_FIFO_ADDR_WIDTH;
    end

    if (rst) begin
        state_reg <= STATE_IDLE;

        s_axis_write_desc_ready_reg <= 1'b0;
        m_axis_write_desc_status_valid_reg <= 1'b0;

        s_axis_write_data_tready_reg <= 1'b0;

        status_fifo_wr_ptr_reg <= 0;
        status_fifo_rd_ptr_reg <= 0;

        active_count_reg <= 0;
        active_count_av_reg <= 1'b1;
    end
end

// output datapath logic (write data)
generate

genvar n;

for (n = 0; n < SEG_COUNT; n = n + 1) begin

    reg [SEG_BE_WIDTH-1:0]   ram_wr_cmd_be_reg = {SEG_BE_WIDTH{1'b0}};
    reg [SEG_ADDR_WIDTH-1:0] ram_wr_cmd_addr_reg = {SEG_ADDR_WIDTH{1'b0}};
    reg [SEG_DATA_WIDTH-1:0] ram_wr_cmd_data_reg = {SEG_DATA_WIDTH{1'b0}};
    reg                      ram_wr_cmd_valid_reg = 1'b0;

    reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_wr_ptr_reg = 0;
    reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_rd_ptr_reg = 0;
    reg out_fifo_half_full_reg = 1'b0;

    wire out_fifo_full = out_fifo_wr_ptr_reg == (out_fifo_rd_ptr_reg ^ {1'b1, {OUTPUT_FIFO_ADDR_WIDTH{1'b0}}});
    wire out_fifo_empty = out_fifo_wr_ptr_reg == out_fifo_rd_ptr_reg;

    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [SEG_BE_WIDTH-1:0]   out_fifo_wr_cmd_be[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [SEG_ADDR_WIDTH-1:0] out_fifo_wr_cmd_addr[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [SEG_DATA_WIDTH-1:0] out_fifo_wr_cmd_data[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];

    reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] done_count_reg = 0;
    reg done_reg = 1'b0;

    assign ram_wr_cmd_ready_int[n +: 1] = !out_fifo_half_full_reg;

    assign ram_wr_cmd_be[n*SEG_BE_WIDTH +: SEG_BE_WIDTH] = ram_wr_cmd_be_reg;
    assign ram_wr_cmd_addr[n*SEG_ADDR_WIDTH +: SEG_ADDR_WIDTH] = ram_wr_cmd_addr_reg;
    assign ram_wr_cmd_data[n*SEG_DATA_WIDTH +: SEG_DATA_WIDTH] = ram_wr_cmd_data_reg;
    assign ram_wr_cmd_valid[n +: 1] = ram_wr_cmd_valid_reg;

    assign out_done[n] = done_reg;

    always @(posedge clk) begin
        ram_wr_cmd_valid_reg <= ram_wr_cmd_valid_reg && !ram_wr_cmd_ready[n +: 1];

        out_fifo_half_full_reg <= $unsigned(out_fifo_wr_ptr_reg - out_fifo_rd_ptr_reg) >= 2**(OUTPUT_FIFO_ADDR_WIDTH-1);

        if (!out_fifo_full && ram_wr_cmd_valid_int[n +: 1]) begin
            out_fifo_wr_cmd_be[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= ram_wr_cmd_be_int[n*SEG_BE_WIDTH +: SEG_BE_WIDTH];
            out_fifo_wr_cmd_addr[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= ram_wr_cmd_addr_int[n*SEG_ADDR_WIDTH +: SEG_ADDR_WIDTH];
            out_fifo_wr_cmd_data[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= ram_wr_cmd_data_int[n*SEG_DATA_WIDTH +: SEG_DATA_WIDTH];
            out_fifo_wr_ptr_reg <= out_fifo_wr_ptr_reg + 1;
        end

        if (!out_fifo_empty && (!ram_wr_cmd_valid_reg || ram_wr_cmd_ready[n +: 1])) begin
            ram_wr_cmd_be_reg <= out_fifo_wr_cmd_be[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            ram_wr_cmd_addr_reg <= out_fifo_wr_cmd_addr[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            ram_wr_cmd_data_reg <= out_fifo_wr_cmd_data[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            ram_wr_cmd_valid_reg <= 1'b1;
            out_fifo_rd_ptr_reg <= out_fifo_rd_ptr_reg + 1;
        end

        if (done_count_reg < 2**OUTPUT_FIFO_ADDR_WIDTH && ram_wr_done[n] && !out_done_ack[n]) begin
            done_count_reg <= done_count_reg + 1;
            done_reg <= 1;
        end else if (done_count_reg > 0 && !ram_wr_done[n] && out_done_ack[n]) begin
            done_count_reg <= done_count_reg - 1;
            done_reg <= done_count_reg > 1;
        end

        if (rst) begin
            out_fifo_wr_ptr_reg <= 0;
            out_fifo_rd_ptr_reg <= 0;
            ram_wr_cmd_valid_reg <= 1'b0;
            done_count_reg <= 0;
            done_reg <= 1'b0;
        end
    end

end

endgenerate

endmodule

`resetall
