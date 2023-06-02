`default_nettype none

`ifndef __KOIP_DEFINE_H
// Global parameters
`define __KOIP_DEFINE_H

//`define MEM_SIZE (1<<8)
//`define MEM_SIZE (1<<7) // 128*4 = 256 bytes
//`define MEM_SIZE (1<<6) // 64*4 = 256 bytes
`define MEM_SIZE (1<<5) // 32*4 = 128 bytes
//`define MEM_SIZE (1<<4) // 16*4 = 64 bytes

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

Plus space for the calculations
*/
`define DFF_MEM_SIZE (6+(3*`MEM_SIZE*`MEM_SIZE))
`define TYPE_BW 32 // int32_t
//`define TYPE_BW 16 // int16_t

`endif // __GLOBAL_DEFINE_H
