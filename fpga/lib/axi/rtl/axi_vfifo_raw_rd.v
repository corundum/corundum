/*

Copyright (c) 2023 Alex Forencich

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
 * AXI4 virtual FIFO (raw, read side)
 */
module axi_vfifo_raw_rd #
(
    // Width of input segment
    parameter SEG_WIDTH = 32,
    // Segment count
    parameter SEG_CNT = 2,
    // Width of AXI data bus in bits
    parameter AXI_DATA_WIDTH = SEG_WIDTH*SEG_CNT,
    // Width of AXI address bus in bits
    parameter AXI_ADDR_WIDTH = 16,
    // Width of AXI wstrb (width of data bus in words)
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    // Width of AXI ID signal
    parameter AXI_ID_WIDTH = 8,
    // Maximum AXI burst length to generate
    parameter AXI_MAX_BURST_LEN = 16,
    // Width of length field
    parameter LEN_WIDTH = AXI_ADDR_WIDTH,
    // Output FIFO depth for AXI read data (full-width words)
    parameter READ_FIFO_DEPTH = 128,
    // Max AXI read burst length
    parameter READ_MAX_BURST_LEN = READ_FIFO_DEPTH/4,
    // Use control output
    parameter CTRL_OUT_EN = 0
)
(
    input  wire                          clk,
    input  wire                          rst,

    /*
     * Segmented data output (to decode logic)
     */
    input  wire                          output_clk,
    input  wire                          output_rst,
    output wire                          output_rst_out,
    output wire [SEG_CNT*SEG_WIDTH-1:0]  output_data,
    output wire [SEG_CNT-1:0]            output_valid,
    input  wire [SEG_CNT-1:0]            output_ready,
    output wire [SEG_CNT*SEG_WIDTH-1:0]  output_ctrl_data,
    output wire [SEG_CNT-1:0]            output_ctrl_valid,
    input  wire [SEG_CNT-1:0]            output_ctrl_ready,

    /*
     * AXI master interface
     */
    output wire [AXI_ID_WIDTH-1:0]       m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0]     m_axi_araddr,
    output wire [7:0]                    m_axi_arlen,
    output wire [2:0]                    m_axi_arsize,
    output wire [1:0]                    m_axi_arburst,
    output wire                          m_axi_arlock,
    output wire [3:0]                    m_axi_arcache,
    output wire [2:0]                    m_axi_arprot,
    output wire                          m_axi_arvalid,
    input  wire                          m_axi_arready,
    input  wire [AXI_ID_WIDTH-1:0]       m_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0]     m_axi_rdata,
    input  wire [1:0]                    m_axi_rresp,
    input  wire                          m_axi_rlast,
    input  wire                          m_axi_rvalid,
    output wire                          m_axi_rready,

    /*
     * FIFO control
     */
    input  wire [LEN_WIDTH+1-1:0]        wr_start_ptr_in,
    input  wire [LEN_WIDTH+1-1:0]        wr_finish_ptr_in,
    output wire [LEN_WIDTH+1-1:0]        rd_start_ptr_out,
    output wire [LEN_WIDTH+1-1:0]        rd_finish_ptr_out,

    /*
     * Configuration
     */
    input  wire [AXI_ADDR_WIDTH-1:0]     cfg_fifo_base_addr,
    input  wire [LEN_WIDTH-1:0]          cfg_fifo_size_mask,
    input  wire                          cfg_enable,
    input  wire                          cfg_reset,

    /*
     * Status
     */
    output wire                          sts_read_active
);

localparam AXI_BYTE_LANES = AXI_STRB_WIDTH;
localparam AXI_BYTE_SIZE = AXI_DATA_WIDTH/AXI_BYTE_LANES;
localparam AXI_BURST_SIZE = $clog2(AXI_STRB_WIDTH);
localparam AXI_MAX_BURST_SIZE = AXI_MAX_BURST_LEN << AXI_BURST_SIZE;

