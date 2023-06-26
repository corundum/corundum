// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2022-2023 The Regents of the University of California
 */

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * RX queue port mapping
 */
module mqnic_rx_queue_map #
(
    // Number of ports
    parameter PORTS = 1,
    // Queue index width
    parameter QUEUE_INDEX_WIDTH = 10,
    // Indirection table address width
    parameter INDIR_TBL_ADDR_WIDTH = QUEUE_INDEX_WIDTH > 8 ? 8 : QUEUE_INDEX_WIDTH,
    // AXI stream tid signal width (source port)
    parameter ID_WIDTH = $clog2(PORTS),
    // AXI stream tdest signal width (from application)
    parameter DEST_WIDTH = QUEUE_INDEX_WIDTH+1,
    // Flow hash width
    parameter HASH_WIDTH = 32,
    // Tag width
    parameter TAG_WIDTH = 8,
    // Control register interface address width
    parameter REG_ADDR_WIDTH = $clog2(16 + PORTS*16),
    // Control register interface data width
    parameter REG_DATA_WIDTH = 32,
    // Control register interface byte enable width
    parameter REG_STRB_WIDTH = (REG_DATA_WIDTH/8),
    // Register block base address
    parameter RB_BASE_ADDR = 0,
    // Register block next block address
    parameter RB_NEXT_PTR = 0,
    // Width of AXI lite data bus in bits
    parameter AXIL_DATA_WIDTH = 32,
    // Width of AXI lite address bus in bits
    parameter AXIL_ADDR_WIDTH = $clog2(PORTS)+INDIR_TBL_ADDR_WIDTH+2,
    // Width of AXI lite wstrb (width of data bus in words)
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    // Base address of AXI lite interface
    parameter AXIL_BASE_ADDR = 0
)
(
    input  wire                          clk,
    input  wire                          rst,

    /*
     * Register interface
     */
    input  wire [REG_ADDR_WIDTH-1:0]     reg_wr_addr,
    input  wire [REG_DATA_WIDTH-1:0]     reg_wr_data,
    input  wire [REG_STRB_WIDTH-1:0]     reg_wr_strb,
    input  wire                          reg_wr_en,
    output wire                          reg_wr_wait,
    output wire                          reg_wr_ack,
    input  wire [REG_ADDR_WIDTH-1:0]     reg_rd_addr,
    input  wire                          reg_rd_en,
    output wire [REG_DATA_WIDTH-1:0]     reg_rd_data,
    output wire                          reg_rd_wait,
    output wire                          reg_rd_ack,

    /*
     * AXI-Lite slave interface (indirection table)
     */
    input  wire [AXIL_ADDR_WIDTH-1:0]    s_axil_awaddr,
    input  wire [2:0]                    s_axil_awprot,
    input  wire                          s_axil_awvalid,
    output wire                          s_axil_awready,
    input  wire [AXIL_DATA_WIDTH-1:0]    s_axil_wdata,
    input  wire [AXIL_STRB_WIDTH-1:0]    s_axil_wstrb,
    input  wire                          s_axil_wvalid,
    output wire                          s_axil_wready,
    output wire [1:0]                    s_axil_bresp,
    output wire                          s_axil_bvalid,
    input  wire                          s_axil_bready,
    input  wire [AXIL_ADDR_WIDTH-1:0]    s_axil_araddr,
    input  wire [2:0]                    s_axil_arprot,
    input  wire                          s_axil_arvalid,
    output wire                          s_axil_arready,
    output wire [AXIL_DATA_WIDTH-1:0]    s_axil_rdata,
    output wire [1:0]                    s_axil_rresp,
    output wire                          s_axil_rvalid,
    input  wire                          s_axil_rready,

    /*
     * Request input
     */
    input  wire [ID_WIDTH-1:0]           req_id,
    input  wire [DEST_WIDTH-1:0]         req_dest,
    input  wire [HASH_WIDTH-1:0]         req_hash,
    input  wire [TAG_WIDTH-1:0]          req_tag,
    input  wire                          req_valid,

    /*
     * Response output
     */
    output wire [QUEUE_INDEX_WIDTH-1:0]  resp_queue,
    output wire [TAG_WIDTH-1:0]          resp_tag,
    output wire                          resp_valid
);

