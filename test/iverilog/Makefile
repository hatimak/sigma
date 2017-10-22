CC=iverilog

FPU_SRC=../../src/verilog/fpu/fpu_double.v \
		../../src/verilog/fpu/fpu_add.v \
		../../src/verilog/fpu/fpu_sub.v \
		../../src/verilog/fpu/fpu_mul.v \
		../../src/verilog/fpu/fpu_div.v \
		../../src/verilog/fpu/fpu_exceptions.v \
		../../src/verilog/fpu/fpu_round.v

fpu: fpu.v $(FPU_SRC)
	$(CC) -o fpu.out fpu.v $(FPU_SRC)
	vvp fpu.out

matrix_add: matrix_add.v ../../src/verilog/matrix/matrix_add.v $(FPU_SRC)
	$(CC) -o matrix_add.out matrix_add.v ../../src/verilog/matrix/matrix_add.v $(FPU_SRC)
	vvp matrix_add.out

.PHONY: clean

clean:
	rm -rf *.out *.vcd
