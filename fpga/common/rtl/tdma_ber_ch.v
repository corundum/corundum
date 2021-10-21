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
 * TDMA BER module
 */
module tdma_ber_ch #
(
    // Timeslot index width
    parameter INDEX_WIDTH = 6,
    // Slice index width
    parameter SLICE_WIDTH = 5,
    // Width of AXI lite data bus in bits
    parameter AXIL_DATA_WIDTH = 32,
    // Width of AXI lite address bus in bits
    parameter AXIL_ADDR_WIDTH = INDEX_WIDTH+4,
    // Width of AXI lite wstrb (width of data bus in words)
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8)
)
(
    input  wire                        clk,
    input  wire                        rst,

    /*
     * PHY connections
     */
    input  wire                        phy_tx_clk,
    input  wire                        phy_rx_clk,
    input  wire [6:0]                  phy_rx_error_count,
    output wire                        phy_tx_prbs31_enable,
    output wire                        phy_rx_prbs31_enable,

    /*
     * AXI-Lite slave interface
     */
    input  wire [AXIL_ADDR_WIDTH-1:0]  s_axil_awaddr,
    input  wire [2:0]                  s_axil_awprot,
    input  wire                        s_axil_awvalid,
    output wire                        s_axil_awready,
    input  wire [AXIL_DATA_WIDTH-1:0]  s_axil_wdata,
    input  wire [AXIL_STRB_WIDTH-1:0]  s_axil_wstrb,
    input  wire                        s_axil_wvalid,
    output wire                        s_axil_wready,
    output wire [1:0]                  s_axil_bresp,
    output wire                        s_axil_bvalid,
    input  wire                        s_axil_bready,
    input  wire [AXIL_ADDR_WIDTH-1:0]  s_axil_araddr,
    input  wire [2:0]                  s_axil_arprot,
    input  wire                        s_axil_arvalid,
    output wire                        s_axil_arready,
    output wire [AXIL_DATA_WIDTH-1:0]  s_axil_rdata,
    output wire [1:0]                  s_axil_rresp,
    output wire                        s_axil_rvalid,
    input  wire                        s_axil_rready,

    /*
     * TDMA schedule
     */
    input  wire [INDEX_WIDTH-1:0]      tdma_timeslot_index,
    input  wire                        tdma_timeslot_start,
    input  wire                        tdma_timeslot_active
);

parameter VALID_ADDR_WIDTH = AXIL_ADDR_WIDTH - $clog2(AXIL_STRB_WIDTH);
parameter WORD_WIDTH = AXIL_STRB_WIDTH;
parameter WORD_SIZE = AXIL_DATA_WIDTH/WORD_WIDTH;

// check configuration
initial begin
    if (AXIL_ADDR_WIDTH < INDEX_WIDTH+4) begin
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

reg tx_prbs31_enable_reg = 1'b0, tx_prbs31_enable_next;
reg rx_prbs31_enable_reg = 1'b0, rx_prbs31_enable_next;

// PHY TX BER interface
reg phy_tx_prbs31_enable_reg = 1'b0;

always @(posedge phy_tx_clk) begin
    phy_tx_prbs31_enable_reg <= tx_prbs31_enable_reg;
end

assign phy_tx_prbs31_enable = phy_tx_prbs31_enable_reg;

// PHY RX BER interface
reg phy_rx_prbs31_enable_reg = 1'b0;

// accumulate errors, dump every 16 cycles
reg [10:0] phy_rx_error_count_reg = 0;
reg [10:0] phy_rx_error_count_acc_reg = 0;
reg [3:0] phy_rx_count_reg = 4'd0;
reg phy_rx_flag_reg = 1'b0;

always @(posedge phy_rx_clk) begin
    phy_rx_prbs31_enable_reg <= rx_prbs31_enable_reg;

    phy_rx_count_reg <= phy_rx_count_reg + 1;

    if (phy_rx_count_reg == 0) begin
        phy_rx_error_count_reg <= phy_rx_error_count_acc_reg;
        phy_rx_error_count_acc_reg <= phy_rx_error_count;
        phy_rx_flag_reg <= !phy_rx_flag_reg;
    end else begin
        phy_rx_error_count_acc_reg <= phy_rx_error_count_acc_reg + phy_rx_error_count;
    end
