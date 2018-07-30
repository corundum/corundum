# Verilog AXI Components Readme

For more information and updates: http://alexforencich.com/wiki/en/verilog/axi/start

GitHub repository: https://github.com/alexforencich/verilog-axi

## Introduction

Collection of AXI4 bus components.  Most components are fully parametrizable
in interface widths.  Includes full MyHDL testbench with intelligent bus
cosimulation endpoints.

## Documentation

### axi_ram module

RAM with parametrizable data and address interface widths. Supports FIXED and
INCR burst types as well as narrow bursts.  

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
    USER_WIDTH           : width of *user signals

### Source Files

    rtl/arbiter.v                   : Parametrizable arbiter
    rtl/axi_ram.v                   : Parametrizable AXI RAM
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

Running the included testbenches requires MyHDL and Icarus Verilog.  Make sure
that myhdl.vpi is installed properly for cosimulation to work correctly.  The
testbenches can be run with a Python test runner like nose or py.test, or the
individual test scripts can be run with python directly.

### Testbench Files

    tb/axi.py            : MyHDL AXI4 master and memory BFM
