`define APP_CUSTOM_INTF_PARAMS \
    AXIL_APP_CUSTOM_DATA_WIDTH = 32, \
    AXIL_APP_CUSTOM_STRB_WIDTH = (AXIL_APP_CUSTOM_DATA_WIDTH/8),

// List of custom interface wires for app, consisting of port direction, dimension (can be empty for regular 1-bit wire) and name
`define APP_CUSTOM_INTF_WIRES(EXPR) \
    EXPR(output,   [AXIL_APP_CTRL_ADDR_WIDTH-1:0], m_axil_app_ctrl_awaddr) \
    EXPR(output,                            [2:0], m_axil_app_ctrl_awprot) \
    EXPR(output,                                 , m_axil_app_ctrl_awvalid) \
    EXPR(input,                                  , m_axil_app_ctrl_awready) \
    EXPR(output, [AXIL_APP_CUSTOM_DATA_WIDTH-1:0], m_axil_app_ctrl_wdata) \
    EXPR(output, [AXIL_APP_CUSTOM_STRB_WIDTH-1:0], m_axil_app_ctrl_wstrb) \
    EXPR(output,                                 , m_axil_app_ctrl_wvalid) \
    EXPR(input,                                  , m_axil_app_ctrl_wready) \
    EXPR(input,                             [1:0], m_axil_app_ctrl_bresp) \
    EXPR(input,                                  , m_axil_app_ctrl_bvalid) \
    EXPR(output,                                 , m_axil_app_ctrl_bready) \
    EXPR(output,   [AXIL_APP_CTRL_ADDR_WIDTH-1:0], m_axil_app_ctrl_araddr) \
    EXPR(output,                            [2:0], m_axil_app_ctrl_arprot) \
    EXPR(output,                                 , m_axil_app_ctrl_arvalid) \
    EXPR(input,                                  , m_axil_app_ctrl_arready) \
    EXPR(input,  [AXIL_APP_CUSTOM_DATA_WIDTH-1:0], m_axil_app_ctrl_rdata) \
    EXPR(input,                             [1:0], m_axil_app_ctrl_rresp) \
    EXPR(input,                                  , m_axil_app_ctrl_rvalid) \
    EXPR(output,                                 , m_axil_app_ctrl_rready)

// create wire declaration from signal list
`define WIRE_DECL(DIR, DIM, NAME) \
    wire DIM NAME;

// create port declaration from signal list
`define PORT_DECL(DIR, DIM, NAME) \
    DIR wire DIM NAME,

// create port mapping from signal list
`define PORT_MAP(DIR, DIM, NAME) \
    .NAME(NAME),

// define convenience macros
`define APP_CUSTOM_INTF_WIRE_DECL `APP_CUSTOM_INTF_WIRES(`WIRE_DECL)
`define APP_CUSTOM_INTF_PORT_DECL `APP_CUSTOM_INTF_WIRES(`PORT_DECL)
`define APP_CUSTOM_INTF_PORT_MAP  `APP_CUSTOM_INTF_WIRES(`PORT_MAP)
