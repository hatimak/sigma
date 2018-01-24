# get the directory where this script resides
set thisDir [file dirname [info script]]
# source common utilities
source -notrace $thisDir/utils.tcl

set ipDir ./ip

create_project -force ip ./vivado/ip -part xc7a100tcsg324-1 -ip

# Set project properties
set obj [get_projects ip]
set_property "board_part" "digilentinc.com:nexys4_ddr:part0:1.1" $obj
set_property "simulator_language" "Mixed" $obj
set_property "target_language" "Verilog" $obj
set_property coreContainer.enable 1 $obj

set_property target_simulator XSim [current_project]

# Create IPs
# ==========

# pe_matrix_ip_mac
# ----------------
create_ip -name xbip_multadd -vendor xilinx.com -library ip -version 3.0 -module_name pe_matrix_ip_mac -dir $ipDir

set_property -dict [list \
	CONFIG.c_a_width {32} \
	CONFIG.c_b_width {32} \
	CONFIG.c_c_width {64} \
	CONFIG.c_out_high {63} \
	CONFIG.c_out_low {0} \
	CONFIG.c_ab_latency {0} \
	CONFIG.c_c_latency {0} \
] [get_ips pe_matrix_ip_mac]

generate_target all [get_files pe_matrix_ip_mac.xci]
# ------------------------------------------------------------------------------

# pe_meas_ip_add_long
# -------------------
create_ip -name c_addsub -vendor xilinx.com -library ip -version 12.0 -module_name pe_meas_ip_add_long -dir $ipDir

set_property -dict [list \
	CONFIG.Component_Name {pe_meas_ip_add_long} \
	CONFIG.Implementation {DSP48} \
	CONFIG.A_Width {48} \
	CONFIG.B_Width {48} \
	CONFIG.Out_Width {48} \
	CONFIG.Latency {0} \
	CONFIG.CE {false} \
	CONFIG.B_Value {000000000000000000000000000000000000000000000000} \
] [get_ips pe_meas_ip_add_long]

generate_target all [get_files pe_meas_ip_add_long.xci]
# ------------------------------------------------------------------------------

# pe_meas_ip_arctan
# -----------------
create_ip -name cordic -vendor xilinx.com -library ip -version 6.0 -module_name pe_meas_ip_arctan -dir $ipDir

set_property -dict [list \
	CONFIG.Component_Name {pe_meas_ip_arctan} \
	CONFIG.Functional_Selection {Arc_Tan} \
	CONFIG.Pipelining_Mode {Optimal} \
	CONFIG.Input_Width {32} \
	CONFIG.Output_Width {19} \
	CONFIG.Data_Format {SignedFraction} \
	CONFIG.Round_Mode {Nearest_Even} \
	CONFIG.ACLKEN {true} \
] [get_ips pe_meas_ip_arctan]

generate_target all [get_files pe_meas_ip_arctan.xci]
# ------------------------------------------------------------------------------

# pe_meas_ip_shift_ram
# --------------------
create_ip -name c_shift_ram -vendor xilinx.com -library ip -version 12.0 -module_name pe_meas_ip_shift_ram -dir $ipDir

set_property -dict [list \
	CONFIG.Component_Name {pe_meas_ip_shift_ram} \
	CONFIG.CE {true} \
	CONFIG.Width {32} \
	CONFIG.Depth {5} \
	CONFIG.DefaultData {00000000000000000000000000000000} \
	CONFIG.AsyncInitVal {00000000000000000000000000000000} \
	CONFIG.SyncInitVal {00000000000000000000000000000000} \
] [get_ips pe_meas_ip_shift_ram]

generate_target all [get_files pe_meas_ip_shift_ram.xci]
# ------------------------------------------------------------------------------

# pe_meas_ip_shift_valid
# ----------------------
create_ip -name c_shift_ram -vendor xilinx.com -library ip -version 12.0 -module_name pe_meas_ip_shift_valid -dir $ipDir

set_property -dict [list \
	CONFIG.Component_Name {pe_meas_ip_shift_valid} \
	CONFIG.CE {true} \
	CONFIG.Width {1} \
	CONFIG.Depth {22} \
	CONFIG.DefaultData {0} \
	CONFIG.AsyncInitVal {0} \
	CONFIG.SyncInitVal {0} \
] [get_ips pe_meas_ip_shift_valid]

