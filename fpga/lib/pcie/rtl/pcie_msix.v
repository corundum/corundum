/*

Copyright (c) 2022 Alex Forencich

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
 * PCIe MSI-X module
 */
module pcie_msix #
(
    // Interrupt configuration
    parameter IRQ_INDEX_WIDTH = 11,

    // AXI-lite interface configuration
    parameter AXIL_DATA_WIDTH = 32,
    parameter AXIL_ADDR_WIDTH = IRQ_INDEX_WIDTH+5,
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),

    // TLP interface configuration
    parameter TLP_HDR_WIDTH = 128,
    parameter TLP_FORCE_64_BIT_ADDR = 0
)
(
    input  wire                        clk,
    input  wire                        rst,

    /*
     * AXI lite interface for MSI-X tables
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
     * Interrupt request input
     */
    input  wire [IRQ_INDEX_WIDTH-1:0]  irq_index,
    input  wire                        irq_valid,
    output wire                        irq_ready,

    /*
     * Memory write TLP output
     */
    output wire [31:0]                 tx_wr_req_tlp_data,
    output wire                        tx_wr_req_tlp_strb,
    output wire [TLP_HDR_WIDTH-1:0]    tx_wr_req_tlp_hdr,
    output wire                        tx_wr_req_tlp_valid,
    output wire                        tx_wr_req_tlp_sop,
    output wire                        tx_wr_req_tlp_eop,
    input  wire                        tx_wr_req_tlp_ready,

    /*
     * Configuration
     */
    input  wire [15:0]                 requester_id,
    input  wire                        msix_enable,
    input  wire                        msix_mask
);

parameter TBL_ADDR_WIDTH = IRQ_INDEX_WIDTH+1;
parameter PBA_ADDR_WIDTH = IRQ_INDEX_WIDTH > 6 ? IRQ_INDEX_WIDTH-6 : 0;
parameter PBA_ADDR_WIDTH_INT = PBA_ADDR_WIDTH > 0 ? PBA_ADDR_WIDTH : 1;

parameter INDEX_SHIFT = $clog2(64/8);
parameter WORD_SELECT_SHIFT = $clog2(AXIL_DATA_WIDTH/8);
parameter WORD_SELECT_WIDTH = 64 > AXIL_DATA_WIDTH ? $clog2((64+7)/8) - $clog2(AXIL_DATA_WIDTH/8) : 0;

