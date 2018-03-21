create_clock -period 10.000 -waveform {0.000 5.000} [get_ports SYSCLK_P]

set_property -dict {PACKAGE_PIN C19 IOSTANDARD LVDS_25} [get_ports SYSCLK_N]
set_property -dict {PACKAGE_PIN D18 IOSTANDARD LVDS_25} [get_ports SYSCLK_P]