localparam CL_PORTS = $clog2(PORTS);

localparam FULL_TABLE_ADDR_WIDTH = CL_PORTS+INDIR_TBL_ADDR_WIDTH;

localparam RBB = RB_BASE_ADDR & {REG_ADDR_WIDTH{1'b1}};

// check configuration
initial begin
    if (REG_DATA_WIDTH != 32) begin
        $error("Error: Register interface width must be 32 (instance %m)");
        $finish;
    end

    if (REG_STRB_WIDTH * 8 != REG_DATA_WIDTH) begin
        $error("Error: Register interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end

    if (REG_ADDR_WIDTH < $clog2(16 + PORTS*16)) begin
        $error("Error: Register address width too narrow (instance %m)");
        $finish;
    end

    if (RB_NEXT_PTR >= RB_BASE_ADDR && RB_NEXT_PTR < RB_BASE_ADDR + 16 + PORTS*16) begin
        $error("Error: RB_NEXT_PTR overlaps block (instance %m)");
        $finish;
    end

    if (AXIL_DATA_WIDTH != 32) begin
        $error("Error: AXI lite interface width must be 32 (instance %m)");
        $finish;
    end

    if (AXIL_STRB_WIDTH * 8 != AXIL_DATA_WIDTH) begin
        $error("Error: AXI lite interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end

    if (AXIL_ADDR_WIDTH < CL_PORTS+INDIR_TBL_ADDR_WIDTH+2) begin
        $error("Error: AXI lite address width too narrow (instance %m)");
        $finish;
    end
end

(* ramstyle = "no_rw_check" *)
reg [AXIL_DATA_WIDTH-1:0] indir_tbl_mem[(2**FULL_TABLE_ADDR_WIDTH)-1:0];

// control registers
reg reg_wr_ack_reg = 1'b0;
reg [REG_DATA_WIDTH-1:0] reg_rd_data_reg = 0;
reg reg_rd_ack_reg = 1'b0;

reg [QUEUE_INDEX_WIDTH-1:0] offset_reg[PORTS-1:0];
reg [PORTS-1:0] app_direct_en_reg = 0;
reg [QUEUE_INDEX_WIDTH-1:0] hash_mask_reg[PORTS-1:0];
reg [QUEUE_INDEX_WIDTH-1:0] app_mask_reg[PORTS-1:0];

reg [FULL_TABLE_ADDR_WIDTH-1:0] indir_tbl_index_reg = 0;
reg [QUEUE_INDEX_WIDTH-1:0] indir_tbl_queue_reg = 0;
reg [DEST_WIDTH-1:0] req_dest_d1_reg = 0, req_dest_d2_reg = 0;
reg [TAG_WIDTH-1:0] req_tag_d1_reg = 0, req_tag_d2_reg = 0;
reg req_valid_d1_reg = 0, req_valid_d2_reg = 0;

reg [QUEUE_INDEX_WIDTH-1:0] resp_queue_reg = 0;
reg [TAG_WIDTH-1:0] resp_tag_reg = 0;
reg resp_valid_reg = 1'b0;

assign reg_wr_wait = 1'b0;
assign reg_wr_ack = reg_wr_ack_reg;
assign reg_rd_data = reg_rd_data_reg;
assign reg_rd_wait = 1'b0;
assign reg_rd_ack = reg_rd_ack_reg;

assign resp_queue = resp_queue_reg;
assign resp_tag = resp_tag_reg;
assign resp_valid = resp_valid_reg;

integer i, j;

initial begin
    for (i = 0; i < PORTS; i = i + 1) begin
        offset_reg[i] = 0;
        hash_mask_reg[i] = 0;
        app_mask_reg[i] = 0;
    end

    // two nested loops for smaller number of iterations per loop
    // workaround for synthesizer complaints about large loop counts
    for (i = 0; i < 2**FULL_TABLE_ADDR_WIDTH; i = i + 2**(FULL_TABLE_ADDR_WIDTH/2)) begin
        for (j = i; j < i + 2**(FULL_TABLE_ADDR_WIDTH/2); j = j + 1) begin
            indir_tbl_mem[j] = 0;
        end
    end
end

integer k;

always @(posedge clk) begin
    reg_wr_ack_reg <= 1'b0;
    reg_rd_data_reg <= 0;
    reg_rd_ack_reg <= 1'b0;

    if (reg_wr_en && !reg_wr_ack_reg) begin
        // write operation
        reg_wr_ack_reg <= 1'b0;
        for (k = 0; k < PORTS; k = k + 1) begin
            if ({reg_wr_addr >> 2, 2'b00} == RBB+7'h14 + k*16) begin
                hash_mask_reg[k] <= reg_wr_data;
                reg_wr_ack_reg <= 1'b1;
            end
            if ({reg_wr_addr >> 2, 2'b00} == RBB+7'h18 + k*16) begin
                app_mask_reg[k] <= reg_wr_data[30:0];
                app_direct_en_reg[k] <= reg_wr_data[31];
                reg_wr_ack_reg <= 1'b1;
            end
        end
    end

    if (reg_rd_en && !reg_rd_ack_reg) begin
        // read operation
        reg_rd_ack_reg <= 1'b1;
        case ({reg_rd_addr >> 2, 2'b00})
            RBB+7'h00: reg_rd_data_reg <= 32'h0000C090;  // Type
            RBB+7'h04: reg_rd_data_reg <= 32'h00000200;  // Version
            RBB+7'h08: reg_rd_data_reg <= RB_NEXT_PTR;   // Next header
            RBB+7'h0C: begin
                reg_rd_data_reg[7:0]  <= PORTS;
                reg_rd_data_reg[15:8] <= INDIR_TBL_ADDR_WIDTH;
            end
            default: reg_rd_ack_reg <= 1'b0;
        endcase
        for (k = 0; k < PORTS; k = k + 1) begin
            if ({reg_rd_addr >> 2, 2'b00} == RBB+7'h10 + k*16) begin
                reg_rd_data_reg <= AXIL_BASE_ADDR + 2**(INDIR_TBL_ADDR_WIDTH+2)*k;
                reg_rd_ack_reg <= 1'b1;
            end
            if ({reg_rd_addr >> 2, 2'b00} == RBB+7'h14 + k*16) begin
                reg_rd_data_reg <= hash_mask_reg[k];
                reg_rd_ack_reg <= 1'b1;
            end
            if ({reg_rd_addr >> 2, 2'b00} == RBB+7'h18 + k*16) begin
                reg_rd_data_reg[30:0] <= app_mask_reg[k];
                reg_rd_data_reg[31] <= app_direct_en_reg[k];
                reg_rd_ack_reg <= 1'b1;
            end
        end
    end

    indir_tbl_index_reg[INDIR_TBL_ADDR_WIDTH-1:0] <= (req_dest & app_mask_reg[req_id]) + (req_hash & hash_mask_reg[req_id]);
    if (PORTS > 1) begin
        indir_tbl_index_reg[INDIR_TBL_ADDR_WIDTH +: CL_PORTS] <= req_id;
    end
    req_dest_d1_reg <= req_dest;
    req_dest_d1_reg[DEST_WIDTH-1] <= req_dest[DEST_WIDTH-1] & app_direct_en_reg[req_id];
    req_tag_d1_reg <= req_tag;
    req_valid_d1_reg <= req_valid;

    indir_tbl_queue_reg <= indir_tbl_mem[indir_tbl_index_reg];
    req_dest_d2_reg <= req_dest_d1_reg;
    req_tag_d2_reg <= req_tag_d1_reg;
    req_valid_d2_reg <= req_valid_d1_reg;

    if (req_dest_d2_reg[DEST_WIDTH-1]) begin
        resp_queue_reg <= req_dest_d2_reg;
    end else begin
        resp_queue_reg <= indir_tbl_queue_reg;
    end
    resp_tag_reg <= req_tag_d2_reg;
    resp_valid_reg <= req_valid_d2_reg;

    if (rst) begin
        reg_wr_ack_reg <= 1'b0;
        reg_rd_ack_reg <= 1'b0;

        app_direct_en_reg <= 0;
        for (k = 0; k < PORTS; k = k + 1) begin
            offset_reg[k] <= 0;
            hash_mask_reg[k] <= 0;
            app_mask_reg[k] <= 0;
        end

        req_valid_d1_reg <= 1'b0;
        req_valid_d2_reg <= 1'b0;

        resp_valid_reg <= 1'b0;
    end
end

// AXI lite interface
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
reg [AXIL_DATA_WIDTH-1:0] s_axil_rdata_pipe_reg = {AXIL_DATA_WIDTH{1'b0}};
reg s_axil_rvalid_pipe_reg = 1'b0;

wire [FULL_TABLE_ADDR_WIDTH-1:0] s_axil_awaddr_valid = s_axil_awaddr >> 2;
wire [FULL_TABLE_ADDR_WIDTH-1:0] s_axil_araddr_valid = s_axil_araddr >> 2;

assign s_axil_awready = s_axil_awready_reg;
assign s_axil_wready = s_axil_wready_reg;
assign s_axil_bresp = 2'b00;
assign s_axil_bvalid = s_axil_bvalid_reg;
assign s_axil_arready = s_axil_arready_reg;
assign s_axil_rdata = s_axil_rdata_pipe_reg;
assign s_axil_rresp = 2'b00;
assign s_axil_rvalid = s_axil_rvalid_pipe_reg;

always @* begin
    mem_wr_en = 1'b0;
    mem_rd_en = 1'b0;

    last_read_next = last_read_reg;

    s_axil_awready_next = 1'b0;
    s_axil_wready_next = 1'b0;
    s_axil_bvalid_next = s_axil_bvalid_reg && !s_axil_bready;

    s_axil_arready_next = 1'b0;
    s_axil_rvalid_next = s_axil_rvalid_reg && !(s_axil_rready || !s_axil_rvalid_pipe_reg);

    write_eligible = s_axil_awvalid && s_axil_wvalid && (!s_axil_bvalid || s_axil_bready) && (!s_axil_awready && !s_axil_wready);
    read_eligible = s_axil_arvalid && (!s_axil_rvalid || s_axil_rready || !s_axil_rvalid_pipe_reg) && (!s_axil_arready);

    if (write_eligible && (!read_eligible || last_read_reg)) begin
        last_read_next = 1'b0;

        s_axil_awready_next = 1'b1;
        s_axil_wready_next = 1'b1;
        s_axil_bvalid_next = 1'b1;

        mem_wr_en = 1'b1;
    end else if (read_eligible) begin
        last_read_next = 1'b1;

        s_axil_arready_next = 1'b1;
        s_axil_rvalid_next = 1'b1;

        mem_rd_en = 1'b1;
    end
end

always @(posedge clk) begin
    last_read_reg <= last_read_next;

    s_axil_awready_reg <= s_axil_awready_next;
    s_axil_wready_reg <= s_axil_wready_next;
    s_axil_bvalid_reg <= s_axil_bvalid_next;

    s_axil_arready_reg <= s_axil_arready_next;
    s_axil_rvalid_reg <= s_axil_rvalid_next;

    if (mem_rd_en) begin
        s_axil_rdata_reg <= indir_tbl_mem[s_axil_araddr_valid];
    end else begin
        if (mem_wr_en) begin
            indir_tbl_mem[s_axil_awaddr_valid] <= s_axil_wdata;
        end
    end

    if (!s_axil_rvalid_pipe_reg || s_axil_rready) begin
        s_axil_rdata_pipe_reg <= s_axil_rdata_reg;
        s_axil_rvalid_pipe_reg <= s_axil_rvalid_reg;
    end

    if (rst) begin
        last_read_reg <= 1'b0;

        s_axil_awready_reg <= 1'b0;
        s_axil_wready_reg <= 1'b0;
        s_axil_bvalid_reg <= 1'b0;

        s_axil_arready_reg <= 1'b0;
        s_axil_rvalid_reg <= 1'b0;
        s_axil_rvalid_pipe_reg <= 1'b0;
    end
end

endmodule

`resetall
