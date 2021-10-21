/*

Copyright (c) 2018 Alex Forencich

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
 * Ultrascale PCIe CQ demultiplexer
 */
module pcie_us_axis_cq_demux #
(
    // Output count
    parameter M_COUNT = 2,
    // Width of PCIe AXI stream interfaces in bits
    parameter AXIS_PCIE_DATA_WIDTH = 256,
    // PCIe AXI stream tkeep signal width (words per cycle)
    parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32),
    // PCIe AXI stream CQ tuser signal width
    parameter AXIS_PCIE_CQ_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 85 : 183
)
(
    input  wire                                       clk,
    input  wire                                       rst,

    /*
     * AXI input (CQ)
     */
    input  wire [AXIS_PCIE_DATA_WIDTH-1:0]            s_axis_cq_tdata,
    input  wire [AXIS_PCIE_KEEP_WIDTH-1:0]            s_axis_cq_tkeep,
    input  wire                                       s_axis_cq_tvalid,
    output wire                                       s_axis_cq_tready,
    input  wire                                       s_axis_cq_tlast,
    input  wire [AXIS_PCIE_CQ_USER_WIDTH-1:0]         s_axis_cq_tuser,

    /*
     * AXI output (CQ)
     */
    output wire [M_COUNT*AXIS_PCIE_DATA_WIDTH-1:0]    m_axis_cq_tdata,
    output wire [M_COUNT*AXIS_PCIE_KEEP_WIDTH-1:0]    m_axis_cq_tkeep,
    output wire [M_COUNT-1:0]                         m_axis_cq_tvalid,
    input  wire [M_COUNT-1:0]                         m_axis_cq_tready,
    output wire [M_COUNT-1:0]                         m_axis_cq_tlast,
    output wire [M_COUNT*AXIS_PCIE_CQ_USER_WIDTH-1:0] m_axis_cq_tuser,

    /*
     * Fields
     */
    output wire [3:0]                                 req_type,
    output wire [7:0]                                 target_function,
    output wire [2:0]                                 bar_id,
    output wire [7:0]                                 msg_code,
    output wire [2:0]                                 msg_routing,

    /*
     * Control
     */
    input  wire                                       enable,
    input  wire                                       drop,
    input  wire [M_COUNT-1:0]                         select
);

parameter CL_M_COUNT = $clog2(M_COUNT);

// bus width assertions
initial begin
    if (AXIS_PCIE_DATA_WIDTH != 64 && AXIS_PCIE_DATA_WIDTH != 128 && AXIS_PCIE_DATA_WIDTH != 256 && AXIS_PCIE_DATA_WIDTH != 512) begin
        $error("Error: PCIe interface width must be 64, 128, 256, or 512 (instance %m)");
        $finish;
    end

    if (AXIS_PCIE_KEEP_WIDTH * 32 != AXIS_PCIE_DATA_WIDTH) begin
        $error("Error: PCIe interface requires dword (32-bit) granularity (instance %m)");
        $finish;
    end
end