end

assign phy_rx_prbs31_enable = phy_rx_prbs31_enable_reg;

// synchronize dumped counts to control clock domain
reg rx_flag_sync_reg_1 = 1'b0;
reg rx_flag_sync_reg_2 = 1'b0;
reg rx_flag_sync_reg_3 = 1'b0;

always @(posedge clk) begin
    rx_flag_sync_reg_1 <= phy_rx_flag_reg;
    rx_flag_sync_reg_2 <= rx_flag_sync_reg_1;
    rx_flag_sync_reg_3 <= rx_flag_sync_reg_2;
end

reg [31:0] cycle_count_reg = 32'd0, cycle_count_next;
reg [31:0] update_count_reg = 32'd0, update_count_next;
reg [31:0] rx_error_count_reg = 32'd0, rx_error_count_next;

reg [31:0] atomic_cycle_count_reg = 32'd0, atomic_cycle_count_next;
reg [31:0] atomic_update_count_reg = 32'd0, atomic_update_count_next;
reg [31:0] atomic_rx_error_count_reg = 32'd0, atomic_rx_error_count_next;

reg accumulate_enable_reg = 1'b0, accumulate_enable_next;
reg slice_enable_reg = 1'b0, slice_enable_next;

reg [31:0] slice_time_reg = 0, slice_time_next;
reg [31:0] slice_offset_reg = 0, slice_offset_next;

reg [SLICE_WIDTH-1:0] slice_select_reg = 0, slice_select_next;

reg error_count_mem_read_reg = 0;
reg [31:0] error_count_mem_read_data_reg = 0;
reg update_count_mem_read_reg = 0;
reg [31:0] update_count_mem_read_data_reg = 0;

reg [31:0] error_count_mem[(2**(INDEX_WIDTH+SLICE_WIDTH))-1:0];
reg [31:0] update_count_mem[(2**(INDEX_WIDTH+SLICE_WIDTH))-1:0];

integer i;

initial begin
    for (i = 0; i < 2**(INDEX_WIDTH+SLICE_WIDTH); i = i + 1) begin
        error_count_mem[i] = 0;
        update_count_mem[i] = 0;
    end
end

reg [10:0] phy_rx_error_count_sync_reg = 0;
reg phy_rx_error_count_sync_valid_reg = 1'b0;

always @(posedge clk) begin
    phy_rx_error_count_sync_valid_reg <= 1'b0;
    if (rx_flag_sync_reg_2 ^ rx_flag_sync_reg_3) begin
        phy_rx_error_count_sync_reg <= phy_rx_error_count_reg;
        phy_rx_error_count_sync_valid_reg <= 1'b1;
    end
end

reg slice_running_reg = 1'b0;
reg slice_active_reg = 1'b0;
reg [31:0] slice_count_reg = 0;
reg [SLICE_WIDTH-1:0] cur_slice_reg = 0;

reg [1:0] accumulate_state_reg = 0;
reg [31:0] rx_ts_update_count_read_reg = 0;
reg [31:0] rx_ts_error_count_read_reg = 0;
reg [31:0] rx_ts_update_count_reg = 0;
reg [31:0] rx_ts_error_count_reg = 0;
reg [INDEX_WIDTH+SLICE_WIDTH-1:0] index_reg = 0;

