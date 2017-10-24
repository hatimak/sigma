# sigma

Contains Verilog for controller/observer that is being implemented as part of Bachelors Thesis work under supervision of Dr Shovan Bhaumik, Indian Institute of Technology Patna.

Contact me@hatimak.me for details.

-----

### FuseSoC Usage

Make sure [FuseSoC](https://github.com/olofk/fusesoc) is installed and initialised.

Run simulation with `fusesoc sim [--sim=SIMULATOR] [--testbench=TESTBENCH_MODULE] sigma`. Default simulator is [Icarus](http://iverilog.icarus.com) and default testbench is [`fpu_tb`](test/iverilog/fpu.v).

The `sigma` core needs to be in the `cores_root` list for it to be found. This can be achieved either by supplying an argument with `fusesoc` invocation, like `fusesoc --cores-root ../sigma sim sigma`, or by adding to the `cores_root` list in `~/.config/fusesoc/fusesoc.conf` the path to the directory which holds `sigma.core`. For more information on this, please refer to FuseSoC documentation.
