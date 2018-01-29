RTL=./hdl/pe_time_proc.v ./hdl/pe_meas_proc.v ./hdl/pe_matrix_expectation_comb.v

IP=./ip/cholesky_ip_div.xcix ./ip/cholesky_ip_sqrt.xcix ./ip/cholesky_ip_sub.xcix ./ip/pe_matrix_ip_mac.xcix ./ip/pe_meas_ip_add_long.xcix ./ip/pe_meas_ip_arctan.xcix ./ip/pe_meas_ip_shift_ram.xcix ./ip/pe_meas_ip_shift_valid.xcix ./ip/pe_meas_ip_sqrt.xcix ./ip/pe_meas_ip_square.xcix ./ip/pe_time_ip_add.xcix ./ip/pe_time_ip_div.xcix ./ip/pe_time_ip_mult_dsp.xcix ./ip/pe_time_ip_sub.xcix ./ip/pe_time_ip_sub_const.xcix ./ip/pe_time_ip_trig.xcix

vivado: ip_vivado setup_vivado

setup_vivado: ./vivado/.setup_vivado.done
./vivado/.setup_vivado.done: $(RTL) ./vivado/.ip_top_vivado.done
	mkdir -p ./vivado/top
	vivado -mode batch -source ./scripts/setup.tcl -log ./vivado/top/setup.log -jou ./vivado/top/setup.jou

ip_vivado: ./vivado/.ip_top_vivado.done $(IP)

./vivado/.ip_top_vivado.done:
	mkdir -p ./vivado/ip
	mkdir -p ./ip
	vivado -mode batch -source ./scripts/ip_project.tcl -log ./vivado/ip/ip.log -jou ./vivado/ip/ip.jou

$(IP): ./vivado/.ip_top_vivado.done
	vivado -mode batch -source ./scripts/$(@:.xcix=.tcl) -log ./vivado/$(@:.xcix=.log) -jou ./vivado/$(@:.xcix=.jou)

.PHONY: clean
clean:
	rm -rf ./vivado ./ip/* .Xil