localparam OFFSET_ADDR_WIDTH = AXI_STRB_WIDTH > 1 ? $clog2(AXI_STRB_WIDTH) : 1;
localparam OFFSET_ADDR_MASK = AXI_STRB_WIDTH > 1 ? {OFFSET_ADDR_WIDTH{1'b1}} : 0;
localparam ADDR_MASK = {AXI_ADDR_WIDTH{1'b1}} << $clog2(AXI_STRB_WIDTH);
localparam CYCLE_COUNT_WIDTH = LEN_WIDTH - AXI_BURST_SIZE + 1;

localparam READ_FIFO_ADDR_WIDTH = $clog2(READ_FIFO_DEPTH);

// mask(x) = (2**$clog2(x))-1
// log2(min(x, y, z)) = (mask & mask & mask)+1
// floor(log2(x)) = $clog2(x+1)-1
// floor(log2(min(AXI_MAX_BURST_LEN, READ_MAX_BURST_LEN, 2**(READ_FIFO_ADDR_WIDTH-1), 4096/AXI_BYTE_LANES)))
localparam READ_MAX_BURST_LEN_INT = ((2**($clog2(AXI_MAX_BURST_LEN+1)-1)-1) & (2**($clog2(READ_MAX_BURST_LEN+1)-1)-1) & (2**(READ_FIFO_ADDR_WIDTH-1)-1) & ((4096/AXI_BYTE_LANES)-1)) + 1;
localparam READ_MAX_BURST_SIZE_INT = READ_MAX_BURST_LEN_INT << AXI_BURST_SIZE;
localparam READ_BURST_LEN_WIDTH = $clog2(READ_MAX_BURST_LEN_INT);
localparam READ_BURST_ADDR_WIDTH = $clog2(READ_MAX_BURST_SIZE_INT);
localparam READ_BURST_ADDR_MASK = READ_BURST_ADDR_WIDTH > 1 ? {READ_BURST_ADDR_WIDTH{1'b1}} : 0;

// validate parameters
initial begin
    if (AXI_BYTE_SIZE * AXI_STRB_WIDTH != AXI_DATA_WIDTH) begin
        $error("Error: AXI data width not evenly divisible (instance %m)");
        $finish;
    end

    if (2**$clog2(AXI_BYTE_LANES) != AXI_BYTE_LANES) begin
        $error("Error: AXI byte lane count must be even power of two (instance %m)");
        $finish;
    end

    if (AXI_MAX_BURST_LEN < 1 || AXI_MAX_BURST_LEN > 256) begin
        $error("Error: AXI_MAX_BURST_LEN must be between 1 and 256 (instance %m)");
        $finish;
    end

    if (SEG_CNT * SEG_WIDTH != AXI_DATA_WIDTH) begin
        $error("Error: Width mismatch (instance %m)");
        $finish;
    end
end

localparam [1:0]
    AXI_RESP_OKAY = 2'b00,
    AXI_RESP_EXOKAY = 2'b01,
    AXI_RESP_SLVERR = 2'b10,
    AXI_RESP_DECERR = 2'b11;

reg [AXI_ADDR_WIDTH-1:0] m_axi_araddr_reg = {AXI_ADDR_WIDTH{1'b0}}, m_axi_araddr_next;
reg [7:0] m_axi_arlen_reg = 8'd0, m_axi_arlen_next;
reg m_axi_arvalid_reg = 1'b0, m_axi_arvalid_next;

assign m_axi_arid = {AXI_ID_WIDTH{1'b0}};
assign m_axi_araddr = m_axi_araddr_reg;
assign m_axi_arlen = m_axi_arlen_reg;
assign m_axi_arsize = AXI_BURST_SIZE;
assign m_axi_arburst = 2'b01;
assign m_axi_arlock = 1'b0;
assign m_axi_arcache = 4'b0011;
assign m_axi_arprot = 3'b010;
assign m_axi_arvalid = m_axi_arvalid_reg;

// reset synchronization
wire rst_req_int = cfg_reset;

(* shreg_extract = "no" *)
reg rst_sync_1_reg = 1'b1,  rst_sync_2_reg = 1'b1, rst_sync_3_reg = 1'b1;

assign output_rst_out = rst_sync_3_reg;

always @(posedge output_clk or posedge rst_req_int) begin
    if (rst_req_int) begin
        rst_sync_1_reg <= 1'b1;
    end else begin
        rst_sync_1_reg <= 1'b0;
    end
end

always @(posedge output_clk) begin
    rst_sync_2_reg <= rst_sync_1_reg;
    rst_sync_3_reg <= rst_sync_2_reg;
end

// output datapath logic (read data)
reg [AXI_DATA_WIDTH-1:0] m_axis_tdata_reg  = {AXI_DATA_WIDTH{1'b0}};
reg                      m_axis_tvalid_reg = 1'b0;

reg [READ_FIFO_ADDR_WIDTH-1:0] read_fifo_read_start_cnt = 0;
reg read_fifo_read_start_en = 1'b0;

reg [READ_FIFO_ADDR_WIDTH+1-1:0] read_fifo_read_start_ptr_reg = 0;
reg [READ_FIFO_ADDR_WIDTH+1-1:0] read_fifo_wr_ptr_reg = 0;
reg [READ_FIFO_ADDR_WIDTH+1-1:0] read_fifo_wr_ptr_gray_reg = 0;
wire [READ_FIFO_ADDR_WIDTH+1-1:0] read_fifo_rd_ptr;
wire [READ_FIFO_ADDR_WIDTH+1-1:0] read_fifo_rd_ptr_gray;
wire [READ_FIFO_ADDR_WIDTH+1-1:0] read_fifo_ctrl_rd_ptr;
wire [READ_FIFO_ADDR_WIDTH+1-1:0] read_fifo_ctrl_rd_ptr_gray;

reg [READ_FIFO_ADDR_WIDTH+1-1:0] read_fifo_wr_ptr_temp;

(* shreg_extract = "no" *)
reg [READ_FIFO_ADDR_WIDTH+1-1:0] read_fifo_wr_ptr_gray_sync_1_reg = 0;
(* shreg_extract = "no" *)
reg [READ_FIFO_ADDR_WIDTH+1-1:0] read_fifo_wr_ptr_gray_sync_2_reg = 0;

(* shreg_extract = "no" *)
reg [READ_FIFO_ADDR_WIDTH+1-1:0] read_fifo_rd_ptr_gray_sync_1_reg = 0;
(* shreg_extract = "no" *)
reg [READ_FIFO_ADDR_WIDTH+1-1:0] read_fifo_rd_ptr_gray_sync_2_reg = 0;
reg [READ_FIFO_ADDR_WIDTH+1-1:0] read_fifo_rd_ptr_sync_reg = 0;

(* shreg_extract = "no" *)
reg [READ_FIFO_ADDR_WIDTH+1-1:0] read_fifo_ctrl_rd_ptr_gray_sync_1_reg = 0;
(* shreg_extract = "no" *)
reg [READ_FIFO_ADDR_WIDTH+1-1:0] read_fifo_ctrl_rd_ptr_gray_sync_2_reg = 0;
reg [READ_FIFO_ADDR_WIDTH+1-1:0] read_fifo_ctrl_rd_ptr_sync_reg = 0;

reg read_fifo_half_full_reg = 1'b0;
reg [READ_FIFO_ADDR_WIDTH+1-1:0] read_fifo_occupancy_reg = 0;
reg [READ_FIFO_ADDR_WIDTH+1-1:0] read_fifo_occupancy_lookahead_reg = 0;

wire read_fifo_full = read_fifo_wr_ptr_gray_reg == (read_fifo_rd_ptr_gray_sync_2_reg ^ {2'b11, {READ_FIFO_ADDR_WIDTH-1{1'b0}}});
wire read_fifo_empty = read_fifo_rd_ptr_gray == read_fifo_wr_ptr_gray_sync_2_reg;

wire read_fifo_ctrl_full = read_fifo_wr_ptr_gray_reg == (read_fifo_ctrl_rd_ptr_gray_sync_2_reg ^ {2'b11, {READ_FIFO_ADDR_WIDTH-1{1'b0}}});
wire read_fifo_ctrl_empty = read_fifo_ctrl_rd_ptr_gray == read_fifo_wr_ptr_gray_sync_2_reg;

assign m_axi_rready = (!read_fifo_full && (!CTRL_OUT_EN || !read_fifo_ctrl_full)) || cfg_reset;

genvar n;
integer k;

generate

for (n = 0; n < SEG_CNT; n = n + 1) begin : read_fifo_seg

    reg [READ_FIFO_ADDR_WIDTH+1-1:0] seg_rd_ptr_reg = 0;
    reg [READ_FIFO_ADDR_WIDTH+1-1:0] seg_rd_ptr_gray_reg = 0;

    reg [READ_FIFO_ADDR_WIDTH+1-1:0] seg_rd_ptr_temp;

    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [SEG_WIDTH-1:0] seg_mem_data[2**READ_FIFO_ADDR_WIDTH-1:0];

    reg [SEG_WIDTH-1:0] seg_rd_data_reg = 0;
    reg seg_rd_data_valid_reg = 0;

    wire seg_empty = seg_rd_ptr_gray_reg == read_fifo_wr_ptr_gray_sync_2_reg;

    assign output_data[n*SEG_WIDTH +: SEG_WIDTH] = seg_rd_data_reg;
    assign output_valid[n] = seg_rd_data_valid_reg;

    if (n == SEG_CNT-1) begin
        assign read_fifo_rd_ptr = seg_rd_ptr_reg;
        assign read_fifo_rd_ptr_gray = seg_rd_ptr_gray_reg;
    end

    always @(posedge clk) begin
        if (!read_fifo_full && m_axi_rready && m_axi_rvalid) begin
            seg_mem_data[read_fifo_wr_ptr_reg[READ_FIFO_ADDR_WIDTH-1:0]] <= m_axi_rdata[n*SEG_WIDTH +: SEG_WIDTH];
        end
    end

    // per-segment read logic
    always @(posedge output_clk) begin
        seg_rd_data_valid_reg <= seg_rd_data_valid_reg && !output_ready[n];

        if (!seg_empty && (!seg_rd_data_valid_reg || output_ready[n])) begin
            seg_rd_data_reg <= seg_mem_data[seg_rd_ptr_reg[READ_FIFO_ADDR_WIDTH-1:0]];
            seg_rd_data_valid_reg <= 1'b1;

            seg_rd_ptr_temp = seg_rd_ptr_reg + 1;
            seg_rd_ptr_reg <= seg_rd_ptr_temp;
            seg_rd_ptr_gray_reg <= seg_rd_ptr_temp ^ (seg_rd_ptr_temp >> 1);
        end

        if (output_rst || output_rst_out) begin
            seg_rd_ptr_reg <= 0;
            seg_rd_ptr_gray_reg <= 0;
            seg_rd_data_valid_reg <= 1'b0;
        end
    end

end

endgenerate

// write logic
always @(posedge clk) begin
    read_fifo_occupancy_reg <= read_fifo_wr_ptr_reg - read_fifo_rd_ptr_sync_reg;
    read_fifo_half_full_reg <= $unsigned(read_fifo_wr_ptr_reg - read_fifo_rd_ptr_sync_reg) >= 2**(READ_FIFO_ADDR_WIDTH-1);

    if (read_fifo_read_start_en) begin
        read_fifo_read_start_ptr_reg <= read_fifo_read_start_ptr_reg + read_fifo_read_start_cnt;
        read_fifo_occupancy_lookahead_reg <= read_fifo_read_start_ptr_reg + read_fifo_read_start_cnt - read_fifo_rd_ptr_sync_reg;
    end else begin
        read_fifo_occupancy_lookahead_reg <= read_fifo_read_start_ptr_reg - read_fifo_rd_ptr_sync_reg;
    end

    if (!read_fifo_full && m_axi_rready && m_axi_rvalid) begin
        read_fifo_wr_ptr_temp = read_fifo_wr_ptr_reg + 1;
        read_fifo_wr_ptr_reg <= read_fifo_wr_ptr_temp;
        read_fifo_wr_ptr_gray_reg <= read_fifo_wr_ptr_temp ^ (read_fifo_wr_ptr_temp >> 1);

        read_fifo_occupancy_reg <= read_fifo_wr_ptr_temp - read_fifo_rd_ptr_sync_reg;
    end

    if (rst || cfg_reset) begin
        read_fifo_read_start_ptr_reg <= 0;
        read_fifo_wr_ptr_reg <= 0;
        read_fifo_wr_ptr_gray_reg <= 0;
    end
end

// pointer synchronization
always @(posedge clk) begin
    read_fifo_rd_ptr_gray_sync_1_reg <= read_fifo_rd_ptr_gray;
    read_fifo_rd_ptr_gray_sync_2_reg <= read_fifo_rd_ptr_gray_sync_1_reg;

    for (k = 0; k < READ_FIFO_ADDR_WIDTH+1; k = k + 1) begin
        read_fifo_rd_ptr_sync_reg[k] <= ^(read_fifo_rd_ptr_gray_sync_2_reg >> k);
    end

    if (rst || cfg_reset) begin
        read_fifo_rd_ptr_gray_sync_1_reg <= 0;
        read_fifo_rd_ptr_gray_sync_2_reg <= 0;
        read_fifo_rd_ptr_sync_reg <= 0;
    end
end

always @(posedge clk) begin
    read_fifo_ctrl_rd_ptr_gray_sync_1_reg <= read_fifo_ctrl_rd_ptr_gray;
    read_fifo_ctrl_rd_ptr_gray_sync_2_reg <= read_fifo_ctrl_rd_ptr_gray_sync_1_reg;

    for (k = 0; k < READ_FIFO_ADDR_WIDTH+1; k = k + 1) begin
        read_fifo_ctrl_rd_ptr_sync_reg[k] <= ^(read_fifo_ctrl_rd_ptr_gray_sync_2_reg >> k);
    end

    if (rst || cfg_reset) begin
        read_fifo_ctrl_rd_ptr_gray_sync_1_reg <= 0;
        read_fifo_ctrl_rd_ptr_gray_sync_2_reg <= 0;
        read_fifo_ctrl_rd_ptr_sync_reg <= 0;
    end
end

always @(posedge output_clk) begin
    read_fifo_wr_ptr_gray_sync_1_reg <= read_fifo_wr_ptr_gray_reg;
    read_fifo_wr_ptr_gray_sync_2_reg <= read_fifo_wr_ptr_gray_sync_1_reg;

    if (output_rst || output_rst_out) begin
        read_fifo_wr_ptr_gray_sync_1_reg <= 0;
        read_fifo_wr_ptr_gray_sync_2_reg <= 0;
    end
end

generate

if (CTRL_OUT_EN) begin
    
    for (n = 0; n < SEG_CNT; n = n + 1) begin : read_fifo_ctrl_seg

        reg [READ_FIFO_ADDR_WIDTH+1-1:0] seg_rd_ptr_reg = 0;
        reg [READ_FIFO_ADDR_WIDTH+1-1:0] seg_rd_ptr_gray_reg = 0;

        reg [READ_FIFO_ADDR_WIDTH+1-1:0] seg_rd_ptr_temp;

        (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
        reg [SEG_WIDTH-1:0] seg_mem_data[2**READ_FIFO_ADDR_WIDTH-1:0];

        reg [SEG_WIDTH-1:0] seg_rd_data_reg = 0;
        reg seg_rd_data_valid_reg = 0;

        reg seg_output_ready_reg = 1'b0;

        wire seg_empty = seg_rd_ptr_gray_reg == read_fifo_wr_ptr_gray_sync_2_reg;

        if (n == SEG_CNT-1) begin
            assign read_fifo_ctrl_rd_ptr = seg_rd_ptr_reg;
            assign read_fifo_ctrl_rd_ptr_gray = seg_rd_ptr_gray_reg;
        end

        always @(posedge clk) begin
            if (!read_fifo_full && m_axi_rready && m_axi_rvalid) begin
                seg_mem_data[read_fifo_wr_ptr_reg[READ_FIFO_ADDR_WIDTH-1:0]] <= m_axi_rdata[n*SEG_WIDTH +: SEG_WIDTH];
            end
        end

        // per-segment read logic
        always @(posedge output_clk) begin
            seg_rd_data_valid_reg <= seg_rd_data_valid_reg && !seg_output_ready_reg;

            if (!seg_empty && (!seg_rd_data_valid_reg || seg_output_ready_reg)) begin
                seg_rd_data_reg <= seg_mem_data[seg_rd_ptr_reg[READ_FIFO_ADDR_WIDTH-1:0]];
                seg_rd_data_valid_reg <= 1'b1;

                seg_rd_ptr_temp = seg_rd_ptr_reg + 1;
                seg_rd_ptr_reg <= seg_rd_ptr_temp;
                seg_rd_ptr_gray_reg <= seg_rd_ptr_temp ^ (seg_rd_ptr_temp >> 1);
            end

            if (output_rst || output_rst_out) begin
                seg_rd_ptr_reg <= 0;
                seg_rd_ptr_gray_reg <= 0;
                seg_rd_data_valid_reg <= 1'b0;
            end
        end

        // skid buffer
        reg [SEG_WIDTH-1:0] seg_output_data_reg = 0;
        reg seg_output_valid_reg = 1'b0;

        reg [SEG_WIDTH-1:0] temp_seg_output_data_reg = 0;
        reg temp_seg_output_valid_reg = 1'b0;

        assign output_ctrl_data[n*SEG_WIDTH +: SEG_WIDTH] = seg_output_data_reg;
        assign output_ctrl_valid[n] = seg_output_valid_reg;

        always @(posedge output_clk) begin
            // enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
            seg_output_ready_reg <= output_ctrl_ready[n] || (!temp_seg_output_valid_reg && (!seg_output_valid_reg || !seg_rd_data_valid_reg));

            if (seg_output_ready_reg) begin
                // input is ready
                if (output_ctrl_ready[n] || !seg_output_valid_reg) begin
                    // output is ready or currently not valid, transfer data to output
                    seg_output_data_reg <= seg_rd_data_reg;
                    seg_output_valid_reg <= seg_rd_data_valid_reg;
                end else begin
                    // output is not ready, store input in temp
                    temp_seg_output_data_reg <= seg_rd_data_reg;
                    temp_seg_output_valid_reg <= seg_rd_data_valid_reg;
                end
            end else if (output_ctrl_ready[n]) begin
                // input is not ready, but output is ready
                seg_output_data_reg <= temp_seg_output_data_reg;
                seg_output_valid_reg <= temp_seg_output_valid_reg;
                temp_seg_output_valid_reg <= 1'b0;
            end

            if (output_rst || output_rst_out) begin
                seg_output_ready_reg <= 1'b0;
                seg_output_valid_reg <= 1'b0;
                temp_seg_output_valid_reg <= 1'b0;
            end
        end

    end

end

endgenerate

reg [READ_BURST_LEN_WIDTH+1-1:0] rd_burst_len;
reg [READ_BURST_LEN_WIDTH+1-1:0] rd_outstanding_inc;
reg rd_outstanding_dec;
reg [READ_FIFO_ADDR_WIDTH+1-1:0] rd_outstanding_reg = 0, rd_outstanding_next;
reg [LEN_WIDTH+1-1:0] rd_start_ptr;
reg [7:0] rd_timeout_count_reg = 0, rd_timeout_count_next;
reg rd_timeout_reg = 0, rd_timeout_next;

reg [LEN_WIDTH+1-1:0] rd_start_ptr_reg = 0, rd_start_ptr_next;
reg [LEN_WIDTH+1-1:0] rd_finish_ptr_reg = 0, rd_finish_ptr_next;

assign rd_start_ptr_out = rd_start_ptr_reg;
assign rd_finish_ptr_out = rd_finish_ptr_reg;

assign sts_read_active = rd_outstanding_reg != 0;

// read logic
always @* begin
    rd_start_ptr_next = rd_start_ptr_reg;
    rd_finish_ptr_next = rd_finish_ptr_reg;

    rd_outstanding_inc = 0;
    rd_outstanding_dec = 0;
    rd_outstanding_next = rd_outstanding_reg;
    rd_timeout_count_next = rd_timeout_count_reg;
    rd_timeout_next = rd_timeout_reg;

    m_axi_araddr_next = m_axi_araddr_reg;
    m_axi_arlen_next = m_axi_arlen_reg;
    m_axi_arvalid_next = m_axi_arvalid_reg && !m_axi_arready;

    // partial burst timeout handling
    rd_timeout_next = rd_timeout_count_reg == 0;
    if (wr_finish_ptr_in == rd_start_ptr_reg || m_axi_arvalid) begin
        rd_timeout_count_next = 8'hff;
        rd_timeout_next = 1'b0;
    end else if (rd_timeout_count_reg > 0) begin
        rd_timeout_count_next = rd_timeout_count_reg - 1;
    end

    // compute length based on DRAM occupancy
    if ((wr_finish_ptr_in ^ rd_start_ptr_reg) >> READ_BURST_ADDR_WIDTH != 0) begin
        // crosses burst boundary, read up to burst boundary
        rd_burst_len = READ_MAX_BURST_LEN_INT - ((rd_start_ptr_reg & READ_BURST_ADDR_MASK) >> AXI_BURST_SIZE);
        rd_start_ptr = (rd_start_ptr_reg & ~READ_BURST_ADDR_MASK) + (1 << READ_BURST_ADDR_WIDTH);
    end else begin
        // does not cross burst boundary, read available data
        rd_burst_len = (wr_finish_ptr_in - rd_start_ptr_reg) >> AXI_BURST_SIZE;
        rd_start_ptr = wr_finish_ptr_in;
    end

    read_fifo_read_start_cnt = rd_burst_len;
    read_fifo_read_start_en = 1'b0;

    // generate AXI read bursts
    if (!m_axi_arvalid_reg) begin
        // ready to start new burst

        m_axi_araddr_next = cfg_fifo_base_addr + (rd_start_ptr_reg & cfg_fifo_size_mask);
        m_axi_arlen_next = rd_burst_len - 1;

        if (cfg_enable && (wr_finish_ptr_in ^ rd_start_ptr_reg) != 0 && read_fifo_occupancy_lookahead_reg < 2**READ_FIFO_ADDR_WIDTH - READ_MAX_BURST_LEN_INT) begin
            // enabled, have data to write, have space for data
            if ((wr_finish_ptr_in ^ rd_start_ptr_reg) >> READ_BURST_ADDR_WIDTH != 0 || rd_timeout_reg) begin
                // have full burst or timed out
                read_fifo_read_start_en = 1'b1;
                rd_outstanding_inc = rd_burst_len;
                m_axi_arvalid_next = 1'b1;
                rd_start_ptr_next = rd_start_ptr;
            end
        end
    end

    // handle AXI read completions
    if (m_axi_rready && m_axi_rvalid) begin
        rd_finish_ptr_next = rd_finish_ptr_reg + AXI_BYTE_LANES;
        rd_outstanding_dec = 1;
    end

    rd_outstanding_next = rd_outstanding_reg + rd_outstanding_inc - rd_outstanding_dec;

    if (cfg_reset) begin
        rd_start_ptr_next = 0;
        rd_finish_ptr_next = 0;
    end
end

always @(posedge clk) begin
    rd_start_ptr_reg <= rd_start_ptr_next;
    rd_finish_ptr_reg <= rd_finish_ptr_next;

    rd_outstanding_reg <= rd_outstanding_next;
    rd_timeout_count_reg <= rd_timeout_count_next;
    rd_timeout_reg <= rd_timeout_next;

    m_axi_araddr_reg <= m_axi_araddr_next;
    m_axi_arlen_reg <= m_axi_arlen_next;
    m_axi_arvalid_reg <= m_axi_arvalid_next;

    if (rst) begin
        rd_outstanding_reg <= 0;
        m_axi_arvalid_reg <= 1'b0;
    end
end

endmodule

`resetall
