// (32-10)/2-1 = 22/2-1 = 11-1 = 10
`define SEQ_BITS 10
//`define MEM_SIZE (1<<9) // max size 512
//`define MEM_SIZE (1<<8) // max size 256
`define MEM_SIZE (1<<4)
`define PARALLEL_MULT_JOBS 2
/*
Input memory contains registers 1-6
0: operation code to perform
// 1..4: dimensional information
1: width A
2: height A
3: width B
4: height B
// shoot and go
5: done writing values, go!

Plus 2 matrices
*/
`define IN_MEM_SIZE (6+(2*`MEM_SIZE*`MEM_SIZE))
// Output memory: One matrix
`define OUT_MEM_SIZE (`MEM_SIZE*`MEM_SIZE)
