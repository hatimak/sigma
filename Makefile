RTL=./hdl/pe_time_proc.v
IP=./ip/pe_time/pe_time_ip_add.xcix ./ip/pe_time/pe_time_ip_mult_dsp.xcix ./ip/pe_time/pe_time_ip_sub.xcix ./ip/pe_time/pe_time_ip_div.xcix ./ip/pe_time/pe_time_ip_sub_const.xcix ./ip/pe_time/pe_time_ip_trig.xcix

vivado : setup_vivado

# This setups up the top level project
setup_vivado : ./vivado/.setup.done
./vivado/.setup.done : $(RTL) $(IP)
	vivado -mode batch -source ./scripts/setup.tcl -log ./vivado/setup.log -jou ./vivado/setup.jou

clean :	
	rm -rf vivado/* *.log *.jou ./vivado/.setup.done

