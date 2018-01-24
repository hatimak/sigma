RTL=./hdl/pe_time_proc.v ./hdl/pe_meas_proc.v ./hdl/pe_matrix_expectation_comb.v

vivado: ip_vivado setup_vivado

setup_vivado: .setup_vivado.done
.setup_vivado.done: $(RTL) .ip_vivado.done
	mkdir -p ./vivado/top
	vivado -mode batch -source ./scripts/setup.tcl -log ./vivado/top/setup.log -jou ./vivado/top/setup.jou

ip_vivado: .ip_vivado.done
.ip_vivado.done:
	mkdir -p ./vivado/ip
	mkdir -p ./ip
	vivado -mode batch -source ./scripts/ip.tcl -log ./vivado/ip/ip.log -jou ./vivado/ip/ip.jou

clean:
	rm -rf ./vivado .setup_vivado.done .ip_vivado.done ./ip/*