generate_target all [get_files pe_meas_ip_shift_valid.xci]
# ------------------------------------------------------------------------------

# pe_meas_ip_sqrt
# ---------------
create_ip -name cordic -vendor xilinx.com -library ip -version 6.0 -module_name pe_meas_ip_sqrt -dir $ipDir

set_property -dict [list \
	CONFIG.Component_Name {pe_meas_ip_sqrt} \
	CONFIG.Functional_Selection {Square_Root} \
	CONFIG.Pipelining_Mode {Optimal} \
	CONFIG.Input_Width {47} \
	CONFIG.Output_Width {32} \
	CONFIG.Round_Mode {Nearest_Even} \
	CONFIG.ACLKEN {true} \
	CONFIG.Data_Format {UnsignedFraction} \
	CONFIG.Coarse_Rotation {false} \
] [get_ips pe_meas_ip_sqrt]

generate_target all [get_files pe_meas_ip_sqrt.xci]
# ------------------------------------------------------------------------------

# pe_meas_ip_square
# -----------------
create_ip -name mult_gen -vendor xilinx.com -library ip -version 12.0 -module_name pe_meas_ip_square -dir $ipDir

set_property -dict [list \
	CONFIG.Component_Name {pe_meas_ip_square} \
	CONFIG.PortAWidth {32} \
	CONFIG.PortBWidth {32} \
	CONFIG.Multiplier_Construction {Use_Mults} \
	CONFIG.Use_Custom_Output_Width {true} \
	CONFIG.OutputWidthHigh {63} \
	CONFIG.OutputWidthLow {16} \
	CONFIG.PipeStages {0} \
] [get_ips pe_meas_ip_square]

generate_target all [get_files pe_meas_ip_square.xci]
# ------------------------------------------------------------------------------

# pe_time_ip_add
# --------------
create_ip -name c_addsub -vendor xilinx.com -library ip -version 12.0 -module_name pe_time_ip_add -dir $ipDir

set_property -dict [list \
	CONFIG.Component_Name {pe_time_ip_add} \
	CONFIG.Implementation {DSP48} \
	CONFIG.A_Width {32} \
	CONFIG.B_Width {32} \
	CONFIG.Latency {0} \
	CONFIG.CE {false} \
	CONFIG.Out_Width {32} \
	CONFIG.B_Value {00000000000000000000000000000000} \
] [get_ips pe_time_ip_add]

generate_target all [get_files pe_time_ip_add.xci]
# ------------------------------------------------------------------------------

# pe_time_ip_div
# --------------
create_ip -name div_gen -vendor xilinx.com -library ip -version 5.1 -module_name pe_time_ip_div -dir $ipDir

set_property -dict [list \
	CONFIG.Component_Name {pe_time_ip_div} \
	CONFIG.dividend_and_quotient_width {32} \
	CONFIG.divisor_width {32} \
	CONFIG.remainder_type {Fractional} \
	CONFIG.fractional_width {17} \
	CONFIG.latency_configuration {Manual} \
	CONFIG.latency {21} \
	CONFIG.ACLKEN {true} \
] [get_ips pe_time_ip_div]

generate_target all [get_files pe_time_ip_div.xci]
# ------------------------------------------------------------------------------

# pe_time_ip_mult_dsp
# -------------------
create_ip -name mult_gen -vendor xilinx.com -library ip -version 12.0 -module_name pe_time_ip_mult_dsp -dir $ipDir

set_property -dict [list \
	CONFIG.Component_Name {pe_time_ip_mult_dsp} \
	CONFIG.PortAWidth {32} \
	CONFIG.PortBWidth {32} \
	CONFIG.Multiplier_Construction {Use_Mults} \
	CONFIG.Use_Custom_Output_Width {true} \
	CONFIG.OutputWidthHigh {47} \
	CONFIG.OutputWidthLow {16} \
	CONFIG.PipeStages {0} \
] [get_ips pe_time_ip_mult_dsp]

generate_target all [get_files pe_time_ip_mult_dsp.xci]
# ------------------------------------------------------------------------------

