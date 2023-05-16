FILES = convolution.v \
	convolution_test.v \
	FPU/fpu_double.v

sim:
	iverilog -o convolution_test -s Convolution_Test -g2005-sv $(FILES)
	vvp convolution_test

