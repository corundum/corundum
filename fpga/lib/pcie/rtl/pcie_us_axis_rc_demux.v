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
 * Ultrascale PCIe RC demultiplexer
 */
module pcie_us_axis_rc_demux #
(
    // Output count
    parameter M_COUNT = 2,
    // Width of PCIe AXI stream interfaces in bits
    parameter AXIS_PCIE_DATA_WIDTH = 256,
    // PCIe AXI stream tkeep signal width (words per cycle)
    parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32),
    // PCIe AXI stream RC tuser signal width
    parameter AXIS_PCIE_RC_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 75 : 161
)
(
    input  wire                                       clk,
    input  wire                                       rst,

    /*
     * AXI input (RC)
     */
    input  wire [AXIS_PCIE_DATA_WIDTH-1:0]            s_axis_rc_tdata,
    input  wire [AXIS_PCIE_KEEP_WIDTH-1:0]            s_axis_rc_tkeep,
    input  wire                                       s_axis_rc_tvalid,
    output wire                                       s_axis_rc_tready,
    input  wire                                       s_axis_rc_tlast,
    input  wire [AXIS_PCIE_RC_USER_WIDTH-1:0]         s_axis_rc_tuser,

    /*
     * AXI output (RC)
     */
    output wire [M_COUNT*AXIS_PCIE_DATA_WIDTH-1:0]    m_axis_rc_tdata,
    output wire [M_COUNT*AXIS_PCIE_KEEP_WIDTH-1:0]    m_axis_rc_tkeep,
    output wire [M_COUNT-1:0]                         m_axis_rc_tvalid,
    input  wire [M_COUNT-1:0]                         m_axis_rc_tready,
    output wire [M_COUNT-1:0]                         m_axis_rc_tlast,
    output wire [M_COUNT*AXIS_PCIE_RC_USER_WIDTH-1:0] m_axis_rc_tuser,

    /*
     * Fields
     */
    output wire [15:0]                                requester_id,

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

reg s_axis_rc_tready_reg = 1'b0, s_axis_rc_tready_next;

// internal datapath
reg  [AXIS_PCIE_DATA_WIDTH-1:0]    m_axis_rc_tdata_int;
reg  [AXIS_PCIE_KEEP_WIDTH-1:0]    m_axis_rc_tkeep_int;
reg  [M_COUNT-1:0]                 m_axis_rc_tvalid_int;
reg                                m_axis_rc_tready_int_reg = 1'b0;
reg                                m_axis_rc_tlast_int;
reg  [AXIS_PCIE_RC_USER_WIDTH-1:0] m_axis_rc_tuser_int;
wire                               m_axis_rc_tready_int_early;

assign s_axis_rc_tready = s_axis_rc_tready_reg && enable;

assign requester_id = s_axis_rc_tdata[63:48];

integer i;

always @* begin
    select_next = select_reg;
    select_ctl = select_reg;
    drop_next = drop_reg;
    drop_ctl = drop_reg;
    frame_next = frame_reg;
    frame_ctl = frame_reg;

    s_axis_rc_tready_next = 1'b0;

    if (s_axis_rc_tvalid && s_axis_rc_tready) begin
        // end of frame detection
        if (s_axis_rc_tlast) begin
            frame_next = 1'b0;
            drop_next = 1'b0;
        end
    end

    if (!frame_reg && s_axis_rc_tvalid && s_axis_rc_tready) begin
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
        if (!(s_axis_rc_tready && s_axis_rc_tvalid && s_axis_rc_tlast)) begin
            select_next = select_ctl;
            drop_next = drop_ctl;
            frame_next = 1'b1;
        end
    end

    s_axis_rc_tready_next = m_axis_rc_tready_int_early || drop_ctl;

    m_axis_rc_tdata_int  = s_axis_rc_tdata;
    m_axis_rc_tkeep_int  = s_axis_rc_tkeep;
    m_axis_rc_tvalid_int = (s_axis_rc_tvalid && s_axis_rc_tready && !drop_ctl) << select_ctl;
    m_axis_rc_tlast_int  = s_axis_rc_tlast;
    m_axis_rc_tuser_int  = s_axis_rc_tuser; 
end

always @(posedge clk) begin
    if (rst) begin
        select_reg <= 2'd0;
        drop_reg <= 1'b0;
        frame_reg <= 1'b0;
        s_axis_rc_tready_reg <= 1'b0;
    end else begin
        select_reg <= select_next;
        drop_reg <= drop_next;
        frame_reg <= frame_next;
        s_axis_rc_tready_reg <= s_axis_rc_tready_next;
    end
end

// output datapath logic
reg [AXIS_PCIE_DATA_WIDTH-1:0]    m_axis_rc_tdata_reg  = {AXIS_PCIE_DATA_WIDTH{1'b0}};
reg [AXIS_PCIE_KEEP_WIDTH-1:0]    m_axis_rc_tkeep_reg  = {AXIS_PCIE_KEEP_WIDTH{1'b0}};
reg [M_COUNT-1:0]                 m_axis_rc_tvalid_reg = {M_COUNT{1'b0}}, m_axis_rc_tvalid_next;
reg                               m_axis_rc_tlast_reg  = 1'b0;
reg [AXIS_PCIE_RC_USER_WIDTH-1:0] m_axis_rc_tuser_reg  = {AXIS_PCIE_RC_USER_WIDTH{1'b0}};

reg [AXIS_PCIE_DATA_WIDTH-1:0]    temp_m_axis_rc_tdata_reg  = {AXIS_PCIE_DATA_WIDTH{1'b0}};
reg [AXIS_PCIE_KEEP_WIDTH-1:0]    temp_m_axis_rc_tkeep_reg  = {AXIS_PCIE_KEEP_WIDTH{1'b0}};
reg [M_COUNT-1:0]                 temp_m_axis_rc_tvalid_reg = {M_COUNT{1'b0}}, temp_m_axis_rc_tvalid_next;
reg                               temp_m_axis_rc_tlast_reg  = 1'b0;
reg [AXIS_PCIE_RC_USER_WIDTH-1:0] temp_m_axis_rc_tuser_reg  = {AXIS_PCIE_RC_USER_WIDTH{1'b0}};

// datapath control
reg store_axis_int_to_output;
reg store_axis_int_to_temp;
reg store_axis_rc_temp_to_output;

assign m_axis_rc_tdata  = {M_COUNT{m_axis_rc_tdata_reg}};
assign m_axis_rc_tkeep  = {M_COUNT{m_axis_rc_tkeep_reg}};
assign m_axis_rc_tvalid = m_axis_rc_tvalid_reg;
assign m_axis_rc_tlast  = {M_COUNT{m_axis_rc_tlast_reg}};
assign m_axis_rc_tuser  = {M_COUNT{m_axis_rc_tuser_reg}};

// enable ready input next cycle if output is ready or if both output registers are empty
assign m_axis_rc_tready_int_early = (m_axis_rc_tready & m_axis_rc_tvalid) || (!temp_m_axis_rc_tvalid_reg && !m_axis_rc_tvalid_reg);

always @* begin
    // transfer sink ready state to source
    m_axis_rc_tvalid_next = m_axis_rc_tvalid_reg;
    temp_m_axis_rc_tvalid_next = temp_m_axis_rc_tvalid_reg;

    store_axis_int_to_output = 1'b0;
    store_axis_int_to_temp = 1'b0;
    store_axis_rc_temp_to_output = 1'b0;

    if (m_axis_rc_tready_int_reg) begin
        // input is ready
        if ((m_axis_rc_tready & m_axis_rc_tvalid) || !m_axis_rc_tvalid) begin
            // output is ready or currently not valid, transfer data to output
            m_axis_rc_tvalid_next = m_axis_rc_tvalid_int;
            store_axis_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_m_axis_rc_tvalid_next = m_axis_rc_tvalid_int;
            store_axis_int_to_temp = 1'b1;
        end
    end else if (m_axis_rc_tready & m_axis_rc_tvalid) begin
        // input is not ready, but output is ready
        m_axis_rc_tvalid_next = temp_m_axis_rc_tvalid_reg;
        temp_m_axis_rc_tvalid_next = 1'b0;
        store_axis_rc_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    m_axis_rc_tvalid_reg <= m_axis_rc_tvalid_next;
    m_axis_rc_tready_int_reg <= m_axis_rc_tready_int_early;
    temp_m_axis_rc_tvalid_reg <= temp_m_axis_rc_tvalid_next;

    // datapath
    if (store_axis_int_to_output) begin
        m_axis_rc_tdata_reg <= m_axis_rc_tdata_int;
        m_axis_rc_tkeep_reg <= m_axis_rc_tkeep_int;
        m_axis_rc_tlast_reg <= m_axis_rc_tlast_int;
        m_axis_rc_tuser_reg <= m_axis_rc_tuser_int;
    end else if (store_axis_rc_temp_to_output) begin
        m_axis_rc_tdata_reg <= temp_m_axis_rc_tdata_reg;
        m_axis_rc_tkeep_reg <= temp_m_axis_rc_tkeep_reg;
        m_axis_rc_tlast_reg <= temp_m_axis_rc_tlast_reg;
        m_axis_rc_tuser_reg <= temp_m_axis_rc_tuser_reg;
    end

    if (store_axis_int_to_temp) begin
        temp_m_axis_rc_tdata_reg <= m_axis_rc_tdata_int;
        temp_m_axis_rc_tkeep_reg <= m_axis_rc_tkeep_int;
        temp_m_axis_rc_tlast_reg <= m_axis_rc_tlast_int;
        temp_m_axis_rc_tuser_reg <= m_axis_rc_tuser_int;
    end

    if (rst) begin
        m_axis_rc_tvalid_reg <= {M_COUNT{1'b0}};
        m_axis_rc_tready_int_reg <= 1'b0;
        temp_m_axis_rc_tvalid_reg <= 1'b0;
    end
end

endmodule

`resetall
