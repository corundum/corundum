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
 * Transmit checksum offload module
 */
module tx_checksum #
(
    // Width of AXI stream interfaces in bits
    parameter DATA_WIDTH = 256,
    // AXI stream tkeep signal width (words per cycle)
    parameter KEEP_WIDTH = (DATA_WIDTH/8),
    // Propagate tid signal
    parameter ID_ENABLE = 0,
    // tid signal width
    parameter ID_WIDTH = 8,
    // Propagate tdest signal
    parameter DEST_ENABLE = 0,
    // tdest signal width
    parameter DEST_WIDTH = 8,
    // Propagate tuser signal
    parameter USER_ENABLE = 1,
    // tuser signal width
    parameter USER_WIDTH = 1,
    // Use checksum init value
    parameter USE_INIT_VALUE = 0,
    // Depth of data FIFO in words
    parameter DATA_FIFO_DEPTH = 4096,
    // Depth of checksum FIFO
    parameter CHECKSUM_FIFO_DEPTH = 64
)
(
    input  wire                   clk,
    input  wire                   rst,

    /*
     * AXI input
     */
    input  wire [DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]  s_axis_tkeep,
    input  wire                   s_axis_tvalid,
    output wire                   s_axis_tready,
    input  wire                   s_axis_tlast,
    input  wire [ID_WIDTH-1:0]    s_axis_tid,
    input  wire [DEST_WIDTH-1:0]  s_axis_tdest,
    input  wire [USER_WIDTH-1:0]  s_axis_tuser,

    /*
     * AXI output
     */
    output wire [DATA_WIDTH-1:0]  m_axis_tdata,
    output wire [KEEP_WIDTH-1:0]  m_axis_tkeep,
    output wire                   m_axis_tvalid,
    input  wire                   m_axis_tready,
    output wire                   m_axis_tlast,
    output wire [ID_WIDTH-1:0]    m_axis_tid,
    output wire [DEST_WIDTH-1:0]  m_axis_tdest,
    output wire [USER_WIDTH-1:0]  m_axis_tuser,

    /*
     * Control
     */
    input  wire                   s_axis_cmd_csum_enable,
    input  wire [7:0]             s_axis_cmd_csum_start,
    input  wire [7:0]             s_axis_cmd_csum_offset,
    input  wire [15:0]            s_axis_cmd_csum_init,
    input  wire                   s_axis_cmd_valid,
    output wire                   s_axis_cmd_ready
);

parameter LEVELS = $clog2(DATA_WIDTH/8);

