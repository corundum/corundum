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
 * AXI stream source DMA client
 */
module dma_client_axis_source #
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
     * AXI read descriptor input
     */
    input  wire [RAM_ADDR_WIDTH-1:0]            s_axis_read_desc_ram_addr,
    input  wire [LEN_WIDTH-1:0]                 s_axis_read_desc_len,
    input  wire [TAG_WIDTH-1:0]                 s_axis_read_desc_tag,
    input  wire [AXIS_ID_WIDTH-1:0]             s_axis_read_desc_id,
    input  wire [AXIS_DEST_WIDTH-1:0]           s_axis_read_desc_dest,
    input  wire [AXIS_USER_WIDTH-1:0]           s_axis_read_desc_user,
    input  wire                                 s_axis_read_desc_valid,
    output wire                                 s_axis_read_desc_ready,

    /*
     * AXI read descriptor status output
     */
    output wire [TAG_WIDTH-1:0]                 m_axis_read_desc_status_tag,
    output wire [3:0]                           m_axis_read_desc_status_error,
    output wire                                 m_axis_read_desc_status_valid,

    /*
     * AXI stream read data output
     */
    output wire [AXIS_DATA_WIDTH-1:0]           m_axis_read_data_tdata,
    output wire [AXIS_KEEP_WIDTH-1:0]           m_axis_read_data_tkeep,
    output wire                                 m_axis_read_data_tvalid,
    input  wire                                 m_axis_read_data_tready,
    output wire                                 m_axis_read_data_tlast,
    output wire [AXIS_ID_WIDTH-1:0]             m_axis_read_data_tid,
    output wire [AXIS_DEST_WIDTH-1:0]           m_axis_read_data_tdest,
    output wire [AXIS_USER_WIDTH-1:0]           m_axis_read_data_tuser,

    /*
     * RAM interface
     */
    output wire [SEG_COUNT*SEG_ADDR_WIDTH-1:0]  ram_rd_cmd_addr,
    output wire [SEG_COUNT-1:0]                 ram_rd_cmd_valid,
    input  wire [SEG_COUNT-1:0]                 ram_rd_cmd_ready,
    input  wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]  ram_rd_resp_data,
    input  wire [SEG_COUNT-1:0]                 ram_rd_resp_valid,
    output wire [SEG_COUNT-1:0]                 ram_rd_resp_ready,

    /*
     * Configuration
     */
    input  wire                                 enable
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

localparam [0:0]
    READ_STATE_IDLE = 1'd0,
    READ_STATE_READ = 1'd1;

reg [0:0] read_state_reg = READ_STATE_IDLE, read_state_next;

localparam [0:0]
    AXIS_STATE_IDLE = 1'd0,
    AXIS_STATE_READ = 1'd1;

reg [0:0] axis_state_reg = AXIS_STATE_IDLE, axis_state_next;

// datapath control signals
reg axis_cmd_ready;

integer i;

