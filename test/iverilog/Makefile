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

matrix_mul: matrix_mul.v ../../src/verilog/matrix/matrix_mul.v $(FPU_SRC)
	$(CC) -o matrix_mul.out matrix_mul.v ../../src/verilog/matrix/matrix_mul.v $(FPU_SRC)
	vvp matrix_mul.out

sqrt: sqrt.v ../../src/verilog/ancillary/sqrt.v $(FPU_SRC)
	$(CC) -o sqrt.out sqrt.v ../../src/verilog/ancillary/sqrt.v $(FPU_SRC)
	vvp sqrt.out

cholesky: cholesky.v ../../src/verilog/matrix/cholesky.v ../../src/verilog/ancillary/sqrt.v $(FPU_SRC)
	$(CC) -o cholesky.out cholesky.v ../../src/verilog/matrix/cholesky.v ../../src/verilog/ancillary/sqrt.v $(FPU_SRC)
	vvp cholesky.out

rng_uni: rng_uni.v ../../src/verilog/rng/uniform/rng_uni.v ../../src/verilog/rng/uniform/rng_uni_sr.v
	$(CC) -o rng_uni.out rng_uni.v ../../src/verilog/rng/uniform/rng_uni.v ../../src/verilog/rng/uniform/rng_uni_sr.v
	vvp rng_uni.out

.PHONY: clean

clean:
	rm -rf *.out *.vcd *.log
