# Verilog AXI Components Readme

[![Build Status](https://github.com/alexforencich/verilog-axi/workflows/Regression%20Tests/badge.svg?branch=master)](https://github.com/alexforencich/verilog-axi/actions/)

For more information and updates: http://alexforencich.com/wiki/en/verilog/axi/start

GitHub repository: https://github.com/alexforencich/verilog-axi

## Introduction

Collection of AXI4 and AXI4 lite bus components.  Most components are fully
parametrizable in interface widths.  Includes full cocotb testbenches that
utilize [cocotbext-axi](https://github.com/alexforencich/cocotbext-axi).

## Documentation

### `axi_adapter` module

AXI width adapter module with parametrizable data and address interface widths.
Supports INCR burst types and narrow bursts.  Wrapper for `axi_adapter_rd` and `axi_adapter_wr`.

### `axi_adapter_rd` module

AXI width adapter module with parametrizable data and address interface widths.
Supports INCR burst types and narrow bursts.

### `axi_adapter_wr` module

AXI width adapter module with parametrizable data and address interface widths.
Supports INCR burst types and narrow bursts.

### `axi_axil_adapter` module

AXI to AXI lite converter and width adapter module with parametrizable data
and address interface widths.  Supports INCR burst types and narrow bursts.
Wrapper for `axi_axil_adapter_rd` and `axi_axil_adapter_wr`.

### `axi_axil_adapter_rd` module

AXI to AXI lite converter and width adapter module with parametrizable data
and address interface widths.  Supports INCR burst types and narrow bursts.

### `axi_axil_adapter_wr` module

AXI to AXI lite converter and width adapter module with parametrizable data
and address interface widths.  Supports INCR burst types and narrow bursts.

### `axi_cdma` module

AXI to AXI DMA engine with parametrizable data and address interface widths.
Generates full-width INCR bursts only, with parametrizable maximum burst
length.  Supports unaligned transfers, which can be disabled via parameter
to save on resource consumption.

### `axi_cdma_desc_mux` module

Descriptor multiplexer/demultiplexer for AXI CDMA module.  Enables sharing the
AXI CDMA module between multiple request sources, interleaving requests and
distributing responses.

### `axi_crossbar` module

AXI nonblocking crossbar interconnect with parametrizable data and address
interface widths and master and slave interface counts.  Supports all burst
types.  Fully nonblocking with completely separate read and write paths;
ID-based transaction ordering protection logic; and per-port address decode,
admission control, and decode error handling.  Wrapper for `axi_crossbar_rd`
and `axi_crossbar_wr`.

Wrappers can generated with `axi_crossbar_wrap.py`.

### `axi_crossbar_addr` module

Address decode and admission control module for AXI nonblocking crossbar interconnect.

### `axi_crossbar_rd` module

AXI nonblocking crossbar interconnect with parametrizable data and address
interface widths and master and slave interface counts.  Read interface only.
Supports all burst types.  Fully nonblocking with completely separate read and
write paths; ID-based transaction ordering protection logic; and per-port
address decode, admission control, and decode error handling.

### `axi_crossbar_wr` module

AXI nonblocking crossbar interconnect with parametrizable data and address
interface widths and master and slave interface counts.  Write interface only.
Supports all burst types.  Fully nonblocking with completely separate read and
write paths; ID-based transaction ordering protection logic; and per-port
address decode, admission control, and decode error handling.

### `axi_dma` module

AXI to AXI stream DMA engine with parametrizable data and address interface
widths.  Generates full-width INCR bursts only, with parametrizable maximum
burst length.  Supports unaligned transfers, which can be disabled via
parameter to save on resource consumption.  Wrapper for `axi_dma_rd` and
`axi_dma_wr`.

### `axi_dma_desc_mux` module

Descriptor multiplexer/demultiplexer for AXI DMA module.  Enables sharing the
AXI DMA module between multiple request sources, interleaving requests and
distributing responses.

### `axi_dma_rd` module

AXI to AXI stream DMA engine with parametrizable data and address interface
widths.  Generates full-width INCR bursts only, with parametrizable maximum
burst length.  Supports unaligned transfers, which can be disabled via
parameter to save on resource consumption.

### `axi_dma_wr` module

AXI stream to AXI DMA engine with parametrizable data and address interface
widths.  Generates full-width INCR bursts only, with parametrizable maximum
burst length.  Supports unaligned transfers, which can be disabled via
parameter to save on resource consumption.

### `axi_dp_ram` module

AXI dual-port RAM with parametrizable data and address interface widths.
Supports FIXED and INCR burst types as well as narrow bursts.

### `axi_fifo` module

AXI FIFO with parametrizable data and address interface widths.  Supports all
burst types.  Optionally can delay the address channel until either the write
data is completely shifted into the FIFO or the read data FIFO has enough
capacity to fit the whole burst.  Wrapper for `axi_fifo_rd` and `axi_fifo_wr`.

### `axi_fifo_rd` module

AXI FIFO with parametrizable data and address interface widths.  AR and R
channels only.  Supports all burst types.  Optionally can delay the address
channel until either the read data FIFO is empty or has enough capacity to fit
the whole burst.

### `axi_fifo_wr` module

AXI FIFO with parametrizable data and address interface widths.  WR, W, and B
channels only.  Supports all burst types.  Optionally can delay the address
channel until the write data is shifted completely into the write data FIFO,
or the current burst completely fills the write data FIFO.

### `axi_interconnect` module

AXI shared interconnect with parametrizable data and address interface
widths and master and slave interface counts.  Supports all burst types.
Small in area, but does not support concurrent operations.

Wrappers can generated with `axi_interconnect_wrap.py`.

### `axi_ram` module

AXI RAM with parametrizable data and address interface widths.  Supports FIXED
and INCR burst types as well as narrow bursts.

### `axi_ram_rd_if` module

AXI RAM read interface with parametrizable data and address interface widths.
Handles bursts and presents a simplified internal memory interface.  Supports
FIXED and INCR burst types as well as narrow bursts.

### `axi_ram_wr_if` module

AXI RAM write interface with parametrizable data and address interface widths.
Handles bursts and presents a simplified internal memory interface.  Supports
FIXED and INCR burst types as well as narrow bursts.

### `axi_ram_wr_rd_if` module

AXI RAM read/write interface with parametrizable data and address interface
widths.  Handles bursts and presents a simplified internal memory interface.
Supports FIXED and INCR burst types as well as narrow bursts.  Wrapper for
`axi_ram_rd_if` and `axi_ram_wr_if`.

### `axi_register` module

AXI register with parametrizable data and address interface widths.  Supports
all burst types.  Inserts simple buffers or skid buffers into all channels.
Channel register types can be individually changed or bypassed.  Wrapper for
`axi_register_rd` and `axi_register_wr`.

### `axi_register_rd` module

AXI register with parametrizable data and address interface widths.  AR and R
channels only.  Supports all burst types.  Inserts simple buffers or skid
buffers into all channels.  Channel register types can be individually changed
or bypassed.

### `axi_register_wr` module

AXI register with parametrizable data and address interface widths.  WR, W,
and B channels only.  Supports all burst types.  Inserts simple buffers or
skid buffers into all channels.  Channel register types can be individually
changed or bypassed.

### `axil_adapter` module

AXI lite width adapter module with parametrizable data and address interface
widths.  Wrapper for `axi_adapter_rd` and `axi_adapter_wr`.

### `axil_adapter_rd` module

AXI lite width adapter module with parametrizable data and address interface
widths.

### `axil_adapter_wr` module

AXI lite width adapter module with parametrizable data and address interface
widths.

### `axil_cdc` module

AXI lite clock domain crossing module with parametrizable data and address
interface widths.  Wrapper for `axi_cdc_rd` and `axi_cdc_wr`.

### `axil_cdc_rd` module

AXI lite clock domain crossing module with parametrizable data and address
interface widths.

### `axil_cdc_wr` module

AXI lite clock domain crossing module with parametrizable data and address
interface widths.

### `axil_crossbar` module

AXI lite nonblocking crossbar interconnect with parametrizable data and address
interface widths and master and slave interface counts.  Fully nonblocking
with completely separate read and write paths; FIFO-based transaction ordering
protection logic; and per-port address decode, admission control, and decode
error handling.  Wrapper for `axil_crossbar_rd` and `axil_crossbar_wr`.

Wrappers can generated with `axil_crossbar_wrap.py`.

### `axil_crossbar_addr` module

Address decode and admission control module for AXI lite nonblocking crossbar interconnect.

### `axil_crossbar_rd` module

AXI lite nonblocking crossbar interconnect with parametrizable data and address
interface widths and master and slave interface counts.  Read interface only.
Fully nonblocking with completely separate read and write paths; FIFO-based
transaction ordering protection logic; and per-port address decode, admission
control, and decode error handling.

### `axil_crossbar_wr` module

AXI lite nonblocking crossbar interconnect with parametrizable data and address
interface widths and master and slave interface counts.  Write interface only.
Fully nonblocking with completely separate read and write paths; FIFO-based
transaction ordering protection logic; and per-port address decode, admission
control, and decode error handling.

### `axil_interconnect` module

AXI lite shared interconnect with parametrizable data and address interface
widths and master and slave interface counts.  Small in area, but does not
support concurrent operations.

Wrappers can generated with `axil_interconnect_wrap.py`.

### `axil_ram` module

AXI lite RAM with parametrizable data and address interface widths.

### `axil_reg_if` module

AXI lite register interface with parametrizable data and address interface
widths.  Can be used to assemble a set of control registers across multiple
modules and hierarchy levels without complicated arbitration logic.  Wrapper
for `axil_reg_if_rd` and `axil_reg_if_wr`.

### `axil_reg_if_rd` module

AXI lite register interface with parametrizable data and address interface
widths.  Read direction only.  Can be used to assemble a set of control
registers across multiple modules and hierarchy levels without complicated
arbitration logic.

### `axil_reg_if_wr` module

AXI lite register interface with parametrizable data and address interface
widths.  Write direction only.  Can be used to assemble a set of control
registers across multiple modules and hierarchy levels without complicated
arbitration logic.

### `axil_register` module

AXI lite register with parametrizable data and address interface widths.
Inserts skid buffers into all channels.  Channel registers can be individually
bypassed.  Wrapper for `axil_register_rd` and `axil_register_wr`.

### `axil_register_rd` module

AXI lite register with parametrizable data and address interface widths.  AR
and R channels only.  Inserts simple buffers into all channels.  Channel
registers can be individually bypassed.

### `axil_register_wr` module

AXI lite register with parametrizable data and address interface widths.  WR,
W, and B channels only.  Inserts simple buffers into all channels.  Channel
registers can be individually bypassed.

### Common signals

    awid     : Write address ID
    awaddr   : Write address
    awlen    : Write burst length
    awsize   : Write burst size
    awburst  : Write burst type
    awlock   : Write locking
    awcache  : Write cache handling
    awprot   : Write protection level
    awqos    : Write QoS setting
    awregion : Write region
    awuser   : Write user sideband signal
    awvalid  : Write address valid
    awready  : Write address ready (from slave)
    wdata    : Write data
    wstrb    : Write data strobe (byte select)
    wlast    : Write data last transfer in burst
    wuser    : Write data user sideband signal
    wvalid   : Write data valid
    wready   : Write data ready (from slave)
    bid      : Write response ID
    bresp    : Write response
    buser    : Write response user sideband signal
    bvalid   : Write response valid
    bready   : Write response ready (from master)
    arid     : Read address ID
    araddr   : Read address
    arlen    : Read burst length
    arsize   : Read burst size
    arburst  : Read burst type
    arlock   : Read locking
    arcache  : Read cache handling
    arprot   : Read protection level
    arqos    : Read QoS setting
    arregion : Read region
    aruser   : Read user sideband signal
    arvalid  : Read address valid
    arready  : Read address ready (from slave)
    rid      : Read data ID
    rdata    : Read data
    rresp    : Read response
    rlast    : Read data last transfer in burst
    ruser    : Read data user sideband signal
    rvalid   : Read response valid
    rready   : Read response ready (from master)

### Common parameters

    ADDR_WIDTH           : width of awaddr and araddr signals
    DATA_WIDTH           : width of wdata and rdata signals
    STRB_WIDTH           : width of wstrb signal
    ID_WIDTH             : width of *id signals
    AWUSER_ENABLE        : enable awuser signal
    AWUSER_WIDTH         : width of awuser signal
    WUSER_ENABLE         : enable wuser signal
    WUSER_WIDTH          : width of wuser signal
    BUSER_ENABLE         : enable buser signal
    BUSER_WIDTH          : width of buser signal
    ARUSER_ENABLE        : enable aruser signal
    ARUSER_WIDTH         : width of aruser signal
    RUSER_ENABLE         : enable ruser signal
    RUSER_WIDTH          : width of ruser signal

### Source Files

    rtl/arbiter.v                   : Parametrizable arbiter
    rtl/axi_adapter.v               : AXI lite width converter
    rtl/axi_adapter_rd.v            : AXI lite width converter (read)
    rtl/axi_adapter_wr.v            : AXI lite width converter (write)
    rtl/axi_axil_adapter.v          : AXI to AXI lite converter
    rtl/axi_axil_adapter_rd.v       : AXI to AXI lite converter (read)
    rtl/axi_axil_adapter_wr.v       : AXI to AXI lite converter (write)
    rtl/axi_cdma.v                  : AXI central DMA engine
    rtl/axi_cdma_desc_mux.v         : AXI CDMA descriptor mux
    rtl/axi_crossbar.v              : AXI nonblocking crossbar interconnect
    rtl/axi_crossbar_addr.v         : AXI crossbar address module
    rtl/axi_crossbar_rd.v           : AXI crossbar interconnect (read)
    rtl/axi_crossbar_wr.v           : AXI crossbar interconnect (write)
    rtl/axi_dma.v                   : AXI DMA engine
    rtl/axi_dma_desc_mux.v          : AXI DMA descriptor mux
    rtl/axi_dma_rd.v                : AXI DMA engine (read)
    rtl/axi_dma_wr.v                : AXI DMA engine (write)
    rtl/axi_dp_ram.v                : AXI dual-port RAM
    rtl/axi_fifo.v                  : AXI FIFO
    rtl/axi_fifo_rd.v               : AXI FIFO (read)
    rtl/axi_fifo_wr.v               : AXI FIFO (write)
    rtl/axi_interconnect.v          : AXI shared interconnect
    rtl/axi_ram.v                   : AXI RAM
    rtl/axi_ram_rd_if.v             : AXI RAM read interface
    rtl/axi_ram_wr_if.v             : AXI RAM write interface
    rtl/axi_ram_wr_rd_if.v          : AXI RAM read/write interface
    rtl/axi_register.v              : AXI register
    rtl/axi_register_rd.v           : AXI register (read)
    rtl/axi_register_wr.v           : AXI register (write)
    rtl/axil_adapter.v              : AXI lite width converter
    rtl/axil_adapter_rd.v           : AXI lite width converter (read)
    rtl/axil_adapter_wr.v           : AXI lite width converter (write)
    rtl/axil_cdc.v                  : AXI lite CDC
    rtl/axil_cdc_rd.v               : AXI lite CDC (read)
    rtl/axil_cdc_wr.v               : AXI lite CDC (write)
    rtl/axil_crossbar.v             : AXI lite nonblocking crossbar interconnect
    rtl/axil_crossbar_addr.v        : AXI lite crossbar address module
    rtl/axil_crossbar_rd.v          : AXI lite crossbar interconnect (read)
    rtl/axil_crossbar_wr.v          : AXI lite crossbar interconnect (write)
    rtl/axil_interconnect.v         : AXI lite shared interconnect
    rtl/axil_ram.v                  : AXI lite RAM
    rtl/axil_reg_if.v               : AXI lite register interface
    rtl/axil_reg_if_rd.v            : AXI lite register interface (read)
    rtl/axil_reg_if_wr.v            : AXI lite register interface (write)
    rtl/axil_register.v             : AXI lite register
    rtl/axil_register_rd.v          : AXI lite register (read)
    rtl/axil_register_wr.v          : AXI lite register (write)
    rtl/priority_encoder.v          : Parametrizable priority encoder

### AXI4-Lite Interface Example

Write

                ___     ___     ___     ___     ___    
    clk     ___/   \___/   \___/   \___/   \___/   \___
                _______
    awid    XXXX_ID____XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
                _______
    awaddr  XXXX_ADDR__XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
                _______
    awlen   XXXX_00____XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
                _______
    awsize  XXXX_0_____XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
                _______
    awburst XXXX_0_____XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
                _______
    awprot  XXXX_PROT__XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
                _______
    awvalid ___/       \_______________________________
            ___________         _______________________
    awready            \_______/
                _______________
    wdata   XXXX_DATA__________XXXXXXXXXXXXXXXXXXXXXXXX
                _______________
    wstrb   XXXX_STRB__________XXXXXXXXXXXXXXXXXXXXXXXX
                _______________
    wvalid  ___/               \_______________________
                        _______
    wready  ___________/       \_______________________
                                        _______
    bid     XXXXXXXXXXXXXXXXXXXXXXXXXXXX_ID____XXXXXXXX
                                        _______
    bresp   XXXXXXXXXXXXXXXXXXXXXXXXXXXX_RESP__XXXXXXXX
                                        _______
    bvalid  ___________________________/       \_______
            ___________________________________________
    bready


Read

                ___     ___     ___     ___     ___    
    clk     ___/   \___/   \___/   \___/   \___/   \___
                _______
    arid    XXXX_ID____XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
                _______
    araddr  XXXX_ADDR__XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
                _______
    arlen   XXXX_00____XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
                _______
    arsize  XXXX_0_____XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
                _______
    arburst XXXX_0_____XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
                _______
    arprot  XXXX_PROT__XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
                _______
    arvalid ___/       \_______________________________
            ___________________________________________
    arready
                                        _______
    rid     XXXXXXXXXXXXXXXXXXXXXXXXXXXX_ID____XXXXXXXX
                                        _______
    rdata   XXXXXXXXXXXXXXXXXXXXXXXXXXXX_DATA__XXXXXXXX
                                        _______
    rresp   XXXXXXXXXXXXXXXXXXXXXXXXXXXX_RESP__XXXXXXXX
                                        _______
    rvalid  ___________________________/       \_______
            ___________________________________________
    rready


## Testing

Running the included testbenches requires [cocotb](https://github.com/cocotb/cocotb), [cocotbext-axi](https://github.com/alexforencich/cocotbext-axi), and [Icarus Verilog](http://iverilog.icarus.com/).  The testbenches can be run with pytest directly (requires [cocotb-test](https://github.com/themperek/cocotb-test)), pytest via tox, or via cocotb makefiles.
