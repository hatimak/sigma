# get the directory where this script resides
set thisDir [file dirname [info script]]

set ipDir ./ip

open_project ./vivado/ip/ip.xpr

# Create IP
create_ip -vlnv xilinx.com:ip:mult_gen:12.0 -module_name cholesky_ip_mult -dir $ipDir
set_property -dict [list \
	CONFIG.PortAWidth {32} \
	CONFIG.PortBWidth {32} \
	CONFIG.Multiplier_Construction {Use_Mults} \
	CONFIG.Use_Custom_Output_Width {true} \
	CONFIG.OutputWidthHigh {47} \
	CONFIG.OutputWidthLow {16} \
	CONFIG.PipeStages {6} \
	CONFIG.ClockEnable {true} \
	CONFIG.SyncClear {false} \
] [get_ips cholesky_ip_mult]

generate_target all [get_files cholesky_ip_mult.xci]

export_ip_user_files -of_objects [get_files cholesky_ip_mult.xci] -no_script -ip_user_files_dir ./vivado/ip_user_files -sync -force -quiet

create_ip_run [get_files -of_objects [get_fileset sources_1] [get_files */cholesky_ip_mult.xci]]

launch_runs -jobs 8 cholesky_ip_mult_synth_1
wait_on_run cholesky_ip_mult_synth_1

export_simulation -of_objects [get_files cholesky_ip_mult.xci] -directory ./vivado/ip_user_files/sim_scripts -ip_user_files_dir ./vivado/ip_user_files -ipstatic_source_dir ./vivado/ip_user_files/ipstatic -use_ip_compiled_libs -force -quiet

close_project