// bus width assertions
initial begin
    if (AXIL_STRB_WIDTH * 8 != AXIL_DATA_WIDTH) begin
        $error("Error: AXI lite interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end

    if (AXIL_DATA_WIDTH > 64) begin
        $error("Error: AXI lite data width must be 64 or less (instance %m)");
        $finish;
    end

    if (AXIL_ADDR_WIDTH < IRQ_INDEX_WIDTH+5) begin
        $error("Error: AXI lite address width too narrow (instance %m)");
        $finish;
    end

    if (IRQ_INDEX_WIDTH > 11) begin
        $error("Error: IRQ index width must be 11 or less (instance %m)");
        $finish;
    end
end

localparam [2:0]
    TLP_FMT_3DW = 3'b000,
    TLP_FMT_4DW = 3'b001,
    TLP_FMT_3DW_DATA = 3'b010,
    TLP_FMT_4DW_DATA = 3'b011,
    TLP_FMT_PREFIX = 3'b100;

localparam [1:0]
    STATE_IDLE = 2'd0,
    STATE_READ_TBL_1 = 2'd1,
    STATE_READ_TBL_2 = 2'd2,
    STATE_SEND_TLP = 2'd3;

reg [1:0] state_reg = STATE_IDLE, state_next;

reg [IRQ_INDEX_WIDTH-1:0] irq_index_reg = 0, irq_index_next;

reg [63:0] vec_addr_reg = 0, vec_addr_next;
reg [31:0] vec_data_reg = 0, vec_data_next;
reg vec_mask_reg = 1'b0, vec_mask_next;

reg last_read_reg = 1'b0, last_read_next;

reg [127:0] tlp_hdr;

reg read_eligible;
reg write_eligible;

reg tbl_axil_mem_rd_en;
reg tbl_axil_mem_wr_en;
reg [7:0] tbl_axil_mem_wr_be;
reg [63:0] tbl_axil_mem_wr_data;
reg pba_axil_mem_rd_en;

reg tbl_mem_rd_en;
reg [TBL_ADDR_WIDTH-1:0] tbl_mem_addr;
reg pba_mem_rd_en;
reg pba_mem_wr_en;
reg [PBA_ADDR_WIDTH-1:0] pba_mem_addr;
reg [63:0] pba_mem_wr_data;

reg s_axil_awready_reg = 1'b0, s_axil_awready_next;
reg s_axil_wready_reg = 1'b0, s_axil_wready_next;
reg s_axil_bvalid_reg = 1'b0, s_axil_bvalid_next;
reg s_axil_arready_reg = 1'b0, s_axil_arready_next;
reg [AXIL_DATA_WIDTH-1:0] s_axil_rdata_reg = {AXIL_DATA_WIDTH{1'b0}}, s_axil_rdata_next;
reg s_axil_rvalid_reg = 1'b0, s_axil_rvalid_next;

reg irq_ready_reg = 1'b0, irq_ready_next;

reg [31:0] tx_wr_req_tlp_data_reg = 0, tx_wr_req_tlp_data_next;
reg [TLP_HDR_WIDTH-1:0] tx_wr_req_tlp_hdr_reg = 0, tx_wr_req_tlp_hdr_next;
reg tx_wr_req_tlp_valid_reg = 0, tx_wr_req_tlp_valid_next;

reg msix_enable_reg = 1'b0;
reg msix_mask_reg = 1'b0;

// MSI-X table
(* ramstyle = "no_rw_check, mlab" *)
reg [63:0] tbl_mem[(2**TBL_ADDR_WIDTH)-1:0];

// MSI-X PBA
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [63:0] pba_mem[(2**PBA_ADDR_WIDTH)-1:0];

reg tbl_rd_data_valid_reg = 1'b0, tbl_rd_data_valid_next;
reg pba_rd_data_valid_reg = 1'b0, pba_rd_data_valid_next;
reg [WORD_SELECT_WIDTH-1:0] rd_data_shift_reg = 0, rd_data_shift_next;

reg [63:0] tbl_mem_rd_data_reg = 0;
reg [63:0] pba_mem_rd_data_reg = 0;
reg [63:0] tbl_axil_mem_rd_data_reg = 0;
reg [63:0] pba_axil_mem_rd_data_reg = 0;

wire [TBL_ADDR_WIDTH-1:0] s_axil_awaddr_index = s_axil_awaddr >> INDEX_SHIFT;
wire [WORD_SELECT_WIDTH-1:0] s_axil_awaddr_word = AXIL_DATA_WIDTH < 64 ? s_axil_awaddr >> WORD_SELECT_SHIFT : 0;

wire [TBL_ADDR_WIDTH-1:0] s_axil_araddr_index = s_axil_araddr >> INDEX_SHIFT;
wire [WORD_SELECT_WIDTH-1:0] s_axil_araddr_word = AXIL_DATA_WIDTH < 64 ? s_axil_araddr >> WORD_SELECT_SHIFT : 0;

assign s_axil_awready = s_axil_awready_reg;
assign s_axil_wready = s_axil_wready_reg;
assign s_axil_bresp = 2'b00;
assign s_axil_bvalid = s_axil_bvalid_reg;
assign s_axil_arready = s_axil_arready_reg;
assign s_axil_rdata = s_axil_rdata_reg;
assign s_axil_rresp = 2'b00;
assign s_axil_rvalid = s_axil_rvalid_reg;

assign irq_ready = irq_ready_reg;

assign tx_wr_req_tlp_data = tx_wr_req_tlp_data_reg;
assign tx_wr_req_tlp_strb = 1;
assign tx_wr_req_tlp_hdr = tx_wr_req_tlp_hdr_reg;
assign tx_wr_req_tlp_valid = tx_wr_req_tlp_valid_reg;
assign tx_wr_req_tlp_sop = 1'b1;
assign tx_wr_req_tlp_eop = 1'b1;

integer i;

initial begin
    for (i = 0; i < 2**TBL_ADDR_WIDTH; i = i + 1) begin
        tbl_mem[i] = 0;
    end
    for (i = 0; i < 2**PBA_ADDR_WIDTH; i = i + 1) begin
        pba_mem[i] = 0;
    end
end

always @* begin
    state_next = STATE_IDLE;

    tbl_mem_rd_en = 1'b0;
    tbl_mem_addr = {irq_index_reg, 1'b0};

    pba_mem_rd_en = 1'b0;
    pba_mem_wr_en = 1'b0;
    pba_mem_addr = irq_index_reg >> 5;
    pba_mem_wr_data = 0;

    irq_index_next = irq_index_reg;

    vec_addr_next = vec_addr_reg;
    vec_data_next = vec_data_reg;
    vec_mask_next = vec_mask_reg;

    irq_ready_next = 1'b0;

    tx_wr_req_tlp_data_next = tx_wr_req_tlp_data_reg;
    tx_wr_req_tlp_hdr_next = tx_wr_req_tlp_hdr_reg;
    tx_wr_req_tlp_valid_next = tx_wr_req_tlp_valid_reg && !tx_wr_req_tlp_ready;

    // TLP header
    // DW 0
    if (((vec_addr_reg[63:2] >> 30) != 0) || TLP_FORCE_64_BIT_ADDR) begin
        tlp_hdr[127:125] = TLP_FMT_4DW_DATA; // fmt - 4DW with data
    end else begin
        tlp_hdr[127:125] = TLP_FMT_3DW_DATA; // fmt - 3DW with data
    end
    tlp_hdr[124:120] = 5'b00000; // type - write
    tlp_hdr[119] = 1'b0; // T9
    tlp_hdr[118:116] = 3'b000; // TC
    tlp_hdr[115] = 1'b0; // T8
    tlp_hdr[114] = 1'b0; // attr
    tlp_hdr[113] = 1'b0; // LN
    tlp_hdr[112] = 1'b0; // TH
    tlp_hdr[111] = 1'b0; // TD
    tlp_hdr[110] = 1'b0; // EP
    tlp_hdr[109:108] = 2'b00; // attr
    tlp_hdr[107:106] = 3'b000; // AT
    tlp_hdr[105:96] = 10'd1; // length
    // DW 1
    tlp_hdr[95:80] = requester_id; // requester ID
    tlp_hdr[79:72] = 8'd0; // tag
    tlp_hdr[71:68] = 4'b0000; // last BE
    tlp_hdr[67:64] = 4'b1111; // first BE
    if (((vec_addr_reg[63:2] >> 30) != 0) || TLP_FORCE_64_BIT_ADDR) begin
        // DW 2+3
        tlp_hdr[63:2] = vec_addr_reg[63:2]; // address
        tlp_hdr[1:0] = 2'b00; // PH
    end else begin
        // DW 2
        tlp_hdr[63:34] = vec_addr_reg[63:2]; // address
        tlp_hdr[33:32] = 2'b00; // PH
        // DW 3
        tlp_hdr[31:0] = 32'd0;
    end

    case (state_reg)
        STATE_IDLE: begin
            irq_ready_next = 1'b1;

            if (irq_valid && irq_ready) begin
                // new request
                irq_ready_next = 1'b0;
                irq_index_next = irq_index;

                tbl_mem_rd_en = 1'b1;
                tbl_mem_addr = {irq_index_next, 1'b0};

                pba_mem_rd_en = 1'b1;
                pba_mem_addr = irq_index_next >> 6;

                state_next = STATE_READ_TBL_1;
            end else if (!irq_valid && msix_enable_reg && !msix_mask_reg) begin
                // no new request waiting, scan PBA for masked requests

                if (pba_mem_rd_data_reg[irq_index_reg & 6'h3f]) begin
                    // PBA bit for current index is set, try issuing it
                    irq_ready_next = 1'b0;

                    tbl_mem_rd_en = 1'b1;
                    tbl_mem_addr = {irq_index_next, 1'b0};

                    pba_mem_rd_en = 1'b1;
                    pba_mem_addr = irq_index_next >> 6;

                    state_next = STATE_READ_TBL_1;
                end else begin
                    // PBA bit for current index is not set
                    if (pba_mem_rd_data_reg) begin
                        // at least one bit set in current group, move to next index
                        irq_index_next = irq_index_reg + 1;
                    end else begin
                        // no bits set in current group, move to next group
                        irq_index_next = (irq_index_reg & ({IRQ_INDEX_WIDTH{1'b1}} << 6)) + 7'd64;
                    end

                    pba_mem_rd_en = 1'b1;
                    pba_mem_addr = irq_index_next >> 6;

                    state_next = STATE_IDLE;
                end
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_READ_TBL_1: begin
            // handle first table read
            tbl_mem_rd_en = 1'b1;
            tbl_mem_addr = {irq_index_reg, 1'b1};

            vec_addr_next = {tbl_mem_rd_data_reg[63:2], 2'b00};

            state_next = STATE_READ_TBL_2;
        end
        STATE_READ_TBL_2: begin
            // handle second table read
            vec_data_next = tbl_mem_rd_data_reg[31:0];
            vec_mask_next = tbl_mem_rd_data_reg[32];

            if (msix_enable_reg && !msix_mask_reg && !vec_mask_next) begin
                // send TLP
                state_next = STATE_SEND_TLP;
            end else begin
                // set PBA bit
                pba_mem_wr_en = 1'b1;
                pba_mem_wr_data = pba_mem_rd_data_reg | (1 << (irq_index_reg & 6'h3F));
                irq_ready_next = 1'b1;
                state_next = STATE_IDLE;
            end
        end
        STATE_SEND_TLP: begin
            if (!tx_wr_req_tlp_valid || tx_wr_req_tlp_ready) begin
                // send TLP
                tx_wr_req_tlp_data_next = vec_data_reg;
                tx_wr_req_tlp_hdr_next = tlp_hdr;
                tx_wr_req_tlp_valid_next = 1'b1;

                // clear PBA bit
                pba_mem_wr_en = 1'b1;
                pba_mem_wr_data = pba_mem_rd_data_reg & ~(1 << (irq_index_reg & 6'h3F));

                // increment index so we don't check the same PBA bit immediately
                irq_index_next = irq_index_reg + 1;

                irq_ready_next = 1'b1;
                state_next = STATE_IDLE;
            end else begin
                state_next = STATE_SEND_TLP;
            end
        end
    endcase
end

always @(posedge clk) begin
    state_reg <= state_next;

    irq_index_reg <= irq_index_next;

    vec_addr_reg <= vec_addr_next;
    vec_data_reg <= vec_data_next;
    vec_mask_reg <= vec_mask_next;

    irq_ready_reg <= irq_ready_next;

    tx_wr_req_tlp_data_reg <= tx_wr_req_tlp_data_next;
    tx_wr_req_tlp_hdr_reg <= tx_wr_req_tlp_hdr_next;
    tx_wr_req_tlp_valid_reg <= tx_wr_req_tlp_valid_next;

    msix_enable_reg <= msix_enable;
    msix_mask_reg <= msix_mask;

    if (tbl_mem_rd_en) begin
        tbl_mem_rd_data_reg <= tbl_mem[tbl_mem_addr];
    end

    if (pba_mem_wr_en) begin
        pba_mem[pba_mem_addr] <= pba_mem_wr_data;
    end else if (pba_mem_rd_en) begin
        pba_mem_rd_data_reg <= pba_mem[pba_mem_addr];
    end

    if (rst) begin
        state_reg <= STATE_IDLE;

        irq_ready_reg <= 1'b0;

        tx_wr_req_tlp_valid_reg <= 1'b0;
    end
end

// AXI lite interface
always @* begin
    tbl_axil_mem_rd_en = 1'b0;
    tbl_axil_mem_wr_en = 1'b0;
    tbl_axil_mem_wr_be = s_axil_wstrb << (s_axil_awaddr_word * AXIL_STRB_WIDTH);
    tbl_axil_mem_wr_data = {2**WORD_SELECT_WIDTH{s_axil_wdata}};
    pba_axil_mem_rd_en = 1'b0;

    tbl_rd_data_valid_next = tbl_rd_data_valid_reg;
    pba_rd_data_valid_next = pba_rd_data_valid_reg;
    rd_data_shift_next = rd_data_shift_reg;

    last_read_next = last_read_reg;

    s_axil_awready_next = 1'b0;
    s_axil_wready_next = 1'b0;
    s_axil_bvalid_next = s_axil_bvalid_reg && !s_axil_bready;

    s_axil_arready_next = 1'b0;
    s_axil_rdata_next = s_axil_rdata_reg;
    s_axil_rvalid_next = s_axil_rvalid_reg && !s_axil_rready;

    write_eligible = s_axil_awvalid && s_axil_wvalid && (!s_axil_bvalid || s_axil_bready) && (!s_axil_awready && !s_axil_wready);
    read_eligible = s_axil_arvalid && (!s_axil_rvalid || s_axil_rready || !(tbl_rd_data_valid_reg || pba_rd_data_valid_reg)) && (!s_axil_arready);

    if ((tbl_rd_data_valid_reg || pba_rd_data_valid_reg) && (!s_axil_rvalid || s_axil_rready)) begin
        s_axil_rvalid_next = 1'b1;
        tbl_rd_data_valid_next = 1'b0;
        pba_rd_data_valid_next = 1'b0;

        if (tbl_rd_data_valid_reg) begin
            if (AXIL_DATA_WIDTH < 64) begin
                s_axil_rdata_next = tbl_axil_mem_rd_data_reg >> rd_data_shift_reg*AXIL_DATA_WIDTH;
            end else begin
                s_axil_rdata_next = tbl_axil_mem_rd_data_reg;
            end
        end else begin
            if (AXIL_DATA_WIDTH < 64) begin
                s_axil_rdata_next = pba_axil_mem_rd_data_reg >> rd_data_shift_reg*AXIL_DATA_WIDTH;
            end else begin
                s_axil_rdata_next = pba_axil_mem_rd_data_reg;
            end
        end
    end

    if (write_eligible && (!read_eligible || last_read_reg)) begin
        last_read_next = 1'b0;

        s_axil_awready_next = 1'b1;
        s_axil_wready_next = 1'b1;
        s_axil_bvalid_next = 1'b1;

        if (s_axil_awaddr[AXIL_ADDR_WIDTH-1] == 0) begin
            tbl_axil_mem_wr_en = 1'b1;
        end
    end else if (read_eligible) begin
        last_read_next = 1'b1;

        s_axil_arready_next = 1'b1;

        rd_data_shift_next = s_axil_araddr_word;

        if (s_axil_araddr[AXIL_ADDR_WIDTH-1] == 0) begin
            tbl_axil_mem_rd_en = 1'b1;
            tbl_rd_data_valid_next = 1'b1;
        end else begin
            pba_axil_mem_rd_en = 1'b1;
            pba_rd_data_valid_next = 1'b1;
        end
    end
end

always @(posedge clk) begin
    tbl_rd_data_valid_reg <= tbl_rd_data_valid_next;
    pba_rd_data_valid_reg <= pba_rd_data_valid_next;
    rd_data_shift_reg <= rd_data_shift_next;

    last_read_reg <= last_read_next;

    s_axil_awready_reg <= s_axil_awready_next;
    s_axil_wready_reg <= s_axil_wready_next;
    s_axil_bvalid_reg <= s_axil_bvalid_next;

    s_axil_arready_reg <= s_axil_arready_next;
    s_axil_rdata_reg <= s_axil_rdata_next;
    s_axil_rvalid_reg <= s_axil_rvalid_next;

    if (tbl_axil_mem_rd_en) begin
        tbl_axil_mem_rd_data_reg <= tbl_mem[s_axil_araddr_index];
    end else begin
        for (i = 0; i < 8; i = i + 1) begin
            if (tbl_axil_mem_wr_en && tbl_axil_mem_wr_be[i]) begin
                tbl_mem[s_axil_awaddr_index][8*i +: 8] <= tbl_axil_mem_wr_data[8*i +: 8];
            end
        end
    end

    if (pba_axil_mem_rd_en) begin
        pba_axil_mem_rd_data_reg <= pba_mem[s_axil_araddr_index];
    end

    if (rst) begin
        tbl_rd_data_valid_reg <= 1'b0;
        pba_rd_data_valid_reg <= 1'b0;
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
