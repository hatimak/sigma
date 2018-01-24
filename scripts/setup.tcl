# get the directory where this script resides
set thisDir [file dirname [info script]]
# source common utilities
source -notrace $thisDir/utils.tcl

set hdlRoot ./hdl
set xdcRoot ./xdc
set ipRoot ./ip
set tbRoot ./tb

# Create project
create_project -force top ./vivado/top -part xc7a100tcsg324-1

# Set project properties
set obj [get_projects top]
set_property "board_part" "digilentinc.com:nexys4_ddr:part0:1.1" $obj
set_property "simulator_language" "Mixed" $obj
set_property "target_language" "Verilog" $obj
set_property coreContainer.enable 1 $obj

add_files -norecurse $hdlRoot/pe_time_proc.v
add_files -norecurse $hdlRoot/pe_meas_proc.v

add_files -norecurse $ipRoot/pe_time_ip_add.xcix
add_files -norecurse $ipRoot/pe_time_ip_mult_dsp.xcix
add_files -norecurse $ipRoot/pe_time_ip_sub.xcix
add_files -norecurse $ipRoot/pe_time_ip_div.xcix
add_files -norecurse $ipRoot/pe_time_ip_sub_const.xcix
add_files -norecurse $ipRoot/pe_time_ip_trig.xcix
add_files -norecurse $ipRoot/pe_meas_ip_add_long.xcix
add_files -norecurse $ipRoot/pe_meas_ip_shift_ram.xcix
add_files -norecurse $ipRoot/pe_meas_ip_sqrt.xcix
add_files -norecurse $ipRoot/pe_meas_ip_arctan.xcix
add_files -norecurse $ipRoot/pe_meas_ip_shift_valid.xcix
add_files -norecurse $ipRoot/pe_meas_ip_square.xcix
add_files -norecurse $ipRoot/pe_matrix_ip_mac.xcix

update_compile_order -fileset sources_1
set_property SOURCE_SET sources_1 [get_filesets sim_1]
add_files -fileset sim_1 -norecurse $tbRoot/tb_pe_time_proc.v
update_compile_order -fileset sim_1

# If successful, "touch" a file so the make utility will know it's done 
touch {.setup_vivado.done}

