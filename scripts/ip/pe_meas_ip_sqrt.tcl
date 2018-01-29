# get the directory where this script resides
set thisDir [file dirname [info script]]

set ipDir ./ip

open_project ./vivado/ip/ip.xpr

# Create IP
create_ip -vlnv xilinx.com:ip:cordic:6.0 -module_name pe_meas_ip_sqrt -dir $ipDir

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

export_ip_user_files -of_objects [get_files pe_meas_ip_sqrt.xci] -no_script -ip_user_files_dir ./vivado/ip_user_files -sync -force -quiet

create_ip_run [get_files -of_objects [get_fileset sources_1] [get_files */pe_meas_ip_sqrt.xci]]

launch_runs -jobs 4 pe_meas_ip_sqrt_synth_1
wait_on_run pe_meas_ip_sqrt_synth_1

export_simulation -of_objects [get_files pe_meas_ip_sqrt.xci] -directory ./vivado/ip_user_files/sim_scripts -ip_user_files_dir ./vivado/ip_user_files -ipstatic_source_dir ./vivado/ip_user_files/ipstatic -use_ip_compiled_libs -force -quiet

close_project