// bus width assertions
initial begin
    if (KEEP_WIDTH * 8 != DATA_WIDTH) begin
        $error("Error: AXI stream interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end
end

reg transfer_in_reg = 1'b0;

reg [15:0] csum_in_csum_reg = 0;
reg [7:0] csum_in_offset_reg = 0;
reg csum_in_enable_reg = 1'b0;
reg csum_in_valid_reg = 1'b0;
wire csum_in_ready;

wire [15:0] csum_out_csum;
wire [7:0] csum_out_offset;
wire csum_out_enable;
wire csum_out_valid;
reg csum_out_ready = 1'b0;

reg [KEEP_WIDTH-1:0] mask_reg = 0;
reg first_cycle_reg = 1'b0;
reg [7:0] input_offset_reg = 0;
reg [DATA_WIDTH-1:0] s_axis_tdata_masked;

reg frame_reg = 1'b0, frame_next;

reg [15:0] csum_reg = 16'd0, csum_next;
reg [7:0] csum_offset_reg = 8'd0, csum_offset_next;
reg csum_enable_reg = 1'b0, csum_enable_next;
reg csum_split_reg = 1'b0, csum_split_next;

reg [DATA_WIDTH-1:0] sum_reg[LEVELS-2:0];
reg [LEVELS-2:0] sum_valid_reg = 0;
reg [LEVELS-2:0] sum_odd_reg = 0;
reg [LEVELS-2:0] sum_last_reg = 0;
reg [LEVELS-2:0] sum_enable_reg = 0;
reg [7:0] sum_offset_reg[LEVELS-2:0];
reg [15:0] sum_init_reg[LEVELS-2:0];
reg [LEVELS-2:0] sum_init_valid_reg = 0;

reg [16+LEVELS-1:0] sum_acc_temp = 0;
reg [15:0] sum_acc_reg = 0;

// internal datapath
reg  [DATA_WIDTH-1:0] m_axis_tdata_int;
reg  [KEEP_WIDTH-1:0] m_axis_tkeep_int;
reg                   m_axis_tvalid_int;
reg                   m_axis_tready_int_reg = 1'b0;
reg                   m_axis_tlast_int;
reg  [ID_WIDTH-1:0]   m_axis_tid_int;
reg  [DEST_WIDTH-1:0] m_axis_tdest_int;
reg  [USER_WIDTH-1:0] m_axis_tuser_int;
wire                  m_axis_tready_int_early;

wire [DATA_WIDTH-1:0] data_in_axis_tdata;
wire [KEEP_WIDTH-1:0] data_in_axis_tkeep;
wire                  data_in_axis_tvalid;
wire                  data_in_axis_tready;
wire                  data_in_axis_tlast;
wire [ID_WIDTH-1:0]   data_in_axis_tid;
wire [DEST_WIDTH-1:0] data_in_axis_tdest;
wire [USER_WIDTH-1:0] data_in_axis_tuser;

wire [DATA_WIDTH-1:0] data_out_axis_tdata;
wire [KEEP_WIDTH-1:0] data_out_axis_tkeep;
wire                  data_out_axis_tvalid;
reg                   data_out_axis_tready;
wire                  data_out_axis_tlast;
wire [ID_WIDTH-1:0]   data_out_axis_tid;
wire [DEST_WIDTH-1:0] data_out_axis_tdest;
wire [USER_WIDTH-1:0] data_out_axis_tuser;

assign s_axis_tready = data_in_axis_tready && csum_in_ready && transfer_in_reg;

assign s_axis_cmd_ready = csum_in_ready && !transfer_in_reg;

// data FIFO
assign data_in_axis_tdata = s_axis_tdata;
assign data_in_axis_tkeep = s_axis_tkeep;
assign data_in_axis_tvalid = s_axis_tvalid && csum_in_ready && transfer_in_reg;
assign data_in_axis_tlast = s_axis_tlast;
assign data_in_axis_tid = s_axis_tid;
assign data_in_axis_tdest = s_axis_tdest;
assign data_in_axis_tuser = s_axis_tuser;

axis_fifo #(
    .DEPTH(DATA_FIFO_DEPTH),
    .DATA_WIDTH(DATA_WIDTH),
    .KEEP_ENABLE(1),
    .KEEP_WIDTH(KEEP_WIDTH),
    .LAST_ENABLE(1),
    .ID_ENABLE(ID_ENABLE),
    .ID_WIDTH(ID_WIDTH),
    .DEST_ENABLE(DEST_ENABLE),
    .DEST_WIDTH(DEST_WIDTH),
    .USER_ENABLE(USER_ENABLE),
    .USER_WIDTH(USER_WIDTH),
    .FRAME_FIFO(0)
)
data_fifo (
    .clk(clk),
    .rst(rst),
    // AXI input
    .s_axis_tdata(data_in_axis_tdata),
    .s_axis_tkeep(data_in_axis_tkeep),
    .s_axis_tvalid(data_in_axis_tvalid),
    .s_axis_tready(data_in_axis_tready),
    .s_axis_tlast(data_in_axis_tlast),
    .s_axis_tid(data_in_axis_tid),
    .s_axis_tdest(data_in_axis_tdest),
    .s_axis_tuser(data_in_axis_tuser),
    // AXI output
    .m_axis_tdata(data_out_axis_tdata),
    .m_axis_tkeep(data_out_axis_tkeep),
    .m_axis_tvalid(data_out_axis_tvalid),
    .m_axis_tready(data_out_axis_tready),
    .m_axis_tlast(data_out_axis_tlast),
    .m_axis_tid(data_out_axis_tid),
    .m_axis_tdest(data_out_axis_tdest),
    .m_axis_tuser(data_out_axis_tuser),
    // Status
    .status_overflow(),
    .status_bad_frame(),
    .status_good_frame()
);

// checksum FIFO
axis_fifo #(
    .DEPTH(CHECKSUM_FIFO_DEPTH),
    .DATA_WIDTH(16+8+1),
    .KEEP_ENABLE(0),
    .LAST_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(0),
    .FRAME_FIFO(0)
)
csum_fifo (
    .clk(clk),
    .rst(rst),
    // AXI input
    .s_axis_tdata({csum_in_csum_reg, csum_in_offset_reg, csum_in_enable_reg}),
    .s_axis_tkeep(0),
    .s_axis_tvalid(csum_in_valid_reg),
    .s_axis_tready(csum_in_ready),
    .s_axis_tlast(0),
    .s_axis_tid(0),
    .s_axis_tdest(0),
    .s_axis_tuser(0),
    // AXI output
    .m_axis_tdata({csum_out_csum, csum_out_offset, csum_out_enable}),
    .m_axis_tkeep(),
    .m_axis_tvalid(csum_out_valid),
    .m_axis_tready(csum_out_ready),
    .m_axis_tlast(),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(),
    // Status
    .status_overflow(),
    .status_bad_frame(),
    .status_good_frame()
);

