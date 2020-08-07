/*

Copyright (c) 2019 Alex Forencich

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
reg [SEG_COUNT-1:0] ram_mask_reg = 0, ram_mask_next;
reg [AXIS_KEEP_WIDTH_INT-1:0] keep_mask_reg = {AXIS_KEEP_WIDTH_INT{1'b0}}, keep_mask_next;
reg [OFFSET_WIDTH-1:0] last_cycle_offset_reg = {OFFSET_WIDTH{1'b0}}, last_cycle_offset_next;
reg [LEN_WIDTH-1:0] length_reg = {LEN_WIDTH{1'b0}}, length_next;
reg [CYCLE_COUNT_WIDTH-1:0] cycle_count_reg = {CYCLE_COUNT_WIDTH{1'b0}}, cycle_count_next;
reg last_cycle_reg = 1'b0, last_cycle_next;

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
reg  [SEG_COUNT-1:0]                ram_wr_cmd_ready_int_reg = 1'b0;
wire [SEG_COUNT-1:0]                ram_wr_cmd_ready_int_early;

assign s_axis_write_desc_ready = s_axis_write_desc_ready_reg;

assign m_axis_write_desc_status_len = m_axis_write_desc_status_len_reg;
assign m_axis_write_desc_status_tag = m_axis_write_desc_status_tag_reg;
assign m_axis_write_desc_status_id = m_axis_write_desc_status_id_reg;
assign m_axis_write_desc_status_dest = m_axis_write_desc_status_dest_reg;
assign m_axis_write_desc_status_user = m_axis_write_desc_status_user_reg;
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

    ram_wr_cmd_be_int = (s_axis_write_data_tkeep & keep_mask_reg) << (addr_reg & ({PART_COUNT_WIDTH{1'b1}} << PART_OFFSET_WIDTH));
    ram_wr_cmd_addr_int = {PART_COUNT{addr_reg[RAM_ADDR_WIDTH-1:RAM_ADDR_WIDTH-SEG_ADDR_WIDTH]}};
    ram_wr_cmd_data_int = {PART_COUNT{s_axis_write_data_tdata}};
    ram_wr_cmd_valid_int = {SEG_COUNT{1'b0}};

    cycle_size = AXIS_KEEP_WIDTH_INT;

    addr_next = addr_reg;
    ram_mask_next = ram_mask_reg;
    keep_mask_next = keep_mask_reg;
    last_cycle_offset_next = last_cycle_offset_reg;
    length_next = length_reg;
    cycle_count_next = cycle_count_reg;
    last_cycle_next = last_cycle_reg;

    case (state_reg)
        STATE_IDLE: begin
            // idle state - load new descriptor to start operation
            s_axis_write_desc_ready_next = enable;

            addr_next = s_axis_write_desc_ram_addr & ADDR_MASK;
            last_cycle_offset_next = s_axis_write_desc_len & OFFSET_MASK;

            if (PART_COUNT > 1) begin
                ram_mask_next = {SEGS_PER_PART{1'b1}} << ((((addr_next >> PART_OFFSET_WIDTH) & ({PART_COUNT_WIDTH{1'b1}})) / PARTS_PER_SEG) * SEGS_PER_PART);
            end else begin
                ram_mask_next = {SEG_COUNT{1'b1}};
            end

            m_axis_write_desc_status_tag_next = s_axis_write_desc_tag;

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
                s_axis_write_data_tready_next = !(~ram_wr_cmd_ready_int_early & ram_mask_next);
                state_next = STATE_WRITE;
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_WRITE: begin
            // write state - generate write operations
            s_axis_write_data_tready_next = !(~ram_wr_cmd_ready_int_early & ram_mask_reg);

            if (s_axis_write_data_tready && s_axis_write_data_tvalid) begin
                m_axis_write_desc_status_id_next = s_axis_write_data_tid;
                m_axis_write_desc_status_dest_next = s_axis_write_data_tdest;
                m_axis_write_desc_status_user_next = s_axis_write_data_tuser;

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
                    ram_mask_next = {SEGS_PER_PART{1'b1}} << ((((addr_next >> PART_OFFSET_WIDTH) & ({PART_COUNT_WIDTH{1'b1}})) / PARTS_PER_SEG) * SEGS_PER_PART);
                end else begin
                    ram_mask_next = {SEG_COUNT{1'b1}};
                end

                if (PART_COUNT > 1) begin
                    ram_wr_cmd_be_int = (s_axis_write_data_tkeep & keep_mask_reg) << (addr_reg & ({PART_COUNT_WIDTH{1'b1}} << PART_OFFSET_WIDTH));
                end else begin
                    ram_wr_cmd_be_int = s_axis_write_data_tkeep & keep_mask_reg;
                end
                ram_wr_cmd_addr_int = {SEG_COUNT{addr_reg[RAM_ADDR_WIDTH-1:RAM_ADDR_WIDTH-SEG_ADDR_WIDTH]}};
                ram_wr_cmd_data_int = {PART_COUNT{s_axis_write_data_tdata}};
                for (i = 0; i < SEG_COUNT; i = i + 1) begin
                    ram_wr_cmd_valid_int[i] = ram_wr_cmd_be_int[i*SEG_BE_WIDTH +: SEG_BE_WIDTH] != 0;
                end

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

                    m_axis_write_desc_status_len_next = length_next;
                    m_axis_write_desc_status_valid_next = 1'b1;

                    s_axis_write_data_tready_next = 1'b0;
                    s_axis_write_desc_ready_next = enable;
                    state_next = STATE_IDLE;
                end else if (last_cycle_reg) begin
                    if (last_cycle_offset_reg > 0) begin
                        length_next = length_reg + last_cycle_offset_reg;
                    end

                    m_axis_write_desc_status_len_next = length_next;
                    m_axis_write_desc_status_valid_next = 1'b1;

                    if (AXIS_LAST_ENABLE) begin
                        s_axis_write_data_tready_next = 1'b1;
                        state_next = STATE_DROP_DATA;
                    end else begin
                        s_axis_write_data_tready_next = 1'b0;
                        s_axis_write_desc_ready_next = enable;
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
                    s_axis_write_desc_ready_next = enable;
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_DROP_DATA;
                end
            end else begin
                state_next = STATE_DROP_DATA;
            end
        end
    endcase
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
    ram_mask_reg <= ram_mask_next;
    keep_mask_reg <= keep_mask_next;
    last_cycle_offset_reg <= last_cycle_offset_next;
    length_reg <= length_next;
    cycle_count_reg <= cycle_count_next;
    last_cycle_reg <= last_cycle_next;

    if (rst) begin
        state_reg <= STATE_IDLE;
        s_axis_write_desc_ready_reg <= 1'b0;
        m_axis_write_desc_status_valid_reg <= 1'b0;
        s_axis_write_data_tready_reg <= 1'b0;
    end
end

// output datapath logic (write data)
generate

genvar n;

for (n = 0; n < SEG_COUNT; n = n + 1) begin

    reg [SEG_BE_WIDTH-1:0]   ram_wr_cmd_be_reg = {SEG_BE_WIDTH{1'b0}};
    reg [SEG_ADDR_WIDTH-1:0] ram_wr_cmd_addr_reg = {SEG_ADDR_WIDTH{1'b0}};
    reg [SEG_DATA_WIDTH-1:0] ram_wr_cmd_data_reg = {SEG_DATA_WIDTH{1'b0}};
    reg                      ram_wr_cmd_valid_reg = 1'b0, ram_wr_cmd_valid_next;

    reg [SEG_BE_WIDTH-1:0]   temp_ram_wr_cmd_be_reg = {SEG_BE_WIDTH{1'b0}};
    reg [SEG_ADDR_WIDTH-1:0] temp_ram_wr_cmd_addr_reg = {SEG_ADDR_WIDTH{1'b0}};
    reg [SEG_DATA_WIDTH-1:0] temp_ram_wr_cmd_data_reg = {SEG_DATA_WIDTH{1'b0}};
    reg                      temp_ram_wr_cmd_valid_reg = 1'b0, temp_ram_wr_cmd_valid_next;

    // datapath control
    reg store_axi_w_int_to_output;
    reg store_axi_w_int_to_temp;
    reg store_axi_w_temp_to_output;

    assign ram_wr_cmd_be[n*SEG_BE_WIDTH +: SEG_BE_WIDTH] = ram_wr_cmd_be_reg;
    assign ram_wr_cmd_addr[n*SEG_ADDR_WIDTH +: SEG_ADDR_WIDTH] = ram_wr_cmd_addr_reg;
    assign ram_wr_cmd_data[n*SEG_DATA_WIDTH +: SEG_DATA_WIDTH] = ram_wr_cmd_data_reg;
    assign ram_wr_cmd_valid[n +: 1] = ram_wr_cmd_valid_reg;

    // enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
    assign ram_wr_cmd_ready_int_early[n +: 1] = ram_wr_cmd_ready[n +: 1] || (!temp_ram_wr_cmd_valid_reg && (!ram_wr_cmd_valid_reg || !ram_wr_cmd_valid_int[n +: 1]));

    always @* begin
        // transfer sink ready state to source
        ram_wr_cmd_valid_next = ram_wr_cmd_valid_reg;
        temp_ram_wr_cmd_valid_next = temp_ram_wr_cmd_valid_reg;

        store_axi_w_int_to_output = 1'b0;
        store_axi_w_int_to_temp = 1'b0;
        store_axi_w_temp_to_output = 1'b0;
        
        if (ram_wr_cmd_ready_int_reg[n +: 1]) begin
            // input is ready
            if (ram_wr_cmd_ready[n +: 1] || !ram_wr_cmd_valid_reg) begin
                // output is ready or currently not valid, transfer data to output
                ram_wr_cmd_valid_next = ram_wr_cmd_valid_int[n +: 1];
                store_axi_w_int_to_output = 1'b1;
            end else begin
                // output is not ready, store input in temp
                temp_ram_wr_cmd_valid_next = ram_wr_cmd_valid_int[n +: 1];
                store_axi_w_int_to_temp = 1'b1;
            end
        end else if (ram_wr_cmd_ready[n +: 1]) begin
            // input is not ready, but output is ready
            ram_wr_cmd_valid_next = temp_ram_wr_cmd_valid_reg;
            temp_ram_wr_cmd_valid_next = 1'b0;
            store_axi_w_temp_to_output = 1'b1;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            ram_wr_cmd_valid_reg <= 1'b0;
            ram_wr_cmd_ready_int_reg[n +: 1] <= 1'b0;
            temp_ram_wr_cmd_valid_reg <= 1'b0;
        end else begin
            ram_wr_cmd_valid_reg <= ram_wr_cmd_valid_next;
            ram_wr_cmd_ready_int_reg[n +: 1] <= ram_wr_cmd_ready_int_early[n +: 1];
            temp_ram_wr_cmd_valid_reg <= temp_ram_wr_cmd_valid_next;
        end

        // datapath
        if (store_axi_w_int_to_output) begin
            ram_wr_cmd_be_reg <= ram_wr_cmd_be_int[n*SEG_BE_WIDTH +: SEG_BE_WIDTH];
            ram_wr_cmd_addr_reg <= ram_wr_cmd_addr_int[n*SEG_ADDR_WIDTH +: SEG_ADDR_WIDTH];
            ram_wr_cmd_data_reg <= ram_wr_cmd_data_int[n*SEG_DATA_WIDTH +: SEG_DATA_WIDTH];
        end else if (store_axi_w_temp_to_output) begin
            ram_wr_cmd_be_reg <= temp_ram_wr_cmd_be_reg;
            ram_wr_cmd_addr_reg <= temp_ram_wr_cmd_addr_reg;
            ram_wr_cmd_data_reg <= temp_ram_wr_cmd_data_reg;
        end

        if (store_axi_w_int_to_temp) begin
            temp_ram_wr_cmd_be_reg <= ram_wr_cmd_be_int[n*SEG_BE_WIDTH +: SEG_BE_WIDTH];
            temp_ram_wr_cmd_addr_reg <= ram_wr_cmd_addr_int[n*SEG_ADDR_WIDTH +: SEG_ADDR_WIDTH];
            temp_ram_wr_cmd_data_reg <= ram_wr_cmd_data_int[n*SEG_DATA_WIDTH +: SEG_DATA_WIDTH];
        end
    end

end

endgenerate

endmodule