reg [RAM_ADDR_WIDTH-1:0] read_addr_reg = {RAM_ADDR_WIDTH{1'b0}}, read_addr_next;
reg [SEG_COUNT-1:0] read_ram_mask_reg = 0, read_ram_mask_next;
reg [CYCLE_COUNT_WIDTH-1:0] read_cycle_count_reg = {CYCLE_COUNT_WIDTH{1'b0}}, read_cycle_count_next;

reg [RAM_ADDR_WIDTH-1:0] axis_cmd_addr_reg = {RAM_ADDR_WIDTH{1'b0}}, axis_cmd_addr_next;
reg [OFFSET_WIDTH-1:0] axis_cmd_last_cycle_offset_reg = {OFFSET_WIDTH{1'b0}}, axis_cmd_last_cycle_offset_next;
reg [CYCLE_COUNT_WIDTH-1:0] axis_cmd_cycle_count_reg = {CYCLE_COUNT_WIDTH{1'b0}}, axis_cmd_cycle_count_next;
reg [TAG_WIDTH-1:0] axis_cmd_tag_reg = {TAG_WIDTH{1'b0}}, axis_cmd_tag_next;
reg [AXIS_ID_WIDTH-1:0] axis_cmd_axis_id_reg = {AXIS_ID_WIDTH{1'b0}}, axis_cmd_axis_id_next;
reg [AXIS_DEST_WIDTH-1:0] axis_cmd_axis_dest_reg = {AXIS_DEST_WIDTH{1'b0}}, axis_cmd_axis_dest_next;
reg [AXIS_USER_WIDTH-1:0] axis_cmd_axis_user_reg = {AXIS_USER_WIDTH{1'b0}}, axis_cmd_axis_user_next;
reg axis_cmd_valid_reg = 1'b0, axis_cmd_valid_next;

reg [RAM_ADDR_WIDTH-1:0] addr_reg = {RAM_ADDR_WIDTH{1'b0}}, addr_next;
reg [SEG_COUNT-1:0] ram_mask_reg = 0, ram_mask_next;
reg [OFFSET_WIDTH-1:0] last_cycle_offset_reg = {OFFSET_WIDTH{1'b0}}, last_cycle_offset_next;
reg [CYCLE_COUNT_WIDTH-1:0] cycle_count_reg = {CYCLE_COUNT_WIDTH{1'b0}}, cycle_count_next;
reg last_cycle_reg = 1'b0, last_cycle_next;

reg [AXIS_ID_WIDTH-1:0] axis_id_reg = {AXIS_ID_WIDTH{1'b0}}, axis_id_next;
reg [AXIS_DEST_WIDTH-1:0] axis_dest_reg = {AXIS_DEST_WIDTH{1'b0}}, axis_dest_next;
reg [AXIS_USER_WIDTH-1:0] axis_user_reg = {AXIS_USER_WIDTH{1'b0}}, axis_user_next;

reg s_axis_read_desc_ready_reg = 1'b0, s_axis_read_desc_ready_next;

reg [TAG_WIDTH-1:0] m_axis_read_desc_status_tag_reg = {TAG_WIDTH{1'b0}}, m_axis_read_desc_status_tag_next;
reg m_axis_read_desc_status_valid_reg = 1'b0, m_axis_read_desc_status_valid_next;

reg [SEG_COUNT*SEG_ADDR_WIDTH-1:0] ram_rd_cmd_addr_reg = 0, ram_rd_cmd_addr_next;
reg [SEG_COUNT-1:0] ram_rd_cmd_valid_reg = 0, ram_rd_cmd_valid_next;
reg [SEG_COUNT-1:0] ram_rd_resp_ready_cmb;

// internal datapath
reg  [AXIS_DATA_WIDTH-1:0] m_axis_read_data_tdata_int;
reg  [AXIS_KEEP_WIDTH-1:0] m_axis_read_data_tkeep_int;
reg                        m_axis_read_data_tvalid_int;
wire                       m_axis_read_data_tready_int;
reg                        m_axis_read_data_tlast_int;
reg  [AXIS_ID_WIDTH-1:0]   m_axis_read_data_tid_int;
reg  [AXIS_DEST_WIDTH-1:0] m_axis_read_data_tdest_int;
reg  [AXIS_USER_WIDTH-1:0] m_axis_read_data_tuser_int;

assign s_axis_read_desc_ready = s_axis_read_desc_ready_reg;

assign m_axis_read_desc_status_tag = m_axis_read_desc_status_tag_reg;
assign m_axis_read_desc_status_error = 4'd0;
assign m_axis_read_desc_status_valid = m_axis_read_desc_status_valid_reg;

assign ram_rd_cmd_addr = ram_rd_cmd_addr_reg;
assign ram_rd_cmd_valid = ram_rd_cmd_valid_reg;
assign ram_rd_resp_ready = ram_rd_resp_ready_cmb;

always @* begin
    read_state_next = READ_STATE_IDLE;

    s_axis_read_desc_ready_next = 1'b0;

    ram_rd_cmd_addr_next = ram_rd_cmd_addr_reg;
    ram_rd_cmd_valid_next = ram_rd_cmd_valid_reg & ~ram_rd_cmd_ready;

    read_addr_next = read_addr_reg;
    read_ram_mask_next = read_ram_mask_reg;
    read_cycle_count_next = read_cycle_count_reg;

    axis_cmd_addr_next = axis_cmd_addr_reg;
    axis_cmd_last_cycle_offset_next = axis_cmd_last_cycle_offset_reg;
    axis_cmd_cycle_count_next = axis_cmd_cycle_count_reg;
    axis_cmd_tag_next = axis_cmd_tag_reg;
    axis_cmd_axis_id_next = axis_cmd_axis_id_reg;
    axis_cmd_axis_dest_next = axis_cmd_axis_dest_reg;
    axis_cmd_axis_user_next = axis_cmd_axis_user_reg;
    axis_cmd_valid_next = axis_cmd_valid_reg && !axis_cmd_ready;

    case (read_state_reg)
        READ_STATE_IDLE: begin
            // idle state - load new descriptor to start operation
            s_axis_read_desc_ready_next = !axis_cmd_valid_reg && enable;

            if (s_axis_read_desc_ready && s_axis_read_desc_valid) begin

                read_addr_next = s_axis_read_desc_ram_addr & ADDR_MASK;

                if (PART_COUNT > 1) begin
                    read_ram_mask_next = {SEGS_PER_PART{1'b1}} << ((((read_addr_next >> PART_OFFSET_WIDTH) & ({PART_COUNT_WIDTH{1'b1}})) / PARTS_PER_SEG) * SEGS_PER_PART);
                end else begin
                    read_ram_mask_next = {SEG_COUNT{1'b1}};
                end

                axis_cmd_addr_next = s_axis_read_desc_ram_addr & ADDR_MASK;
                axis_cmd_last_cycle_offset_next = s_axis_read_desc_len & OFFSET_MASK;

                axis_cmd_tag_next = s_axis_read_desc_tag;

                axis_cmd_axis_id_next = s_axis_read_desc_id;
                axis_cmd_axis_dest_next = s_axis_read_desc_dest;
                axis_cmd_axis_user_next = s_axis_read_desc_user;

                axis_cmd_cycle_count_next = (s_axis_read_desc_len - 1) >> $clog2(AXIS_KEEP_WIDTH_INT);
                read_cycle_count_next = (s_axis_read_desc_len - 1) >> $clog2(AXIS_KEEP_WIDTH_INT);

                axis_cmd_valid_next = 1'b1;

                s_axis_read_desc_ready_next = 1'b0;
                read_state_next = READ_STATE_READ;
            end else begin
                read_state_next = READ_STATE_IDLE;
            end
        end
        READ_STATE_READ: begin
            // read state - start new read operations

            if (!(ram_rd_cmd_valid & ~ram_rd_cmd_ready & read_ram_mask_reg)) begin

                // update counters
                read_addr_next = read_addr_reg + AXIS_KEEP_WIDTH_INT;
                read_cycle_count_next = read_cycle_count_reg - 1;

                if (PART_COUNT > 1) begin
                    read_ram_mask_next = {SEGS_PER_PART{1'b1}} << ((((read_addr_next >> PART_OFFSET_WIDTH) & ({PART_COUNT_WIDTH{1'b1}})) / PARTS_PER_SEG) * SEGS_PER_PART);
                end else begin
                    read_ram_mask_next = {SEG_COUNT{1'b1}};
                end

                for (i = 0; i < SEG_COUNT; i = i + 1) begin
                    if (read_ram_mask_reg[i]) begin
                        ram_rd_cmd_addr_next[i*SEG_ADDR_WIDTH +: SEG_ADDR_WIDTH] = read_addr_reg[RAM_ADDR_WIDTH-1:RAM_ADDR_WIDTH-SEG_ADDR_WIDTH];
                        ram_rd_cmd_valid_next[i] = 1'b1;
                    end
                end

                if (read_cycle_count_reg == 0) begin
                    s_axis_read_desc_ready_next = !axis_cmd_valid_reg && enable;
                    read_state_next = READ_STATE_IDLE;
                end else begin
                    read_state_next = READ_STATE_READ;
                end
            end else begin
                read_state_next = READ_STATE_READ;
            end
        end
    endcase
end

always @* begin
    axis_state_next = AXIS_STATE_IDLE;

    m_axis_read_desc_status_tag_next = m_axis_read_desc_status_tag_reg;
    m_axis_read_desc_status_valid_next = 1'b0;

    if (PART_COUNT > 1) begin
        m_axis_read_data_tdata_int = ram_rd_resp_data >> (((addr_reg >> PART_OFFSET_WIDTH) & {PART_COUNT_WIDTH{1'b1}}) * AXIS_DATA_WIDTH);
    end else begin
        m_axis_read_data_tdata_int = ram_rd_resp_data;
    end
    m_axis_read_data_tkeep_int = {AXIS_KEEP_WIDTH{1'b1}};
    m_axis_read_data_tlast_int = 1'b0;
    m_axis_read_data_tvalid_int = 1'b0;
    m_axis_read_data_tid_int = axis_id_reg;
    m_axis_read_data_tdest_int = axis_dest_reg;
    m_axis_read_data_tuser_int = axis_user_reg;

    ram_rd_resp_ready_cmb = {SEG_COUNT{1'b0}};

    axis_cmd_ready = 1'b0;

    addr_next = addr_reg;
    ram_mask_next = ram_mask_reg;
    last_cycle_offset_next = last_cycle_offset_reg;
    cycle_count_next = cycle_count_reg;
    last_cycle_next = last_cycle_reg;

    axis_id_next = axis_id_reg;
    axis_dest_next = axis_dest_reg;
    axis_user_next = axis_user_reg;

    case (axis_state_reg)
        AXIS_STATE_IDLE: begin
            // idle state - load new descriptor to start operation

            // store transfer parameters
            addr_next = axis_cmd_addr_reg;
            last_cycle_offset_next = axis_cmd_last_cycle_offset_reg;
            cycle_count_next = axis_cmd_cycle_count_reg;
            last_cycle_next = axis_cmd_cycle_count_reg == 0;

            if (PART_COUNT > 1) begin
                ram_mask_next = {SEGS_PER_PART{1'b1}} << ((((addr_next >> PART_OFFSET_WIDTH) & ({PART_COUNT_WIDTH{1'b1}})) / PARTS_PER_SEG) * SEGS_PER_PART);
            end else begin
                ram_mask_next = {SEG_COUNT{1'b1}};
            end
            
            m_axis_read_desc_status_tag_next = axis_cmd_tag_reg;
            axis_id_next = axis_cmd_axis_id_reg;
            axis_dest_next = axis_cmd_axis_dest_reg;
            axis_user_next = axis_cmd_axis_user_reg;

            if (axis_cmd_valid_reg) begin
                axis_cmd_ready = 1'b1;
                axis_state_next = AXIS_STATE_READ;
            end
        end
        AXIS_STATE_READ: begin
            // handle read data
            ram_rd_resp_ready_cmb = {SEG_COUNT{1'b0}};

            if (!(ram_mask_reg & ~ram_rd_resp_valid) && m_axis_read_data_tready_int) begin
                // transfer in read data
                ram_rd_resp_ready_cmb = ram_mask_reg;

                // update counters
                addr_next = addr_reg + AXIS_KEEP_WIDTH_INT;
                cycle_count_next = cycle_count_reg - 1;
                last_cycle_next = cycle_count_next == 0;

                if (PART_COUNT > 1) begin
                    ram_mask_next = {SEGS_PER_PART{1'b1}} << ((((addr_next >> PART_OFFSET_WIDTH) & ({PART_COUNT_WIDTH{1'b1}})) / PARTS_PER_SEG) * SEGS_PER_PART);
                end else begin
                    ram_mask_next = {SEG_COUNT{1'b1}};
                end

                if (PART_COUNT > 1) begin
                    m_axis_read_data_tdata_int = ram_rd_resp_data >> (((addr_reg >> PART_OFFSET_WIDTH) & {PART_COUNT_WIDTH{1'b1}}) * AXIS_DATA_WIDTH);
                end else begin
                    m_axis_read_data_tdata_int = ram_rd_resp_data;
                end
                m_axis_read_data_tkeep_int = {AXIS_KEEP_WIDTH_INT{1'b1}};
                m_axis_read_data_tvalid_int = 1'b1;

                if (last_cycle_reg) begin
                    // no more data to transfer, finish operation
                    if (last_cycle_offset_reg > 0) begin
                        m_axis_read_data_tkeep_int = {AXIS_KEEP_WIDTH_INT{1'b1}} >> (AXIS_KEEP_WIDTH_INT - last_cycle_offset_reg);
                    end
                    m_axis_read_data_tlast_int = 1'b1;

                    m_axis_read_desc_status_valid_next = 1'b1;

                    axis_state_next = AXIS_STATE_IDLE;
                end else begin
                    // more cycles in AXI transfer
                    axis_state_next = AXIS_STATE_READ;
                end
            end else begin
                axis_state_next = AXIS_STATE_READ;
            end
        end
    endcase
end

always @(posedge clk) begin
    read_state_reg <= read_state_next;
    axis_state_reg <= axis_state_next;

    s_axis_read_desc_ready_reg <= s_axis_read_desc_ready_next;

    m_axis_read_desc_status_tag_reg <= m_axis_read_desc_status_tag_next;
    m_axis_read_desc_status_valid_reg <= m_axis_read_desc_status_valid_next;

    ram_rd_cmd_addr_reg <= ram_rd_cmd_addr_next;
    ram_rd_cmd_valid_reg <= ram_rd_cmd_valid_next;

    read_addr_reg <= read_addr_next;
    read_ram_mask_reg <= read_ram_mask_next;
    read_cycle_count_reg <= read_cycle_count_next;

    axis_cmd_addr_reg <= axis_cmd_addr_next;
    axis_cmd_last_cycle_offset_reg <= axis_cmd_last_cycle_offset_next;
    axis_cmd_cycle_count_reg <= axis_cmd_cycle_count_next;
    axis_cmd_tag_reg <= axis_cmd_tag_next;
    axis_cmd_axis_id_reg <= axis_cmd_axis_id_next;
    axis_cmd_axis_dest_reg <= axis_cmd_axis_dest_next;
    axis_cmd_axis_user_reg <= axis_cmd_axis_user_next;
    axis_cmd_valid_reg <= axis_cmd_valid_next;

    addr_reg <= addr_next;
    ram_mask_reg <= ram_mask_next;
    last_cycle_offset_reg <= last_cycle_offset_next;
    cycle_count_reg <= cycle_count_next;
    last_cycle_reg <= last_cycle_next;

    axis_id_reg <= axis_id_next;
    axis_dest_reg <= axis_dest_next;
    axis_user_reg <= axis_user_next;

    if (rst) begin
        read_state_reg <= READ_STATE_IDLE;
        axis_state_reg <= AXIS_STATE_IDLE;

        axis_cmd_valid_reg <= 1'b0;

        s_axis_read_desc_ready_reg <= 1'b0;
        m_axis_read_desc_status_valid_reg <= 1'b0;

        ram_rd_cmd_valid_reg <= {SEG_COUNT{1'b0}};
    end
end

// output datapath logic
reg [AXIS_DATA_WIDTH-1:0] m_axis_read_data_tdata_reg  = {AXIS_DATA_WIDTH{1'b0}};
reg [AXIS_KEEP_WIDTH-1:0] m_axis_read_data_tkeep_reg  = {AXIS_KEEP_WIDTH{1'b0}};
reg                       m_axis_read_data_tvalid_reg = 1'b0;
reg                       m_axis_read_data_tlast_reg  = 1'b0;
reg [AXIS_ID_WIDTH-1:0]   m_axis_read_data_tid_reg    = {AXIS_ID_WIDTH{1'b0}};
reg [AXIS_DEST_WIDTH-1:0] m_axis_read_data_tdest_reg  = {AXIS_DEST_WIDTH{1'b0}};
reg [AXIS_USER_WIDTH-1:0] m_axis_read_data_tuser_reg  = {AXIS_USER_WIDTH{1'b0}};

reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_wr_ptr_reg = 0;
reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_rd_ptr_reg = 0;
reg out_fifo_half_full_reg = 1'b0;

wire out_fifo_full = out_fifo_wr_ptr_reg == (out_fifo_rd_ptr_reg ^ {1'b1, {OUTPUT_FIFO_ADDR_WIDTH{1'b0}}});
wire out_fifo_empty = out_fifo_wr_ptr_reg == out_fifo_rd_ptr_reg;

(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [AXIS_DATA_WIDTH-1:0] out_fifo_tdata[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [AXIS_KEEP_WIDTH-1:0] out_fifo_tkeep[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg                       out_fifo_tlast[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [AXIS_ID_WIDTH-1:0]   out_fifo_tid[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [AXIS_DEST_WIDTH-1:0] out_fifo_tdest[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [AXIS_USER_WIDTH-1:0] out_fifo_tuser[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];

assign m_axis_read_data_tready_int = !out_fifo_half_full_reg;

assign m_axis_read_data_tdata  = m_axis_read_data_tdata_reg;
assign m_axis_read_data_tkeep  = AXIS_KEEP_ENABLE ? m_axis_read_data_tkeep_reg : {AXIS_KEEP_WIDTH{1'b1}};
assign m_axis_read_data_tvalid = m_axis_read_data_tvalid_reg;
assign m_axis_read_data_tlast  = AXIS_LAST_ENABLE ? m_axis_read_data_tlast_reg : 1'b1;
assign m_axis_read_data_tid    = AXIS_ID_ENABLE   ? m_axis_read_data_tid_reg   : {AXIS_ID_WIDTH{1'b0}};
assign m_axis_read_data_tdest  = AXIS_DEST_ENABLE ? m_axis_read_data_tdest_reg : {AXIS_DEST_WIDTH{1'b0}};
assign m_axis_read_data_tuser  = AXIS_USER_ENABLE ? m_axis_read_data_tuser_reg : {AXIS_USER_WIDTH{1'b0}};

always @(posedge clk) begin
    m_axis_read_data_tvalid_reg <= m_axis_read_data_tvalid_reg && !m_axis_read_data_tready;

    out_fifo_half_full_reg <= $unsigned(out_fifo_wr_ptr_reg - out_fifo_rd_ptr_reg) >= 2**(OUTPUT_FIFO_ADDR_WIDTH-1);

    if (!out_fifo_full && m_axis_read_data_tvalid_int) begin
        out_fifo_tdata[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_read_data_tdata_int;
        out_fifo_tkeep[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_read_data_tkeep_int;
        out_fifo_tlast[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_read_data_tlast_int;
        out_fifo_tid[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_read_data_tid_int;
        out_fifo_tdest[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_read_data_tdest_int;
        out_fifo_tuser[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_read_data_tuser_int;
        out_fifo_wr_ptr_reg <= out_fifo_wr_ptr_reg + 1;
    end

    if (!out_fifo_empty && (!m_axis_read_data_tvalid_reg || m_axis_read_data_tready)) begin
        m_axis_read_data_tdata_reg <= out_fifo_tdata[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        m_axis_read_data_tkeep_reg <= out_fifo_tkeep[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        m_axis_read_data_tvalid_reg <= 1'b1;
        m_axis_read_data_tlast_reg <= out_fifo_tlast[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        m_axis_read_data_tid_reg <= out_fifo_tid[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        m_axis_read_data_tdest_reg <= out_fifo_tdest[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        m_axis_read_data_tuser_reg <= out_fifo_tuser[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        out_fifo_rd_ptr_reg <= out_fifo_rd_ptr_reg + 1;
    end

    if (rst) begin
        out_fifo_wr_ptr_reg <= 0;
        out_fifo_rd_ptr_reg <= 0;
        m_axis_read_data_tvalid_reg <= 1'b0;
    end
end

endmodule

`resetall
