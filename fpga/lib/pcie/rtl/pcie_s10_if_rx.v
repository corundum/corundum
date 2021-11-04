/*

Copyright (c) 2021 Alex Forencich

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
 * Intel Stratix 10 H-Tile/L-Tile PCIe interface adapter (receive)
 */
module pcie_s10_if_rx #
(
    // H-Tile/L-Tile AVST segment count
    parameter SEG_COUNT = 1,
    // H-Tile/L-Tile AVST segment data width
    parameter SEG_DATA_WIDTH = 256,
    // H-Tile/L-Tile AVST segment empty signal width
    parameter SEG_EMPTY_WIDTH = $clog2(SEG_DATA_WIDTH/32),
    // TLP segment count
    parameter TLP_SEG_COUNT = 1,
    // TLP segment data width
    parameter TLP_SEG_DATA_WIDTH = (SEG_COUNT*SEG_DATA_WIDTH)/TLP_SEG_COUNT,
    // TLP segment strobe width
    parameter TLP_SEG_STRB_WIDTH = TLP_SEG_DATA_WIDTH/32,
    // TLP segment header width
    parameter TLP_SEG_HDR_WIDTH = 128,
    // IO bar index
    // rx_st_bar_range = 6 is mapped to IO_BAR_INDEX on rx_req_tlp_bar_id
    parameter IO_BAR_INDEX = 5
)
(
    input  wire                                         clk,
    input  wire                                         rst,

    // H-Tile/L-Tile RX AVST interface
    input  wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]          rx_st_data,
    input  wire [SEG_COUNT*SEG_EMPTY_WIDTH-1:0]         rx_st_empty,
    input  wire [SEG_COUNT-1:0]                         rx_st_sop,
    input  wire [SEG_COUNT-1:0]                         rx_st_eop,
    input  wire [SEG_COUNT-1:0]                         rx_st_valid,
    output wire                                         rx_st_ready,
    input  wire [SEG_COUNT-1:0]                         rx_st_vf_active,
    input  wire [SEG_COUNT*2-1:0]                       rx_st_func_num,
    input  wire [SEG_COUNT*11-1:0]                      rx_st_vf_num,
    input  wire [SEG_COUNT*3-1:0]                       rx_st_bar_range,

    /*
     * TLP output (request to BAR)
     */
    output wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  rx_req_tlp_data,
    output wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   rx_req_tlp_hdr,
    output wire [TLP_SEG_COUNT*3-1:0]                   rx_req_tlp_bar_id,
    output wire [TLP_SEG_COUNT*8-1:0]                   rx_req_tlp_func_num,
    output wire [TLP_SEG_COUNT-1:0]                     rx_req_tlp_valid,
    output wire [TLP_SEG_COUNT-1:0]                     rx_req_tlp_sop,
    output wire [TLP_SEG_COUNT-1:0]                     rx_req_tlp_eop,
    input  wire                                         rx_req_tlp_ready,

    /*
     * TLP output (completion to DMA)
     */
    output wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  rx_cpl_tlp_data,
    output wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   rx_cpl_tlp_hdr,
    output wire [TLP_SEG_COUNT*4-1:0]                   rx_cpl_tlp_error,
    output wire [TLP_SEG_COUNT-1:0]                     rx_cpl_tlp_valid,
    output wire [TLP_SEG_COUNT-1:0]                     rx_cpl_tlp_sop,
    output wire [TLP_SEG_COUNT-1:0]                     rx_cpl_tlp_eop,
    input  wire                                         rx_cpl_tlp_ready
);

parameter OUTPUT_FIFO_ADDR_WIDTH = 5;
parameter OUTPUT_FIFO_LIMIT = 8;

// bus width assertions
initial begin
    if (SEG_COUNT != 1) begin
        $error("Error: segment count must be 1 (instance %m)");
        $finish;        
    end

    if (SEG_DATA_WIDTH != 256) begin
        $error("Error: segment data width must be 256 (instance %m)");
        $finish;        
    end

    if (TLP_SEG_COUNT != 1) begin
        $error("Error: TLP segment count must be 1 (instance %m)");
        $finish;
    end

    if (TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH != SEG_COUNT*SEG_DATA_WIDTH) begin
        $error("Error: Interface widths must match (instance %m)");
        $finish;
    end

    if (TLP_SEG_HDR_WIDTH != 128) begin
        $error("Error: TLP segment header width must be 128 (instance %m)");
        $finish;
    end
