FILES = FPU/fpu_add.v  FPU/fpu_div.v  FPU/fpu_double.v  FPU/fpu_exceptions.v  FPU/fpu_mul.v  FPU/fpu_round.v  FPU/fpu_sub.v  FPU/fpu_TB.v \
	convolution.v \
	convolution_test.v

sim:
	iverilog -o convolution_test -s Convolution_Test -g2005-sv $(FILES)
	vvp convolution_test