reg [CL_M_COUNT-1:0] select_reg = {CL_M_COUNT{1'b0}}, select_ctl, select_next;
reg drop_reg = 1'b0, drop_ctl, drop_next;
reg frame_reg = 1'b0, frame_ctl, frame_next;

reg s_axis_cq_tready_reg = 1'b0, s_axis_cq_tready_next;

reg [AXIS_PCIE_DATA_WIDTH-1:0]    temp_s_axis_cq_tdata_reg = {AXIS_PCIE_DATA_WIDTH{1'b0}};
reg [AXIS_PCIE_KEEP_WIDTH-1:0]    temp_s_axis_cq_tkeep_reg = {AXIS_PCIE_KEEP_WIDTH{1'b0}};
reg                               temp_s_axis_cq_tvalid_reg = 1'b0;
reg                               temp_s_axis_cq_tlast_reg = 1'b0;
reg [AXIS_PCIE_CQ_USER_WIDTH-1:0] temp_s_axis_cq_tuser_reg = {AXIS_PCIE_CQ_USER_WIDTH{1'b0}};

// internal datapath
reg  [AXIS_PCIE_DATA_WIDTH-1:0]    m_axis_cq_tdata_int;
reg  [AXIS_PCIE_KEEP_WIDTH-1:0]    m_axis_cq_tkeep_int;
reg  [M_COUNT-1:0]                 m_axis_cq_tvalid_int;
reg                                m_axis_cq_tready_int_reg = 1'b0;
reg                                m_axis_cq_tlast_int;
reg  [AXIS_PCIE_CQ_USER_WIDTH-1:0] m_axis_cq_tuser_int;
wire                               m_axis_cq_tready_int_early;

assign s_axis_cq_tready = (s_axis_cq_tready_reg || (AXIS_PCIE_DATA_WIDTH == 64 && !temp_s_axis_cq_tvalid_reg)) && enable;

assign req_type =        AXIS_PCIE_DATA_WIDTH > 64 ? s_axis_cq_tdata[78:75]   : s_axis_cq_tdata[14:11];
assign target_function = AXIS_PCIE_DATA_WIDTH > 64 ? s_axis_cq_tdata[111:104] : s_axis_cq_tdata[47:40];
assign bar_id =          AXIS_PCIE_DATA_WIDTH > 64 ? s_axis_cq_tdata[114:112] : s_axis_cq_tdata[50:48];
assign msg_code =        AXIS_PCIE_DATA_WIDTH > 64 ? s_axis_cq_tdata[111:104] : s_axis_cq_tdata[47:40];
assign msg_routing =     AXIS_PCIE_DATA_WIDTH > 64 ? s_axis_cq_tdata[114:112] : s_axis_cq_tdata[50:48];

integer i;

always @* begin
    select_next = select_reg;
    select_ctl = select_reg;
    drop_next = drop_reg;
    drop_ctl = drop_reg;
    frame_next = frame_reg;
    frame_ctl = frame_reg;

    s_axis_cq_tready_next = 1'b0;

    if (AXIS_PCIE_DATA_WIDTH == 64) begin
        if (temp_s_axis_cq_tvalid_reg && s_axis_cq_tready) begin
            // end of frame detection
            if (temp_s_axis_cq_tlast_reg) begin
                frame_next = 1'b0;
                drop_next = 1'b0;
            end
        end
    end else begin
        if (s_axis_cq_tvalid && s_axis_cq_tready) begin
            // end of frame detection
            if (s_axis_cq_tlast) begin
                frame_next = 1'b0;
                drop_next = 1'b0;
            end
        end
    end

    if (!frame_reg && (AXIS_PCIE_DATA_WIDTH != 64 || temp_s_axis_cq_tvalid_reg) && s_axis_cq_tvalid && s_axis_cq_tready) begin
        // start of frame, grab select value
        select_ctl = 0;
        drop_ctl = 1'b1;
        frame_ctl = 1'b1;
        for (i = M_COUNT-1; i >= 0; i = i - 1) begin
            if (select[i]) begin
                select_ctl = i;
                drop_ctl = 1'b0;
            end
        end
        drop_ctl = drop_ctl || drop;
        if (AXIS_PCIE_DATA_WIDTH == 64) begin
            if (!(s_axis_cq_tready && temp_s_axis_cq_tvalid_reg && temp_s_axis_cq_tlast_reg)) begin
                select_next = select_ctl;
                drop_next = drop_ctl;
                frame_next = 1'b1;
            end
        end else begin
            if (!(s_axis_cq_tready && s_axis_cq_tvalid && s_axis_cq_tlast)) begin
                select_next = select_ctl;
                drop_next = drop_ctl;
                frame_next = 1'b1;
            end
        end
    end

    s_axis_cq_tready_next = m_axis_cq_tready_int_early || drop_ctl;

    if (AXIS_PCIE_DATA_WIDTH == 64) begin
        m_axis_cq_tdata_int  = temp_s_axis_cq_tdata_reg;
        m_axis_cq_tkeep_int  = temp_s_axis_cq_tkeep_reg;
        m_axis_cq_tvalid_int = (temp_s_axis_cq_tvalid_reg && s_axis_cq_tready && !drop_ctl && frame_ctl) << select_ctl;
        m_axis_cq_tlast_int  = temp_s_axis_cq_tlast_reg;
        m_axis_cq_tuser_int  = temp_s_axis_cq_tuser_reg; 
    end else begin
        m_axis_cq_tdata_int  = s_axis_cq_tdata;
        m_axis_cq_tkeep_int  = s_axis_cq_tkeep;
        m_axis_cq_tvalid_int = (s_axis_cq_tvalid && s_axis_cq_tready && !drop_ctl && frame_ctl) << select_ctl;
        m_axis_cq_tlast_int  = s_axis_cq_tlast;
        m_axis_cq_tuser_int  = s_axis_cq_tuser; 
    end
end

always @(posedge clk) begin
    if (rst) begin
        select_reg <= 2'd0;
        drop_reg <= 1'b0;
        frame_reg <= 1'b0;
        s_axis_cq_tready_reg <= 1'b0;
    end else begin
        select_reg <= select_next;
        drop_reg <= drop_next;
        frame_reg <= frame_next;
        s_axis_cq_tready_reg <= s_axis_cq_tready_next;
    end

    if (AXIS_PCIE_DATA_WIDTH == 64) begin
        temp_s_axis_cq_tvalid_reg <= temp_s_axis_cq_tvalid_reg && !(s_axis_cq_tready && !drop_ctl && frame_ctl);

        if (s_axis_cq_tready && s_axis_cq_tvalid) begin
            temp_s_axis_cq_tdata_reg <= s_axis_cq_tdata;
            temp_s_axis_cq_tkeep_reg <= s_axis_cq_tkeep;
            temp_s_axis_cq_tvalid_reg <= 1'b1;
            temp_s_axis_cq_tlast_reg <= s_axis_cq_tlast;
            temp_s_axis_cq_tuser_reg <= s_axis_cq_tuser;
        end
    end
end

// output datapath logic
reg [AXIS_PCIE_DATA_WIDTH-1:0]    m_axis_cq_tdata_reg  = {AXIS_PCIE_DATA_WIDTH{1'b0}};
reg [AXIS_PCIE_KEEP_WIDTH-1:0]    m_axis_cq_tkeep_reg  = {AXIS_PCIE_KEEP_WIDTH{1'b0}};
reg [M_COUNT-1:0]                 m_axis_cq_tvalid_reg = {M_COUNT{1'b0}}, m_axis_cq_tvalid_next;
reg                               m_axis_cq_tlast_reg  = 1'b0;
reg [AXIS_PCIE_CQ_USER_WIDTH-1:0] m_axis_cq_tuser_reg  = {AXIS_PCIE_CQ_USER_WIDTH{1'b0}};

reg [AXIS_PCIE_DATA_WIDTH-1:0]    temp_m_axis_cq_tdata_reg  = {AXIS_PCIE_DATA_WIDTH{1'b0}};
reg [AXIS_PCIE_KEEP_WIDTH-1:0]    temp_m_axis_cq_tkeep_reg  = {AXIS_PCIE_KEEP_WIDTH{1'b0}};
reg [M_COUNT-1:0]                 temp_m_axis_cq_tvalid_reg = {M_COUNT{1'b0}}, temp_m_axis_cq_tvalid_next;
reg                               temp_m_axis_cq_tlast_reg  = 1'b0;
reg [AXIS_PCIE_CQ_USER_WIDTH-1:0] temp_m_axis_cq_tuser_reg  = {AXIS_PCIE_CQ_USER_WIDTH{1'b0}};

// datapath control
reg store_axis_int_to_output;
reg store_axis_int_to_temp;
reg store_axis_cq_temp_to_output;

assign m_axis_cq_tdata  = {M_COUNT{m_axis_cq_tdata_reg}};
assign m_axis_cq_tkeep  = {M_COUNT{m_axis_cq_tkeep_reg}};
assign m_axis_cq_tvalid = m_axis_cq_tvalid_reg;
assign m_axis_cq_tlast  = {M_COUNT{m_axis_cq_tlast_reg}};
assign m_axis_cq_tuser  = {M_COUNT{m_axis_cq_tuser_reg}};

// enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
assign m_axis_cq_tready_int_early = (m_axis_cq_tready & m_axis_cq_tvalid) || (!temp_m_axis_cq_tvalid_reg && (!m_axis_cq_tvalid || !m_axis_cq_tvalid_int));

always @* begin
    // transfer sink ready state to source
    m_axis_cq_tvalid_next = m_axis_cq_tvalid_reg;
    temp_m_axis_cq_tvalid_next = temp_m_axis_cq_tvalid_reg;

    store_axis_int_to_output = 1'b0;
    store_axis_int_to_temp = 1'b0;
    store_axis_cq_temp_to_output = 1'b0;

    if (m_axis_cq_tready_int_reg) begin
        // input is ready
        if ((m_axis_cq_tready & m_axis_cq_tvalid) || !m_axis_cq_tvalid) begin
            // output is ready or currently not valid, transfer data to output
            m_axis_cq_tvalid_next = m_axis_cq_tvalid_int;
            store_axis_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_m_axis_cq_tvalid_next = m_axis_cq_tvalid_int;
            store_axis_int_to_temp = 1'b1;
        end
    end else if (m_axis_cq_tready & m_axis_cq_tvalid) begin
        // input is not ready, but output is ready
        m_axis_cq_tvalid_next = temp_m_axis_cq_tvalid_reg;
        temp_m_axis_cq_tvalid_next = 1'b0;
        store_axis_cq_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    if (rst) begin
        m_axis_cq_tvalid_reg <= {M_COUNT{1'b0}};
        m_axis_cq_tready_int_reg <= 1'b0;
        temp_m_axis_cq_tvalid_reg <= 1'b0;
    end else begin
        m_axis_cq_tvalid_reg <= m_axis_cq_tvalid_next;
        m_axis_cq_tready_int_reg <= m_axis_cq_tready_int_early;
        temp_m_axis_cq_tvalid_reg <= temp_m_axis_cq_tvalid_next;
    end

    // datapath
    if (store_axis_int_to_output) begin
        m_axis_cq_tdata_reg <= m_axis_cq_tdata_int;
        m_axis_cq_tkeep_reg <= m_axis_cq_tkeep_int;
        m_axis_cq_tlast_reg <= m_axis_cq_tlast_int;
        m_axis_cq_tuser_reg <= m_axis_cq_tuser_int;
    end else if (store_axis_cq_temp_to_output) begin
        m_axis_cq_tdata_reg <= temp_m_axis_cq_tdata_reg;
        m_axis_cq_tkeep_reg <= temp_m_axis_cq_tkeep_reg;
        m_axis_cq_tlast_reg <= temp_m_axis_cq_tlast_reg;
        m_axis_cq_tuser_reg <= temp_m_axis_cq_tuser_reg;
    end

    if (store_axis_int_to_temp) begin
        temp_m_axis_cq_tdata_reg <= m_axis_cq_tdata_int;
        temp_m_axis_cq_tkeep_reg <= m_axis_cq_tkeep_int;
        temp_m_axis_cq_tlast_reg <= m_axis_cq_tlast_int;
        temp_m_axis_cq_tuser_reg <= m_axis_cq_tuser_int;
    end
end

endmodule

`resetall
