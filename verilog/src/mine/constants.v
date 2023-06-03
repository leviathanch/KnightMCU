`default_nettype none

`ifndef __KOIP_DEFINE_H
// Global parameters
`define __KOIP_DEFINE_H

`define KICP_SRAM_AWIDTH 8

/*
Input memory contains registers 1-6
0: operation code to perform
// 1..4: dimensional information
0: width A
1: height A
2: width B
3: height B

Rest: Matrices and results

Plus space for the calculations
*/

`define TYPE_BW 32 // int32_t
//`define TYPE_BW 16 // int16_t

`endif // __GLOBAL_DEFINE_H
