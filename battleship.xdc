# # @Author: EvanPai, Haotien

# ## Clock signal
# set_property PACKAGE_PIN W5 [get_ports clk]
# set_property IOSTANDARD LVCMOS33 [get_ports clk]
# create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports clk]

# ## Buttons
# set_property PACKAGE_PIN U18 [get_ports rst]
# set_property IOSTANDARD LVCMOS33 [get_ports rst]

# ## Switches
# set_property PACKAGE_PIN V17 [get_ports en]
# set_property IOSTANDARD LVCMOS33 [get_ports en]
# set_property PACKAGE_PIN V16 [get_ports dir]
# set_property IOSTANDARD LVCMOS33 [get_ports dir]
# set_property PACKAGE_PIN W16 [get_ports vmir]
# set_property IOSTANDARD LVCMOS33 [get_ports vmir]
# set_property PACKAGE_PIN W17 [get_ports hmir]
# set_property IOSTANDARD LVCMOS33 [get_ports hmir]
# set_property PACKAGE_PIN W15 [get_ports enlarge]
# set_property IOSTANDARD LVCMOS33 [get_ports enlarge]

# ## VGA Connector
# set_property PACKAGE_PIN G19 [get_ports {vgaRed[0]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {vgaRed[0]}]
# set_property PACKAGE_PIN H19 [get_ports {vgaRed[1]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {vgaRed[1]}]
# set_property PACKAGE_PIN J19 [get_ports {vgaRed[2]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {vgaRed[2]}]
# set_property PACKAGE_PIN N19 [get_ports {vgaRed[3]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {vgaRed[3]}]
# set_property PACKAGE_PIN N18 [get_ports {vgaBlue[0]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {vgaBlue[0]}]
# set_property PACKAGE_PIN L18 [get_ports {vgaBlue[1]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {vgaBlue[1]}]
# set_property PACKAGE_PIN K18 [get_ports {vgaBlue[2]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {vgaBlue[2]}]
# set_property PACKAGE_PIN J18 [get_ports {vgaBlue[3]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {vgaBlue[3]}]
# set_property PACKAGE_PIN J17 [get_ports {vgaGreen[0]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {vgaGreen[0]}]
# set_property PACKAGE_PIN H17 [get_ports {vgaGreen[1]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {vgaGreen[1]}]
# set_property PACKAGE_PIN G17 [get_ports {vgaGreen[2]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {vgaGreen[2]}]
# set_property PACKAGE_PIN D17 [get_ports {vgaGreen[3]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {vgaGreen[3]}]
# set_property PACKAGE_PIN P19 [get_ports hsync]
# set_property IOSTANDARD LVCMOS33 [get_ports hsync]
# set_property PACKAGE_PIN R19 [get_ports vsync]
# set_property IOSTANDARD LVCMOS33 [get_ports vsync]


# set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
# set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
# set_property CONFIG_MODE SPIx4 [current_design]

# set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]

# set_property CONFIG_VOLTAGE 3.3 [current_design]
# set_property CFGBVS VCCO [current_design]

