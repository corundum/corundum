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
 * Ultrascale PCIe configuration shim
 */
module pcie_us_cfg #
(
    parameter PF_COUNT = 1,
    parameter VF_COUNT = 0,
    parameter VF_OFFSET = 64,
    parameter F_COUNT = PF_COUNT+VF_COUNT,
    parameter READ_EXT_TAG_ENABLE = 1,
    parameter READ_MAX_READ_REQ_SIZE = 1,
    parameter READ_MAX_PAYLOAD_SIZE = 1,
    parameter PCIE_CAP_OFFSET = 12'h0C0
)
(
    input  wire                  clk,
    input  wire                  rst,

    /*
     * Configuration outputs
     */
    output wire [F_COUNT-1:0]    ext_tag_enable,
    output wire [F_COUNT*3-1:0]  max_read_request_size,
    output wire [F_COUNT*3-1:0]  max_payload_size,

    /*
     * Interface to Ultrascale PCIe IP core
     */
    output wire [9:0]            cfg_mgmt_addr,
    output wire [7:0]            cfg_mgmt_function_number,
    output wire                  cfg_mgmt_write,
    output wire [31:0]           cfg_mgmt_write_data,
    output wire [3:0]            cfg_mgmt_byte_enable,
    output wire                  cfg_mgmt_read,
    input  wire [31:0]           cfg_mgmt_read_data,
    input  wire                  cfg_mgmt_read_write_done
);

localparam READ_REV_CTRL = READ_EXT_TAG_ENABLE || READ_MAX_READ_REQ_SIZE || READ_MAX_PAYLOAD_SIZE;

localparam DEV_CTRL_OFFSET = PCIE_CAP_OFFSET + 12'h008;

reg [F_COUNT-1:0] ext_tag_enable_reg = {F_COUNT{1'b0}}, ext_tag_enable_next;
reg [F_COUNT*3-1:0] max_read_request_size_reg = {F_COUNT{3'd0}}, max_read_request_size_next;
reg [F_COUNT*3-1:0] max_payload_size_reg = {F_COUNT{3'd0}}, max_payload_size_next;

reg [9:0] cfg_mgmt_addr_reg = 10'd0, cfg_mgmt_addr_next;
reg [7:0] cfg_mgmt_function_number_reg = 8'd0, cfg_mgmt_function_number_next;
reg cfg_mgmt_write_reg = 1'b0, cfg_mgmt_write_next;
reg [31:0] cfg_mgmt_write_data_reg = 32'd0, cfg_mgmt_write_data_next;
reg [3:0] cfg_mgmt_byte_enable_reg = 4'd0, cfg_mgmt_byte_enable_next;
reg cfg_mgmt_read_reg = 1'b0, cfg_mgmt_read_next;

reg [7:0] delay_reg = 8'hff, delay_next;
reg [7:0] func_cnt_reg = 8'd0, func_cnt_next;

assign ext_tag_enable = ext_tag_enable_reg;
assign max_read_request_size = max_read_request_size_reg;
assign max_payload_size = max_payload_size_reg;

assign cfg_mgmt_addr = cfg_mgmt_addr_reg;
assign cfg_mgmt_function_number = cfg_mgmt_function_number_reg;
assign cfg_mgmt_write = cfg_mgmt_write_reg;
assign cfg_mgmt_write_data = cfg_mgmt_write_data_reg;
assign cfg_mgmt_byte_enable = cfg_mgmt_byte_enable_reg;
assign cfg_mgmt_read = cfg_mgmt_read_reg;

always @* begin
    ext_tag_enable_next = ext_tag_enable_reg;
    max_read_request_size_next = max_read_request_size_reg;
    max_payload_size_next = max_payload_size_reg;

    cfg_mgmt_addr_next = cfg_mgmt_addr_reg;
    cfg_mgmt_function_number_next = cfg_mgmt_function_number_reg;
    cfg_mgmt_write_next = cfg_mgmt_write_reg && !cfg_mgmt_read_write_done;
    cfg_mgmt_write_data_next = cfg_mgmt_write_data_reg;
    cfg_mgmt_byte_enable_next = cfg_mgmt_byte_enable_reg;
    cfg_mgmt_read_next = cfg_mgmt_read_reg && !cfg_mgmt_read_write_done;

    delay_next = delay_reg;
    func_cnt_next = func_cnt_reg;

    if (delay_reg > 0) begin
        delay_next = delay_reg - 1;
    end else begin
        cfg_mgmt_addr_next = DEV_CTRL_OFFSET >> 2;
        cfg_mgmt_read_next = 1'b1;
        if (cfg_mgmt_read_write_done) begin
            cfg_mgmt_read_next = 1'b0;
            
            ext_tag_enable_next[func_cnt_reg] = cfg_mgmt_read_data[8];
            max_read_request_size_next[func_cnt_reg*3 +: 3] = cfg_mgmt_read_data[14:12];
            max_payload_size_next[func_cnt_reg*3 +: 3] = cfg_mgmt_read_data[7:5];

            if (func_cnt_reg == F_COUNT-1) begin
                func_cnt_next = 0;
                cfg_mgmt_function_number_next = 0;
            end else if (func_cnt_reg == PF_COUNT-1) begin
                func_cnt_next = func_cnt_reg + 1;
                cfg_mgmt_function_number_next = VF_OFFSET;
            end else begin
                func_cnt_next = func_cnt_reg + 1;
                cfg_mgmt_function_number_next = cfg_mgmt_function_number_reg + 1;
            end

            delay_next = 8'hff;
        end
    end
end

always @(posedge clk) begin
    if (rst) begin
        ext_tag_enable_reg <= {F_COUNT{1'b0}};
        max_read_request_size_reg <= {F_COUNT{3'd0}};
        max_payload_size_reg <= {F_COUNT{3'd0}};

        cfg_mgmt_addr_reg <= 10'd0;
        cfg_mgmt_function_number_reg <= 8'd0;
        cfg_mgmt_write_reg <= 1'b0;
        cfg_mgmt_read_reg <= 1'b0;

        delay_reg <= 8'hff;
        func_cnt_reg <= 8'd0;
    end else begin
        ext_tag_enable_reg <= ext_tag_enable_next;
        max_read_request_size_reg <= max_read_request_size_next;
        max_payload_size_reg <= max_payload_size_next;

        cfg_mgmt_addr_reg <= cfg_mgmt_addr_next;
        cfg_mgmt_function_number_reg <= cfg_mgmt_function_number_next;
        cfg_mgmt_write_reg <= cfg_mgmt_write_next;
        cfg_mgmt_read_reg <= cfg_mgmt_read_next;

        delay_reg <= delay_next;
        func_cnt_reg <= func_cnt_next;
    end
    
    cfg_mgmt_write_data_reg <= cfg_mgmt_write_data_next;
    cfg_mgmt_byte_enable_reg <= cfg_mgmt_byte_enable_next;

end

endmodule

`resetall
