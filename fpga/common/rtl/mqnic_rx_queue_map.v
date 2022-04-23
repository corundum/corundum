/*

Copyright 2022, The Regents of the University of California.
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
 * RX queue port mapping
 */
module mqnic_rx_queue_map #
(
    // Number of ports
    parameter PORTS = 1,
    // Queue index width
    parameter QUEUE_INDEX_WIDTH = 10,
    // AXI stream tid signal width (source port)
    parameter ID_WIDTH = $clog2(PORTS),
    // AXI stream tdest signal width (from application)
    parameter DEST_WIDTH = QUEUE_INDEX_WIDTH,
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
    parameter RB_NEXT_PTR = 0
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
end

// control registers
reg reg_wr_ack_reg = 1'b0;
reg [REG_DATA_WIDTH-1:0] reg_rd_data_reg = 0;
reg reg_rd_ack_reg = 1'b0;

reg [QUEUE_INDEX_WIDTH-1:0] offset_reg[PORTS-1:0];
reg [QUEUE_INDEX_WIDTH-1:0] hash_mask_reg[PORTS-1:0];
reg [QUEUE_INDEX_WIDTH-1:0] app_mask_reg[PORTS-1:0];

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

integer k;

initial begin
    for (k = 0; k < PORTS; k = k + 1) begin
        offset_reg[k] = 0;
        hash_mask_reg[k] = 0;
        app_mask_reg[k] = 0;
    end
end

always @(posedge clk) begin
    reg_wr_ack_reg <= 1'b0;
    reg_rd_data_reg <= 0;
    reg_rd_ack_reg <= 1'b0;

    if (reg_wr_en && !reg_wr_ack_reg) begin
        // write operation
        reg_wr_ack_reg <= 1'b0;
        for (k = 0; k < PORTS; k = k + 1) begin
            if ({reg_wr_addr >> 2, 2'b00} == RBB+7'h10 + k*16) begin
                offset_reg[k] <= reg_wr_data;
                reg_wr_ack_reg <= 1'b1;
            end
            if ({reg_wr_addr >> 2, 2'b00} == RBB+7'h14 + k*16) begin
                hash_mask_reg[k] <= reg_wr_data;
                reg_wr_ack_reg <= 1'b1;
            end
            if ({reg_wr_addr >> 2, 2'b00} == RBB+7'h18 + k*16) begin
                app_mask_reg[k] <= reg_wr_data;
                reg_wr_ack_reg <= 1'b1;
            end
        end
    end

    if (reg_rd_en && !reg_rd_ack_reg) begin
        // read operation
        reg_rd_ack_reg <= 1'b1;
        case ({reg_rd_addr >> 2, 2'b00})
            RBB+7'h00: reg_rd_data_reg <= 32'h0000C090;  // Type
            RBB+7'h04: reg_rd_data_reg <= 32'h00000100;  // Version
            RBB+7'h08: reg_rd_data_reg <= RB_NEXT_PTR;   // Next header
            RBB+7'h0C: reg_rd_data_reg <= PORTS;         // Port count
            default: reg_rd_ack_reg <= 1'b0;
        endcase
        for (k = 0; k < PORTS; k = k + 1) begin
            if ({reg_rd_addr >> 2, 2'b00} == RBB+7'h10 + k*16) begin
                reg_rd_data_reg <= offset_reg[k];
                reg_rd_ack_reg <= 1'b1;
            end
            if ({reg_rd_addr >> 2, 2'b00} == RBB+7'h14 + k*16) begin
                reg_rd_data_reg <= hash_mask_reg[k];
                reg_rd_ack_reg <= 1'b1;
            end
            if ({reg_rd_addr >> 2, 2'b00} == RBB+7'h18 + k*16) begin
                reg_rd_data_reg <= app_mask_reg[k];
                reg_rd_ack_reg <= 1'b1;
            end
        end
    end

    resp_queue_reg <= (req_dest & app_mask_reg[req_id]) + (req_hash & hash_mask_reg[req_id]) + offset_reg[req_id];
    resp_tag_reg <= req_tag;
    resp_valid_reg <= req_valid;

    if (rst) begin
        reg_wr_ack_reg <= 1'b0;
        reg_rd_ack_reg <= 1'b0;

        for (k = 0; k < PORTS; k = k + 1) begin
            offset_reg[k] <= 0;
            hash_mask_reg[k] <= 0;
            app_mask_reg[k] <= 0;
        end

        resp_valid_reg <= 1'b0;
    end
end

endmodule

`resetall