# pe_time_ip_sub
# --------------
create_ip -name c_addsub -vendor xilinx.com -library ip -version 12.0 -module_name pe_time_ip_sub -dir $ipDir

set_property -dict [list \
	CONFIG.Component_Name {pe_time_ip_sub} \
	CONFIG.Implementation {DSP48} \
	CONFIG.A_Width {32} \
	CONFIG.B_Width {32} \
	CONFIG.Add_Mode {Subtract} \
	CONFIG.Out_Width {32} \
	CONFIG.Latency {0} \
	CONFIG.CE {false} \
	CONFIG.Out_Width {32} \
	CONFIG.Latency {0} \
	CONFIG.B_Value {00000000000000000000000000000000} \
] [get_ips pe_time_ip_sub]

generate_target all [get_files pe_time_ip_sub.xci]
# ------------------------------------------------------------------------------

# pe_time_ip_sub_const
# --------------------
create_ip -name c_addsub -vendor xilinx.com -library ip -version 12.0 -module_name pe_time_ip_sub_const -dir $ipDir

set_property -dict [list \
	CONFIG.Component_Name {pe_time_ip_sub_const} \
	CONFIG.Implementation {DSP48} \
	CONFIG.A_Type {Unsigned} \
	CONFIG.B_Type {Unsigned} \
	CONFIG.A_Width {32} \
	CONFIG.B_Width {1} \
	CONFIG.Add_Mode {Subtract} \
	CONFIG.Latency {0} \
	CONFIG.B_Constant {true} \
	CONFIG.B_Value {1} \
	CONFIG.CE {false} \
	CONFIG.Out_Width {32} \
] [get_ips pe_time_ip_sub_const]

generate_target all [get_files pe_time_ip_sub_const.xci]
# ------------------------------------------------------------------------------

# pe_time_ip_trig
# ---------------
create_ip -name cordic -vendor xilinx.com -library ip -version 6.0 -module_name pe_time_ip_trig -dir $ipDir

set_property -dict [list \
	CONFIG.Component_Name {pe_time_ip_trig} \
	CONFIG.Functional_Selection {Sin_and_Cos} \
	CONFIG.Pipelining_Mode {Optimal} \
	CONFIG.Input_Width {19} \
	CONFIG.Output_Width {18} \
	CONFIG.Round_Mode {Nearest_Even} \
	CONFIG.ACLKEN {true} \
	CONFIG.Data_Format {SignedFraction} \
] [get_ips pe_time_ip_trig]

generate_target all [get_files pe_time_ip_trig.xci]
# ------------------------------------------------------------------------------

# Export IP user files
# ====================

export_ip_user_files -of_objects [get_files pe_matrix_ip_mac.xci] -no_script -ip_user_files_dir ./vivado/ip_user_files -sync -force -quiet
export_ip_user_files -of_objects [get_files pe_meas_ip_add_long.xci] -no_script -ip_user_files_dir ./vivado/ip_user_files -sync -force -quiet
export_ip_user_files -of_objects [get_files pe_meas_ip_arctan.xci] -no_script -ip_user_files_dir ./vivado/ip_user_files -sync -force -quiet
export_ip_user_files -of_objects [get_files pe_meas_ip_shift_ram.xci] -no_script -ip_user_files_dir ./vivado/ip_user_files -sync -force -quiet
export_ip_user_files -of_objects [get_files pe_meas_ip_shift_valid.xci] -no_script -ip_user_files_dir ./vivado/ip_user_files -sync -force -quiet
export_ip_user_files -of_objects [get_files pe_meas_ip_sqrt.xci] -no_script -ip_user_files_dir ./vivado/ip_user_files -sync -force -quiet
export_ip_user_files -of_objects [get_files pe_meas_ip_square.xci] -no_script -ip_user_files_dir ./vivado/ip_user_files -sync -force -quiet
export_ip_user_files -of_objects [get_files pe_time_ip_add.xci] -no_script -ip_user_files_dir ./vivado/ip_user_files -sync -force -quiet
export_ip_user_files -of_objects [get_files pe_time_ip_div.xci] -no_script -ip_user_files_dir ./vivado/ip_user_files -sync -force -quiet
export_ip_user_files -of_objects [get_files pe_time_ip_mult_dsp.xci] -no_script -ip_user_files_dir ./vivado/ip_user_files -sync -force -quiet
export_ip_user_files -of_objects [get_files pe_time_ip_sub.xci] -no_script -ip_user_files_dir ./vivado/ip_user_files -sync -force -quiet
export_ip_user_files -of_objects [get_files pe_time_ip_sub_const.xci] -no_script -ip_user_files_dir ./vivado/ip_user_files -sync -force -quiet
export_ip_user_files -of_objects [get_files pe_time_ip_trig.xci] -no_script -ip_user_files_dir ./vivado/ip_user_files -sync -force -quiet

