# get the directory where this script resides
set thisDir [file dirname [info script]]

set ipDir ./ip

open_project ./vivado/ip/ip.xpr

# Create IP
create_ip -vlnv xilinx.com:ip:xbip_multadd:3.0 -module_name pe_matrix_ip_mac -dir $ipDir

set_property -dict [list \
	CONFIG.c_a_width {32} \
	CONFIG.c_b_width {32} \
	CONFIG.c_c_width {64} \
	CONFIG.c_out_high {63} \
	CONFIG.c_out_low {0} \
	CONFIG.c_ab_latency {-1} \
	CONFIG.c_c_latency {-1} \
] [get_ips pe_matrix_ip_mac]

generate_target all [get_files pe_matrix_ip_mac.xci]

export_ip_user_files -of_objects [get_files pe_matrix_ip_mac.xci] -no_script -ip_user_files_dir ./vivado/ip_user_files -sync -force -quiet

create_ip_run [get_files -of_objects [get_fileset sources_1] [get_files */pe_matrix_ip_mac.xci]]

launch_runs -jobs 8 pe_matrix_ip_mac_synth_1
wait_on_run pe_matrix_ip_mac_synth_1

export_simulation -of_objects [get_files pe_matrix_ip_mac.xci] -directory ./vivado/ip_user_files/sim_scripts -ip_user_files_dir ./vivado/ip_user_files -ipstatic_source_dir ./vivado/ip_user_files/ipstatic -use_ip_compiled_libs -force -quiet

close_project