// Mask input data
integer j;

always @* begin
    for (j = 0; j < KEEP_WIDTH; j = j + 1) begin
        s_axis_tdata_masked[j*8 +: 8] = (s_axis_tkeep[j] && mask_reg[j]) ? s_axis_tdata[j*8 +: 8] : 8'd0;
    end
end

// Compute checksum
integer i;

always @(posedge clk) begin
    sum_valid_reg[0] <= sum_valid_reg[0] && !csum_in_ready;

    if (s_axis_tvalid && s_axis_tready) begin
        for (i = 0; i < DATA_WIDTH/8/4; i = i + 1) begin
            sum_reg[0][i*17 +: 17] <= {s_axis_tdata_masked[(4*i+0)*8 +: 8], s_axis_tdata_masked[(4*i+1)*8 +: 8]} + {s_axis_tdata_masked[(4*i+2)*8 +: 8], s_axis_tdata_masked[(4*i+3)*8 +: 8]};
        end
        sum_valid_reg[0] <= 1'b1;
        sum_last_reg[0] <= s_axis_tlast;
        sum_init_valid_reg[0] <= first_cycle_reg;

        first_cycle_reg <= 1'b0;

        if (s_axis_tlast) begin
            transfer_in_reg <= 1'b0;
        end

        if (input_offset_reg > 0) begin
            if (input_offset_reg >= KEEP_WIDTH) begin
                mask_reg <= 0;
                input_offset_reg <= input_offset_reg - KEEP_WIDTH;
            end else begin
                mask_reg <= {KEEP_WIDTH{1'b1}} << input_offset_reg;
                input_offset_reg <= 0;
            end
        end else begin
            mask_reg <= {KEEP_WIDTH{1'b1}};
        end
    end

    if (s_axis_cmd_valid && s_axis_cmd_ready) begin
        transfer_in_reg <= 1'b1;
        sum_odd_reg[0] <= s_axis_cmd_csum_start[0];
        sum_enable_reg[0] <= s_axis_cmd_csum_enable;
        sum_offset_reg[0] <= s_axis_cmd_csum_offset;
        sum_init_reg[0] <= s_axis_cmd_csum_init;
        first_cycle_reg <= 1'b1;
        
        if (s_axis_cmd_csum_start >= KEEP_WIDTH) begin
            mask_reg <= 0;
            input_offset_reg <= s_axis_cmd_csum_start - KEEP_WIDTH;
        end else begin
            mask_reg <= {KEEP_WIDTH{1'b1}} << s_axis_cmd_csum_start;
            input_offset_reg <= 0;
        end
    end

    if (rst) begin
        transfer_in_reg <= 1'b0;
        sum_valid_reg[0] <= 1'b0;
    end
end

generate

    genvar l;

    for (l = 1; l < LEVELS-1; l = l + 1) begin

        always @(posedge clk) begin
            sum_valid_reg[l] <= sum_valid_reg[l] && !csum_in_ready;

            if (sum_valid_reg[l-1] && csum_in_ready) begin
                for (i = 0; i < DATA_WIDTH/8/4/2**l; i = i + 1) begin
                    sum_reg[l][i*(17+l) +: (17+l)] <= sum_reg[l-1][(i*2+0)*(17+l-1) +: (17+l-1)] + sum_reg[l-1][(i*2+1)*(17+l-1) +: (17+l-1)];
                end
                sum_valid_reg[l] <= 1'b1;
                sum_odd_reg[l] <= sum_odd_reg[l-1];
                sum_last_reg[l] <= sum_last_reg[l-1];
                sum_enable_reg[l] <= sum_enable_reg[l-1];
                sum_offset_reg[l] <= sum_offset_reg[l-1];
                sum_init_reg[l] <= sum_init_reg[l-1];
                sum_init_valid_reg[l] <= sum_init_valid_reg[l-1];
            end

            if (rst) begin
                sum_valid_reg[l] <= 1'b0;
            end
        end

    end

endgenerate

always @(posedge clk) begin
    csum_in_valid_reg <= 1'b0;

    if (sum_valid_reg[LEVELS-2] && csum_in_ready) begin
        sum_acc_temp = sum_reg[LEVELS-2][16+LEVELS-1-1:0] + (sum_init_valid_reg[LEVELS-2] && USE_INIT_VALUE ? sum_init_reg[LEVELS-2] : sum_acc_reg);
        sum_acc_temp = sum_acc_temp[15:0] + (sum_acc_temp >> 16);
        sum_acc_temp = sum_acc_temp[15:0] + sum_acc_temp[16];

        if (sum_last_reg[LEVELS-2]) begin
            if (sum_odd_reg[LEVELS-2]) begin
                csum_in_csum_reg[7:0] <= ~sum_acc_temp[15:8];
                csum_in_csum_reg[15:8] <= ~sum_acc_temp[7:0];
            end else begin
                csum_in_csum_reg[7:0] <= ~sum_acc_temp[7:0];
                csum_in_csum_reg[15:8] <= ~sum_acc_temp[15:8];
            end
            csum_in_offset_reg <= sum_offset_reg[LEVELS-2];
            csum_in_enable_reg <= sum_enable_reg[LEVELS-2];
            csum_in_valid_reg <= 1'b1;
            sum_acc_reg <= 0;
        end else begin
            sum_acc_reg <= sum_acc_temp;
        end
    end

    if (rst) begin
        csum_in_valid_reg <= 1'b0;
    end
end

// Insert checksum
always @* begin
    data_out_axis_tready = m_axis_tready_int_reg && frame_reg;
    csum_out_ready = 1'b0;

    frame_next = frame_reg;

    csum_next = csum_reg;
    csum_offset_next = csum_offset_reg;
    csum_enable_next = csum_enable_reg;
    csum_split_next = csum_split_reg;

    m_axis_tdata_int  = data_out_axis_tdata;
    m_axis_tkeep_int  = data_out_axis_tkeep;
    m_axis_tvalid_int = data_out_axis_tvalid && data_out_axis_tready;
    m_axis_tlast_int  = data_out_axis_tlast;
    m_axis_tid_int    = data_out_axis_tid;
    m_axis_tdest_int  = data_out_axis_tdest;
    m_axis_tuser_int  = data_out_axis_tuser;

    if (frame_reg) begin
        if (data_out_axis_tvalid && data_out_axis_tready) begin
            if (data_out_axis_tlast) begin
                frame_next = 1'b0;
            end

            if (csum_enable_reg) begin
                if (csum_offset_reg >= KEEP_WIDTH) begin
                    csum_offset_next = csum_offset_reg - KEEP_WIDTH;
                end else if (csum_split_reg) begin
                    // other byte of split checksum
                    m_axis_tdata_int[0 +: 8] = csum_reg[7:0];
                    csum_enable_next = 1'b0;
                end else if (csum_offset_reg == KEEP_WIDTH-1) begin
                    // split across two cycles
                    m_axis_tdata_int[DATA_WIDTH-8 +: 8] = csum_reg[15:8];
                    csum_split_next = 1'b1;
                end else begin
                    m_axis_tdata_int[csum_offset_reg*8 +: 8] = csum_reg[15:8];
                    m_axis_tdata_int[(csum_offset_reg+1)*8 +: 8] = csum_reg[7:0];

                    csum_enable_next = 1'b0;
                end
            end
        end
    end else begin
        csum_out_ready = 1'b1;
        csum_next = csum_out_csum;
        csum_offset_next = csum_out_offset;
        csum_enable_next = csum_out_enable;
        csum_split_next = 1'b0;
        if (csum_out_valid) begin
            frame_next = 1'b1;
        end
    end
end

always @(posedge clk) begin
    frame_reg <= frame_next;

    csum_reg <= csum_next;
    csum_offset_reg <= csum_offset_next;
    csum_enable_reg <= csum_enable_next;
    csum_split_reg <= csum_split_next;

    if (rst) begin
        frame_reg <= 1'b0;
        csum_enable_reg <= 1'b0;
    end
end

// output datapath logic
reg [DATA_WIDTH-1:0] m_axis_tdata_reg  = {DATA_WIDTH{1'b0}};
reg [KEEP_WIDTH-1:0] m_axis_tkeep_reg  = {KEEP_WIDTH{1'b0}};
reg                  m_axis_tvalid_reg = 1'b0, m_axis_tvalid_next;
reg                  m_axis_tlast_reg  = 1'b0;
reg [ID_WIDTH-1:0]   m_axis_tid_reg    = {ID_WIDTH{1'b0}};
reg [DEST_WIDTH-1:0] m_axis_tdest_reg  = {DEST_WIDTH{1'b0}};
reg [USER_WIDTH-1:0] m_axis_tuser_reg  = {USER_WIDTH{1'b0}};

reg [DATA_WIDTH-1:0] temp_m_axis_tdata_reg  = {DATA_WIDTH{1'b0}};
reg [KEEP_WIDTH-1:0] temp_m_axis_tkeep_reg  = {KEEP_WIDTH{1'b0}};
reg                  temp_m_axis_tvalid_reg = 1'b0, temp_m_axis_tvalid_next;
reg                  temp_m_axis_tlast_reg  = 1'b0;
reg [ID_WIDTH-1:0]   temp_m_axis_tid_reg    = {ID_WIDTH{1'b0}};
reg [DEST_WIDTH-1:0] temp_m_axis_tdest_reg  = {DEST_WIDTH{1'b0}};
reg [USER_WIDTH-1:0] temp_m_axis_tuser_reg  = {USER_WIDTH{1'b0}};

// datapath control
reg store_axis_int_to_output;
reg store_axis_int_to_temp;
reg store_axis_temp_to_output;

assign m_axis_tdata  = m_axis_tdata_reg;
assign m_axis_tkeep  = m_axis_tkeep_reg;
assign m_axis_tvalid = m_axis_tvalid_reg;
assign m_axis_tlast  = m_axis_tlast_reg;
assign m_axis_tid    = ID_ENABLE   ? m_axis_tid_reg   : {ID_WIDTH{1'b0}};
assign m_axis_tdest  = DEST_ENABLE ? m_axis_tdest_reg : {DEST_WIDTH{1'b0}};
assign m_axis_tuser  = USER_ENABLE ? m_axis_tuser_reg : {USER_WIDTH{1'b0}};

// enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
assign m_axis_tready_int_early = m_axis_tready || (!temp_m_axis_tvalid_reg && (!m_axis_tvalid_reg || !m_axis_tvalid_int));

always @* begin
    // transfer sink ready state to source
    m_axis_tvalid_next = m_axis_tvalid_reg;
    temp_m_axis_tvalid_next = temp_m_axis_tvalid_reg;

    store_axis_int_to_output = 1'b0;
    store_axis_int_to_temp = 1'b0;
    store_axis_temp_to_output = 1'b0;

    if (m_axis_tready_int_reg) begin
        // input is ready
        if (m_axis_tready || !m_axis_tvalid_reg) begin
            // output is ready or currently not valid, transfer data to output
            m_axis_tvalid_next = m_axis_tvalid_int;
            store_axis_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_m_axis_tvalid_next = m_axis_tvalid_int;
            store_axis_int_to_temp = 1'b1;
        end
    end else if (m_axis_tready) begin
        // input is not ready, but output is ready
        m_axis_tvalid_next = temp_m_axis_tvalid_reg;
        temp_m_axis_tvalid_next = 1'b0;
        store_axis_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    if (rst) begin
        m_axis_tvalid_reg <= 1'b0;
        m_axis_tready_int_reg <= 1'b0;
        temp_m_axis_tvalid_reg <= 1'b0;
    end else begin
        m_axis_tvalid_reg <= m_axis_tvalid_next;
        m_axis_tready_int_reg <= m_axis_tready_int_early;
        temp_m_axis_tvalid_reg <= temp_m_axis_tvalid_next;
    end

    // datapath
    if (store_axis_int_to_output) begin
        m_axis_tdata_reg <= m_axis_tdata_int;
        m_axis_tkeep_reg <= m_axis_tkeep_int;
        m_axis_tlast_reg <= m_axis_tlast_int;
        m_axis_tid_reg   <= m_axis_tid_int;
        m_axis_tdest_reg <= m_axis_tdest_int;
        m_axis_tuser_reg <= m_axis_tuser_int;
    end else if (store_axis_temp_to_output) begin
        m_axis_tdata_reg <= temp_m_axis_tdata_reg;
        m_axis_tkeep_reg <= temp_m_axis_tkeep_reg;
        m_axis_tlast_reg <= temp_m_axis_tlast_reg;
        m_axis_tid_reg   <= temp_m_axis_tid_reg;
        m_axis_tdest_reg <= temp_m_axis_tdest_reg;
        m_axis_tuser_reg <= temp_m_axis_tuser_reg;
    end

    if (store_axis_int_to_temp) begin
        temp_m_axis_tdata_reg <= m_axis_tdata_int;
        temp_m_axis_tkeep_reg <= m_axis_tkeep_int;
        temp_m_axis_tlast_reg <= m_axis_tlast_int;
        temp_m_axis_tid_reg   <= m_axis_tid_int;
        temp_m_axis_tdest_reg <= m_axis_tdest_int;
        temp_m_axis_tuser_reg <= m_axis_tuser_int;
    end
end

endmodule

`resetall