always @(posedge clk) begin
    if (tdma_timeslot_start) begin
        slice_running_reg <= 1'b1;
        if (slice_offset_reg) begin
            slice_active_reg <= 1'b0;
            slice_count_reg <= slice_offset_reg;
        end else begin
            slice_active_reg <= 1'b1;
            slice_count_reg <= slice_time_reg;
        end
        cur_slice_reg <= 0;
    end else if (slice_count_reg > 0) begin
        slice_count_reg <= slice_count_reg - 1;
    end else begin
        slice_count_reg <= slice_time_reg;
        slice_active_reg <= slice_running_reg;
        if (slice_active_reg && slice_running_reg) begin
            cur_slice_reg <= cur_slice_reg + 1;
            slice_running_reg <= cur_slice_reg < {SLICE_WIDTH{1'b1}};
            slice_active_reg <= cur_slice_reg < {SLICE_WIDTH{1'b1}};
        end
    end

    case (accumulate_state_reg)
        2'd0: begin
            if (accumulate_enable_reg && tdma_timeslot_active && phy_rx_error_count_sync_valid_reg) begin
                if (slice_enable_reg) begin
                    index_reg <= (tdma_timeslot_index << SLICE_WIDTH) + cur_slice_reg;
                    if (slice_active_reg) begin
                        accumulate_state_reg <= 2'd1;
                    end
                end else begin
                    index_reg <= (tdma_timeslot_index << SLICE_WIDTH);
                    accumulate_state_reg <= 2'd1;
                end
            end
        end
        2'd1: begin
            rx_ts_update_count_read_reg <= update_count_mem[index_reg];
            rx_ts_error_count_read_reg <= error_count_mem[index_reg];

            accumulate_state_reg <= 2'd2;
        end
        2'd2: begin
            rx_ts_error_count_reg <= rx_ts_error_count_read_reg + phy_rx_error_count_sync_reg;
            rx_ts_update_count_reg <= rx_ts_update_count_read_reg + 1;

            // if ((rx_ts_error_count_reg + inc_reg) >> 32) begin
            //     rx_ts_error_count_reg <= 32'hffffffff;
            // end else begin
            //     rx_ts_error_count_reg <= rx_ts_error_count_reg + inc_reg;
            // end

            // if ((rx_ts_update_count_reg + 1) >> 32) begin
            //     rx_ts_update_count_reg <= 32'hffffffff;
            // end else begin
            //     rx_ts_update_count_reg <= rx_ts_update_count_reg + 1;
            // end

            accumulate_state_reg <= 2'd3;
        end
        2'd3: begin
            update_count_mem[index_reg] <= rx_ts_update_count_reg;
            error_count_mem[index_reg] <= rx_ts_error_count_reg;

            accumulate_state_reg <= 2'd0;
        end
        default: begin
            accumulate_state_reg <= 2'd0;
        end
    endcase
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

assign s_axil_awready = s_axil_awready_reg;
assign s_axil_wready = s_axil_wready_reg;
assign s_axil_bresp = 2'b00;
assign s_axil_bvalid = s_axil_bvalid_reg;
assign s_axil_arready = s_axil_arready_reg;
assign s_axil_rdata = error_count_mem_read_reg ? error_count_mem_read_data_reg : (update_count_mem_read_reg ? update_count_mem_read_data_reg : s_axil_rdata_reg);
assign s_axil_rresp = 2'b00;
assign s_axil_rvalid = s_axil_rvalid_reg;

wire [INDEX_WIDTH+SLICE_WIDTH-1:0] axil_ram_addr = ((mem_rd_en ? s_axil_araddr[INDEX_WIDTH+1+2-1:1+2] : s_axil_awaddr[INDEX_WIDTH+1+2-1:1+2]) << SLICE_WIDTH) | slice_select_reg;

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

    cycle_count_next = cycle_count_reg + 1;

    update_count_next = update_count_reg;
    rx_error_count_next = rx_error_count_reg;
    if (phy_rx_error_count_sync_valid_reg) begin
        update_count_next = update_count_reg + 1;
        rx_error_count_next = phy_rx_error_count_sync_reg + rx_error_count_reg;
    end

    atomic_cycle_count_next = atomic_cycle_count_reg + 1;
    if (atomic_cycle_count_reg[31] && ~atomic_cycle_count_next[31]) begin
        atomic_cycle_count_next = 32'hffffffff;
    end

    atomic_update_count_next = atomic_update_count_reg;
    atomic_rx_error_count_next = atomic_rx_error_count_reg;
    if (phy_rx_error_count_sync_valid_reg) begin
        atomic_update_count_next = atomic_update_count_reg + 1;
        atomic_rx_error_count_next = phy_rx_error_count_sync_reg + atomic_rx_error_count_reg;

        // saturate
        if (atomic_update_count_reg[31] && ~atomic_update_count_next[31]) begin
            atomic_update_count_next = 32'hffffffff;
        end
        if (atomic_rx_error_count_reg[31] && ~atomic_rx_error_count_next[31]) begin
            atomic_rx_error_count_next = 32'hffffffff;
        end
    end

    accumulate_enable_next = accumulate_enable_reg;
    slice_enable_next = slice_enable_reg;

    slice_time_next = slice_time_reg;
    slice_offset_next = slice_offset_reg;

    slice_select_next = slice_select_reg;

    tx_prbs31_enable_next = tx_prbs31_enable_reg;
    rx_prbs31_enable_next = rx_prbs31_enable_reg;

    write_eligible = s_axil_awvalid && s_axil_wvalid && (!s_axil_bvalid || s_axil_bready) && (!s_axil_awready && !s_axil_wready);
    read_eligible = s_axil_arvalid && (!s_axil_rvalid || s_axil_rready) && (!s_axil_arready);

    if (write_eligible && (!read_eligible || last_read_reg)) begin
        last_read_next = 1'b0;

        s_axil_awready_next = 1'b1;
        s_axil_wready_next = 1'b1;
        s_axil_bvalid_next = 1'b1;

        if (s_axil_awaddr[INDEX_WIDTH+2+1+1-1]) begin
            mem_wr_en = 1'b1;
        end else begin
            case (s_axil_awaddr & ({AXIL_ADDR_WIDTH{1'b1}} << 2))
                16'h0000: begin
                    // control
                    tx_prbs31_enable_next = s_axil_wdata[0];
                    rx_prbs31_enable_next = s_axil_wdata[1];
                end
                16'h0004: begin
                    // cycle count
                    cycle_count_next = 1;
                end
                16'h0008: begin
                    // update count
                    update_count_next = 0;
                end
                16'h000C: begin
                    // error count
                    rx_error_count_next = 0;
                end
                16'h0014: begin
                    // cycle count
                    atomic_cycle_count_next = 1;
                end
                16'h0018: begin
                    // update count
                    atomic_update_count_next = 0;
                end
                16'h001C: begin
                    // error count
                    atomic_rx_error_count_next = 0;
                end
                16'h0020: begin
                    // control
                    accumulate_enable_next = s_axil_wdata[0];
                    slice_enable_next = s_axil_wdata[1];
                end
                16'h0024: begin
                    // slice time
                    slice_time_next = s_axil_wdata;
                end
                16'h0028: begin
                    // slice offset
                    slice_offset_next = s_axil_wdata;
                end
                16'h0030: begin
                    // slice select
                    slice_select_next = s_axil_wdata;
                end
            endcase
        end
    end else if (read_eligible) begin
        last_read_next = 1'b1;

        s_axil_arready_next = 1'b1;
        s_axil_rvalid_next = 1'b1;
        s_axil_rdata_next = {AXIL_DATA_WIDTH{1'b0}};

        if (s_axil_araddr[INDEX_WIDTH+2+1+1-1]) begin
            mem_rd_en = 1'b1;
        end else begin
            case (s_axil_araddr & ({AXIL_ADDR_WIDTH{1'b1}} << 2))
                16'h0000: begin
                    // control
                    s_axil_rdata_next[0] = tx_prbs31_enable_reg;
                    s_axil_rdata_next[1] = rx_prbs31_enable_reg;
                end
                16'h0004: begin
                    // cycle count
                    s_axil_rdata_next = cycle_count_reg;
                end
                16'h0008: begin
                    // update count
                    s_axil_rdata_next = update_count_reg;
                end
                16'h000C: begin
                    // error count
                    s_axil_rdata_next = rx_error_count_reg;
                end
                16'h0014: begin
                    // cycle count
                    s_axil_rdata_next = atomic_cycle_count_reg;
                    atomic_cycle_count_next = 1;
                end
                16'h0018: begin
                    // update count
                    s_axil_rdata_next = atomic_update_count_reg;
                    atomic_update_count_next = 0;
                end
                16'h001C: begin
                    // error count
                    s_axil_rdata_next = atomic_rx_error_count_reg;
                    atomic_rx_error_count_next = 0;
                end
                16'h0020: begin
                    // control
                    s_axil_rdata_next[0] = accumulate_enable_reg;
                    s_axil_rdata_next[1] = slice_enable_reg;
                end
                16'h0024: begin
                    // slice time
                    s_axil_rdata_next = slice_time_reg;
                end
                16'h0028: begin
                    // slice offset
                    s_axil_rdata_next = slice_offset_reg;
                end
                16'h0030: begin
                    // slice select
                    s_axil_rdata_next = slice_select_reg;
                end
            endcase
        end
    end
end

always @(posedge clk) begin
    if (rst) begin
        last_read_reg <= 1'b0;

        s_axil_awready_reg <= 1'b0;
        s_axil_wready_reg <= 1'b0;
        s_axil_bvalid_reg <= 1'b0;

        s_axil_arready_reg <= 1'b0;
        s_axil_rvalid_reg <= 1'b0;

        cycle_count_reg <= 32'd0;
        update_count_reg <= 32'd0;
        rx_error_count_reg <= 32'd0;

        atomic_cycle_count_reg <= 32'd0;
        atomic_update_count_reg <= 32'd0;
        atomic_rx_error_count_reg <= 32'd0;

        accumulate_enable_reg <= 1'b0;
        slice_enable_reg <= 1'b0;

        slice_time_reg <= 32'd0;
        slice_offset_reg <= 32'd0;

        slice_select_reg <= 0;

        tx_prbs31_enable_reg <= 1'b0;
        rx_prbs31_enable_reg <= 1'b0;
    end else begin
        last_read_reg <= last_read_next;

        s_axil_awready_reg <= s_axil_awready_next;
        s_axil_wready_reg <= s_axil_wready_next;
        s_axil_bvalid_reg <= s_axil_bvalid_next;

        s_axil_arready_reg <= s_axil_arready_next;
        s_axil_rvalid_reg <= s_axil_rvalid_next;

        cycle_count_reg <= cycle_count_next;
        update_count_reg <= update_count_next;
        rx_error_count_reg <= rx_error_count_next;

        atomic_cycle_count_reg <= atomic_cycle_count_next;
        atomic_update_count_reg <= atomic_update_count_next;
        atomic_rx_error_count_reg <= atomic_rx_error_count_next;

        accumulate_enable_reg <= accumulate_enable_next;
        slice_enable_reg <= slice_enable_next;

        slice_time_reg <= slice_time_next;
        slice_offset_reg <= slice_offset_next;

        slice_select_reg <= slice_select_next;

        tx_prbs31_enable_reg <= tx_prbs31_enable_next;
        rx_prbs31_enable_reg <= rx_prbs31_enable_next;
    end

    s_axil_rdata_reg <= s_axil_rdata_next;

    error_count_mem_read_reg <= 1'b0;
    update_count_mem_read_reg <= 1'b0;

    if (mem_rd_en) begin
        if (s_axil_araddr[2]) begin
            error_count_mem_read_data_reg <= error_count_mem[axil_ram_addr];
            error_count_mem_read_reg <= 1'b1;
        end else begin
            update_count_mem_read_data_reg <= update_count_mem[axil_ram_addr];
            update_count_mem_read_reg <= 1'b1;
        end
    end else begin
        for (i = 0; i < WORD_WIDTH; i = i + 1) begin
            if (mem_wr_en && s_axil_wstrb[i]) begin
                if (s_axil_awaddr[2]) begin
                    error_count_mem[axil_ram_addr][WORD_SIZE*i +: WORD_SIZE] <= s_axil_wdata[WORD_SIZE*i +: WORD_SIZE];
                end else begin
                    update_count_mem[axil_ram_addr][WORD_SIZE*i +: WORD_SIZE] <= s_axil_wdata[WORD_SIZE*i +: WORD_SIZE];
                end
            end
        end
    end
end

endmodule

`resetall
