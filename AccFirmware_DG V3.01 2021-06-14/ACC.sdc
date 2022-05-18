#**************************************************************
# Create Clock
#**************************************************************
derive_pll_clocks -create_base_clocks -use_net_name
derive_clock_uncertainty -add

set_false_path -from *signaltap*
set_false_path -to *signaltap*

create_clock -period "125.0 MHz" [get_ports clockIn.localOsc]
create_clock -period "125.0 MHz" [get_ports ETH_in.rx_clk]
#create_clock -period "48.0 MHz"  [get_ports clockIn.USB_IFCLK]

#Clock Generation for PLL clocks
#create_generated_clock -name   -source [get_nets {inst134|pll_new_inst|altera_pll_i|arriav_pll|divclk[0]}] -divide_by 1 -multiply_by 1 -duty_cycle 50 -phase 0 -offset 0 


set_max_delay -from [get_registers *param_handshake_sync*src_params_latch*] -to [get_registers *param_handshake_sync*dest_params*] 25

set_false_path -from [get_clocks {ethernet_adapter:ethernet_adapter_inst|ETH_pll:ETH_pll_inst|ETH_pll_0002:eth_pll_inst|altera_pll:altera_pll_i|outclk_wire[0]}] -to [get_clocks {ClockGenerator:clockGen_map|pll:PLL_MAP|pll_0002:pll_inst|altera_pll:altera_pll_i|outclk_wire[0]}]
set_false_path -to [get_clocks {ethernet_adapter:ethernet_adapter_inst|ETH_pll:ETH_pll_inst|ETH_pll_0002:eth_pll_inst|altera_pll:altera_pll_i|outclk_wire[0]}] -from [get_clocks {ClockGenerator:clockGen_map|pll:PLL_MAP|pll_0002:pll_inst|altera_pll:altera_pll_i|outclk_wire[0]}]
set_false_path -to {led[*]~reg0}