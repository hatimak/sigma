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

close_project

# If successful, "touch" a file so the make utility will know it's done 
touch {./vivado/.ip_top_vivado.done}

