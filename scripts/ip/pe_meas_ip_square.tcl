# get the directory where this script resides
set thisDir [file dirname [info script]]

set ipDir ./ip

open_project ./vivado/ip/ip.xpr

# Create IP
create_ip -vlnv xilinx.com:ip:mult_gen:12.0 -module_name pe_meas_ip_square -dir $ipDir

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

export_ip_user_files -of_objects [get_files pe_meas_ip_square.xci] -no_script -ip_user_files_dir ./vivado/ip_user_files -sync -force -quiet

create_ip_run [get_files -of_objects [get_fileset sources_1] [get_files */pe_meas_ip_square.xci]]

launch_runs -jobs 4 pe_meas_ip_square_synth_1
wait_on_run pe_meas_ip_square_synth_1

export_simulation -of_objects [get_files pe_meas_ip_square.xci] -directory ./vivado/ip_user_files/sim_scripts -ip_user_files_dir ./vivado/ip_user_files -ipstatic_source_dir ./vivado/ip_user_files/ipstatic -use_ip_compiled_libs -force -quiet

close_project

