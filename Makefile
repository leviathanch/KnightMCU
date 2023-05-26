#FILES = FPU/fpu_add.v  FPU/fpu_div.v  FPU/fpu_double.v  FPU/fpu_exceptions.v  FPU/fpu_mul.v  FPU/fpu_round.v  FPU/fpu_sub.v  FPU/fpu_TB.v \
#	convolution.v \
#	convolution_test.v

#sim:
#	iverilog -o convolution_test -s Convolution_Test -g2005-sv $(FILES)
#	vvp convolution_test


#memory_access_unit_tb:
#	iverilog -o memory_access_unit_tb -s memory_access_unit_tb -g2005-sv \
#		verilog/src/ai/memory_access_unit.v \
#		verilog/benches/memory_access_unit_tb.v

#mixed_precision_alu_tb:
#	iverilog -o mixed_precision_alu_tb -s mixed_precision_alu_tb -g2005-sv \
#		verilog/src/ai/mixed_precision_alu.v \
#		verilog/benches/mixed_precision_alu_tb.v
#

#MatrixConvolution_TB:
#	iverilog -o MatrixConvolution_TB -s MatrixConvolution_TB -g2005-sv \
#		verilog/src/chatgpt/MatrixConvolution.v \
#		verilog/benches/convolution_test2.v

#all: memory_access_unit_tb memory_access_unit_tb

AI_Accelerator_Top_TB:
	iverilog -o AI_Accelerator_Top_TB -s AI_Accelerator_Top_TB -g2005-sv \
		verilog/src/chatgpt/Matrix_Multiplication.v \
		verilog/src/chatgpt/AI_Accelerator_Top.v \
		verilog/benches/AI_Accelerator_Top_TB.v
	vvp AI_Accelerator_Top_TB --stop-time 10000

clean:
	rm -f AI_Accelerator_Top_TB