end

localparam [1:0]
    TLP_INPUT_STATE_IDLE = 2'd0,
    TLP_INPUT_STATE_HEADER = 2'd1,
    TLP_INPUT_STATE_PAYLOAD = 2'd2;

reg [1:0] tlp_input_state_reg = TLP_INPUT_STATE_IDLE, tlp_input_state_next;

reg payload_offset_reg = 0, payload_offset_next;

reg cpl_reg = 1'b0, cpl_next;

// internal datapath
reg  [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  rx_req_tlp_data_int;
reg  [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   rx_req_tlp_hdr_int;
reg  [TLP_SEG_COUNT*3-1:0]                   rx_req_tlp_bar_id_int;
reg  [TLP_SEG_COUNT*8-1:0]                   rx_req_tlp_func_num_int;
reg  [TLP_SEG_COUNT-1:0]                     rx_req_tlp_sop_int;
reg  [TLP_SEG_COUNT-1:0]                     rx_req_tlp_eop_int;
wire                                         rx_req_tlp_ready_int;
reg  [TLP_SEG_COUNT-1:0]                     rx_req_tlp_valid_int;
wire                                         rx_cpl_tlp_ready_int;
reg  [TLP_SEG_COUNT-1:0]                     rx_cpl_tlp_valid_int;

reg [SEG_COUNT*SEG_DATA_WIDTH-1:0]  rx_st_data_int_reg = 0, rx_st_data_int_next;
reg [SEG_COUNT*SEG_EMPTY_WIDTH-1:0] rx_st_empty_int_reg = 0, rx_st_empty_int_next;
reg [SEG_COUNT-1:0]                 rx_st_sop_int_reg = 0, rx_st_sop_int_next;
reg [SEG_COUNT-1:0]                 rx_st_eop_int_reg = 0, rx_st_eop_int_next;
reg [SEG_COUNT-1:0]                 rx_st_valid_int_reg = 0, rx_st_valid_int_next;
reg [SEG_COUNT-1:0]                 rx_st_vf_active_int_reg = 0, rx_st_vf_active_int_next;
reg [SEG_COUNT*2-1:0]               rx_st_func_num_int_reg = 0, rx_st_func_num_int_next;
reg [SEG_COUNT*11-1:0]              rx_st_vf_num_int_reg = 0, rx_st_vf_num_int_next;
reg [SEG_COUNT*3-1:0]               rx_st_bar_range_int_reg = 0, rx_st_bar_range_int_next;

wire [SEG_COUNT*SEG_DATA_WIDTH*2-1:0] rx_st_data_full = {rx_st_data, rx_st_data_int_reg};

assign rx_st_ready = rx_req_tlp_ready_int && rx_cpl_tlp_ready_int;

always @* begin
    tlp_input_state_next = TLP_INPUT_STATE_IDLE;

    payload_offset_next = payload_offset_reg;

    cpl_next = cpl_reg;

    if (payload_offset_reg) begin
        rx_req_tlp_data_int = rx_st_data_full[SEG_COUNT*SEG_DATA_WIDTH+128-1:128];
    end else begin
        rx_req_tlp_data_int = rx_st_data_full[SEG_COUNT*SEG_DATA_WIDTH+96-1:96];
    end
    rx_req_tlp_hdr_int[127:96] = rx_st_data_full[31:0];
    rx_req_tlp_hdr_int[95:64] = rx_st_data_full[63:32];
    rx_req_tlp_hdr_int[63:32] = rx_st_data_full[95:64];
    rx_req_tlp_hdr_int[31:0] = rx_st_data_full[127:96];
    if (rx_st_bar_range == 6) begin
        // IO BAR
        rx_req_tlp_bar_id_int = IO_BAR_INDEX;
    end else if (rx_st_bar_range == 7) begin
        // expansion ROM BAR
        rx_req_tlp_bar_id_int = 6;
    end else begin
        // memory BAR
        rx_req_tlp_bar_id_int = rx_st_bar_range;
    end
    rx_req_tlp_func_num_int = rx_st_func_num;
    rx_req_tlp_valid_int = 1'b0;
    rx_req_tlp_sop_int = 1'b1;
    rx_req_tlp_eop_int = 1'b1;
    rx_cpl_tlp_valid_int = 1'b0;

    rx_st_data_int_next = rx_st_data_int_reg;
    rx_st_empty_int_next = rx_st_empty_int_reg;
    rx_st_sop_int_next = rx_st_sop_int_reg;
    rx_st_eop_int_next = rx_st_eop_int_reg;
    rx_st_valid_int_next = rx_st_valid_int_reg;
    rx_st_vf_active_int_next = rx_st_vf_active_int_reg;
    rx_st_func_num_int_next = rx_st_func_num_int_reg;
    rx_st_vf_num_int_next = rx_st_vf_num_int_reg;
    rx_st_bar_range_int_next = rx_st_bar_range_int_reg;

    case (tlp_input_state_reg)
        TLP_INPUT_STATE_IDLE: begin
            if (rx_st_valid_int_reg) begin
                rx_req_tlp_hdr_int[127:96] = rx_st_data_full[31:0];
                rx_req_tlp_hdr_int[95:64] = rx_st_data_full[63:32];
                rx_req_tlp_hdr_int[63:32] = rx_st_data_full[95:64];
                rx_req_tlp_hdr_int[31:0] = rx_st_data_full[127:96];

                payload_offset_next = rx_st_data_full[29];

                if (rx_st_bar_range == 6) begin
                    // IO BAR
                    rx_req_tlp_bar_id_int = IO_BAR_INDEX;
                end else if (rx_st_bar_range == 7) begin
                    // expansion ROM BAR
                    rx_req_tlp_bar_id_int = 6;
                end else begin
                    // memory BAR
                    rx_req_tlp_bar_id_int = rx_st_bar_range;
                end
                rx_req_tlp_func_num_int = rx_st_func_num;

                if (payload_offset_next) begin
                    rx_req_tlp_data_int = rx_st_data_full[(SEG_COUNT*SEG_DATA_WIDTH)+128-1:128];
                end else begin
                    rx_req_tlp_data_int = rx_st_data_full[(SEG_COUNT*SEG_DATA_WIDTH)+96-1:96];
                end
                rx_req_tlp_sop_int = 1'b1;
                rx_req_tlp_eop_int = 1'b0;

                cpl_next = !rx_st_data_full[29] && rx_st_data_full[28:25] == 4'b0101;

                if (rx_st_eop_int_reg) begin
                    rx_req_tlp_valid_int = !cpl_next;
                    rx_cpl_tlp_valid_int = cpl_next;
                    rx_req_tlp_eop_int = 1'b1;
                    rx_st_valid_int_next = 1'b0;
                    tlp_input_state_next = TLP_INPUT_STATE_IDLE;
                end else if (rx_st_valid) begin
                    rx_req_tlp_valid_int = !cpl_next;
                    rx_cpl_tlp_valid_int = cpl_next;
                    tlp_input_state_next = TLP_INPUT_STATE_PAYLOAD;
                end else begin
                    tlp_input_state_next = TLP_INPUT_STATE_IDLE;
                end
            end else begin
                tlp_input_state_next = TLP_INPUT_STATE_IDLE;
            end
        end
        TLP_INPUT_STATE_PAYLOAD: begin
            if (rx_st_valid_int_reg) begin

                if (payload_offset_reg) begin
                    rx_req_tlp_data_int = rx_st_data_full[SEG_COUNT*SEG_DATA_WIDTH+128-1:128];
                end else begin
                    rx_req_tlp_data_int = rx_st_data_full[SEG_COUNT*SEG_DATA_WIDTH+96-1:96];
                end
                rx_req_tlp_sop_int = 1'b0;
                rx_req_tlp_eop_int = 1'b0;

                if (rx_st_eop_int_reg) begin
                    rx_req_tlp_valid_int = !cpl_reg;
                    rx_cpl_tlp_valid_int = cpl_reg;
                    rx_req_tlp_eop_int = 1'b1;
                    rx_st_valid_int_next = 1'b0;
                    tlp_input_state_next = TLP_INPUT_STATE_IDLE;
                end else if (rx_st_valid) begin
                    rx_req_tlp_valid_int = !cpl_reg;
                    rx_cpl_tlp_valid_int = cpl_reg;
                    tlp_input_state_next = TLP_INPUT_STATE_PAYLOAD;
                end else begin
                    tlp_input_state_next = TLP_INPUT_STATE_PAYLOAD;
                end
            end else begin
                tlp_input_state_next = TLP_INPUT_STATE_PAYLOAD;
            end
        end
    endcase

    if (rx_st_valid) begin
        rx_st_data_int_next = rx_st_data;
        rx_st_empty_int_next = rx_st_empty;
        rx_st_sop_int_next = rx_st_sop;
        rx_st_eop_int_next = rx_st_eop;
        rx_st_valid_int_next = rx_st_valid;
        rx_st_vf_active_int_next = rx_st_vf_active;
        rx_st_func_num_int_next = rx_st_func_num;
        rx_st_vf_num_int_next = rx_st_vf_num;
        rx_st_bar_range_int_next = rx_st_bar_range;
    end
end

always @(posedge clk) begin
    tlp_input_state_reg <= tlp_input_state_next;

    payload_offset_reg <= payload_offset_next;

    cpl_reg <= cpl_next;

    rx_st_data_int_reg <= rx_st_data_int_next;
    rx_st_empty_int_reg <= rx_st_empty_int_next;
    rx_st_sop_int_reg <= rx_st_sop_int_next;
    rx_st_eop_int_reg <= rx_st_eop_int_next;
    rx_st_valid_int_reg <= rx_st_valid_int_next;
    rx_st_vf_active_int_reg <= rx_st_vf_active_int_next;
    rx_st_func_num_int_reg <= rx_st_func_num_int_next;
    rx_st_vf_num_int_reg <= rx_st_vf_num_int_next;
    rx_st_bar_range_int_reg <= rx_st_bar_range_int_next;

    if (rst) begin
        tlp_input_state_reg <= TLP_INPUT_STATE_IDLE;

        rx_st_valid_int_reg <= 1'b0;
    end
end

// output datapath logic (request TLP)
reg  [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  rx_req_tlp_data_reg = 0;
reg  [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   rx_req_tlp_hdr_reg = 0;
reg  [TLP_SEG_COUNT*3-1:0]                   rx_req_tlp_bar_id_reg = 0;
reg  [TLP_SEG_COUNT*8-1:0]                   rx_req_tlp_func_num_reg = 0;
reg  [TLP_SEG_COUNT-1:0]                     rx_req_tlp_valid_reg = 0;
reg  [TLP_SEG_COUNT-1:0]                     rx_req_tlp_sop_reg = 0;
reg  [TLP_SEG_COUNT-1:0]                     rx_req_tlp_eop_reg = 0;

reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_req_fifo_wr_ptr_reg = 0;
reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_req_fifo_rd_ptr_reg = 0;
reg out_req_fifo_watermark_reg = 1'b0;

wire out_req_fifo_full = out_req_fifo_wr_ptr_reg == (out_req_fifo_rd_ptr_reg ^ {1'b1, {OUTPUT_FIFO_ADDR_WIDTH{1'b0}}});
wire out_req_fifo_empty = out_req_fifo_wr_ptr_reg == out_req_fifo_rd_ptr_reg;

(* ramstyle = "no_rw_check, mlab" *)
reg  [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  out_req_fifo_rx_req_tlp_data[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ramstyle = "no_rw_check, mlab" *)
reg  [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   out_req_fifo_rx_req_tlp_hdr[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ramstyle = "no_rw_check, mlab" *)
reg  [TLP_SEG_COUNT*3-1:0]                   out_req_fifo_rx_req_tlp_bar_id[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ramstyle = "no_rw_check, mlab" *)
reg  [TLP_SEG_COUNT*8-1:0]                   out_req_fifo_rx_req_tlp_func_num[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ramstyle = "no_rw_check, mlab" *)
reg  [TLP_SEG_COUNT-1:0]                     out_req_fifo_rx_req_tlp_valid[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ramstyle = "no_rw_check, mlab" *)
reg  [TLP_SEG_COUNT-1:0]                     out_req_fifo_rx_req_tlp_sop[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ramstyle = "no_rw_check, mlab" *)
reg  [TLP_SEG_COUNT-1:0]                     out_req_fifo_rx_req_tlp_eop[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];

assign rx_req_tlp_ready_int = !out_req_fifo_watermark_reg;

assign rx_req_tlp_data = rx_req_tlp_data_reg;
assign rx_req_tlp_hdr = rx_req_tlp_hdr_reg;
assign rx_req_tlp_bar_id = rx_req_tlp_bar_id_reg;
assign rx_req_tlp_func_num = rx_req_tlp_func_num_reg;
assign rx_req_tlp_valid = rx_req_tlp_valid_reg;
assign rx_req_tlp_sop = rx_req_tlp_sop_reg;
assign rx_req_tlp_eop = rx_req_tlp_eop_reg;

always @(posedge clk) begin
    rx_req_tlp_valid_reg <= rx_req_tlp_valid_reg && !rx_req_tlp_ready;

    out_req_fifo_watermark_reg <= $unsigned(out_req_fifo_wr_ptr_reg - out_req_fifo_rd_ptr_reg) >= OUTPUT_FIFO_LIMIT;

    if (!out_req_fifo_full && rx_req_tlp_valid_int) begin
        out_req_fifo_rx_req_tlp_data[out_req_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= rx_req_tlp_data_int;
        out_req_fifo_rx_req_tlp_hdr[out_req_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= rx_req_tlp_hdr_int;
        out_req_fifo_rx_req_tlp_bar_id[out_req_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= rx_req_tlp_bar_id_int;
        out_req_fifo_rx_req_tlp_func_num[out_req_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= rx_req_tlp_func_num_int;
        out_req_fifo_rx_req_tlp_sop[out_req_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= rx_req_tlp_sop_int;
        out_req_fifo_rx_req_tlp_eop[out_req_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= rx_req_tlp_eop_int;
        out_req_fifo_wr_ptr_reg <= out_req_fifo_wr_ptr_reg + 1;
    end

    if (!out_req_fifo_empty && (!rx_req_tlp_valid_reg || rx_req_tlp_ready)) begin
        rx_req_tlp_data_reg <= out_req_fifo_rx_req_tlp_data[out_req_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        rx_req_tlp_hdr_reg <= out_req_fifo_rx_req_tlp_hdr[out_req_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        rx_req_tlp_bar_id_reg <= out_req_fifo_rx_req_tlp_bar_id[out_req_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        rx_req_tlp_func_num_reg <= out_req_fifo_rx_req_tlp_func_num[out_req_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        rx_req_tlp_sop_reg <= out_req_fifo_rx_req_tlp_sop[out_req_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        rx_req_tlp_eop_reg <= out_req_fifo_rx_req_tlp_eop[out_req_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        rx_req_tlp_valid_reg <= 1'b1;
        out_req_fifo_rd_ptr_reg <= out_req_fifo_rd_ptr_reg + 1;
    end

    if (rst) begin
        out_req_fifo_wr_ptr_reg <= 0;
        out_req_fifo_rd_ptr_reg <= 0;
        rx_req_tlp_valid_reg <= 1'b0;
    end
end

// output datapath logic (completion TLP)
reg  [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  rx_cpl_tlp_data_reg = 0;
reg  [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   rx_cpl_tlp_hdr_reg = 0;
reg  [TLP_SEG_COUNT-1:0]                     rx_cpl_tlp_valid_reg = 0;
reg  [TLP_SEG_COUNT-1:0]                     rx_cpl_tlp_sop_reg = 0;
reg  [TLP_SEG_COUNT-1:0]                     rx_cpl_tlp_eop_reg = 0;

reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_cpl_fifo_wr_ptr_reg = 0;
reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_cpl_fifo_rd_ptr_reg = 0;
reg out_cpl_fifo_watermark_reg = 1'b0;

wire out_cpl_fifo_full = out_cpl_fifo_wr_ptr_reg == (out_cpl_fifo_rd_ptr_reg ^ {1'b1, {OUTPUT_FIFO_ADDR_WIDTH{1'b0}}});
wire out_cpl_fifo_empty = out_cpl_fifo_wr_ptr_reg == out_cpl_fifo_rd_ptr_reg;

(* ramstyle = "no_rw_check, mlab" *)
reg  [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  out_cpl_fifo_rx_cpl_tlp_data[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ramstyle = "no_rw_check, mlab" *)
reg  [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   out_cpl_fifo_rx_cpl_tlp_hdr[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ramstyle = "no_rw_check, mlab" *)
reg  [TLP_SEG_COUNT-1:0]                     out_cpl_fifo_rx_cpl_tlp_valid[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ramstyle = "no_rw_check, mlab" *)
reg  [TLP_SEG_COUNT-1:0]                     out_cpl_fifo_rx_cpl_tlp_sop[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ramstyle = "no_rw_check, mlab" *)
reg  [TLP_SEG_COUNT-1:0]                     out_cpl_fifo_rx_cpl_tlp_eop[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];

assign rx_cpl_tlp_ready_int = !out_cpl_fifo_watermark_reg;

assign rx_cpl_tlp_data = rx_cpl_tlp_data_reg;
assign rx_cpl_tlp_hdr = rx_cpl_tlp_hdr_reg;
assign rx_cpl_tlp_error = 0;
assign rx_cpl_tlp_valid = rx_cpl_tlp_valid_reg;
assign rx_cpl_tlp_sop = rx_cpl_tlp_sop_reg;
assign rx_cpl_tlp_eop = rx_cpl_tlp_eop_reg;

always @(posedge clk) begin
    rx_cpl_tlp_valid_reg <= rx_cpl_tlp_valid_reg && !rx_cpl_tlp_ready;

    out_cpl_fifo_watermark_reg <= $unsigned(out_cpl_fifo_wr_ptr_reg - out_cpl_fifo_rd_ptr_reg) >= OUTPUT_FIFO_LIMIT;

    if (!out_cpl_fifo_full && rx_cpl_tlp_valid_int) begin
        out_cpl_fifo_rx_cpl_tlp_data[out_cpl_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= rx_req_tlp_data_int;
        out_cpl_fifo_rx_cpl_tlp_hdr[out_cpl_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= rx_req_tlp_hdr_int;
        out_cpl_fifo_rx_cpl_tlp_sop[out_cpl_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= rx_req_tlp_sop_int;
        out_cpl_fifo_rx_cpl_tlp_eop[out_cpl_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= rx_req_tlp_eop_int;
        out_cpl_fifo_wr_ptr_reg <= out_cpl_fifo_wr_ptr_reg + 1;
    end

    if (!out_cpl_fifo_empty && (!rx_cpl_tlp_valid_reg || rx_cpl_tlp_ready)) begin
        rx_cpl_tlp_data_reg <= out_cpl_fifo_rx_cpl_tlp_data[out_cpl_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        rx_cpl_tlp_hdr_reg <= out_cpl_fifo_rx_cpl_tlp_hdr[out_cpl_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        rx_cpl_tlp_sop_reg <= out_cpl_fifo_rx_cpl_tlp_sop[out_cpl_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        rx_cpl_tlp_eop_reg <= out_cpl_fifo_rx_cpl_tlp_eop[out_cpl_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        rx_cpl_tlp_valid_reg <= 1'b1;
        out_cpl_fifo_rd_ptr_reg <= out_cpl_fifo_rd_ptr_reg + 1;
    end

    if (rst) begin
        out_cpl_fifo_wr_ptr_reg <= 0;
        out_cpl_fifo_rd_ptr_reg <= 0;
        rx_cpl_tlp_valid_reg <= 1'b0;
    end
end

endmodule

`resetall