# ------------------------------------------------------------------------------

# IP Runs
# =======

create_ip_run [get_files -of_objects [get_fileset sources_1] [get_files */pe_matrix_ip_mac.xci]]
create_ip_run [get_files -of_objects [get_fileset sources_1] [get_files */pe_meas_ip_add_long.xci]]
create_ip_run [get_files -of_objects [get_fileset sources_1] [get_files */pe_meas_ip_arctan.xci]]
create_ip_run [get_files -of_objects [get_fileset sources_1] [get_files */pe_meas_ip_shift_ram.xci]]
create_ip_run [get_files -of_objects [get_fileset sources_1] [get_files */pe_meas_ip_shift_valid.xci]]
create_ip_run [get_files -of_objects [get_fileset sources_1] [get_files */pe_meas_ip_sqrt.xci]]
create_ip_run [get_files -of_objects [get_fileset sources_1] [get_files */pe_meas_ip_square.xci]]
create_ip_run [get_files -of_objects [get_fileset sources_1] [get_files */pe_time_ip_add.xci]]
create_ip_run [get_files -of_objects [get_fileset sources_1] [get_files */pe_time_ip_div.xci]]
create_ip_run [get_files -of_objects [get_fileset sources_1] [get_files */pe_time_ip_mult_dsp.xci]]
create_ip_run [get_files -of_objects [get_fileset sources_1] [get_files */pe_time_ip_sub.xci]]
create_ip_run [get_files -of_objects [get_fileset sources_1] [get_files */pe_time_ip_sub_const.xci]]
create_ip_run [get_files -of_objects [get_fileset sources_1] [get_files */pe_time_ip_trig.xci]]

launch_runs -jobs 4 pe_matrix_ip_mac_synth_1
wait_on_run pe_matrix_ip_mac_synth_1

launch_runs -jobs 4 pe_meas_ip_add_long_synth_1
wait_on_run pe_meas_ip_add_long_synth_1

launch_runs -jobs 4 pe_meas_ip_arctan_synth_1
wait_on_run pe_meas_ip_arctan_synth_1

launch_runs -jobs 4 pe_meas_ip_shift_ram_synth_1
wait_on_run pe_meas_ip_shift_ram_synth_1

launch_runs -jobs 4 pe_meas_ip_shift_valid_synth_1
wait_on_run pe_meas_ip_shift_valid_synth_1

launch_runs -jobs 4 pe_meas_ip_sqrt_synth_1
wait_on_run pe_meas_ip_sqrt_synth_1

launch_runs -jobs 4 pe_meas_ip_square_synth_1
wait_on_run pe_meas_ip_square_synth_1

launch_runs -jobs 4 pe_time_ip_add_synth_1
wait_on_run pe_time_ip_add_synth_1

launch_runs -jobs 4 pe_time_ip_div_synth_1
wait_on_run pe_time_ip_div_synth_1

launch_runs -jobs 4 pe_time_ip_mult_dsp_synth_1
wait_on_run pe_time_ip_mult_dsp_synth_1

launch_runs -jobs 4 pe_time_ip_sub_synth_1
wait_on_run pe_time_ip_sub_synth_1

launch_runs -jobs 4 pe_time_ip_sub_const_synth_1
wait_on_run pe_time_ip_sub_const_synth_1

launch_runs -jobs 4 pe_time_ip_trig_synth_1
wait_on_run pe_time_ip_trig_synth_1
# ------------------------------------------------------------------------------

