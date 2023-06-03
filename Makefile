AI_Accelerator_Top_TB:
	iverilog -o AI_Accelerator_Top_TB -s AI_Accelerator_Top_TB -pARRAY_SIZE_LIMIT=1073807361 \
		verilog/src/mine/constants.v \
		verilog/src/mine/RAM256.v \
		verilog/src/chatgpt/Matrix_Convolution.v \
		verilog/src/chatgpt/Matrix_Multiplication.v \
		verilog/src/chatgpt/AI_Accelerator_Top.v \
		verilog/benches/AI_Accelerator_Top_TB.v
	vvp AI_Accelerator_Top_TB --stop-time 10000

clean:
	rm -f AI_Accelerator_Top_TB
