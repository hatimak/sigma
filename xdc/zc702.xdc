create_clock -period 5.000 -waveform {0.000 2.500} [get_ports SYSCLK_P]

set_property -dict {PACKAGE_PIN C19 IOSTANDARD LVDS_25} [get_ports SYSCLK_N]
set_property -dict {PACKAGE_PIN D18 IOSTANDARD LVDS_25} [get_ports SYSCLK_P]