# Export Simulations
# ==================

export_simulation -of_objects [get_files pe_matrix_ip_mac.xci] -directory ./vivado/ip_user_files/sim_scripts -ip_user_files_dir ./vivado/ip_user_files -ipstatic_source_dir ./vivado/ip_user_files/ipstatic -use_ip_compiled_libs -force -quiet
export_simulation -of_objects [get_files pe_meas_ip_add_long.xci] -directory ./vivado/ip_user_files/sim_scripts -ip_user_files_dir ./vivado/ip_user_files -ipstatic_source_dir ./vivado/ip_user_files/ipstatic -use_ip_compiled_libs -force -quiet
export_simulation -of_objects [get_files pe_meas_ip_arctan.xci] -directory ./vivado/ip_user_files/sim_scripts -ip_user_files_dir ./vivado/ip_user_files -ipstatic_source_dir ./vivado/ip_user_files/ipstatic -use_ip_compiled_libs -force -quiet
export_simulation -of_objects [get_files pe_meas_ip_shift_ram.xci] -directory ./vivado/ip_user_files/sim_scripts -ip_user_files_dir ./vivado/ip_user_files -ipstatic_source_dir ./vivado/ip_user_files/ipstatic -use_ip_compiled_libs -force -quiet
export_simulation -of_objects [get_files pe_meas_ip_shift_valid.xci] -directory ./vivado/ip_user_files/sim_scripts -ip_user_files_dir ./vivado/ip_user_files -ipstatic_source_dir ./vivado/ip_user_files/ipstatic -use_ip_compiled_libs -force -quiet
export_simulation -of_objects [get_files pe_meas_ip_sqrt.xci] -directory ./vivado/ip_user_files/sim_scripts -ip_user_files_dir ./vivado/ip_user_files -ipstatic_source_dir ./vivado/ip_user_files/ipstatic -use_ip_compiled_libs -force -quiet
export_simulation -of_objects [get_files pe_meas_ip_square.xci] -directory ./vivado/ip_user_files/sim_scripts -ip_user_files_dir ./vivado/ip_user_files -ipstatic_source_dir ./vivado/ip_user_files/ipstatic -use_ip_compiled_libs -force -quiet
export_simulation -of_objects [get_files pe_time_ip_add.xci] -directory ./vivado/ip_user_files/sim_scripts -ip_user_files_dir ./vivado/ip_user_files -ipstatic_source_dir ./vivado/ip_user_files/ipstatic -use_ip_compiled_libs -force -quiet
export_simulation -of_objects [get_files pe_time_ip_div.xci] -directory ./vivado/ip_user_files/sim_scripts -ip_user_files_dir ./vivado/ip_user_files -ipstatic_source_dir ./vivado/ip_user_files/ipstatic -use_ip_compiled_libs -force -quiet
export_simulation -of_objects [get_files pe_time_ip_mult_dsp.xci] -directory ./vivado/ip_user_files/sim_scripts -ip_user_files_dir ./vivado/ip_user_files -ipstatic_source_dir ./vivado/ip_user_files/ipstatic -use_ip_compiled_libs -force -quiet
export_simulation -of_objects [get_files pe_time_ip_sub.xci] -directory ./vivado/ip_user_files/sim_scripts -ip_user_files_dir ./vivado/ip_user_files -ipstatic_source_dir ./vivado/ip_user_files/ipstatic -use_ip_compiled_libs -force -quiet
export_simulation -of_objects [get_files pe_time_ip_sub_const.xci] -directory ./vivado/ip_user_files/sim_scripts -ip_user_files_dir ./vivado/ip_user_files -ipstatic_source_dir ./vivado/ip_user_files/ipstatic -use_ip_compiled_libs -force -quiet
export_simulation -of_objects [get_files pe_time_ip_trig.xci] -directory ./vivado/ip_user_files/sim_scripts -ip_user_files_dir ./vivado/ip_user_files -ipstatic_source_dir ./vivado/ip_user_files/ipstatic -use_ip_compiled_libs -force -quiet
# ------------------------------------------------------------------------------

# If successful, "touch" a file so the make utility will know it's done
touch {.ip_vivado.done}

