create_clock -period 4.444 -waveform {0.000 2.222} [get_ports SYSCLK_P]

set_property -dict {PACKAGE_PIN C19 IOSTANDARD LVDS_25} [get_ports SYSCLK_N]
set_property -dict {PACKAGE_PIN D18 IOSTANDARD LVDS_25} [get_ports SYSCLK_P]

set_property ADREG 1 [get_cells {cholesky_0/MAC_BLOCK[0].mac/mac_0/U0/i_synth/device_supports_dsp.use_multadd_dsp/dsp48s_multadd.separate.add/two_dsps.addsub0/i_synth_option.i_synth_model/opt_vx7.i_uniwrap/i_primitive}]
set_property DREG 1 [get_cells {cholesky_0/MAC_BLOCK[0].mac/mac_0/U0/i_synth/device_supports_dsp.use_multadd_dsp/dsp48s_multadd.separate.add/two_dsps.addsub0/i_synth_option.i_synth_model/opt_vx7.i_uniwrap/i_primitive}]

set_property ADREG 1 [get_cells {cholesky_0/MAC_BLOCK[1].mac/mac_0/U0/i_synth/device_supports_dsp.use_multadd_dsp/dsp48s_multadd.separate.add/two_dsps.addsub0/i_synth_option.i_synth_model/opt_vx7.i_uniwrap/i_primitive}]
set_property DREG 1 [get_cells {cholesky_0/MAC_BLOCK[1].mac/mac_0/U0/i_synth/device_supports_dsp.use_multadd_dsp/dsp48s_multadd.separate.add/two_dsps.addsub0/i_synth_option.i_synth_model/opt_vx7.i_uniwrap/i_primitive}]

set_property ADREG 1 [get_cells {cholesky_0/MAC_BLOCK[2].mac/mac_0/U0/i_synth/device_supports_dsp.use_multadd_dsp/dsp48s_multadd.separate.add/two_dsps.addsub0/i_synth_option.i_synth_model/opt_vx7.i_uniwrap/i_primitive}]
set_property DREG 1 [get_cells {cholesky_0/MAC_BLOCK[2].mac/mac_0/U0/i_synth/device_supports_dsp.use_multadd_dsp/dsp48s_multadd.separate.add/two_dsps.addsub0/i_synth_option.i_synth_model/opt_vx7.i_uniwrap/i_primitive}]

set_property ADREG 1 [get_cells {cholesky_0/MAC_BLOCK[3].mac/mac_0/U0/i_synth/device_supports_dsp.use_multadd_dsp/dsp48s_multadd.separate.add/two_dsps.addsub0/i_synth_option.i_synth_model/opt_vx7.i_uniwrap/i_primitive}]
set_property DREG 1 [get_cells {cholesky_0/MAC_BLOCK[3].mac/mac_0/U0/i_synth/device_supports_dsp.use_multadd_dsp/dsp48s_multadd.separate.add/two_dsps.addsub0/i_synth_option.i_synth_model/opt_vx7.i_uniwrap/i_primitive}]

set_property ADREG 1 [get_cells cholesky_0/inv_sqrt_0/sub_0/U0/xst_addsub/xbip_addsub.i_a_b_nogrowth.not_unsigned_max_width.i_xbip_addsub/addsub_usecase.i_addsub/i_synth_option.i_synth_model/opt_vx7.i_uniwrap/i_primitive]
set_property DREG 1 [get_cells cholesky_0/inv_sqrt_0/sub_0/U0/xst_addsub/xbip_addsub.i_a_b_nogrowth.not_unsigned_max_width.i_xbip_addsub/addsub_usecase.i_addsub/i_synth_option.i_synth_model/opt_vx7.i_uniwrap/i_primitive]
