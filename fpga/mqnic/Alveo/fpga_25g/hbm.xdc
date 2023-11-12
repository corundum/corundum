# force debug hub to use HBM APB clock to prevent CDC issues
connect_debug_port dbg_hub/clk [get_nets */*/APB_0_PCLK]
