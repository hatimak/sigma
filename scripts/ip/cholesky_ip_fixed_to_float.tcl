# get the directory where this script resides
set thisDir [file dirname [info script]]

set ipDir ./ip

open_project ./vivado/ip/ip.xpr

# Create IP
create_ip -vlnv xilinx.com:ip:floating_point:7.1 -module_name cholesky_ip_fixed_to_float -dir $ipDir
set_property -dict [list \
	CONFIG.Operation_Type {Fixed_to_float} \
	CONFIG.A_Precision_Type {Custom} \
	CONFIG.C_A_Exponent_Width {16} \
	CONFIG.C_A_Fraction_Width {16} \
	CONFIG.Axi_Optimize_Goal {Performance} \
	CONFIG.Has_RESULT_TREADY {false} \
	CONFIG.Has_ACLKEN {true} \
	CONFIG.Has_ARESETn {true} \
	CONFIG.Result_Precision_Type {Single} \
	CONFIG.C_Result_Exponent_Width {8} \
	CONFIG.C_Result_Fraction_Width {24} \
	CONFIG.C_Accum_Msb {32} \
	CONFIG.C_Accum_Lsb {-31} \
	CONFIG.C_Accum_Input_Msb {32} \
	CONFIG.C_Mult_Usage {No_Usage} \
	CONFIG.C_Latency {7} \
	CONFIG.C_Rate {1} \
] [get_ips cholesky_ip_fixed_to_float]

generate_target all [get_files cholesky_ip_fixed_to_float.xci]

export_ip_user_files -of_objects [get_files cholesky_ip_fixed_to_float.xci] -no_script -ip_user_files_dir ./vivado/ip_user_files -sync -force -quiet

create_ip_run [get_files -of_objects [get_fileset sources_1] [get_files */cholesky_ip_fixed_to_float.xci]]

launch_runs -jobs 8 cholesky_ip_fixed_to_float_synth_1
wait_on_run cholesky_ip_fixed_to_float_synth_1

export_simulation -of_objects [get_files cholesky_ip_fixed_to_float.xci] -directory ./vivado/ip_user_files/sim_scripts -ip_user_files_dir ./vivado/ip_user_files -ipstatic_source_dir ./vivado/ip_user_files/ipstatic -use_ip_compiled_libs -force -quiet

close_project
