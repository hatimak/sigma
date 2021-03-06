# get the directory where this script resides
set thisDir [file dirname [info script]]

set ipDir ./ip

open_project ./vivado/ip/ip.xpr

# Create IP
create_ip -vlnv xilinx.com:ip:c_shift_ram:12.0 -module_name pe_meas_ip_shift_ram -dir $ipDir

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

export_ip_user_files -of_objects [get_files pe_meas_ip_shift_ram.xci] -no_script -ip_user_files_dir ./vivado/ip_user_files -sync -force -quiet

create_ip_run [get_files -of_objects [get_fileset sources_1] [get_files */pe_meas_ip_shift_ram.xci]]

launch_runs -jobs 8 pe_meas_ip_shift_ram_synth_1
wait_on_run pe_meas_ip_shift_ram_synth_1

export_simulation -of_objects [get_files pe_meas_ip_shift_ram.xci] -directory ./vivado/ip_user_files/sim_scripts -ip_user_files_dir ./vivado/ip_user_files -ipstatic_source_dir ./vivado/ip_user_files/ipstatic -use_ip_compiled_libs -force -quiet

close_project

